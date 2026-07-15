# 回归 SSoT - WeChat RSS Stack

## 活跃回归 Gate

| Gate ID | 覆盖面 | 主入口 | 触发场景 | 证据深度 | 上次验证 | 当前结果 | 负责人 | 残余路由 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RG-001 | Shell、YAML、镜像摘要、Caddy/Base 静态契约 | shell lint；Compose/Base parse | 任意配置/脚本/Base 变更 | L1-tests | 2026-07-15 | pass | coordinator | none |
| RG-002 | 本机 Compose、回环端口、代理与网络隔离 | `./scripts/verify.sh --local`; network inspect | 镜像、端口、Caddy、WeRSS/Readeck 变更 | L2-local-smoke | 2026-07-15 | partial；安全/隔离/Readeck pass，WeRSS 架构 residual | coordinator | R-002 |
| RG-003 | Cloudflare Access + Readeck 公网身份边界 | `./scripts/verify.sh --reader-public`; 无痕/授权浏览器 | Access、Tunnel、DNS、Reader Caddy 变更 | L3-live | 2026-07-15 | local 403/403 fail-closed 与模拟 Access 200/200 pass；Zero Trust 金融授权待确认 | user + coordinator | R-003 |
| RG-004 | WeRSS/Readeck/同步状态/Reader 主题备份恢复 | `backup.sh`; `restore-test.sh` | 数据、密钥、镜像、主题升级前后 | L2-local-smoke | 2026-07-15 | pass；backup 20260715-121728、restore 20260715-121812 | coordinator | none |
| RG-005 | Obsidian Base 与真实笔记结构 | Base parse；Obsidian UI；真实样本 | Base/字段/目录变更 | L3-live | 2026-07-15 | partial；真实 UI screenshot pass，Base 列待验 | user + coordinator | R-005 |
| RG-006 | 微信抓取与每小时调度 | 12 源 + `17 * * * *` + SQLite/任务队列 | 授权、抓取配置、镜像升级 | L3-live | 2026-07-15 | partial；三次连续 12/12 周期与 2.16 分钟同步通过，长期周期待观察 | user + coordinator | R-006 |
| RG-007 | WeRSS → Readeck 全量同步 | unittest；跨三个 SQLite 唯一映射；LaunchAgent | 同步器/Readeck API 变更 | L2/L3 | 2026-07-15 | pass；12/12 来源、95/95 正文唯一映射，0 孤儿/错配 | coordinator | none |
| RG-008 | Readeck → Obsidian 收藏/高亮/批注与保护 | 真实样本；hash/mtime；unittest | Markdown 渲染/筛选规则变更 | L3-live | 2026-07-15 | pass-with-residual；1 真实样本，额外排版样本待补 | coordinator | R-008 |

## 未关闭回归残余

| 残余 ID | Gate ID | 问题 | 严重级别 | 负责人 | 创建日期 | 路由 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-002 | RG-002 | 上游 arm64 manifest 实际包含 AMD64 layers；固定摘要只能通过 Rosetta 运行 | P1 | user + coordinator | 2026-07-14 | 接受模拟运行或维护自建 ARM64 镜像 | open |
| R-003 | RG-003 | Cloudflare 账号授权已完成；Zero Trust Free 激活要求未来超额用量收费授权，Access/Tunnel/DNS 尚未创建 | P1 | user | 2026-07-15 | 用户明确允许或拒绝激活；允许后先 Access 再 Tunnel | open |
| R-005 | RG-005 | Obsidian UI 截图已完成；Base 实机列验证仍待收口 | P2 | user + coordinator | 2026-07-15 | 在现有 Base 验证字段和过滤 | open |
| R-006 | RG-006 | 三次连续 12/12 周期和真实新增文章 2.16 分钟零重复已通过；12:17 维护中断样本已排除；仅 72 小时/7 天时间性证据尚未达到 | P1 | user + automation | 2026-07-15 | 73 次 `wechat-rss-hourly-observation` + 8 天 `wechat-rss-stability-watch` + 22 列 observation TSV | open |
| R-008 | RG-008 | 真实长文/高亮/批注/人工保护通过；表格/代码、复杂排版等额外样本待自然出现或构造 | P2 | coordinator | 2026-07-15 | 补充样本 | open |

## 证据深度

- L1-tests：静态语法、结构或 registry 断言。
- L2-local-smoke：本机真实容器与恢复实例。
- L3-live：真实微信、Readeck、Cloudflare、Obsidian 端到端。
- L4-browser-human-proxy：桌面应用自动化截图。
- L5-hard-gate：脚本以非零退出阻断；WeRSS 架构 residual 保持硬失败。
