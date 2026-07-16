#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_env_file
require_command python3

runtime_dir="$HOME/.local/share/wechat-rss"
secret_file="$runtime_dir/reader_refresh_secret"
credentials_file="$runtime_dir/werss_refresh_credentials.json"
config_file="$runtime_dir/reader_refresh_config.json"
mkdir -p "$runtime_dir"
chmod 700 "$runtime_dir"

env_secret="$(env_value READER_REFRESH_SECRET)"
file_secret=""
if [[ -f "$secret_file" ]]; then
  file_secret="$(tr -d '\r\n' <"$secret_file")"
fi
if [[ -n "$env_secret" && -n "$file_secret" && "$env_secret" != "$file_secret" ]]; then
  die "READER_REFRESH_SECRET 与运行时密钥不一致，拒绝静默覆盖"
fi
refresh_secret="${file_secret:-$env_secret}"
if [[ -z "$refresh_secret" ]]; then
  refresh_secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
fi
[[ ${#refresh_secret} -ge 48 ]] || die "READER_REFRESH_SECRET 长度不足"
printf '%s\n' "$refresh_secret" >"$secret_file"
chmod 600 "$secret_file"
set_env_value READER_REFRESH_SECRET "$refresh_secret"

allowed_host="$(env_value READECK_PUBLIC_HOSTNAME reader.example.com)"
allowed_email="$(env_value CF_ACCESS_EMAIL)"
[[ "$allowed_host" =~ ^[a-z0-9.-]+$ ]] || die "READECK_PUBLIC_HOSTNAME 格式异常"
[[ "$allowed_email" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || die "CF_ACCESS_EMAIL 格式异常"
python3 - "$config_file" "$allowed_host" "$allowed_email" <<'PY'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
temp = path.with_suffix(".tmp")
temp.write_text(
    json.dumps({"allowed_host": sys.argv[2], "allowed_email": sys.argv[3]}, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
os.chmod(temp, 0o600)
temp.replace(path)
os.chmod(path, 0o600)
PY

if [[ ! -f "$credentials_file" ]]; then
  python3 - "$ENV_FILE" "$credentials_file" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

env_file = Path(sys.argv[1])
output = Path(sys.argv[2])


def parse_env(path):
    values = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def request(url, *, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as exc:
        raise SystemExit("无法通过 WeRSS 受支持 API 创建主动刷新凭据") from exc


values = parse_env(env_file)
username = values.get("WERSS_ADMIN_USERNAME", "werss_admin")
password = values.get("WERSS_BOOTSTRAP_PASSWORD", "")
if not password:
    raise SystemExit(".env 缺少 WERSS_BOOTSTRAP_PASSWORD")

form = urllib.parse.urlencode({"username": username, "password": password}).encode("utf-8")
token_payload = request(
    "http://127.0.0.1:8001/api/v1/wx/auth/token",
    data=form,
    headers={"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"},
)
token = token_payload.get("access_token")
if not token:
    raise SystemExit("WeRSS 管理密码与 .env 不一致，请先在本机管理端确认密码")

body = json.dumps(
    {
        "name": "Reader 主动刷新",
        "description": "仅供本机 Reader 刷新控制端使用",
        "permissions": ["message_task:run", "task_queue:read"],
        "expires_in_days": 3650,
    },
    ensure_ascii=False,
).encode("utf-8")
created = request(
    "http://127.0.0.1:8001/api/v1/wx/auth/ak/create",
    data=body,
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    },
)
data = created.get("data") if isinstance(created, dict) else None
if not isinstance(data, dict) or not str(data.get("key", "")).startswith("WK") or not str(data.get("secret", "")).startswith("SK"):
    raise SystemExit("WeRSS 未返回有效的主动刷新 Access Key")

temp = output.with_suffix(".tmp")
temp.write_text(
    json.dumps({"key": data["key"], "secret": data["secret"], "name": "Reader 主动刷新"}, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
os.chmod(temp, 0o600)
temp.replace(output)
os.chmod(output, 0o600)
PY
fi

chmod 600 "$credentials_file"
chmod 600 "$config_file"
printf 'Reader 主动刷新内部密钥与 WeRSS Access Key 已准备完成。\n'
