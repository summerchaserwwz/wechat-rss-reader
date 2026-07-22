from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PATCHER = Path(__file__).resolve().parents[1] / "scripts/patch-werss-runtime.py"


class PatchWeRSSRuntimeTests(unittest.TestCase):
    def test_periodic_fetch_uses_dedicated_refresh_page_limit_and_is_idempotent(self):
        source = """\
wx.get_Articles(item.faker_id,CallBack=UpdateArticle,Mps_id=item.id,Mps_title=item.mp_name, MaxPage=1)
wx.get_Articles(mp.faker_id,CallBack=UpdateArticle,Mps_id=mp.id,Mps_title=mp.mp_name, MaxPage=1,Over_CallBack=Update_Over,interval=interval)
"""
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "mps.py"
            target.write_text(source, encoding="utf-8")

            first = subprocess.run(
                [sys.executable, str(PATCHER), "--target", str(target)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            patched = target.read_text(encoding="utf-8")
            self.assertEqual(
                patched.count('MaxPage=int(cfg.get("refresh_max_page", "1"))'),
                2,
            )

            second = subprocess.run(
                [sys.executable, str(PATCHER), "--target", str(target)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(target.read_text(encoding="utf-8"), patched)

    def test_unknown_upstream_shape_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "mps.py"
            target.write_text("MaxPage=99\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(PATCHER), "--target", str(target)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("无法确认", result.stderr)


if __name__ == "__main__":
    unittest.main()
