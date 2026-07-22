#!/usr/bin/env python3
"""Patch the pinned WeRSS scheduler to honor REFRESH_MAX_PAGE."""

from __future__ import annotations

import argparse
import stat
import sys
from pathlib import Path


REPLACEMENTS = (
    (
        b"Mps_id=item.id,Mps_title=item.mp_name, MaxPage=1)",
        b'Mps_id=item.id,Mps_title=item.mp_name, MaxPage=int(cfg.get("refresh_max_page", "1")))',
    ),
    (
        b"Mps_id=mp.id,Mps_title=mp.mp_name, MaxPage=1,Over_CallBack=Update_Over,interval=interval)",
        b'Mps_id=mp.id,Mps_title=mp.mp_name, MaxPage=int(cfg.get("refresh_max_page", "1")),Over_CallBack=Update_Over,interval=interval)',
    ),
)


def patch_target(target: Path) -> str:
    try:
        original = target.read_bytes()
    except OSError as exc:
        raise RuntimeError(f"无法读取 WeRSS 运行时文件: {target}") from exc

    old_counts = [original.count(old) for old, _new in REPLACEMENTS]
    new_counts = [original.count(new) for _old, new in REPLACEMENTS]
    if old_counts == [0, 0] and new_counts == [1, 1]:
        return "WeRSS REFRESH_MAX_PAGE 运行时补丁已存在"
    if old_counts != [1, 1] or new_counts != [0, 0]:
        raise RuntimeError(
            "无法确认固定 WeRSS 代码形状，拒绝应用 REFRESH_MAX_PAGE 运行时补丁"
        )

    patched = original
    for old, new in REPLACEMENTS:
        patched = patched.replace(old, new, 1)
    if [patched.count(new) for _old, new in REPLACEMENTS] != [1, 1]:
        raise RuntimeError("WeRSS REFRESH_MAX_PAGE 运行时补丁校验失败")

    temporary = target.with_name(target.name + ".reader-patch")
    temporary.write_bytes(patched)
    temporary.chmod(stat.S_IMODE(target.stat().st_mode))
    temporary.replace(target)
    return "WeRSS 定时抓取已改为使用配置的 REFRESH_MAX_PAGE"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", type=Path, default=Path("/app/jobs/mps.py"))
    args = parser.parse_args()
    try:
        print(patch_target(args.target))
    except RuntimeError as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
