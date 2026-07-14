#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command docker
require_command jq
require_env_file

"$SCRIPT_DIR/ensure-readeck-secrets.sh" >/dev/null

password="$(env_value READECK_ADMIN_PASSWORD)"
[[ ${#password} -ge 24 ]] || die "READECK_ADMIN_PASSWORD 长度不足 24 字符"

printf '拉取固定版本 Readeck 0.22.3...\n'
docker_compose pull readeck

check_json="$(
  BOOTSTRAP_PASSWORD="$password" docker_compose run --rm --no-deps \
    -e BOOTSTRAP_PASSWORD \
    readeck /bin/readeck user \
    -config config.toml \
    -user summer \
    -email summer@localhost \
    -group admin \
    -password env:BOOTSTRAP_PASSWORD \
    -dry-run \
    -json
)"

if [[ "$(jq -r '.exists' <<<"$check_json")" != "true" ]]; then
  BOOTSTRAP_PASSWORD="$password" docker_compose run --rm --no-deps \
    -e BOOTSTRAP_PASSWORD \
    readeck /bin/readeck user \
    -config config.toml \
    -user summer \
    -email summer@localhost \
    -group admin \
    -password env:BOOTSTRAP_PASSWORD \
    -json >/dev/null
  printf '已创建 Readeck 管理用户 summer。\n'
else
  printf 'Readeck 管理用户 summer 已存在，未修改现有密码。\n'
fi

docker_compose up -d readeck

ready=0
for _ in $(seq 1 60); do
  if curl -fsS --max-time 3 http://127.0.0.1:8002/ >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
(( ready == 1 )) || die "Readeck 在 120 秒内未就绪"

printf 'Readeck 已就绪：http://127.0.0.1:8002/\n'
printf '用户名：summer；密码保存在本机 .env 的 READECK_ADMIN_PASSWORD。\n'
