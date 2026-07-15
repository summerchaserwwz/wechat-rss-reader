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
eligible_articles="unknown"
mapping_duplicates="unknown"
mapping_missing="unknown"
latest_ready="none"
latest_loaded="none"
latest_latency_minutes="unknown"
if [[ -f "$sync_db" ]]; then
  sync_mappings="$(sqlite3 -readonly "$sync_db" "select count(*) from article_map;" 2>/dev/null || printf 'unknown')"
  mapping_snapshot="$(sqlite3 -readonly -separator $'\t' "$sync_db" "
    attach database '$ROOT_DIR/data/we_mp_rss.db' as w;
    attach database '$readeck_db' as r;
    with eligible as (
      select id, created_at
      from w.articles
      where has_content=1 and length(trim(coalesce(content_html,content,'')))>=80
    ), latest as (
      select e.created_at ready_at, b.updated loaded_at
      from eligible e
      left join article_map m on m.article_id=e.id
      left join r.bookmark b on b.uid=m.bookmark_id
      order by datetime(e.created_at) desc
      limit 1
    )
    select
      (select count(*) from eligible),
      ((select count(*)-count(distinct article_id) from article_map) +
       (select count(*)-count(distinct bookmark_id) from article_map)),
      ((select count(*) from eligible e left join article_map m on m.article_id=e.id where m.article_id is null) +
       (select count(*) from article_map m left join r.bookmark b on b.uid=m.bookmark_id where b.uid is null)),
      coalesce((select ready_at from latest), 'none'),
      coalesce((select strftime('%Y-%m-%d %H:%M:%S', loaded_at, '+8 hours') from latest), 'none'),
      coalesce((select round((julianday(loaded_at,'+8 hours')-julianday(ready_at))*24*60,2) from latest), 'unknown');
  ")"
  IFS=$'\t' read -r eligible_articles mapping_duplicates mapping_missing latest_ready latest_loaded latest_latency_minutes <<<"$mapping_snapshot"
fi

sync_state="unknown"
if [[ -f /tmp/wechat-rss-reading-sync.log ]] && tail -n 1 /tmp/wechat-rss-reading-sync.log | grep -q '同步完成'; then
  sync_state="ok"
elif [[ -s /tmp/wechat-rss-reading-sync.err ]]; then
  sync_state="error"
fi

timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
old_header=$'timestamp\twerss_service\treadeck_service\treader_caddy_service\tenabled_feeds\twerss_articles\twerss_complete\twerss_latest\tcron_exp\tcron_status\treadeck_bookmarks\treadeck_marked\treadeck_annotated\treadeck_latest\tsync_mappings\tsync_state'
new_header="${old_header}"$'\teligible_articles\tmapping_duplicates\tmapping_missing\tlatest_ready\tlatest_loaded\tlatest_latency_minutes'
if [[ ! -f "$log" ]]; then
  printf '%s\n' "$new_header" >"$log"
else
  current_header="$(head -n 1 "$log")"
  if [[ "$current_header" == "$old_header" ]]; then
    migrated="$(mktemp "$ROOT_DIR/observations/readeck-stability.tsv.tmp.XXXXXX")"
    chmod 600 "$migrated"
    printf '%s\n' "$new_header" >"$migrated"
    tail -n +2 "$log" | awk '{ print $0 "\tunknown\tunknown\tunknown\tunknown\tunknown\tunknown" }' >>"$migrated"
    mv "$migrated" "$log"
  elif [[ "$current_header" != "$new_header" ]]; then
    die "观察文件表头不是已知版本，拒绝覆盖"
  fi
fi

row=(
  "$timestamp"
  "$(service_state we-mp-rss)"
  "$(service_state readeck)"
  "$(service_state reader-caddy)"
  "$enabled_feeds" "$werss_articles" "$werss_complete" "$werss_latest"
  "$cron_exp" "$cron_status"
  "$readeck_bookmarks" "$readeck_marked" "$readeck_annotated" "$readeck_latest"
  "$sync_mappings" "$sync_state"
  "$eligible_articles" "$mapping_duplicates" "$mapping_missing"
  "$latest_ready" "$latest_loaded" "$latest_latency_minutes"
)
(IFS=$'\t'; printf '%s\n' "${row[*]}") >>"$log"

chmod 600 "$log"
printf '已记录一次 Readeck 稳定性观察：%s\n' "$log"
