# WeRSS Readeck Obsidian 阅读系统 - 审查

## 审查者身份（Reviewer Identity）

| Reviewer | Type | Scope |
| --- | --- | --- |
| coordinator-self | self | Compose/Caddy、同步器、备份恢复、Cloudflare 脚本、SummerOS 写入边界 |

## 审查范围

- 审查类型：adversarial + security + regression
- 范围内：本任务所有部署、脚本、文档、真实 Readeck/Obsidian 样本和恢复证据
- 范围外：尚未获得 Zero Trust Free 金融授权的 Cloudflare live 对象；72 小时/7 天真实时间门禁
- 来源材料：task plan、完整 working-tree diff、8 个单测、本机容器、网络 inspect、备份恢复、真实笔记 hash

## Agent Review Submission（Agent 提交审查）

本节由 agent 或 coordinator 在审查材料包准备好时填写。它只表示“提交待审”，不表示人工批准。

| Field | Value |
| --- | --- |
| Submission ID | [由 task-review 生成] |
| Submitted At | [timestamp] |
| Submitted By | [agent 或 coordinator 身份] |
| Task Key | 2026-07-14-werss-folo-obsidian-7118a818 |
| Materials Checklist Hash | [由 task-review 生成；只作信息记录，不作为手工门禁] |
| Evidence Summary | [测试、diff、运行和审查材料证据] |
| Open Findings Count | [数字] |
| Scanner Version | [生成时的 scanner 版本] |

### Material Checklist（材料清单）

| Material | Required? | Status | Evidence |
| --- | --- | --- | --- |
| Brief | yes / no | present / missing / incomplete | [路径或原因] |
| Task plan | yes / no | present / missing / incomplete | [路径或原因] |
| Progress and evidence | yes / no | present / missing / incomplete | [路径或原因] |
| Visual map | yes / no | present / missing / incomplete | [路径或原因] |
| Lesson candidate decision | yes / no | present / missing / incomplete | [路径或原因] |
| Walkthrough or closeout link | yes / no | present / missing / incomplete | [路径或原因] |

Scanner 会根据必需文件、章节、证据和这个严格提交块派生 `materialsReady`。如果材料未齐，任务应进入缺材料队列，而不是人工审查确认队列。
如果存在开放的 P0/P1/P2 阻塞发现，任务应进入阻塞队列，而不是人工审查确认队列。

## 信心挑战（Confidence Challenge）

直接回答：你是否对当前计划、实现和策略有 100% 信心？

- Verdict：no
- 如果不是 100%，剩余漏洞或证据缺口：
  - Cloudflare 账号登录授权已完成；Zero Trust Free 激活、Access、DNS、Tunnel 和公网 smoke 尚未执行。
  - Obsidian 真实 UI screenshot 已完成；Base 列验证尚未执行。
  - 72 小时/7 天时间性证据尚未达到。
- Fix loop count：3（同步幂等；恢复/API Token；Docker 出网网络隔离）
- 当前结论：本机实现和可恢复性可提交；整体任务不能 closeout，等待明确人工/live gate。

## 重要发现（Material Findings，表头供 checker 解析）

| ID | Severity | Finding | Evidence Checked | Required Action | Open | Disposition | Blocks Release | Follow-up |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| REV-001 | P2 | WeRSS 与 Readeck 初版复用普通出网 bridge，容器间可直连 | Compose + docker inspect | 拆分 `werss-internet`/`readeck-internet` 并重跑恢复 | no | closed | no | RG-002 |

不要保留示例 finding。若没有重要发现，只保留表头，并补全下面的无重要发现声明。

允许的 `Severity`：`P0`, `P1`, `P2`, `P3`。
允许的 `Open`：`yes`, `no`。
允许的 `Disposition`：`open`, `mitigated`, `closed`, `deferred`, `accepted-risk`, `not-reproducible`, `out-of-scope`。
允许的 `Blocks Release`：`yes`, `no`。

## 非阻塞备注（Non-Material Notes）

- Reader Caddy 与 RSS Caddy 仍分别连接普通 host-ingress bridge 以支持 Docker Desktop 回环端口发布；固定上游且无用户可控反代目标。
- WeRSS 上游固定摘要的伪 ARM64 问题仍按 R-002 硬失败保留。

## 已检查证据（Evidence Checked）

| Evidence ID | Type | Path | Summary |
| --- | --- | --- | --- |
| E-001 | command | TARGET:tests | 8 unittest pass |
| E-002 | command | TARGET:scripts/verify.sh | 回环端口、Feed、安全、Readeck 303/401 通过；仅 R-002 架构失败 |
| E-003 | command | PRIVATE:backups/wechat-rss-20260715-121728.tar.gz | 独立恢复三个 SQLite、主题、用户、95 篇、收藏、批注、API Token 通过；restore 20260715-121812 |
| E-004 | fixture | EXTERNAL:SummerOS/readeck_inbox/真实文章 | 高亮、批注、原文和人工笔记存在，重复同步 hash 稳定 |
| E-005 | command | TARGET:compose.yaml | WeRSS/Readeck 出网网络隔离，WeRSS 无法解析 Readeck |
| E-006 | screenshot | TARGET:docs/images/01-readeck-公众号文章库.png | 90 篇中文公众号阅读库 |
| E-007 | screenshot | TARGET:docs/images/02-readeck-划线批注.png | 真实高亮和批注汇总 |
| E-008 | screenshot | TARGET:docs/images/03-reader-桌面文章库.png | 新版中文桌面文章库 |
| E-009 | screenshot | TARGET:docs/images/04-reader-移动端正文.png | 390×844 中文长文阅读，无横向溢出 |
| E-010 | screenshot | TARGET:docs/images/05-reader-划线批注.png | 选区、持久下划线和可编辑批注 |
| E-011 | screenshot | TARGET:docs/images/06-obsidian-高亮批注笔记.png | 我的笔记、摘录、批注和原文同页 |
| E-012 | command | TARGET:scripts/restore-test.sh | 本机 Host 303/401；公网 Host 无 Access 身份 403/403；模拟精确 Access 身份 200/200 |

## 无重要发现声明

本轮已检查上述证据，已发现并关闭 REV-001；当前没有开放的代码/配置重要发现。整体发布仍受外部人工和时间门禁约束。

## 残余风险

| Risk | Owner | Accepted? | Follow-up |
| --- | --- | --- | --- |
| Cloudflare live 未验证 | user + coordinator | no | 用户确认 Zero Trust Free 金融授权后，先建 Access 再执行 `configure-cloudflare-tunnel.sh` + `verify --reader-public` |
| Obsidian Base 未验证 | user + coordinator | no | 在现有 Base 验证过滤和列；真实笔记 UI screenshot 已完成 |
| WeRSS x86_64 Rosetta | user + coordinator | no | R-002 |
| 72h/7d 稳定性 | user | no | 稳定性观察模板 |

## Lifecycle Queue Routing（生命周期队列路由）

| Queue | Applies? | Reason | Exit condition |
| --- | --- | --- | --- |
| Review | no | live evidence 未齐，尚未提交最终审查。 | Cloudflare Access/Base/时间证据满足。 |
| Missing Materials | yes | 缺 Obsidian Base 列验证、Cloudflare live、时间性证据。 | 补齐材料。 |
| Blocked | no | 当前是明确人工/时间门禁，不是代码 impasse。 | n/a |
| Lessons | yes | 候选仍待人工决定。 | 人工决定候选路由。 |
| Confirmed / Finalized | no | 未人工确认。 | 最终 review-confirm/closeout。 |
| Soft-deleted / Superseded | no | 任务有效；仅原 Folo 架构被替代。 | n/a |

## 后续路由（Follow-Up Routing）

- 任务计划：已切换 Readeck 架构。
- Progress：2026-07-15 00:25..01:22 条目。
- 发现记录：已记录 Folo 替代、同步保护、网络隔离。
- Regression SSoT：RG-001..008 已调整。
- Lessons：pending human review。
- 收口记录：待 live gate 后更新 `walkthrough.md`。

## 最终信心依据（Final Confidence Basis）

当前信心来自真实容器、真实公众号文章、真实高亮/批注、真实 Reader/Obsidian 截图、幂等 hash、独立恢复和网络隔离证据。尚未形成最终发布信心；Cloudflare Access、Base 与时间 gate 后仍需最终复审。
