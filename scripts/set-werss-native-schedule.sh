#!/usr/bin/env bash

set -Eeuo pipefail

mode="${1:-}"
case "$mode" in
  enable) target_status=1; target_cron="17 * * * *" ;;
  cloudflare) target_status=1; target_cron="43 3 29 2 *" ;;
  disable) target_status=0; target_cron="" ;;
  *)
    printf '用法：%s <enable|cloudflare|disable>\n' "$0" >&2
    exit 2
    ;;
esac

credentials_file="$HOME/.local/share/wechat-rss/werss_refresh_credentials.json"
[[ -f "$credentials_file" ]] || {
  printf '错误：缺少 WeRSS 刷新凭据，请先运行 install-reader-refresh-control.sh\n' >&2
  exit 1
}

/usr/bin/python3 - "$credentials_file" "$mode" "$target_status" "$target_cron" <<'PY'
import json
import sys
import urllib.error
import urllib.request

credentials = json.load(open(sys.argv[1], encoding="utf-8"))
mode = sys.argv[2]
target_status = int(sys.argv[3])
target_cron = sys.argv[4]
authorization = f"AK-SK {credentials['key']}:{credentials['secret']}"
base = "http://127.0.0.1:8001/api/v1/wx"


def request(method, endpoint, payload=None):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    headers = {"Authorization": authorization, "Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(base + endpoint, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"WeRSS API 更新调度失败（HTTP {exc.code}）") from exc
    return json.loads(raw.decode("utf-8")) if raw else {}


result = request("GET", "/message_tasks?limit=100&offset=0")
data = result.get("data", result)
tasks = data.get("list", []) if isinstance(data, dict) else []
task = next((item for item in tasks if "公众号" in str(item.get("name") or "")), None)
if task is None:
    raise SystemExit("WeRSS 没有找到公众号抓取任务")

payload = {
    "message_template": str(task.get("message_template") or ""),
    "web_hook_url": str(task.get("web_hook_url") or ""),
    "mps_id": str(task.get("mps_id") or ""),
    "name": str(task.get("name") or ""),
    "message_type": int(task.get("message_type") or 0),
    "cron_exp": target_cron or str(task.get("cron_exp") or "17 * * * *"),
    "status": target_status,
    "headers": task.get("headers") or "",
    "cookies": task.get("cookies") or "",
}
request("PUT", f"/message_tasks/{task['id']}", payload)
request("PUT", "/message_tasks/job/fresh")
if mode == "cloudflare":
    print("WeRSS 抓取任务已切到 Cloudflare 模式：保留手工运行能力，原生 Cron 停放到闰年 2 月 29 日。")
elif mode == "enable":
    print("WeRSS 原生 Cron 已恢复为每小时第 17 分钟运行。")
else:
    print("WeRSS 抓取任务已完全停用；此状态下受保护刷新控制端也无法手工执行。")
PY
