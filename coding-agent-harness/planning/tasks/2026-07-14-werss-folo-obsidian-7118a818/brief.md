# WeRSS Readeck Obsidian 阅读系统

## Task ID

`2026-07-14-werss-folo-obsidian-7118a818`（历史 ID 保留，主链路已从 Folo 切换到 Readeck）

## 一句话结果

建立本机自托管的公众号近实时阅读系统：WeRSS 抓取，自定义公众号阅读器与 Readeck 提供全文阅读/收藏/划线/批注，精选内容自动进入 SummerOS Archive，Cloudflare 提供受 Access 保护的 Reader 与 WeRSS 管理入口。

## 已实现

- 12 个公众号、124 篇 WeRSS 文章；118 篇去重后的完整文章已进入 Readeck。
- Readeck 0.22.3 原生 ARM64，只绑定 `127.0.0.1:8002`。
- 每 5 分钟自动同步；收藏或高亮文章进入 `readeck_inbox`。
- 真实样本验证高亮、批注、原文、人工笔记和不覆盖。
- WeRSS 调整为每小时第 17 分钟抓取。
- Reader 已完成全中文科技蓝磨砂三栏、Apple 磨砂交互控件、顶部 Tab、一键收藏、自动阅读进度、价值评分、主题标签和不改正文颜色的淡绿虚线高亮。
- 批注框会避让选区，保存后自动回到对应划线并显示原位笔记；“划线笔记”按条集中摘录、批注和来源，支持 Markdown 下载、可配置 Obsidian 目录与右侧字号持久化。
- Reader 主动刷新控制端已真实触发全部公众号抓取并继续同步阅读库；有 10 分钟冷却、single-flight、连续失败和微信风控保护。
- Reader 与 WeRSS 管理分别通过独立 Access 应用/AUD 接入同一 Tunnel；匿名访问均被拦截。
- 完整集成栈已发布到公开仓库 `summerchaserwwz/wechat-rss-reader`；默认 `main`、README/部署/安全文档与 GitHub CI 均已核验。

## 边界

- 微信没有 webhook，近实时而非秒级。
- WeRSS 原始端口永不公开；公网管理只通过 `werss.sumerchaser.top -> 127.0.0.1:8083`，并保留原生管理登录。
- Readeck 公网只通过 `reader.sumerchaser.top -> 127.0.0.1:8082`。
- 原文留在 Archive；Knowledge/Output 使用衍生条目。
- Folo/Tailscale 不再是完成依赖。

## 当前下一步

等待 72 小时/7 天真实观察完成，再执行最终对抗审查、walkthrough 和人工确认。
