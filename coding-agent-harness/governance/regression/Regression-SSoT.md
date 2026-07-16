# 回归 SSoT - WeChat RSS Stack

## 活跃回归 Gate

| Gate ID | 覆盖面 | 主入口 | 触发场景 | 证据深度 | 上次验证 | 当前结果 | 负责人 | 残余路由 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RG-001 | Shell、YAML、plist、镜像摘要、Caddy/Base 静态契约 | shell lint；Compose/plist/Base parse | 任意配置/脚本/Base 变更 | L1-tests | 2026-07-16 | pass；14 unittest、Shell、Compose、4 plist、diff check、Harness | coordinator | none |
| RG-002 | 本机 Compose、回环端口、代理与网络隔离 | `./scripts/verify.sh --local`; network inspect | 镜像、端口、Caddy、WeRSS/Readeck 变更 | L2-local-smoke | 2026-07-16 | partial；8001/8002/8080/8082/8083、同步映射和安全 pass，WeRSS 架构 residual | coordinator | R-002 |
| RG-003 | Cloudflare Access + Reader/WeRSS 公网身份边界 | `./scripts/verify.sh --reader-public`; `verify-werss-public.sh`; 无 Cookie/授权浏览器 | Access、Tunnel、DNS、Reader/WeRSS Caddy 变更 | L3-live | 2026-07-16 | pass；两个 Access 应用和独立 AUD，匿名 Reader/API/Feed/WeRSS 拦截；授权浏览器免 Readeck 密码并到达 WeRSS 原生登录 | user + coordinator | none |
| RG-004 | WeRSS/Readeck/同步状态/Reader 主题/主动刷新备份恢复 | `backup.sh`; `restore-test.sh` | 数据、密钥、镜像、主题升级前后 | L2-local-smoke | 2026-07-16 | pass；backup 20260716-002238、restore 20260716-002339，三个 SQLite、107 篇、双 Access Caddy、刷新凭据、Tunnel 作用域凭据且排除 cert.pem | coordinator | none |
| RG-005 | Obsidian Base 与真实笔记结构 | Base parse；Obsidian UI；真实样本 | Base/字段/目录变更 | L3-live | 2026-07-15 | pass；真实笔记与 Base 九列横向实机验收 | user + coordinator | none |
| RG-006 | 微信抓取与每小时调度 | 12 源 + `17 * * * *` + SQLite/任务队列 | 授权、抓取配置、镜像升级 | L3-live | 2026-07-15 | partial；三次连续 12/12 周期与 2.16 分钟同步通过，长期周期待观察 | user + coordinator | R-006 |
| RG-007 | WeRSS → Readeck 全量同步 | unittest；跨三个 SQLite 唯一映射；LaunchAgent | 同步器/Readeck API 变更 | L2/L3 | 2026-07-16 | pass；12/12 来源、107/107 正文唯一映射，0 孤儿/错配 | coordinator | none |
| RG-008 | Readeck → Obsidian 收藏/高亮/批注与保护 | 真实样本；hash/mtime；unittest | Markdown 渲染/筛选规则变更 | L3-live | 2026-07-15 | pass-with-residual；1 真实样本，额外排版样本待补 | coordinator | R-008 |
| RG-009 | 中文科技蓝 Reader UI 与主动刷新 | `verify-reader-ui.sh`; 1440×900/390×844 截图；真实按钮点击；4 refresh tests | Reader UI、主题、刷新控制端、WeRSS API 变更 | L3/L4 | 2026-07-16 | pass；6 Tab、收藏/已读/价值/主题、淡绿虚线、刷新全链路 complete、10 分钟冷却与失败保护 | coordinator | none |

## 未关闭回归残余

| 残余 ID | Gate ID | 问题 | 严重级别 | 负责人 | 创建日期 | 路由 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-002 | RG-002 | 上游 arm64 manifest 实际包含 AMD64 layers；固定摘要只能通过 Rosetta 运行 | P1 | user + coordinator | 2026-07-14 | 接受模拟运行或维护自建 ARM64 镜像 | open |
| R-006 | RG-006 | 三次连续 12/12 周期和真实新增文章 2.16 分钟零重复已通过；12:17 维护中断样本已排除；仅 72 小时/7 天时间性证据尚未达到 | P1 | user + automation | 2026-07-15 | 73 次 `wechat-rss-hourly-observation` + 8 天 `wechat-rss-stability-watch` + 22 列 observation TSV | open |
| R-008 | RG-008 | 真实长文/高亮/批注/人工保护通过；表格/代码、复杂排版等额外样本待自然出现或构造 | P2 | coordinator | 2026-07-15 | 补充样本 | open |

## 证据深度

- L1-tests：静态语法、结构或 registry 断言。
- L2-local-smoke：本机真实容器与恢复实例。
- L3-live：真实微信、Readeck、Cloudflare、Obsidian 端到端。
- L4-browser-human-proxy：桌面应用自动化截图。
- L5-hard-gate：脚本以非零退出阻断；WeRSS 架构 residual 保持硬失败。
