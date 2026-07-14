# CI/CD 标准

- Platform：local-only。
- Runtime：Docker Compose + Bash。
- Install：人工完成 Docker Desktop 首次启动。
- Lint：`bash -n scripts/*.sh`。
- Config：`docker compose config --quiet`。
- Test/Smoke：`scripts/verify.sh`、`scripts/restore-test.sh`。
- CD：不适用；Tailscale Funnel 是人工批准后的本机发布入口。

当前没有远程仓库，GitHub Actions 与 required status checks 状态为 `blocked-with-owner`。Owner 为用户；建立远程后应新增 PR workflow，且不得在 CI 注入真实 `.env`、微信授权或 Feed 前缀。
