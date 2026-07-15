# WeRSS Readeck Obsidian 阅读系统

Task Contract: harness-task/v1

## 目标

把用户指定公众号持续抓取到免费开源阅读器，支持全文浏览、收藏、划线和批注，并把人工精选内容无缝、可恢复地同步进 Obsidian。

## 架构决策

原 Folo 方案因私密订阅和 Obsidian 集成需要付费，且不提供本项目要求的持久划线批注，已被以下链路取代：

```text
WeRSS -> Readeck -> reading-sync -> SummerOS Archive
                     |
                     +-> Cloudflare Tunnel（可选外网）
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

## 验收标准

- [x] 公众号运营者授权和 12 个来源完成。
- [x] 当前 95 篇完整正文进入 Readeck，容器原生 aarch64。
- [x] Readeck 收藏、高亮和批注真实可用。
- [x] 精选文章自动生成 Obsidian 原文笔记。
- [x] 人工笔记和人工字段经重复同步不覆盖。
- [x] WeRSS Cron 调整为 `17 * * * *`。
- [x] Reader Caddy 仅绑定 `127.0.0.1:8082`；本机匿名 API 为 `401`，公网 Host 缺 Access 身份为 `403`。
- [ ] Cloudflare Tunnel/DNS 通过用户授权并完成公网安全验收。
- [x] Obsidian UI 真实文章截图完成。
- [ ] Obsidian Base 列验证完成。
- [x] 扩展备份恢复真实通过，含 API Token、用户、95 篇文章、收藏、批注、Reader 主题和模拟 Access 身份映射。
- [x] 三次连续小时任务完整处理 12/12 个公众号，真实新增文章 2.16 分钟进入 Readeck且零重复。
- [ ] 72 小时/7 天近实时观察完成。
- [ ] 最终 review/walkthrough/人工确认完成。

## 工作树与所有权

- 仓库：`/Users/summer/Documents/wechat-rss`
- 分支：`codex/wechat-rss-stack`
- SummerOS：只修改 `02_Archive/02_DailyProcessed/reading` 新路径，不触碰大量既有 dirty 改动。
- 共享配置和 Harness 由 coordinator 串行维护。

## 人工/外部门禁

- Cloudflare 账号授权已完成；Zero Trust Free 激活仍需用户明确同意其未来超额用量收费授权。
- 72 小时/7 天证据必须真实等待，不能提前声称。

## 关联

- Architecture：`context/architecture/Architecture-SSoT.md`
- Regression：`governance/regression/Regression-SSoT.md`
- Review：`review.md`
