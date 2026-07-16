# Security Policy

这套系统处理微信授权、私人订阅、完整文章、阅读记录和 Obsidian 笔记，默认按私人系统设计。

## 永远不要提交

- `.env`
- `data/`、`readeck-data/`、`sync-state/`
- `backups/`、`observations/`
- Readeck API Token、WeRSS Access Key
- Cloudflare AUD、Tunnel 凭据、账户 `cert.pem`
- Feed 随机前缀、微信授权文件、数据库和容器日志

仓库的 `.gitignore` 已覆盖这些路径，但推送前仍应运行秘密扫描。

## 公网边界

- WeRSS、Readeck、三个 Caddy 和刷新控制端都只绑定 `127.0.0.1`。
- 公网只能通过 Cloudflare Access + Tunnel。
- Reader 与 WeRSS 管理使用不同 Access Application 和 AUD。
- 只允许精确邮箱；不要使用 `Include Everyone`。
- 浏览器不接收 Readeck API Token 或 WeRSS Access Key。

## 密码

公开部署应使用至少 24 位随机密码。即使外层有 Cloudflare Access，也不要把示例密码、个人密码或弱密码写进 Compose、README、截图或 Git 历史。

## 日志

WeRSS 上游当前可能把环境变量打印进容器日志。不要公开 `docker compose logs we-mp-rss` 的原始内容，也不要把它附到 Issue。

## 报告问题

安全问题请不要附带真实 Token、Cookie、数据库、授权二维码或文章内容。优先提供脱敏后的复现步骤和受影响版本。
