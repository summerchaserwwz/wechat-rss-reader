#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

warn() {
  printf '警告：%s\n' "$*" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

require_env_file() {
  [[ -f "$ENV_FILE" ]] || die "缺少 .env，请先运行 scripts/init-secrets.sh"
  [[ "$(stat -f '%Lp' "$ENV_FILE")" == "600" ]] || warn ".env 权限不是 600，建议运行 chmod 600 .env"
}

env_value() {
  local key="$1"
  local fallback="${2:-}"
  local value

  value="$(awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE")"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '%s' "$fallback"
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  local tmp

  require_env_file
  tmp="$(mktemp "$ROOT_DIR/.env.tmp.XXXXXX")"
  chmod 600 "$tmp"
  awk -F= -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    $1 == key { print key "=" value; replaced = 1; next }
    { print }
    END { if (!replaced) print key "=" value }
  ' "$ENV_FILE" >"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

docker_compose() {
  require_env_file
  docker compose \
    --project-directory "$ROOT_DIR" \
    --env-file "$ENV_FILE" \
    -f "$ROOT_DIR/compose.yaml" \
    "$@"
}
