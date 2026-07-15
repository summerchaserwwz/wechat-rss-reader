#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.summer.wechat-rss-reading-sync"
OLD_LABEL="com.summer.wechat-rss-obsidian-inbox"
RUNTIME_DIR="$HOME/.local/share/wechat-rss"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

[[ -f "$RUNTIME_DIR/readeck_api_token" ]] || {
  echo "缺少 $RUNTIME_DIR/readeck_api_token；请先在 Readeck 创建最小权限 API 令牌" >&2
  exit 1
}

mkdir -p "$RUNTIME_DIR" "$RUNTIME_DIR/public-status" "$PLIST_DIR"
chmod 700 "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR/public-status"
chmod 600 "$RUNTIME_DIR/readeck_api_token"
install -m 0755 "$ROOT_DIR/scripts/reading-sync.py" "$RUNTIME_DIR/reading-sync.py"
install -m 0644 "$ROOT_DIR/config/$LABEL.plist" "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null

launchctl bootout "$DOMAIN/$OLD_LABEL" >/dev/null 2>&1 || true
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "公众号阅读同步已启用：每 5 分钟检查 WeRSS、Readeck、Reader 状态与 Obsidian。"
