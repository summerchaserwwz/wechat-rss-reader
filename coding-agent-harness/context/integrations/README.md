# 外部集成契约

Context Doc Type: integrations-index
Owner: coordinator
Last Verified: 2026-07-15
Confidence: high locally; Cloudflare live pending

## 微信公众平台

- 必须拥有公众号/服务号运营权限。
- Chrome 扫码选择运营账号。
- 搜索/添加间隔 30–60 秒；出现 `200013` 时暂停。
- 没有文章 webhook；当前 Cron `17 * * * *`，近实时而非秒级。

## Readeck

- 自托管版本 `0.22.3`，固定镜像摘要。
- 本机地址 `127.0.0.1:8002`，账号 `summer`。
- 负责完整文章库、收藏、阅读进度、高亮和批注。
- API Token 仅有书签读写权限，文件权限 `600`。
- 匿名首页跳转登录，匿名 `/api/bookmarks` 返回 `401`。

## Cloudflare Tunnel

- 独立 Tunnel 名 `wechat-rss`，不复用其他项目 Tunnel。
- DNS `reader.sumerchaser.top`。
- Origin 仅 `http://127.0.0.1:8082`，由专用 Caddy 转发 Readeck。
- 本机 config 与 Tunnel 作用域凭据权限 `600`；账户 `cert.pem` 不进入项目备份。
- 回滚只停止 LaunchAgent，不自动删除 DNS/Tunnel。

## Obsidian/SummerOS

- Vault：`/Users/summer/Obsidian/SummerOS`。
- Inbox：`02_Archive/02_DailyProcessed/reading/readeck_inbox`。
- Base 过滤该目录。
- 高亮映射为 `==...==`；批注同时写入摘录区和原文脚注。
- 人工字段与“我的笔记”不可覆盖。
- 原文不直接晋升；Knowledge/Output 创建衍生条目。

## Folo/Tailscale

- 已退出主链路。
- Folo 可选使用，但付费集成不是完成条件。
- Tailscale Funnel 脚本保留作兼容 RSS 实验，不参与 Readeck 公网阅读。
