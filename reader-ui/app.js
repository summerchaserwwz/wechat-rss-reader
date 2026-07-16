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
    refreshControl: {
      phase: "idle",
      message: "可以检查新文章",
      new_articles: 0,
      last_werss_fetch_at: "",
      last_sync_at: "",
      next_allowed_at: "",
    },
    refreshPollTimer: 0,
    refreshGeneration: 0,
    progressTimer: 0,
    progressStartTimer: 0,
    annotationTimer: 0,
    annotationObserver: null,
    pendingAnnotationId: "",
    lastSelectionRect: null,
    fontSize: 17,
    exportDirectoryHandle: null,
  };

  const tabMeta = {
    inbox: ["收件箱", "按发布时间排列"],
    unread: ["未读", "还没有读完的文章"],
    favorites: ["收藏", "准备继续处理的文章"],
    highlights: ["划线笔记", "摘录、批注与来源"],
    valuable: ["高价值", "价值评分为 4-5 的文章"],
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
    notesActions: $("#notes-actions"),
    notesDownload: $("#notes-download"),
    notesFolder: $("#notes-folder"),
    refresh: $("#refresh"),
    refreshLabel: $("#refresh-label"),
    refreshSummary: $("#refresh-summary"),
    refreshDetail: $("#refresh-detail"),
    readerEmpty: $("#reader-empty"),
    readerContent: $("#reader-content"),
    readerTitle: $("#reader-title"),
    readerMeta: $("#reader-meta"),
    readerRead: $("#reader-read"),
    readerStar: $("#reader-star"),
    readerBack: $("#reader-back"),
    readerAutoStatus: $("#reader-auto-status"),
    articleFrame: $("#article-frame"),
    fontLarger: $("#font-larger"),
    fontSmaller: $("#font-smaller"),
    fontSize: $("#font-size"),
    articleNotes: $("#article-notes"),
    ratingControl: $("#rating-control"),
    topicList: $("#topic-list"),
    topicForm: $("#topic-form"),
    topicInput: $("#topic-input"),
    subscriptionDetail: $("#subscription-detail"),
    statusGenerated: $("#status-generated"),
    statusLatest: $("#status-latest"),
    statusFeeds: $("#status-feeds"),
    statusHealth: $("#status-health"),
    statusRefreshResult: $("#status-refresh-result"),
    statusNextRefresh: $("#status-next-refresh"),
    syncBrief: $("#sync-brief"),
    healthDot: $("#health-dot"),
    healthText: $("#health-text"),
    addFeed: $("#add-feed"),
    subscriptionAdd: $("#subscription-add"),
    feedDialog: $("#feed-dialog"),
    feedDeviceNote: $("#feed-device-note"),
    feedPublicLink: $("#feed-public-link"),
    feedLocalLink: $("#feed-local-link"),
    exportDialog: $("#export-dialog"),
    exportFolderLabel: $("#export-folder-label"),
    chooseExportFolder: $("#choose-export-folder"),
    exportToFolder: $("#export-to-folder"),
    forgetExportFolder: $("#forget-export-folder"),
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
      throw new Error("当前会话没有阅读库访问权限，请重新完成 Cloudflare 邮箱验证。");
    }
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 240);
      throw new Error(`阅读库请求失败（${response.status}）${detail ? `：${detail}` : ""}`);
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
    if (!value) return "暂无";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "暂无";
    return new Intl.DateTimeFormat("zh-CN", {
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(date);
  }

  function cooldownText(value) {
    if (!value) return "现在可以";
    const date = new Date(value);
    if (Number.isNaN(date.getTime()) || date.getTime() <= Date.now()) return "现在可以";
    const seconds = Math.max(1, Math.ceil((date.getTime() - Date.now()) / 1000));
    if (seconds < 60) return `${seconds} 秒后`;
    return `${Math.ceil(seconds / 60)} 分钟后`;
  }

  function scheduleText(cron, intervalSeconds) {
    const parts = String(cron || "").trim().split(/\s+/);
    let fetchText = "定时抓取";
    if (parts.length === 5 && /^\d+$/.test(parts[0])) {
      if (parts[1] === "*") fetchText = `每小时第 ${parts[0]} 分钟抓取`;
      else if (/^\*\/\d+$/.test(parts[1])) fetchText = `每 ${parts[1].slice(2)} 小时第 ${parts[0]} 分钟抓取`;
    }
    const seconds = Number(intervalSeconds || 300);
    const syncText = seconds >= 60 && seconds % 60 === 0 ? `约 ${seconds / 60} 分钟同步` : `约 ${seconds} 秒同步`;
    return `${fetchText} · ${syncText}`;
  }

  function annotationsFor(bookmarkId) {
    return state.annotations.filter((item) => item.bookmark_id === bookmarkId);
  }

  function annotationById(id) {
    return state.annotations.find((item) => String(item.id) === String(id)) || null;
  }

  function annotationSource(item) {
    const bookmark = state.bookmarks.find((entry) => entry.id === item.bookmark_id);
    return bookmark ? sourceName(bookmark) : item.bookmark_site_name || "未知公众号";
  }

  function markdownEscape(value) {
    return String(value || "").replaceAll("\r", "").trim();
  }

  function buildAnnotationsMarkdown(items = state.annotations) {
    const created = new Intl.DateTimeFormat("zh-CN", { dateStyle: "long", timeStyle: "short" }).format(new Date());
    const sections = items.map((item, index) => {
      const bookmark = state.bookmarks.find((entry) => entry.id === item.bookmark_id);
      const title = bookmark?.title || item.bookmark_title || "未命名文章";
      const url = bookmark?.url || item.bookmark_url || "";
      const source = annotationSource(item);
      const quote = markdownEscape(item.text).split("\n").map((line) => `> ${line}`).join("\n");
      const note = markdownEscape(item.note) || "（未填写笔记）";
      return `## ${index + 1}. ${title}\n\n- 公众号：${source}\n- 原文：${url ? `[${url}](${url})` : "暂无"}\n- 划线时间：${fullTime(item.created)}\n\n${quote}\n\n**我的笔记**\n\n${note}`;
    });
    return `# 公众号划线笔记\n\n- 导出时间：${created}\n- 共 ${items.length} 条摘录\n\n${sections.join("\n\n---\n\n")}\n`;
  }

  function markdownFilename() {
    const date = new Intl.DateTimeFormat("sv-SE", { year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
    return `公众号划线笔记-${date}.md`;
  }

  function downloadMarkdown() {
    if (!state.annotations.length) {
      showToast("还没有划线笔记");
      return;
    }
    const blob = new Blob([buildAnnotationsMarkdown()], { type: "text/markdown;charset=utf-8" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = markdownFilename();
    link.click();
    window.setTimeout(() => URL.revokeObjectURL(link.href), 1000);
    showToast(`已导出 ${state.annotations.length} 条划线笔记`);
  }

  function openSettingsDb() {
    return new Promise((resolve, reject) => {
      const requestDb = indexedDB.open("wechat-reader-settings", 1);
      requestDb.onupgradeneeded = () => requestDb.result.createObjectStore("settings");
      requestDb.onsuccess = () => resolve(requestDb.result);
      requestDb.onerror = () => reject(requestDb.error);
    });
  }

  async function saveDirectoryHandle(handle) {
    const db = await openSettingsDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction("settings", "readwrite");
      tx.objectStore("settings").put(handle, "obsidian-directory");
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  }

  async function loadDirectoryHandle() {
    if (!("indexedDB" in window)) return;
    try {
      const db = await openSettingsDb();
      state.exportDirectoryHandle = await new Promise((resolve, reject) => {
        const tx = db.transaction("settings", "readonly");
        const requestHandle = tx.objectStore("settings").get("obsidian-directory");
        requestHandle.onsuccess = () => resolve(requestHandle.result || null);
        requestHandle.onerror = () => reject(requestHandle.error);
      });
      db.close();
      renderExportTarget();
    } catch {
      state.exportDirectoryHandle = null;
    }
  }

  async function forgetDirectoryHandle() {
    const db = await openSettingsDb();
    await new Promise((resolve, reject) => {
      const tx = db.transaction("settings", "readwrite");
      tx.objectStore("settings").delete("obsidian-directory");
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
    state.exportDirectoryHandle = null;
    renderExportTarget();
    showToast("已清除浏览器导出目录");
  }

  function renderExportTarget() {
    const supported = "showDirectoryPicker" in window;
    elements.exportFolderLabel.textContent = state.exportDirectoryHandle?.name || (supported ? "尚未选择" : "此浏览器不支持直写目录");
    elements.chooseExportFolder.disabled = !supported;
    elements.exportToFolder.disabled = !state.exportDirectoryHandle;
    elements.forgetExportFolder.disabled = !state.exportDirectoryHandle;
  }

  async function chooseExportDirectory() {
    if (!("showDirectoryPicker" in window)) {
      showToast("当前浏览器不支持选择目录，请使用 Markdown 下载", true);
      return;
    }
    try {
      const handle = await window.showDirectoryPicker({ mode: "readwrite", startIn: "documents" });
      state.exportDirectoryHandle = handle;
      await saveDirectoryHandle(handle);
      renderExportTarget();
      showToast(`已选择目录：${handle.name}`);
    } catch (error) {
      if (error?.name !== "AbortError") showToast("无法保存所选目录", true);
    }
  }

  async function exportToDirectory() {
    const handle = state.exportDirectoryHandle;
    if (!handle) {
      await chooseExportDirectory();
      if (!state.exportDirectoryHandle) return;
    }
    if (!state.annotations.length) {
      showToast("还没有划线笔记");
      return;
    }
    try {
      const permission = await state.exportDirectoryHandle.requestPermission({ mode: "readwrite" });
      if (permission !== "granted") throw new Error("目录写入权限未授予");
      const file = await state.exportDirectoryHandle.getFileHandle(markdownFilename(), { create: true });
      const writer = await file.createWritable();
      await writer.write(buildAnnotationsMarkdown());
      await writer.close();
      showToast(`已写入 ${state.exportDirectoryHandle.name}`);
    } catch (error) {
      showToast(error.message || "导出到 Obsidian 目录失败", true);
    }
  }

  function selectedBookmark() {
    return state.bookmarks.find((item) => item.id === state.selectedId) || null;
  }

  function counts() {
    return {
      inbox: state.bookmarks.length,
      unread: state.bookmarks.filter((item) => Number(item.read_progress || 0) < 100).length,
      favorites: state.bookmarks.filter((item) => item.is_marked).length,
      highlights: state.annotations.length,
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

  function filteredAnnotations() {
    return state.annotations
      .filter((item) => !state.activeSource || annotationSource(item) === state.activeSource)
      .sort((a, b) => new Date(b.created || 0) - new Date(a.created || 0));
  }

  function annotationRow(item) {
    const note = markdownEscape(item.note);
    return `<article class="annotation-row" data-bookmark-id="${escapeHtml(item.bookmark_id)}" data-annotation-id="${escapeHtml(item.id)}" tabindex="0">
      <div class="annotation-row-meta"><span>${escapeHtml(annotationSource(item))}</span><time>${shortTime(item.created)}</time></div>
      <blockquote>${escapeHtml(markdownEscape(item.text) || "空摘录")}</blockquote>
      <p class="annotation-row-note ${note ? "" : "is-empty"}">${escapeHtml(note || "尚未写笔记，点击回到原文补充")}</p>
      <span class="annotation-row-source">${escapeHtml(item.bookmark_title || "查看原文")}</span>
    </article>`;
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
    for (const row of elements.timeline.querySelectorAll(".annotation-row")) {
      const open = () => selectAnnotation(row.dataset.bookmarkId, row.dataset.annotationId);
      row.addEventListener("click", open);
      row.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          open();
        }
      });
    }
  }

  function renderTimeline() {
    const [title, subtitle] = tabMeta[state.activeTab];
    elements.notesActions.hidden = state.activeTab !== "highlights";
    elements.timelineTitle.textContent = state.activeSource && state.activeTab !== "subscriptions" ? state.activeSource : title;
    const activeCount = state.activeTab === "highlights" ? filteredAnnotations().length : filteredBookmarks().length;
    elements.timelineSubtitle.textContent = state.activeSource && state.activeTab !== "subscriptions" ? `${activeCount} 条 · ${subtitle}` : subtitle;
    if (state.loading) {
      elements.timeline.innerHTML = `<div class="loading-list">正在同步文章状态…</div>`;
      return;
    }
    if (state.activeTab === "subscriptions") {
      elements.timeline.innerHTML = subscriptionRows();
      bindTimelineRows();
      return;
    }
    if (state.activeTab === "highlights") {
      const annotations = filteredAnnotations();
      elements.timeline.innerHTML = annotations.length
        ? `<div class="annotation-library-intro"><strong>自动收集的划线笔记</strong><span>点击任意摘录回到原文；每 5 分钟自动同步到 Obsidian。</span></div>${annotations.map(annotationRow).join("")}`
        : `<div class="empty-list">选中文字写下笔记后，会自动出现在这里。</div>`;
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

  function renderFontSize() {
    elements.fontSize.value = String(state.fontSize);
    elements.fontSize.textContent = `${state.fontSize}px`;
    elements.fontSmaller.disabled = state.fontSize <= 15;
    elements.fontLarger.disabled = state.fontSize >= 24;
    try {
      elements.articleFrame.contentDocument?.documentElement.style.setProperty("--reader-font-size", `${state.fontSize}px`);
    } catch {
      // The next same-origin frame load applies the preference.
    }
  }

  function setFontSize(value) {
    state.fontSize = Math.max(15, Math.min(24, Number(value) || 17));
    localStorage.setItem("reader-font-size", String(state.fontSize));
    renderFontSize();
    showToast(`正文字号 ${state.fontSize}px`);
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
    const progress = Number(bookmark.read_progress || 0);
    elements.readerAutoStatus.textContent = progress >= 100 ? "已自动记录 · 已读" : progress > 0 ? `自动记录 · ${progress}%` : "自动记录 · 未读";
    const noteCount = annotationsFor(bookmark.id).length;
    elements.articleNotes.querySelector("b").textContent = String(noteCount);
    elements.articleNotes.classList.toggle("has-notes", noteCount > 0);
    renderRating(bookmark);
    renderTopics(bookmark);
    renderFontSize();
  }

  function renderSubscriptionStatus() {
    const status = state.status;
    const refresh = state.refreshControl;
    elements.statusGenerated.textContent = fullTime(status?.generated_at);
    elements.statusLatest.textContent = fullTime(status?.latest_fetched_at);
    elements.statusFeeds.textContent = `${sourceCatalog().length} 个公众号`;
    elements.statusHealth.textContent = status?.health === "ok" ? "运行正常" : status ? "需要检查" : "等待状态";
    elements.statusRefreshResult.textContent = refresh.phase === "complete"
      ? `新增 ${Number(refresh.new_articles || 0)} 篇`
      : refresh.message || "尚未主动检查";
    elements.statusNextRefresh.textContent = cooldownText(refresh.next_allowed_at);
  }

  function renderRefreshControl() {
    const refresh = state.refreshControl || {};
    const labels = {
      idle: "检查新文章",
      checking_werss: "检查 WeRSS",
      syncing_reader: "同步阅读库",
      complete: "检查完成",
      cooldown: "冷却中",
      single_flight: "正在检查",
      failed: "检查失败",
    };
    const phase = labels[refresh.phase] ? refresh.phase : "idle";
    const active = phase === "checking_werss" || phase === "syncing_reader" || phase === "single_flight";
    elements.refresh.dataset.phase = phase;
    elements.refresh.disabled = active;
    elements.refresh.classList.toggle("is-loading", active);
    elements.refreshLabel.textContent = labels[phase];
    elements.refreshSummary.textContent = refresh.message || labels[phase];

    const details = [];
    if (phase === "complete") details.push(`新增 ${Number(refresh.new_articles || 0)} 篇`);
    if (refresh.last_werss_fetch_at) details.push(`抓取 ${fullTime(refresh.last_werss_fetch_at)}`);
    if (refresh.last_sync_at) details.push(`同步 ${fullTime(refresh.last_sync_at)}`);
    if (phase === "cooldown" || cooldownText(refresh.next_allowed_at) !== "现在可以") {
      details.push(`下次 ${cooldownText(refresh.next_allowed_at)}`);
    }
    elements.refreshDetail.textContent = details.join(" / ") || "触发 WeRSS 抓取并同步阅读库";
  }

  function renderHealth() {
    const ok = state.status?.health === "ok";
    elements.healthDot.className = `health-dot ${ok ? "ok" : state.status ? "error" : ""}`;
    elements.healthText.textContent = ok ? "抓取与同步运行正常" : state.status ? "同步状态需要检查" : "未读取到抓取状态";
    elements.syncBrief.textContent = scheduleText(state.status?.cron || "17 * * * *", state.status?.sync_interval_seconds || 300);
  }

  function render() {
    renderTabs();
    renderSources();
    renderTimeline();
    renderReader();
    renderHealth();
    renderRefreshControl();
  }

  async function refreshAnnotations({ focusNewest = false } = {}) {
    const previousIds = new Set(state.annotations.map((item) => String(item.id)));
    const annotations = await fetchPaged("/api/bookmarks/annotations?");
    state.annotations = annotations;
    state.annotatedIds = new Set(annotations.map((item) => item.bookmark_id));
    renderTabs();
    if (state.activeTab === "highlights") renderTimeline();
    renderReader();
    const newest = focusNewest ? annotations.find((item) => !previousIds.has(String(item.id))) : null;
    enhanceArticleAnnotations(elements.articleFrame.contentDocument, newest?.id || state.pendingAnnotationId);
    if (newest) {
      state.pendingAnnotationId = "";
      showToast("划线笔记已保存，并进入 Obsidian 自动同步队列");
    }
  }

  async function refreshData({ quiet = false } = {}) {
    if (state.loading) return;
    state.loading = true;
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
      elements.timeline.innerHTML = `<div class="empty-list">${escapeHtml(error.message || "无法读取阅读库")}</div>`;
    } finally {
      state.loading = false;
      render();
    }
  }

  async function refreshControlRequest(action) {
    return request("/reader-control/refresh", {
      method: "POST",
      body: JSON.stringify({ action }),
    });
  }

  function setRefreshControl(payload) {
    if (!payload || typeof payload !== "object") return;
    state.refreshControl = { ...state.refreshControl, ...payload };
    renderRefreshControl();
    if (state.activeTab === "subscriptions") renderSubscriptionStatus();
  }

  async function pollRefreshControl(generation) {
    window.clearTimeout(state.refreshPollTimer);
    if (generation !== state.refreshGeneration) return;
    try {
      const payload = await refreshControlRequest("status");
      if (generation !== state.refreshGeneration) return;
      setRefreshControl(payload);
      const terminal = ["complete", "cooldown", "failed", "idle"].includes(payload.phase);
      if (!terminal) {
        state.refreshPollTimer = window.setTimeout(() => pollRefreshControl(generation), 1800);
        return;
      }
      await refreshData({ quiet: true });
      if (payload.phase === "complete") {
        showToast(`检查完成，新增 ${Number(payload.new_articles || 0)} 篇文章`);
      } else if (payload.phase === "failed") {
        showToast(payload.message || "检查新文章失败", true);
      }
    } catch (error) {
      setRefreshControl({ phase: "failed", message: error.message || "刷新控制端不可用" });
      showToast(error.message || "刷新控制端不可用", true);
    }
  }

  async function checkForNewArticles() {
    const generation = ++state.refreshGeneration;
    window.clearTimeout(state.refreshPollTimer);
    setRefreshControl({ phase: "checking_werss", message: "正在请求 WeRSS 检查新文章" });
    try {
      const payload = await refreshControlRequest("start");
      if (generation !== state.refreshGeneration) return;
      setRefreshControl(payload);
      if (["checking_werss", "syncing_reader", "single_flight"].includes(payload.phase)) {
        state.refreshPollTimer = window.setTimeout(() => pollRefreshControl(generation), 1000);
        return;
      }
      await refreshData({ quiet: true });
      if (payload.phase === "cooldown") {
        showToast(`主动抓取仍在冷却，${cooldownText(payload.next_allowed_at)}可再次检查`);
      } else if (payload.phase === "complete") {
        showToast(`检查完成，新增 ${Number(payload.new_articles || 0)} 篇文章`);
      } else if (payload.phase === "failed") {
        showToast(payload.message || "检查新文章失败", true);
      }
    } catch (error) {
      setRefreshControl({ phase: "failed", message: error.message || "检查新文章失败" });
      showToast(error.message || "检查新文章失败", true);
    }
  }

  async function loadRefreshControl() {
    try {
      const payload = await refreshControlRequest("status");
      setRefreshControl(payload);
      if (["checking_werss", "syncing_reader", "single_flight"].includes(payload.phase)) {
        const generation = ++state.refreshGeneration;
        state.refreshPollTimer = window.setTimeout(() => pollRefreshControl(generation), 600);
      }
    } catch (error) {
      setRefreshControl({ phase: "failed", message: "刷新控制端尚未就绪" });
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

  function selectionRect(doc) {
    const selection = doc?.getSelection?.();
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return null;
    const rect = selection.getRangeAt(0).getBoundingClientRect();
    if (!rect.width && !rect.height) return null;
    return { top: rect.top, right: rect.right, bottom: rect.bottom, left: rect.left, width: rect.width, height: rect.height };
  }

  function placeFloatingElement(element, anchor, doc, preferredWidth = 320) {
    if (!element || !anchor || !doc?.defaultView) return;
    const viewportWidth = doc.defaultView.innerWidth;
    const viewportHeight = doc.defaultView.innerHeight;
    const margin = 14;
    const gap = 12;
    const width = Math.min(preferredWidth, viewportWidth - margin * 2);
    element.style.setProperty("position", "fixed", "important");
    element.style.setProperty("width", `${width}px`, "important");
    element.style.setProperty("max-width", `${width}px`, "important");
    element.style.setProperty("transform", "none", "important");
    element.style.setProperty("right", "auto", "important");
    element.style.setProperty("bottom", "auto", "important");
    const height = Math.min(element.offsetHeight || 180, viewportHeight - margin * 2);

    let left;
    let top;
    if (anchor.right + gap + width <= viewportWidth - margin) {
      left = anchor.right + gap;
      top = Math.max(margin, Math.min(anchor.top - 12, viewportHeight - height - margin));
    } else if (anchor.left - gap - width >= margin) {
      left = anchor.left - gap - width;
      top = Math.max(margin, Math.min(anchor.top - 12, viewportHeight - height - margin));
    } else {
      left = Math.max(margin, Math.min(anchor.left + anchor.width / 2 - width / 2, viewportWidth - width - margin));
      const below = anchor.bottom + gap;
      top = below + height <= viewportHeight - margin ? below : Math.max(margin, anchor.top - height - gap);
    }
    element.style.setProperty("left", `${Math.round(left)}px`, "important");
    element.style.setProperty("top", `${Math.round(top)}px`, "important");
  }

  function positionNativeAnnotator(doc) {
    const annotator = doc?.querySelector?.(".annotator");
    if (!annotator || getComputedStyle(annotator).display === "none") return;
    const anchor = selectionRect(doc) || state.lastSelectionRect;
    if (!anchor) return;
    annotator.classList.add("reader-positioned-annotator");
    placeFloatingElement(annotator, anchor, doc, 340);
  }

  function showAnnotationPopover(doc, item, target) {
    if (!doc || !item || !target) return;
    doc.querySelector(".reader-note-popover")?.remove();
    const popover = doc.createElement("aside");
    popover.className = "reader-note-popover";
    popover.setAttribute("role", "note");

    const heading = doc.createElement("div");
    heading.className = "reader-note-popover-heading";
    const label = doc.createElement("strong");
    label.textContent = "划线笔记";
    const close = doc.createElement("button");
    close.type = "button";
    close.setAttribute("aria-label", "关闭笔记");
    close.textContent = "×";
    close.addEventListener("click", () => popover.remove());
    heading.append(label, close);

    const quote = doc.createElement("blockquote");
    quote.textContent = markdownEscape(item.text) || "空摘录";
    const note = doc.createElement("p");
    note.textContent = markdownEscape(item.note) || "尚未写笔记；再次点击划线可编辑。";
    if (!markdownEscape(item.note)) note.classList.add("is-empty");
    const source = doc.createElement("small");
    source.textContent = `${annotationSource(item)} · ${fullTime(item.created)}`;
    popover.append(heading, quote, note, source);
    doc.body.append(popover);
    placeFloatingElement(popover, target.getBoundingClientRect(), doc, 286);
  }

  function enhanceArticleAnnotations(doc, focusId = "") {
    const bookmark = selectedBookmark();
    if (!doc || !bookmark) return;
    const byId = new Map(annotationsFor(bookmark.id).map((item) => [String(item.id), item]));
    let focusTarget = null;
    for (const target of doc.querySelectorAll("rd-annotation[data-annotation-id-value], .rd-annotation[data-annotation-id-value]")) {
      const id = target.getAttribute("data-annotation-id-value") || "";
      const item = byId.get(id);
      if (!item) continue;
      target.setAttribute("tabindex", "0");
      target.setAttribute("role", "button");
      target.setAttribute("aria-label", item.note ? "查看划线笔记" : "查看划线摘录");
      target.title = item.note || "查看划线摘录";
      if (!target.dataset.readerNoteBound) {
        const open = (event) => {
          event.stopPropagation();
          showAnnotationPopover(doc, annotationById(id), target);
        };
        target.addEventListener("click", open);
        target.addEventListener("keydown", (event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            open(event);
          }
        });
        target.dataset.readerNoteBound = "true";
      }
      if (focusId && id === String(focusId) && !focusTarget) focusTarget = target;
    }
    if (focusTarget) {
      focusTarget.scrollIntoView({ behavior: "auto", block: "center" });
      window.setTimeout(() => showAnnotationPopover(doc, annotationById(focusId), focusTarget), 120);
      state.pendingAnnotationId = "";
    }
  }

  function selectAnnotation(bookmarkId, annotationId) {
    state.pendingAnnotationId = annotationId;
    selectBookmark(bookmarkId);
    window.setTimeout(() => enhanceArticleAnnotations(elements.articleFrame.contentDocument, annotationId), 80);
  }

  function showCurrentArticleNotes() {
    const bookmark = selectedBookmark();
    if (!bookmark) return;
    const notes = annotationsFor(bookmark.id);
    if (!notes.length) {
      showToast("本文还没有划线笔记");
      return;
    }
    enhanceArticleAnnotations(elements.articleFrame.contentDocument, notes[0].id);
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
          embedTheme.href = "/reader-assets/embed.css?v=3";
          embedTheme.dataset.readerEmbedTheme = "true";
          doc.head.append(embedTheme);
        }
        doc.documentElement.style.setProperty("--reader-font-size", `${state.fontSize}px`);
        state.annotationObserver?.disconnect();
        state.annotationObserver = new MutationObserver((records) => {
          const annotationChanged = records.some((record) => [...record.addedNodes, ...record.removedNodes].some((node) => node.nodeType === 1 && (node.matches?.("rd-annotation, .rd-annotation") || node.querySelector?.("rd-annotation, .rd-annotation"))));
          const annotatorChanged = records.some((record) => record.target?.matches?.(".annotator") || [...record.addedNodes].some((node) => node.nodeType === 1 && (node.matches?.(".annotator") || node.querySelector?.(".annotator"))));
          if (annotatorChanged) window.requestAnimationFrame(() => positionNativeAnnotator(doc));
          if (!annotationChanged) return;
          window.clearTimeout(state.annotationTimer);
          state.annotationTimer = window.setTimeout(() => refreshAnnotations({ focusNewest: true }).catch(() => {}), 500);
        });
        state.annotationObserver.observe(doc.body, { attributes: true, attributeFilter: ["class", "style", "hidden"], childList: true, subtree: true });
        enhanceArticleAnnotations(doc, state.pendingAnnotationId);

        const captureSelection = () => {
          const rect = selectionRect(doc);
          if (rect) {
            state.lastSelectionRect = rect;
            doc.querySelector(".reader-note-popover")?.remove();
          }
          window.setTimeout(() => positionNativeAnnotator(doc), 0);
        };
        doc.addEventListener("selectionchange", captureSelection);
        doc.addEventListener("pointerup", captureSelection);

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
        frameWindow.addEventListener("scroll", () => {
          doc.querySelector(".reader-note-popover")?.remove();
          updateProgress();
        }, { passive: true });
        frameWindow.addEventListener("resize", () => doc.querySelector(".reader-note-popover")?.remove(), { passive: true });
        window.clearTimeout(state.progressStartTimer);
        state.progressStartTimer = window.setTimeout(() => {
          const current = selectedBookmark();
          if (current?.id === bookmark.id && Number(current.read_progress || 0) === 0) setReadProgress(bookmark.id, 1, true);
        }, 1500);
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

  function prepareFeedDialog() {
    const mobileDevice = window.matchMedia("(max-width: 760px), (pointer: coarse)").matches;
    const publicFeedUrl = new URL(window.location.href);
    if (publicFeedUrl.hostname.startsWith("reader.")) {
      publicFeedUrl.hostname = `werss.${publicFeedUrl.hostname.slice("reader.".length)}`;
      publicFeedUrl.pathname = "/";
      publicFeedUrl.search = "";
      publicFeedUrl.hash = "";
      elements.feedPublicLink.href = publicFeedUrl.toString();
    } else {
      elements.feedPublicLink.href = "http://127.0.0.1:8001";
    }
    elements.feedLocalLink.hidden = mobileDevice;
    elements.feedDeviceNote.textContent = mobileDevice
      ? "当前设备请使用公网入口。新增后回到阅读器点击“检查新文章”。"
      : "推荐使用公网入口；部署这套系统的 Mac 还可使用本机备用入口。";
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
    elements.refresh.addEventListener("click", () => checkForNewArticles());
    elements.notesDownload.addEventListener("click", downloadMarkdown);
    elements.notesFolder.addEventListener("click", () => {
      renderExportTarget();
      elements.exportDialog.showModal();
    });
    elements.readerStar.addEventListener("click", () => toggleFavorite());
    elements.readerRead.addEventListener("click", () => {
      const bookmark = selectedBookmark();
      if (bookmark) setReadProgress(bookmark.id, Number(bookmark.read_progress || 0) >= 100 ? 0 : 100);
    });
    elements.topicForm.addEventListener("submit", (event) => {
      event.preventDefault();
      addTopic(elements.topicInput.value);
    });
    elements.fontLarger.addEventListener("click", () => setFontSize(state.fontSize + 1));
    elements.fontSmaller.addEventListener("click", () => setFontSize(state.fontSize - 1));
    elements.articleNotes.addEventListener("click", showCurrentArticleNotes);
    elements.chooseExportFolder.addEventListener("click", chooseExportDirectory);
    elements.exportToFolder.addEventListener("click", exportToDirectory);
    elements.forgetExportFolder.addEventListener("click", forgetDirectoryHandle);
    elements.readerBack.addEventListener("click", () => { elements.app.dataset.mobileView = "timeline"; });
    elements.timelineBack.addEventListener("click", () => { elements.app.dataset.mobileView = "sources"; });
    for (const button of [elements.addFeed, elements.subscriptionAdd]) {
      button.addEventListener("click", () => {
        prepareFeedDialog();
        elements.feedDialog.showModal();
      });
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
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) loadRefreshControl();
    });
    bindArticleFrame();
  }

  state.fontSize = Math.max(15, Math.min(24, Number(localStorage.getItem("reader-font-size")) || 17));
  bindEvents();
  render();
  renderFontSize();
  loadDirectoryHandle();
  refreshData();
  loadRefreshControl();
})();
