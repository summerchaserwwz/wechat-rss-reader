#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command curl
require_command xmllint
require_env_file

mp_id="${1:-}"
folo_all="${2:-待确认}"
folo_single="${3:-待确认}"
rss_base_url="$(env_value RSS_BASE_URL)"
[[ "$rss_base_url" == https://* ]] || die "请先启用 Funnel，再记录 Folo 稳定性"

umask 077
mkdir -p "$ROOT_DIR/observations"
chmod 700 "$ROOT_DIR/observations"
log="$ROOT_DIR/observations/folo-stability.tsv"
tmp="$(mktemp /tmp/wechat-rss-observe.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

inspect_feed() {
  local label="$1"
  local url="$2"
  local code latest count

  code="$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 60 "$url")"
  if [[ "$code" == "200" ]] && xmllint --noout "$tmp" >/dev/null 2>&1; then
    latest="$(xmllint --xpath 'string(/*[local-name()="feed"]/*[local-name()="updated"][1])' "$tmp" 2>/dev/null || true)"
    count="$(xmllint --xpath 'count(/*[local-name()="feed"]/*[local-name()="entry"])' "$tmp" 2>/dev/null || printf '0')"
  else
    latest="invalid"
    count="0"
  fi
  printf '%s\t%s\t%s\t%s' "$label" "$code" "$latest" "$count"
}

timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
all_result="$(inspect_feed all "${rss_base_url}feed/all.atom")"
single_result="not-configured\tNA\tNA\tNA"
if [[ -n "$mp_id" ]]; then
  single_result="$(inspect_feed single "${rss_base_url}feed/${mp_id}.atom")"
fi

if [[ ! -f "$log" ]]; then
  printf 'timestamp\tall_label\tall_http\tall_updated\tall_entries\tsingle_label\tsingle_http\tsingle_updated\tsingle_entries\tfolo_all\tfolo_single\n' >"$log"
fi
printf '%s\t%s\t%s\t%s\t%s\n' "$timestamp" "$all_result" "$single_result" "$folo_all" "$folo_single" >>"$log"
chmod 600 "$log"

printf '已记录一次观察：%s\n' "$log"
printf '参数：scripts/record-observation.sh [公众号ID] [聚合源在Folo可见状态] [单源在Folo可见状态]\n'
