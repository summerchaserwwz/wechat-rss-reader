# Visual Map / 可视化图谱

Visual Map Contract: v1.0

## 阶段关系图

```mermaid
flowchart LR
  I["INIT Harness"] --> W["WeRSS 授权/12源"]
  W --> R["Readeck 全文库"]
  R --> O["收藏/高亮 -> Obsidian"]
  O --> C["Reader Caddy"]
  C --> CF["Cloudflare Access 金融授权"]
  CF --> B["备份恢复/全量验证"]
  B --> V["Agent 审查"]
  V --> H["人工确认"]
```

## 阶段表

| Phase ID | Kind | Depends On | State | Completion | Output | Required Evidence | Exit Command | Actor | Evidence Status | Blocking Risk | Owner / Handoff |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- |
| INIT-01 | init | none | done | 100 | Harness task files | status/check | n/a | agent | present | none | coordinator |
| WERSS-01 | execution | INIT-01 | in_progress | 88 | 12 源、99 篇、每小时 Cron | SQLite、任务队列、72h/7d | n/a | coordinator | partial | 时间证据 | user + coordinator |
| READECK-01 | execution | WERSS-01 | done | 100 | 95 loaded、aarch64、中文阅读 UI | API/SQLite/UI | n/a | agent | present | 4 篇正文未达导入条件 | coordinator |
| OBSIDIAN-01 | execution | READECK-01 | in_progress | 96 | 收藏/高亮/批注/不覆盖 | 真实笔记、hash、UI screenshot、Base | n/a | agent | partial | Base 列验证 | user + coordinator |
| CLOUDFLARE-01 | gate | OBSIDIAN-01 | in_progress | 55 | Access fail-closed Reader 与 Tunnel 脚本 | 403/Access OTP/Tunnel/DNS/公网 smoke | n/a | coordinator | partial | Zero Trust 金融授权 | user + coordinator |
| RECOVERY-01 | execution | READECK-01 | done | 100 | 扩展备份恢复 | 三 SQLite、主题、用户/文章/收藏/批注 | n/a | agent | present | none | coordinator |
| REVIEW-01 | gate | CLOUDFLARE-01,RECOVERY-01 | planned | 0 | Agent Review Submission | tests、diff、live evidence、review.md | harness task-review | agent | partial | live gate | coordinator |
| HUMAN-01 | gate | REVIEW-01 | planned | 0 | Human Review Confirmation | review packet | Dashboard human confirmation | human | missing | agent 不得代办 | user |

## 数据流

```mermaid
flowchart LR
  WX["公众号原文"] --> W["WeRSS"] --> R["Readeck 全文库"]
  R --> H["收藏 / 高亮 / 批注"] --> O["Archive readeck_inbox"]
  O --> K["Knowledge 综合条目"]
  O --> OUT["Output 脱敏草稿"]
```
