#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command open
require_env_file

mode="${1:---local}"

case "$mode" in
  --local)
    port="${READER_CADDY_HOST_PORT:-$(env_value READER_CADDY_HOST_PORT 8082)}"
    base_url="http://127.0.0.1:${port}"
    ;;
  --public)
    base_url="https://reader.sumerchaser.top"
    ;;
  *)
    die "用法：scripts/open-reader.sh [--local|--public]"
    ;;
esac

open "${base_url}/bookmarks/unread"
printf '已打开阅读器。公网首次访问将由设备授权层确认身份。\n'
