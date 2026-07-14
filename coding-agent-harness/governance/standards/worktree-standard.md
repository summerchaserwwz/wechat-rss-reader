# Worktree 标准

- Coordinator 当前使用 `codex/wechat-rss-stack`。
- 仓库初始化时没有基线提交，无法先创建 linked worktree，因此当前分支作为隔离边界。
- 只读 reviewer 不需要 worktree。
- 任何可写 worker 必须使用独立 worktree/branch、限定 write scope、提交后 handoff。
- 已验证切片主动提交；不能提交时记录 no-commit reason。
