# WeRSS Folo Obsidian 阅读系统 - 长程任务合同

## 目标

完整建立并验证安全、可恢复的公众号阅读链路，或在真实人工/时间门禁处保留可恢复状态。

## 范围

### 范围内

- 本仓部署、脚本、文档、Harness。
- `/Users/summer/Obsidian/SummerOS/02_Archive/02_DailyProcessed/reading` 新路径。
- Docker/Folo App 安装准备与 Tailscale/微信/Folo 用户门禁协作。

### 范围外

- 自动接受法律协议、代办账号登录/付费。
- 修改上游源码、自动公开管理端、Webhook、全量附件下载。
- 处理 SummerOS 既有大量 dirty 状态。

### 共享文件 / 冲突风险

- 本仓共享配置由 coordinator 独占。
- SummerOS 只新增 reading 路径；不提交或整理其他 dirty 文件。

## 主调用入口

- 主调用方：本机用户 + coordinator。
- 必须支持：Shell、Docker Compose、Chrome/WeRSS UI、Tailscale CLI、Folo UI、Obsidian UI。
- 不要求：公网管理 UI、自动化付费、外部 Webhook。

## 执行授权

- Continuous execution：allowed within requested plan。
- 每轮后直接继续：yes，直到人工/时间/高风险门禁。
- reviewer subagent：yes，read-only。
- 审查报告：yes，`review.md`。
- 仍需人工批准：Docker 协议/权限、微信扫码、Tailscale 首次 Funnel、Folo 登录/付费、人工 review confirmation。

## 必需循环

1. 实现或配置。
2. 静态检查。
3. 可用时运行本机/live smoke。
4. Confidence Challenge。
5. 吸收 reviewer finding。
6. 重跑证据。
7. 更新 progress、findings、Regression。

最低要求：实现期 reviewer 无开放重要 finding；live gate 逐个有真实证据。

## 审查者合同

- 角色：只读安全/运行时/Obsidian reviewer。
- 范围：任务文件、官方来源与本机只读状态。
- 必须报告：缺陷、回归、缺失验证、未验证假设、material/no-finding。
- 不得：改文件、扩大 scope、公开秘密。

## 证据

- [x] Shell/YAML/Base 静态检查。
- [x] 镜像摘要 ARM64 核验。
- [x] reviewer 实现设计无开放重要发现。
- [ ] Docker 本机 smoke。
- [ ] Funnel live smoke。
- [ ] 微信 3 源/36 周期。
- [ ] Folo 72 小时/7 天。
- [ ] Obsidian 五类样本与同名保护。
- [ ] 真实备份恢复。
- [ ] final review/walkthrough。

## 完成条件

- [ ] RG-001..RG-008 满足通过或按用户确认的降级方案关闭。
- [ ] open P0/P1 为 0。
- [ ] 所有人工/时间 gate 有真实 evidence。
- [ ] walkthrough、lesson decision、Harness closeout 完成。

## 暂停条件

- [x] 人工协议、登录、扫码、批准或时间门禁出现时可暂停。
- [ ] 目标/范围失效。
- [ ] 无关 dirty 与目标路径冲突。
- [ ] reviewer 发现改变方向的问题。

## 交付物

- [x] 配置、脚本、文档和 Obsidian 结构。
- [x] L1 evidence 和 reviewer 结论。
- [ ] L2/L3 运行证据。
- [ ] 最终 review、walkthrough、lesson 与 closeout。
