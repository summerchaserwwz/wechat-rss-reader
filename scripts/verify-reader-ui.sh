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
tab_count="$(grep -c 'data-tab=' "$ROOT_DIR/reader-ui/index.html")"
[[ "$tab_count" == "6" ]] || die "Reader 顶部 Tab 不是 6 个（实际：$tab_count）"
shortcut_count="$(grep -c 'aria-keyshortcuts="[1-6]"' "$ROOT_DIR/reader-ui/index.html")"
[[ "$shortcut_count" == "6" ]] || die "Reader 顶部 Tab 快捷键不是 1–6 六个"
if grep -R -nE 'https://|Authorization:[[:space:]]*Bearer|FEED_PREFIX|CF_ACCESS_AUD|readeck_api_token' "$ROOT_DIR/reader-ui"; then
  die "Reader 浏览器资源包含远程依赖或秘密标识"
fi
grep -q 'read_progress' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现阅读进度"
grep -q 'ratio >= 0.8' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现 80% 自动已读阈值"
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

printf 'Reader UI 验证通过：Apple 磨砂阅读控件、淡绿虚线选区/批注、原位笔记、Markdown/Obsidian 导出、字号/自动已读、受保护刷新状态机和 Access 边界均符合契约。\n'
