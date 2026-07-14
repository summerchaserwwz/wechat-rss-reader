# 执行工作流标准

1. 恢复 Harness 与 Git 状态。
2. 对齐当前任务、人工门禁和停止条件。
3. 静态配置先验证，再安装/启动运行时。
4. 本机验证通过后才启用 Funnel。
5. RSS 自身更新通过后才判断 Folo 刷新。
6. 72 小时门禁通过后才启用 Folo Basic/Obsidian 集成。
7. 每个切片更新 `progress.md`、`findings.md` 和相关 Regression gate。
8. 提交只包含本仓任务文件；SummerOS 既有 dirty 不进入本仓提交。
9. 人工门禁或时间门禁未完成时记录 residual，不虚构结果。
