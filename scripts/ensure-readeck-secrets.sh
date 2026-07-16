#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command openssl
require_env_file

umask 077

append_if_missing() {
  local key="$1"
  local value="$2"
  if ! grep -qE "^${key}=" "$ENV_FILE"; then
    printf '%s=%s\n' "$key" "$value" >>"$ENV_FILE"
  fi
}

append_if_missing READECK_SECRET_KEY "$(openssl rand -hex 32)"
append_if_missing READECK_ADMIN_PASSWORD "$(openssl rand -hex 24)"
append_if_missing READECK_BASE_URL "http://127.0.0.1:8002/"
append_if_missing READECK_ALLOWED_HOSTS "127.0.0.1,localhost,readeck,reader.example.com"
append_if_missing HOST_UID "$(id -u)"
append_if_missing HOST_GID "$(id -g)"

chmod 600 "$ENV_FILE"
mkdir -p "$ROOT_DIR/readeck-data" "$ROOT_DIR/sync-state" "$ROOT_DIR/secrets"
chmod 700 "$ROOT_DIR/readeck-data" "$ROOT_DIR/sync-state" "$ROOT_DIR/secrets"

printf 'Readeck 密钥与本机目录已就绪；现有 .env 值未被覆盖。\n'
