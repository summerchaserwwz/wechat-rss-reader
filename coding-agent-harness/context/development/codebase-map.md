# 代码库地图

Context Doc Type: codebase-map
Owner: coordinator
Source Evidence: repository file tree and current task diff
Last Verified: 2026-07-15
Confidence: high

| Path | Responsibility |
| --- | --- |
| `compose.yaml` | WeRSS、Readeck、两个 Caddy、端口、持久化与日志 |
| `Caddyfile` | 可选只读 Atom 白名单 |
| `Caddyfile.reader` | Readeck 专用本机反代 |
| `scripts/reading-sync.py` | 全文入 Readeck、精选入 Obsidian、人工区保护 |
| `scripts/install-reading-sync.sh` | 安装 5 分钟 LaunchAgent |
| `scripts/configure-cloudflare-tunnel.sh` | 独立 Tunnel、DNS 与 LaunchAgent |
| `scripts/verify.sh` | 本机、兼容 RSS 公网、Readeck 公网门禁 |
| `scripts/backup.sh` | WeRSS/Readeck/同步/Tunnel 一致性备份 |
| `scripts/restore-test.sh` | 独立恢复演练 |
| `tests/test_reading_sync.py` | Markdown、幂等、命名、权限契约 |
| `README.md`, `docs/` | 中文图文教程与验收 |
| `coding-agent-harness/` | 工程主账本 |
