#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command docker
require_command tar
require_env_file

umask 077
mkdir -p "$ROOT_DIR/backups"
chmod 700 "$ROOT_DIR/backups"

stamp="$(date '+%Y%m%d-%H%M%S')"
archive="$ROOT_DIR/backups/wechat-rss-${stamp}.tar.gz"
tmp_archive="${archive}.tmp"
was_running=0

cleanup() {
  local status=$?
  rm -f "$tmp_archive"
  if (( was_running == 1 )); then
    docker_compose start we-mp-rss >/dev/null
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

if [[ "$(docker_compose ps --status running -q we-mp-rss)" != "" ]]; then
  was_running=1
  printf '短暂停止 WeRSS 以获得一致性备份...\n'
  docker_compose stop -t 30 we-mp-rss >/dev/null
fi

[[ -d "$ROOT_DIR/data" ]] || die "data/ 不存在"

tar -C "$ROOT_DIR" -czf "$tmp_archive" \
  data \
  .env \
  compose.yaml \
  Caddyfile \
  .env.example \
  README.md

tar -tzf "$tmp_archive" >/dev/null
mv "$tmp_archive" "$archive"
chmod 600 "$archive"

if (( was_running == 1 )); then
  docker_compose start we-mp-rss >/dev/null
  was_running=0
fi

trap - EXIT INT TERM
printf '备份完成：%s\n' "$archive"
