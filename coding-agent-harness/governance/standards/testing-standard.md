# 测试标准

## 证据层级

- L1：Shell/YAML/Caddy/Base/unittest 静态验证。
- L2：本机 Compose、Feed、Readeck 303/401、同步和独立恢复。
- L3：真实微信抓取、Readeck 高亮、Obsidian UI、Cloudflare 公网。

## 固定入口

```bash
bash -n scripts/*.sh
python3 -m unittest discover -s tests -v
docker compose config --quiet
./scripts/verify.sh --local
./scripts/verify.sh --reader-public  # Cloudflare 启用后
./scripts/backup.sh
./scripts/restore-test.sh
harness check --profile target-project .
```

## 规则

- 不输出完整 Compose 展开值或 WeRSS 原始日志。
- 本机测试覆盖四个回环端口、Atom 白名单和 Readeck 登录/API 边界。
- 公网测试必须确认 HTTPS 登录跳转、匿名 API 401、错误 Feed 404。
- Obsidian 必须验证真实高亮/批注、同名保护和人工区 hash 稳定。
- 恢复必须校验用户、文章、收藏、批注和同步状态。
