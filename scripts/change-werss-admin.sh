#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command docker
require_command sqlite3
require_command htpasswd
require_env_file

new_user="${1:-}"
[[ "$new_user" =~ ^[A-Za-z0-9_-]{3,32}$ ]] \
  || die "用法：scripts/change-werss-admin.sh <3-32 位字母、数字、下划线或连字符用户名>"

printf '新密码（至少 8 位，推荐 24 位随机值；输入不回显）：'
IFS= read -r -s new_password
printf '\n再次输入新密码：'
IFS= read -r -s confirmation
printf '\n'
[[ "$new_password" == "$confirmation" ]] || die "两次密码不一致"
[[ ${#new_password} -ge 8 ]] || die "密码不能少于 8 位"

"$SCRIPT_DIR/backup.sh"

hash="$(/usr/sbin/htpasswd -bnBC 12 '' "$new_password" | tr -d '\n')"
hash="${hash#:}"
hash="${hash/\$2y\$/\$2b\$}"
[[ "$hash" == \$2b\$12\$* ]] || die "无法生成 bcrypt 密码哈希"

docker_compose stop werss-public-caddy caddy we-mp-rss >/dev/null
sqlite3 "$ROOT_DIR/data/we_mp_rss.db" \
  "begin immediate; update users set username='$new_user', nickname='$new_user', password_hash='$hash', updated_at=datetime('now') where id='0'; commit;"
set_env_value WERSS_ADMIN_USERNAME "$new_user"
set_env_value WERSS_BOOTSTRAP_PASSWORD "$new_password"
unset new_password confirmation hash
docker_compose up -d we-mp-rss caddy werss-public-caddy >/dev/null

printf 'WeRSS 管理账号已更新；请在 http://127.0.0.1:8001/login 验证登录。\n'
