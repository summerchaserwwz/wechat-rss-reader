# 工程与架构标准

## 架构边界

- WeRSS 是唯一公众号抓取服务，只绑定 `127.0.0.1:8001`。
- Readeck 是全文阅读、收藏、高亮和批注服务，只绑定 `127.0.0.1:8002`。
- reading-sync 全量同步完整正文到 Readeck，默认只把收藏/高亮文章写入 Obsidian。
- Reader Caddy 只绑定 `127.0.0.1:8082`，是 Cloudflare 唯一 origin。
- Obsidian `readeck_inbox` 属于 Archive，不是 Knowledge。

## 数据与秘密

- `.env`、`data/`、`readeck-data/`、API Token、Tunnel 凭据和备份不进入 Git。
- Readeck API Token 只授予书签读写权限。
- WeRSS 容器日志可能包含环境变量，不进入公开 evidence。
- Tunnel 备份只包含作用域凭据，不包含高权限 Cloudflare `cert.pem`。

## 变更原则

- 镜像固定摘要，不使用 Watchtower/`latest`。
- 修改镜像、数据库、端口、Caddy、同步筛选或 Vault 路径必须更新 Regression 并做恢复验证。
- 人工笔记和人工 frontmatter 字段不可被同步器覆盖。
- 不增加公共 WeRSS 管理端、Webhook 或全量附件下载，除非另开任务。
