# 架构事实源

Context Doc Type: architecture-ssot
Owner: coordinator
Last Verified: 2026-07-14
Confidence: high for local design; pending for live external gates

## System Summary

本仓库不是 WeRSS 源码 fork，而是可复现的本机部署与运维包。WeRSS 抓取公众号并生成 Atom；Caddy 只公开随机前缀下的 Atom；Tailscale Funnel 提供公网 HTTPS；Folo 云端抓取并在桌面/移动端浏览；精选文章进入 SummerOS Archive，在 Obsidian 批注并按需提升。

## Current Architecture Facts

| ID | Fact | Source Evidence | Last Verified | Confidence | Read Before |
| --- | --- | --- | --- | --- | --- |
| ARCH-001 | WeRSS 管理端只绑定 `127.0.0.1:8001` | `compose.yaml` | 2026-07-14 | high | 网络/端口修改 |
| ARCH-002 | Caddy 只绑定 `127.0.0.1:8080`，只放行随机前缀的 `feed/*.atom` | `compose.yaml`; `Caddyfile` | 2026-07-14 | high | 公网安全修改 |
| ARCH-003 | WeRSS 镜像摘要含 linux/arm64，固定镜像实际使用 WebKit | GHCR manifest；镜像 config；`compose.yaml` | 2026-07-14 | high | 镜像/浏览器修改 |
| ARCH-004 | 数据、授权与密钥持久化位于 `data/` 与 `.env` | `compose.yaml`; `scripts/backup.sh` | 2026-07-14 | high | 备份/恢复 |
| ARCH-005 | Folo 不自托管，批注系统在 Obsidian | 用户确认计划；Folo 能力审查 | 2026-07-14 | high | 阅读流修改 |
| ARCH-006 | SummerOS 目标是 Archive processed source inbox | `/Users/summer/Obsidian/SummerOS/.../reading/README.md` | 2026-07-14 | high | Vault 写入 |
| ARCH-007 | Tailscale 已有 tailnet 身份但当前可能 Stopped，Funnel 需首次网页批准 | 本机 Tailscale 1.98.5 status/help | 2026-07-14 | high | Funnel 操作 |
| ARCH-008 | 微信授权和 72 小时/7 天观察尚需人工/时间证据 | 当前 task progress | 2026-07-14 | high | 完成判断 |

## Promotion Log

| Source Task | Promoted Fact | Destination | Decision | Date |
| --- | --- | --- | --- | --- |
| `2026-07-14-werss-folo-obsidian-7118a818` | 本表 ARCH-001..008 | architecture SSoT | accepted | 2026-07-14 |
