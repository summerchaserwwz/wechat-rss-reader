from __future__ import annotations

import base64
import datetime as dt
import hashlib
import importlib.util
import json
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/reader-refresh-control.py"
SPEC = importlib.util.spec_from_file_location("reader_refresh_control", MODULE_PATH)
assert SPEC and SPEC.loader
refresh = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(refresh)


class BlockingWeRSS:
    def __init__(self):
        self.started = threading.Event()
        self.release = threading.Event()

    def trigger_and_wait(self, on_message):
        on_message("WeRSS 已接收全部公众号抓取任务")
        self.started.set()
        self.release.wait(timeout=3)


class FailingWeRSS:
    def trigger_and_wait(self, _on_message):
        raise RuntimeError("抓取失败")


class RefreshControlTests(unittest.TestCase):
    def status_payload(self, count):
        return {
            "generated_at": "2026-07-15T15:00:00Z",
            "latest_fetched_at": "2026-07-15T14:59:00Z",
            "feeds": [{"readeck_articles": count}],
        }

    def test_single_flight_then_complete_and_cooldown(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state_file = root / "state.json"
            reader_status = root / "reader.json"
            reader_status.write_text(json.dumps(self.status_payload(10)), encoding="utf-8")
            werss = BlockingWeRSS()

            def sync_runner():
                reader_status.write_text(json.dumps(self.status_payload(12)), encoding="utf-8")

            coordinator = refresh.RefreshCoordinator(
                state_file,
                reader_status,
                werss,
                root / "sync.py",
                cooldown_seconds=600,
                sync_runner=sync_runner,
            )
            status, first = coordinator.start()
            self.assertEqual(status, 202)
            self.assertEqual(first["phase"], "checking_werss")
            self.assertTrue(werss.started.wait(timeout=2))

            status, second = coordinator.start()
            self.assertEqual(status, 202)
            self.assertEqual(second["phase"], "single_flight")

            werss.release.set()
            coordinator.worker.join(timeout=3)
            completed = coordinator.status()
            self.assertEqual(completed["phase"], "complete")
            self.assertEqual(completed["new_articles"], 2)

            status, cooldown = coordinator.start()
            self.assertEqual(status, 200)
            self.assertEqual(cooldown["phase"], "cooldown")
            self.assertGreater(cooldown["cooldown_remaining_seconds"], 0)
            self.assertEqual(state_file.stat().st_mode & 0o777, 0o600)

    def test_transient_failures_do_not_permanently_pause_refresh(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            reader_status = root / "reader.json"
            reader_status.write_text(json.dumps(self.status_payload(10)), encoding="utf-8")
            now = [dt.datetime(2026, 7, 15, 15, 0, tzinfo=dt.timezone.utc)]
            coordinator = refresh.RefreshCoordinator(
                root / "state.json",
                reader_status,
                FailingWeRSS(),
                root / "sync.py",
                now=lambda: now[0],
                sync_runner=lambda: None,
            )
            coordinator.start()
            coordinator.worker.join(timeout=2)
            self.assertEqual(coordinator.status()["phase"], "failed")

            now[0] += dt.timedelta(minutes=11)
            coordinator.start()
            coordinator.worker.join(timeout=2)
            self.assertIn("连续 2 次失败", coordinator.status()["message"])

            now[0] += dt.timedelta(minutes=11)
            status, payload = coordinator.start()
            self.assertEqual(status, 202)
            self.assertEqual(payload["phase"], "checking_werss")
            coordinator.worker.join(timeout=2)
            self.assertIn("下次计划任务会自动重试", coordinator.status()["message"])

    def test_error_sanitizer_removes_credentials(self):
        message = refresh.sanitize_error("AK-SK WKabcdefghijklmnop:SKabcdefghijklmnop Bearer tokenvalue")
        self.assertNotIn("WKabcdefghijklmnop", message)
        self.assertNotIn("tokenvalue", message)

    def test_wechat_auth_coordinator_returns_qr_and_detects_scan(self):
        class FakeAdmin:
            authorized = False
            finished = False
            reads = 0
            stale_qr = b"\x89PNG\r\n\x1a\nstale"
            fresh_qr = b"\x89PNG\r\n\x1a\nfresh"

            def start_qr(self):
                return (
                    "temporary-token",
                    "/static/wx_qrcode.png?t=1",
                    hashlib.sha256(self.stale_qr).hexdigest(),
                )

            def read_qr(self, _qr_path):
                self.reads += 1
                return self.stale_qr if self.reads == 1 else self.fresh_qr

            def is_authorized(self, _token):
                return self.authorized

            def finish_qr(self, _token):
                self.finished = True

        admin = FakeAdmin()
        auth = refresh.WeChatAuthCoordinator(admin, qr_wait_seconds=1, poll_seconds=0.01)
        status, preparing = auth.start()
        self.assertEqual(status, 202)
        self.assertEqual(preparing["phase"], "auth_preparing")
        auth.worker.join(timeout=2)

        status, waiting = auth.status()
        self.assertEqual(status, 200)
        self.assertEqual(waiting["phase"], "auth_waiting")
        self.assertTrue(waiting["qr_image"].startswith("data:image/png;base64,"))
        self.assertEqual(
            base64.b64decode(waiting["qr_image"].split(",", 1)[1]),
            admin.fresh_qr,
        )

        admin.authorized = True
        status, completed = auth.status()
        self.assertEqual(status, 200)
        self.assertEqual(completed["phase"], "auth_complete")
        self.assertTrue(admin.finished)
        self.assertNotIn("qr_image", completed)

    def test_cloudflare_parked_task_remains_runnable(self):
        client = object.__new__(refresh.WeRSSClient)
        client.json = lambda _method, _path: {
            "code": 0,
            "data": {
                "list": [
                    {
                        "id": "task-cloudflare",
                        "name": "公众号每小时自动更新",
                        "status": 1,
                        "cron_exp": "43 3 29 2 *",
                    }
                ]
            },
        }
        self.assertEqual(client.active_task_id(), "task-cloudflare")

    def test_disabled_task_is_not_reported_as_runnable(self):
        client = object.__new__(refresh.WeRSSClient)
        client.json = lambda _method, _path: {
            "code": 0,
            "data": {
                "list": [
                    {"id": "task-disabled", "name": "公众号每小时自动更新", "status": 0}
                ]
            },
        }
        with self.assertRaisesRegex(RuntimeError, "没有已启用"):
            client.active_task_id()

    def test_expired_wechat_session_fails_before_queueing_refresh(self):
        client = object.__new__(refresh.WeRSSClient)
        requested = []

        def fake_json(_method, path):
            requested.append(path)
            if path.startswith("/mps?"):
                return {
                    "code": 0,
                    "data": {"list": [{"mp_name": "新智元"}]},
                }
            return {
                "detail": {
                    "code": 50001,
                    "message": "搜索公众号失败,请重新扫码授权！",
                }
            }

        client.json = fake_json
        client.queue_status = lambda: self.fail("授权失效时不应进入任务队列")

        with self.assertRaisesRegex(RuntimeError, "重新扫码"):
            client.trigger_and_wait(lambda _message: None)

        self.assertEqual(len(requested), 2)
        self.assertIn("%E6%96%B0%E6%99%BA%E5%85%83", requested[1])

    def test_long_refresh_keeps_waiting_while_queue_makes_progress(self):
        client = object.__new__(refresh.WeRSSClient)
        client.poll_seconds = 600
        statuses = iter(
            [
                {"pending_count": 4, "history_count": 10, "current_task": {"id": "a"}},
                {"pending_count": 4, "history_count": 10, "current_task": {"id": "a"}},
                {"pending_count": 3, "history_count": 10, "current_task": {"id": "b"}},
                {"pending_count": 2, "history_count": 10, "current_task": {"id": "c"}},
                {"pending_count": 1, "history_count": 10, "current_task": {"id": "d"}},
                {"pending_count": 0, "history_count": 11, "current_task": None},
                {"pending_count": 0, "history_count": 11, "current_task": None},
            ]
        )
        client.ensure_session = lambda: None
        client.queue_status = lambda: next(statuses)
        clock = [0.0]

        with (
            mock.patch.object(refresh.time, "monotonic", side_effect=lambda: clock[0]),
            mock.patch.object(refresh.time, "sleep", side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)),
        ):
            client.trigger_and_wait(lambda _message: None)

        self.assertGreater(clock[0], 1800)

    def test_expired_session_state_recovers_after_rescan(self):
        class RecoveredWeRSS:
            def __init__(self):
                self.probes = 0

            def ensure_session(self):
                self.probes += 1

            def trigger_and_wait(self, on_message):
                self.ensure_session()
                on_message("WeRSS 已接收全部公众号抓取任务")

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state_file = root / "state.json"
            state_file.write_text(
                json.dumps(
                    {
                        "version": 1,
                        "phase": "failed",
                        "message": "WeRSS 微信授权已失效，请打开 WeRSS 重新扫码授权",
                        "new_articles": 0,
                        "started_at": "2026-07-20T07:00:00Z",
                        "completed_at": "2026-07-20T07:00:01Z",
                        "last_werss_fetch_at": "",
                        "last_sync_at": "",
                        "next_allowed_at": "2026-07-20T09:00:00Z",
                        "consecutive_failures": 2,
                        "auth_required": True,
                    }
                ),
                encoding="utf-8",
            )
            reader_status = root / "reader.json"
            reader_status.write_text(json.dumps(self.status_payload(10)), encoding="utf-8")
            werss = RecoveredWeRSS()
            coordinator = refresh.RefreshCoordinator(
                state_file,
                reader_status,
                werss,
                root / "sync.py",
                now=lambda: dt.datetime(2026, 7, 20, 8, 0, tzinfo=dt.timezone.utc),
                sync_runner=lambda: None,
            )

            status, payload = coordinator.start()
            self.assertEqual(status, 202)
            self.assertEqual(payload["phase"], "checking_werss")
            coordinator.worker.join(timeout=2)
            self.assertEqual(coordinator.status()["phase"], "complete")
            self.assertEqual(werss.probes, 2)

    def test_sync_success_keeps_expired_session_gate_for_next_refresh(self):
        class ExpiredWeRSS:
            def ensure_session(self):
                raise RuntimeError("重新扫码")

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state_file = root / "state.json"
            state_file.write_text(
                json.dumps(
                    {
                        **refresh.RefreshCoordinator._default_state(),
                        "phase": "failed",
                        "message": "WeRSS 微信授权已失效，请打开 WeRSS 重新扫码授权",
                        "consecutive_failures": 1,
                        "auth_required": True,
                    }
                ),
                encoding="utf-8",
            )
            reader_status = root / "reader.json"
            reader_status.write_text(json.dumps(self.status_payload(10)), encoding="utf-8")
            coordinator = refresh.RefreshCoordinator(
                state_file,
                reader_status,
                ExpiredWeRSS(),
                root / "sync.py",
                sync_runner=lambda: None,
            )

            status, payload = coordinator.start_sync()
            self.assertEqual(status, 202)
            coordinator.worker.join(timeout=2)
            self.assertEqual(coordinator.status()["phase"], "complete")

            status, payload = coordinator.start()
            self.assertEqual(status, 409)
            self.assertEqual(payload["phase"], "failed")
            self.assertIn("重新扫码", payload["message"])

    def test_sync_only_skips_werss_and_counts_all_reader_items(self):
        class UnexpectedWeRSS:
            def trigger_and_wait(self, _on_message):
                raise AssertionError("sync-only 不应触发 WeRSS")

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            reader_status = root / "reader.json"
            reader_status.write_text(
                json.dumps({"total_reader_items": 10, "feeds": []}),
                encoding="utf-8",
            )

            def sync_runner():
                reader_status.write_text(
                    json.dumps({"total_reader_items": 12, "feeds": []}),
                    encoding="utf-8",
                )

            coordinator = refresh.RefreshCoordinator(
                root / "state.json",
                reader_status,
                UnexpectedWeRSS(),
                root / "sync.py",
                sync_runner=sync_runner,
            )
            status, payload = coordinator.start_sync()
            self.assertEqual(status, 202)
            self.assertEqual(payload["phase"], "syncing_reader")
            coordinator.worker.join(timeout=2)
            completed = coordinator.status()
            self.assertEqual(completed["phase"], "complete")
            self.assertEqual(completed["new_articles"], 2)

    def test_http_endpoint_requires_post_identity_origin_and_internal_secret(self):
        class FakeCoordinator:
            sync_started = False

            def status(self):
                return {"phase": "idle", "message": "ok"}

            def start(self):
                return 202, {"phase": "checking_werss", "message": "started"}

            def start_sync(self):
                self.sync_started = True
                return 202, {"phase": "syncing_reader", "message": "started"}

        class FakeWechatAuth:
            def start(self):
                return 202, {"phase": "auth_preparing", "message": "preparing"}

            def status(self):
                return 200, {"phase": "auth_waiting", "message": "waiting", "qr_image": "data:image/png;base64,AA=="}

        coordinator = FakeCoordinator()
        app = refresh.RefreshApplication(
            coordinator,
            "reader.sumerchaser.top",
            "https://reader.sumerchaser.top",
            "allowed@example.com",
            "secret-value",
            FakeWechatAuth(),
        )
        server = refresh.ThreadingHTTPServer(("127.0.0.1", 0), refresh.RefreshHandler)
        server.app = app
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}/refresh"
        try:
            with self.assertRaises(urllib.error.HTTPError) as get_error:
                urllib.request.urlopen(base, timeout=2)
            self.assertEqual(get_error.exception.code, 405)

            body = json.dumps({"action": "status"}).encode("utf-8")
            bad = urllib.request.Request(base, data=body, headers={"Content-Type": "application/json"}, method="POST")
            with self.assertRaises(urllib.error.HTTPError) as bad_error:
                urllib.request.urlopen(bad, timeout=2)
            self.assertEqual(bad_error.exception.code, 403)

            good = urllib.request.Request(
                base,
                data=body,
                headers={
                    "Content-Type": "application/json",
                    "Host": "reader.sumerchaser.top",
                    "Origin": "https://reader.sumerchaser.top",
                    "Cf-Access-Authenticated-User-Email": "allowed@example.com",
                    "Cf-Access-Jwt-Assertion": "test-jwt",
                    "X-Reader-Control-Secret": "secret-value",
                },
                method="POST",
            )
            with urllib.request.urlopen(good, timeout=2) as response:
                payload = json.loads(response.read().decode("utf-8"))
            self.assertEqual(payload["phase"], "idle")

            auth_start = urllib.request.Request(
                base,
                data=json.dumps({"action": "auth_start"}).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "Host": "reader.sumerchaser.top",
                    "Origin": "https://reader.sumerchaser.top",
                    "Cf-Access-Authenticated-User-Email": "allowed@example.com",
                    "Cf-Access-Jwt-Assertion": "test-jwt",
                    "X-Reader-Control-Secret": "secret-value",
                },
                method="POST",
            )
            with urllib.request.urlopen(auth_start, timeout=2) as response:
                payload = json.loads(response.read().decode("utf-8"))
            self.assertEqual(payload["phase"], "auth_preparing")

            machine = urllib.request.Request(
                base,
                data=json.dumps({"action": "sync"}).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "Host": "reader.sumerchaser.top",
                    "Cf-Access-Jwt-Assertion": "service-token-jwt",
                    "X-Reader-Automation": "cloudflare",
                    "X-Reader-Control-Secret": "secret-value",
                },
                method="POST",
            )
            with urllib.request.urlopen(machine, timeout=2) as response:
                payload = json.loads(response.read().decode("utf-8"))
            self.assertEqual(payload["phase"], "syncing_reader")
            self.assertTrue(coordinator.sync_started)

            machine_auth = urllib.request.Request(
                base,
                data=json.dumps({"action": "auth_start"}).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "Host": "reader.sumerchaser.top",
                    "Cf-Access-Jwt-Assertion": "service-token-jwt",
                    "X-Reader-Automation": "cloudflare",
                    "X-Reader-Control-Secret": "secret-value",
                },
                method="POST",
            )
            with self.assertRaises(urllib.error.HTTPError) as machine_auth_error:
                urllib.request.urlopen(machine_auth, timeout=2)
            self.assertEqual(machine_auth_error.exception.code, 403)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
