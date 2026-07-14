# Review Routing

- L0 self-review：所有改动。
- L1 subagent：非平凡任务默认，当前任务分别使用 Compose/Caddy 安全、运行时安装、Obsidian 契约 reviewer。
- L2 external reviewer：发布到公网、升级镜像或发生重大分歧时按需。
- L3 human：微信授权、Docker 协议、Cloudflare 持久授权/DNS、Obsidian UI 解锁和最终发布判断。

Reviewer 默认只读。若需改文件，必须升级为 worker、使用独立 worktree/branch 并交付 commit SHA。
