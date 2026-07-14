# WeRSS Folo Obsidian 阅读系统

## Task ID

`2026-07-14-werss-folo-obsidian-7118a818`

## 创建日期

2026-07-14

## 一句话结果

建立一个管理端仅本机可见、Atom 只读公网暴露、可在 Folo 筛选并把精选文章安全落入 SummerOS Archive 的公众号阅读系统。

## 完成后能得到什么

仓库提供固定镜像摘要的 Compose、Caddy 白名单、密钥初始化、安全验证、备份恢复、Funnel 配置和 Folo 观察脚本；本机安装 Docker/Folo，SummerOS 建立收件箱、Base 与批注模板。用户完成公众号运营者扫码、Funnel 首次批准和 Folo 时间门禁后，可在 Folo 干净浏览，在 Obsidian 高亮批注并创建 Knowledge/Output 衍生条目。

## 交付物

- 可见产物：根部署包、中文 README、验收文档、SummerOS reading 目录。
- 修改位置：`/Users/summer/Documents/wechat-rss`；SummerOS 新路径 `02_Archive/02_DailyProcessed/reading`。
- 验证证据：静态 gate、本机/公网 smoke、备份恢复、review、72 小时/7 天观察记录。

## 第一眼应该看什么

1. `task_plan.md`
2. `progress.md`
3. `findings.md`
4. 根 `README.md`
5. `governance/regression/Regression-SSoT.md`

## 边界

- 范围内：部署、安装准备、安全代理、运维脚本、Folo 试验流程、Obsidian 收件箱。
- 范围外：修改 WeRSS/Folo 源码、自动下载全部图片、Webhook、公开管理端、自动付费、绕过微信/Tailscale 权限。
- 停止条件：需要用户接受协议、扫码、登录/付费或等待时间性证据时暂停在对应门禁。

## 完成判断

- 本机 Compose/Atom/代理安全与恢复通过。
- 公众号运营者授权、3 个源与 36 周期有证据。
- Funnel 公网只有随机 Atom 路径可用。
- Folo 72 小时与 7 天稳定性通过或按规则降级。
- Obsidian 五类样本、同名保护和提升边界通过。

## 执行合同

- Owner：coordinator
- 生命周期状态：进行中
- 证据：必须进入 `progress.md`、`review.md` 和 Regression SSoT

## 当前下一步

完成 Docker Desktop 首次协议/权限门禁，启动容器并运行 `scripts/verify.sh --local`。
