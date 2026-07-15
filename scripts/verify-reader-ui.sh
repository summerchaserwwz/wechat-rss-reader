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
reader_host="${READECK_PUBLIC_HOSTNAME:-reader.sumerchaser.top}"
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
tab_count="$(grep -c 'data-tab=' "$ROOT_DIR/reader-ui/index.html")"
[[ "$tab_count" == "6" ]] || die "Reader 顶部 Tab 不是 6 个（实际：$tab_count）"
if grep -R -nE 'https://|Authorization:[[:space:]]*Bearer|FEED_PREFIX|CF_ACCESS_AUD|readeck_api_token' "$ROOT_DIR/reader-ui"; then
  die "Reader 浏览器资源包含远程依赖或秘密标识"
fi
grep -q 'read_progress' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现阅读进度"
grep -q '价值/' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现价值标签"
grep -q '主题/' "$ROOT_DIR/reader-ui/app.js" || die "Reader 未实现主题标签"

printf '检查匿名与模拟 Access 身份边界...\n'
anonymous_root="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $reader_host" "$reader_url/")"
anonymous_api="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $reader_host" "$reader_url/api/bookmarks")"
[[ "$anonymous_root" == "403" && "$anonymous_api" == "403" ]] \
  || die "缺少 Access 身份时 Reader/API 不是 403/403"

curl -fsS "${headers[@]}" "$reader_url/" -o "$tmp_dir/index.html"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/styles.css" -o "$tmp_dir/styles.css"
curl -fsS "${headers[@]}" "$reader_url/reader-assets/app.js" -o "$tmp_dir/app.js"
curl -fsS "${headers[@]}" "$reader_url/reader-runtime/status.json" -o "$tmp_dir/status.json"
authorized_api="$(curl -sS -o /dev/null -w '%{http_code}' "${headers[@]}" "$reader_url/api/bookmarks?limit=1")"
[[ "$authorized_api" == "200" ]] || die "模拟 Access 身份无法读取 Readeck API"
grep -q '<title>公众号 Reader</title>' "$tmp_dir/index.html" || die "公网根路径不是新 Reader UI"
grep -q -- '--timeline-width' "$tmp_dir/styles.css" || die "Reader 三栏样式未送达"
grep -q 'toggleFavorite' "$tmp_dir/app.js" || die "Reader 一键收藏逻辑未送达"

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

printf 'Reader UI 验证通过：6 个 Tab、三栏资源、Access 403/403、授权 API、抓取状态和无前端秘密均符合契约。\n'
