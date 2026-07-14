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
- 运行时确认：未登录的新安装会展示 `AI`、`Developer`、`Games`、`News`、`Podcasts`、`Science` 等英文示例目录和公开 Feed；它们不是用户订阅，也不是 WeRSS 生成。Folo 导航与登录流程已随系统显示中文，英文标题来自示例 Feed 内容。

### Obsidian Base 与 Folo 字段

- 发现：Obsidian 1.12.7 支持 `file.inFolder`、`file.hasTag`、`properties.displayName`、`views.order/sort`；Folo 导出包含 `tags: [folo]`、`feedTitle`、`feedUrl`、`publishedAt`。
- 影响：Base 可稳定过滤 Inbox + `folo` 标签；批注模板不能插入第二份 frontmatter。

### SummerOS 仓库 dirty

- 发现：Vault 有大量既有改动和未跟踪治理文件。
- 影响：本任务只新增 `02_Archive/02_DailyProcessed/reading`，不修改/提交其他 SummerOS 文件；来源注册表更新延后到 Folo 真正启用后。

### 上游 ARM64 manifest 实际包含 AMD64 文件系统

- 现象：固定摘要的 OCI index 声明有 `linux/arm64`，但在 Apple Silicon 上运行后，`uname -m`、`dpkg --print-architecture`、Python 和系统 ELF 都显示 `x86_64/amd64`。
- 根因：上游 `base-mini`、`base-full` 和应用 Dockerfile 都使用 `FROM --platform=$BUILDPLATFORM`；多架构 workflow 在 AMD64 runner 上构建时，两个 target manifest 复用了同一组 AMD64 layer，只改了 config 中的架构声明。
- 反证：同一 Docker daemon 运行官方 Alpine/Debian 的 `linux/arm64` 镜像均返回 `aarch64`，排除 Docker Desktop 与宿主配置问题。
- 影响：固定摘要当前只能通过 Rosetta 模拟运行，RG-002 的“原生 ARM64”仍失败；不得通过删除或放宽架构断言掩盖。
- 后续选择：继续用固定摘要并接受模拟运行，或维护一条从原生 Ubuntu ARM64 重建 WeRSS 的自有镜像链；后者会偏离用户锁定的固定上游摘要，需显式决策。

### Docker Desktop 的 internal 网络不发布宿主端口

- 现象：Caddy 的 `HostConfig.PortBindings` 声明 `127.0.0.1:8080`，但 `NetworkSettings.Ports` 为空，宿主无法连接。
- 根因：Docker Desktop 29.6.1 中，仅连接 `internal: true` 网络的容器不会建立 published port；最小 Caddy 对照实验可稳定复现。
- 修复：Caddy 同时加入用于宿主回环发布的 `host-ingress` bridge 和内部 `feed-proxy`；WeRSS 仍通过 `feed-proxy` 被反代，宿主绑定仍严格为 `127.0.0.1:8080`。Caddy 继续使用只读根文件系统、`no-new-privileges`，删除默认 capabilities，仅保留镜像二进制执行所需的 `NET_BIND_SERVICE`。
- 安全残余：普通 `host-ingress` bridge 同时赋予 Caddy 出站与 `host.docker.internal` 可达性，并非单纯的 ingress-only 网络。当前 Caddyfile 没有用户可控上游，且该网络没有 WeRSS；这是 P2 深防御残余，不改变公网路由白名单。
- HEAD 兼容：WeRSS 的 Atom 端点对原生 HEAD 返回 `405`；Caddy 只在已通过随机前缀和 `.atom` 白名单的 GET/HEAD 路由内把上游方法设为 GET，使公网 HEAD 返回元数据且不放宽其他路径。

## 技术决策

| 决策 | 选择 | 原因 | 替代方案 | 状态 |
| --- | --- | --- | --- | --- |
| WeRSS 浏览器 | WebKit | 与固定镜像实际能力一致 | Firefox（当前不可用） | accepted |
| 公网边界 | Caddy `.atom` matcher + 随机前缀 + Funnel | 最小暴露面 | 公开 WeRSS / VPN-only | accepted |
| 网络 | Caddy 使用 host-ingress 发布回环端口并通过内部 feed-proxy 访问 WeRSS；WeRSS 额外使用 internet | Docker Desktop 对仅 internal 网络不建立端口发布；仍保持服务隔离与回环绑定 | 将 feed-proxy 改为非 internal | accepted |
| SECRET_KEY | 由 WeRSS 生成到 `data/.secret_key` | 减少日志中的环境秘密 | 注入 `.env` | accepted |
| 入库 | Folo Basic Obsidian 集成为主，Clipper 备用 | 不依赖未执行的 `EXPORT_MARKDOWN` | WeRSS 自动导出 | accepted |
| Vault 层级 | Archive processed source inbox | 符合 SummerOS 晋升链路 | 直接 Knowledge | accepted |
| 图片 | v1 不自动本地化 | 避免附件污染 | 全量下载 | accepted |

## 待确认问题

| 问题 | 当前判断 | Owner | 截止点 |
| --- | --- | --- | --- |
| 是否拥有公众号运营权限？ | 已确认；WeRSS 显示已授权且 Token 有效 | user | done |
| Docker 协议/权限是否完成？ | App 安装后需用户操作 | user | 本机 smoke 前 |
| Funnel 首次批准是否完成？ | 尚未 | user | 公网 smoke 前 |
| Folo 是否稳定？ | 需 72 小时和 7 天 | user | Basic 购买前 |
