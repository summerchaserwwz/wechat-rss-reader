#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command tar
require_command sqlite3
require_command curl

archive="${1:-}"
if [[ -z "$archive" ]]; then
  archive="$(find "$ROOT_DIR/backups" -maxdepth 1 -type f -name 'wechat-rss-*.tar.gz' -print | sort | tail -n 1)"
fi
[[ -n "$archive" && -f "$archive" ]] || die "找不到备份；用法：scripts/restore-test.sh [备份文件]"

umask 077
stamp="$(date '+%Y%m%d-%H%M%S')"
restore_dir="$ROOT_DIR/backups/restore-tests/$stamp"
mkdir -p "$restore_dir"
chmod 700 "$restore_dir"
tar -xzf "$archive" -C "$restore_dir"

[[ -f "$restore_dir/.env" ]] || die "备份缺少 .env"
[[ -f "$restore_dir/compose.yaml" ]] || die "备份缺少 compose.yaml"
[[ -f "$restore_dir/Caddyfile" ]] || die "备份缺少 Caddyfile"
db_file="$restore_dir/data/we_mp_rss.db"
[[ -f "$db_file" ]] || die "备份缺少 data/we_mp_rss.db"

integrity="$(sqlite3 "$db_file" 'PRAGMA integrity_check;')"
[[ "$integrity" == "ok" ]] || die "SQLite 完整性检查失败：$integrity"
printf '离线恢复检查通过：归档完整，SQLite integrity_check=ok。\n'

if [[ -f "$restore_dir/data/wx.lic" ]]; then
  printf '已找到 wx.lic，微信授权文件包含在备份中。\n'
else
  warn "未找到 wx.lic；若尚未完成微信授权，这是正常的"
fi
if [[ -f "$restore_dir/data/key.lic" ]]; then
  printf '已找到 key.lic；它与 .env 中稳定的 SAFE_LIC_KEY 共同保护授权数据。\n'
else
  warn "未找到 key.lic；完成微信授权后应再次备份并复验"
fi
if [[ -f "$restore_dir/data/.secret_key" ]]; then
  printf '已找到 data/.secret_key，登录 Token 密钥已包含在备份中。\n'
else
  warn "未找到 data/.secret_key；WeRSS 首次成功启动后应再次备份"
fi

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  warn "Docker daemon 不可用，跳过独立容器启动；恢复目录保留在 $restore_dir"
  exit 0
fi

find_free_port() {
  local port
  for port in $(jot -r 100 18000 19999); do
    if ! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      printf '%s' "$port"
      return 0
    fi
  done
  return 1
}

werss_port="$(find_free_port)"
caddy_port="$(find_free_port)"
while [[ "$caddy_port" == "$werss_port" ]]; do
  caddy_port="$(find_free_port)"
done

project="wechat-rss-restore-${stamp}"
cleanup_stack() {
  COMPOSE_PROJECT_NAME="$project" \
  WERSS_HOST_PORT="$werss_port" \
  CADDY_HOST_PORT="$caddy_port" \
    docker compose --project-directory "$restore_dir" --env-file "$restore_dir/.env" -f "$restore_dir/compose.yaml" down >/dev/null 2>&1 || true
}
trap cleanup_stack EXIT INT TERM

COMPOSE_PROJECT_NAME="$project" \
WERSS_HOST_PORT="$werss_port" \
CADDY_HOST_PORT="$caddy_port" \
  docker compose --project-directory "$restore_dir" --env-file "$restore_dir/.env" -f "$restore_dir/compose.yaml" up -d >/dev/null

ready=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 "http://127.0.0.1:${werss_port}/" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
(( ready == 1 )) || die "恢复实例在 120 秒内未就绪"

prefix="$(awk -F= '$1 == "FEED_PREFIX" { sub(/^[^=]*=/, ""); print; exit }' "$restore_dir/.env")"
root_status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${caddy_port}/")"
feed_status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${caddy_port}/${prefix}/feed/all.atom")"
[[ "$root_status" == "404" ]] || die "恢复实例 Caddy 根路径不是 404"
[[ "$feed_status" == "200" ]] || die "恢复实例 Feed 不是 200"

cleanup_stack
trap - EXIT INT TERM
printf '独立容器恢复演练通过；测试实例已关闭，恢复目录保留在：%s\n' "$restore_dir"
