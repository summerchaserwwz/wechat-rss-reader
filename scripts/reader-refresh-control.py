#!/usr/bin/env python3
"""Reader -> WeRSS -> reading-sync 受保护主动刷新控制端。"""

from __future__ import annotations

import argparse
import datetime as dt
import hmac
import json
import os
import re
import subprocess
import threading
import time
import urllib.error
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable


DEFAULT_RUNTIME = Path.home() / ".local/share/wechat-rss"
DEFAULT_CREDENTIALS = DEFAULT_RUNTIME / "werss_refresh_credentials.json"
DEFAULT_SECRET_FILE = DEFAULT_RUNTIME / "reader_refresh_secret"
DEFAULT_CONFIG_FILE = DEFAULT_RUNTIME / "reader_refresh_config.json"
DEFAULT_STATE_FILE = DEFAULT_RUNTIME / "refresh-control-state.json"
DEFAULT_READER_STATUS = DEFAULT_RUNTIME / "public-status/reader-status.json"
DEFAULT_SYNC_SCRIPT = DEFAULT_RUNTIME / "reading-sync.py"
ACTIVE_PHASES = {"checking_werss", "syncing_reader"}


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso(value: dt.datetime | None = None) -> str:
    return (value or utc_now()).isoformat().replace("+00:00", "Z")


def parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except ValueError:
        return None


def sanitize_error(value: Any) -> str:
    text = str(value or "").strip()
    text = re.sub(r"AK-SK\s+[^\s]+", "AK-SK [REDACTED]", text, flags=re.IGNORECASE)
    text = re.sub(r"Bearer\s+[^\s]+", "Bearer [REDACTED]", text, flags=re.IGNORECASE)
    text = re.sub(r"(WK|SK)[A-Za-z0-9_-]{12,}", "[REDACTED]", text)
    return text[:500] or "未知错误"


def read_json(path: Path, fallback: dict[str, Any] | None = None) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        return payload if isinstance(payload, dict) else dict(fallback or {})
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return dict(fallback or {})


def atomic_json(path: Path, payload: dict[str, Any], mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.parent.chmod(0o700)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.chmod(mode)
    temp.replace(path)
    path.chmod(mode)


def total_reader_articles(payload: dict[str, Any]) -> int:
    return sum(int(item.get("readeck_articles") or 0) for item in payload.get("feeds") or [])


class WeRSSClient:
    def __init__(self, base_url: str, credentials_file: Path, poll_seconds: float = 2.0):
        self.base_url = base_url.rstrip("/") + "/api/v1/wx"
        credentials = read_json(credentials_file)
        key = str(credentials.get("key") or "")
        secret = str(credentials.get("secret") or "")
        if not key.startswith("WK") or not secret.startswith("SK"):
            raise RuntimeError("WeRSS 主动刷新凭据缺失或格式错误")
        self.authorization = f"AK-SK {key}:{secret}"
        self.poll_seconds = poll_seconds

    def json(self, method: str, path: str) -> dict[str, Any]:
        request = urllib.request.Request(
            self.base_url + path,
            headers={"Authorization": self.authorization, "Accept": "application/json"},
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            raise RuntimeError(f"WeRSS API 返回 HTTP {exc.code}") from exc
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            raise RuntimeError("WeRSS API 当前不可用") from exc
        if not isinstance(payload, dict):
            raise RuntimeError("WeRSS API 返回格式异常")
        if "200013" in json.dumps(payload, ensure_ascii=False):
            raise RuntimeError("微信返回 200013，主动刷新已停止")
        return payload

    @staticmethod
    def data(payload: dict[str, Any]) -> Any:
        if payload.get("code") not in (None, 0, 200):
            raise RuntimeError(payload.get("message") or "WeRSS API 操作失败")
        return payload.get("data", payload)

    def queue_status(self) -> dict[str, Any]:
        data = self.data(self.json("GET", "/task-queue/main/status"))
        return data if isinstance(data, dict) else {}

    def active_task_id(self) -> str:
        data = self.data(self.json("GET", "/message_tasks?limit=100&offset=0"))
        tasks = data.get("list") if isinstance(data, dict) else []
        enabled = [item for item in tasks or [] if int(item.get("status") or 0) == 1]
        preferred = next((item for item in enabled if "公众号" in str(item.get("name") or "")), None)
        task = preferred or (enabled[0] if enabled else None)
        task_id = str(task.get("id") or "") if task else ""
        if not task_id:
            raise RuntimeError("WeRSS 没有启用的公众号抓取任务")
        return task_id

    @staticmethod
    def busy(status: dict[str, Any]) -> bool:
        return bool(status.get("current_task")) or int(status.get("pending_count") or 0) > 0

    def trigger_and_wait(
        self,
        on_message: Callable[[str], None],
        timeout_seconds: int = 1800,
    ) -> None:
        before = self.queue_status()
        baseline_history = int(before.get("history_count") or 0)
        already_busy = self.busy(before)
        if already_busy:
            on_message("WeRSS 已有抓取任务，正在等待完成")
            observed = True
        else:
            task_id = self.active_task_id()
            self.data(self.json("GET", f"/message_tasks/{task_id}/run"))
            on_message("WeRSS 已接收全部公众号抓取任务")
            observed = False

        deadline = time.monotonic() + timeout_seconds
        idle_samples = 0
        while time.monotonic() < deadline:
            status = self.queue_status()
            encoded = json.dumps(status, ensure_ascii=False)
            if "200013" in encoded:
                raise RuntimeError("微信返回 200013，主动刷新已停止")
            current_busy = self.busy(status)
            history_changed = int(status.get("history_count") or 0) > baseline_history
            if current_busy or history_changed:
                observed = True
            if observed and not current_busy:
                idle_samples += 1
                if idle_samples >= 2:
                    return
            else:
                idle_samples = 0
            time.sleep(self.poll_seconds)
        if not observed:
            raise RuntimeError("WeRSS 未出现任务队列活动，未继续同步 Reader")
        raise RuntimeError("WeRSS 抓取超过 30 分钟仍未完成")


class RefreshCoordinator:
    def __init__(
        self,
        state_file: Path,
        reader_status_file: Path,
        werss_client: WeRSSClient,
        sync_script: Path,
        cooldown_seconds: int = 600,
        now: Callable[[], dt.datetime] = utc_now,
        sync_runner: Callable[[], None] | None = None,
    ):
        self.state_file = state_file
        self.reader_status_file = reader_status_file
        self.werss_client = werss_client
        self.sync_script = sync_script
        self.cooldown_seconds = max(600, cooldown_seconds)
        self.now = now
        self.sync_runner = sync_runner or self._run_sync
        self.lock = threading.Lock()
        self.worker: threading.Thread | None = None
        self.state = read_json(state_file, self._default_state())
        if self.state.get("phase") in ACTIVE_PHASES:
            self.state.update(
                phase="failed",
                message="刷新控制服务曾在任务中重启，请先确认 WeRSS 状态后重试",
                completed_at=iso(self.now()),
            )
            self._save()

    @staticmethod
    def _default_state() -> dict[str, Any]:
        return {
            "version": 1,
            "phase": "idle",
            "message": "可以检查新文章",
            "new_articles": 0,
            "started_at": "",
            "completed_at": "",
            "last_werss_fetch_at": "",
            "last_sync_at": "",
            "next_allowed_at": "",
            "consecutive_failures": 0,
        }

    def _save(self) -> None:
        atomic_json(self.state_file, self.state)

    def _public(self, override_phase: str | None = None, override_message: str | None = None) -> dict[str, Any]:
        payload = {
            key: self.state.get(key)
            for key in (
                "version",
                "phase",
                "message",
                "new_articles",
                "started_at",
                "completed_at",
                "last_werss_fetch_at",
                "last_sync_at",
                "next_allowed_at",
            )
        }
        if override_phase:
            payload["phase"] = override_phase
        if override_message:
            payload["message"] = override_message
        next_allowed = parse_iso(str(payload.get("next_allowed_at") or ""))
        payload["cooldown_remaining_seconds"] = max(
            0,
            int((next_allowed - self.now()).total_seconds()) if next_allowed else 0,
        )
        return payload

    def status(self) -> dict[str, Any]:
        with self.lock:
            return self._public()

    def start(self) -> tuple[int, dict[str, Any]]:
        with self.lock:
            if self.worker and self.worker.is_alive():
                return HTTPStatus.ACCEPTED, self._public("single_flight", "已有检查正在运行，不会重复请求微信")
            if int(self.state.get("consecutive_failures") or 0) >= 2:
                return HTTPStatus.CONFLICT, self._public(
                    "failed",
                    "主动刷新已因连续两次失败暂停，请先在 WeRSS 检查授权与任务状态",
                )
            next_allowed = parse_iso(str(self.state.get("next_allowed_at") or ""))
            if next_allowed and self.now() < next_allowed:
                return HTTPStatus.OK, self._public("cooldown", "主动抓取仍在 10 分钟冷却期")
            started = self.now()
            self.state.update(
                phase="checking_werss",
                message="正在请求 WeRSS 检查新文章",
                new_articles=0,
                started_at=iso(started),
                completed_at="",
                next_allowed_at=iso(started + dt.timedelta(seconds=self.cooldown_seconds)),
            )
            self._save()
            self.worker = threading.Thread(target=self._worker, daemon=True, name="reader-refresh-worker")
            self.worker.start()
            return HTTPStatus.ACCEPTED, self._public()

    def _message(self, message: str) -> None:
        with self.lock:
            self.state["message"] = message
            self._save()

    def _run_sync(self) -> None:
        if not self.sync_script.is_file():
            raise RuntimeError("reading-sync 尚未安装")
        process = subprocess.run(
            ["/usr/bin/python3", str(self.sync_script)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=1200,
            check=False,
        )
        if process.returncode != 0:
            raise RuntimeError("reading-sync 执行失败")

    def _worker(self) -> None:
        before = read_json(self.reader_status_file)
        try:
            self.werss_client.trigger_and_wait(self._message)
            with self.lock:
                self.state.update(phase="syncing_reader", message="WeRSS 抓取完成，正在同步阅读库")
                self._save()
            self.sync_runner()
            after = read_json(self.reader_status_file)
            with self.lock:
                self.state.update(
                    phase="complete",
                    message="检查完成，阅读库已更新",
                    new_articles=max(0, total_reader_articles(after) - total_reader_articles(before)),
                    completed_at=iso(self.now()),
                    last_werss_fetch_at=str(after.get("latest_fetched_at") or ""),
                    last_sync_at=str(after.get("generated_at") or iso(self.now())),
                    consecutive_failures=0,
                )
                self._save()
        except Exception as exc:  # noqa: BLE001 - 进程边界统一脱敏
            message = sanitize_error(exc)
            with self.lock:
                failures = int(self.state.get("consecutive_failures") or 0) + 1
                if "200013" in message:
                    failures = max(2, failures)
                    message = "微信返回 200013，主动刷新已暂停，请稍后在 WeRSS 手工确认"
                elif failures >= 2:
                    message = "主动刷新连续两次失败，已暂停自动重试，请先检查 WeRSS"
                self.state.update(
                    phase="failed",
                    message=message,
                    completed_at=iso(self.now()),
                    consecutive_failures=failures,
                )
                self._save()


class RefreshHandler(BaseHTTPRequestHandler):
    server_version = "ReaderRefresh/1"

    def do_GET(self) -> None:  # noqa: N802
        self._json(HTTPStatus.METHOD_NOT_ALLOWED, {"phase": "failed", "message": "只允许 POST"})

    def do_POST(self) -> None:  # noqa: N802
        app: RefreshApplication = self.server.app  # type: ignore[attr-defined]
        if self.path != "/refresh":
            self._json(HTTPStatus.NOT_FOUND, {"phase": "failed", "message": "Not found"})
            return
        if self.client_address[0] not in {"127.0.0.1", "::1"}:
            self._json(HTTPStatus.FORBIDDEN, {"phase": "failed", "message": "Forbidden"})
            return
        host = (self.headers.get("Host") or "").split(":", 1)[0].lower()
        origin = self.headers.get("Origin") or ""
        email = (self.headers.get("Cf-Access-Authenticated-User-Email") or "").lower()
        jwt = self.headers.get("Cf-Access-Jwt-Assertion") or ""
        supplied = self.headers.get("X-Reader-Control-Secret") or ""
        if (
            host != app.allowed_host
            or origin != app.allowed_origin
            or email != app.allowed_email
            or not jwt
            or not hmac.compare_digest(supplied, app.internal_secret)
        ):
            self._json(HTTPStatus.FORBIDDEN, {"phase": "failed", "message": "Forbidden"})
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length < 2 or length > 4096:
            self._json(HTTPStatus.BAD_REQUEST, {"phase": "failed", "message": "请求体格式错误"})
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._json(HTTPStatus.BAD_REQUEST, {"phase": "failed", "message": "请求体格式错误"})
            return
        action = payload.get("action") if isinstance(payload, dict) else None
        if action == "status":
            self._json(HTTPStatus.OK, app.coordinator.status())
        elif action == "start":
            status, response = app.coordinator.start()
            self._json(status, response)
        else:
            self._json(HTTPStatus.BAD_REQUEST, {"phase": "failed", "message": "未知操作"})

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(int(status))
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format: str, *_args: Any) -> None:
        return


class RefreshApplication:
    def __init__(
        self,
        coordinator: RefreshCoordinator,
        allowed_host: str,
        allowed_origin: str,
        allowed_email: str,
        internal_secret: str,
    ):
        self.coordinator = coordinator
        self.allowed_host = allowed_host.lower()
        self.allowed_origin = allowed_origin
        self.allowed_email = allowed_email.lower()
        self.internal_secret = internal_secret


def main() -> int:
    parser = argparse.ArgumentParser(description="Reader 主动刷新控制端")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--config-file", type=Path, default=DEFAULT_CONFIG_FILE)
    parser.add_argument("--credentials-file", type=Path, default=DEFAULT_CREDENTIALS)
    parser.add_argument("--secret-file", type=Path, default=DEFAULT_SECRET_FILE)
    parser.add_argument("--state-file", type=Path, default=DEFAULT_STATE_FILE)
    parser.add_argument("--reader-status-file", type=Path, default=DEFAULT_READER_STATUS)
    parser.add_argument("--sync-script", type=Path, default=DEFAULT_SYNC_SCRIPT)
    args = parser.parse_args()

    if args.host not in {"127.0.0.1", "::1"}:
        raise SystemExit("刷新控制端只允许绑定回环地址")
    runtime_config = read_json(args.config_file)
    allowed_host = str(runtime_config.get("allowed_host") or "reader.example.com")
    allowed_email = str(runtime_config.get("allowed_email") or "")
    if not allowed_email or "@" not in allowed_email:
        raise SystemExit("缺少 CF_ACCESS_EMAIL")
    internal_secret = args.secret_file.read_text(encoding="utf-8").strip()
    if len(internal_secret) < 32:
        raise SystemExit("刷新控制内部密钥格式错误")

    werss_client = WeRSSClient("http://127.0.0.1:8001", args.credentials_file)
    coordinator = RefreshCoordinator(
        args.state_file,
        args.reader_status_file,
        werss_client,
        args.sync_script,
    )
    app = RefreshApplication(
        coordinator,
        allowed_host,
        f"https://{allowed_host}",
        allowed_email,
        internal_secret,
    )
    server = ThreadingHTTPServer((args.host, args.port), RefreshHandler)
    server.app = app  # type: ignore[attr-defined]
    os.umask(0o077)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
