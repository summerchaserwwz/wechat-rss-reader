# 回归 SSoT - WeChat RSS Stack

## 活跃回归 Gate

| Gate ID | 覆盖面 | 主入口 | 触发场景 | 证据深度 | 上次验证 | 当前结果 | 负责人 | 残余路由 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RG-001 | Shell、YAML、镜像摘要、Caddy/Base 静态契约 | `bash -n scripts/*.sh`; Compose/YAML/Base parse | 任意配置、脚本、Base 变更 | L1-tests | 2026-07-14 | pass | coordinator | none |
| RG-002 | 本机 ARM64 Compose 与只读代理 | `./scripts/verify.sh --local` | 镜像、端口、Caddy、WeRSS 配置变更 | L2-local-smoke | 2026-07-14 | fail（安全/Feed pass，架构 fail） | coordinator | R-002 |
| RG-003 | Tailscale Funnel 公网安全 | `./scripts/verify.sh --public` | Funnel、前缀、RSS_BASE_URL、Caddy 变更 | L3-live | 2026-07-14 | paused | user + coordinator | R-003 |
| RG-004 | SQLite/授权一致性备份与独立恢复 | `./scripts/backup.sh`; `./scripts/restore-test.sh` | data、密钥、镜像升级前后 | L2-local-smoke | 2026-07-14 | pass-with-residual | coordinator | R-004 |
| RG-005 | Obsidian Base 与收件箱结构 | YAML parse + Obsidian 1.12.7 人工打开 | Base/字段/目录变更 | L1-tests | 2026-07-14 | pass-with-residual | user + coordinator | R-005 |
| RG-006 | 微信抓取与定时任务 | 3 个试验源 + `17 */2 * * *` | 授权、抓取配置、镜像升级 | L3-live | 2026-07-14 | partial（授权/任务/5源有文章） | user | R-006 |
| RG-007 | Folo 云端刷新稳定性 | `scripts/record-observation.sh` + Folo UI | Feed/订阅/Folo 变更 | L3-live | 2026-07-14 | paused | user | R-007 |
| RG-008 | Folo -> Obsidian 五类样本与同名保护 | Folo UI + Vault 样本检查 | Folo/Obsidian 集成变更 | L3-live | 2026-07-14 | paused | user | R-008 |

## 未关闭回归残余

| 残余 ID | Gate ID | 问题 | 严重级别 | 负责人 | 创建日期 | 路由 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-002 | RG-002 | 上游 arm64 manifest 实际包含 AMD64 layers；固定摘要只能通过 Rosetta 运行 | P1 | user + coordinator | 2026-07-14 | 显式选择接受模拟运行或维护自建原生 ARM64 镜像 | open |
| R-003 | RG-003 | Tailscale 当前需连接，首次 Funnel 需网页批准 | P1 | user | 2026-07-14 | `configure-funnel.sh` | open |
| R-004 | RG-004 | 独立恢复实例与 SQLite 已通过；当前备份有 `wx.lic` 和 `.secret_key`，但尚无 `key.lic`，需在真实微信授权后复验登录与授权状态 | P1 | coordinator | 2026-07-14 | 微信授权后再次备份恢复 | open |
| R-005 | RG-005 | Base 已静态验证，尚未在 Obsidian UI 打开确认列类型/显示 | P2 | user | 2026-07-14 | 打开 `公众号精选.base` | open |
| R-006 | RG-006 | 授权、12 个源和 Cron 已完成，5 个源有文章；其余来源及至少 36 个自动周期仍待观察 | P1 | user | 2026-07-14 | WeRSS UI、任务日志与 Atom | open |
| R-007 | RG-007 | 72 小时/7 天 Folo 观察尚未开始 | P1 | user | 2026-07-14 | `docs/稳定性观察模板.md` | open |
| R-008 | RG-008 | Basic、集成授权与五类导出样本尚未完成 | P1 | user | 2026-07-14 | 72 小时门禁后执行 | open |

## 证据深度

- L1-tests：静态语法、结构或 registry 断言。
- L2-local-smoke：本机真实容器与恢复实例。
- L3-live：真实微信、Tailscale、Folo、Obsidian 端到端。
- L4-browser-human-proxy：后续如建立浏览器自动化再启用。
- L5-hard-gate：脚本以非零退出阻断；`verify.sh` 属于局部 L5 判定，但整体环境证据仍按 L2/L3 标注。
