#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command curl
require_command docker
require_env_file

host="$(env_value WERSS_PUBLIC_HOSTNAME werss.example.com)"
reader_host="$(env_value READECK_PUBLIC_HOSTNAME reader.example.com)"
email="$(env_value CF_ACCESS_EMAIL)"
aud="$(env_value CF_WERSS_ACCESS_AUD)"
access_ready="$(env_value CF_WERSS_ACCESS_READY false)"
port="${WERSS_PUBLIC_CADDY_HOST_PORT:-$(env_value WERSS_PUBLIC_CADDY_HOST_PORT 8083)}"
local_url="http://127.0.0.1:${port}"
public_url="https://${host}/"
config_file="$HOME/.cloudflared/wechat-rss.yml"

[[ "$access_ready" == "true" ]] || die "CF_WERSS_ACCESS_READY 尚未确认"
[[ "$host" =~ ^[a-z0-9.-]+$ ]] || die "WERSS_PUBLIC_HOSTNAME 格式异常"
[[ "$reader_host" =~ ^[a-z0-9.-]+$ ]] || die "READECK_PUBLIC_HOSTNAME 格式异常"
[[ "$host" != "$reader_host" ]] || die "Reader 与 WeRSS 必须使用不同域名"
[[ "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || die "CF_ACCESS_EMAIL 格式异常"
[[ "$aud" =~ ^[A-Za-z0-9_-]{32,128}$ ]] || die "CF_WERSS_ACCESS_AUD 格式异常"

docker_compose config --quiet
binding="$(docker_compose port werss-public-caddy 8080)"
[[ "$binding" == 127.0.0.1:* ]] || die "WeRSS 公网 Caddy 没有只绑定 127.0.0.1"
docker_compose exec -T werss-public-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

printf '检查 WeRSS 公网 Caddy 本机拒绝边界...\n'
root_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$local_url/")"
anonymous_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -H "Host: $host" "$local_url/")"
anonymous_api="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -H "Host: $host" "$local_url/api/v1/wx/message_tasks")"
[[ "$root_status" == "404" ]] || die "非目标 Host 的本机请求不是 404"
[[ "$anonymous_status" == "403" && "$anonymous_api" == "403" ]] \
  || die "目标 Host 缺少 Access 身份时不是 403/403"

authorized_html="$(curl -fsS --max-time 10 \
  -H "Host: $host" \
  -H "Cf-Access-Authenticated-User-Email: $email" \
  -H 'Cf-Access-Jwt-Assertion: werss-public-local-smoke' \
  "$local_url/")"
grep -q '<title>WeRss微信公众号订阅助手</title>' <<<"$authorized_html" \
  || die "模拟 Access 身份未到达 WeRSS UI"

[[ -f "$config_file" ]] || die "缺少 Cloudflare Tunnel 配置"
grep -qE "^[[:space:]]*-[[:space:]]+hostname:[[:space:]]+$reader_host$" "$config_file" \
  || die "Tunnel 丢失现有 Reader ingress"
grep -qE "^[[:space:]]*-[[:space:]]+hostname:[[:space:]]+$host$" "$config_file" \
  || die "Tunnel 缺少 WeRSS ingress"
grep -qE '^[[:space:]]+service:[[:space:]]+http://127\.0\.0\.1:8083$' "$config_file" \
  || die "WeRSS Tunnel origin 不是 127.0.0.1:8083"
required_count="$(grep -cE '^[[:space:]]+required:[[:space:]]+true$' "$config_file")"
(( required_count >= 2 )) || die "Reader 与 WeRSS ingress 没有分别强制 Access JWT"
grep -qF "$aud" "$config_file" || die "Tunnel 配置缺少 WeRSS Access AUD"

printf '检查 Cloudflare Access 公网匿名边界...\n'
headers="$(mktemp /tmp/wechat-rss-werss-public.XXXXXX)"
trap 'rm -f "$headers"' EXIT
public_status="$(curl -sS -D "$headers" -o /dev/null -w '%{http_code}' --max-time 60 "$public_url")"
[[ "$public_status" == "302" || "$public_status" == "401" || "$public_status" == "403" ]] \
  || die "WeRSS 公网根路径没有被 Access 拦截（实际：$public_status）"
if [[ "$public_status" == "302" ]]; then
  grep -qiE '^location: https://[^[:space:]]*cloudflareaccess\.com/' "$headers" \
    || die "WeRSS 公网根路径跳转目标不是 Cloudflare Access"
fi
public_api="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 60 "${public_url}api/v1/wx/message_tasks")"
[[ "$public_api" == "302" || "$public_api" == "401" || "$public_api" == "403" ]] \
  || die "WeRSS 公网 API 未被 Access 拦截（实际：$public_api）"

printf 'WeRSS 公网安全验证通过：origin 仅回环，匿名本机 403/403，Tunnel 保留 Reader 并强制独立 AUD，公网匿名请求被 Access 拦截。\n'
