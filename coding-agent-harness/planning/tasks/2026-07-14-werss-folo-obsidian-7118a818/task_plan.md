# WeRSS Folo Obsidian 阅读系统

Task Contract: harness-task/v1
Task Package Index: required

## 目标

把用户指定的公众号阅读方案真实落地到本机，并以安全、可恢复、可观察的方式推进到必须由用户完成的外部门禁。

## 范围

- 做什么：Harness、Compose/Caddy、密钥、安装、验证、备份恢复、Funnel、Folo 试验、SummerOS Inbox/Base/模板。
- 不做什么：修改上游源码、自动接受法律协议、代办账号登录/付费、公开管理端、自动全量附件本地化。
- 主要风险：微信运营资格、WeRSS 上游风控、随机 URL 泄露、Mac 休眠、Folo 云刷新、SQLite/授权恢复、SummerOS dirty 仓库。

## 目标对齐反问

| 问题 | 回答 / 证据 |
| --- | --- |
| 必须保持为真的原始用户目标是什么？ | 精选公众号能在干净 RSS 中自动更新，优秀内容可进入 Obsidian 高亮批注和知识提升。 |
| 本任务是否直接让该目标更真实？ | yes；同时实现抓取、只读公网、阅读、入库、维护和验证。 |
| 最容易误用的便利替代是什么？ | 只写 Compose/README，或只证明 Feed URL 当前能打开，就声称全链路完成。 |
| 本任务完成后不能声称什么？ | 人工扫码、Folo 72 小时/7 天、Basic 入库和五类样本没有真实证据前，不能声称系统完成。 |
| evidence-only 为什么不等于完成？ | 静态和本机证据不能替代微信、Funnel、Folo 与 Obsidian 的 live gate。 |
| replacement/cutover 证据是什么？ | 不适用；这是新系统建立，不替换现有生产依赖。 |

## 预算选择

选择预算：complex

选择理由：跨 Docker、本机 App、微信、网络暴露、云阅读器、独立 Vault、秘密、恢复和 7 天观察，且使用多个只读 reviewer。

## 上下文包

| ID | 类型 | 路径 | 为什么需要 | 使用者 |
| --- | --- | --- | --- | --- |
| C-001 | external | `URL:https://github.com/rachelos/we-mp-rss` | 上游环境变量、镜像和授权行为 | coordinator/reviewer |
| C-002 | code | `TARGET:compose.yaml`; `TARGET:Caddyfile` | 核心部署与安全边界 | coordinator/reviewer |
| C-003 | private-plan | `TARGET:README.md`; `TARGET:docs/验收清单.md` | 用户操作与验收 | coordinator/user |
| C-004 | external | `URL:https://github.com/RSSNext/Folo` | Folo 版本、字段和 Obsidian 集成 | coordinator/reviewer |
| C-005 | private-plan | `EXTERNAL:/Users/summer/Obsidian/SummerOS/AGENTS.md` | SummerOS 写入边界 | coordinator/reviewer |

## 步骤

1. 初始化并项目化 complex + long-running Harness。
2. 创建 Compose、Caddy、密钥、验证、Funnel、观察、备份与恢复部署包。
3. 创建 SummerOS reading Inbox、Base、模板和中文边界说明。
4. 安装 Docker Desktop 与 Folo，完成本机 Compose/ARM64/Atom/安全冒烟。
5. 用户完成公众号资格、Docker/Tailscale/微信/Folo 人工门禁，添加 3 个源与定时任务。
6. 启用 Funnel 并完成公网安全验收。
7. 连续观察 Folo 72 小时和 7 天，按规则选择聚合/单源/本地备用。
8. 通过后启用 Obsidian 集成，验证五类样本和同名保护。
9. 完成真实备份恢复、对抗审查、walkthrough 和 closeout。

## 验收标准

- [x] 部署包、密钥权限、日志轮转和固定摘要落地。
- [x] Caddy 仅允许随机 `.atom` GET/HEAD，其他路径/方法 404。
- [x] SummerOS Inbox、Base、模板和 Archive 边界落地。
- [ ] Docker 本机运行与 `verify --local` 通过。
- [ ] 微信运营者授权、3 个源、`17 */2 * * *` 与 36 周期通过。
- [ ] Funnel 与 `verify --public` 通过。
- [ ] Folo 72 小时/7 天门禁通过或完成降级判断。
- [ ] Obsidian 五类样本、同名保护与提升流程通过。
- [ ] 真实备份恢复、review 和人工确认完成。

## 工作树

- 路径：当前 checkout `/Users/summer/Documents/wechat-rss`
- 分支：`codex/wechat-rss-stack`
- Worker owner：coordinator
- Worker handoff commit required：不适用
- Coordinator integration branch：`main`
- 未使用 linked worktree 的原因：仓库启动时没有任何基线提交，无法从 unborn HEAD 创建 worktree；已先创建独立功能分支。

## 长程任务判定

- 是否属于长程任务：是
- 合同文件：`long-running-task-contract.md`
- 连续执行权限：已由“PLEASE IMPLEMENT THIS PLAN”授权范围内推进
- Stop Condition：所有 agent 可执行 gate 完成；人工/时间 gate 真实通过或以明确 residual 暂停。

## 审查判定

- 是否需要对抗性审查：是
- 报告文件：`review.md`
- Reviewer：self + 3 个只读 subagent + 最终复审
- No-finding 要求：Compose/Caddy 安全无 open material finding；人工 live gate 未完成时作为 residual，不伪装 no-finding。

## 关联

- Regression Gate：RG-001..RG-008
- 审查报告：`review.md`
- Generated Ledger：Harness lifecycle CLI
- 前置任务：无

## 模块关联

- Module：不适用
- Step：不适用
- Module Plan：不适用

## 协调者交接

- Global sync owner：coordinator
- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：task lifecycle CLI
- Closeout / Regression update needed：`walkthrough.md`; Regression SSoT
