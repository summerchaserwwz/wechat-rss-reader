# 执行策略

## Subagent Authorization

| Role | Status | Permission | Authorized By | Authorized At | Scope | Worktree / Branch | Reuse |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reviewer subagent | allowed | read-only | harness task policy | task creation | Compose/Caddy、App 安装、Obsidian | n/a | allowed |
| worker subagent | not needed | none | coordinator decision | 2026-07-14 | 小型单仓，无独立写入切片 | n/a | n/a |

## Subagent Delegation Decision

| Question | Decision | Reason | Next Action |
| --- | --- | --- | --- |
| Should a reviewer subagent be used? | yes | 网络暴露、秘密、恢复、外部 App 和 Vault 契约需要独立视角 | 已使用 3 个只读 reviewer，结论进入 findings/review。 |
| Would a worker subagent materially help? | no | 核心文件共享度高、仓库小，写入并行增加冲突；调查可只读并行 | coordinator 串行实现。 |

## User Authorization Decision

| Gate | State | Decided By | Decided At | Scope | Worktree / Branch | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| worker subagent | not-needed | coordinator | 2026-07-14 | n/a | n/a | 只读 reviewer 已足够。 |

## 决策表

| 决策 | 选择 | 说明 |
| --- | --- | --- |
| 主执行者 | coordinator | 统一管理共享配置、Harness 和 SummerOS 新路径。 |
| Subagent 模式 | reviewer-only | 3 个独立只读审查切片。 |
| 审查模型 | adversarial review | 安全、恢复与外部门禁不能只靠 self-check。 |
| Worktree 策略 | current feature branch | unborn repo 无法先建 linked worktree。 |
| 冲突控制 | coordinator owns shared files | reviewer 不写文件；SummerOS 只新增专属路径。 |
| 证据深度 | L1 + L2 + L3 | Docker/Readeck/Obsidian 已有 live 证据；Cloudflare 与时间 gate 逐级升级。 |

## 子代理合同

| 角色 | 输入包 | 写入范围 | 交接要求 | 负责人 |
| --- | --- | --- | --- | --- |
| Compose/Caddy reviewer | C-001, C-002 | read-only | 镜像、变量、路径绕过、备份 finding | coordinator |
| Runtime reviewer | C-003, 本机环境 | read-only | 官方安装源、签名、人工门禁 | coordinator |
| Obsidian reviewer | Readeck Markdown 契约、SummerOS AGENTS | read-only | Base YAML、人工区保护、Archive 边界 | coordinator |

## 证据计划

| 证据层级 | 计划命令或检查 | 记录位置 | 完成条件 |
| --- | --- | --- | --- |
| L0 | diff、自审、秘密扫描 | `progress.md` | 无明显越界或秘密进入 Git |
| L1 | `bash -n`; YAML/Base parse; registry digest; Caddy validate | `progress.md`; RG-001/RG-005 | 全部通过 |
| L2 | Docker ARM64、本机 Atom/Caddy、备份恢复 | `progress.md`; RG-002/RG-004 | 脚本非零硬门禁通过 |
| L3 | 微信、Readeck、Cloudflare、Obsidian 样本 | `progress.md`; RG-003/006/007/008 | 真实外部证据通过 |

## 暂停 / 升级条件

- 用户没有公众号运营权限。
- Cloudflare 持久账号授权、DNS 变更或桌面应用解锁未完成。
- reviewer 发现 P0/P1 或改变架构的 P2。
- SummerOS 目标路径出现冲突或已有文件。
- 72 小时/7 天尚未达到，不得提前判断长期稳定。
