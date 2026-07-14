# 工程与架构标准

## 架构边界

- WeRSS 是唯一公众号抓取与 Atom 生成服务。
- Caddy 只做路径白名单与前缀剥离，不承载认证、管理 UI 或内容转换。
- Tailscale Funnel 只把本机 Caddy 端口发布为 HTTPS。
- Folo 是外部云抓取与阅读客户端，不是系统事实源。
- Obsidian `folo_inbox` 是 Archive processed source inbox，不是 Knowledge。

## 数据与秘密

- SQLite、授权文件、Redis 持久化和自动生成的 `.secret_key` 全部位于 `data/`。
- `SAFE_LIC_KEY` 与授权文件必须一起备份并长期稳定。
- `.env` 与 `data/` 不进入 Git、公开日志或公开笔记。
- Feed 前缀泄露时必须轮换并重新订阅 Folo。

## 变更原则

- 优先最小配置与上游真实环境变量名。
- 修改镜像摘要、数据库路径、Caddy matcher、授权键或 Vault 目录属于高风险变更，必须更新 Regression SSoT 并做恢复验证。
- 不增加自动更新器、公共管理端、Webhook 或自动图片下载，除非另开任务。
