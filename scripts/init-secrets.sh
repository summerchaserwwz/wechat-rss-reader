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
readeck_secret_key="$(openssl rand -hex 32)"
readeck_admin_password="$(openssl rand -hex 24)"

{
  printf 'WERSS_ADMIN_USERNAME=werss_admin\n'
  printf 'WERSS_BOOTSTRAP_PASSWORD=%s\n' "$password"
  printf 'SAFE_LIC_KEY=%s\n' "$lic_key"
  printf 'FEED_PREFIX=%s\n' "$feed_prefix"
  printf 'RSS_BASE_URL=http://127.0.0.1:8001/\n'
  printf 'READECK_SECRET_KEY=%s\n' "$readeck_secret_key"
  printf 'READECK_ADMIN_PASSWORD=%s\n' "$readeck_admin_password"
  printf 'READECK_BASE_URL=http://127.0.0.1:8002/\n'
  printf 'OBSIDIAN_INBOX_DIR=%s\n' "$HOME/Documents/Obsidian/reading/readeck_inbox"
  printf 'READECK_ALLOWED_HOSTS=127.0.0.1,localhost,readeck,reader.example.com\n'
  printf 'READECK_PUBLIC_HOSTNAME=reader.example.com\n'
  printf 'WERSS_PUBLIC_HOSTNAME=werss.example.com\n'
  printf 'HOST_UID=%s\n' "$(id -u)"
  printf 'HOST_GID=%s\n' "$(id -g)"
} >"$tmp"

chmod 600 "$tmp"
mv "$tmp" "$ENV_FILE"
trap - EXIT

mkdir -p "$ROOT_DIR/data" "$ROOT_DIR/backups" "$ROOT_DIR/observations" "$ROOT_DIR/readeck-data" "$ROOT_DIR/sync-state" "$ROOT_DIR/secrets"
chmod 700 "$ROOT_DIR/data" "$ROOT_DIR/backups" "$ROOT_DIR/observations" "$ROOT_DIR/readeck-data" "$ROOT_DIR/sync-state" "$ROOT_DIR/secrets"

printf '已创建 .env（权限 600）及 WeRSS、Readeck、同步与备份目录。\n'
printf 'WeRSS 管理用户名与密码只保存在本机 .env；默认用户名为 werss_admin。\n'
printf 'Readeck 管理用户名固定为 summer；密码只保存在本机 .env。\n'
