#!/usr/bin/env bash

set -Eeuo pipefail

LABEL="com.summer.wechat-rss-cloudflared"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
printf '已停止本机 Cloudflare Tunnel。DNS 与 Cloudflare Tunnel 对象未删除，便于安全恢复。\n'
