# 回归 SSoT - WeChat RSS Stack

## 活跃回归 Gate

| Gate ID | 覆盖面 | 主入口 | 触发场景 | 证据深度 | 上次验证 | 当前结果 | 负责人 | 残余路由 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RG-001 | Shell、YAML、镜像摘要、Caddy/Base 静态契约 | shell lint；Compose/Base parse | 任意配置/脚本/Base 变更 | L1-tests | 2026-07-15 | pass | coordinator | none |
| RG-002 | 本机 Compose、回环端口、代理与网络隔离 | `./scripts/verify.sh --local`; network inspect | 镜像、端口、Caddy、WeRSS/Readeck 变更 | L2-local-smoke | 2026-07-15 | partial；安全/隔离/Readeck pass，WeRSS 架构 residual | coordinator | R-002 |
| RG-003 | Cloudflare Readeck 公网登录边界 | `./scripts/verify.sh --reader-public` | Tunnel、DNS、Reader Caddy 变更 | L3-live | 2026-07-15 | paused before account authorization | user + coordinator | R-003 |
| RG-004 | WeRSS/Readeck/同步状态备份恢复 | `backup.sh`; `restore-test.sh` | 数据、密钥、镜像升级前后 | L2-local-smoke | 2026-07-15 | pass | coordinator | none |
| RG-005 | Obsidian Base 与真实笔记结构 | Base parse；Obsidian UI；真实样本 | Base/字段/目录变更 | L3-live | 2026-07-15 | partial；文件样本 pass，UI screenshot pending unlock | user + coordinator | R-005 |
| RG-006 | 微信抓取与每小时调度 | 12 源 + `17 * * * *` + SQLite/任务队列 | 授权、抓取配置、镜像升级 | L3-live | 2026-07-15 | partial；12 源/94 篇，长期周期待观察 | user + coordinator | R-006 |
| RG-007 | WeRSS → Readeck 全量同步 | unittest；API/SQLite 计数；LaunchAgent | 同步器/Readeck API 变更 | L2/L3 | 2026-07-15 | pass；90 完整文章 loaded | coordinator | none |
| RG-008 | Readeck → Obsidian 收藏/高亮/批注与保护 | 真实样本；hash/mtime；unittest | Markdown 渲染/筛选规则变更 | L3-live | 2026-07-15 | pass-with-residual；1 真实样本，额外排版样本待补 | coordinator | R-008 |

## 未关闭回归残余

| 残余 ID | Gate ID | 问题 | 严重级别 | 负责人 | 创建日期 | 路由 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-002 | RG-002 | 上游 arm64 manifest 实际包含 AMD64 layers；固定摘要只能通过 Rosetta 运行 | P1 | user + coordinator | 2026-07-14 | 接受模拟运行或维护自建 ARM64 镜像 | open |
| R-003 | RG-003 | 创建 Tunnel 与 DNS 需要用户对 Cloudflare 持久账号授权进行 action-time 确认 | P1 | user | 2026-07-15 | 解锁 Mac、确认后运行配置脚本 | open |
| R-005 | RG-005 | Mac 锁屏，暂时无法取得 Obsidian UI 截图和 Base 实机列验证 | P2 | user + coordinator | 2026-07-15 | 用户解锁后 Computer Use | open |
| R-006 | RG-006 | 12 源和每小时 Cron 已完成；72 小时/7 天时间性证据尚未达到 | P1 | user + automation | 2026-07-15 | `wechat-rss-stability-watch` + observation TSV | open |
| R-008 | RG-008 | 真实长文/高亮/批注/人工保护通过；表格/代码、复杂排版等额外样本待自然出现或构造 | P2 | coordinator | 2026-07-15 | 补充样本 | open |

## 证据深度

- L1-tests：静态语法、结构或 registry 断言。
- L2-local-smoke：本机真实容器与恢复实例。
- L3-live：真实微信、Readeck、Cloudflare、Obsidian 端到端。
- L4-browser-human-proxy：桌面应用自动化截图。
- L5-hard-gate：脚本以非零退出阻断；WeRSS 架构 residual 保持硬失败。
