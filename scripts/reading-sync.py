#!/usr/bin/env python3
"""WeRSS -> Readeck -> Obsidian 自动同步。

默认行为：
- 把 WeRSS 中已经抓到正文的文章全部送入 Readeck。
- 只把 Readeck 中已收藏或含高亮/批注的公众号文章写入 Obsidian。
- 自动更新区会刷新，人工 frontmatter 字段和“我的笔记”区永不覆盖。
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import ipaddress
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterable


DEFAULT_BASE_URL = "http://127.0.0.1:8002"
DEFAULT_CONTAINER = "wechat-rss-we-mp-rss-1"
DEFAULT_RUNTIME = Path.home() / ".local/share/wechat-rss"
DEFAULT_TOKEN_FILE = DEFAULT_RUNTIME / "readeck_api_token"
DEFAULT_STATE_DB = DEFAULT_RUNTIME / "reading-sync.sqlite3"
DEFAULT_STATUS_FILE = DEFAULT_RUNTIME / "public-status/reader-status.json"
DEFAULT_VAULT = Path(
    os.environ.get(
        "OBSIDIAN_INBOX_DIR",
        str(Path.home() / "Documents/Obsidian/reading/readeck_inbox"),
    )
).expanduser()
DEFAULT_HELPER_VAULT = (
    Path(os.environ["OBSIDIAN_HELPER_VAULT"]).expanduser()
    if os.environ.get("OBSIDIAN_HELPER_VAULT")
    else None
)

HELPER_LABEL = "Obsidian同步助手"
HELPER_SOURCE_LABEL = f"公众号/{HELPER_LABEL}"
HELPER_ORIGIN_LABEL = "来源/微信收藏"
HELPER_ASSET_HOSTS = {"media30d.clipfx.app", "wework.qpic.cn", "wx.qlogo.cn"}
WECHAT_MESSAGE_LABEL = "微信消息"
WECHAT_MESSAGE_SOURCE_LABEL = f"公众号/{WECHAT_MESSAGE_LABEL}"
WECHAT_MESSAGE_URL_PREFIX = "https://wechat-message.invalid/"

MANUAL_START = "<!-- readeck-sync:manual:start -->"
MANUAL_END = "<!-- readeck-sync:manual:end -->"
MANAGED_START = "<!-- readeck-sync:managed:start -->"
MANAGED_END = "<!-- readeck-sync:managed:end -->"
MANUAL_FIELDS = ("reading_status", "rating", "topics", "promote_to", "reviewed_at")

CONTAINER_EXPORT_CODE = r"""
import json, sqlite3
db = sqlite3.connect('file:/app/data/we_mp_rss.db?mode=ro', uri=True)
db.row_factory = sqlite3.Row
sql = '''
select a.id, a.title, a.url, a.description, a.publish_time, a.created_at,
       a.has_content, a.content, a.content_html, f.mp_name as feed_name
from articles a
left join feeds f on f.id = a.mp_id
where a.url is not null and a.url != ''
order by a.publish_time asc, a.id asc
'''
for row in db.execute(sql):
    print(json.dumps(dict(row), ensure_ascii=False, separators=(',', ':')))
""".strip()

CONTAINER_STATUS_CODE = r"""
import json, sqlite3
db = sqlite3.connect('file:/app/data/we_mp_rss.db?mode=ro', uri=True)
db.row_factory = sqlite3.Row
cron = db.execute(
    'select cron_exp, status from message_tasks order by id desc limit 1'
).fetchone() or ('missing', 0)
rows = db.execute('''
select f.id, f.mp_name, f.sync_time, f.update_time, f.updated_at,
       count(a.id) as articles,
       sum(case when a.has_content=1 and length(trim(coalesce(a.content_html,a.content,'')))>=80 then 1 else 0 end) as complete_articles,
       max(a.publish_time) as latest_published_at,
       max(a.created_at) as latest_article_created_at
from feeds f
left join articles a on a.mp_id=f.id
where f.status=1
group by f.id, f.mp_name, f.sync_time, f.update_time, f.updated_at
order by f.mp_name
''').fetchall()
print(json.dumps({
    'cron': cron[0],
    'cron_status': cron[1],
    'feeds': [dict(row) for row in rows],
}, ensure_ascii=False, separators=(',', ':')))
""".strip()


def log(message: str) -> None:
    stamp = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{stamp}] {message}", flush=True)


def iso_time(timestamp: Any, fallback: str | None = None) -> str:
    try:
        value = int(timestamp)
        if value > 10_000_000_000:
            value //= 1000
        return dt.datetime.fromtimestamp(value, dt.timezone.utc).isoformat().replace("+00:00", "Z")
    except (TypeError, ValueError, OverflowError, OSError):
        if fallback:
            try:
                value = dt.datetime.fromisoformat(fallback.replace("Z", "+00:00"))
                if value.tzinfo is None:
                    value = value.replace(tzinfo=dt.timezone.utc)
                return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")
            except ValueError:
                pass
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def date_part(value: str | None) -> str:
    if value:
        match = re.search(r"\d{4}-\d{2}-\d{2}", value)
        if match:
            return match.group(0)
    return dt.date.today().isoformat()


def safe_filename(title: str, bookmark_id: str) -> str:
    cleaned = re.sub(r"[\\/:*?\"<>|\r\n\t]+", "-", title).strip(" .-")
    cleaned = re.sub(r"\s+", " ", cleaned)
    if not cleaned:
        cleaned = "未命名文章"
    if len(cleaned) > 96:
        cleaned = cleaned[:96].rstrip()
    return f"{cleaned}--{bookmark_id[-8:]}.md"


def clean_title(value: Any) -> str:
    text = str(value or "").strip()
    first_line = next((line.strip() for line in text.splitlines() if line.strip()), "")
    first_line = re.sub(r"\s+", " ", first_line)
    if not first_line:
        return "未命名文章"
    if len(first_line) > 240:
        return first_line[:237].rstrip() + "…"
    return first_line


def canonical_external_url(value: Any) -> str | None:
    text = html.unescape(str(value or "")).strip().strip("<>\"'")
    text = text.rstrip(".,;，。；")
    try:
        parsed = urllib.parse.urlsplit(text)
    except ValueError:
        return None
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return None
    hostname = parsed.hostname.lower().rstrip(".")
    if hostname == "localhost" or hostname.endswith(".local"):
        return None
    if hostname in HELPER_ASSET_HOSTS:
        return None
    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        address = None
    if address and not address.is_global:
        return None
    if re.search(r"\.(?:png|jpe?g|gif|webp|svg|ico)(?:$|\?)", parsed.path, re.IGNORECASE):
        return None
    path = urllib.parse.quote(
        urllib.parse.unquote(parsed.path),
        safe="/%:@!$&'()*+,;=-._~",
    )
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path, parsed.query, ""))


def helper_note_urls(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    frontmatter, body = split_frontmatter(text)
    candidates: list[str] = []
    for key in ("url", "original_url", "originalUrl", "omnivore_url"):
        match = re.search(rf"(?mi)^{re.escape(key)}\s*:\s*[\"']?(https?://[^\s\"']+)", frontmatter)
        if match:
            candidates.append(match.group(1))
    if not candidates:
        # 图片 URL 不属于阅读条目；先移除 Markdown 图片，再提取链接和裸 URL。
        link_body = re.sub(r"!\[[^\]]*\]\(\s*https?://[^)]*\)", "", body)
        candidates.extend(re.findall(r"(?<!!)\[[^\]]*\]\((https?://[^)\s]+)\)", link_body))
        candidates.extend(re.findall(r"(?<![\"'=])https?://[^\s<>\])\"']+", link_body))
    result: list[str] = []
    for candidate in candidates:
        url = canonical_external_url(candidate)
        if url and url not in result:
            result.append(url)
        if len(result) >= 50:
            break
    return result


def helper_note_title(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        text = ""
    match = re.search(r"(?m)^#\s+(.+?)\s*$", text)
    if match:
        return clean_title(match.group(1))
    stem = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", path.stem)
    return clean_title(stem)


def helper_message_created(value: str, path: Path) -> str:
    match = re.search(r"\d{4}-\d{2}-\d{2}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?", value)
    if match:
        try:
            parsed = dt.datetime.fromisoformat(match.group(0))
            if parsed.tzinfo is None:
                parsed = parsed.astimezone()
            return parsed.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")
        except ValueError:
            pass
    fallback = date_part(path.stem)
    parsed = dt.datetime.fromisoformat(f"{fallback}T12:00:00").astimezone()
    return parsed.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def helper_messages(path: Path, root: Path) -> list[dict[str, str]]:
    """把同步助手的每日 Markdown 拆成不可变消息块。"""
    try:
        relative = path.relative_to(root)
    except ValueError:
        return []
    if not relative.parts or relative.parts[0] != WECHAT_MESSAGE_LABEL:
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    _, body = split_frontmatter(text)
    starts = list(re.finditer(r"(?m)^####\s+(.+?)\s*$", body))
    result: list[dict[str, str]] = []
    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(body)
        block = body[start.start() : end].strip()
        block = re.sub(r"(?:\n\s*---\s*)+$", "", block).strip()
        if not block:
            continue
        title = clean_title(start.group(1))
        time_heading = re.search(r"(?m)^##\s+(.+?)\s*$", block)
        created = helper_message_created(time_heading.group(1) if time_heading else "", path)
        content = block[len(start.group(0)) :].lstrip("\n")
        if time_heading:
            content = re.sub(r"(?m)^##\s+.+?\s*$", "", content, count=1).strip()
        normalized = "\n".join(line.rstrip() for line in block.splitlines()).strip()
        source_key = hashlib.sha256(
            (relative.as_posix() + "\0" + normalized).encode("utf-8")
        ).hexdigest()
        result.append(
            {
                "source_key": source_key,
                "url": WECHAT_MESSAGE_URL_PREFIX + source_key,
                "title": title,
                "created": created,
                "content": content,
                "signature": hashlib.sha256(normalized.encode("utf-8")).hexdigest(),
            }
        )
    return result


def render_helper_message_html(message: dict[str, str]) -> str:
    title = html.escape(clean_title(message.get("title")))
    created = html.escape(message.get("created") or "")
    paragraphs: list[str] = []
    for chunk in re.split(r"\n\s*\n", message.get("content") or ""):
        chunk = chunk.strip()
        if not chunk or chunk == "---":
            continue
        lines = chunk.splitlines()
        if all(re.match(r"^\s*[-*+]\s+", line) for line in lines):
            items = ""
            for line in lines:
                item = re.sub(r"^\s*[-*+]\s+", "", line)
                items += f"<li>{html.escape(item)}</li>"
            paragraphs.append(f"<ul>{items}</ul>")
        elif all(line.lstrip().startswith(">") for line in lines):
            quote = "<br>".join(html.escape(line.lstrip()[1:].lstrip()) for line in lines)
            paragraphs.append(f"<blockquote>{quote}</blockquote>")
        else:
            paragraphs.append("<p>" + "<br>".join(html.escape(line) for line in lines) + "</p>")
    content = "\n".join(paragraphs) or "<p>（空消息）</p>"
    return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>{title}</title>
<meta name="author" content="微信消息"><meta property="article:published_time" content="{created}">
</head><body><article><h1>{title}</h1><p><time datetime="{created}">{created}</time></p>{content}</article></body></html>"""


def yaml_string(value: Any) -> str:
    return json.dumps("" if value is None else str(value), ensure_ascii=False)


def reader_metadata(labels: Iterable[str]) -> tuple[int | None, list[str]]:
    value: int | None = None
    topics: list[str] = []
    for label in labels:
        match = re.fullmatch(r"价值/([1-5])", str(label))
        if match:
            value = int(match.group(1))
        elif str(label).startswith("主题/"):
            topic = str(label)[3:].strip()
            if topic and topic not in topics:
                topics.append(topic)
    return value, topics


def split_frontmatter(text: str) -> tuple[str, str]:
    if not text.startswith("---\n"):
        return "", text
    end = text.find("\n---\n", 4)
    if end == -1:
        return "", text
    return text[4:end], text[end + 5 :]


def extract_field_block(frontmatter: str, key: str) -> str | None:
    lines = frontmatter.splitlines()
    start = None
    for index, line in enumerate(lines):
        if re.match(rf"^{re.escape(key)}\s*:", line):
            start = index
            break
    if start is None:
        return None
    end = start + 1
    while end < len(lines):
        line = lines[end]
        if line and not line[0].isspace() and re.match(r"^[A-Za-z0-9_-]+\s*:", line):
            break
        end += 1
    return "\n".join(lines[start:end])


def manual_block(existing_text: str, saved_at: str) -> str:
    if MANUAL_START in existing_text and MANUAL_END in existing_text:
        start = existing_text.index(MANUAL_START)
        end = existing_text.index(MANUAL_END, start) + len(MANUAL_END)
        return existing_text[start:end]
    return f"""{MANUAL_START}
> [!note] 我的笔记
> - 收纳日期：{saved_at}
> - 为什么保存：
> - 核心判断：
> - 我是否同意：
> - 可执行动作：
> - 关联主题：
{MANUAL_END}"""


def strip_export_metadata(markdown: str) -> str:
    _, body = split_frontmatter(markdown)
    body = body.lstrip()
    body = re.sub(r"^#\s+[^\n]+\n+", "", body, count=1)
    return body.rstrip()


def annotation_section(annotations: list[dict[str, Any]]) -> str:
    if not annotations:
        return "还没有划线。回到 Readeck 选中文字即可创建高亮和批注。"
    chunks: list[str] = []
    for index, item in enumerate(annotations, start=1):
        text = str(item.get("text") or "").strip()
        note = str(item.get("note") or "").strip()
        color = str(item.get("color") or "yellow")
        created = str(item.get("created") or "")
        chunk = [f"### 摘录 {index}", "", f"> =={text}==", ">"]
        if note:
            chunk.append(f"> 批注：{note}")
        else:
            chunk.append("> 批注：")
        chunk.extend(["", f"颜色：`{color}` · 创建时间：{created or '未知'}"])
        chunks.append("\n".join(chunk))
    return "\n\n".join(chunks)


def render_note(
    bookmark: dict[str, Any],
    feed_name: str,
    exported_markdown: str,
    annotations: list[dict[str, Any]],
    existing_text: str = "",
) -> str:
    existing_frontmatter, _ = split_frontmatter(existing_text)
    preserved = {key: extract_field_block(existing_frontmatter, key) for key in MANUAL_FIELDS}
    reader_value, reader_topics = reader_metadata(bookmark.get("labels") or [])

    published = str(bookmark.get("published") or bookmark.get("created") or "")
    saved_at = date_part(str(bookmark.get("created") or ""))
    fields = [
        f"title: {yaml_string(bookmark.get('title'))}",
        f"url: {yaml_string(bookmark.get('url'))}",
        f"author: {yaml_string(feed_name)}",
        f"feedTitle: {yaml_string(feed_name)}",
        f"publishedAt: {yaml_string(published)}",
        f"saved_at: {saved_at}",
        "source_system: readeck",
        f"readeck_id: {yaml_string(bookmark.get('id'))}",
        f"favorite: {'true' if bookmark.get('is_marked') else 'false'}",
        f"read_progress: {int(bookmark.get('read_progress') or 0)}",
        f"reader_value: {reader_value if reader_value is not None else ''}",
    ]
    if reader_topics:
        fields.append("reader_tags:")
        fields.extend(f"  - {yaml_string(topic)}" for topic in reader_topics)
    else:
        fields.append("reader_tags: []")
    defaults = {
        "reading_status": "reading_status: 待读",
        "rating": "rating:",
        "topics": "topics: []",
        "promote_to": "promote_to: 无",
        "reviewed_at": "reviewed_at:",
    }
    fields.extend(preserved[key] or defaults[key] for key in MANUAL_FIELDS)
    fields.extend(["tags:", "  - 微信公众号", "  - readeck"])

    article = strip_export_metadata(exported_markdown)
    manual = manual_block(existing_text, saved_at)
    managed = f"""{MANAGED_START}
## 划线与批注

> [!info] Readeck 同步状态
> - 收藏：{'是' if bookmark.get('is_marked') else '否'}
> - 阅读进度：{int(bookmark.get('read_progress') or 0)}%
> - Reader 价值：{reader_value if reader_value is not None else '未评分'}
> - Reader 主题：{', '.join(reader_topics) if reader_topics else '无'}
> - Readeck 更新：{bookmark.get('updated') or '未知'}

{annotation_section(annotations)}

---

## 原文

{article}
{MANAGED_END}"""
    return "---\n" + "\n".join(fields) + "\n---\n\n# " + str(bookmark.get("title") or "未命名文章") + "\n\n" + manual + "\n\n" + managed + "\n"


class State:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path)
        path.chmod(0o600)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(
            """
            create table if not exists article_map (
                article_id text primary key,
                url text not null unique,
                bookmark_id text not null unique,
                feed_name text not null,
                published_at text not null,
                title text not null,
                note_path text,
                last_signature text,
                updated_at text not null
            );
            create table if not exists helper_map (
                source_url text primary key,
                bookmark_id text not null,
                note_path text not null,
                title text not null,
                updated_at text not null
            );
            create table if not exists helper_message_map (
                source_key text primary key,
                source_url text not null unique,
                bookmark_id text not null unique,
                note_path text not null,
                title text not null,
                signature text not null,
                updated_at text not null
            );
            """
        )

    def upsert_article(self, article: dict[str, Any], bookmark_id: str) -> None:
        self.db.execute(
            """
            insert into article_map(article_id,url,bookmark_id,feed_name,published_at,title,updated_at)
            values(?,?,?,?,?,?,?)
            on conflict(article_id) do update set
              url=excluded.url, bookmark_id=excluded.bookmark_id,
              feed_name=excluded.feed_name, published_at=excluded.published_at,
              title=excluded.title, updated_at=excluded.updated_at
            """,
            (
                article["id"],
                article["url"],
                bookmark_id,
                article.get("feed_name") or "未知公众号",
                iso_time(article.get("publish_time"), article.get("created_at")),
                clean_title(article.get("title")),
                dt.datetime.now(dt.timezone.utc).isoformat(),
            ),
        )
        self.db.commit()

    def by_bookmark(self, bookmark_id: str) -> sqlite3.Row | None:
        return self.db.execute("select * from article_map where bookmark_id=?", (bookmark_id,)).fetchone()

    def set_note(self, bookmark_id: str, path: Path, signature: str) -> None:
        self.db.execute(
            "update article_map set note_path=?, last_signature=?, updated_at=? where bookmark_id=?",
            (str(path), signature, dt.datetime.now(dt.timezone.utc).isoformat(), bookmark_id),
        )
        self.db.commit()

    def helper_bookmark(self, source_url: str) -> str | None:
        row = self.db.execute(
            "select bookmark_id from helper_map where source_url=?",
            (source_url,),
        ).fetchone()
        return str(row["bookmark_id"]) if row else None

    def upsert_helper(self, source_url: str, bookmark_id: str, path: Path, title: str) -> None:
        self.db.execute(
            """
            insert into helper_map(source_url,bookmark_id,note_path,title,updated_at)
            values(?,?,?,?,?)
            on conflict(source_url) do update set
              bookmark_id=excluded.bookmark_id, note_path=excluded.note_path,
              title=excluded.title, updated_at=excluded.updated_at
            """,
            (
                source_url,
                bookmark_id,
                str(path),
                clean_title(title),
                dt.datetime.now(dt.timezone.utc).isoformat(),
            ),
        )
        self.db.commit()

    def forget_helper(self, source_url: str) -> None:
        self.db.execute("delete from helper_map where source_url=?", (source_url,))
        self.db.commit()

    def helper_message_bookmark(self, source_key: str) -> str | None:
        row = self.db.execute(
            "select bookmark_id from helper_message_map where source_key=?",
            (source_key,),
        ).fetchone()
        return str(row["bookmark_id"]) if row else None

    def upsert_helper_message(
        self,
        message: dict[str, str],
        bookmark_id: str,
        path: Path,
    ) -> None:
        self.db.execute(
            """
            insert into helper_message_map(
                source_key,source_url,bookmark_id,note_path,title,signature,updated_at
            ) values(?,?,?,?,?,?,?)
            on conflict(source_key) do update set
              source_url=excluded.source_url, bookmark_id=excluded.bookmark_id,
              note_path=excluded.note_path, title=excluded.title,
              signature=excluded.signature, updated_at=excluded.updated_at
            """,
            (
                message["source_key"],
                message["url"],
                bookmark_id,
                str(path),
                clean_title(message.get("title")),
                message["signature"],
                dt.datetime.now(dt.timezone.utc).isoformat(),
            ),
        )
        self.db.commit()

    def forget_helper_message(self, source_key: str) -> None:
        self.db.execute("delete from helper_message_map where source_key=?", (source_key,))
        self.db.commit()


class ReadeckClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip("/")
        self.api_url = self.base_url + "/api"
        self.token = token

    def request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        accept: str = "application/json",
    ) -> tuple[int, dict[str, str], bytes]:
        body = None
        headers = {"Authorization": f"Bearer {self.token}", "Accept": accept}
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.api_url + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.status, dict(response.headers.items()), response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:1000]
            raise RuntimeError(f"Readeck API {method} {path} 返回 {exc.code}: {detail}") from exc

    def json(self, method: str, path: str, payload: dict[str, Any] | None = None) -> tuple[dict[str, str], Any]:
        _, headers, body = self.request(method, path, payload)
        return headers, json.loads(body.decode("utf-8")) if body else None

    def list_bookmarks(self) -> list[dict[str, Any]]:
        result: list[dict[str, Any]] = []
        offset = 0
        while True:
            _, items = self.json("GET", f"/bookmarks?limit=100&offset={offset}&sort=-created")
            items = items or []
            result.extend(items)
            if len(items) < 100:
                return result
            offset += len(items)

    def create_bookmark(self, article: dict[str, Any]) -> str:
        published = iso_time(article.get("publish_time"), article.get("created_at"))
        title = clean_title(article.get("title"))
        feed = str(article.get("feed_name") or "未知公众号")
        content = str(article.get("content_html") or article.get("content") or "").strip()
        document = f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>{html.escape(title)}</title>
<meta name="author" content="{html.escape(feed)}"><meta property="article:published_time" content="{published}">
</head><body><article>{content}</article></body></html>"""
        headers, _ = self.json(
            "POST",
            "/bookmarks",
            {
                "url": article["url"],
                "title": title,
                "labels": ["微信公众号", "WeRSS", f"公众号/{feed}"],
                "created": published,
                "html": document,
            },
        )
        bookmark_id = headers.get("Bookmark-Id") or headers.get("bookmark-id")
        if not bookmark_id and headers.get("Location"):
            bookmark_id = headers["Location"].rstrip("/").rsplit("/", 1)[-1]
        if not bookmark_id:
            raise RuntimeError("Readeck 创建文章后没有返回 Bookmark-Id")
        return bookmark_id

    def create_external_bookmark(self, url: str, title: str) -> str:
        headers, _ = self.json(
            "POST",
            "/bookmarks",
            {
                "url": url,
                "title": clean_title(title),
                "labels": [HELPER_LABEL, HELPER_ORIGIN_LABEL, HELPER_SOURCE_LABEL],
            },
        )
        bookmark_id = headers.get("Bookmark-Id") or headers.get("bookmark-id")
        if not bookmark_id and headers.get("Location"):
            bookmark_id = headers["Location"].rstrip("/").rsplit("/", 1)[-1]
        if not bookmark_id:
            raise RuntimeError("Readeck 创建外部文章后没有返回 Bookmark-Id")
        return bookmark_id

    def create_helper_message(self, message: dict[str, str]) -> str:
        headers, _ = self.json(
            "POST",
            "/bookmarks",
            {
                "url": message["url"],
                "title": clean_title(message.get("title")),
                "labels": [
                    HELPER_LABEL,
                    HELPER_ORIGIN_LABEL,
                    WECHAT_MESSAGE_LABEL,
                    WECHAT_MESSAGE_SOURCE_LABEL,
                ],
                "created": message["created"],
                "html": render_helper_message_html(message),
            },
        )
        bookmark_id = headers.get("Bookmark-Id") or headers.get("bookmark-id")
        if not bookmark_id and headers.get("Location"):
            bookmark_id = headers["Location"].rstrip("/").rsplit("/", 1)[-1]
        if not bookmark_id:
            raise RuntimeError("Readeck 创建微信消息后没有返回 Bookmark-Id")
        return bookmark_id

    def add_helper_labels(self, bookmark: dict[str, Any]) -> bool:
        labels = [str(item) for item in bookmark.get("labels") or []]
        wanted = [HELPER_LABEL, HELPER_ORIGIN_LABEL]
        if not any(item.startswith("公众号/") for item in labels):
            wanted.append(HELPER_SOURCE_LABEL)
        updated = labels + [item for item in wanted if item not in labels]
        if updated == labels:
            return False
        self.json("PATCH", f"/bookmarks/{bookmark['id']}", {"labels": updated})
        return True

    def patch_helper_message(self, bookmark_id: str, message: dict[str, str]) -> None:
        self.json(
            "PATCH",
            f"/bookmarks/{bookmark_id}",
            {
                "title": clean_title(message.get("title")),
                "site_name": WECHAT_MESSAGE_LABEL,
                "authors": [WECHAT_MESSAGE_LABEL],
                "published": message["created"],
                "labels": [
                    HELPER_LABEL,
                    HELPER_ORIGIN_LABEL,
                    WECHAT_MESSAGE_LABEL,
                    WECHAT_MESSAGE_SOURCE_LABEL,
                ],
            },
        )

    def add_helper_message_labels(self, bookmark: dict[str, Any]) -> bool:
        labels = [str(item) for item in bookmark.get("labels") or []]
        wanted = [
            HELPER_LABEL,
            HELPER_ORIGIN_LABEL,
            WECHAT_MESSAGE_LABEL,
            WECHAT_MESSAGE_SOURCE_LABEL,
        ]
        updated = labels + [item for item in wanted if item not in labels]
        if updated == labels:
            return False
        self.json("PATCH", f"/bookmarks/{bookmark['id']}", {"labels": updated})
        return True

    def wait_loaded(self, bookmark_id: str, timeout: int = 90) -> dict[str, Any]:
        deadline = time.monotonic() + timeout
        last: dict[str, Any] = {}
        while time.monotonic() < deadline:
            _, last = self.json("GET", f"/bookmarks/{bookmark_id}")
            if last.get("loaded"):
                return last
            time.sleep(1)
        raise RuntimeError(f"Readeck 文章 {bookmark_id} 在 {timeout} 秒内未完成处理")

    def patch_metadata(
        self,
        bookmark_id: str,
        article: dict[str, Any],
        existing_labels: Iterable[str] = (),
    ) -> None:
        feed = str(article.get("feed_name") or "未知公众号")
        labels = [str(item) for item in existing_labels if str(item) != HELPER_SOURCE_LABEL]
        for label in ("微信公众号", "WeRSS", f"公众号/{feed}"):
            if label not in labels:
                labels.append(label)
        self.json(
            "PATCH",
            f"/bookmarks/{bookmark_id}",
            {
                "title": clean_title(article.get("title")),
                "site_name": feed,
                "authors": [feed],
                "published": iso_time(article.get("publish_time"), article.get("created_at")),
                "labels": labels,
            },
        )

    def annotations(self, bookmark_id: str) -> list[dict[str, Any]]:
        _, items = self.json("GET", f"/bookmarks/{bookmark_id}/annotations")
        return items or []

    def markdown(self, bookmark_id: str) -> str:
        _, _, body = self.request("GET", f"/bookmarks/{bookmark_id}/article.md", accept="text/markdown")
        return body.decode("utf-8")


def read_token(path: Path) -> str:
    token = path.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[A-Za-z0-9]{40,80}", token):
        raise RuntimeError(f"Readeck API 令牌格式错误：{path}")
    return token


def direct_articles(path: Path) -> Iterable[dict[str, Any]]:
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    sql = """
    select a.id, a.title, a.url, a.description, a.publish_time, a.created_at,
           a.has_content, a.content, a.content_html, f.mp_name as feed_name
    from articles a left join feeds f on f.id = a.mp_id
    where a.url is not null and a.url != ''
    order by a.publish_time asc, a.id asc
    """
    try:
        for row in db.execute(sql):
            yield dict(row)
    finally:
        db.close()


def docker_binary() -> str:
    candidates = [
        shutil.which("docker"),
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate
    raise RuntimeError("找不到 Docker CLI")


def container_articles(container: str) -> Iterable[dict[str, Any]]:
    process = subprocess.Popen(
        [docker_binary(), "exec", container, "python3", "-c", CONTAINER_EXPORT_CODE],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    assert process.stdout is not None
    for line in process.stdout:
        if line.strip():
            yield json.loads(line)
    stderr = process.stderr.read() if process.stderr else ""
    status = process.wait()
    if status != 0:
        raise RuntimeError(f"无法从 WeRSS 容器读取文章：{stderr.strip()[:1000]}")


def direct_feed_snapshot(path: Path) -> dict[str, Any]:
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    try:
        cron = db.execute(
            "select cron_exp, status from message_tasks order by id desc limit 1"
        ).fetchone() or ("missing", 0)
        rows = db.execute(
            """
            select f.id, f.mp_name, f.sync_time, f.update_time, f.updated_at,
                   count(a.id) as articles,
                   sum(case when a.has_content=1 and length(trim(coalesce(a.content_html,a.content,'')))>=80 then 1 else 0 end) as complete_articles,
                   max(a.publish_time) as latest_published_at,
                   max(a.created_at) as latest_article_created_at
            from feeds f
            left join articles a on a.mp_id=f.id
            where f.status=1
            group by f.id, f.mp_name, f.sync_time, f.update_time, f.updated_at
            order by f.mp_name
            """
        ).fetchall()
        return {"cron": cron[0], "cron_status": cron[1], "feeds": [dict(row) for row in rows]}
    finally:
        db.close()


def container_feed_snapshot(container: str) -> dict[str, Any]:
    process = subprocess.run(
        [docker_binary(), "exec", container, "python3", "-c", CONTAINER_STATUS_CODE],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=60,
        check=False,
    )
    if process.returncode != 0:
        raise RuntimeError(f"无法从 WeRSS 容器读取订阅状态：{process.stderr.strip()[:1000]}")
    try:
        return json.loads(process.stdout.strip())
    except json.JSONDecodeError as exc:
        raise RuntimeError("WeRSS 订阅状态不是合法 JSON") from exc


def optional_iso(*values: Any) -> str:
    for value in values:
        if value in (None, "", 0, "0"):
            continue
        if isinstance(value, (int, float)) or str(value).isdigit():
            return iso_time(value)
        try:
            parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return parsed.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")
        except ValueError:
            continue
    return ""


def bookmark_feed(bookmark: dict[str, Any]) -> str:
    for label in bookmark.get("labels") or []:
        if str(label).startswith("公众号/"):
            return str(label)[4:]
    return str(bookmark.get("site_name") or "未知公众号")


def build_reader_status(feed_snapshot: dict[str, Any], bookmarks: list[dict[str, Any]]) -> dict[str, Any]:
    bookmark_stats: dict[str, dict[str, int]] = {}
    for bookmark in bookmarks:
        feed = bookmark_feed(bookmark)
        stats = bookmark_stats.setdefault(feed, {"articles": 0, "unread": 0})
        stats["articles"] += 1
        if int(bookmark.get("read_progress") or 0) < 100:
            stats["unread"] += 1

    feeds: list[dict[str, Any]] = []
    latest = ""
    for row in feed_snapshot.get("feeds") or []:
        name = str(row.get("mp_name") or "未知公众号")
        latest_fetched = optional_iso(
            row.get("update_time"),
            row.get("sync_time"),
            row.get("updated_at"),
            row.get("latest_article_created_at"),
        )
        if latest_fetched > latest:
            latest = latest_fetched
        complete = int(row.get("complete_articles") or 0)
        stats = bookmark_stats.get(name, {"articles": 0, "unread": 0})
        feeds.append(
            {
                "name": name,
                "articles": int(row.get("articles") or 0),
                "complete_articles": complete,
                "readeck_articles": stats["articles"],
                "unread": stats["unread"],
                "latest_fetched_at": latest_fetched,
                "latest_published_at": optional_iso(row.get("latest_published_at")),
                "health": "正常" if complete > 0 else "等待正文",
            }
        )

    native_cron = str(feed_snapshot.get("cron") or "missing")
    cloudflare_driven = native_cron == "43 3 29 2 *"
    cron_ok = bool(int(feed_snapshot.get("cron_status") or 0))
    return {
        "version": 1,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "health": "ok" if cron_ok and feeds else "error",
        "scheduler": "cloudflare" if cloudflare_driven else "werss",
        "cron": "17 * * * *" if cloudflare_driven else native_cron,
        "werss_native_cron": native_cron,
        "sync_interval_seconds": 300,
        "total_reader_items": len(bookmarks),
        "latest_fetched_at": latest,
        "feeds": feeds,
    }


def write_reader_status(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.parent.chmod(0o700)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temp.chmod(0o644)
    temp.replace(path)
    path.chmod(0o644)


def is_complete(article: dict[str, Any]) -> bool:
    content = str(article.get("content_html") or article.get("content") or "").strip()
    return bool(article.get("has_content") and len(content) >= 80)


def ingest(client: ReadeckClient, state: State, articles: Iterable[dict[str, Any]]) -> tuple[int, int, int]:
    bookmarks = client.list_bookmarks()
    by_id = {str(item.get("id")): item for item in bookmarks if item.get("id")}
    by_url = {str(item.get("url")): item for item in bookmarks if item.get("url") and item.get("id")}
    total = created = skipped = 0
    for article in articles:
        total += 1
        if not is_complete(article):
            skipped += 1
            continue
        article_url = str(article["url"])
        existing = by_url.get(article_url)
        if not existing:
            helper_id = state.helper_bookmark(canonical_external_url(article_url) or article_url)
            existing = by_id.get(helper_id) if helper_id else None
        if not existing:
            bookmark_id = client.create_bookmark(article)
            loaded = client.wait_loaded(bookmark_id)
            client.patch_metadata(bookmark_id, article, loaded.get("labels") or [])
            loaded.update(
                {
                    "id": bookmark_id,
                    "url": article_url,
                    "labels": ["微信公众号", "WeRSS", f"公众号/{article.get('feed_name') or '未知公众号'}"],
                }
            )
            by_id[bookmark_id] = loaded
            by_url[article_url] = loaded
            created += 1
            if created % 10 == 0:
                log(f"已回填 {created} 篇文章到 Readeck")
            time.sleep(0.2)
        else:
            bookmark_id = str(existing["id"])
            feed_label = f"公众号/{article.get('feed_name') or '未知公众号'}"
            labels = [str(item) for item in existing.get("labels") or []]
            if "WeRSS" not in labels or feed_label not in labels or HELPER_SOURCE_LABEL in labels:
                client.patch_metadata(bookmark_id, article, labels)
                existing["labels"] = [
                    item for item in labels if item != HELPER_SOURCE_LABEL
                ] + [item for item in ("微信公众号", "WeRSS", feed_label) if item not in labels]
        state.upsert_article(article, bookmark_id)
    return total, created, skipped


def ingest_helper_notes(client: ReadeckClient, state: State, root: Path | None) -> tuple[int, int, int, int]:
    if root is None or not root.exists():
        return 0, 0, 0, 0
    bookmarks = client.list_bookmarks()
    by_id = {str(item.get("id")): item for item in bookmarks if item.get("id")}
    by_url = {
        canonical_external_url(item.get("url")): item
        for item in bookmarks
        if canonical_external_url(item.get("url")) and item.get("id")
    }
    scanned = created = labeled = failed = 0
    for path in sorted(root.rglob("*.md")):
        for url in helper_note_urls(path):
            scanned += 1
            title = helper_note_title(path)
            mapped_id = state.helper_bookmark(url)
            existing = by_id.get(mapped_id) if mapped_id else None
            if mapped_id and not existing:
                state.forget_helper(url)
            existing = existing or by_url.get(url)
            if existing:
                state.upsert_helper(url, str(existing["id"]), path, title)
                if client.add_helper_labels(existing):
                    labeled += 1
                    existing["labels"] = [
                        *(existing.get("labels") or []),
                        HELPER_LABEL,
                        HELPER_ORIGIN_LABEL,
                    ]
                continue
            try:
                bookmark_id = client.create_external_bookmark(url, title)
                # Readeck 加载后可能把 URL 改成重定向终点。先持久化原始链接，
                # 即使正文解析超时，下次运行也不会重复创建同一条目。
                state.upsert_helper(url, bookmark_id, path, title)
                loaded = client.wait_loaded(bookmark_id)
            except RuntimeError:
                failed += 1
                host = urllib.parse.urlsplit(url).hostname or "未知站点"
                log(f"同步助手链接导入失败（{host}），保留到下次重试")
                continue
            loaded["id"] = bookmark_id
            loaded["url"] = url
            loaded["labels"] = [HELPER_LABEL, HELPER_ORIGIN_LABEL, HELPER_SOURCE_LABEL]
            by_url[url] = loaded
            created += 1
            time.sleep(0.2)
    return scanned, created, labeled, failed


def ingest_helper_messages(client: ReadeckClient, state: State, root: Path | None) -> tuple[int, int, int, int]:
    if root is None or not root.exists():
        return 0, 0, 0, 0
    bookmarks = client.list_bookmarks()
    by_id = {str(item.get("id")): item for item in bookmarks if item.get("id")}
    by_url = {
        str(item.get("url")): item
        for item in bookmarks
        if str(item.get("url") or "").startswith(WECHAT_MESSAGE_URL_PREFIX) and item.get("id")
    }
    scanned = created = labeled = failed = 0
    message_dir = root / WECHAT_MESSAGE_LABEL
    if not message_dir.is_dir():
        return 0, 0, 0, 0
    for path in sorted(message_dir.rglob("*.md")):
        for message in helper_messages(path, root):
            scanned += 1
            mapped_id = state.helper_message_bookmark(message["source_key"])
            existing = by_id.get(mapped_id) if mapped_id else None
            if mapped_id and not existing:
                state.forget_helper_message(message["source_key"])
            existing = existing or by_url.get(message["url"])
            if existing:
                state.upsert_helper_message(message, str(existing["id"]), path)
                if client.add_helper_message_labels(existing):
                    labeled += 1
                    existing["labels"] = [
                        *(existing.get("labels") or []),
                        HELPER_LABEL,
                        HELPER_ORIGIN_LABEL,
                        WECHAT_MESSAGE_LABEL,
                        WECHAT_MESSAGE_SOURCE_LABEL,
                    ]
                continue
            try:
                bookmark_id = client.create_helper_message(message)
                state.upsert_helper_message(message, bookmark_id, path)
                loaded = client.wait_loaded(bookmark_id)
                client.patch_helper_message(bookmark_id, message)
            except RuntimeError:
                failed += 1
                log("微信消息导入失败，已保留到下次重试")
                continue
            loaded.update(
                {
                    "id": bookmark_id,
                    "url": message["url"],
                    "title": message["title"],
                    "labels": [
                        HELPER_LABEL,
                        HELPER_ORIGIN_LABEL,
                        WECHAT_MESSAGE_LABEL,
                        WECHAT_MESSAGE_SOURCE_LABEL,
                    ],
                }
            )
            by_id[bookmark_id] = loaded
            by_url[message["url"]] = loaded
            created += 1
            time.sleep(0.2)
    return scanned, created, labeled, failed


def sync_obsidian(client: ReadeckClient, state: State, vault: Path, sync_all: bool) -> tuple[int, int]:
    vault.mkdir(parents=True, exist_ok=True)
    selected = updated = 0
    for bookmark in client.list_bookmarks():
        labels = bookmark.get("labels") or []
        if "WeRSS" not in labels:
            continue
        mapping = state.by_bookmark(str(bookmark["id"]))
        if mapping is None:
            continue
        annotations = client.annotations(str(bookmark["id"]))
        existing_path = Path(mapping["note_path"]) if mapping["note_path"] else None
        should_sync = sync_all or bool(bookmark.get("is_marked")) or bool(annotations) or bool(existing_path)
        if not should_sync:
            continue
        selected += 1
        if existing_path:
            path = existing_path
        else:
            name = f"{date_part(mapping['published_at'])}-{safe_filename(str(bookmark.get('title') or mapping['title']), str(bookmark['id']))}"
            path = vault / name
        existing_text = path.read_text(encoding="utf-8") if path.exists() else ""
        exported = client.markdown(str(bookmark["id"]))
        rendered = render_note(bookmark, str(mapping["feed_name"]), exported, annotations, existing_text)
        signature = hashlib.sha256(rendered.encode("utf-8")).hexdigest()
        if not path.exists() or path.read_text(encoding="utf-8") != rendered:
            tmp = path.with_suffix(path.suffix + ".tmp")
            tmp.write_text(rendered, encoding="utf-8")
            tmp.replace(path)
            updated += 1
        state.set_note(str(bookmark["id"]), path, signature)
    return selected, updated


def run(args: argparse.Namespace) -> int:
    token = read_token(args.token_file)
    client = ReadeckClient(args.readeck_url, token)
    state = State(args.state_db)
    articles = list(direct_articles(args.source_db) if args.source_db else container_articles(args.container))
    feed_snapshot = direct_feed_snapshot(args.source_db) if args.source_db else container_feed_snapshot(args.container)
    total, created, skipped = ingest(client, state, articles)
    helper_scanned, helper_created, helper_labeled, helper_failed = ingest_helper_notes(
        client,
        state,
        args.helper_vault,
    )
    message_scanned, message_created, message_labeled, message_failed = ingest_helper_messages(
        client,
        state,
        args.helper_vault,
    )
    selected, updated = sync_obsidian(client, state, args.vault, args.sync_all)
    write_reader_status(args.status_file, build_reader_status(feed_snapshot, client.list_bookmarks()))
    log(
        f"同步完成：扫描 WeRSS {total} 篇，新入 Readeck {created} 篇，"
        f"正文未就绪 {skipped} 篇；同步助手链接 {helper_scanned} 条，"
        f"新入 Reader {helper_created} 条，补充分组 {helper_labeled} 条，失败 {helper_failed} 条；"
        f"微信消息 {message_scanned} 条，新入 {message_created} 条，"
        f"补充分组 {message_labeled} 条，失败 {message_failed} 条；"
        f"Obsidian 入选 {selected} 篇，更新 {updated} 篇"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="WeRSS、Readeck 与 Obsidian 自动同步")
    parser.add_argument("--readeck-url", default=os.environ.get("READECK_URL", DEFAULT_BASE_URL))
    parser.add_argument("--token-file", type=Path, default=DEFAULT_TOKEN_FILE)
    parser.add_argument("--state-db", type=Path, default=DEFAULT_STATE_DB)
    parser.add_argument("--status-file", type=Path, default=DEFAULT_STATUS_FILE)
    parser.add_argument("--vault", type=Path, default=DEFAULT_VAULT)
    parser.add_argument("--helper-vault", type=Path, default=DEFAULT_HELPER_VAULT)
    parser.add_argument("--container", default=os.environ.get("WERSS_CONTAINER", DEFAULT_CONTAINER))
    parser.add_argument("--source-db", type=Path, help="测试或手工运行时直接读取 WeRSS SQLite")
    parser.add_argument("--sync-all", action="store_true", help="把所有公众号文章写入 Obsidian；默认只写收藏或有划线的文章")
    args = parser.parse_args()
    try:
        return run(args)
    except Exception as exc:  # noqa: BLE001 - 命令行边界需要汇总错误
        log(f"同步失败：{exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
