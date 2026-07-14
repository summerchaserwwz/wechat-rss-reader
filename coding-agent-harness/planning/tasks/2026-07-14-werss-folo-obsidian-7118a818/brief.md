# WeRSS Readeck Obsidian 阅读系统

## Task ID

`2026-07-14-werss-folo-obsidian-7118a818`（历史 ID 保留，主链路已从 Folo 切换到 Readeck）

## 一句话结果

建立本机自托管的公众号近实时阅读系统：WeRSS 抓取，Readeck 全文阅读/收藏/划线/批注，精选内容自动进入 SummerOS Archive，Cloudflare 提供可选外网登录入口。

## 已实现

- 12 个公众号、94 篇文章；90 篇完整正文已进入 Readeck。
- Readeck 0.22.3 原生 ARM64，只绑定 `127.0.0.1:8002`。
- 每 5 分钟自动同步；收藏或高亮文章进入 `readeck_inbox`。
- 真实样本验证高亮、批注、原文、人工笔记和不覆盖。
- WeRSS 调整为每小时第 17 分钟抓取。
- 独立 Reader Caddy、Cloudflare 配置脚本、扩展备份恢复和中文教程已实现或待最终验证。

## 边界

- 微信没有 webhook，近实时而非秒级。
- WeRSS 管理端永不公开。
- Readeck 公网只通过 `reader.sumerchaser.top -> 127.0.0.1:8082`。
- 原文留在 Archive；Knowledge/Output 使用衍生条目。
- Folo/Tailscale 不再是完成依赖。

## 当前下一步

用户解锁 Mac 后完成 Obsidian 实机截图；对 Cloudflare 账号持久授权进行 action-time 确认后创建 Tunnel/DNS；随后跑扩展备份恢复、全量回归与最终审查。
