# 回归节奏总账 - WeChat RSS Stack

## 触发规则

| 改动范围 | 必跑 Gate | 条件 Gate | 负责人 |
| --- | --- | --- | --- |
| `scripts/*.sh`、`.env.example` | RG-001 | RG-002/004 | coordinator |
| Compose、镜像、端口、网络 | RG-001, RG-002 | RG-003, RG-004 | coordinator |
| `Caddyfile.reader`、Cloudflare | RG-001, RG-002, RG-003 | RG-004 | coordinator + user |
| 微信抓取/Cron | RG-002, RG-006 | RG-007 | user + coordinator |
| Readeck API/同步器 | RG-001, RG-007, RG-008 | RG-004 | coordinator |
| SummerOS reading/Base | RG-001, RG-005, RG-008 | none | coordinator + user |
| 镜像升级 | RG-001, RG-002, RG-004, RG-006, RG-007 | RG-003 | coordinator + user |

## 批次日志

| 批次 ID | 日期 | 范围 | 结果 | 残余 |
| --- | --- | --- | --- | --- |
| SRB-001 | 2026-07-14 | 初始 WeRSS/Folo 方案 | superseded | Folo 付费与批注缺口 |
| SRB-002 | 2026-07-15 | Readeck 主链路、同步器、Reader Caddy | in progress | Cloudflare/UI/恢复 final gate |
