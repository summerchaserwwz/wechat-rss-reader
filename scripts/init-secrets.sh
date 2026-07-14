#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command openssl

if [[ -e "$ENV_FILE" ]]; then
  die ".env 已存在；为避免覆盖现有密钥，本脚本已停止"
fi

umask 077
tmp="$(mktemp "$ROOT_DIR/.env.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

password="$(openssl rand -hex 24)"
lic_key="$(openssl rand -hex 32)"
feed_prefix="rss-$(openssl rand -hex 24)"

{
  printf 'WERSS_BOOTSTRAP_PASSWORD=%s\n' "$password"
  printf 'SAFE_LIC_KEY=%s\n' "$lic_key"
  printf 'FEED_PREFIX=%s\n' "$feed_prefix"
  printf 'RSS_BASE_URL=http://127.0.0.1:8001/\n'
} >"$tmp"

chmod 600 "$tmp"
mv "$tmp" "$ENV_FILE"
trap - EXIT

mkdir -p "$ROOT_DIR/data" "$ROOT_DIR/backups" "$ROOT_DIR/observations"
chmod 700 "$ROOT_DIR/data" "$ROOT_DIR/backups" "$ROOT_DIR/observations"

printf '已创建 .env（权限 600）、data/、backups/ 和 observations/。\n'
printf 'Bootstrap 用户名固定为 werss_admin；密码只保存在本机 .env。\n'
