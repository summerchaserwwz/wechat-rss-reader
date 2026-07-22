# WeRSS Readeck Obsidian 阅读系统

## Task ID

`2026-07-14-werss-folo-obsidian-7118a818`（历史 ID 保留，主链路已从 Folo 切换到 Readeck）

## 一句话结果

建立本机自托管的公众号近实时阅读系统：WeRSS 抓取，自定义公众号阅读器与 Readeck 提供全文阅读/收藏/划线/批注，精选内容自动进入 SummerOS Archive，Cloudflare 提供受 Access 保护的 Reader 与 WeRSS 管理入口。

## 已实现

- 15 个公众号；完整正文会由 Cloudflare 驱动的 WeRSS/Reader 链路持续入库，最新 live 验证已新增正文并进入 Reader。
- Readeck 0.22.3 原生 ARM64，只绑定 `127.0.0.1:8002`。
- 同步助手的文章外链与 140 条微信消息已进入 Reader；收藏或高亮文章进入 `readeck_inbox`。
- 真实样本验证高亮、批注、原文、人工笔记和不覆盖。
- Cloudflare 免费 Cron Trigger 每小时第 17 分钟触发 WeRSS 抓取、每 5 分钟同步 Reader；WeRSS 原生 Cron 已停放，仍保留受保护的手工触发能力。
- Reader 已完成全中文科技蓝磨砂三栏、Apple 磨砂交互控件、顶部 Tab、一键收藏、自动阅读进度、价值评分、主题标签和不改正文颜色的淡绿虚线高亮。
- Reader 正文滚轮与键盘滚动已修复；初始时间线按 60 篇渐进加载并预取正文，公众号栏可收起，全屏阅读可隐藏两栏和顶部导航并进入浏览器全屏。
- 拖选正文后立即显示淡绿划线预览与磨砂笔记框；空笔记 Enter 保存纯划线，输入后 Enter 保存笔记，Shift+Enter 换行；越界或近整篇误选会被拒绝。保存后自动回到对应划线并显示原位笔记；“划线笔记”按条集中摘录、批注和来源，支持 Markdown 下载、可配置 Obsidian 目录与右侧字号持久化。
- Reader 主动刷新控制端已真实触发全部公众号抓取并继续同步阅读库；有 10 分钟冷却、single-flight 和自动重试；微信授权失效时网页刷新会直接弹出二维码，扫码后继续抓取。
- Cloudflare 免费 Cron Trigger、Workflow、Access Service Token、Service Auth policy、Worker secrets 与 live schedule 已完成；真实 `start` Workflow 完成轮询并新增正文，两个本机 Cron 已切换出调度权。
- Reader 与 WeRSS 管理分别通过独立 Access 应用/AUD 接入同一 Tunnel；匿名访问均被拦截。
- 完整集成栈已发布到公开仓库 `summerchaserwwz/wechat-rss-reader`；默认 `main`、README/部署/安全文档与 GitHub CI 均已核验。

## 边界

- 微信没有 webhook，近实时而非秒级。
- WeRSS 原始端口永不公开；公网管理只通过 `werss.sumerchaser.top -> 127.0.0.1:8083`，并保留原生管理登录。
- Readeck 公网只通过 `reader.sumerchaser.top -> 127.0.0.1:8082`。
- 原文留在 Archive；Knowledge/Output 使用衍生条目。
- Folo/Tailscale 不再是完成依赖。

## 当前下一步

等待 72 小时/7 天真实观察，执行最终对抗审查、walkthrough 和人工确认。
