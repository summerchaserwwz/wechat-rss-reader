# Delivery Operating Model

- Model：`solo-orchestrator`
- Team shape：一名用户 + 一个 coordinator + 只读 reviewer subagents
- Repo topology：单仓部署包，外接本机 SummerOS Vault
- Planning owner：coordinator
- Integration owner：coordinator
- Release owner：用户
- Agent visibility：本仓全量；SummerOS 只允许本任务新建路径和只读治理上下文

任务由用户目标和 Harness task package 定义。共享文件由 coordinator 串行修改。当前不需要 Delivery SSoT；若未来多人或多仓并行，再升级 operating model。
