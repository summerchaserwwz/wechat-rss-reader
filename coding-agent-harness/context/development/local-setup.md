# 本地启动

Context Doc Type: local-setup
Owner: coordinator
Source Evidence: local macOS/app inspection; `README.md`; scripts
Last Verified: 2026-07-14
Confidence: medium

| Task | Command | Expected Result |
| --- | --- | --- |
| 诊断 | `./scripts/doctor.sh` | 环境与人工资格清单 |
| 安装 App | `./scripts/install-macos-apps.sh` | Docker/Folo 复制到 `/Applications` |
| 密钥 | `./scripts/init-secrets.sh` | `.env` 600，数据目录 700 |
| 启动 | `docker compose pull && docker compose up -d` | WeRSS healthy、Caddy running |
| 本机验证 | `./scripts/verify.sh --local` | 管理端/Atom/安全边界通过 |
| Funnel | `./scripts/configure-funnel.sh` | 写入 HTTPS `RSS_BASE_URL` |
| 公网验证 | `./scripts/verify.sh --public` | 公网只读 Atom 通过 |

## Required Local State

- Docker Desktop 首次协议与权限由用户完成。
- Chrome 用于微信首次授权。
- Tailscale 首次 Funnel 由 tailnet Owner/Admin 批准。
- `.env` 不进入 Git，不从聊天复制真实值。
