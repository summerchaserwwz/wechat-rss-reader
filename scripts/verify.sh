#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

mode="${1:---local}"
[[ "$mode" == "--local" || "$mode" == "--public" || "$mode" == "--reader-public" ]] \
  || die "用法：scripts/verify.sh [--local|--public|--reader-public]"

require_command curl
require_command xmllint
require_command docker
require_env_file

prefix="$(env_value FEED_PREFIX)"
[[ "$prefix" =~ ^rss-[0-9a-f]{48}$ ]] || die "FEED_PREFIX 格式不正确"

werss_port="${WERSS_HOST_PORT:-$(env_value WERSS_HOST_PORT 8001)}"
caddy_port="${CADDY_HOST_PORT:-$(env_value CADDY_HOST_PORT 8080)}"
readeck_port="${READECK_HOST_PORT:-$(env_value READECK_HOST_PORT 8002)}"
reader_caddy_port="${READER_CADDY_HOST_PORT:-$(env_value READER_CADDY_HOST_PORT 8082)}"
admin_url="http://127.0.0.1:${werss_port}"
proxy_url="http://127.0.0.1:${caddy_port}"
readeck_url="http://127.0.0.1:${readeck_port}"
reader_proxy_url="http://127.0.0.1:${reader_caddy_port}"
reader_host="reader.sumerchaser.top"
local_feed_url="${proxy_url}/${prefix}/feed/all.atom"
tmp_feed="$(mktemp /tmp/wechat-rss-feed.XXXXXX)"
trap 'rm -f "$tmp_feed"' EXIT

expect_status() {
  local expected="$1"
  local method="$2"
  local url="$3"
  local actual

  if [[ "$method" == "HEAD" ]]; then
    actual="$(curl -sS -o /dev/null -w '%{http_code}' --head --max-time 30 "$url")"
  else
    actual="$(curl -sS -o /dev/null -w '%{http_code}' -X "$method" --max-time 30 "$url")"
  fi
  if [[ "$actual" != "$expected" ]]; then
    die "${method} 请求状态不符合预期：期望 ${expected}，实际 ${actual}"
  fi
}

printf '检查 Compose 配置与容器状态...\n'
docker_compose config --quiet
docker_compose ps
container_arch="$(docker_compose exec -T we-mp-rss uname -m)"
docker_compose exec -T caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
docker_compose exec -T reader-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

printf '检查管理端只绑定本机...\n'
admin_binding="$(docker_compose port we-mp-rss 8001)"
caddy_binding="$(docker_compose port caddy 8080)"
readeck_binding="$(docker_compose port readeck 8000)"
reader_caddy_binding="$(docker_compose port reader-caddy 8080)"
[[ "$admin_binding" == 127.0.0.1:* ]] || die "WeRSS 端口没有只绑定 127.0.0.1"
[[ "$caddy_binding" == 127.0.0.1:* ]] || die "Caddy 端口没有只绑定 127.0.0.1"
[[ "$readeck_binding" == 127.0.0.1:* ]] || die "Readeck 端口没有只绑定 127.0.0.1"
[[ "$reader_caddy_binding" == 127.0.0.1:* ]] || die "Readeck 反代端口没有只绑定 127.0.0.1"

printf '检查本机管理端与只读代理...\n'
expect_status 200 GET "${admin_url}/"
expect_status 404 GET "${proxy_url}/"
expect_status 404 GET "${proxy_url}/${prefix}/"
expect_status 404 GET "${proxy_url}/${prefix}/api"
expect_status 404 GET "${proxy_url}/${prefix}/feed/all"
expect_status 404 POST "$local_feed_url"
expect_status 200 HEAD "$local_feed_url"
expect_status 200 GET "$local_feed_url"
traversal_status="$(curl --path-as-is -sS -o /dev/null -w '%{http_code}' --max-time 30 "${proxy_url}/${prefix}/feed/../api/docs")"
[[ "$traversal_status" == "404" ]] || die "路径穿越请求未被拒绝"
curl -fsS --max-time 30 "$local_feed_url" -o "$tmp_feed"
xmllint --noout "$tmp_feed"

printf '检查 Readeck 本机登录边界与专用反代...\n'
expect_status 303 GET "${readeck_url}/"
expect_status 401 GET "${readeck_url}/api/bookmarks"
reader_root_status="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: ${reader_host}" "${reader_proxy_url}/")"
reader_api_status="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: ${reader_host}" "${reader_proxy_url}/api/bookmarks")"
[[ "$reader_root_status" == "303" ]] || die "Readeck 反代根路径未跳转到登录页"
[[ "$reader_api_status" == "401" ]] || die "Readeck 未登录 API 不是 401"

if [[ "$mode" == "--public" ]]; then
  rss_base_url="$(env_value RSS_BASE_URL)"
  [[ "$rss_base_url" == https://*"/${prefix}/" ]] || die "RSS_BASE_URL 不是预期的 HTTPS 随机前缀地址"
  public_origin="$(printf '%s' "$rss_base_url" | sed -E 's#^(https://[^/]+).*$#\1#')"
  public_feed_url="${rss_base_url}feed/all.atom"

  printf '检查公网 Funnel 安全边界...\n'
  expect_status 404 GET "${public_origin}/"
  expect_status 404 GET "${public_origin}/${prefix}/api"
  expect_status 404 GET "${rss_base_url}feed/all"
  expect_status 404 POST "$public_feed_url"
  expect_status 200 HEAD "$public_feed_url"
  expect_status 200 GET "$public_feed_url"
  traversal_status="$(curl --path-as-is -sS -o /dev/null -w '%{http_code}' --max-time 60 "${public_origin}/${prefix}/feed/../api/docs")"
  [[ "$traversal_status" == "404" ]] || die "公网路径穿越请求未被拒绝"
  curl -fsS --max-time 60 "$public_feed_url" -o "$tmp_feed"
  xmllint --noout "$tmp_feed"
fi

if [[ "$mode" == "--reader-public" ]]; then
  readeck_base_url="$(env_value READECK_BASE_URL)"
  [[ "$readeck_base_url" == "https://${reader_host}/" ]] || die "READECK_BASE_URL 不是预期公网地址"

  printf '检查公网 Readeck 登录与 API 边界...\n'
  headers="$(mktemp /tmp/wechat-rss-reader-headers.XXXXXX)"
  trap 'rm -f "$tmp_feed" "$headers"' EXIT
  public_root_status="$(curl -sS -D "$headers" -o /dev/null -w '%{http_code}' --max-time 60 "$readeck_base_url")"
  [[ "$public_root_status" == "303" ]] || die "公网 Readeck 根路径未跳转到登录页"
  grep -qiE '^location: https://reader\.sumerchaser\.top/login' "$headers" \
    || die "公网 Readeck 登录跳转没有保持 HTTPS 域名"
  grep -qiE '^x-content-type-options: nosniff' "$headers" || die "公网缺少 nosniff 安全头"
  expect_status 401 GET "${readeck_base_url}api/bookmarks"
  expect_status 404 GET "${readeck_base_url}feed/all.atom"
fi

[[ "$container_arch" == "aarch64" ]] || die "安全与 Feed 检查已完成，但 WeRSS 容器不是原生 aarch64（实际：${container_arch}）"

printf '验证通过：管理后台仅本机可见，随机前缀下的只读 Atom Feed 可用。\n'
