# 对抗性审查标准

涉及网络暴露、密钥、SQLite、恢复、Cloudflare 或 SummerOS 写入时必须使用 `review.md`。

审查至少覆盖：

1. WeRSS/Readeck/两个 Caddy 是否只绑定回环地址。
2. Cloudflare 是否只能到 Reader Caddy，匿名 API 是否保持 `401`。
3. 镜像摘要和实际运行架构是否一致；WeRSS 伪 ARM64 residual 不得隐藏。
4. `.env`、日志、API Token、备份和 Tunnel 凭据是否泄露。
5. 备份是否一致，恢复是否不覆盖 live data。
6. 收藏、高亮、批注、Obsidian 导入和人工区保护是否有真实证据。

P0/P1 必须修复或保留明确人工/时间门禁；P2 必须修复或带 Owner/条件路由。
