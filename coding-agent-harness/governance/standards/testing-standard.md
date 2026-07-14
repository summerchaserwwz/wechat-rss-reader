# 测试标准

## 证据层级

- L1：Shell/YAML/Caddy/Base 静态验证。
- L2：本机 Docker Compose、管理端、Atom、代理安全和恢复实例冒烟。
- L3：真实 Tailscale Funnel、微信抓取、Folo 云端刷新和 Obsidian 导出。

## 固定入口

```bash
bash -n scripts/*.sh
docker compose config --quiet
./scripts/verify.sh --local
./scripts/verify.sh --public
./scripts/backup.sh
./scripts/restore-test.sh
harness check --profile target-project .
```

## 规则

- 不用 `docker compose config` 无参数输出，避免展开秘密。
- 不把 `docker compose logs` 原文写入 evidence。
- 公网测试必须覆盖根路径、API、POST、合法 Atom 和 dot-segment。
- Folo 成功以“无需重新订阅出现新文章”为准，不能只证明 Feed URL 可添加。
- Obsidian 必须覆盖五类样本和同名保护。
