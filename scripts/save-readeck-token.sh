#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

runtime_dir="$HOME/.local/share/wechat-rss"
runtime_file="$runtime_dir/readeck_api_token"
backup_file="$ROOT_DIR/secrets/readeck_api_token"

printf '请粘贴 Readeck API Token（输入不会回显）：'
IFS= read -r -s token
printf '\n'

token="${token//$'\r'/}"
token="${token//$'\n'/}"
[[ ${#token} -ge 20 ]] || die "API Token 长度异常"

umask 077
mkdir -p "$runtime_dir" "$ROOT_DIR/secrets"
chmod 700 "$runtime_dir" "$ROOT_DIR/secrets"
printf '%s\n' "$token" >"$runtime_file"
printf '%s\n' "$token" >"$backup_file"
chmod 600 "$runtime_file" "$backup_file"
unset token

printf 'Readeck API Token 已保存到受 Git 忽略、权限为 600 的运行时与备份源文件。\n'
