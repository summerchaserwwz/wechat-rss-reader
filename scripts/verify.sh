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
require_command sqlite3
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
reader_root_status="$(curl -sS -o /dev/null -w '%{http_code}' "${reader_proxy_url}/")"
reader_api_status="$(curl -sS -o /dev/null -w '%{http_code}' "${reader_proxy_url}/api/bookmarks")"
[[ "$reader_root_status" == "303" ]] || die "Readeck 反代根路径未跳转到登录页"
[[ "$reader_api_status" == "401" ]] || die "Readeck 未登录 API 不是 401"
reader_theme="$(curl -fsS "${reader_proxy_url}/assets/bundle.1cd17fd7.css")"
grep -q 'WeChat RSS Reader theme' <<<"$reader_theme" || die "Reader 自定义阅读主题未生效"
reader_public_root_status="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: ${reader_host}" "${reader_proxy_url}/")"
reader_public_api_status="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: ${reader_host}" "${reader_proxy_url}/api/bookmarks")"
[[ "$reader_public_root_status" == "403" ]] || die "缺少 Access 身份时 Reader 公网 Host 根路径不是 403"
[[ "$reader_public_api_status" == "403" ]] || die "缺少 Access 身份时 Reader 公网 Host API 不是 403"

printf '检查 WeRSS → Readeck 全量同步映射...\n'
sync_db="$HOME/.local/share/wechat-rss/reading-sync.sqlite3"
[[ -f "$sync_db" ]] || die "缺少阅读同步状态数据库"
sync_snapshot="$(sqlite3 -readonly -separator '|' "$sync_db" "
  attach database '$ROOT_DIR/data/we_mp_rss.db' as w;
  attach database '$ROOT_DIR/readeck-data/data/db.sqlite3' as r;
  select
    (select count(*) from w.feeds where status=1),
    (select count(*) from w.articles where has_content=1 and length(trim(coalesce(content_html,content,'')))>=80),
    (select count(*) from article_map),
    (select count(distinct article_id) from article_map),
    (select count(distinct bookmark_id) from article_map),
    (select count(*) from article_map m left join w.articles a on a.id=m.article_id where a.id is null),
    (select count(*) from article_map m left join r.bookmark b on b.uid=m.bookmark_id where b.uid is null),
    (select count(*) from article_map m join r.bookmark b on b.uid=m.bookmark_id where b.url<>m.url),
    (select count(distinct f.id) from w.feeds f join w.articles a on a.mp_id=f.id where f.status=1 and a.has_content=1 and length(trim(coalesce(a.content_html,a.content,'')))>=80),
    (select count(distinct a.mp_id) from article_map m join w.articles a on a.id=m.article_id join w.feeds f on f.id=a.mp_id where f.status=1);
")"
IFS='|' read -r enabled_feeds eligible_articles mapped_articles unique_articles unique_bookmarks missing_werss missing_readeck url_mismatch eligible_feeds mapped_feeds <<<"$sync_snapshot"
(( enabled_feeds > 0 )) || die "没有启用的公众号"
[[ "$eligible_articles" == "$mapped_articles" ]] || die "达到正文门槛的 WeRSS 文章尚未全部同步到 Readeck"
[[ "$mapped_articles" == "$unique_articles" && "$mapped_articles" == "$unique_bookmarks" ]] || die "同步映射存在重复文章或书签"
[[ "$missing_werss" == "0" && "$missing_readeck" == "0" && "$url_mismatch" == "0" ]] || die "同步映射存在孤儿或 URL 错配"
[[ "$eligible_feeds" == "$enabled_feeds" && "$mapped_feeds" == "$enabled_feeds" ]] || die "并非所有启用公众号都有可用正文和 Readeck 映射"
printf '同步映射通过：%s 个公众号，%s 篇可用正文，均唯一进入 Readeck。\n' "$enabled_feeds" "$mapped_articles"

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

  printf '检查公网 Cloudflare Access 与 API 拒绝边界...\n'
  headers="$(mktemp /tmp/wechat-rss-reader-headers.XXXXXX)"
  trap 'rm -f "$tmp_feed" "$headers"' EXIT
  public_root_status="$(curl -sS -D "$headers" -o /dev/null -w '%{http_code}' --max-time 60 "$readeck_base_url")"
  [[ "$public_root_status" == "302" || "$public_root_status" == "401" || "$public_root_status" == "403" ]] \
    || die "未授权公网根路径不是 Access 拒绝/认证响应（实际：${public_root_status}）"
  if [[ "$public_root_status" == "302" ]]; then
    grep -qiE '^location: https://[^[:space:]]*cloudflareaccess\.com/' "$headers" \
      || die "公网根路径跳转目标不是 Cloudflare Access"
  fi
  public_api_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 60 "${readeck_base_url}api/bookmarks")"
  [[ "$public_api_status" == "401" || "$public_api_status" == "403" ]] \
    || die "未授权公网 API 不是 401/403（实际：${public_api_status}）"
  public_feed_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 60 "${readeck_base_url}feed/all.atom")"
  [[ "$public_feed_status" == "302" || "$public_feed_status" == "401" || "$public_feed_status" == "403" ]] \
    || die "未授权公网 Feed 路径没有被 Access 拦截（实际：${public_feed_status}）"
fi

[[ "$container_arch" == "aarch64" ]] || die "安全与 Feed 检查已完成，但 WeRSS 容器不是原生 aarch64（实际：${container_arch}）"

printf '验证通过：管理后台仅本机可见，随机前缀下的只读 Atom Feed 可用。\n'
