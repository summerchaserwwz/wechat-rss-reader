#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command curl
require_command docker
require_command python3
require_env_file

reader_port="${READER_CADDY_HOST_PORT:-$(env_value READER_CADDY_HOST_PORT 8082)}"
reader_url="http://127.0.0.1:${reader_port}"
reader_host="$(env_value READECK_PUBLIC_HOSTNAME reader.example.com)"
access_email="$(env_value CF_ACCESS_EMAIL)"
[[ -n "$access_email" ]] || die "缺少 CF_ACCESS_EMAIL，无法模拟已授权 Reader 身份"

status_file="$HOME/.local/share/wechat-rss/public-status/reader-status.json"
[[ -f "$status_file" ]] || die "缺少 Reader 状态文件；先运行本机 reading-sync"

tmp_dir="$(mktemp -d /tmp/wechat-rss-reader-ui.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

headers=(
  -H "Host: $reader_host"
  -H "Cf-Access-Authenticated-User-Email: $access_email"
  -H "Cf-Access-Jwt-Assertion: reader-ui-verify-jwt"
)

printf '检查 Reader UI 源文件与无秘密边界...\n'
[[ -f "$ROOT_DIR/reader-ui/index.html" ]] || die "缺少 reader-ui/index.html"
[[ -f "$ROOT_DIR/reader-ui/styles.css" ]] || die "缺少 reader-ui/styles.css"
[[ -f "$ROOT_DIR/reader-ui/app.js" ]] || die "缺少 reader-ui/app.js"
[[ -f "$ROOT_DIR/reader-ui/embed.css" ]] || die "缺少 reader-ui/embed.css"
[[ -f "$ROOT_DIR/reader-ui/manifest.webmanifest" ]] || die "Reader 缺少 Android PWA manifest"
[[ -s "$ROOT_DIR/reader-ui/icons/reader-192.png" ]] || die "Reader 缺少 192px PWA 图标"
[[ -s "$ROOT_DIR/reader-ui/icons/reader-512.png" ]] || die "Reader 缺少 512px PWA 图标"
tab_count="$(grep -c 'data-tab=' "$ROOT_DIR/reader-ui/index.html")"
[[ "$tab_count" == "6" ]] || die "Reader 顶部 Tab 不是 6 个（实际：$tab_count）"
shortcut_count="$(grep -c 'aria-keyshortcuts="[1-6]"' "$ROOT_DIR/reader-ui/index.html")"
[[ "$shortcut_count" == "6" ]] || die "Reader 顶部 Tab 快捷键不是 1–6 六个"
if grep -R -nE 'https://|Authorization:[[:space:]]*Bearer|FEED_PREFIX|CF_ACCESS_AUD|readeck_api_token' "$ROOT_DIR/reader-ui"; then
  die "Reader 浏览器资源包含远程依赖或秘密标识"
fi
grep -q 'read_progress' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现阅读进度"
grep -q 'ratio >= 0.8' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现 80% 自动已读阈值"
grep -q 'activeTab: "unread"' "$ROOT_DIR/reader-ui/app.js" || die "Reader 默认视图不是未读"
grep -q 'case "inbox".*read_progress.*>= 100' "$ROOT_DIR/reader-ui/app.js" || die "Reader 已读栏目未只收纳已读文章"
grep -q 'data-tab="inbox" aria-label="已读"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 顶部缺少已读栏目"
grep -q '价值/' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现价值标签"
grep -q '主题/' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现主题标签"
grep -q 'data-reader-embed-theme' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未注入沉浸正文主题"
grep -q 'bookmark-sidebar' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 没有隐藏 Readeck 正文侧栏"
grep -q 'pointer: coarse' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未区分手机端新增公众号流程"
grep -q 'id="feed-public-link"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少 Access 保护的 WeRSS 公网新增入口"
grep -q 'feed-local-link' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少部署 Mac 本机新增入口"
grep -q '@media (min-width: 761px)' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 缺少桌面开发工具风格覆盖"
grep -q -- '--canvas: #0a0d12' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 桌面未使用中性近黑画布"
grep -q 'background: #292c32' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 桌面三栏之间缺少细分隔线"
grep -q 'grid-template-rows: 52px minmax(0, 1fr)' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 桌面顶栏仍然过高"
grep -q '\.reader-empty::before { display: none; }' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 桌面空状态仍使用旧悬浮大卡片"
grep -q '\.app-shell\[data-focus-mode="true"\] \.value-toolbar { display: none; }' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 全屏阅读未收起价值工具栏"
grep -q -- '--reader-content-width: 46rem' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 缺少深色专注的桌面正文行宽"
grep -q 'width: min(100%, var(--reader-content-width))' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 正文行宽未接入排版预设"
grep -q -- '--reader-preset-leading: 1.68' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 桌面正文排版未同步紧凑风格"
grep -q 'background: #191b20 !important' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 桌面批注框仍使用旧蓝色磨砂"
grep -q -- '--annotation-line: #8ad4a8' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 缺少淡绿色划线 token"
grep -q -- '--reader-body-font: "SF Pro Text"' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 正文未使用中文友好的系统字体"
grep -q '::selection' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 正文缺少清晰选区反馈"
grep -q 'text-decoration-style: dashed' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 临时选区不是虚线下划线"
grep -q 'text-decoration-style: dashed' "$ROOT_DIR/reader-theme/reader.css" || die "Readeck 持久批注不是虚线下划线"
grep -q 'background: transparent' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 临时选区仍可能遮挡正文"
grep -q 'color: var(--reader-body) !important' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 选区或持久划线可能改变正文颜色"
grep -q 'reader-note-popover' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 缺少划线原位笔记浮层"
grep -q 'positionNativeAnnotator' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未避让定位原生批注框"
grep -q 'buildAnnotationsMarkdown' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少划线笔记 Markdown 导出"
grep -q 'showDirectoryPicker' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少可配置 Obsidian 目录"
grep -q 'id="font-larger"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少右侧字号控制"
grep -q 'id="source-toggle"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少左侧公众号栏折叠控制"
grep -q 'id="reader-focus"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少全屏阅读控制"
grep -q 'id="reader-archive"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 顶部缺少移至归档控制"
grep -q 'id="reader-original"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 顶部缺少微信原文媒体入口"
grep -q 'id="mobile-reader-original"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机设置缺少微信原文媒体入口"
grep -q 'id="reading-preset"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 桌面缺少正文排版预设"
grep -q 'id="mobile-reading-preset"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机设置缺少正文排版预设"
grep -q 'const readingPresets' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未定义正文排版预设"
grep -q 'applyReadingPresetToArticle' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未向正文应用排版预设"
grep -q 'data-reader-preset="paper"' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 缺少浅色稿纸正文预设"
grep -q 'id="article-loading"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少正文加载骨架"
grep -q 'id="highlight-mode"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少显式划线模式控制"
grep -q 'timelineLimit: 60' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未限制初始时间线 DOM 数量"
grep -q 'async function fetchPage' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现首屏分页读取"
grep -q 'bookmarksExhausted' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未跟踪文章分页结束状态"
grep -q 'async function loadMoreBookmarks' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现按需追加文章"
if grep -q 'fetchPaged("/api/bookmarks?sort=-published")' "$ROOT_DIR/reader-ui/app.js"; then
  die "Reader 首屏仍会阻塞等待全量文章分页"
fi
grep -q 'prefetchArticle' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少正文预取"
grep -q 'bindArticleScrolling' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少 iframe 纵向滚动链修复"
grep -q 'configureNativeAnnotator' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少快速批注交互"
grep -q 'readerAutoHighlightQueued' "$ROOT_DIR/reader-ui/app.js" || die "Reader 划线模式未接入纯划线自动保存"
grep -q 'articlePrimeTimer' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未在图片加载完成前优先呈现正文"
grep -q 'reader-font-size-mobile' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少独立的手机紧凑字号偏好"
grep -q 'event.pointerType === "touch"' "$ROOT_DIR/reader-ui/app.js" || die "Reader 仍可能在触摸结束时抢焦点并中断惯性滚动"
grep -q 'id="mobile-scroll-layer"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少手机原生滚动触摸层"
grep -q 'id="mobile-scroll-spacer"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少手机原生滚动占位层"
grep -q 'configureMobileNativeScrolling' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未按正文高度配置手机原生滚动"
grep -q 'readerParentScroll' "$ROOT_DIR/reader-ui/app.js" || die "Reader 手机正文未标记父容器原生滚动"
grep -q 'id="reader-more"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机顶栏缺少更多操作入口"
grep -q 'id="reader-actions-dialog"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少手机文章操作面板"
grep -q 'id="mobile-font-size"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机设置缺少字号控制"
grep -q 'id="mobile-highlight-mode"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机设置缺少划线模式入口"
grep -q 'id="install-app"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机设置缺少安装到桌面入口"
grep -q 'id="edge-back-indicator"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少边缘返回提示"
grep -q 'bindEdgeSwipeBack' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少正文左滑返回手势"
grep -q 'Math.max(0, swipe.startX - event.clientX)' "$ROOT_DIR/reader-ui/app.js" || die "Reader 正文返回手势方向不是左滑"
grep -q 'swipe.captureTarget.setPointerCapture.*event.pointerId' "$ROOT_DIR/reader-ui/app.js" || die "Reader 左滑返回未在移动后捕获指针"
grep -q 'saveCurrentReadingProgress' "$ROOT_DIR/reader-ui/app.js" || die "Reader 返回前未保存阅读进度"
grep -q 'function toggleArchive' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少收藏旁的归档状态更新"
grep -q 'function openOriginalArticle' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少打开微信原文操作"
grep -q 'function configureArticleOriginalCallout' "$ROOT_DIR/reader-ui/app.js" || die "Reader 正文开头缺少原文媒体入口"
grep -q 'reader-original-callout' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 正文原文媒体入口缺少样式"
grep -q '视频和视频化动图需在微信原文中播放' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未解释微信动态媒体的安全降级"
grep -q 'link.target = "_blank"' "$ROOT_DIR/reader-ui/app.js" || die "Reader 原文媒体入口未使用新窗口"
grep -q 'link.rel = "noopener"' "$ROOT_DIR/reader-ui/app.js" || die "Reader 原文媒体入口未隔离 opener"
grep -q 'clearSelection: true, immediate: true' "$ROOT_DIR/reader-ui/app.js" || die "Reader 归档后不会立即退出正文"
grep -q 'data-reader-action="archive"' "$ROOT_DIR/reader-ui/app.js" || die "Reader 正文结尾缺少可点击归档操作"
grep -q '\[data-reader-action\], a\[href\]' "$ROOT_DIR/reader-ui/app.js" || die "Reader 透明滚动层未向正文结尾操作转发点击"
grep -q 'grid-template-columns: repeat(2, minmax(0, 1fr))' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 正文结尾收藏与归档未并排显示"
grep -q 'bindMobilePaneSwipe' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少公众号列表与文章列表双向滑动"
grep -q 'Math.abs(swipe.distance) >= 64' "$ROOT_DIR/reader-ui/app.js" || die "Reader 列表滑动缺少防误触阈值"
grep -q 'if (!swipe.moved) pane.element.setPointerCapture' "$ROOT_DIR/reader-ui/app.js" || die "Reader 列表仍会在轻点时抢走按钮指针"
grep -q 'state-chip' "$ROOT_DIR/reader-ui/app.js" || die "Reader 紧凑文章列表缺少状态标签"
grep -q 'history.replaceState({ readerView: "timeline" }' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未接管 Android 系统返回历史"
grep -q '\.reading-dock { display: none; }' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机布局未移除右下角悬浮条"
grep -q -- '--panel-radius: 0px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机最外层仍有圆角包围"
grep -q -- '--card-radius: 8px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机内部行未使用克制 8px 圆角"
grep -q 'border-radius: 4px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机标签未使用 4px 圆角"
grep -q 'backdrop-filter: blur(24px) saturate(108%)' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机外壳未使用克制的半透明磨砂"
grep -q 'function tagTone' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未按作者稳定分配彩虹色"
grep -q 'authorToneCount = 16' "$ROOT_DIR/reader-ui/app.js" || die "Reader 作者彩谱不足以区分当前公众号"
grep -q '\.tone-15' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 缺少完整的十六色作者彩谱"
grep -q 'background: var(--tone-ink);' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 文章行缺少柔和纯色作者谱线"
grep -q 'body::after { display: none; }' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机底色仍包含大面积极光装饰"
grep -q 'border-radius: 0;' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机文章列表仍保留外框圆角"
grep -q 'is-pane-swiping\[data-mobile-view="sources"\].*source-pane' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机列表缺少跟手横向位移"
grep -q 'contain-intrinsic-size: 66px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机文章列表仍不够紧凑"
grep -q 'rel="manifest"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 首页未声明 PWA manifest"
grep -q 'styles.css?v=31' "$ROOT_DIR/reader-ui/index.html" || die "Reader 桌面样式资源版本未刷新"
grep -q 'app.js?v=41' "$ROOT_DIR/reader-ui/index.html" || die "Reader 桌面交互资源版本未刷新"
grep -q 'embed.css?v=16' "$ROOT_DIR/reader-ui/app.js" || die "Reader 桌面正文主题资源版本未刷新"
grep -q '\.mobile-scroll-layer' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 缺少手机原生滚动触摸层样式"
if grep -q 'addEventListener("touchmove"' "$ROOT_DIR/reader-ui/app.js"; then
  die "Reader 仍使用 JavaScript 接管 touchmove，手机惯性滚动会卡顿"
fi
grep -q 'scrolling="yes"' "$ROOT_DIR/reader-ui/index.html" || die "Reader iframe 未显式允许手机滚动"
grep -q 'Shift+Enter 换行' "$ROOT_DIR/reader-ui/app.js" || die "Reader 快速批注缺少回车提示"
grep -q 'transparent.click()' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未同步原生 annotator 的透明划线状态"
grep -q 'rejectUnsafeArticleSelection' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未阻止跨出正文的整篇误选"
grep -q 'reader-pending-annotation' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 缺少待确认划线预览"
grep -q 'method: "DELETE"' "$ROOT_DIR/reader-ui/app.js" || die "Reader 点按划线未调用删除接口"
grep -q '点按取消划线' "$ROOT_DIR/reader-ui/app.js" || die "Reader 划线缺少直接取消提示"
grep -q 'targets.forEach(unwrapAnnotation)' "$ROOT_DIR/reader-ui/app.js" || die "Reader 取消划线仍需要刷新正文"
grep -q 'isMobileReader() || state.highlightMode' "$ROOT_DIR/reader-ui/app.js" || die "Reader 手机划线仍可能弹出笔记框"
grep -q 'data-reader-highlight-mode="false"' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 阅读模式未阻止手机误选全文"
grep -q 'annotator--colors' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 未隐藏原生高亮颜色选择"
grep -q 'env(safe-area-inset-bottom)' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机布局缺少底部安全区"
grep -q 'data-mobile-view="reader".*top-tabs' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机正文页未隐藏全局导航"
grep -q 'min-width: 44px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机端缺少 44px 触控目标"
grep -q 'position: fixed !important' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 手机快速笔记未使用键盘友好的底部面板"
if grep -q 'frameWindow.addEventListener("scroll"' "$ROOT_DIR/reader-ui/app.js"; then
  die "Reader 仍在 iframe window 上运行逐帧滚动监听"
fi
grep -q 'scheduleText' "$ROOT_DIR/reader-ui/app.js" || die "Reader 仍可能直接显示 Cron 表达式"
grep -q 'refreshControlRequest' "$ROOT_DIR/reader-ui/app.js" || die "Reader 刷新按钮未接入受保护控制端"
grep -q 'checking_werss' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少 WeRSS 检查状态"
grep -q 'syncing_reader' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少同步状态"
grep -q 'id="wechat-auth-dialog"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少微信授权二维码弹窗"
grep -q 'beginWeChatAuthorization' "$ROOT_DIR/reader-ui/app.js" || die "Reader 授权失效时不会自动拉起二维码"
grep -q 'auth_start' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未调用微信授权启动接口"
grep -q 'auth_status' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未轮询微信扫码状态"
grep -q 'parseResponsePayload' "$ROOT_DIR/reader-ui/app.js" || die "Reader HTTP 错误未结构化解析"
grep -q 'resumeRefreshAfterAuth' "$ROOT_DIR/reader-ui/app.js" || die "Reader 扫码后不会自动继续刷新"
if grep -q 'await response.text()).slice' "$ROOT_DIR/reader-ui/app.js"; then
  die "Reader 仍会把原始 HTTP 错误 JSON 直接显示给用户"
fi
if grep -R -nE '#9196ff|#a5a9ff|#8d93ff|#ffd8c2|rgba\((103, 111, 255|145, 150, 255|139, 145, 255|112, 119, 255|115, 122, 255|101, 77, 193)' \
  "$ROOT_DIR/reader-ui" "$ROOT_DIR/reader-theme"; then
  die "Reader 仍包含旧紫色或遮挡式选区颜色"
fi
if grep -R -nE '[—–]' "$ROOT_DIR/reader-ui"; then
  die "Reader 可见文案包含不一致的长破折号"
fi

screenshot_names=(
  09-reader-folo-inbox.png
  10-reader-top-tabs.png
  11-reader-one-click-favorite.png
  12-reader-subscriptions.png
  13-reader-value-tags.png
  14-reader-mobile.png
  15-reader-划线笔记与字号.png
)
for screenshot in "${screenshot_names[@]}"; do
  [[ -s "$ROOT_DIR/docs/images/$screenshot" ]] || die "缺少 Reader 验收截图：$screenshot"
done

printf '检查匿名与模拟 Access 身份边界...\n'
anonymous_root="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $reader_host" "$reader_url/")"
anonymous_api="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $reader_host" "$reader_url/api/bookmarks")"
[[ "$anonymous_root" == "403" && "$anonymous_api" == "403" ]] \
  || die "缺少 Access 身份时 Reader/API 不是 403/403"

curl -fsS "${headers[@]}" "$reader_url/" -o "$tmp_dir/index.html"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/styles.css" -o "$tmp_dir/styles.css"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/app.js" -o "$tmp_dir/app.js"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/embed.css" -o "$tmp_dir/embed.css"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/manifest.webmanifest" -o "$tmp_dir/manifest.webmanifest"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/icons/reader-192.png" -o "$tmp_dir/reader-192.png"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/icons/reader-512.png" -o "$tmp_dir/reader-512.png"
curl -fsS "${headers[@]}" "$reader_url/reader-runtime/status.json" -o "$tmp_dir/status.json"
curl -fsS "${headers[@]}" \
  -H "Origin: https://$reader_host" \
  -H 'Content-Type: application/json' \
  --data '{"action":"status"}' \
  "$reader_url/reader-control/refresh" -o "$tmp_dir/refresh.json"
refresh_get_status="$(curl -sS -o /dev/null -w '%{http_code}' "${headers[@]}" "$reader_url/reader-control/refresh")"
[[ "$refresh_get_status" == "404" ]] || die "刷新控制路径的 GET 请求不是 404"
authorized_api="$(curl -sS -o /dev/null -w '%{http_code}' "${headers[@]}" "$reader_url/api/bookmarks?limit=1")"
[[ "$authorized_api" == "200" ]] || die "模拟 Access 身份无法读取 Readeck API"
grep -q '<title>公众号阅读器</title>' "$tmp_dir/index.html" || die "公网根路径不是新 Reader UI"
grep -q -- '--timeline-width' "$tmp_dir/styles.css" || die "Reader 三栏样式未送达"
grep -q 'toggleFavorite' "$tmp_dir/app.js" || die "Reader 一键收藏逻辑未送达"
grep -q 'bookmark-sidebar' "$tmp_dir/embed.css" || die "Reader 沉浸正文样式未送达"

python3 - "$tmp_dir/manifest.webmanifest" "$tmp_dir/reader-192.png" "$tmp_dir/reader-512.png" <<'PY'
import json
import struct
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["start_url"] == "/"
assert manifest["scope"] == "/"
assert manifest["display"] == "standalone"
assert {item["sizes"] for item in manifest["icons"]} >= {"192x192", "512x512"}

for path, expected in ((Path(sys.argv[2]), 192), (Path(sys.argv[3]), 512)):
    payload = path.read_bytes()
    assert payload[:8] == b"\x89PNG\r\n\x1a\n"
    width, height = struct.unpack(">II", payload[16:24])
    assert (width, height) == (expected, expected)
PY

python3 - "$tmp_dir/status.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["version"] == 1
assert payload["cron"] == "17 * * * *"
assert payload["sync_interval_seconds"] == 300
assert payload["health"] in {"ok", "error"}
assert len(payload["feeds"]) > 0
required = {"name", "articles", "complete_articles", "readeck_articles", "unread", "health"}
assert all(required <= set(item) for item in payload["feeds"])
PY

python3 - "$tmp_dir/refresh.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["version"] == 1
assert payload["phase"] in {"idle", "checking_werss", "syncing_reader", "complete", "cooldown", "failed"}
assert "next_allowed_at" in payload
assert "cooldown_remaining_seconds" in payload
assert "secret" not in json.dumps(payload).lower()
PY

printf 'Reader UI 验证通过：手机与桌面统一的中性 Codex 风格、桌面扁平三栏、紧凑全屏阅读、Android PWA 独立窗口、稳定作者彩色标签、公众号/文章列表双向滑动、正文原生滚动与左滑返回、选中即划线与点按取消、未读默认与已读归档、桌面划线导出、受保护刷新状态机和 Access 边界均符合契约。\n'
