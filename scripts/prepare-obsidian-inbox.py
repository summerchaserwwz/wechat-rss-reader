#!/usr/bin/env python3
"""把 Folo/Web Clipper 导出的 Markdown 整理成可批注的公众号笔记。

安全约束：
- 只处理传入目录中的 Markdown 文件；默认跳过 README.md。
- 不覆盖同名目标文件。
- 通过固定 marker 保证重复运行不会重复插入批注区。
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path


DEFAULT_INBOX = Path(
    "/Users/summer/Obsidian/SummerOS/02_Archive/02_DailyProcessed/reading/folo_inbox"
)
MARKER = "<!-- wechat-rss-note-layout:v1 -->"
READECK_MARKER = "<!-- readeck-sync:managed:start -->"
DATE_PREFIX = re.compile(r"^\d{4}-\d{2}-\d{2}-")
PUBLISHED_KEYS = ("publishedAt", "published_at", "date", "created")


def split_frontmatter(text: str) -> tuple[str, str]:
    if not text.startswith("---\n"):
        return "", text
    end = text.find("\n---\n", 4)
    if end == -1:
        return "", text
    return text[: end + 5], text[end + 5 :]


def frontmatter_value(frontmatter: str, key: str) -> str | None:
    match = re.search(rf"(?m)^{re.escape(key)}:\s*[\"']?([^\n\"']+)", frontmatter)
    return match.group(1).strip() if match else None


def note_date(path: Path, frontmatter: str) -> str:
    for key in PUBLISHED_KEYS:
        value = frontmatter_value(frontmatter, key)
        if value:
            match = re.search(r"\d{4}-\d{2}-\d{2}", value)
            if match:
                return match.group(0)
            if value.isdigit():
                timestamp = int(value)
                if timestamp > 10_000_000_000:
                    timestamp //= 1000
                try:
                    return dt.datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d")
                except (OverflowError, OSError, ValueError):
                    pass
    return dt.datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d")


def add_manual_fields(frontmatter: str, saved_date: str) -> str:
    fields = {
        "reading_status": "待读",
        "rating": "",
        "topics": "[]",
        "promote_to": "无",
        "reviewed_at": "",
        "saved_at": saved_date,
    }
    additions = [f"{key}: {value}" for key, value in fields.items() if not re.search(rf"(?m)^{re.escape(key)}:", frontmatter)]
    if not frontmatter:
        return "---\n" + "\n".join(additions) + "\n---\n"
    if not additions:
        return frontmatter
    return frontmatter[:-4] + "\n".join(additions) + "\n---\n"


def annotation_block(saved_date: str) -> str:
    return f"""{MARKER}
> [!note] 我的笔记
> - 保存日期：{saved_date}
> - 为什么保存：
> - 核心判断：
> - 我是否同意：
> - 可执行动作：
> - 关联主题：

## 划线与摘录

- 在下方原文中用 `==关键句==` 直接高亮。
- 需要保留上下文时，把摘录放在这里，并补一句自己的判断。

---

## 原文

"""


def target_path(path: Path, saved_date: str) -> Path:
    if DATE_PREFIX.match(path.name):
        return path
    return path.with_name(f"{saved_date}-{path.name}")


def process(path: Path, dry_run: bool = False, min_age: int = 0) -> str:
    if not path.is_file() or path.suffix.lower() != ".md" or path.name.lower() == "readme.md":
        return "skip"
    age = dt.datetime.now().timestamp() - path.stat().st_mtime
    if age < min_age:
        return "too-new"

    text = path.read_text(encoding="utf-8")
    if READECK_MARKER in text:
        return "skip-readeck-managed"
    frontmatter, body = split_frontmatter(text)
    saved_date = note_date(path, frontmatter)
    destination = target_path(path, saved_date)

    if destination != path and destination.exists():
        raise FileExistsError(f"目标文件已存在，未覆盖：{destination}")

    changed = False
    new_frontmatter = add_manual_fields(frontmatter, saved_date)
    if new_frontmatter != frontmatter:
        changed = True

    if MARKER not in body:
        body = annotation_block(saved_date) + body.lstrip("\n")
        changed = True

    if destination != path:
        changed = True

    if not changed:
        return "unchanged"
    if dry_run:
        return f"would-update:{destination.name}"

    destination.write_text(new_frontmatter + body, encoding="utf-8")
    if destination != path:
        path.unlink()
    return f"updated:{destination.name}"


def main() -> int:
    parser = argparse.ArgumentParser(description="整理 Obsidian 公众号精选收件箱")
    parser.add_argument("paths", nargs="*", type=Path, help="单个 Markdown 文件或目录")
    parser.add_argument("--dry-run", action="store_true", help="只显示将进行的操作")
    parser.add_argument("--min-age", type=int, default=0, help="跳过最近 N 秒内仍可能在写入的文件")
    args = parser.parse_args()

    roots = args.paths or [DEFAULT_INBOX]
    files: list[Path] = []
    for root in roots:
        files.extend(sorted(root.glob("*.md")) if root.is_dir() else [root])

    failures = 0
    for path in files:
        try:
            result = process(path, dry_run=args.dry_run, min_age=args.min_age)
            if result not in {"skip", "too-new"}:
                print(f"{path.name}: {result}")
        except (OSError, UnicodeError) as exc:
            failures += 1
            print(f"{path}: ERROR: {exc}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
