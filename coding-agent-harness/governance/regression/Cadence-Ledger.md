# 回归节奏总账 - WeChat RSS Stack

## 触发规则

| 改动范围 | 必跑 Gate | 条件 Gate | 触发说明 | 负责人 |
| --- | --- | --- | --- | --- |
| `scripts/*.sh`、`.env.example` | RG-001 | RG-002/004 | 脚本语法与真实运行 | coordinator |
| `compose.yaml`、镜像摘要、端口、网络 | RG-001, RG-002 | RG-003, RG-004 | 运行、出网、安全和数据兼容 | coordinator |
| `Caddyfile`、`FEED_PREFIX`、Funnel | RG-001, RG-002, RG-003 | none | 公网白名单与绕过检查 | coordinator + user |
| 微信抓取配置 | RG-002, RG-006 | RG-007 | 上游抓取决定下游可用性 | user |
| Folo 订阅/Basic | RG-007 | RG-008 | 先稳定再入库 | user |
| SummerOS reading 结构/Base | RG-001, RG-005 | RG-008 | Archive 边界和显示字段 | coordinator + user |
| 镜像升级 | RG-001, RG-002, RG-004, RG-006 | RG-003, RG-007 | 先备份、临时验证、再切换 | coordinator + user |

## 共享回归批次日志

| 批次 ID | 日期 | 范围 | 触发条件 | 执行 Gate | 结果 | 证据 | 残余路由 | 下一检查点 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SRB-001 | 2026-07-14 | 初始化实现切片 | 配置、脚本、Base 与 Harness 建立 | RG-001, RG-005 | pass-with-residual | task `progress.md`; reviewer reports | R-002..R-008 | Docker 首次启动后 SRB-002 |
