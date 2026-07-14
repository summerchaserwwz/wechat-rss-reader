# 服务目录

Context Doc Type: service-catalog
Owner: coordinator
Source Evidence: `compose.yaml`; local runtime; scripts; SummerOS reading files
Last Verified: 2026-07-15
Confidence: high locally; Cloudflare pending live

| Service / Component | Responsibility | Interfaces | Source Evidence | Last Verified | Confidence |
| --- | --- | --- | --- | --- | --- |
| WeRSS | 公众号授权、抓取、正文与 Atom | `127.0.0.1:8001`; `data/` | Compose/runtime | 2026-07-15 | high |
| RSS Caddy | 随机前缀 Atom 白名单 | `127.0.0.1:8080` | Caddyfile/verify | 2026-07-15 | high |
| Readeck | 全文阅读、收藏、高亮、批注 | `127.0.0.1:8002`; `readeck-data/` | API/SQLite/UI | 2026-07-15 | high |
| reading-sync | WeRSS 全量入 Readeck；精选入 Obsidian | LaunchAgent；Readeck API；runtime SQLite | script/tests/log | 2026-07-15 | high |
| Reader Caddy | Cloudflare origin 与安全头 | `127.0.0.1:8082` -> `readeck:8000` | config/curl | 2026-07-15 | high |
| Cloudflare Tunnel | 手机/外网 HTTPS 阅读 | `reader.sumerchaser.top` | config script | 2026-07-15 | pending live |
| Obsidian/SummerOS | Archive、Base、人工笔记与知识提升 | local Vault | real note/SummerOS files | 2026-07-15 | high |
