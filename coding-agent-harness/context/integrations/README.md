# 外部集成契约

Context Doc Type: integrations-index
Owner: coordinator
Last Verified: 2026-07-16
Confidence: high locally and on live Cloudflare

## 微信公众平台

- 必须拥有公众号/服务号运营权限。
- Chrome 扫码选择运营账号。
- 搜索/添加间隔 30–60 秒；出现 `200013` 时暂停。
- 没有文章 webhook；当前 Cron `17 * * * *`，近实时而非秒级。
- WeRSS 原始端口只在 `127.0.0.1:8001`；公网管理使用 `werss.sumerchaser.top` 的专用 Caddy 与独立 Cloudflare Access 应用/AUD。
- Reader 主动刷新通过受保护控制端调用 WeRSS Access Key API，不写 WeRSS SQLite，不暴露 Docker socket。

## Readeck

- 自托管版本 `0.22.3`，固定镜像摘要。
- 本机地址 `127.0.0.1:8002`，账号 `summer`。
- 负责完整文章库、收藏、阅读进度、高亮和批注。
- API Token 仅有书签读写权限，文件权限 `600`。
- 匿名首页跳转登录，匿名 `/api/bookmarks` 返回 `401`。
- 日常公网阅读不使用本机账号密码；Access 身份只映射到固定 `summer` 用户，不转发外部管理员组。
- Reader 顶部“检查新文章”有 10 分钟冷却、single-flight、连续两次失败暂停和 `200013` 停止保护；WeRSS 完成后才运行 reading-sync。

## Cloudflare Tunnel

- 独立 Tunnel 名 `wechat-rss`，不复用其他项目 Tunnel。
- DNS 为 `reader.sumerchaser.top` 与 `werss.sumerchaser.top`。
- Reader origin 为 `http://127.0.0.1:8082`；WeRSS 管理 origin 为 `http://127.0.0.1:8083`，两者均由专用 Caddy 转发。
- 必须先建 Access self-hosted application，再建 Tunnel/DNS；策略只允许精确邮箱并使用 OTP，禁止 `Include Everyone` 或仅凭 `Login Methods: OTP` 放行。
- 本地 Tunnel 的两个 ingress 都必须启用 `originRequest.access.required`，同时包含 team name 与各自 application AUD；`cloudflared` 先验证 JWT，Caddy 再要求 JWT header 与精确邮箱一致。
- `CF_ACCESS_READY=false` 或 `CF_WERSS_ACCESS_READY=false` 时配置脚本在任何 Tunnel/DNS 写操作前失败关闭；禁止 URL Token、静态一年 Cookie 或前端硬编码凭据。
- 本机 config 与 Tunnel 作用域凭据权限 `600`；账户 `cert.pem` 不进入项目备份。
- 回滚只停止 LaunchAgent，不自动删除 DNS/Tunnel。
- 当前 live：Reader 与 WeRSS 管理分别使用 Access 精确邮箱 + OTP + 一周会话和独立 AUD；已授权设备无需 Readeck 密码，WeRSS 仍保留原生管理登录；未授权 Reader/API/Feed/WeRSS 均被边缘拦截；Tunnel 有活动连接。

## Obsidian/SummerOS

- Vault：`/Users/summer/Obsidian/SummerOS`。
- Inbox：`02_Archive/02_DailyProcessed/reading/readeck_inbox`。
- Base 过滤该目录。
- 高亮映射为 `==...==`；批注同时写入摘录区和原文脚注。
- 人工字段与“我的笔记”不可覆盖。
- 原文不直接晋升；Knowledge/Output 创建衍生条目。
- 后台 `reading-sync` 每 5 分钟把收藏或含高亮/批注的文章逐篇写入固定 Archive Inbox；这是权威自动入库路径。
- Reader 的“划线笔记”另提供浏览器侧汇总 Markdown：可以下载，也可以通过 File System Access API 选择一个本机 Obsidian 目录直接写入。目录授权只保存在当前浏览器，可随时重选；浏览器不接收 Readeck API Token。

## Folo/Tailscale

- 已退出主链路。
- Folo 可选使用，但付费集成不是完成条件。
- Tailscale Funnel 脚本保留作兼容 RSS 实验，不参与 Readeck 公网阅读。
