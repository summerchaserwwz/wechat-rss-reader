# 对抗性审查标准

涉及网络暴露、密钥、SQLite、恢复、外部 SaaS 或 SummerOS 写入时必须使用 `review.md`。

审查至少覆盖：

1. 公网是否可能绕过随机 Atom matcher。
2. 管理端、API、导出或非 GET/HEAD 方法是否暴露。
3. 镜像摘要和浏览器运行时是否匹配 ARM64。
4. `.env`、日志、备份和 Folo `feedUrl` 是否泄露秘密。
5. 备份是否一致，恢复是否不覆盖 live data。
6. Folo 与 Obsidian 的成功结论是否有真实外部证据。

P0/P1 必须修复；P2 必须修复或带 Owner/条件路由。没有开放重要发现后才能提交审查材料。
