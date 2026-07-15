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
[[ -f "$restore_dir/Caddyfile.reader" ]] || die "备份缺少 Caddyfile.reader"
[[ -f "$restore_dir/reader-theme/reader.css" ]] || die "备份缺少 Reader 自定义主题"
db_file="$restore_dir/data/we_mp_rss.db"
[[ -f "$db_file" ]] || die "备份缺少 data/we_mp_rss.db"
readeck_db="$restore_dir/readeck-data/data/db.sqlite3"
[[ -f "$readeck_db" ]] || die "备份缺少 Readeck 数据库"
sync_db="$restore_dir/runtime/reading-sync.sqlite3"
[[ -f "$sync_db" ]] || die "备份缺少阅读同步状态数据库"
[[ -f "$restore_dir/secrets/readeck_api_token" ]] || die "备份缺少 Readeck API 令牌"
[[ -f "$restore_dir/runtime/readeck_api_token" ]] || die "备份缺少运行时 Readeck API 令牌"

integrity="$(sqlite3 "$db_file" 'PRAGMA integrity_check;')"
[[ "$integrity" == "ok" ]] || die "SQLite 完整性检查失败：$integrity"
readeck_integrity="$(sqlite3 "$readeck_db" 'PRAGMA integrity_check;')"
[[ "$readeck_integrity" == "ok" ]] || die "Readeck SQLite 完整性检查失败：$readeck_integrity"
sync_integrity="$(sqlite3 "$sync_db" 'PRAGMA integrity_check;')"
[[ "$sync_integrity" == "ok" ]] || die "同步状态 SQLite 完整性检查失败：$sync_integrity"
expected_users="$(sqlite3 "$readeck_db" 'select count(*) from user;')"
expected_bookmarks="$(sqlite3 "$readeck_db" 'select count(*) from bookmark;')"
expected_marked="$(sqlite3 "$readeck_db" 'select count(*) from bookmark where is_marked=1;')"
expected_annotated="$(sqlite3 "$readeck_db" "select count(*) from bookmark where annotations not in ('','[]','null');")"
(( expected_users >= 1 )) || die "Readeck 备份中没有用户"
printf '离线恢复检查通过：三个 SQLite 数据库 integrity_check=ok；Readeck 有 %s 个用户、%s 篇文章、%s 个收藏、%s 篇含批注。\n' \
  "$expected_users" "$expected_bookmarks" "$expected_marked" "$expected_annotated"
cmp -s "$restore_dir/secrets/readeck_api_token" "$restore_dir/runtime/readeck_api_token" \
  || die "源 API 令牌与运行时 API 令牌不一致"
if [[ -f "$restore_dir/cloudflared/wechat-rss.yml" ]]; then
  credentials_name="$(awk '$1 == "credentials-file:" { value=$2; sub(/^.*\//, "", value); print value; exit }' "$restore_dir/cloudflared/wechat-rss.yml")"
  [[ -n "$credentials_name" && -f "$restore_dir/cloudflared/$credentials_name" ]] \
    || die "Cloudflare Tunnel 配置存在但凭据文件缺失"
  printf 'Cloudflare Tunnel 本机配置与作用域凭据已包含；恢复演练不会启动第二个公网副本。\n'
fi

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
readeck_port="$(find_free_port)"
reader_caddy_port="$(find_free_port)"
while [[ "$caddy_port" == "$werss_port" || "$readeck_port" == "$werss_port" || "$readeck_port" == "$caddy_port" || "$reader_caddy_port" == "$werss_port" || "$reader_caddy_port" == "$caddy_port" || "$reader_caddy_port" == "$readeck_port" ]]; do
  caddy_port="$(find_free_port)"
  readeck_port="$(find_free_port)"
  reader_caddy_port="$(find_free_port)"
done

project="wechat-rss-restore-${stamp}"
cleanup_stack() {
  COMPOSE_PROJECT_NAME="$project" \
  WERSS_HOST_PORT="$werss_port" \
  CADDY_HOST_PORT="$caddy_port" \
  READECK_HOST_PORT="$readeck_port" \
  READER_CADDY_HOST_PORT="$reader_caddy_port" \
  READECK_BASE_URL="http://127.0.0.1:${readeck_port}/" \
    docker compose --project-directory "$restore_dir" --env-file "$restore_dir/.env" -f "$restore_dir/compose.yaml" down >/dev/null 2>&1 || true
}
trap cleanup_stack EXIT INT TERM

COMPOSE_PROJECT_NAME="$project" \
WERSS_HOST_PORT="$werss_port" \
CADDY_HOST_PORT="$caddy_port" \
READECK_HOST_PORT="$readeck_port" \
READER_CADDY_HOST_PORT="$reader_caddy_port" \
READECK_BASE_URL="http://127.0.0.1:${readeck_port}/" \
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

readeck_ready=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 "http://127.0.0.1:${readeck_port}/" >/dev/null 2>&1; then
    readeck_ready=1
    break
  fi
  sleep 2
done
(( readeck_ready == 1 )) || die "恢复 Readeck 在 120 秒内未就绪"

caddy_ready=0
for _ in $(seq 1 30); do
  caddy_probe="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${caddy_port}/" 2>/dev/null || true)"
  if [[ "$caddy_probe" == "404" ]]; then
    caddy_ready=1
    break
  fi
  sleep 1
done
(( caddy_ready == 1 )) || die "恢复 Feed Caddy 在 30 秒内未就绪"

reader_caddy_ready=0
for _ in $(seq 1 30); do
  reader_probe="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 \
    "http://127.0.0.1:${reader_caddy_port}/" 2>/dev/null || true)"
  if [[ "$reader_probe" == "303" ]]; then
    reader_caddy_ready=1
    break
  fi
  sleep 1
done
(( reader_caddy_ready == 1 )) || die "恢复 Reader Caddy 在 30 秒内未就绪"

api_token="$(tr -d '\r\n' <"$restore_dir/runtime/readeck_api_token")"
api_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
  -H "Authorization: Bearer $api_token" \
  "http://127.0.0.1:${readeck_port}/api/bookmarks?limit=1")"
[[ "$api_status" == "200" ]] || die "恢复实例的 Readeck API Token 无法读取书签"

prefix="$(awk -F= '$1 == "FEED_PREFIX" { sub(/^[^=]*=/, ""); print; exit }' "$restore_dir/.env")"
root_status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${caddy_port}/")"
feed_status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${caddy_port}/${prefix}/feed/all.atom")"
[[ "$root_status" == "404" ]] || die "恢复实例 Caddy 根路径不是 404"
[[ "$feed_status" == "200" ]] || die "恢复实例 Feed 不是 200"
reader_status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${reader_caddy_port}/")"
reader_api_status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${reader_caddy_port}/api/bookmarks")"
[[ "$reader_status" == "303" ]] || die "恢复实例 Readeck 反代没有跳转到登录页"
[[ "$reader_api_status" == "401" ]] || die "恢复实例 Readeck 未登录 API 不是 401"
reader_public_status="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: reader.sumerchaser.top' "http://127.0.0.1:${reader_caddy_port}/")"
reader_public_api_status="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: reader.sumerchaser.top' "http://127.0.0.1:${reader_caddy_port}/api/bookmarks")"
[[ "$reader_public_status" == "403" ]] || die "恢复实例缺少 Access 身份时 Reader 公网 Host 根路径不是 403"
[[ "$reader_public_api_status" == "403" ]] || die "恢复实例缺少 Access 身份时 Reader 公网 Host API 不是 403"

actual_users="$(sqlite3 "$readeck_db" 'select count(*) from user;')"
actual_bookmarks="$(sqlite3 "$readeck_db" 'select count(*) from bookmark;')"
actual_marked="$(sqlite3 "$readeck_db" 'select count(*) from bookmark where is_marked=1;')"
actual_annotated="$(sqlite3 "$readeck_db" "select count(*) from bookmark where annotations not in ('','[]','null');")"
[[ "$actual_users:$actual_bookmarks:$actual_marked:$actual_annotated" == "$expected_users:$expected_bookmarks:$expected_marked:$expected_annotated" ]] \
  || die "恢复后 Readeck 用户/文章/收藏/批注计数不一致"

cleanup_stack
trap - EXIT INT TERM
printf '独立容器恢复演练通过：WeRSS Feed、Readeck 登录、文章、收藏、批注与同步状态均已验证；测试实例已关闭，恢复目录保留在：%s\n' "$restore_dir"
