# 服务目录

Context Doc Type: service-catalog
Owner: coordinator
Source Evidence: `compose.yaml`; local app inspection; official service docs
Last Verified: 2026-07-14
Confidence: high

| Service / Component | Responsibility | Interfaces | Source Evidence | Last Verified | Confidence |
| --- | --- | --- | --- | --- | --- |
| WeRSS | 公众号抓取、存储、Atom 与管理 UI | `127.0.0.1:8001`; `/feed/*.atom`; `data/` | pinned image manifest; `compose.yaml` | 2026-07-14 | high |
| Caddy | 随机前缀 Atom 白名单与前缀剥离 | `127.0.0.1:8080` -> `we-mp-rss:8001` | `Caddyfile`; Caddy validate | 2026-07-14 | high |
| Tailscale Funnel | 把本机 8080 发布为 HTTPS | Tailscale CLI; `*.ts.net` | local 1.98.5 status/help | 2026-07-14 | high |
| Folo | 云端抓取、浏览、筛选、保存到 Obsidian | public Atom; desktop/mobile UI | Folo release/source review | 2026-07-14 | medium |
| Obsidian/SummerOS | Archive 收件箱、Base、批注与知识提升 | local Vault files | SummerOS AGENTS; Obsidian 1.12.7 | 2026-07-14 | high |
