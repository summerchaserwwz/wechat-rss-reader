import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "prepare-obsidian-inbox.py"
SPEC = importlib.util.spec_from_file_location("prepare_obsidian_inbox", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class PrepareObsidianInboxTest(unittest.TestCase):
    def test_adds_date_layout_fields_and_renames(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "一篇文章.md"
            source.write_text(
                "---\ntitle: 一篇文章\npublishedAt: 2026-07-13T08:00:00+08:00\n---\n正文内容\n",
                encoding="utf-8",
            )

            result = MODULE.process(source)
            target = Path(temp) / "2026-07-13-一篇文章.md"

            self.assertEqual(result, "updated:2026-07-13-一篇文章.md")
            self.assertFalse(source.exists())
            self.assertTrue(target.exists())
            text = target.read_text(encoding="utf-8")
            self.assertIn("saved_at: 2026-07-13", text)
            self.assertIn("reading_status: 待读", text)
            self.assertIn(MODULE.MARKER, text)
            self.assertIn("## 原文\n\n正文内容", text)

    def test_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "2026-07-13-一篇文章.md"
            source.write_text(
                "---\npublishedAt: 2026-07-13\nreading_status: 待读\nrating: \ntopics: []\npromote_to: 无\nreviewed_at: \nsaved_at: 2026-07-13\n---\n"
                + MODULE.annotation_block("2026-07-13")
                + "正文内容\n",
                encoding="utf-8",
            )

            before = source.read_text(encoding="utf-8")
            self.assertEqual(MODULE.process(source), "unchanged")
            self.assertEqual(source.read_text(encoding="utf-8"), before)

    def test_never_overwrites_existing_target(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "同名.md"
            target = Path(temp) / "2026-07-13-同名.md"
            source.write_text("---\npublishedAt: 2026-07-13\n---\n新内容", encoding="utf-8")
            target.write_text("已有批注", encoding="utf-8")

            with self.assertRaises(FileExistsError):
                MODULE.process(source)
            self.assertEqual(target.read_text(encoding="utf-8"), "已有批注")
            self.assertTrue(source.exists())


if __name__ == "__main__":
    unittest.main()
