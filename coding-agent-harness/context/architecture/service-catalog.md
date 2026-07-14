# 服务目录

| Service | Owner | Runtime | Network | Persistent Data | Health/Verification |
| --- | --- | --- | --- | --- | --- |
| WeRSS | upstream + local operator | pinned Docker ARM64 | host `127.0.0.1:8001`; Docker internet + feed-proxy | `data/` | built-in healthcheck; `verify.sh` |
| Caddy | local operator | pinned Docker ARM64 | host `127.0.0.1:8080`; internal feed-proxy | none | `caddy validate`; proxy smoke |
| Tailscale Funnel | user/tailnet | macOS app 1.98.5 | public HTTPS to 8080 | tailnet config | `funnel status --json`; public smoke |
| Folo | Folo service/user | macOS/iOS/cloud | public Feed fetch | Folo account | 72h/7d observation |
| Obsidian/SummerOS | user | Obsidian 1.12.7 | local files | Vault | Base YAML + five export samples |
