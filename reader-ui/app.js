(() => {
  "use strict";

  const state = {
    bookmarks: [],
    annotations: [],
    annotatedIds: new Set(),
    status: null,
    activeTab: "unread",
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
    pendingAnnotationDocument: null,
    pendingAnnotationRange: null,
    lastSelectionRect: null,
    fontSize: 17,
    exportDirectoryHandle: null,
    timelineLimit: 60,
    timelineBatch: 60,
    sourceCollapsed: false,
    focusMode: false,
    nativeFullscreenActive: false,
    prefetchedIds: new Set(),
    articleLoadGeneration: 0,
    articlePrimeTimer: 0,
    articleResizeObserver: null,
    articleStageScrollHandler: null,
    highlightMode: false,
    installPrompt: null,
    edgeSwipe: null,
    mobilePaneSwipe: null,
    paneSwipeTimer: 0,
    suppressPaneClickUntil: 0,
  };

  const tabMeta = {
    inbox: ["已读", "读完后归档在这里"],
    unread: ["未读", "还没有读完的文章"],
    favorites: ["收藏", "准备继续处理的文章"],
    highlights: ["划线笔记", "摘录、批注与来源"],
    valuable: ["高价值", "价值评分为 4-5 的文章"],
    subscriptions: ["订阅", "公众号来源与抓取状态"],
  };

  const $ = (selector) => document.querySelector(selector);
  const elements = {
    app: $("#app"),
    sourcePane: $(".source-pane"),
    timelinePane: $(".timeline-pane"),
    sourceToggle: $("#source-toggle"),
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
    readerArchive: $("#reader-archive"),
    readerBack: $("#reader-back"),
    readerAutoStatus: $("#reader-auto-status"),
    readerFocus: $("#reader-focus"),
    readerMore: $("#reader-more"),
    readerStage: $(".reader-stage"),
    articleFrame: $("#article-frame"),
    articleLoading: $("#article-loading"),
    mobileScrollLayer: $("#mobile-scroll-layer"),
    mobileScrollSpacer: $("#mobile-scroll-spacer"),
    edgeBackIndicator: $("#edge-back-indicator"),
    fontLarger: $("#font-larger"),
    fontSmaller: $("#font-smaller"),
    fontSize: $("#font-size"),
    highlightMode: $("#highlight-mode"),
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
    readerActionsDialog: $("#reader-actions-dialog"),
    mobileActionsTitle: $("#mobile-actions-title"),
    mobileActionsClose: $("#mobile-actions-close"),
    mobileReaderRead: $("#mobile-reader-read"),
    mobileFontLarger: $("#mobile-font-larger"),
    mobileFontSmaller: $("#mobile-font-smaller"),
    mobileFontSize: $("#mobile-font-size"),
    installApp: $("#install-app"),
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

  function resetTimelineWindow() {
    state.timelineLimit = state.timelineBatch;
  }

  function isMobileReader() {
    return window.matchMedia("(max-width: 760px), (pointer: coarse)").matches;
  }

  function isMobileLayout() {
    return window.matchMedia("(max-width: 760px)").matches;
  }

  function fontPreferenceKey() {
    return isMobileReader() ? "reader-font-size-mobile-codex" : "reader-font-size";
  }

  function applyHighlightModeToArticle(doc = elements.articleFrame.contentDocument) {
    try {
      if (!doc?.documentElement) return;
      doc.documentElement.dataset.readerHighlightMode = String(state.highlightMode);
      if (!state.highlightMode) {
        doc.getSelection()?.removeAllRanges();
        doc.querySelector(".annotator")?.classList.add("hidden");
        clearPendingAnnotationPreview(doc);
      }
    } catch {
      // The next same-origin article pass applies the mode.
    }
  }

  function renderHighlightMode() {
    elements.readerContent.dataset.highlightMode = String(state.highlightMode);
    elements.highlightMode.classList.toggle("is-active", state.highlightMode);
    elements.highlightMode.setAttribute("aria-pressed", String(state.highlightMode));
    elements.highlightMode.setAttribute("aria-label", state.highlightMode ? "退出划线模式" : "进入划线模式");
    elements.highlightMode.title = state.highlightMode ? "退出划线模式" : "进入划线模式";
    applyHighlightModeToArticle();
  }

  function setHighlightMode(active, { quiet = false } = {}) {
    state.highlightMode = Boolean(active);
    renderHighlightMode();
    if (!quiet) {
      showToast(state.highlightMode
        ? "已进入划线模式：拖选文字即保存，不记笔记"
        : "已回到阅读模式：可以顺滑滚动，不会误选全文");
    }
  }

  function applyLayoutState() {
    elements.app.dataset.sourceCollapsed = String(state.sourceCollapsed);
    elements.app.dataset.focusMode = String(state.focusMode);
    elements.sourceToggle.setAttribute("aria-pressed", String(state.sourceCollapsed));
    elements.sourceToggle.setAttribute("aria-label", state.sourceCollapsed ? "展开左侧栏" : "收起左侧栏");
    elements.sourceToggle.title = state.sourceCollapsed ? "展开左侧栏" : "收起左侧栏";
    elements.readerFocus.setAttribute("aria-pressed", String(state.focusMode));
    elements.readerFocus.setAttribute("aria-label", state.focusMode ? "退出全屏阅读" : "全屏阅读");
    elements.readerFocus.title = state.focusMode ? "退出全屏阅读" : "全屏阅读";
    elements.readerFocus.querySelector("span").textContent = state.focusMode ? "退出全屏" : "全屏阅读";
    renderHighlightMode();
    if (selectedBookmark()) renderMobileActions(selectedBookmark());
  }

  function toggleSourcePane() {
    state.sourceCollapsed = !state.sourceCollapsed;
    localStorage.setItem("reader-source-collapsed", String(state.sourceCollapsed));
    applyLayoutState();
  }

  async function setReaderFocus(active, { syncNative = true } = {}) {
    if (active && !selectedBookmark()) {
      showToast("先选择一篇文章，再进入全屏阅读");
      return;
    }
    state.focusMode = Boolean(active);
    applyLayoutState();
    if (!syncNative) return;
    try {
      if (state.focusMode && !document.fullscreenElement && document.documentElement.requestFullscreen) {
        await document.documentElement.requestFullscreen();
      } else if (!state.focusMode && document.fullscreenElement && document.exitFullscreen) {
        await document.exitFullscreen();
      }
    } catch {
      if (state.focusMode) showToast("已进入沉浸阅读；浏览器未允许隐藏工具栏");
    }
  }

  function setArticleLoading(active) {
    elements.articleLoading.hidden = !active;
    elements.articleFrame.classList.toggle("is-loading", active);
  }

  function prefetchArticle(id) {
    if (!id || state.prefetchedIds.has(String(id))) return;
    state.prefetchedIds.add(String(id));
    const link = document.createElement("link");
    link.rel = "prefetch";
    link.as = "document";
    link.href = `/bookmarks/${encodeURIComponent(id)}?reader=1`;
    link.dataset.readerPrefetch = String(id);
    document.head.append(link);
    window.setTimeout(() => link.remove(), 30000);
  }

  function syncMobileArticleHeight(doc) {
    if (!doc?.body || !doc.documentElement || !isMobileLayout()) return;
    const stageHeight = elements.readerStage.clientHeight;
    const documentHeight = Math.ceil(Math.max(
      doc.body.scrollHeight,
      doc.body.getBoundingClientRect().height,
      doc.documentElement.scrollHeight,
      stageHeight,
    ));
    const current = Number.parseFloat(elements.articleFrame.style.height) || 0;
    if (Math.abs(current - documentHeight) > 1) {
      elements.articleFrame.style.height = `${documentHeight}px`;
    }
    elements.mobileScrollSpacer.style.height = `${Math.max(0, documentHeight - stageHeight)}px`;
    doc.documentElement.dataset.readerParentScroll = "true";
  }

  function configureMobileNativeScrolling(doc) {
    if (!doc?.body || !isMobileLayout()) return;
    syncMobileArticleHeight(doc);
    if (doc.documentElement.dataset.readerParentScrollBound) return;
    doc.documentElement.dataset.readerParentScrollBound = "true";
    state.articleResizeObserver?.disconnect();
    let heightFrame = 0;
    const scheduleHeight = () => {
      if (heightFrame) return;
      heightFrame = doc.defaultView.requestAnimationFrame(() => {
        heightFrame = 0;
        syncMobileArticleHeight(doc);
      });
    };
    if (doc.defaultView.ResizeObserver) {
      state.articleResizeObserver = new doc.defaultView.ResizeObserver(scheduleHeight);
      state.articleResizeObserver.observe(doc.body);
    }
    doc.addEventListener("load", scheduleHeight, { capture: true });
    doc.fonts?.ready?.then(scheduleHeight).catch(() => {});
    window.setTimeout(scheduleHeight, 80);
    window.setTimeout(scheduleHeight, 500);
  }

  function refreshArticleLayout() {
    const doc = elements.articleFrame.contentDocument;
    if (!doc?.body) return;
    if (isMobileLayout()) {
      configureMobileNativeScrolling(doc);
      syncMobileArticleHeight(doc);
      return;
    }
    state.articleResizeObserver?.disconnect();
    elements.articleFrame.style.removeProperty("height");
    elements.mobileScrollSpacer.style.height = "0px";
    doc.documentElement.dataset.readerParentScroll = "false";
  }

  function primeArticleFrame(generation, id) {
    window.clearTimeout(state.articlePrimeTimer);
    const startedAt = performance.now();
    const poll = () => {
      if (generation !== state.articleLoadGeneration || state.selectedId !== id) return;
      try {
        const doc = elements.articleFrame.contentDocument;
        const path = elements.articleFrame.contentWindow?.location?.pathname || "";
        const prose = doc?.querySelector?.(".bookmark-article .prose");
        if (doc?.head && prose && path.includes(`/bookmarks/${id}`)) {
          doc.documentElement.classList.add("reader-embed", "dark");
          doc.documentElement.dataset.readerHighlightMode = String(state.highlightMode);
          doc.documentElement.style.setProperty("--reader-font-size", `${state.fontSize}px`);
          configureArticleEndActions(doc);
          bindArticleScrolling(doc);
          configureMobileNativeScrolling(doc);
          bindArticleAnnotationInteractions(doc);
          let embedTheme = doc.querySelector("link[data-reader-embed-theme]");
          const revealArticle = () => {
            if (generation !== state.articleLoadGeneration) return;
            window.requestAnimationFrame(() => setArticleLoading(false));
          };
          if (!embedTheme) {
            embedTheme = doc.createElement("link");
            embedTheme.rel = "stylesheet";
            embedTheme.href = "/reader-assets/embed.css?v=12";
            embedTheme.dataset.readerEmbedTheme = "true";
            embedTheme.addEventListener("load", revealArticle, { once: true });
            embedTheme.addEventListener("error", revealArticle, { once: true });
            doc.head.append(embedTheme);
            window.setTimeout(revealArticle, 450);
          } else {
            revealArticle();
          }
          return;
        }
      } catch {
        // The iframe is still swapping its initial document.
      }
      if (performance.now() - startedAt < 4000) {
        state.articlePrimeTimer = window.setTimeout(poll, 32);
      }
    };
    poll();
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

  function tagTone(value) {
    let hash = 2166136261;
    for (const character of String(value || "")) {
      hash ^= character.codePointAt(0);
      hash = Math.imul(hash, 16777619);
    }
    return `tone-${(hash >>> 0) % 6}`;
  }

  function isHelperBookmark(bookmark) {
    return (bookmark.labels || []).includes("Obsidian同步助手");
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
      inbox: state.bookmarks.filter((item) => Number(item.read_progress || 0) >= 100).length,
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
    const helperBookmarks = state.bookmarks.filter(isHelperBookmark);
    if (helperBookmarks.length) {
      const latest = helperBookmarks.reduce((value, bookmark) => {
        const published = bookmark.published || bookmark.created || "";
        return !value || new Date(published) > new Date(value) ? published : value;
      }, "");
      byName.set("Obsidian同步助手", {
        name: "Obsidian同步助手",
        articles: helperBookmarks.length,
        unread: helperBookmarks.filter((item) => Number(item.read_progress || 0) < 100).length,
        latest,
        health: "自动同步",
      });
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
      ...catalog.map((item) => `<button class="source-item ${tagTone(item.name)}" type="button" data-source="${escapeHtml(item.name)}" aria-current="${state.activeSource === item.name}">
        <span class="source-avatar">${escapeHtml(item.name.trim().slice(0, 1) || "公")}</span>
        <span class="source-name">${escapeHtml(item.name)}</span><span class="source-count">${item.unread}</span>
      </button>`),
    ];
    elements.sourceList.innerHTML = rows.join("");
    for (const button of elements.sourceList.querySelectorAll("[data-source]")) {
      button.addEventListener("click", () => {
        if (isPaneClickSuppressed()) return;
        state.activeSource = button.dataset.source || "";
        if (state.activeTab === "subscriptions") state.activeTab = "unread";
        resetTimelineWindow();
        elements.app.dataset.mobileView = "timeline";
        render();
      });
    }
  }

  function filteredBookmarks() {
    const sourceFiltered = state.activeSource === "Obsidian同步助手"
      ? state.bookmarks.filter(isHelperBookmark)
      : state.activeSource
        ? state.bookmarks.filter((item) => sourceName(item) === state.activeSource)
        : state.bookmarks;
    switch (state.activeTab) {
      case "inbox": return sourceFiltered.filter((item) => Number(item.read_progress || 0) >= 100);
      case "unread": return sourceFiltered.filter((item) => Number(item.read_progress || 0) < 100);
      case "favorites": return sourceFiltered.filter((item) => item.is_marked);
      case "highlights": return sourceFiltered.filter((item) => state.annotatedIds.has(item.id));
      case "valuable": return sourceFiltered.filter((item) => valueOf(item) >= 4);
      default: return sourceFiltered;
    }
  }

  function filteredAnnotations() {
    return state.annotations
      .filter((item) => {
        if (!state.activeSource) return true;
        if (state.activeSource === "Obsidian同步助手") {
          return isHelperBookmark(state.bookmarks.find((bookmark) => bookmark.id === item.bookmark_id) || {});
        }
        return annotationSource(item) === state.activeSource;
      })
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
    const stateName = readState(bookmark);
    const author = sourceName(bookmark);
    const tone = tagTone(author);
    const progress = Number(bookmark.read_progress || 0);
    const progressLabel = stateName === "read" ? "已读" : stateName === "reading" ? `${progress}%` : "未读";
    const labels = [
      ...(value ? [`<span class="chip value">价值 ${value}</span>`] : []),
      ...topics.slice(0, 2).map((topic) => `<span class="chip">${escapeHtml(topic)}</span>`),
    ].join("");
    const published = bookmark.published || bookmark.created;
    return `<article class="entry-row is-${stateName} ${tone}" data-id="${bookmark.id}" tabindex="0" aria-current="${state.selectedId === bookmark.id}">
      <span class="entry-status"><i class="unread-dot" title="${stateName === "read" ? "已读" : stateName === "reading" ? `阅读 ${bookmark.read_progress}%` : "未读"}"></i></span>
      <div class="entry-body">
        <div class="entry-meta"><span class="entry-source">${escapeHtml(author)}</span><span class="chip state-chip is-${stateName}">${progressLabel}</span><span class="entry-time">${shortTime(published)}</span></div>
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
    return catalog.map((feed) => `<article class="subscription-row ${tagTone(feed.name)}" data-feed="${escapeHtml(feed.name)}">
      <span class="source-avatar">${escapeHtml(feed.name.trim().slice(0, 1) || "公")}</span>
      <div><strong>${escapeHtml(feed.name)}</strong><p>最近抓取 ${fullTime(feed.latest)} · ${escapeHtml(feed.health)}</p></div>
      <div class="subscription-stats"><b>${feed.articles} 篇</b>${feed.unread} 未读</div>
    </article>`).join("");
  }

  function loadMoreTimeline() {
    if (["subscriptions", "highlights"].includes(state.activeTab)) return;
    const total = filteredBookmarks().length;
    if (state.timelineLimit >= total) return;
    const previousScrollTop = elements.timeline.scrollTop;
    state.timelineLimit = Math.min(total, state.timelineLimit + state.timelineBatch);
    renderTimeline();
    elements.timeline.scrollTop = previousScrollTop;
  }

  function bindTimelineRows() {
    for (const row of elements.timeline.querySelectorAll(".entry-row")) {
      const open = () => selectBookmark(row.dataset.id);
      row.addEventListener("click", (event) => {
        if (isPaneClickSuppressed()) return;
        if (!event.target.closest("[data-star]")) open();
      });
      row.addEventListener("pointerenter", (event) => {
        if (event.pointerType !== "touch") prefetchArticle(row.dataset.id);
      }, { once: true });
      row.addEventListener("focusin", () => prefetchArticle(row.dataset.id), { once: true });
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
        if (isPaneClickSuppressed()) return;
        toggleFavorite(button.dataset.star);
      });
    }
    for (const row of elements.timeline.querySelectorAll("[data-feed]")) {
      row.addEventListener("click", () => {
        if (isPaneClickSuppressed()) return;
        state.activeSource = row.dataset.feed;
        state.activeTab = "unread";
        resetTimelineWindow();
        elements.app.dataset.mobileView = "timeline";
        render();
      });
    }
    for (const row of elements.timeline.querySelectorAll(".annotation-row")) {
      const open = () => selectAnnotation(row.dataset.bookmarkId, row.dataset.annotationId);
      row.addEventListener("click", () => {
        if (!isPaneClickSuppressed()) open();
      });
      row.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          open();
        }
      });
    }
    elements.timeline.querySelector("[data-load-more]")?.addEventListener("click", () => {
      if (!isPaneClickSuppressed()) loadMoreTimeline();
    });
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
    const visible = bookmarks.slice(0, state.timelineLimit);
    const remaining = Math.max(0, bookmarks.length - visible.length);
    elements.timeline.innerHTML = bookmarks.length
      ? `${visible.map(entryRow).join("")}${remaining ? `<button class="timeline-more" type="button" data-load-more>继续加载 ${Math.min(state.timelineBatch, remaining)} 篇</button>` : ""}`
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

  function renderMobileActions(bookmark) {
    if (!bookmark) return;
    const isRead = Number(bookmark.read_progress || 0) >= 100;
    elements.mobileActionsTitle.textContent = bookmark.title || "未命名文章";
    elements.mobileReaderRead.querySelector("span").textContent = isRead ? "标为未读" : "标为已读";
  }

  function renderFontSize() {
    elements.fontSize.value = String(state.fontSize);
    elements.fontSize.textContent = `${state.fontSize}px`;
    elements.fontSmaller.disabled = state.fontSize <= 12;
    elements.fontLarger.disabled = state.fontSize >= 20;
    elements.mobileFontSize.value = String(state.fontSize);
    elements.mobileFontSize.textContent = `${state.fontSize}px`;
    elements.mobileFontSmaller.disabled = state.fontSize <= 12;
    elements.mobileFontLarger.disabled = state.fontSize >= 20;
    try {
      elements.articleFrame.contentDocument?.documentElement.style.setProperty("--reader-font-size", `${state.fontSize}px`);
    } catch {
      // The next same-origin frame load applies the preference.
    }
  }

  function setFontSize(value) {
    state.fontSize = Math.max(12, Math.min(20, Number(value) || (isMobileReader() ? 14 : 17)));
    localStorage.setItem(fontPreferenceKey(), String(state.fontSize));
    renderFontSize();
    showToast(`正文字号 ${state.fontSize}px`);
  }

  function isStandaloneApp() {
    return window.matchMedia("(display-mode: standalone), (display-mode: fullscreen)").matches;
  }

  function renderInstallAction() {
    elements.installApp.hidden = isStandaloneApp();
  }

  async function installReaderApp() {
    if (isStandaloneApp()) return;
    if (!state.installPrompt) {
      showToast("请在 Chrome 菜单中选择“安装应用”或“添加到主屏幕”");
      return;
    }
    state.installPrompt.prompt();
    const result = await state.installPrompt.userChoice;
    state.installPrompt = null;
    renderInstallAction();
    if (result.outcome === "accepted") showToast("已安装到桌面，下次打开不显示地址栏");
  }

  function currentReadingProgress() {
    const bookmark = selectedBookmark();
    if (!bookmark) return 0;
    let root = elements.readerStage;
    if (!isMobileLayout()) {
      const doc = elements.articleFrame.contentDocument;
      root = doc?.scrollingElement || doc?.documentElement;
    }
    if (!root) return Number(bookmark.read_progress || 0);
    const maxScroll = Math.max(1, root.scrollHeight - root.clientHeight);
    const ratio = Math.min(1, Math.max(0, root.scrollTop / maxScroll));
    const measured = ratio >= 0.8 ? 100 : Math.min(99, Math.max(1, Math.round(ratio * 100)));
    return Math.max(Number(bookmark.read_progress || 0), measured);
  }

  async function saveCurrentReadingProgress() {
    const bookmark = selectedBookmark();
    if (!bookmark) return;
    window.clearTimeout(state.progressTimer);
    window.clearTimeout(state.progressStartTimer);
    const progress = currentReadingProgress();
    if (progress !== Number(bookmark.read_progress || 0)) {
      await setReadProgress(bookmark.id, progress, true);
    }
  }

  async function returnToTimeline({ fromHistory = false } = {}) {
    await saveCurrentReadingProgress();
    if (state.focusMode) await setReaderFocus(false);
    if (!fromHistory && isMobileLayout() && history.state?.readerView === "reader") {
      history.back();
      return;
    }
    elements.app.dataset.mobileView = "timeline";
  }

  function resetEdgeSwipe() {
    state.edgeSwipe = null;
    elements.readerContent.classList.remove("is-edge-swiping", "is-edge-swipe-ready");
    elements.readerContent.style.removeProperty("--edge-swipe-distance");
  }

  function isPaneClickSuppressed() {
    return performance.now() < state.suppressPaneClickUntil;
  }

  function clearMobilePaneSwipe(nextView = "") {
    window.clearTimeout(state.paneSwipeTimer);
    if (nextView) elements.app.dataset.mobileView = nextView;
    elements.app.classList.remove("is-pane-swiping", "is-pane-settling");
    elements.app.style.removeProperty("--pane-swipe-x");
    state.mobilePaneSwipe = null;
  }

  function bindMobilePaneSwipe() {
    const panes = [
      { element: elements.sourcePane, view: "sources", target: "timeline", direction: -1 },
      { element: elements.timelinePane, view: "timeline", target: "sources", direction: 1 },
    ];

    for (const pane of panes) {
      pane.element.addEventListener("pointerdown", (event) => {
        if (!isMobileLayout()
          || elements.app.dataset.mobileView !== pane.view
          || state.mobilePaneSwipe
          || event.button !== 0
          || event.target.closest("input, textarea, select, dialog, [contenteditable='true']")) return;
        state.mobilePaneSwipe = {
          ...pane,
          pointerId: event.pointerId,
          startX: event.clientX,
          startY: event.clientY,
          distance: 0,
          moved: false,
          width: Math.max(pane.element.clientWidth, window.innerWidth),
        };
      });

      pane.element.addEventListener("pointermove", (event) => {
        const swipe = state.mobilePaneSwipe;
        if (!swipe || swipe.pointerId !== event.pointerId || swipe.element !== pane.element) return;
        const rawX = event.clientX - swipe.startX;
        const vertical = Math.abs(event.clientY - swipe.startY);
        const horizontal = Math.abs(rawX);
        if (vertical > horizontal && vertical > 12) {
          clearMobilePaneSwipe();
          return;
        }
        if (horizontal < 8 || Math.sign(rawX) !== swipe.direction) return;
        event.preventDefault();
        if (!swipe.moved) pane.element.setPointerCapture?.(event.pointerId);
        swipe.moved = true;
        swipe.distance = swipe.direction < 0 ? Math.max(-swipe.width, rawX) : Math.min(swipe.width, rawX);
        state.suppressPaneClickUntil = performance.now() + 420;
        elements.app.classList.add("is-pane-swiping");
        elements.app.style.setProperty("--pane-swipe-x", `${swipe.distance}px`);
      }, { passive: false });

      const finish = (event, cancelled = false) => {
        const swipe = state.mobilePaneSwipe;
        if (!swipe || swipe.pointerId !== event.pointerId || swipe.element !== pane.element) return;
        const shouldSwitch = !cancelled && swipe.moved && Math.abs(swipe.distance) >= 64;
        if (!swipe.moved) {
          clearMobilePaneSwipe();
          return;
        }
        state.suppressPaneClickUntil = performance.now() + 420;
        elements.app.classList.add("is-pane-settling");
        elements.app.style.setProperty("--pane-swipe-x", `${shouldSwitch ? swipe.direction * swipe.width : 0}px`);
        const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        state.paneSwipeTimer = window.setTimeout(
          () => clearMobilePaneSwipe(shouldSwitch ? swipe.target : ""),
          reducedMotion ? 0 : 170,
        );
      };

      pane.element.addEventListener("pointerup", (event) => finish(event));
      pane.element.addEventListener("pointercancel", (event) => finish(event, true));
    }
  }

  function bindEdgeSwipeBack() {
    elements.readerContent.addEventListener("pointerdown", (event) => {
      if (!isMobileLayout() || elements.app.dataset.mobileView !== "reader" || event.button !== 0 || event.clientX > 28) return;
      state.edgeSwipe = {
        pointerId: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        distance: 0,
      };
    });
    elements.readerContent.addEventListener("pointermove", (event) => {
      const swipe = state.edgeSwipe;
      if (!swipe || swipe.pointerId !== event.pointerId) return;
      const distance = Math.max(0, event.clientX - swipe.startX);
      const vertical = Math.abs(event.clientY - swipe.startY);
      if (vertical > distance && vertical > 18) {
        resetEdgeSwipe();
        return;
      }
      swipe.distance = distance;
      if (distance < 8) return;
      event.preventDefault();
      elements.readerContent.setPointerCapture?.(event.pointerId);
      elements.readerContent.classList.add("is-edge-swiping");
      elements.readerContent.classList.toggle("is-edge-swipe-ready", distance >= 72);
      elements.readerContent.style.setProperty("--edge-swipe-distance", `${Math.min(36, distance * 0.5)}px`);
    }, { passive: false });
    const finish = (event) => {
      const swipe = state.edgeSwipe;
      if (!swipe || swipe.pointerId !== event.pointerId) return;
      const shouldReturn = swipe.distance >= 72;
      resetEdgeSwipe();
      if (shouldReturn) returnToTimeline();
    };
    elements.readerContent.addEventListener("pointerup", finish);
    elements.readerContent.addEventListener("pointercancel", resetEdgeSwipe);
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
    elements.readerStar.setAttribute("aria-label", bookmark.is_marked ? "取消收藏" : "收藏");
    elements.readerArchive.classList.toggle("is-active", Boolean(bookmark.is_archived));
    elements.readerArchive.querySelector("span").textContent = bookmark.is_archived ? "移出归档" : "移至归档";
    elements.readerArchive.setAttribute("aria-label", bookmark.is_archived ? "移出归档" : "移至归档");
    const isRead = Number(bookmark.read_progress || 0) >= 100;
    elements.readerRead.querySelector("span").textContent = isRead ? "标为未读" : "标为已读";
    elements.readerRead.setAttribute("aria-label", isRead ? "标为未读" : "标为已读");
    const progress = Number(bookmark.read_progress || 0);
    elements.readerAutoStatus.textContent = progress >= 100 ? "已自动记录 · 已读" : progress > 0 ? `自动记录 · ${progress}%` : "自动记录 · 未读";
    const noteCount = annotationsFor(bookmark.id).length;
    elements.articleNotes.querySelector("b").textContent = String(noteCount);
    elements.articleNotes.classList.toggle("has-notes", noteCount > 0);
    renderRating(bookmark);
    renderTopics(bookmark);
    renderMobileActions(bookmark);
    syncArticleEndActions(elements.articleFrame.contentDocument, bookmark);
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
    enhanceArticleAnnotations(elements.articleFrame.contentDocument, state.highlightMode ? state.pendingAnnotationId : newest?.id || state.pendingAnnotationId);
    if (newest) {
      state.pendingAnnotationId = "";
      showToast(state.highlightMode
        ? "纯划线已保存，不含笔记"
        : "划线笔记已保存，并进入 Obsidian 自动同步队列");
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

  async function patchBookmark(id, payload, { rerender = true } = {}) {
    const updated = await request(`/api/bookmarks/${id}`, { method: "PATCH", body: JSON.stringify(payload) });
    const index = state.bookmarks.findIndex((item) => item.id === id);
    if (index >= 0) state.bookmarks[index] = { ...state.bookmarks[index], ...(updated || {}), ...payload };
    if (rerender) render();
    return state.bookmarks[index];
  }

  async function toggleFavorite(id = state.selectedId) {
    const bookmark = state.bookmarks.find((item) => item.id === id);
    if (!bookmark) return;
    const previous = Boolean(bookmark.is_marked);
    bookmark.is_marked = !previous;
    render();
    try {
      await patchBookmark(id, { is_marked: !previous }, { rerender: false });
      showToast(!previous ? "已收藏，后续会同步到 Obsidian" : "已取消收藏");
    } catch (error) {
      bookmark.is_marked = previous;
      render();
      showToast(error.message || "收藏失败", true);
    }
  }

  async function toggleArchive(id = state.selectedId) {
    const bookmark = state.bookmarks.find((item) => item.id === id);
    if (!bookmark) return;
    const previousArchived = Boolean(bookmark.is_archived);
    const previousProgress = Number(bookmark.read_progress || 0);
    const archived = !previousArchived;
    const progress = archived ? 100 : 0;
    bookmark.is_archived = archived;
    bookmark.read_progress = progress;
    render();
    try {
      await patchBookmark(id, { is_archived: archived, read_progress: progress }, { rerender: false });
      showToast(archived ? "已移至归档，并归入已读栏目" : "已移出归档，并恢复为未读");
    } catch (error) {
      bookmark.is_archived = previousArchived;
      bookmark.read_progress = previousProgress;
      render();
      showToast(error.message || "归档状态保存失败", true);
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
      await patchBookmark(id, { read_progress: progress }, { rerender: false });
      if (!quiet) showToast(progress >= 100 ? "已读，已归入已读栏目" : progress === 0 ? "已标为未读" : `阅读进度 ${progress}%`);
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

  function clearPendingAnnotationPreview(doc = state.pendingAnnotationDocument) {
    try {
      doc?.defaultView?.CSS?.highlights?.delete("reader-pending-annotation");
    } catch {
      // Custom Highlight is progressive enhancement; saving still uses Readeck.
    }
    if (!doc || doc === state.pendingAnnotationDocument) {
      state.pendingAnnotationDocument = null;
      state.pendingAnnotationRange = null;
    }
  }

  function showPendingAnnotationPreview(doc, range) {
    if (!doc || !range || range.collapsed) return;
    clearPendingAnnotationPreview();
    state.pendingAnnotationDocument = doc;
    state.pendingAnnotationRange = range.cloneRange();
    try {
      const HighlightCtor = doc.defaultView?.Highlight;
      if (HighlightCtor && doc.defaultView.CSS?.highlights) {
        doc.defaultView.CSS.highlights.set("reader-pending-annotation", new HighlightCtor(state.pendingAnnotationRange));
      }
    } catch {
      // Browsers without the Custom Highlight API retain the native selection.
    }
  }

  function selectionWithinArticle(doc) {
    const selection = doc?.getSelection?.();
    if (!selection || selection.rangeCount !== 1 || selection.isCollapsed) return true;
    const root = doc.querySelector(".bookmark-article .prose");
    const range = selection.getRangeAt(0);
    if (!root || !root.contains(range.startContainer) || !root.contains(range.endContainer)) return false;
    const selectedLength = selection.toString().trim().length;
    const articleLength = root.textContent.trim().length;
    const maxLength = state.highlightMode ? 1200 : 2500;
    const maxRatio = state.highlightMode ? 0.25 : 0.45;
    return selectedLength <= maxLength && !(articleLength > 400 && selectedLength > articleLength * maxRatio);
  }

  function rejectUnsafeArticleSelection(doc) {
    const selection = doc?.getSelection?.();
    if (!selection || selection.isCollapsed || selectionWithinArticle(doc)) return false;
    selection.removeAllRanges();
    doc.querySelector(".annotator")?.classList.add("hidden");
    clearPendingAnnotationPreview(doc);
    showToast("已阻止整篇误选，请只划选正文中的一段文字");
    return true;
  }

  function placeFloatingElement(element, anchor, doc, preferredWidth = 320) {
    if (!element || !anchor || !doc?.defaultView) return;
    const viewportWidth = doc.defaultView.innerWidth;
    const viewportHeight = doc.defaultView.innerHeight;
    const margin = 14;
    const gap = 12;
    const width = Math.min(preferredWidth, viewportWidth - margin * 2);
    const setImportant = (name, value) => {
      if (element.style.getPropertyValue(name) === value && element.style.getPropertyPriority(name) === "important") return;
      element.style.setProperty(name, value, "important");
    };
    setImportant("position", "fixed");
    setImportant("width", `${width}px`);
    setImportant("max-width", `${width}px`);
    setImportant("transform", "none");
    setImportant("right", "auto");
    setImportant("bottom", "auto");
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
    setImportant("left", `${Math.round(left)}px`);
    setImportant("top", `${Math.round(top)}px`);
  }

  function positionNativeAnnotator(doc) {
    const annotator = doc?.querySelector?.(".annotator");
    if (!annotator || getComputedStyle(annotator).display === "none") return;
    const anchor = selectionRect(doc) || state.lastSelectionRect;
    if (!anchor) return;
    annotator.classList.add("reader-positioned-annotator");
    placeFloatingElement(annotator, anchor, doc, 340);
  }

  function configureNativeAnnotator(doc) {
    const annotator = doc?.querySelector?.(".annotator");
    if (!annotator || getComputedStyle(annotator).display === "none") return;
    const transparent = annotator.querySelector('input[name="color"][value="none"]');
    // Readeck keeps its own colorValue. A property assignment only changes the
    // radio UI and would still save the controller's default yellow value.
    if (transparent && !transparent.checked) transparent.click();
    const textarea = annotator.querySelector("textarea");
    const action = [...annotator.querySelectorAll('button[data-action*="annotations#"]')]
      .find((button) => !button.classList.contains("hidden") && /annotations#(?:create|update)/.test(button.dataset.action || ""));
    if (state.highlightMode) {
      if (textarea) {
        textarea.value = "";
        textarea.blur();
      }
      if (action && !annotator.dataset.readerAutoHighlightQueued) {
        annotator.dataset.readerAutoHighlightQueued = "true";
        window.setTimeout(() => {
          if (!state.highlightMode || getComputedStyle(annotator).display === "none" || rejectUnsafeArticleSelection(doc)) return;
          action.click();
          window.setTimeout(() => {
            doc.getSelection()?.removeAllRanges();
            clearPendingAnnotationPreview(doc);
          }, 80);
        }, 24);
      }
      return;
    }
    if (!textarea) return;
    textarea.placeholder = "输入笔记（可留空），回车确认 · Shift+Enter 换行";
    textarea.setAttribute("aria-label", "快速笔记");
    if (!textarea.dataset.readerQuickNoteBound) {
      textarea.addEventListener("keydown", (event) => {
        if (event.isComposing || event.key !== "Enter" || event.shiftKey) return;
        event.preventDefault();
        const noteAction = [...annotator.querySelectorAll('button[data-action*="annotations#"]')]
          .find((button) => !button.classList.contains("hidden") && /annotations#(?:create|update)/.test(button.dataset.action || ""));
        noteAction?.click();
      });
      textarea.dataset.readerQuickNoteBound = "true";
    }
    if (doc.activeElement !== textarea && !textarea.dataset.readerFocusQueued) {
      textarea.dataset.readerFocusQueued = "true";
      // A real text drag is followed by a click. Readeck's outside-click
      // handler checks the selection in a zero-delay timer; focusing here
      // synchronously would collapse it first and immediately close the form.
      window.setTimeout(() => {
        delete textarea.dataset.readerFocusQueued;
        if (getComputedStyle(annotator).display !== "none" && doc.activeElement !== textarea) {
          textarea.focus({ preventScroll: true });
        }
      }, 48);
    }
  }

  function enhanceNativeAnnotator(doc) {
    configureNativeAnnotator(doc);
    if (!state.highlightMode) positionNativeAnnotator(doc);
  }

  function nestedScrollCanConsume(target, delta, doc) {
    let node = target?.nodeType === 1 ? target : target?.parentElement;
    while (node && node !== doc.body && node !== doc.documentElement) {
      const style = doc.defaultView.getComputedStyle(node);
      const scrollable = /(auto|scroll)/.test(style.overflowY) && node.scrollHeight > node.clientHeight + 1;
      if (scrollable && ((delta > 0 && node.scrollTop < node.scrollHeight - node.clientHeight - 1) || (delta < 0 && node.scrollTop > 0))) return true;
      node = node.parentElement;
    }
    return false;
  }

  function bindArticleScrolling(doc) {
    if (!doc?.defaultView || doc.documentElement.dataset.readerScrollBound) return;
    doc.documentElement.dataset.readerScrollBound = "true";
    const root = doc.scrollingElement || doc.documentElement;
    doc.body.tabIndex = -1;
    doc.addEventListener("pointerup", (event) => {
      if (event.pointerType === "touch") return;
      if (event.target.matches?.("input, textarea, select, button, a, [contenteditable='true']")) return;
      if (doc.getSelection()?.isCollapsed) doc.body.focus({ preventScroll: true });
    }, { passive: true });
    doc.addEventListener("wheel", (event) => {
      if (event.ctrlKey || !event.deltaY || Math.abs(event.deltaX) > Math.abs(event.deltaY)) return;
      const unit = event.deltaMode === 1 ? 18 : event.deltaMode === 2 ? root.clientHeight : 1;
      const delta = event.deltaY * unit;
      if (nestedScrollCanConsume(event.target, delta, doc)) return;
      const next = Math.max(0, Math.min(root.scrollHeight - root.clientHeight, root.scrollTop + delta));
      if (next === root.scrollTop) return;
      event.preventDefault();
      root.scrollTop = next;
    }, { passive: false });
    doc.addEventListener("keydown", (event) => {
      if (event.target.matches?.("input, textarea, select, button, [contenteditable='true']")) return;
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "a") {
        event.preventDefault();
        event.stopPropagation();
        showToast("为避免整篇误划线，阅读区不执行全选");
        return;
      }
      if (event.key === "Escape" && state.highlightMode) {
        event.preventDefault();
        event.stopPropagation();
        setHighlightMode(false);
        return;
      }
      if (event.key === "Escape" && state.focusMode) {
        event.preventDefault();
        event.stopPropagation();
        setReaderFocus(false);
        return;
      }
      if (event.key.toLowerCase() === "f") {
        event.preventDefault();
        event.stopPropagation();
        setReaderFocus(!state.focusMode);
        return;
      }
      const amount = Math.max(120, root.clientHeight * 0.82);
      const moves = { PageDown: amount, PageUp: -amount, ArrowDown: 56, ArrowUp: -56, " ": event.shiftKey ? -amount : amount };
      if (event.key === "Home") {
        event.preventDefault();
        event.stopPropagation();
        root.scrollTop = 0;
      } else if (event.key === "End") {
        event.preventDefault();
        event.stopPropagation();
        root.scrollTop = root.scrollHeight;
      } else if (Object.hasOwn(moves, event.key)) {
        event.preventDefault();
        event.stopPropagation();
        root.scrollTop += moves[event.key];
      }
    }, { capture: true });
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

  function forwardMobileReaderTap(event) {
    if (state.highlightMode) return;
    try {
      const doc = elements.articleFrame.contentDocument;
      const frameRect = elements.articleFrame.getBoundingClientRect();
      const target = doc?.elementFromPoint?.(event.clientX - frameRect.left, event.clientY - frameRect.top);
      const actionable = target?.closest?.("[data-reader-action], a[href], rd-annotation, .rd-annotation");
      actionable?.click();
    } catch {
      // Reading and native scrolling remain available if a target cannot be forwarded.
    }
  }

  function syncArticleEndActions(doc, bookmark = selectedBookmark()) {
    if (!doc?.body || !bookmark) return;
    const favorite = doc.querySelector('[data-reader-action="favorite"]');
    const archive = doc.querySelector('[data-reader-action="archive"]');
    if (!favorite || !archive) return;
    favorite.classList.toggle("is-active", Boolean(bookmark.is_marked));
    favorite.setAttribute("aria-label", bookmark.is_marked ? "取消收藏" : "收藏");
    favorite.querySelector("[data-reader-action-label]").textContent = bookmark.is_marked ? "已收藏" : "收藏";
    archive.classList.toggle("is-active", Boolean(bookmark.is_archived));
    archive.setAttribute("aria-label", bookmark.is_archived ? "移出归档" : "移至归档");
    archive.querySelector("[data-reader-action-label]").textContent = bookmark.is_archived ? "移出归档" : "移至归档";
  }

  function configureArticleEndActions(doc) {
    if (!doc?.body) return;
    const frame = doc.querySelector('[id^="bookmark-bottom-actions-"]');
    const form = frame?.querySelector("form");
    if (!frame || !form) return;
    frame.closest(".mx-auto")?.setAttribute("data-reader-end-actions", "true");
    form.dataset.readerEndActions = "true";
    form.removeAttribute("data-controller");

    const prepare = (button, action, handler) => {
      if (!button || button.dataset.readerActionBound) return;
      const glyph = button.querySelector(".svgicon")?.outerHTML || "";
      button.type = "button";
      button.removeAttribute("name");
      button.removeAttribute("value");
      button.dataset.readerAction = action;
      button.dataset.readerActionBound = "true";
      button.innerHTML = `${glyph}<span data-reader-action-label></span>`;
      button.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopImmediatePropagation();
        handler();
      });
    };

    prepare(form.querySelector('[name="is_marked"]'), "favorite", () => toggleFavorite());
    prepare(form.querySelector('[name="is_archived"]'), "archive", () => toggleArchive());
    syncArticleEndActions(doc);
  }

  function bindArticleAnnotationInteractions(doc) {
    if (!doc?.body || doc.documentElement.dataset.readerAnnotationsBound) return;
    doc.documentElement.dataset.readerAnnotationsBound = "true";
    state.annotationObserver?.disconnect();
    state.annotationObserver = new MutationObserver((records) => {
      const annotationChanged = records.some((record) => [...record.addedNodes, ...record.removedNodes].some((node) => node.nodeType === 1 && (node.matches?.("rd-annotation, .rd-annotation") || node.querySelector?.("rd-annotation, .rd-annotation"))));
      const annotatorChanged = records.some((record) => record.target?.matches?.(".annotator") || [...record.addedNodes].some((node) => node.nodeType === 1 && (node.matches?.(".annotator") || node.querySelector?.(".annotator"))));
      if (annotatorChanged) {
        window.requestAnimationFrame(() => {
          const annotator = doc.querySelector(".annotator");
          const active = Boolean(annotator && getComputedStyle(annotator).display !== "none");
          elements.readerContent.dataset.annotating = String(active && !state.highlightMode);
          if (!active) {
            if (annotator) delete annotator.dataset.readerAutoHighlightQueued;
            clearPendingAnnotationPreview(doc);
          } else {
            enhanceNativeAnnotator(doc);
          }
        });
      }
      if (!annotationChanged) return;
      clearPendingAnnotationPreview(doc);
      window.clearTimeout(state.annotationTimer);
      state.annotationTimer = window.setTimeout(() => refreshAnnotations({ focusNewest: true }).catch(() => {}), 500);
    });
    state.annotationObserver.observe(doc.body, { attributes: true, attributeFilter: ["class", "style", "hidden"], childList: true, subtree: true });
    const nativeAnnotator = doc.querySelector(".annotator");
    elements.readerContent.dataset.annotating = String(Boolean(nativeAnnotator && getComputedStyle(nativeAnnotator).display !== "none" && !state.highlightMode));
    enhanceNativeAnnotator(doc);
    enhanceArticleAnnotations(doc, state.pendingAnnotationId);

    const captureSelection = () => {
      if (!selectionWithinArticle(doc)) return;
      const rect = selectionRect(doc);
      if (rect) {
        state.lastSelectionRect = rect;
        const selection = doc.getSelection();
        if (selection?.rangeCount === 1) showPendingAnnotationPreview(doc, selection.getRangeAt(0));
        doc.querySelector(".reader-note-popover")?.remove();
      }
      window.setTimeout(() => enhanceNativeAnnotator(doc), 0);
    };
    doc.addEventListener("selectionchange", captureSelection);
    // Readeck resolves the selection in a microtask after pointerup. Guard
    // invalid endpoints in capture phase so dragging outside the article
    // cannot be normalized into an accidental whole-document annotation.
    doc.addEventListener("pointerup", () => rejectUnsafeArticleSelection(doc), { capture: true });
    doc.addEventListener("pointerup", captureSelection);
  }

  function selectBookmark(id, { pushHistory = true } = {}) {
    if (!state.bookmarks.some((item) => item.id === id)) return;
    state.selectedId = id;
    elements.readerContent.dataset.annotating = "false";
    elements.app.dataset.mobileView = "reader";
    if (pushHistory && isMobileLayout() && history.state?.bookmarkId !== id) {
      history.pushState({ readerView: "reader", bookmarkId: id }, "");
    }
    render();
    if (!elements.articleFrame.src.includes(`/bookmarks/${id}?reader=1`)) {
      state.articleResizeObserver?.disconnect();
      elements.readerStage.scrollTop = 0;
      elements.articleFrame.style.removeProperty("height");
      elements.mobileScrollSpacer.style.height = "0px";
      state.articleLoadGeneration += 1;
      setArticleLoading(true);
      elements.articleFrame.src = `/bookmarks/${id}?reader=1`;
      primeArticleFrame(state.articleLoadGeneration, id);
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
        clearPendingAnnotationPreview();
        const loadGeneration = state.articleLoadGeneration;
        doc.documentElement.classList.add("reader-embed", "dark");
        doc.documentElement.dataset.readerHighlightMode = String(state.highlightMode);
        let embedTheme = doc.querySelector("link[data-reader-embed-theme]");
        const revealArticle = () => {
          if (loadGeneration !== state.articleLoadGeneration) return;
          window.requestAnimationFrame(() => setArticleLoading(false));
        };
        if (!embedTheme) {
          embedTheme = doc.createElement("link");
          embedTheme.rel = "stylesheet";
          embedTheme.href = "/reader-assets/embed.css?v=12";
          embedTheme.dataset.readerEmbedTheme = "true";
          embedTheme.addEventListener("load", revealArticle, { once: true });
          embedTheme.addEventListener("error", revealArticle, { once: true });
          doc.head.append(embedTheme);
          window.setTimeout(revealArticle, 900);
        } else {
          revealArticle();
        }
        doc.documentElement.style.setProperty("--reader-font-size", `${state.fontSize}px`);
        configureArticleEndActions(doc);
        bindArticleScrolling(doc);
        configureMobileNativeScrolling(doc);
        bindArticleAnnotationInteractions(doc);

        let lastProgress = Number(bookmark.read_progress || 0);
        const updateProgress = () => {
          const current = selectedBookmark();
          if (!current || current.id !== bookmark.id) return;
          const root = isMobileLayout() ? elements.readerStage : doc.scrollingElement || doc.documentElement;
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
        let progressFrame = 0;
        const trackProgress = () => {
          doc.querySelector(".reader-note-popover")?.remove();
          if (progressFrame) return;
          progressFrame = window.requestAnimationFrame(() => {
            progressFrame = 0;
            updateProgress();
          });
        };
        if (isMobileLayout()) {
          if (state.articleStageScrollHandler) elements.readerStage.removeEventListener("scroll", state.articleStageScrollHandler);
          state.articleStageScrollHandler = trackProgress;
          elements.readerStage.addEventListener("scroll", trackProgress, { passive: true });
        } else {
          doc.addEventListener("scroll", trackProgress, { passive: true, capture: true });
        }
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
    resetTimelineWindow();
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
    elements.sourceToggle.addEventListener("click", toggleSourcePane);
    elements.refresh.addEventListener("click", () => checkForNewArticles());
    elements.notesDownload.addEventListener("click", downloadMarkdown);
    elements.notesFolder.addEventListener("click", () => {
      renderExportTarget();
      elements.exportDialog.showModal();
    });
    elements.readerStar.addEventListener("click", () => toggleFavorite());
    elements.readerArchive.addEventListener("click", () => toggleArchive());
    elements.readerMore.addEventListener("click", () => {
      renderMobileActions(selectedBookmark());
      elements.readerActionsDialog.showModal();
    });
    elements.mobileActionsClose.addEventListener("click", () => elements.readerActionsDialog.close());
    elements.readerActionsDialog.addEventListener("click", (event) => {
      if (event.target === elements.readerActionsDialog) elements.readerActionsDialog.close();
    });
    elements.mobileReaderRead.addEventListener("click", () => {
      const bookmark = selectedBookmark();
      if (bookmark) setReadProgress(bookmark.id, Number(bookmark.read_progress || 0) >= 100 ? 0 : 100);
    });
    elements.mobileFontLarger.addEventListener("click", () => setFontSize(state.fontSize + 1));
    elements.mobileFontSmaller.addEventListener("click", () => setFontSize(state.fontSize - 1));
    elements.installApp.addEventListener("click", installReaderApp);
    elements.mobileScrollLayer.addEventListener("click", forwardMobileReaderTap);
    elements.readerFocus.addEventListener("click", () => setReaderFocus(!state.focusMode));
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
    elements.highlightMode.addEventListener("click", () => setHighlightMode(!state.highlightMode));
    elements.articleNotes.addEventListener("click", showCurrentArticleNotes);
    elements.chooseExportFolder.addEventListener("click", chooseExportDirectory);
    elements.exportToFolder.addEventListener("click", exportToDirectory);
    elements.forgetExportFolder.addEventListener("click", forgetDirectoryHandle);
    elements.readerBack.addEventListener("click", () => returnToTimeline());
    elements.timelineBack.addEventListener("click", () => { elements.app.dataset.mobileView = "sources"; });
    let timelineLoadQueued = false;
    elements.timeline.addEventListener("scroll", () => {
      if (timelineLoadQueued || elements.timeline.scrollHeight - elements.timeline.scrollTop - elements.timeline.clientHeight > 260) return;
      timelineLoadQueued = true;
      window.requestAnimationFrame(() => {
        timelineLoadQueued = false;
        loadMoreTimeline();
      });
    }, { passive: true });
    for (const button of [elements.addFeed, elements.subscriptionAdd]) {
      button.addEventListener("click", () => {
        prepareFeedDialog();
        elements.feedDialog.showModal();
      });
    }
    document.addEventListener("keydown", (event) => {
      const editable = event.target.matches?.("input, textarea, [contenteditable='true']");
      if (editable) return;
      if (event.key === "Escape" && state.highlightMode) {
        setHighlightMode(false);
        return;
      }
      if (event.key === "Escape" && state.focusMode) {
        setReaderFocus(false);
        return;
      }
      if (event.key.toLowerCase() === "f" && state.selectedId) {
        event.preventDefault();
        setReaderFocus(!state.focusMode);
        return;
      }
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
    window.addEventListener("beforeinstallprompt", (event) => {
      event.preventDefault();
      state.installPrompt = event;
      renderInstallAction();
    });
    window.addEventListener("appinstalled", () => {
      state.installPrompt = null;
      renderInstallAction();
    });
    window.addEventListener("popstate", (event) => {
      if (!isMobileLayout()) return;
      if (event.state?.readerView === "reader" && event.state.bookmarkId) {
        selectBookmark(event.state.bookmarkId, { pushHistory: false });
        return;
      }
      if (elements.app.dataset.mobileView === "reader") returnToTimeline({ fromHistory: true });
    });
    let layoutResizeTimer = 0;
    window.addEventListener("resize", () => {
      window.clearTimeout(layoutResizeTimer);
      layoutResizeTimer = window.setTimeout(refreshArticleLayout, 80);
    }, { passive: true });
    document.addEventListener("fullscreenchange", () => {
      if (document.fullscreenElement) {
        state.nativeFullscreenActive = true;
      } else if (state.nativeFullscreenActive) {
        state.nativeFullscreenActive = false;
        if (state.focusMode) setReaderFocus(false, { syncNative: false });
      }
    });
    bindMobilePaneSwipe();
    bindEdgeSwipeBack();
    bindArticleFrame();
  }

  if (isMobileLayout() && !history.state?.readerView) {
    history.replaceState({ readerView: "timeline" }, "");
  }
  state.fontSize = Math.max(12, Math.min(20, Number(localStorage.getItem(fontPreferenceKey())) || (isMobileReader() ? 14 : 17)));
  state.sourceCollapsed = localStorage.getItem("reader-source-collapsed") === "true";
  applyLayoutState();
  bindEvents();
  render();
  renderFontSize();
  renderInstallAction();
  loadDirectoryHandle();
  refreshData();
  loadRefreshControl();
})();
