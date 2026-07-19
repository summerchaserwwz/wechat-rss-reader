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
grep -q -- '--panel-radius: 20px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 未使用统一的紧凑磨砂面板圆角"
grep -q 'backdrop-filter: blur(22px)' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 未保留顶部与来源栏磨砂材质"
grep -q 'background: var(--accent-strong)' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 主操作未使用高对比科技蓝胶囊"
grep -q -- '--canvas: #070b14' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 未使用近黑科技蓝画布"
grep -q -- '--accent: #2f7cf6' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 未使用钴蓝主强调色"
grep -q -- '--annotation-line: #8ad4a8' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 缺少淡绿色划线 token"
grep -q 'font-family: "SF Pro Text"' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 正文未使用中文友好的系统字体"
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
grep -q 'id="article-loading"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少正文加载骨架"
grep -q 'id="highlight-mode"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少显式划线模式控制"
grep -q 'timelineLimit: 60' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未限制初始时间线 DOM 数量"
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
grep -q 'id="install-app"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 手机设置缺少安装到桌面入口"
grep -q 'id="edge-back-indicator"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 缺少边缘返回提示"
grep -q 'bindEdgeSwipeBack' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少左边缘返回手势"
grep -q 'saveCurrentReadingProgress' "$ROOT_DIR/reader-ui/app.js" || die "Reader 返回前未保存阅读进度"
grep -q 'bindMobilePaneSwipe' "$ROOT_DIR/reader-ui/app.js" || die "Reader 缺少公众号列表与文章列表双向滑动"
grep -q 'Math.abs(swipe.distance) >= 64' "$ROOT_DIR/reader-ui/app.js" || die "Reader 列表滑动缺少防误触阈值"
grep -q 'state-chip' "$ROOT_DIR/reader-ui/app.js" || die "Reader 紧凑文章列表缺少状态标签"
grep -q 'history.replaceState({ readerView: "timeline" }' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未接管 Android 系统返回历史"
grep -q '\.reading-dock { display: none; }' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机布局未移除右下角悬浮条"
grep -q -- '--panel-radius: 0px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机列表未移除面板圆角"
grep -q 'is-pane-swiping\[data-mobile-view="sources"\].*source-pane' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机列表缺少跟手横向位移"
grep -q 'contain-intrinsic-size: 68px' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 手机文章列表仍不够紧凑"
grep -q 'rel="manifest"' "$ROOT_DIR/reader-ui/index.html" || die "Reader 首页未声明 PWA manifest"
grep -q '\.mobile-scroll-layer' "$ROOT_DIR/reader-ui/styles.css" || die "Reader 缺少手机原生滚动触摸层样式"
if grep -q 'addEventListener("touchmove"' "$ROOT_DIR/reader-ui/app.js"; then
  die "Reader 仍使用 JavaScript 接管 touchmove，手机惯性滚动会卡顿"
fi
grep -q 'scrolling="yes"' "$ROOT_DIR/reader-ui/index.html" || die "Reader iframe 未显式允许手机滚动"
grep -q 'Shift+Enter 换行' "$ROOT_DIR/reader-ui/app.js" || die "Reader 快速批注缺少回车提示"
grep -q 'transparent.click()' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未同步原生 annotator 的透明划线状态"
grep -q 'rejectUnsafeArticleSelection' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未阻止跨出正文的整篇误选"
grep -q 'reader-pending-annotation' "$ROOT_DIR/reader-ui/embed.css" || die "Reader 缺少待确认划线预览"
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

printf 'Reader UI 验证通过：Android PWA 独立窗口、Codex 风格无圆角紧凑列表、公众号/文章列表双向滑动、正文左边缘返回并保存进度、未读默认与已读归档、手机无悬浮条、桌面划线与导出、受保护刷新状态机和 Access 边界均符合契约。\n'
