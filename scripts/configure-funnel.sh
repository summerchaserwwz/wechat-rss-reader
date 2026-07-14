#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
[[ -x "$TS" ]] || die "未找到 Tailscale CLI"
require_command jq
require_command docker
require_env_file

state="$($TS status --json 2>/dev/null | jq -r '.BackendState // "Unknown"' || true)"
if [[ "$state" != "Running" ]]; then
  open -a Tailscale
  die "Tailscale 当前未运行。请在菜单栏连接后重新执行本脚本"
fi

caddy_port="${CADDY_HOST_PORT:-$(env_value CADDY_HOST_PORT 8080)}"
prefix="$(env_value FEED_PREFIX)"

printf '正在为本机 Caddy 端口启用 Tailscale Funnel...\n'
if ! "$TS" funnel --bg --yes "$caddy_port"; then
  die "Funnel 未启用。首次使用通常需要在 Tailscale 网页批准 HTTPS 和 Funnel 权限，然后重试"
fi

host="$($TS status --json | jq -r '.Self.DNSName | rtrimstr(".")')"
[[ -n "$host" && "$host" != "null" ]] || die "无法读取 Tailscale DNS 名称"

rss_base_url="https://${host}/${prefix}/"
set_env_value RSS_BASE_URL "$rss_base_url"

docker_compose up -d --no-deps --force-recreate we-mp-rss >/dev/null
"$SCRIPT_DIR/verify.sh" --public

printf 'Funnel 已启用，RSS_BASE_URL 已写入 .env。\n'
printf '请把 .env 中的 RSS_BASE_URL 与 feed 路径组合后添加到 Folo；不要公开该随机地址。\n'
