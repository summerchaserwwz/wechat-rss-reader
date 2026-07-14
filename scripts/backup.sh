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
stage="$(mktemp -d "$ROOT_DIR/backups/.backup-stage.XXXXXX")"
was_running_werss=0
was_running_readeck=0
was_running_reader_caddy=0

cleanup() {
  local status=$?
  rm -f "$tmp_archive"
  rm -rf "$stage"
  if (( was_running_werss == 1 )); then
    docker_compose start we-mp-rss >/dev/null
  fi
  if (( was_running_readeck == 1 )); then
    docker_compose start readeck >/dev/null
  fi
  if (( was_running_reader_caddy == 1 )); then
    docker_compose start reader-caddy >/dev/null
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

if [[ "$(docker_compose ps --status running -q we-mp-rss)" != "" ]]; then
  was_running_werss=1
fi
if [[ "$(docker_compose ps --status running -q readeck)" != "" ]]; then
  was_running_readeck=1
fi
if [[ "$(docker_compose ps --status running -q reader-caddy)" != "" ]]; then
  was_running_reader_caddy=1
fi

printf '短暂停止 WeRSS 与 Readeck 以获得一致性 SQLite 备份...\n'
docker_compose stop -t 30 we-mp-rss readeck reader-caddy >/dev/null

[[ -d "$ROOT_DIR/data" ]] || die "data/ 不存在"
[[ -d "$ROOT_DIR/readeck-data" ]] || die "readeck-data/ 不存在"
[[ -f "$ROOT_DIR/secrets/readeck_api_token" ]] || die "缺少 Readeck API 令牌备份源"
runtime_dir="$HOME/.local/share/wechat-rss"
[[ -f "$runtime_dir/reading-sync.sqlite3" ]] || die "缺少实际运行中的阅读同步状态数据库"
[[ -f "$runtime_dir/readeck_api_token" ]] || die "缺少实际运行中的 Readeck API Token"
cmp -s "$ROOT_DIR/secrets/readeck_api_token" "$runtime_dir/readeck_api_token" \
  || die "源 API Token 与 LaunchAgent 运行时 Token 不一致，请先重新安装同步器"

mkdir -p "$stage/runtime" "$stage/cloudflared"
chmod 700 "$stage/runtime" "$stage/cloudflared"
install -m 0600 "$runtime_dir/reading-sync.sqlite3" "$stage/runtime/reading-sync.sqlite3"
install -m 0600 "$runtime_dir/readeck_api_token" "$stage/runtime/readeck_api_token"
if [[ -f "$HOME/.cloudflared/wechat-rss.yml" ]]; then
  install -m 0600 "$HOME/.cloudflared/wechat-rss.yml" "$stage/cloudflared/wechat-rss.yml"
  tunnel_credentials="$(awk '$1 == "credentials-file:" { print $2; exit }' "$HOME/.cloudflared/wechat-rss.yml")"
  if [[ -n "$tunnel_credentials" && -f "$tunnel_credentials" ]]; then
    install -m 0600 "$tunnel_credentials" "$stage/cloudflared/$(basename "$tunnel_credentials")"
  fi
fi

tar -C "$ROOT_DIR" -czf "$tmp_archive" \
  data \
  readeck-data \
  secrets \
  .env \
  compose.yaml \
  Caddyfile \
  Caddyfile.reader \
  .env.example \
  README.md \
  -C "$stage" \
  runtime \
  cloudflared

tar -tzf "$tmp_archive" >/dev/null
mv "$tmp_archive" "$archive"
chmod 600 "$archive"
rm -rf "$stage"

if (( was_running_werss == 1 )); then
  docker_compose start we-mp-rss >/dev/null
  was_running_werss=0
fi
if (( was_running_readeck == 1 )); then
  docker_compose start readeck >/dev/null
  was_running_readeck=0
fi
if (( was_running_reader_caddy == 1 )); then
  docker_compose start reader-caddy >/dev/null
  was_running_reader_caddy=0
fi

trap - EXIT INT TERM
printf '备份完成：%s\n' "$archive"
