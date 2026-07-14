# 外部集成契约

## 微信公众平台

- 资格：必须拥有公众号/服务号运营权限。
- 操作：Chrome 扫码并选择运营账号。
- 风控：搜索/添加间隔 30–60 秒；出现 `200013` 时暂停。

## Tailscale Funnel

- 输入：本机 Caddy 8080。
- 输出：`https://<dns>/<FEED_PREFIX>/`。
- 首次启用需要 tailnet Owner/Admin 批准 HTTPS 与 Funnel。
- 回滚：`scripts/disable-funnel.sh`。

## Folo

- 云端抓取不能访问 localhost，必须使用 Funnel URL。
- v1 先免费测试聚合源和单源；72 小时通过后再启用 Basic Obsidian 集成。
- Folo 不提供本项目要求的持久手工划线/批注。
- `feedUrl` 视为 secret-adjacent。

## Obsidian/SummerOS

- Vault：`/Users/summer/Obsidian/SummerOS`。
- Inbox：`02_Archive/02_DailyProcessed/reading/folo_inbox`。
- Base 使用 `file.inFolder` + `file.hasTag("folo")`。
- 原文章不直接晋升；Knowledge/Output 使用衍生条目。
