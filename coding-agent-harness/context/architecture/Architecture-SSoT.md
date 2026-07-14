# 架构事实源

Context Doc Type: architecture-ssot
Owner: coordinator
Last Verified: 2026-07-15
Confidence: high for local design; Cloudflare live gate pending

## System Summary

本仓库不是 WeRSS 或 Readeck 源码 fork，而是本机部署与运维包。WeRSS 每小时抓取公众号；同步器把完整正文全量写入自托管 Readeck；用户在 Readeck 收藏、划线和批注；精选文章自动进入 SummerOS Archive，人工笔记和元数据永不覆盖。Cloudflare Tunnel 只公开 Readeck 登录入口，Folo/Tailscale 退出主链路。

## Current Architecture Facts

| ID | Fact | Source Evidence | Last Verified | Confidence | Read Before |
| --- | --- | --- | --- | --- | --- |
| ARCH-001 | WeRSS 管理端只绑定 `127.0.0.1:8001` | `compose.yaml` | 2026-07-15 | high | 网络/端口修改 |
| ARCH-002 | 兼容 RSS Caddy 只绑定 `127.0.0.1:8080`，只放行随机前缀 `feed/*.atom` | `compose.yaml`; `Caddyfile` | 2026-07-15 | high | RSS 公网修改 |
| ARCH-003 | Readeck 0.22.3 固定摘要、原生 aarch64，只绑定 `127.0.0.1:8002` | `compose.yaml`; runtime | 2026-07-15 | high | 阅读器修改 |
| ARCH-004 | Readeck 专用 Caddy 只绑定 `127.0.0.1:8082`，通过 internal reading 网络访问 Readeck | `compose.yaml`; `Caddyfile.reader` | 2026-07-15 | high | Cloudflare 修改 |
| ARCH-005 | 完整正文全量进入 Readeck；只有收藏或含高亮/批注的文章默认进入 Obsidian | `scripts/reading-sync.py`; tests | 2026-07-15 | high | 同步器修改 |
| ARCH-006 | SummerOS 目标是 Archive processed source inbox；原文不直接晋升 Knowledge/Output | SummerOS reading README | 2026-07-15 | high | Vault 写入 |
| ARCH-007 | 人工 frontmatter 与“我的笔记”受保护；机器区刷新，高亮为 `==...==`、批注为摘录和脚注 | 实际样本；hash/mtime；tests | 2026-07-15 | high | Markdown 渲染修改 |
| ARCH-008 | WeRSS 定时任务为 `17 * * * *`；微信无 webhook，只能近实时 | live SQLite | 2026-07-15 | high | 调度修改 |
| ARCH-009 | Cloudflare 使用独立 `wechat-rss` Tunnel，目标 `reader.sumerchaser.top -> 127.0.0.1:8082` | scripts/config pending live auth | 2026-07-15 | medium | 公网部署 |
| ARCH-010 | 备份必须同时停止 WeRSS/Readeck，覆盖三个 SQLite、API Token、资源和可选 Tunnel 作用域凭据 | `scripts/backup.sh`; `restore-test.sh` | 2026-07-15 | high | 备份/恢复 |
| ARCH-011 | 固定 WeRSS manifest 实际仍是 AMD64 filesystem，通过 Rosetta 运行；不得伪装原生通过 | runtime root-cause evidence | 2026-07-14 | high | 镜像修改 |
| ARCH-012 | WeRSS 与 Readeck 使用独立出网网络，彼此不能通过共享 bridge 直连 | `compose.yaml`; network inspect | 2026-07-15 | high | 网络修改 |

## Promotion Log

| Source Task | Promoted Fact | Destination | Decision | Date |
| --- | --- | --- | --- | --- |
| `2026-07-14-werss-folo-obsidian-7118a818` | ARCH-001..012 | architecture SSoT | accepted; Folo 架构被 Readeck 架构取代 | 2026-07-15 |
