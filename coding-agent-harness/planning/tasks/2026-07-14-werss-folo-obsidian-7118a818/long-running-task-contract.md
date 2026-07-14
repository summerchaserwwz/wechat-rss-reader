# WeRSS Readeck Obsidian 阅读系统 - 长程任务合同

## 目标

完整建立并验证安全、可恢复、免费自托管的公众号阅读链路，或在真实人工/时间门禁处保留可恢复状态。

## 范围

- 本仓 Compose、WeRSS、Readeck、两个 Caddy、同步器、Cloudflare 脚本、备份恢复、文档和 Harness。
- SummerOS `02_Archive/02_DailyProcessed/reading` 新路径。
- 微信授权、Cloudflare 授权和 Obsidian UI 的人工协作。

范围外：修改上游源码、自动接受法律协议、自动公开 WeRSS、全量附件本地化、整理 SummerOS 无关 dirty 改动。

## 主调用入口

- Shell、Docker Compose、Chrome/WeRSS、Readeck Web、Cloudflare、Obsidian。
- 不依赖 Folo Basic、Tailscale Funnel 或外部 webhook。

## 执行授权

- Continuous execution：用户已授权实现原计划及开源替代方案。
- 外部持久权限：Cloudflare Tunnel/DNS 在 action-time 单独确认。
- reviewer：最终 L1 对抗审查。
- 人工确认：最终 Harness review confirmation 不得代办。

## 必需循环

1. 实现或配置。
2. 静态检查。
3. 本机/live smoke。
4. review -> fix -> rerun。
5. 更新 progress、findings、Regression。

## 证据

- [x] 微信运营授权、12 个源、94 篇文章。
- [x] Readeck 原生 ARM64、90 篇完整正文。
- [x] 收藏、高亮、批注和 Obsidian 真实样本。
- [x] 人工笔记不覆盖、幂等、同名保护单测与实测。
- [x] 每小时 Cron。
- [ ] Reader Cloudflare live smoke。
- [ ] Obsidian UI screenshot/Base 验证。
- [ ] 扩展真实备份恢复。
- [ ] 72 小时/7 天观察。
- [ ] final review/walkthrough。

## 完成条件

- RG-001..RG-008 通过，或未满足部分以用户明确接受的 residual 保留。
- open P0 为 0；P1 必须有 owner 和后续路由。
- 所有可自动执行证据完成；人工/时间 gate 不伪报。
- walkthrough、lesson decision 和人工确认按 Harness 合同完成。

## 暂停条件

- Cloudflare 登录/持久授权需要用户确认。
- Mac 锁屏阻止 UI 验证。
- 72 小时/7 天尚未到期。
- reviewer 发现改变方向的 P0/P1。

## 交付物

- 配置、脚本、Readeck 数据链、Obsidian 结构、图文教程。
- 本机和恢复证据。
- Cloudflare 公网证据（经用户授权后）。
- 最终 review、walkthrough、lesson 与 closeout。
