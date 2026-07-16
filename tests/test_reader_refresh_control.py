from __future__ import annotations

import datetime as dt
import importlib.util
import json
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path


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

    def test_two_failures_pause_active_refresh(self):
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
            self.assertIn("连续两次失败", coordinator.status()["message"])

            now[0] += dt.timedelta(minutes=11)
            status, payload = coordinator.start()
            self.assertEqual(status, 409)
            self.assertEqual(payload["phase"], "failed")

    def test_error_sanitizer_removes_credentials(self):
        message = refresh.sanitize_error("AK-SK WKabcdefghijklmnop:SKabcdefghijklmnop Bearer tokenvalue")
        self.assertNotIn("WKabcdefghijklmnop", message)
        self.assertNotIn("tokenvalue", message)

    def test_http_endpoint_requires_post_identity_origin_and_internal_secret(self):
        class FakeCoordinator:
            def status(self):
                return {"phase": "idle", "message": "ok"}

            def start(self):
                return 202, {"phase": "checking_werss", "message": "started"}

        app = refresh.RefreshApplication(
            FakeCoordinator(),
            "reader.sumerchaser.top",
            "https://reader.sumerchaser.top",
            "allowed@example.com",
            "secret-value",
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
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
