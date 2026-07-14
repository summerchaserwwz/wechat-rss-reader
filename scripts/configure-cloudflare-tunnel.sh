#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CLOUDFLARED="${CLOUDFLARED:-$HOME/.local/bin/cloudflared}"
TUNNEL_NAME="${TUNNEL_NAME:-wechat-rss}"
HOSTNAME="${READECK_PUBLIC_HOSTNAME:-reader.sumerchaser.top}"
CONFIG_DIR="$HOME/.cloudflared"
CONFIG_FILE="$CONFIG_DIR/wechat-rss.yml"
LABEL="com.summer.wechat-rss-cloudflared"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

[[ -x "$CLOUDFLARED" ]] || die "找不到 cloudflared：$CLOUDFLARED"
require_command jq
require_command curl
require_env_file

docker_compose up -d readeck reader-caddy >/dev/null
curl -fsS --max-time 10 -H "Host: $HOSTNAME" http://127.0.0.1:8082/ >/dev/null \
  || die "本机 Readeck 反代尚未就绪"

mkdir -p "$CONFIG_DIR" "$PLIST_DIR"
chmod 700 "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/cert.pem" ]]; then
  printf '即将打开 Cloudflare 授权页；请选择管理 %s 的账号。\n' "$HOSTNAME"
  "$CLOUDFLARED" tunnel login
fi

tunnel_id="$(
  "$CLOUDFLARED" tunnel list --name "$TUNNEL_NAME" --output json \
    | jq -r 'map(select(.name == "'"$TUNNEL_NAME"'" and (.deletedAt == null or .deletedAt == ""))) | first | .id // empty'
)"

if [[ -z "$tunnel_id" ]]; then
  tunnel_id="$("$CLOUDFLARED" tunnel create --output json "$TUNNEL_NAME" | jq -r '.id')"
fi

[[ "$tunnel_id" =~ ^[0-9a-f-]{36}$ ]] || die "Cloudflare Tunnel ID 格式异常"
credentials="$CONFIG_DIR/$tunnel_id.json"
[[ -f "$credentials" ]] || die "缺少 Tunnel 凭据文件：$credentials"
chmod 600 "$credentials" "$CONFIG_DIR/cert.pem"

configured_tunnel=""
if [[ -f "$CONFIG_FILE" ]]; then
  configured_tunnel="$(awk '$1 == "tunnel:" { print $2; exit }' "$CONFIG_FILE")"
fi
if [[ "$configured_tunnel" != "$tunnel_id" ]] || ! grep -qE "^[[:space:]]*-[[:space:]]+hostname:[[:space:]]+$HOSTNAME$" "$CONFIG_FILE" 2>/dev/null; then
  # 不使用 --overwrite-dns：若同名记录已属于其他服务，必须人工判断，不能静默覆盖。
  "$CLOUDFLARED" tunnel route dns "$tunnel_id" "$HOSTNAME"
fi

tmp="$(mktemp "$CONFIG_DIR/wechat-rss.yml.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
chmod 600 "$tmp"
{
  printf 'tunnel: %s\n' "$tunnel_id"
  printf 'credentials-file: %s\n\n' "$credentials"
  printf 'ingress:\n'
  printf '  - hostname: %s\n' "$HOSTNAME"
  printf '    service: http://127.0.0.1:8082\n'
  printf '    originRequest:\n'
  printf '      httpHostHeader: %s\n' "$HOSTNAME"
  printf '      connectTimeout: 10s\n'
  printf '  - service: http_status:404\n'
} >"$tmp"
mv "$tmp" "$CONFIG_FILE"
trap - EXIT
chmod 600 "$CONFIG_FILE"

"$CLOUDFLARED" --config "$CONFIG_FILE" tunnel ingress validate
"$CLOUDFLARED" --config "$CONFIG_FILE" tunnel ingress rule "https://$HOSTNAME/" >/dev/null

install -m 0644 "$ROOT_DIR/config/$LABEL.plist" "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/$LABEL"

set_env_value READECK_BASE_URL "https://$HOSTNAME/"
set_env_value READECK_ALLOWED_HOSTS "127.0.0.1,localhost,readeck,$HOSTNAME"
docker_compose up -d readeck reader-caddy >/dev/null

printf 'Cloudflare Tunnel 已配置：%s -> 127.0.0.1:8082\n' "$HOSTNAME"
printf '运行 scripts/verify.sh --reader-public 完成公网验收。\n'
