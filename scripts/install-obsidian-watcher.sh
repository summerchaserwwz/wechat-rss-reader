#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.summer.wechat-rss-obsidian-inbox"
RUNTIME_DIR="$HOME/.local/share/wechat-rss"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

mkdir -p "$RUNTIME_DIR" "$PLIST_DIR"
install -m 0755 "$ROOT_DIR/scripts/prepare-obsidian-inbox.py" "$RUNTIME_DIR/prepare-obsidian-inbox.py"
install -m 0644 "$ROOT_DIR/config/$LABEL.plist" "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null

launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "Obsidian 收件箱整理任务已启用：每 60 秒检查一次。"
