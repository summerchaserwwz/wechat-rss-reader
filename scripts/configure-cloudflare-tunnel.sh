#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CLOUDFLARED="${CLOUDFLARED:-$HOME/.local/bin/cloudflared}"
TUNNEL_NAME="${TUNNEL_NAME:-wechat-rss}"
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

READER_HOSTNAME="$(env_value READECK_PUBLIC_HOSTNAME)"
WERSS_HOSTNAME="$(env_value WERSS_PUBLIC_HOSTNAME)"
[[ "$READER_HOSTNAME" =~ ^[a-z0-9.-]+$ ]] || die "READECK_PUBLIC_HOSTNAME 格式异常"
[[ "$WERSS_HOSTNAME" =~ ^[a-z0-9.-]+$ ]] || die "WERSS_PUBLIC_HOSTNAME 格式异常"
[[ "$READER_HOSTNAME" != "$WERSS_HOSTNAME" ]] || die "Reader 与 WeRSS 必须使用不同域名"

access_ready="$(env_value CF_ACCESS_READY false)"
access_team_name="$(env_value CF_ACCESS_TEAM_NAME)"
access_aud="$(env_value CF_ACCESS_AUD)"
access_email="$(env_value CF_ACCESS_EMAIL)"
werss_access_ready="$(env_value CF_WERSS_ACCESS_READY false)"
werss_access_aud="$(env_value CF_WERSS_ACCESS_AUD)"
[[ "$access_ready" == "true" ]] || die "必须先创建 Cloudflare Access 应用与精确邮箱 Allow 策略，再把 CF_ACCESS_READY 设为 true"
[[ "$werss_access_ready" == "true" ]] || die "必须先为 $WERSS_HOSTNAME 创建独立 Access 应用与精确邮箱 Allow 策略，再把 CF_WERSS_ACCESS_READY 设为 true"
[[ "$access_team_name" =~ ^[a-z0-9-]+$ ]] || die "CF_ACCESS_TEAM_NAME 格式异常"
[[ "$access_aud" =~ ^[A-Za-z0-9_-]{32,128}$ ]] || die "CF_ACCESS_AUD 格式异常"
[[ "$werss_access_aud" =~ ^[A-Za-z0-9_-]{32,128}$ ]] || die "CF_WERSS_ACCESS_AUD 格式异常"
[[ "$access_email" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || die "CF_ACCESS_EMAIL 格式异常"

docker_compose up -d readeck reader-caddy werss-public-caddy >/dev/null
curl -fsS --max-time 10 http://127.0.0.1:8082/login >/dev/null \
  || die "本机 Readeck 反代尚未就绪"
werss_local_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
  -H "Host: $WERSS_HOSTNAME" http://127.0.0.1:8083/)"
[[ "$werss_local_status" == "403" ]] || die "WeRSS 公网 Caddy 匿名 Host 不是 403"

mkdir -p "$CONFIG_DIR" "$PLIST_DIR"
chmod 700 "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/cert.pem" ]]; then
  printf '即将打开 Cloudflare 授权页；请选择管理 %s 的账号。\n' "$READER_HOSTNAME"
  "$CLOUDFLARED" tunnel login
fi

tunnel_id="$(
  "$CLOUDFLARED" tunnel list --name "$TUNNEL_NAME" --output json \
    | jq -r '(. // []) | map(select(.name == "'"$TUNNEL_NAME"'" and (.deletedAt == null or .deletedAt == ""))) | first | .id // empty'
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
for hostname in "$READER_HOSTNAME" "$WERSS_HOSTNAME"; do
  if [[ "$configured_tunnel" != "$tunnel_id" ]] || ! grep -qE "^[[:space:]]*-[[:space:]]+hostname:[[:space:]]+$hostname$" "$CONFIG_FILE" 2>/dev/null; then
    # 不使用 --overwrite-dns：若同名记录已属于其他服务，必须人工判断，不能静默覆盖。
    "$CLOUDFLARED" tunnel route dns "$tunnel_id" "$hostname"
  fi
done

tmp="$(mktemp "$CONFIG_DIR/wechat-rss.yml.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
chmod 600 "$tmp"
{
  printf 'tunnel: %s\n' "$tunnel_id"
  printf 'credentials-file: %s\n\n' "$credentials"
  printf 'ingress:\n'
  printf '  - hostname: %s\n' "$READER_HOSTNAME"
  printf '    service: http://127.0.0.1:8082\n'
  printf '    originRequest:\n'
  printf '      httpHostHeader: %s\n' "$READER_HOSTNAME"
  printf '      connectTimeout: 10s\n'
  printf '      access:\n'
  printf '        required: true\n'
  printf '        teamName: %s\n' "$access_team_name"
  printf '        audTag:\n'
  printf '          - %s\n' "$access_aud"
  printf '  - hostname: %s\n' "$WERSS_HOSTNAME"
  printf '    service: http://127.0.0.1:8083\n'
  printf '    originRequest:\n'
  printf '      httpHostHeader: %s\n' "$WERSS_HOSTNAME"
  printf '      connectTimeout: 10s\n'
  printf '      access:\n'
  printf '        required: true\n'
  printf '        teamName: %s\n' "$access_team_name"
  printf '        audTag:\n'
  printf '          - %s\n' "$werss_access_aud"
  printf '  - service: http_status:404\n'
} >"$tmp"
mv "$tmp" "$CONFIG_FILE"
trap - EXIT
chmod 600 "$CONFIG_FILE"

"$CLOUDFLARED" --config "$CONFIG_FILE" tunnel ingress validate
"$CLOUDFLARED" --config "$CONFIG_FILE" tunnel ingress rule "https://$READER_HOSTNAME/" >/dev/null
"$CLOUDFLARED" --config "$CONFIG_FILE" tunnel ingress rule "https://$WERSS_HOSTNAME/" >/dev/null

install -m 0644 "$ROOT_DIR/config/$LABEL.plist" "$PLIST_PATH"
/usr/bin/sed -i '' "s|__HOME__|$HOME|g" "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null
launchctl bootout "$DOMAIN/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/$LABEL"

set_env_value READECK_BASE_URL "https://$READER_HOSTNAME/"
set_env_value READECK_ALLOWED_HOSTS "127.0.0.1,localhost,readeck,$READER_HOSTNAME"
set_env_value WERSS_PUBLIC_HOSTNAME "$WERSS_HOSTNAME"
set_env_value READECK_AUTH_FORWARDED_ENABLED "true"
docker_compose up -d readeck reader-caddy werss-public-caddy >/dev/null

printf 'Cloudflare Tunnel 已保留 Reader，并新增受 Access 保护的 WeRSS 管理入口。\n'
printf '运行 scripts/verify.sh --reader-public 完成公网验收。\n'
