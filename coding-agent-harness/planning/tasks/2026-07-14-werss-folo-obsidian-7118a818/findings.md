# WeRSS Folo Obsidian 阅读系统 - 发现记录

## 研究发现

### 固定 WeRSS 镜像与 Firefox 不兼容

- 背景：用户计划锁定 `BROWSER_TYPE=firefox`。
- 发现：固定摘要包含 ARM64，但镜像构建只安装并通过环境脚本固定 WebKit；运行时 Firefox 会被覆盖或缺少浏览器二进制。
- 影响：实现改为 `BROWSER_TYPE=webkit`，README 显式记录偏差。
- 证据：GHCR OCI index、镜像 config、上游 `environment.sh`/Playwright 初始化、Compose reviewer。

### WeRSS 会打印环境变量

- 发现：上游 `main.py` 启动时遍历并打印全部环境变量。
- 影响：Compose 不使用全量 `env_file`，只显式注入必要值；不把容器日志写入公开 evidence。`SECRET_KEY` 由镜像生成并持久化到 `data/.secret_key`，少暴露一个秘密。

### Tailscale 已登录但处于 Stopped

- 发现：1.98.5 已有节点、Owner/Admin capability 与 MagicDNS；`BackendState=Stopped`，Funnel 未配置。
- 影响：不再描述为“未登录”；需要用户从菜单栏连接，首次 Funnel 网页批准后脚本才能继续。

### Folo 安装与能力

- 发现：2026-07-13 最新稳定桌面版为 `1.11.0`，有官方 ARM64 DMG 与 SHA512；Obsidian 集成需要桌面版/Basic。Folo 不是持久批注工具。
- 影响：先免费 72 小时/7 天观察，再决定 Basic；批注留在 Obsidian。

### Obsidian Base 与 Folo 字段

- 发现：Obsidian 1.12.7 支持 `file.inFolder`、`file.hasTag`、`properties.displayName`、`views.order/sort`；Folo 导出包含 `tags: [folo]`、`feedTitle`、`feedUrl`、`publishedAt`。
- 影响：Base 可稳定过滤 Inbox + `folo` 标签；批注模板不能插入第二份 frontmatter。

### SummerOS 仓库 dirty

- 发现：Vault 有大量既有改动和未跟踪治理文件。
- 影响：本任务只新增 `02_Archive/02_DailyProcessed/reading`，不修改/提交其他 SummerOS 文件；来源注册表更新延后到 Folo 真正启用后。

## 技术决策

| 决策 | 选择 | 原因 | 替代方案 | 状态 |
| --- | --- | --- | --- | --- |
| WeRSS 浏览器 | WebKit | 与固定镜像实际能力一致 | Firefox（当前不可用） | accepted |
| 公网边界 | Caddy `.atom` matcher + 随机前缀 + Funnel | 最小暴露面 | 公开 WeRSS / VPN-only | accepted |
| 网络 | Caddy 内部 feed-proxy；WeRSS 额外 internet | Caddy 无需出网，WeRSS 需访问微信 | 单一 bridge | accepted |
| SECRET_KEY | 由 WeRSS 生成到 `data/.secret_key` | 减少日志中的环境秘密 | 注入 `.env` | accepted |
| 入库 | Folo Basic Obsidian 集成为主，Clipper 备用 | 不依赖未执行的 `EXPORT_MARKDOWN` | WeRSS 自动导出 | accepted |
| Vault 层级 | Archive processed source inbox | 符合 SummerOS 晋升链路 | 直接 Knowledge | accepted |
| 图片 | v1 不自动本地化 | 避免附件污染 | 全量下载 | accepted |

## 待确认问题

| 问题 | 当前判断 | Owner | 截止点 |
| --- | --- | --- | --- |
| 是否拥有公众号运营权限？ | 硬门禁，尚未由用户确认 | user | 微信扫码前 |
| Docker 协议/权限是否完成？ | App 安装后需用户操作 | user | 本机 smoke 前 |
| Funnel 首次批准是否完成？ | 尚未 | user | 公网 smoke 前 |
| Folo 是否稳定？ | 需 72 小时和 7 天 | user | Basic 购买前 |
