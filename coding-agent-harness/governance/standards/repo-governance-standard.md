# Repository Governance

- Platform：local Git；尚无远程。
- Default branch：`main`。
- Feature branch：`codex/<task-slug>`。
- Direct push to main：禁止；先在 feature branch 验证。
- Merge：用户决定；当前不自动推送或建 PR。
- Force push、hard reset、覆盖 `.env`：禁止。

## Required Checks

| Check | Command | Required |
| --- | --- | --- |
| Shell | `bash -n scripts/*.sh` | yes |
| Compose | `docker compose config --quiet` | yes |
| Harness | `harness check --profile target-project .` | yes |
| Local smoke | `./scripts/verify.sh --local` | 启动后 yes |
| Public smoke | `./scripts/verify.sh --reader-public` | Cloudflare 后 yes |

Branch protection：`blocked-with-owner`。仓库当前无 GitHub remote，Owner 为用户；若以后发布到 GitHub，再配置 PR、required checks、禁止 force push 与删除。
