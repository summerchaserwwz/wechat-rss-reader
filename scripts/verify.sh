#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

mode="${1:---local}"
[[ "$mode" == "--local" || "$mode" == "--public" ]] || die "用法：scripts/verify.sh [--local|--public]"

require_command curl
require_command xmllint
require_command docker
require_env_file

prefix="$(env_value FEED_PREFIX)"
[[ "$prefix" =~ ^rss-[0-9a-f]{48}$ ]] || die "FEED_PREFIX 格式不正确"

werss_port="${WERSS_HOST_PORT:-$(env_value WERSS_HOST_PORT 8001)}"
caddy_port="${CADDY_HOST_PORT:-$(env_value CADDY_HOST_PORT 8080)}"
admin_url="http://127.0.0.1:${werss_port}"
proxy_url="http://127.0.0.1:${caddy_port}"
local_feed_url="${proxy_url}/${prefix}/feed/all.atom"
tmp_feed="$(mktemp /tmp/wechat-rss-feed.XXXXXX)"
trap 'rm -f "$tmp_feed"' EXIT

expect_status() {
  local expected="$1"
  local method="$2"
  local url="$3"
  local actual

  actual="$(curl -sS -o /dev/null -w '%{http_code}' -X "$method" --max-time 30 "$url")"
  if [[ "$actual" != "$expected" ]]; then
    die "$method 请求状态不符合预期：期望 $expected，实际 $actual"
  fi
}

printf '检查 Compose 配置与容器状态...\n'
docker_compose config --quiet
docker_compose ps
[[ "$(docker_compose exec -T we-mp-rss uname -m)" == "aarch64" ]] || die "WeRSS 容器不是原生 aarch64"
docker_compose exec -T caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null

printf '检查管理端只绑定本机...\n'
admin_binding="$(docker_compose port we-mp-rss 8001)"
caddy_binding="$(docker_compose port caddy 8080)"
[[ "$admin_binding" == 127.0.0.1:* ]] || die "WeRSS 端口没有只绑定 127.0.0.1"
[[ "$caddy_binding" == 127.0.0.1:* ]] || die "Caddy 端口没有只绑定 127.0.0.1"

printf '检查本机管理端与只读代理...\n'
expect_status 200 GET "${admin_url}/"
expect_status 404 GET "${proxy_url}/"
expect_status 404 GET "${proxy_url}/${prefix}/"
expect_status 404 GET "${proxy_url}/${prefix}/api"
expect_status 404 POST "$local_feed_url"
expect_status 200 GET "$local_feed_url"
traversal_status="$(curl --path-as-is -sS -o /dev/null -w '%{http_code}' --max-time 30 "${proxy_url}/${prefix}/feed/../api/docs")"
[[ "$traversal_status" == "404" ]] || die "路径穿越请求未被拒绝"
curl -fsS --max-time 30 "$local_feed_url" -o "$tmp_feed"
xmllint --noout "$tmp_feed"

if [[ "$mode" == "--public" ]]; then
  rss_base_url="$(env_value RSS_BASE_URL)"
  [[ "$rss_base_url" == https://*"/${prefix}/" ]] || die "RSS_BASE_URL 不是预期的 HTTPS 随机前缀地址"
  public_origin="$(printf '%s' "$rss_base_url" | sed -E 's#^(https://[^/]+).*$#\1#')"
  public_feed_url="${rss_base_url}feed/all.atom"

  printf '检查公网 Funnel 安全边界...\n'
  expect_status 404 GET "${public_origin}/"
  expect_status 404 GET "${public_origin}/${prefix}/api"
  expect_status 404 POST "$public_feed_url"
  expect_status 200 GET "$public_feed_url"
  traversal_status="$(curl --path-as-is -sS -o /dev/null -w '%{http_code}' --max-time 60 "${public_origin}/${prefix}/feed/../api/docs")"
  [[ "$traversal_status" == "404" ]] || die "公网路径穿越请求未被拒绝"
  curl -fsS --max-time 60 "$public_feed_url" -o "$tmp_feed"
  xmllint --noout "$tmp_feed"
fi

printf '验证通过：管理后台仅本机可见，随机前缀下的只读 Atom Feed 可用。\n'
