#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_command docker
require_command sqlite3
require_env_file

umask 077
mkdir -p "$ROOT_DIR/observations"
chmod 700 "$ROOT_DIR/observations"
log="$ROOT_DIR/observations/readeck-stability.tsv"

service_state() {
  local service="$1" container
  container="$(docker_compose ps -q "$service")"
  if [[ -z "$container" ]]; then
    printf 'missing'
    return
  fi
  docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container"
}

werss_snapshot="$({
  docker_compose exec -T we-mp-rss python3 - <<'PY'
import datetime as dt
import sqlite3

db = sqlite3.connect("file:/app/data/we_mp_rss.db?mode=ro", uri=True)
enabled = db.execute("select count(*) from feeds where status = 1").fetchone()[0]
articles, complete, latest = db.execute(
    "select count(*), sum(case when has_content then 1 else 0 end), max(publish_time) from articles"
).fetchone()
cron = db.execute(
    "select cron_exp, status from message_tasks order by id desc limit 1"
).fetchone() or ("missing", 0)
latest_iso = "none"
if latest:
    if latest > 10_000_000_000:
        latest //= 1000
    latest_iso = dt.datetime.fromtimestamp(latest, dt.timezone.utc).isoformat().replace("+00:00", "Z")
print(enabled, articles, complete or 0, latest_iso, cron[0], cron[1], sep="\t")
PY
} 2>/dev/null)" || die "无法读取 WeRSS 观察快照"

IFS=$'\t' read -r enabled_feeds werss_articles werss_complete werss_latest cron_exp cron_status <<<"$werss_snapshot"

readeck_db="$ROOT_DIR/readeck-data/data/db.sqlite3"
[[ -f "$readeck_db" ]] || die "缺少 Readeck 数据库"
readeck_snapshot="$(sqlite3 -readonly -separator $'\t' "$readeck_db" \
  "select count(*), coalesce(sum(is_marked = 1), 0), coalesce(sum(annotations not in ('', '[]', '{}', 'null')), 0), coalesce(max(published), 'none') from bookmark;")"
IFS=$'\t' read -r readeck_bookmarks readeck_marked readeck_annotated readeck_latest <<<"$readeck_snapshot"

sync_db="$HOME/.local/share/wechat-rss/reading-sync.sqlite3"
sync_mappings="0"
if [[ -f "$sync_db" ]]; then
  sync_mappings="$(sqlite3 -readonly "$sync_db" "select count(*) from article_map;" 2>/dev/null || printf 'unknown')"
fi

sync_state="unknown"
if [[ -f /tmp/wechat-rss-reading-sync.log ]] && tail -n 1 /tmp/wechat-rss-reading-sync.log | grep -q '同步完成'; then
  sync_state="ok"
elif [[ -s /tmp/wechat-rss-reading-sync.err ]]; then
  sync_state="error"
fi

timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
if [[ ! -f "$log" ]]; then
  printf '%s\n' 'timestamp	werss_service	readeck_service	reader_caddy_service	enabled_feeds	werss_articles	werss_complete	werss_latest	cron_exp	cron_status	readeck_bookmarks	readeck_marked	readeck_annotated	readeck_latest	sync_mappings	sync_state' >"$log"
fi

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$timestamp" \
  "$(service_state we-mp-rss)" \
  "$(service_state readeck)" \
  "$(service_state reader-caddy)" \
  "$enabled_feeds" "$werss_articles" "$werss_complete" "$werss_latest" \
  "$cron_exp" "$cron_status" \
  "$readeck_bookmarks" "$readeck_marked" "$readeck_annotated" "$readeck_latest" \
  "$sync_mappings" "$sync_state" >>"$log"

chmod 600 "$log"
printf '已记录一次 Readeck 稳定性观察：%s\n' "$log"
