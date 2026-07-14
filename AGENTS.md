# WeChat RSS Stack Agent 入口

本仓库维护 WeRSS、自托管 Readeck、两个本机 Caddy、Cloudflare Tunnel、自动同步器和 SummerOS Obsidian 之间的公众号阅读链路。`coding-agent-harness/` 是唯一工程主账本。

## 项目概况

- 项目名：WeRSS + Readeck + Obsidian 公众号阅读系统
- 仓库形态：单仓、本机部署包、外部 SaaS/桌面应用集成
- 运行环境：Apple Silicon macOS、Docker Compose、SQLite、Caddy、Cloudflare Tunnel
- 默认分支：`main`
- 当前实施分支：`codex/wechat-rss-stack`
- Delivery Operating Model：`solo-orchestrator`
- 主任务：`coding-agent-harness/planning/tasks/2026-07-14-werss-folo-obsidian-7118a818`

## 不可违反的规则

1. 不提交 `.env`、`data/`、`backups/`、`observations/`、DMG、Feed 随机前缀或任何登录/授权材料。
2. 不覆盖已有 `.env`；密钥轮换必须显式执行并记录影响。
3. WeRSS 只允许绑定 `127.0.0.1:8001`，RSS Caddy 只允许 `127.0.0.1:8080`，Readeck 只允许 `127.0.0.1:8002`，Reader Caddy 只允许 `127.0.0.1:8082`。
4. 公网只允许随机前缀下的 `GET/HEAD /feed/*.atom`；其他路径和方法必须 `404`。
5. WeRSS、Readeck 与 Caddy 镜像使用固定摘要，不跟随 `latest`，不安装 Watchtower。
6. 固定 WeRSS 镜像只使用 WebKit；不要把 `BROWSER_TYPE` 改为 Firefox，除非先更换并验证镜像。
7. SQLite 备份前必须短暂停止 WeRSS 与 Readeck；恢复演练只能在独立目录、不同 Compose project 和端口执行。
8. WeRSS 会在日志中打印环境变量；不得把原始容器日志写入公开 evidence、Issue 或文档。
9. `FEED_PREFIX`、Readeck API Token 与 Cloudflare Tunnel 凭据都是秘密；不得进入公开笔记、截图、Issue 或日志。
10. Readeck 负责全文阅读、收藏、高亮和批注；同步器只把收藏或含高亮/批注的文章默认写入 Obsidian，且不得覆盖人工区。
11. 完整公众号原文始终留在 SummerOS Archive；提升时创建衍生 Knowledge/Output 条目，不移动原文。
12. 修改 SummerOS 前先读 `/Users/summer/Obsidian/SummerOS/AGENTS.md`，只创建本任务的新路径，不混入其大量既有 dirty 改动。
13. 资格、Docker 协议、微信扫码、Cloudflare 持久授权/DNS、Obsidian UI 解锁和 72 小时观察属于人工或时间门禁，不能虚报完成。
14. 声称完成前必须有真实验证证据；不能验证的部分写入 residual。

## 任务阅读矩阵

| 任务类型 | 先读文件 |
| --- | --- |
| 当前实施或恢复上下文 | 当前任务的 `brief.md`、`task_plan.md`、`progress.md`、`findings.md` |
| Compose、端口、镜像、数据边界 | `coding-agent-harness/context/architecture/Architecture-SSoT.md`、`system-map.md` |
| Caddy、Readeck、Cloudflare、Obsidian 契约 | `coding-agent-harness/context/integrations/README.md` |
| 本机安装与启动 | `coding-agent-harness/context/development/local-setup.md`、根 `README.md` |
| 测试、冒烟、恢复 | `coding-agent-harness/governance/standards/testing-standard.md`、`governance/regression/Regression-SSoT.md` |
| Git、提交、PR | `governance/standards/execution-workflow-standard.md`、`repo-governance-standard.md`、`ci-cd-standard.md` |
| 长程执行 | 当前任务 `long-running-task-contract.md`、`governance/standards/long-running-task-standard.md` |
| 对抗审查 | 当前任务 `review.md`、`governance/standards/adversarial-review-standard.md`、`review-routing-standard.md` |
| 收口与经验 | `governance/standards/walkthrough-standard.md`、当前任务 `walkthrough.md`、`lesson_candidates.md` |

## 标准执行流程

1. 运行 `harness status --json .` 和 `git status --short`，恢复主账本与 dirty 状态。
2. 阅读当前任务目标、阶段表、人工门禁和 residual。
3. 只修改当前任务范围；保护 SummerOS 与本仓库无关改动。
4. 配置改动先做静态验证，再做本机运行时验证，再做公网/人工门禁验证。
5. 使用 `scripts/verify.sh`，不要手工复制会泄露秘密的完整 Compose 配置或日志。
6. 运行备份/恢复前确认路径与服务状态，不覆盖 live data。
7. 研究事实和方案偏差写入 `findings.md`，命令证据写入 `progress.md`。
8. 每个已验证且边界清晰的切片只 stage 本任务文件并提交；不能提交时记录 no-commit reason。
9. 收口前执行 L1 reviewer 对抗审查，关闭阻塞 finding。
10. 人工门禁未完成时保持任务进行中或已阻塞，不执行人工 `review-confirm`。

## Subagent 规则

- 只读 reviewer 默认允许，适合 Compose/Caddy 安全、运行时安装和 Obsidian Base 契约审查。
- 当前仓库很小，worker subagent 默认不需要；若未来让 worker 改文件，必须独立 worktree/branch、明确 write scope 并提交 handoff commit。
- 共享主账本、Regression SSoT 和最终集成由 coordinator 串行维护。

## 本地命令

| 用途 | 命令 |
| --- | --- |
| 生成密钥 | `./scripts/init-secrets.sh` |
| 环境诊断 | `./scripts/doctor.sh` |
| 启动 | `docker compose up -d` |
| 静态检查 | `bash -n scripts/*.sh && docker compose config --quiet` |
| 本机冒烟 | `./scripts/verify.sh --local` |
| Readeck 公网冒烟 | `./scripts/verify.sh --reader-public` |
| 备份 | `./scripts/backup.sh` |
| 独立恢复 | `./scripts/restore-test.sh` |
| Harness 检查 | `harness check --profile target-project .` |

## 单一事实源

- 架构：`coding-agent-harness/context/architecture/Architecture-SSoT.md`
- 任务状态：当前任务 `progress.md`
- 技术判断：当前任务 `findings.md`
- 回归：`coding-agent-harness/governance/regression/Regression-SSoT.md`
- 回归触发：`coding-agent-harness/governance/regression/Cadence-Ledger.md`
- 生命周期总账：`coding-agent-harness/governance/generated/Harness-Ledger.md`
- 用户操作：根 `README.md`

## 完成标准

部署文件、脚本、Obsidian 结构和本机应用准备完成只是实现切片。只有资格、微信授权、Readeck 全文/高亮链路、Cloudflare 安全冒烟、72 小时/7 天观察、Obsidian 样本、备份恢复和对抗审查全部有证据后，整个任务才可完成。
