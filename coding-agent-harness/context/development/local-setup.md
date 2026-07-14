# 本地启动

Context Doc Type: local-setup
Owner: coordinator
Source Evidence: local macOS/runtime; `README.md`; scripts
Last Verified: 2026-07-15
Confidence: high locally; Cloudflare pending live

| Task | Command | Expected Result |
| --- | --- | --- |
| 诊断 | `./scripts/doctor.sh` | 环境与人工资格清单 |
| 密钥 | `./scripts/init-secrets.sh` | `.env` 600，数据目录 700 |
| 启动 | `docker compose up -d` | WeRSS/Readeck healthy，Caddy running |
| Readeck 初始化 | `./scripts/init-readeck.sh` | 用户 `summer` 可登录 |
| 自动同步 | `./scripts/install-reading-sync.sh` | 每 5 分钟运行 |
| 本机验证 | `./scripts/verify.sh --local` | 回环端口、Feed、Readeck 303/401 |
| Cloudflare | `./scripts/configure-cloudflare-tunnel.sh` | 经用户授权创建 Tunnel/DNS |
| 公网验证 | `./scripts/verify.sh --reader-public` | HTTPS 登录跳转与匿名 API 401 |

## Required Local State

- Docker Desktop 首次协议与权限由用户完成。
- Chrome 用于微信首次授权。
- Cloudflare 持久账号授权和 DNS 变更需 action-time 用户确认。
- `.env`、API Token、Tunnel 凭据不进入 Git 或聊天。
