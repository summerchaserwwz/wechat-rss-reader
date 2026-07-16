# WeRSS Readeck Obsidian 阅读系统

Task Contract: harness-task/v1

## 目标

把用户指定公众号持续抓取到免费开源阅读器，支持全文浏览、收藏、划线和批注，并把人工精选内容无缝、可恢复地同步进 Obsidian。

## 架构决策

原 Folo 方案因私密订阅和 Obsidian 集成需要付费，且不提供本项目要求的持久划线批注，已被以下链路取代：

```text
WeRSS -> Readeck -> reading-sync -> SummerOS Archive
                     |
                     +-> Cloudflare Access + Tunnel（已启用外网）
```

## 步骤

1. 保留 WeRSS 运营者授权和 12 个公众号，定时任务调整为每小时。
2. 部署固定摘要 Readeck，建立中文账号和最小权限 API Token。
3. 全量同步完整正文到 Readeck，默认只导出收藏/高亮文章到 Obsidian。
4. 验证高亮、批注、原文脚注、日期命名、同名保护和人工区不覆盖。
5. 建立 Readeck 专用 Caddy 和 Cloudflare Tunnel 配置。
6. 扩展备份/恢复，覆盖 WeRSS、Readeck、API Token、同步状态和可选 Tunnel 凭据。
7. 更新架构、回归、中文图文教程和 SummerOS 操作说明。
8. 完成本机、公网、恢复、UI 和对抗审查。
9. 为 Reader 增加受保护主动刷新，并把 WeRSS 管理端通过独立 Cloudflare Access 应用发布到专用域名。
10. 修复划线文字变黑和批注遮挡，加入 Apple 磨砂批注、原位笔记、划线笔记区、字号调节、自动阅读进度和 Markdown/可选 Obsidian 目录导出。
11. 泛化个人域名、账号、Vault 与 LaunchAgent 路径，补齐公开部署文档、安全策略、CI 和账号/Token 工具，并发布到 GitHub。

## 验收标准

- [x] 公众号运营者授权和 12 个来源完成。
- [x] 当前 118 篇去重后达到正文门槛的文章全部且唯一进入 Readeck，容器原生 aarch64。
- [x] Readeck 收藏、高亮和批注真实可用。
- [x] 精选文章自动生成 Obsidian 原文笔记。
- [x] 人工笔记和人工字段经重复同步不覆盖。
- [x] WeRSS Cron 调整为 `17 * * * *`。
- [x] Reader Caddy 仅绑定 `127.0.0.1:8082`；本机匿名 API 为 `401`，公网 Host 缺 Access 身份为 `403`。
- [x] Cloudflare Access/Tunnel/DNS 通过用户授权并完成公网安全验收。
- [x] Obsidian UI 真实文章截图完成。
- [x] Obsidian Base 九列实机验证完成。
- [x] 扩展备份恢复真实通过，含 API Token、用户、101 篇文章、收藏、批注、Reader 主题、Tunnel 作用域凭据和 Access 身份映射。
- [x] 三次连续小时任务完整处理 12/12 个公众号，真实新增文章 2.16 分钟进入 Readeck且零重复。
- [x] Reader UI 为全中文科技蓝磨砂三栏，顶部 6 个 Tab、行内收藏、已读/未读、价值评分、主题标签与淡绿虚线高亮实机可用。
- [x] 划线保持正文颜色；批注框避让选区；保存后自动定位并显示原位笔记；划线笔记区、Markdown 下载、可选 Obsidian 目录、字号持久化和 390px 移动端均经真实浏览器验证。
- [x] 本机账号迁移通过；公开模板不含实际密码/Token/数据库；本机与模板 Compose、README 链接、秘密扫描、最终备份恢复通过；GitHub 公开仓库已创建。
- [x] “检查新文章”真实触发 12 个公众号抓取并完成 reading-sync；10 分钟冷却、single-flight、连续失败暂停和 `200013` 保护均有测试。
- [x] `werss.sumerchaser.top` 使用独立 Access 应用/AUD 指向 `127.0.0.1:8083`；匿名根/API 被拦截，授权 Chrome 到达 WeRSS 原生登录页，现有 Reader ingress 无回归。
- [ ] 72 小时/7 天近实时观察完成。
- [ ] 最终 review/walkthrough/人工确认完成。

## 工作树与所有权

- 仓库：`/Users/summer/Documents/wechat-rss`
- 分支：`codex/wechat-rss-stack`
- SummerOS：只修改 `02_Archive/02_DailyProcessed/reading` 新路径，不触碰大量既有 dirty 改动。
- 共享配置和 Harness 由 coordinator 串行维护。

## 人工/外部门禁

- Cloudflare Zero Trust、Access、Tunnel 与 DNS 已由用户明确授权并完成。
- 72 小时/7 天证据必须真实等待，不能提前声称。

## 关联

- Architecture：`context/architecture/Architecture-SSoT.md`
- Regression：`governance/regression/Regression-SSoT.md`
- Review：`review.md`
