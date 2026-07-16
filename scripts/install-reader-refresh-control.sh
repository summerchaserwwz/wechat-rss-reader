#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.summer.wechat-rss-reader-refresh"
RUNTIME_DIR="$HOME/.local/share/wechat-rss"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

"$ROOT_DIR/scripts/ensure-reader-refresh-secrets.sh"

mkdir -p "$RUNTIME_DIR" "$PLIST_DIR"
chmod 700 "$RUNTIME_DIR"
install -m 0755 "$ROOT_DIR/scripts/reader-refresh-control.py" "$RUNTIME_DIR/reader-refresh-control.py"
install -m 0644 "$ROOT_DIR/config/$LABEL.plist" "$PLIST_PATH"
/usr/bin/sed -i '' "s|__HOME__|$HOME|g" "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null

launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/$LABEL"

docker compose --project-directory "$ROOT_DIR" --env-file "$ROOT_DIR/.env" -f "$ROOT_DIR/compose.yaml" \
  up -d --force-recreate reader-caddy >/dev/null

for _ in $(seq 1 20); do
  if lsof -nP -iTCP:8787 -sTCP:LISTEN 2>/dev/null | grep -q '127.0.0.1:8787'; then
    printf 'Reader 主动刷新控制端已启用：仅监听 127.0.0.1:8787。\n'
    exit 0
  fi
  sleep 1
done

printf '错误：Reader 主动刷新控制端未在 20 秒内监听回环地址。\n' >&2
exit 1
