#!/usr/bin/env python3
"""Reader -> WeRSS -> reading-sync 受保护主动刷新控制端。"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import hmac
import json
import os
import re
import subprocess
import threading
import time
import urllib.error
import urllib.parse
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
DEFAULT_WERSS_MAX_WAIT_SECONDS = 6 * 60 * 60
DEFAULT_WERSS_STALL_TIMEOUT_SECONDS = 30 * 60
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
    if "total_reader_items" in payload:
        return int(payload.get("total_reader_items") or 0)
    return sum(int(item.get("readeck_articles") or 0) for item in payload.get("feeds") or [])


def env_values(path: Path) -> dict[str, str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise RuntimeError("无法读取 WeRSS 管理配置") from exc
    values: dict[str, str] = {}
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


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

    def ensure_session(self) -> None:
        feeds = self.data(self.json("GET", "/mps?limit=1&offset=0"))
        items = feeds.get("list") if isinstance(feeds, dict) else []
        probe_name = str((items or [{}])[0].get("mp_name") or "微信")
        encoded_name = urllib.parse.quote(probe_name, safe="")
        payload = self.json("GET", f"/mps/search/{encoded_name}?limit=1&offset=0")
        detail = payload.get("detail") if isinstance(payload, dict) else None
        detail_message = str(detail.get("message") or "") if isinstance(detail, dict) else ""
        if "重新扫码" in detail_message or "授权" in detail_message:
            raise RuntimeError("WeRSS 微信授权已失效，请打开 WeRSS 重新扫码授权")
        self.data(payload)

    def active_task_id(self) -> str:
        data = self.data(self.json("GET", "/message_tasks?limit=100&offset=0"))
        tasks = data.get("list") if isinstance(data, dict) else []
        enabled = [item for item in tasks or [] if int(item.get("status") or 0) == 1]
        preferred = next((item for item in enabled if "公众号" in str(item.get("name") or "")), None)
        task = preferred or (enabled[0] if enabled else None)
        task_id = str(task.get("id") or "") if task else ""
        if not task_id:
            raise RuntimeError("WeRSS 没有已启用的公众号抓取任务")
        return task_id

    @staticmethod
    def busy(status: dict[str, Any]) -> bool:
        return bool(status.get("current_task")) or int(status.get("pending_count") or 0) > 0

    @staticmethod
    def progress_marker(status: dict[str, Any]) -> tuple[int, int, str]:
        current = status.get("current_task")
        if isinstance(current, dict):
            current_id = str(current.get("id") or current.get("task_id") or current.get("name") or "")
        else:
            current_id = str(current or "")
        return (
            int(status.get("pending_count") or 0),
            int(status.get("history_count") or 0),
            current_id,
        )

    def trigger_and_wait(
        self,
        on_message: Callable[[str], None],
        timeout_seconds: int = DEFAULT_WERSS_MAX_WAIT_SECONDS,
        stall_timeout_seconds: int = DEFAULT_WERSS_STALL_TIMEOUT_SECONDS,
    ) -> None:
        self.ensure_session()
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

        started_at = time.monotonic()
        deadline = started_at + timeout_seconds
        last_progress_at = started_at
        last_marker = self.progress_marker(before)
        idle_samples = 0
        while time.monotonic() < deadline:
            status = self.queue_status()
            now = time.monotonic()
            encoded = json.dumps(status, ensure_ascii=False)
            if "200013" in encoded:
                raise RuntimeError("微信返回 200013，主动刷新已停止")
            current_busy = self.busy(status)
            history_changed = int(status.get("history_count") or 0) > baseline_history
            marker = self.progress_marker(status)
            if marker != last_marker:
                last_marker = marker
                last_progress_at = now
            if current_busy or history_changed:
                observed = True
            if observed and not current_busy:
                idle_samples += 1
                if idle_samples >= 2:
                    return
            else:
                idle_samples = 0
            if now - last_progress_at >= stall_timeout_seconds:
                raise RuntimeError("WeRSS 队列连续 30 分钟没有进展")
            time.sleep(self.poll_seconds)
        if not observed:
            raise RuntimeError("WeRSS 未出现任务队列活动，未继续同步 Reader")
        raise RuntimeError("WeRSS 抓取超过 6 小时仍未完成")


class WeRSSAdminClient:
    def __init__(self, base_url: str, env_file: Path):
        self.base_url = base_url.rstrip("/")
        values = env_values(env_file)
        self.username = str(values.get("WERSS_ADMIN_USERNAME") or "werss_admin")
        self.password = str(values.get("WERSS_BOOTSTRAP_PASSWORD") or "")
        if not self.password:
            raise RuntimeError("WeRSS 管理配置缺少登录密码")

    def request(
        self,
        method: str,
        path: str,
        *,
        data: bytes | None = None,
        headers: dict[str, str] | None = None,
        binary: bool = False,
    ) -> Any:
        request = urllib.request.Request(
            urllib.parse.urljoin(self.base_url + "/", path.lstrip("/")),
            data=data,
            headers={"Accept": "application/json", **(headers or {})},
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                content = response.read()
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError) as exc:
            raise RuntimeError("无法连接 WeRSS 微信授权服务") from exc
        if binary:
            return content
        try:
            payload = json.loads(content.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise RuntimeError("WeRSS 微信授权服务返回异常") from exc
        if not isinstance(payload, dict):
            raise RuntimeError("WeRSS 微信授权服务返回异常")
        return payload

    def login(self) -> str:
        form = urllib.parse.urlencode(
            {"username": self.username, "password": self.password}
        ).encode("utf-8")
        payload = self.request(
            "POST",
            "/api/v1/wx/auth/login",
            data=form,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        data = payload.get("data") if isinstance(payload, dict) else None
        token = str(data.get("access_token") or "") if isinstance(data, dict) else ""
        if not token:
            raise RuntimeError("WeRSS 管理登录失败")
        return token

    def authorized_json(self, token: str, path: str) -> dict[str, Any]:
        payload = self.request(
            "GET",
            path,
            headers={"Authorization": f"Bearer {token}"},
        )
        return payload if isinstance(payload, dict) else {}

    def start_qr(self) -> tuple[str, str, str]:
        token = self.login()
        try:
            previous_qr = self.read_qr("/static/wx_qrcode.png")
            previous_digest = hashlib.sha256(previous_qr).hexdigest()
        except RuntimeError:
            previous_digest = ""
        payload = self.authorized_json(token, "/api/v1/wx/auth/qr/code")
        data = payload.get("data") if isinstance(payload, dict) else None
        qr_path = str(data.get("code") or "") if isinstance(data, dict) else ""
        if not qr_path.startswith("/static/wx_qrcode.png"):
            raise RuntimeError("WeRSS 未生成微信授权二维码")
        return token, qr_path, previous_digest

    def read_qr(self, qr_path: str) -> bytes:
        content = self.request("GET", qr_path, binary=True)
        if not isinstance(content, bytes) or not content.startswith(b"\x89PNG"):
            raise RuntimeError("WeRSS 微信授权二维码尚未就绪")
        return content

    def is_authorized(self, token: str) -> bool:
        payload = self.authorized_json(token, "/api/v1/wx/auth/qr/status")
        data = payload.get("data") if isinstance(payload, dict) else None
        return bool(data.get("login_status")) if isinstance(data, dict) else False

    def finish_qr(self, token: str) -> None:
        self.authorized_json(token, "/api/v1/wx/auth/qr/over")


class WeChatAuthCoordinator:
    def __init__(
        self,
        admin_client: WeRSSAdminClient,
        qr_wait_seconds: int = 45,
        poll_seconds: float = 0.5,
    ):
        self.admin_client = admin_client
        self.qr_wait_seconds = max(1, qr_wait_seconds)
        self.poll_seconds = max(0.01, poll_seconds)
        self.lock = threading.Lock()
        self.worker: threading.Thread | None = None
        self.token = ""
        self.state: dict[str, Any] = {
            "phase": "auth_idle",
            "message": "需要微信扫码授权",
        }

    def _public(self) -> dict[str, Any]:
        return {
            key: value
            for key, value in self.state.items()
            if key in {"phase", "message", "qr_image"}
        }

    def start(self) -> tuple[int, dict[str, Any]]:
        with self.lock:
            if self.worker and self.worker.is_alive():
                return HTTPStatus.ACCEPTED, self._public()
            self.token = ""
            self.state = {
                "phase": "auth_preparing",
                "message": "正在生成微信授权二维码",
            }
            self.worker = threading.Thread(
                target=self._prepare,
                daemon=True,
                name="wechat-auth-worker",
            )
            self.worker.start()
            return HTTPStatus.ACCEPTED, self._public()

    def _prepare(self) -> None:
        try:
            token, qr_path, previous_digest = self.admin_client.start_qr()
            deadline = time.monotonic() + self.qr_wait_seconds
            while time.monotonic() < deadline:
                try:
                    content = self.admin_client.read_qr(qr_path)
                    current_digest = hashlib.sha256(content).hexdigest()
                    if previous_digest and hmac.compare_digest(current_digest, previous_digest):
                        time.sleep(self.poll_seconds)
                        continue
                    break
                except RuntimeError:
                    time.sleep(self.poll_seconds)
            else:
                raise RuntimeError("微信授权二维码生成超时")
            encoded = base64.b64encode(content).decode("ascii")
            with self.lock:
                self.token = token
                self.state = {
                    "phase": "auth_waiting",
                    "message": "请使用微信扫码完成公众号授权",
                    "qr_image": f"data:image/png;base64,{encoded}",
                }
        except Exception:  # noqa: BLE001 - 授权错误不公开凭据或上游响应
            with self.lock:
                self.token = ""
                self.state = {
                    "phase": "auth_failed",
                    "message": "二维码生成失败，请重新尝试",
                }

    def status(self) -> tuple[int, dict[str, Any]]:
        with self.lock:
            phase = str(self.state.get("phase") or "")
            token = self.token
        if phase == "auth_waiting" and token:
            try:
                authorized = self.admin_client.is_authorized(token)
            except Exception:  # noqa: BLE001 - 保留二维码等待用户重试
                authorized = False
            if authorized:
                try:
                    self.admin_client.finish_qr(token)
                except Exception:
                    pass
                with self.lock:
                    self.token = ""
                    self.state = {
                        "phase": "auth_complete",
                        "message": "微信授权已恢复，正在继续检查新文章",
                    }
        with self.lock:
            return HTTPStatus.OK, self._public()


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
            "auth_required": False,
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
            auth_required = bool(self.state.get("auth_required")) or (
                "授权已失效" in str(self.state.get("message") or "")
            )
            if auth_required:
                try:
                    self.werss_client.ensure_session()
                except Exception:  # noqa: BLE001 - 只公开固定的扫码提示
                    return HTTPStatus.CONFLICT, self._public(
                        "failed",
                        "WeRSS 微信授权仍未恢复，请重新扫码授权",
                    )
                self.state.update(
                    message="微信授权已恢复，可以检查新文章",
                    next_allowed_at="",
                    consecutive_failures=0,
                    auth_required=False,
                )
                self._save()
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

    def start_sync(self) -> tuple[int, dict[str, Any]]:
        """只同步本机已有的 WeRSS/Obsidian 数据，不触发微信抓取。"""
        with self.lock:
            if self.worker and self.worker.is_alive():
                return HTTPStatus.ACCEPTED, self._public("single_flight", "已有同步正在运行")
            started = self.now()
            self.state.update(
                phase="syncing_reader",
                message="正在同步微信消息与阅读库",
                new_articles=0,
                started_at=iso(started),
                completed_at="",
            )
            self._save()
            self.worker = threading.Thread(
                target=self._sync_only_worker,
                daemon=True,
                name="reader-sync-worker",
            )
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
            new_articles = max(0, total_reader_articles(after) - total_reader_articles(before))
            with self.lock:
                self.state.update(
                    phase="complete",
                    message=(
                        f"检查完成，新增 {new_articles} 篇文章"
                        if new_articles
                        else "检查完成，未发现新文章"
                    ),
                    new_articles=new_articles,
                    completed_at=iso(self.now()),
                    last_werss_fetch_at=str(after.get("latest_fetched_at") or ""),
                    last_sync_at=str(after.get("generated_at") or iso(self.now())),
                    consecutive_failures=0,
                    auth_required=False,
                )
                self._save()
        except Exception as exc:  # noqa: BLE001 - 进程边界统一脱敏
            message = sanitize_error(exc)
            with self.lock:
                failures = int(self.state.get("consecutive_failures") or 0) + 1
                if "200013" in message:
                    message = "微信返回 200013，本次抓取失败，下次计划任务会自动重试"
                elif "重新扫码" in message or "授权已失效" in message:
                    message = "WeRSS 微信授权已失效，请打开 WeRSS 重新扫码授权"
                elif failures >= 2:
                    message = f"主动刷新连续 {failures} 次失败，下次计划任务会自动重试"
                self.state.update(
                    phase="failed",
                    message=message,
                    completed_at=iso(self.now()),
                    consecutive_failures=failures,
                    auth_required=("重新扫码" in message or "授权已失效" in message),
                )
                self._save()

    def _sync_only_worker(self) -> None:
        before = read_json(self.reader_status_file)
        try:
            self.sync_runner()
            after = read_json(self.reader_status_file)
            with self.lock:
                self.state.update(
                    phase="complete",
                    message="微信消息与阅读库同步完成",
                    new_articles=max(0, total_reader_articles(after) - total_reader_articles(before)),
                    completed_at=iso(self.now()),
                    last_sync_at=str(after.get("generated_at") or iso(self.now())),
                )
                self._save()
        except Exception as exc:  # noqa: BLE001 - 进程边界统一脱敏
            with self.lock:
                self.state.update(
                    phase="failed",
                    message=sanitize_error(exc),
                    completed_at=iso(self.now()),
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
        automation = self.headers.get("X-Reader-Automation") or ""
        supplied = self.headers.get("X-Reader-Control-Secret") or ""
        human_identity = origin == app.allowed_origin and email == app.allowed_email
        machine_identity = automation == "cloudflare"
        if (
            host != app.allowed_host
            or not jwt
            or not hmac.compare_digest(supplied, app.internal_secret)
            or not (human_identity or machine_identity)
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
        elif action == "sync":
            status, response = app.coordinator.start_sync()
            self._json(status, response)
        elif action == "auth_start":
            if not human_identity or app.wechat_auth is None:
                self._json(HTTPStatus.FORBIDDEN, {"phase": "failed", "message": "Forbidden"})
                return
            status, response = app.wechat_auth.start()
            self._json(status, response)
        elif action == "auth_status":
            if not human_identity or app.wechat_auth is None:
                self._json(HTTPStatus.FORBIDDEN, {"phase": "failed", "message": "Forbidden"})
                return
            status, response = app.wechat_auth.status()
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
        wechat_auth: WeChatAuthCoordinator | None = None,
    ):
        self.coordinator = coordinator
        self.allowed_host = allowed_host.lower()
        self.allowed_origin = allowed_origin
        self.allowed_email = allowed_email.lower()
        self.internal_secret = internal_secret
        self.wechat_auth = wechat_auth


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
    admin_env_file = Path(str(runtime_config.get("admin_env_file") or ""))
    if not allowed_email or "@" not in allowed_email:
        raise SystemExit("缺少 CF_ACCESS_EMAIL")
    internal_secret = args.secret_file.read_text(encoding="utf-8").strip()
    if len(internal_secret) < 32:
        raise SystemExit("刷新控制内部密钥格式错误")
    if not admin_env_file.is_file():
        raise SystemExit("缺少 WeRSS 管理配置文件")

    werss_client = WeRSSClient("http://127.0.0.1:8001", args.credentials_file)
    admin_client = WeRSSAdminClient("http://127.0.0.1:8001", admin_env_file)
    wechat_auth = WeChatAuthCoordinator(admin_client)
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
        wechat_auth,
    )
    server = ThreadingHTTPServer((args.host, args.port), RefreshHandler)
    server.app = app  # type: ignore[attr-defined]
    os.umask(0o077)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
