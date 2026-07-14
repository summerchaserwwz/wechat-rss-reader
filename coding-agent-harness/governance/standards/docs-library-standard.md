# 文档库标准

- 用户操作放根 `README.md` 和 `docs/`。
- Agent 上下文放 `coding-agent-harness/context/`。
- 任务事实放当前 task package。
- 长命令输出只放 task `artifacts/`，且必须脱敏。
- 不在文档中写 `.env` 值、随机 Feed URL、微信授权材料或完整容器日志。
- SummerOS 文章说明放 `02_Archive/02_DailyProcessed/reading/`，不复制本仓 Harness 文档。
