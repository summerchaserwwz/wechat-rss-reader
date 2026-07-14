# 代码库地图

| Path | Responsibility |
| --- | --- |
| `compose.yaml` | 镜像、端口、环境、持久化、健康和日志 |
| `Caddyfile` | 公网只读 Atom 白名单 |
| `.env.example` | 非秘密配置示例 |
| `scripts/init-secrets.sh` | 不覆盖式密钥初始化 |
| `scripts/verify.sh` | 本机/公网硬门禁 |
| `scripts/backup.sh` | 一致性备份 |
| `scripts/restore-test.sh` | 独立恢复演练 |
| `scripts/configure-funnel.sh` | Funnel 与 RSS_BASE_URL 配置 |
| `scripts/record-observation.sh` | Folo 时间性观察记录 |
| `README.md`, `docs/` | 中文操作与验收 |
| `coding-agent-harness/` | 唯一工程主账本 |
