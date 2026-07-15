(() => {
  "use strict";

  const state = {
    bookmarks: [],
    annotations: [],
    annotatedIds: new Set(),
    status: null,
    activeTab: "inbox",
    activeSource: "",
    sourceQuery: "",
    selectedId: "",
    loading: false,
    progressTimer: 0,
    annotationTimer: 0,
    annotationObserver: null,
  };

  const tabMeta = {
    inbox: ["收件箱", "按发布时间排列"],
    unread: ["未读", "还没有读完的文章"],
    favorites: ["收藏", "准备继续处理的文章"],
    highlights: ["划线", "包含摘录或批注的文章"],
    valuable: ["高价值", "价值评分为 4–5 的文章"],
    subscriptions: ["订阅", "公众号来源与抓取状态"],
  };

  const $ = (selector) => document.querySelector(selector);
  const elements = {
    app: $("#app"),
    tabList: $("#tab-list"),
    sourceList: $("#source-list"),
    sourceSearch: $("#source-search"),
    timeline: $("#timeline"),
    timelineTitle: $("#timeline-title"),
    timelineSubtitle: $("#timeline-subtitle"),
    timelineBack: $("#timeline-back"),
    refresh: $("#refresh"),
    readerEmpty: $("#reader-empty"),
    readerContent: $("#reader-content"),
    readerTitle: $("#reader-title"),
    readerMeta: $("#reader-meta"),
    readerRead: $("#reader-read"),
    readerStar: $("#reader-star"),
    readerBack: $("#reader-back"),
    articleFrame: $("#article-frame"),
    ratingControl: $("#rating-control"),
    topicList: $("#topic-list"),
    topicForm: $("#topic-form"),
    topicInput: $("#topic-input"),
    subscriptionDetail: $("#subscription-detail"),
    statusGenerated: $("#status-generated"),
    statusLatest: $("#status-latest"),
    statusFeeds: $("#status-feeds"),
    statusHealth: $("#status-health"),
    syncBrief: $("#sync-brief"),
    healthDot: $("#health-dot"),
    healthText: $("#health-text"),
    addFeed: $("#add-feed"),
    subscriptionAdd: $("#subscription-add"),
    feedDialog: $("#feed-dialog"),
    toast: $("#toast"),
  };

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function icon(name) {
    return `<svg aria-hidden="true"><use href="#i-${name}"></use></svg>`;
  }

  function showToast(message, isError = false) {
    elements.toast.textContent = message;
    elements.toast.style.background = isError ? "#7b2923" : "#242320";
    elements.toast.classList.add("is-visible");
    window.clearTimeout(showToast.timer);
    showToast.timer = window.setTimeout(() => elements.toast.classList.remove("is-visible"), 2600);
  }

  async function request(path, options = {}) {
    const response = await fetch(path, {
      credentials: "same-origin",
      cache: "no-store",
      ...options,
      headers: {
        Accept: "application/json",
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...(options.headers || {}),
      },
    });
    if (response.status === 401 || response.status === 403) {
      throw new Error("当前会话没有 Reader 访问权限，请重新完成 Cloudflare 邮箱验证。");
    }
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 240);
      throw new Error(`Reader 请求失败（${response.status}）${detail ? `：${detail}` : ""}`);
    }
    if (response.status === 204) return null;
    const type = response.headers.get("content-type") || "";
    return type.includes("json") ? response.json() : response.text();
  }

  async function fetchPaged(path) {
    const result = [];
    let offset = 0;
    while (true) {
      const join = path.includes("?") ? "&" : "?";
      const items = await request(`${path}${join}limit=100&offset=${offset}`);
      result.push(...(items || []));
      if (!items || items.length < 100) break;
      offset += items.length;
    }
    return result;
  }

  function sourceName(bookmark) {
    const label = (bookmark.labels || []).find((item) => item.startsWith("公众号/"));
    return label ? label.slice(4) : bookmark.site_name || "未知公众号";
  }

  function valueOf(bookmark) {
    const label = (bookmark.labels || []).find((item) => /^价值\/[1-5]$/.test(item));
    return label ? Number(label.slice(3)) : 0;
  }

  function topicsOf(bookmark) {
    return (bookmark.labels || []).filter((item) => item.startsWith("主题/")).map((item) => item.slice(3));
  }

  function readState(bookmark) {
    const progress = Number(bookmark.read_progress || 0);
    if (progress >= 100) return "read";
    if (progress > 0) return "reading";
    return "unread";
  }

  function shortTime(value) {
    if (!value) return "时间未知";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "时间未知";
    const seconds = Math.max(0, (Date.now() - date.getTime()) / 1000);
    if (seconds < 60) return "刚刚";
    if (seconds < 3600) return `${Math.floor(seconds / 60)} 分钟`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} 小时`;
    if (seconds < 86400 * 7) return `${Math.floor(seconds / 86400)} 天`;
    return new Intl.DateTimeFormat("zh-CN", { month: "numeric", day: "numeric" }).format(date);
  }

  function fullTime(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return new Intl.DateTimeFormat("zh-CN", {
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(date);
  }

  function selectedBookmark() {
    return state.bookmarks.find((item) => item.id === state.selectedId) || null;
  }

  function counts() {
    return {
      inbox: state.bookmarks.length,
      unread: state.bookmarks.filter((item) => Number(item.read_progress || 0) < 100).length,
      favorites: state.bookmarks.filter((item) => item.is_marked).length,
      highlights: state.bookmarks.filter((item) => state.annotatedIds.has(item.id)).length,
      valuable: state.bookmarks.filter((item) => valueOf(item) >= 4).length,
      subscriptions: sourceCatalog().length,
    };
  }

  function sourceCatalog() {
    const byName = new Map();
    for (const feed of state.status?.feeds || []) {
      byName.set(feed.name, {
        name: feed.name,
        articles: Number(feed.readeck_articles ?? feed.complete_articles ?? feed.articles ?? 0),
        unread: Number(feed.unread || 0),
        latest: feed.latest_fetched_at || feed.latest_published_at || "",
        health: feed.health || "正常",
      });
    }
    for (const bookmark of state.bookmarks) {
      const name = sourceName(bookmark);
      const item = byName.get(name) || { name, articles: 0, unread: 0, latest: "", health: "正常" };
      if (!(state.status?.feeds || []).some((feed) => feed.name === name)) {
        item.articles += 1;
        if (Number(bookmark.read_progress || 0) < 100) item.unread += 1;
        const published = bookmark.published || bookmark.created || "";
        if (!item.latest || new Date(published) > new Date(item.latest)) item.latest = published;
      }
      byName.set(name, item);
    }
    return [...byName.values()].sort((a, b) => a.name.localeCompare(b.name, "zh-CN"));
  }

  function renderTabs() {
    const currentCounts = counts();
    for (const button of elements.tabList.querySelectorAll("button[data-tab]")) {
      const tab = button.dataset.tab;
      button.toggleAttribute("aria-current", tab === state.activeTab);
      if (tab === state.activeTab) button.setAttribute("aria-current", "page");
      const count = button.querySelector("b");
      count.textContent = String(currentCounts[tab] || 0);
    }
  }

  function renderSources() {
    const catalog = sourceCatalog().filter((item) => item.name.toLowerCase().includes(state.sourceQuery.toLowerCase()));
    const totalUnread = state.bookmarks.filter((item) => Number(item.read_progress || 0) < 100).length;
    const rows = [
      `<button class="source-item" type="button" data-source="" aria-current="${state.activeSource === ""}">
        <span class="source-avatar">全</span><span class="source-name">全部公众号</span><span class="source-count">${totalUnread}</span>
      </button>`,
      ...catalog.map((item) => `<button class="source-item" type="button" data-source="${escapeHtml(item.name)}" aria-current="${state.activeSource === item.name}">
        <span class="source-avatar">${escapeHtml(item.name.trim().slice(0, 1) || "公")}</span>
        <span class="source-name">${escapeHtml(item.name)}</span><span class="source-count">${item.unread}</span>
      </button>`),
    ];
    elements.sourceList.innerHTML = rows.join("");
    for (const button of elements.sourceList.querySelectorAll("[data-source]")) {
      button.addEventListener("click", () => {
        state.activeSource = button.dataset.source || "";
        if (state.activeTab === "subscriptions") state.activeTab = "inbox";
        elements.app.dataset.mobileView = "timeline";
        render();
      });
    }
  }

  function filteredBookmarks() {
    const sourceFiltered = state.activeSource
      ? state.bookmarks.filter((item) => sourceName(item) === state.activeSource)
      : state.bookmarks;
    switch (state.activeTab) {
      case "unread": return sourceFiltered.filter((item) => Number(item.read_progress || 0) < 100);
      case "favorites": return sourceFiltered.filter((item) => item.is_marked);
      case "highlights": return sourceFiltered.filter((item) => state.annotatedIds.has(item.id));
      case "valuable": return sourceFiltered.filter((item) => valueOf(item) >= 4);
      default: return sourceFiltered;
    }
  }

  function entryRow(bookmark) {
    const value = valueOf(bookmark);
    const topics = topicsOf(bookmark);
    const labels = [
      ...(value ? [`<span class="chip value">价值 ${value}</span>`] : []),
      ...topics.slice(0, 2).map((topic) => `<span class="chip">${escapeHtml(topic)}</span>`),
    ].join("");
    const stateName = readState(bookmark);
    const published = bookmark.published || bookmark.created;
    return `<article class="entry-row is-${stateName}" data-id="${bookmark.id}" tabindex="0" aria-current="${state.selectedId === bookmark.id}">
      <span class="entry-status"><i class="unread-dot" title="${stateName === "read" ? "已读" : stateName === "reading" ? `阅读 ${bookmark.read_progress}%` : "未读"}"></i></span>
      <div class="entry-body">
        <div class="entry-meta"><span class="entry-source">${escapeHtml(sourceName(bookmark))}</span><span class="entry-time">${shortTime(published)}</span></div>
        <h2 class="entry-title">${escapeHtml(bookmark.title || "未命名文章")}</h2>
        <p class="entry-description">${escapeHtml(bookmark.description || "暂无摘要")}</p>
        <div class="entry-labels">${labels}</div>
      </div>
      <div class="entry-actions"><button class="star-action ${bookmark.is_marked ? "is-active" : ""}" type="button" data-star="${bookmark.id}" aria-label="${bookmark.is_marked ? "取消收藏" : "收藏"}">${icon("star")}</button></div>
    </article>`;
  }

  function subscriptionRows() {
    const catalog = sourceCatalog();
    if (!catalog.length) return `<div class="empty-list">尚未读取到公众号状态。</div>`;
    return catalog.map((feed) => `<article class="subscription-row" data-feed="${escapeHtml(feed.name)}">
      <span class="source-avatar">${escapeHtml(feed.name.trim().slice(0, 1) || "公")}</span>
      <div><strong>${escapeHtml(feed.name)}</strong><p>最近抓取 ${fullTime(feed.latest)} · ${escapeHtml(feed.health)}</p></div>
      <div class="subscription-stats"><b>${feed.articles} 篇</b>${feed.unread} 未读</div>
    </article>`).join("");
  }

  function bindTimelineRows() {
    for (const row of elements.timeline.querySelectorAll(".entry-row")) {
      const open = () => selectBookmark(row.dataset.id);
      row.addEventListener("click", (event) => {
        if (!event.target.closest("[data-star]")) open();
      });
      row.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          open();
        }
      });
    }
    for (const button of elements.timeline.querySelectorAll("[data-star]")) {
      button.addEventListener("click", (event) => {
        event.stopPropagation();
        toggleFavorite(button.dataset.star);
      });
    }
    for (const row of elements.timeline.querySelectorAll("[data-feed]")) {
      row.addEventListener("click", () => {
        state.activeSource = row.dataset.feed;
        state.activeTab = "inbox";
        elements.app.dataset.mobileView = "timeline";
        render();
      });
    }
  }

  function renderTimeline() {
    const [title, subtitle] = tabMeta[state.activeTab];
    elements.timelineTitle.textContent = state.activeSource && state.activeTab !== "subscriptions" ? state.activeSource : title;
    elements.timelineSubtitle.textContent = state.activeSource && state.activeTab !== "subscriptions" ? `${filteredBookmarks().length} 篇 · ${subtitle}` : subtitle;
    if (state.loading) {
      elements.timeline.innerHTML = `<div class="loading-list">正在同步文章状态…</div>`;
      return;
    }
    if (state.activeTab === "subscriptions") {
      elements.timeline.innerHTML = subscriptionRows();
      bindTimelineRows();
      return;
    }
    const bookmarks = filteredBookmarks();
    elements.timeline.innerHTML = bookmarks.length
      ? bookmarks.map(entryRow).join("")
      : `<div class="empty-list">这个视图暂时没有文章。</div>`;
    bindTimelineRows();
  }

  function renderRating(bookmark) {
    const current = valueOf(bookmark);
    elements.ratingControl.innerHTML = [1, 2, 3, 4, 5].map((value) => `<button type="button" role="radio" aria-checked="${current === value}" data-rating="${value}" title="价值 ${value}">${value}</button>`).join("");
    for (const button of elements.ratingControl.querySelectorAll("[data-rating]")) {
      button.addEventListener("click", () => setRating(Number(button.dataset.rating)));
    }
  }

  function renderTopics(bookmark) {
    const topics = topicsOf(bookmark);
    elements.topicList.innerHTML = topics.map((topic) => `<span class="topic-chip">${escapeHtml(topic)}<button type="button" data-remove-topic="${escapeHtml(topic)}" aria-label="删除主题 ${escapeHtml(topic)}">×</button></span>`).join("");
    for (const button of elements.topicList.querySelectorAll("[data-remove-topic]")) {
      button.addEventListener("click", () => removeTopic(button.dataset.removeTopic));
    }
  }

  function renderReader() {
    const bookmark = selectedBookmark();
    const subscriptions = state.activeTab === "subscriptions";
    elements.subscriptionDetail.hidden = !subscriptions;
    if (subscriptions) {
      elements.readerEmpty.hidden = true;
      elements.readerContent.hidden = true;
      renderSubscriptionStatus();
      return;
    }
    elements.readerEmpty.hidden = Boolean(bookmark);
    elements.readerContent.hidden = !bookmark;
    if (!bookmark) return;

    elements.readerTitle.textContent = bookmark.title || "未命名文章";
    elements.readerMeta.textContent = `${sourceName(bookmark)} · ${shortTime(bookmark.published || bookmark.created)} · ${bookmark.read_progress || 0}%`;
    elements.readerStar.classList.toggle("is-active", Boolean(bookmark.is_marked));
    elements.readerStar.querySelector("span").textContent = bookmark.is_marked ? "已收藏" : "收藏";
    const isRead = Number(bookmark.read_progress || 0) >= 100;
    elements.readerRead.querySelector("span").textContent = isRead ? "标为未读" : "标为已读";
    renderRating(bookmark);
    renderTopics(bookmark);
  }

  function renderSubscriptionStatus() {
    const status = state.status;
    elements.statusGenerated.textContent = fullTime(status?.generated_at);
    elements.statusLatest.textContent = fullTime(status?.latest_fetched_at);
    elements.statusFeeds.textContent = `${sourceCatalog().length} 个公众号`;
    elements.statusHealth.textContent = status?.health === "ok" ? "运行正常" : status ? "需要检查" : "等待状态";
  }

  function renderHealth() {
    const ok = state.status?.health === "ok";
    elements.healthDot.className = `health-dot ${ok ? "ok" : state.status ? "error" : ""}`;
    elements.healthText.textContent = ok ? "抓取与同步运行正常" : state.status ? "同步状态需要检查" : "未读取到抓取状态";
    elements.syncBrief.textContent = state.status
      ? `抓取 ${state.status.cron || "17 * * * *"} · 同步 ${state.status.sync_interval_seconds || 300} 秒`
      : "每小时抓取 · 5 分钟同步";
  }

  function render() {
    renderTabs();
    renderSources();
    renderTimeline();
    renderReader();
    renderHealth();
  }

  async function refreshAnnotations() {
    const annotations = await fetchPaged("/api/bookmarks/annotations?");
    state.annotations = annotations;
    state.annotatedIds = new Set(annotations.map((item) => item.bookmark_id));
    renderTabs();
    if (state.activeTab === "highlights") renderTimeline();
  }

  async function refreshData({ quiet = false } = {}) {
    if (state.loading) return;
    state.loading = true;
    elements.refresh.classList.add("is-loading");
    if (!quiet) renderTimeline();
    try {
      const [bookmarks, annotations, status] = await Promise.all([
        fetchPaged("/api/bookmarks?sort=-published"),
        fetchPaged("/api/bookmarks/annotations?"),
        fetch("/reader-runtime/status.json", { credentials: "same-origin", cache: "no-store" }).then((response) => response.ok ? response.json() : null).catch(() => null),
      ]);
      state.bookmarks = bookmarks;
      state.annotations = annotations;
      state.annotatedIds = new Set(annotations.map((item) => item.bookmark_id));
      state.status = status;
      if (state.selectedId && !selectedBookmark()) state.selectedId = "";
      if (!quiet) showToast(`已刷新 ${bookmarks.length} 篇文章`);
    } catch (error) {
      showToast(error.message || "刷新失败", true);
      elements.timeline.innerHTML = `<div class="empty-list">${escapeHtml(error.message || "无法读取 Reader")}</div>`;
    } finally {
      state.loading = false;
      elements.refresh.classList.remove("is-loading");
      render();
    }
  }

  async function patchBookmark(id, payload) {
    const updated = await request(`/api/bookmarks/${id}`, { method: "PATCH", body: JSON.stringify(payload) });
    const index = state.bookmarks.findIndex((item) => item.id === id);
    if (index >= 0) state.bookmarks[index] = { ...state.bookmarks[index], ...(updated || {}), ...payload };
    render();
    return state.bookmarks[index];
  }

  async function toggleFavorite(id = state.selectedId) {
    const bookmark = state.bookmarks.find((item) => item.id === id);
    if (!bookmark) return;
    const previous = Boolean(bookmark.is_marked);
    bookmark.is_marked = !previous;
    render();
    try {
      await patchBookmark(id, { is_marked: !previous });
      showToast(!previous ? "已收藏，后续会同步到 Obsidian" : "已取消收藏");
    } catch (error) {
      bookmark.is_marked = previous;
      render();
      showToast(error.message || "收藏失败", true);
    }
  }

  async function setReadProgress(id, progress, quiet = false) {
    const bookmark = state.bookmarks.find((item) => item.id === id);
    if (!bookmark) return;
    const previous = Number(bookmark.read_progress || 0);
    if (previous === progress) return;
    bookmark.read_progress = progress;
    renderTabs();
    renderSources();
    renderTimeline();
    renderReader();
    try {
      await patchBookmark(id, { read_progress: progress });
      if (!quiet) showToast(progress >= 100 ? "已标为已读" : progress === 0 ? "已标为未读" : `阅读进度 ${progress}%`);
    } catch (error) {
      bookmark.read_progress = previous;
      render();
      showToast(error.message || "阅读状态保存失败", true);
    }
  }

  async function setRating(value) {
    const bookmark = selectedBookmark();
    if (!bookmark) return;
    const labels = (bookmark.labels || []).filter((label) => !/^价值\/[1-5]$/.test(label));
    const current = valueOf(bookmark);
    if (current !== value) labels.push(`价值/${value}`);
    try {
      await patchBookmark(bookmark.id, { labels });
      showToast(current === value ? "已清除价值评分" : `价值评分已设为 ${value}`);
    } catch (error) {
      showToast(error.message || "价值评分保存失败", true);
      await refreshData({ quiet: true });
    }
  }

  async function addTopic(topic) {
    const bookmark = selectedBookmark();
    const cleaned = String(topic || "").trim().replaceAll("/", "-");
    if (!bookmark || !cleaned) return;
    if (topicsOf(bookmark).includes(cleaned)) {
      showToast("这个主题已经存在");
      return;
    }
    const labels = [...(bookmark.labels || []), `主题/${cleaned}`];
    try {
      await patchBookmark(bookmark.id, { labels });
      elements.topicInput.value = "";
      showToast(`已添加主题：${cleaned}`);
    } catch (error) {
      showToast(error.message || "主题保存失败", true);
      await refreshData({ quiet: true });
    }
  }

  async function removeTopic(topic) {
    const bookmark = selectedBookmark();
    if (!bookmark) return;
    const labels = (bookmark.labels || []).filter((label) => label !== `主题/${topic}`);
    try {
      await patchBookmark(bookmark.id, { labels });
      showToast(`已移除主题：${topic}`);
    } catch (error) {
      showToast(error.message || "主题移除失败", true);
      await refreshData({ quiet: true });
    }
  }

  function selectBookmark(id) {
    if (!state.bookmarks.some((item) => item.id === id)) return;
    state.selectedId = id;
    elements.app.dataset.mobileView = "reader";
    render();
    if (!elements.articleFrame.src.includes(`/bookmarks/${id}?reader=1`)) {
      elements.articleFrame.src = `/bookmarks/${id}?reader=1`;
    }
  }

  function bindArticleFrame() {
    elements.articleFrame.addEventListener("load", () => {
      const bookmark = selectedBookmark();
      if (!bookmark) return;
      try {
        const doc = elements.articleFrame.contentDocument;
        const frameWindow = elements.articleFrame.contentWindow;
        if (!doc || !frameWindow) return;
        doc.documentElement.classList.add("reader-embed", "dark");
        if (!doc.querySelector("link[data-reader-embed-theme]")) {
          const embedTheme = doc.createElement("link");
          embedTheme.rel = "stylesheet";
          embedTheme.href = "/reader-assets/embed.css?v=1";
          embedTheme.dataset.readerEmbedTheme = "true";
          doc.head.append(embedTheme);
        }
        state.annotationObserver?.disconnect();
        state.annotationObserver = new MutationObserver((records) => {
          if (!records.some((record) => [...record.addedNodes, ...record.removedNodes].some((node) => node.nodeType === 1 && (node.matches?.("rd-annotation, .rd-annotation") || node.querySelector?.("rd-annotation, .rd-annotation"))))) return;
          window.clearTimeout(state.annotationTimer);
          state.annotationTimer = window.setTimeout(() => refreshAnnotations().catch(() => {}), 600);
        });
        state.annotationObserver.observe(doc.body, { childList: true, subtree: true });

        let lastProgress = Number(bookmark.read_progress || 0);
        const updateProgress = () => {
          const current = selectedBookmark();
          if (!current || current.id !== bookmark.id) return;
          const root = doc.scrollingElement || doc.documentElement;
          const maxScroll = Math.max(1, root.scrollHeight - root.clientHeight);
          const ratio = Math.min(1, Math.max(0, root.scrollTop / maxScroll));
          let next = Math.min(99, Math.max(1, Math.round(ratio * 100)));
          if (ratio >= 0.8) next = 100;
          if (ratio < 0.03 && Number(current.read_progress || 0) === 0) return;
          if (next < 100 && Math.abs(next - lastProgress) < 10) return;
          lastProgress = next;
          window.clearTimeout(state.progressTimer);
          state.progressTimer = window.setTimeout(() => setReadProgress(bookmark.id, next, true), 900);
        };
        frameWindow.addEventListener("scroll", updateProgress, { passive: true });
      } catch (error) {
        showToast("正文已打开，但无法读取内嵌阅读进度", true);
      }
    });
  }

  function switchTab(tab) {
    if (!tabMeta[tab]) return;
    state.activeTab = tab;
    if (tab === "subscriptions") {
      elements.app.dataset.mobileView = "reader";
    } else if (window.matchMedia("(max-width: 760px)").matches) {
      elements.app.dataset.mobileView = "timeline";
    }
    render();
  }

  function bindEvents() {
    elements.tabList.addEventListener("click", (event) => {
      const button = event.target.closest("[data-tab]");
      if (button) switchTab(button.dataset.tab);
    });
    elements.sourceSearch.addEventListener("input", () => {
      state.sourceQuery = elements.sourceSearch.value.trim();
      renderSources();
    });
    elements.refresh.addEventListener("click", () => refreshData());
    elements.readerStar.addEventListener("click", () => toggleFavorite());
    elements.readerRead.addEventListener("click", () => {
      const bookmark = selectedBookmark();
      if (bookmark) setReadProgress(bookmark.id, Number(bookmark.read_progress || 0) >= 100 ? 0 : 100);
    });
    elements.topicForm.addEventListener("submit", (event) => {
      event.preventDefault();
      addTopic(elements.topicInput.value);
    });
    elements.readerBack.addEventListener("click", () => { elements.app.dataset.mobileView = "timeline"; });
    elements.timelineBack.addEventListener("click", () => { elements.app.dataset.mobileView = "sources"; });
    for (const button of [elements.addFeed, elements.subscriptionAdd]) {
      button.addEventListener("click", () => elements.feedDialog.showModal());
    }
    document.addEventListener("keydown", (event) => {
      const editable = event.target.matches?.("input, textarea, [contenteditable='true']");
      if (editable) return;
      if (/^[1-6]$/.test(event.key)) {
        const tab = Object.keys(tabMeta)[Number(event.key) - 1];
        switchTab(tab);
        return;
      }
      if (event.key.toLowerCase() === "s" && state.selectedId) {
        event.preventDefault();
        toggleFavorite();
      }
      if (["j", "k"].includes(event.key.toLowerCase())) {
        const rows = filteredBookmarks();
        if (!rows.length) return;
        const index = rows.findIndex((item) => item.id === state.selectedId);
        const delta = event.key.toLowerCase() === "j" ? 1 : -1;
        const next = rows[Math.max(0, Math.min(rows.length - 1, index < 0 ? 0 : index + delta))];
        if (next) selectBookmark(next.id);
      }
    });
    bindArticleFrame();
  }

  bindEvents();
  render();
  refreshData();
})();
