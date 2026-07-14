#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
[[ -x "$TS" ]] || die "未找到 Tailscale CLI"
require_command docker
require_env_file

"$TS" funnel reset
werss_port="${WERSS_HOST_PORT:-$(env_value WERSS_HOST_PORT 8001)}"
set_env_value RSS_BASE_URL "http://127.0.0.1:${werss_port}/"
docker_compose up -d --no-deps --force-recreate we-mp-rss >/dev/null
"$SCRIPT_DIR/verify.sh" --local
printf 'Funnel 已清空，WeRSS 已恢复为本机 RSS_BASE_URL。\n'
