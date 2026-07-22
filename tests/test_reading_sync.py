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
            "labels": ["微信公众号", "WeRSS", "公众号/测试公众号", "价值/4", "主题/Agent"],
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
        self.assertIn("reader_value: 4", output)
        self.assertIn('  - "Agent"', output)

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

    def test_reader_metadata_separates_managed_value_and_topics(self):
        value, topics = reading_sync.reader_metadata(
            ["微信公众号", "价值/2", "主题/AI", "主题/工程", "主题/AI", "价值/5"]
        )
        self.assertEqual(value, 5)
        self.assertEqual(topics, ["AI", "工程"])

    def test_reader_status_contains_feed_counts_without_secret(self):
        status = reading_sync.build_reader_status(
            {
                "cron": "17 * * * *",
                "cron_status": 1,
                "feeds": [
                    {
                        "mp_name": "测试公众号",
                        "articles": 3,
                        "complete_articles": 2,
                        "update_time": 1784029237,
                        "latest_published_at": 1784029200,
                    }
                ],
            },
            [self.bookmark()],
        )
        self.assertEqual(status["health"], "ok")
        self.assertEqual(status["scheduler"], "werss")
        self.assertEqual(status["cron"], "17 * * * *")
        self.assertEqual(status["werss_native_cron"], "17 * * * *")
        self.assertEqual(status["sync_interval_seconds"], 300)
        self.assertEqual(status["feeds"][0]["readeck_articles"], 1)
        self.assertEqual(status["feeds"][0]["unread"], 1)
        self.assertNotIn("token", str(status).lower())

    def test_reader_status_reports_cloudflare_schedule_when_werss_cron_is_parked(self):
        status = reading_sync.build_reader_status(
            {
                "cron": "43 3 29 2 *",
                "cron_status": 1,
                "feeds": [
                    {
                        "mp_name": "测试公众号",
                        "articles": 1,
                        "complete_articles": 1,
                        "update_time": 1784029237,
                    }
                ],
            },
            [self.bookmark()],
        )
        self.assertEqual(status["health"], "ok")
        self.assertEqual(status["scheduler"], "cloudflare")
        self.assertEqual(status["cron"], "17 * * * *")
        self.assertEqual(status["werss_native_cron"], "43 3 29 2 *")

    def test_helper_note_extracts_frontmatter_and_body_urls(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "2026-07-17-收藏.md"
            note.write_text(
                "---\nurl: https://mp.weixin.qq.com/s/example#part\n---\n\n"
                "# 收藏\n\n[另一篇](https://example.com/article?a=1)\n"
                "![](https://example.com/cover.png)\n",
                encoding="utf-8",
            )
            self.assertEqual(
                reading_sync.helper_note_urls(note),
                ["https://mp.weixin.qq.com/s/example"],
            )

    def test_helper_message_without_frontmatter_extracts_multiple_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            note = Path(tmp) / "同步助手_2026-07-17.md"
            note.write_text(
                "[第一篇](https://example.com/one)\n\nhttps://example.com/two\n"
                "![](https://media.example.com/asset-without-extension)\n",
                encoding="utf-8",
            )
            self.assertEqual(
                reading_sync.helper_note_urls(note),
                ["https://example.com/one", "https://example.com/two"],
            )

    def test_helper_url_rejects_local_and_image_targets(self):
        self.assertIsNone(reading_sync.canonical_external_url("http://127.0.0.1/private"))
        self.assertIsNone(reading_sync.canonical_external_url("https://example.com/image.webp"))
        self.assertIsNone(reading_sync.canonical_external_url("https://wx.qlogo.cn/asset-without-extension"))
        self.assertEqual(
            reading_sync.canonical_external_url("https://example.com/article#section"),
            "https://example.com/article",
        )
        self.assertEqual(
            reading_sync.canonical_external_url("https://example.com/…"),
            reading_sync.canonical_external_url("https://example.com/%E2%80%A6"),
        )

    def test_helper_redirect_is_idempotent_across_runs(self):
        class FakeClient:
            def __init__(self):
                self.items = []
                self.created = 0

            def list_bookmarks(self):
                return list(self.items)

            def add_helper_labels(self, bookmark):
                return False

            def create_external_bookmark(self, url, title):
                self.created += 1
                bookmark_id = f"bookmark-{self.created}"
                self.items.append(
                    {
                        "id": bookmark_id,
                        "url": "https://example.com/final-location",
                        "title": title,
                        "labels": [reading_sync.HELPER_LABEL],
                    }
                )
                return bookmark_id

            def wait_loaded(self, bookmark_id):
                return next(item for item in self.items if item["id"] == bookmark_id)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "helper"
            root.mkdir()
            note = root / "收藏.md"
            note.write_text(
                "---\nurl: https://example.com/original-location\n---\n# 收藏\n",
                encoding="utf-8",
            )
            state = reading_sync.State(Path(tmp) / "state.sqlite3")
            client = FakeClient()

            first = reading_sync.ingest_helper_notes(client, state, root)
            second = reading_sync.ingest_helper_notes(client, state, root)

            self.assertEqual(first, (1, 1, 0, 0))
            self.assertEqual(second, (1, 0, 0, 0))
            self.assertEqual(client.created, 1)

    def test_helper_bookmark_is_upgraded_when_werss_gets_same_article(self):
        class FakeClient:
            def __init__(self):
                self.patches = []

            def list_bookmarks(self):
                return [
                    {
                        "id": "helper-bookmark",
                        "url": "https://example.com/redirected",
                        "labels": [
                            reading_sync.HELPER_LABEL,
                            reading_sync.HELPER_ORIGIN_LABEL,
                            reading_sync.HELPER_SOURCE_LABEL,
                        ],
                    }
                ]

            def create_bookmark(self, _article):
                raise AssertionError("同一文章不应重复创建")

            def patch_metadata(self, bookmark_id, article, existing_labels=()):
                self.patches.append((bookmark_id, article, list(existing_labels)))

        article = {
            "id": "article-1",
            "url": "https://example.com/original",
            "title": "正式公众号文章",
            "feed_name": "测试公众号",
            "publish_time": 1784029237,
            "has_content": 1,
            "content_html": "<p>" + "完整正文" * 30 + "</p>",
        }
        with tempfile.TemporaryDirectory() as tmp:
            state = reading_sync.State(Path(tmp) / "state.sqlite3")
            state.upsert_helper(
                article["url"],
                "helper-bookmark",
                Path(tmp) / "source.md",
                article["title"],
            )
            client = FakeClient()

            result = reading_sync.ingest(client, state, [article])

            self.assertEqual(result, (1, 0, 0))
            self.assertEqual(client.patches[0][0], "helper-bookmark")
            self.assertIn(reading_sync.HELPER_LABEL, client.patches[0][2])
            self.assertEqual(state.by_bookmark("helper-bookmark")["article_id"], "article-1")

    def test_helper_message_without_url_becomes_safe_reader_item(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "helper"
            message_dir = root / "微信消息"
            message_dir.mkdir(parents=True)
            note = message_dir / "同步助手_2026-07-17.md"
            note.write_text(
                "---\nsyncedIds: stable-source-id\n---\n\n---\n"
                "#### 一条无链接消息\n## 2026-07-17 13:40:00\n"
                "内容 <script>alert('x')</script>\n",
                encoding="utf-8",
            )

            messages = reading_sync.helper_messages(note, root)

            self.assertEqual(len(messages), 1)
            self.assertEqual(messages[0]["title"], "一条无链接消息")
            self.assertTrue(messages[0]["url"].startswith(reading_sync.WECHAT_MESSAGE_URL_PREFIX))
            rendered = reading_sync.render_helper_message_html(messages[0])
            self.assertIn("内容 &lt;script&gt;", rendered)
            self.assertNotIn("<script>alert", rendered)

    def test_helper_messages_are_incremental_and_idempotent(self):
        class FakeClient:
            def __init__(self):
                self.items = []
                self.created = 0

            def list_bookmarks(self):
                return list(self.items)

            def add_helper_message_labels(self, bookmark):
                return False

            def create_helper_message(self, message):
                self.created += 1
                bookmark_id = f"message-{self.created}"
                self.items.append(
                    {
                        "id": bookmark_id,
                        "url": message["url"],
                        "title": message["title"],
                        "labels": [reading_sync.WECHAT_MESSAGE_LABEL],
                    }
                )
                return bookmark_id

            def wait_loaded(self, bookmark_id):
                return next(item for item in self.items if item["id"] == bookmark_id)

            def patch_helper_message(self, bookmark_id, message):
                return None

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "helper"
            message_dir = root / "微信消息"
            message_dir.mkdir(parents=True)
            note = message_dir / "同步助手_2026-07-17.md"
            note.write_text(
                "---\nsyncedIds: source-id\n---\n\n---\n"
                "#### 第一条\n## 2026-07-17 13:40:00\n正文一\n",
                encoding="utf-8",
            )
            state = reading_sync.State(Path(tmp) / "state.sqlite3")
            client = FakeClient()

            first = reading_sync.ingest_helper_messages(client, state, root)
            second = reading_sync.ingest_helper_messages(client, state, root)
            note.write_text(
                note.read_text(encoding="utf-8")
                + "\n---\n#### 第二条\n## 2026-07-17 13:45:00\n正文二\n",
                encoding="utf-8",
            )
            third = reading_sync.ingest_helper_messages(client, state, root)

            self.assertEqual(first, (1, 1, 0, 0))
            self.assertEqual(second, (1, 0, 0, 0))
            self.assertEqual(third, (2, 1, 0, 0))
            self.assertEqual(client.created, 2)


if __name__ == "__main__":
    unittest.main()
