from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/reading-sync.py"
SPEC = importlib.util.spec_from_file_location("reading_sync", MODULE_PATH)
assert SPEC and SPEC.loader
reading_sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reading_sync)


class ReadingSyncTests(unittest.TestCase):
    def bookmark(self):
        return {
            "id": "AbCdEf1234567890Ghij",
            "title": "一篇测试文章",
            "url": "https://mp.weixin.qq.com/s/example",
            "published": "2026-07-14T10:00:00Z",
            "created": "2026-07-14T10:01:00Z",
            "is_marked": True,
            "read_progress": 42,
        }

    def test_render_contains_obsidian_highlight_and_note(self):
        output = reading_sync.render_note(
            self.bookmark(),
            "测试公众号",
            "---\ntitle: old\n---\n\n# 一篇测试文章\n\n正文里有 ==高亮==[^1]\n\n[^1]: 我的批注\n",
            [{"text": "高亮", "note": "我的批注", "color": "yellow", "created": "2026-07-14"}],
        )
        self.assertIn("> ==高亮==", output)
        self.assertIn("> 批注：我的批注", output)
        self.assertIn("正文里有 ==高亮==[^1]", output)
        self.assertNotIn("title: old", output)

    def test_manual_notes_and_frontmatter_survive_refresh(self):
        first = reading_sync.render_note(self.bookmark(), "测试公众号", "# 标题\n\n第一版正文", [])
        edited = first.replace("reading_status: 待读", "reading_status: 已批注")
        edited = edited.replace("> - 核心判断：", "> - 核心判断：这是我的判断")
        second = reading_sync.render_note(self.bookmark(), "测试公众号", "# 标题\n\n第二版正文", [], edited)
        self.assertIn("reading_status: 已批注", second)
        self.assertIn("> - 核心判断：这是我的判断", second)
        self.assertIn("第二版正文", second)
        self.assertNotIn("第一版正文", second)

    def test_filename_is_dated_and_collision_safe(self):
        name = reading_sync.safe_filename('标题/带:非法*字符?', "AbCdEf1234567890Ghij")
        self.assertEqual(name, "标题-带-非法-字符--7890Ghij.md")

    def test_long_multiline_title_is_cleaned_for_readeck(self):
        value = "第一行标题\n\n" + "正文" * 800
        self.assertEqual(reading_sync.clean_title(value), "第一行标题")
        self.assertLessEqual(len(reading_sync.clean_title("标题" * 500)), 240)

    def test_state_persists_mapping_without_secret(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_path = Path(tmp) / "state.sqlite3"
            state = reading_sync.State(state_path)
            state.upsert_article(
                {
                    "id": "article-1",
                    "url": "https://mp.weixin.qq.com/s/example",
                    "feed_name": "测试公众号",
                    "publish_time": 1784029237,
                    "title": "标题",
                },
                "bookmark-1",
            )
            row = state.by_bookmark("bookmark-1")
            self.assertEqual(row["article_id"], "article-1")
            self.assertNotIn("token", row.keys())
            self.assertEqual(state_path.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
