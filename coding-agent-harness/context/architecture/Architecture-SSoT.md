# 架构事实源

Context Doc Type: architecture-ssot
Owner: coordinator
Last Verified: 2026-07-15
Confidence: high for local and live Cloudflare design

## System Summary

本仓库不是 WeRSS 或 Readeck 源码 fork，而是本机部署与运维包。WeRSS 每小时抓取公众号；同步器把完整正文全量写入自托管 Readeck；用户在自定义公众号阅读器中收藏、划线和批注；精选文章自动进入 SummerOS Archive，人工笔记和元数据永不覆盖。Cloudflare Access 负责设备身份，Tunnel 分别公开经过独立 AUD 校验的 Reader 与 WeRSS 管理入口，Folo/Tailscale 退出主链路。

## Current Architecture Facts

| ID | Fact | Source Evidence | Last Verified | Confidence | Read Before |
| --- | --- | --- | --- | --- | --- |
| ARCH-001 | WeRSS 管理端只绑定 `127.0.0.1:8001` | `compose.yaml` | 2026-07-15 | high | 网络/端口修改 |
| ARCH-002 | 兼容 RSS Caddy 只绑定 `127.0.0.1:8080`，只放行随机前缀 `feed/*.atom` | `compose.yaml`; `Caddyfile` | 2026-07-15 | high | RSS 公网修改 |
| ARCH-003 | Readeck 0.22.3 固定摘要、原生 aarch64，只绑定 `127.0.0.1:8002` | `compose.yaml`; runtime | 2026-07-15 | high | 阅读器修改 |
| ARCH-004 | Readeck 专用 Caddy 只绑定 `127.0.0.1:8082`；公网 Host 缺 Access JWT/精确邮箱时 403，本机 Host 保留 Readeck 303/401 | `compose.yaml`; `Caddyfile.reader`; local smoke | 2026-07-15 | high | Cloudflare 修改 |
| ARCH-005 | 完整正文全量进入 Readeck；只有收藏或含高亮/批注的文章默认进入 Obsidian | `scripts/reading-sync.py`; tests | 2026-07-15 | high | 同步器修改 |
| ARCH-006 | SummerOS 目标是 Archive processed source inbox；原文不直接晋升 Knowledge/Output | SummerOS reading README | 2026-07-15 | high | Vault 写入 |
| ARCH-007 | 人工 frontmatter 与“我的笔记”受保护；机器区刷新，高亮为 `==...==`、批注为摘录和脚注 | 实际样本；hash/mtime；tests | 2026-07-15 | high | Markdown 渲染修改 |
| ARCH-008 | WeRSS 定时任务为 `17 * * * *`；微信无 webhook，只能近实时 | live SQLite | 2026-07-15 | high | 调度修改 |
| ARCH-009 | Cloudflare 先建 Access OTP 精确邮箱 Allow 应用，再建独立 `wechat-rss` Tunnel；`cloudflared` 按 team/AUD 校验 JWT 后转发 `reader.sumerchaser.top -> 127.0.0.1:8082`；当前 live 公网验收通过 | official docs; live Access/Tunnel/DNS; `verify --reader-public` | 2026-07-15 | high | 公网部署 |
| ARCH-010 | 备份必须同时停止 WeRSS/Readeck，覆盖三个 SQLite、API Token、Reader 主题、资源和 Tunnel 作用域凭据，排除账户 `cert.pem` | `scripts/backup.sh`; `restore-test.sh`; restore 20260715-140113 | 2026-07-15 | high | 备份/恢复 |
| ARCH-011 | 固定 WeRSS manifest 实际仍是 AMD64 filesystem，通过 Rosetta 运行；不得伪装原生通过 | runtime root-cause evidence | 2026-07-14 | high | 镜像修改 |
| ARCH-012 | WeRSS 与 Readeck 使用独立出网网络，彼此不能通过共享 bridge 直连 | `compose.yaml`; network inspect | 2026-07-15 | high | 网络修改 |
| ARCH-013 | Reader 主题由固定 Readeck CSS 与本地主题在 Caddy 启动时拼接；Folo 三栏结合 Petdex 科技蓝环境光和 Apple 磨砂控件；Cron 转成人类可读状态；临时选区与持久批注保留正文颜色并使用透明底淡绿虚线；批注框避让选区，保存后原位显示笔记；划线笔记按条集中并支持 Markdown/可选目录导出；右侧字号持久化；390×844 无横向溢出 | browser runtime; screenshots 03-05, 09-15; Markdown export evidence; `verify-reader-ui.sh` | 2026-07-16 | high | UI/主题修改 |
| ARCH-014 | WeRSS 公网 Caddy 只绑定 `127.0.0.1:8083`；`werss.sumerchaser.top` 使用独立 Access 应用和 AUD，匿名根/API 被边缘拦截，授权 Chrome 进入 WeRSS 原生登录页 | `compose.yaml`; `Caddyfile.werss-public`; live Access/Tunnel/DNS; `verify-werss-public.sh` | 2026-07-15 | high | WeRSS 公网修改 |
| ARCH-015 | Reader 主动刷新控制端只绑定 `127.0.0.1:8787`，只接受 Caddy 转发的 POST，并校验 Host、Origin、Access 邮箱/JWT 与内部密钥；使用 WeRSS Access Key 触发全部公众号任务，10 分钟冷却、single-flight、连续两次失败暂停，抓取后运行 reading-sync | `scripts/reader-refresh-control.py`; 4 tests; live full-chain click | 2026-07-15 | high | 主动刷新修改 |

## Promotion Log

| Source Task | Promoted Fact | Destination | Decision | Date |
| --- | --- | --- | --- | --- |
| `2026-07-14-werss-folo-obsidian-7118a818` | ARCH-001..015 | architecture SSoT | accepted; Folo 架构被 Readeck 架构取代，并加入受 Access 保护的 WeRSS 管理与主动刷新 | 2026-07-15 |
