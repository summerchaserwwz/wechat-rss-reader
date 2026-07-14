# 系统图谱

Context Doc Type: system-map
Owner: coordinator
Source Evidence: `compose.yaml`; `Caddyfile`; `README.md`; SummerOS reading files
Last Verified: 2026-07-14
Confidence: high

## Scope

图谱覆盖从公众号运营者授权到 SummerOS 知识提升的完整边界；Folo 与 Tailscale 是外部服务，Obsidian Vault 是独立 dirty 仓库。

```mermaid
flowchart LR
  WX["微信公众平台\n运营者授权"] --> W["WeRSS\n127.0.0.1:8001"]
  W --> DB["data/\nSQLite + 授权 + Redis"]
  W --> C["Caddy\n127.0.0.1:8080"]
  C --> T["Tailscale Funnel\nHTTPS"]
  T --> F["Folo 云端抓取"]
  F --> FC["Folo 桌面/移动端\n浏览与筛选"]
  FC --> O["SummerOS Archive\nfolo_inbox"]
  O --> K["Knowledge 综合条目"]
  O --> OUT["Output 脱敏草稿"]
```

## Trust Boundaries

- `.env`、`data/`、备份：本机 secret-bearing。
- 随机 Feed URL：可公网读取的 bearer-secret URL。
- Folo：外部云服务，会持有 Feed URL。
- Obsidian 原文：私有 Archive；公开前删除 `feedUrl` 并遵守版权边界。
