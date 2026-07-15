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
- 设置确认：`设置 → 通用 → 语言` 当前值为“简体中文”；界面语言不会翻译第三方英文 Feed 原文。Folo 有收藏/Starred，但当前链路不把它当作持久文本划线或批注系统，永久高亮继续使用 Obsidian Markdown `==...==`。
- 登录后确认：账户当前是 Free；`设置 → 集成 → Obsidian` 的启用开关不可用，计划表同时显示 Free 不包含“第三方集成”和“私有订阅”。因此随机 Feed 不能在 Free 下按既定安全模型直接批量加入；无缝一键保存和私密订阅都需要 Basic 或更高计划。

### Folo 主链路被 Readeck 取代

- 用户明确不希望为核心收藏/入库能力持续付费。
- 已部署开源 Readeck 0.22.3 固定摘要；容器原生 `aarch64`，仅绑定 `127.0.0.1:8002`，界面为简体中文。
- 当前 WeRSS 94 篇文章中 90 篇正文完整，已全部进入 Readeck；4 篇因正文未就绪跳过。
- Readeck 实测支持收藏、正文选择高亮和高亮批注；同步器把高亮导出为 `==...==`，批注同时出现在摘录区与原文脚注。
- 因此 Folo/Tailscale 退出主链路，只保留可选兼容能力。

### Readeck -> Obsidian 人工区保护通过真实验证

- 真实文章《Prompt Engineering 已死，任务合同当立》已收藏，并创建一条高亮和批注。
- Obsidian 文件使用“发布日期-标题--短 ID”命名；顶部人工笔记填入五条判断。
- 重新同步后日志为 `Obsidian 入选 1 篇，更新 0 篇`，同步前后 SHA-256 完全一致。
- 同步器只刷新 managed markers 之间的内容，并保留人工 frontmatter 字段。

### WeRSS 调度从两小时缩短到每小时

- 当前任务名为“公众号每小时自动更新”，Cron `17 * * * *`，状态启用。
- 修改前短暂停止 WeRSS 并创建独立 SQLite 备份，修改后容器恢复 healthy。
- 微信没有 webhook；每小时抓取 + 5 分钟同步是当前安全近实时上限，不应宣传为秒级实时。

### Cloudflare 可替代 Tailscale Funnel

- 发现：用户 Cloudflare 账户管理 `sumerchaser.top`，已有一个离线的 `sumerchaser-knowledge-gate` Tunnel，属于其他用途且不应复用。稳定方案可新建独立 `wechat-rss` Tunnel，将 `rss.sumerchaser.top` 指向本机 Caddy `127.0.0.1:8080`。
- 安全边界：Cloudflare 只负责把 HTTPS 流量送到 Caddy；Caddy 仍只放行随机前缀下的 `GET/HEAD /feed/*.atom`，根路径、管理端、API 和其他方法继续 404。不能启用 Cloudflare Access 登录页，因为 Folo 云端抓取无法交互认证。
- 本机准备：已安装 `cloudflared` 2026.7.1 官方 arm64 签名二进制。创建 Tunnel、DNS 路由和持久账户授权属于外部权限变更，需用户即时确认后执行。

### Obsidian Base 与 Folo 字段

- 发现：Obsidian 1.12.7 支持 `file.inFolder`、`file.hasTag`、`properties.displayName`、`views.order/sort`；Folo 导出包含 `tags: [folo]`、`feedTitle`、`feedUrl`、`publishedAt`。
- 影响：Base 改为稳定过滤整个 Inbox，不再依赖 Folo/Web Clipper 是否写入 `folo` 标签；批注模板不能插入第二份 frontmatter。
- 实现：收件箱整理器保留原 frontmatter 和原文，追加人工字段，在同页原文上方加入笔记区，使用发布日期前缀命名并拒绝覆盖已存在的同名目标；LaunchAgent 等文件稳定 30 秒后再处理，避免与导出写入竞争。

### WeRSS 全部来源任务的返回计数不可信

- 发现：消息任务将 `mps_id` 保存为 `[]` 时，后端实际会回退到全部公众号并正常入队，但 `/message_tasks/<id>/run` 的响应按显式选择列表长度计算，错误显示“共执行更新 0 个订阅号”。
- 影响：不能用该响应判断是否抓取；应使用 `/task-queue/main/status`、队列历史和 SQLite 文章数量验证。当前补抓已把文章从 45 增至 83，12/12 个公众号均已有文章；最后一个任务仍在完成正文抓取，但没有待处理来源。

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

### WeRSS 与 Readeck 出网网络必须隔离

- 初版 Readeck Compose 复用了 WeRSS 的普通 `internet` bridge，导致两个服务可在 Docker 内直接互访。
- 两者都需要出网，但没有业务理由互相访问；最终改为 `werss-internet` 与 `readeck-internet` 两条独立 bridge。
- WeRSS 只通过 `feed-proxy` 被 RSS Caddy 访问；Readeck 只通过 `reading` 被 Reader Caddy 访问。

### Reader 裸 HTML 根因是 CSP 阻止 CSS import

- 初版自定义 CSS 用 `@import /_readeck/assets/...` 引入 Readeck 基础样式；浏览器受 Readeck CSP 约束后没有把 imported stylesheet 放进 CSSOM，导致 `.layout`、`.hidden`、标注浮层等核心规则全部缺失。
- 表现为正文横向溢出、隐藏控件常驻、导航退化成无样式 HTML；单独修改配色和字体无法修复。
- 最终由 Reader Caddy 容器启动时从固定 Readeck 0.22.3 实例读取固定 CSS，再和 `reader-theme/reader.css` 拼接成一个同源响应。运行时实测 `.layout=grid`、`.hidden=none`、标注器为 absolute，桌面正文 736 px、移动正文 351 px，两个视口都无横向溢出。

### URL Token 不是可接受的免密码设备授权

- 未提交草案曾通过 URL 携带静态 Token 写一年期 Cookie，并把固定管理员身份转发给 Readeck。
- 该方案会让秘密进入浏览器历史、代理日志和截图；Cookie 也不绑定用户、设备或短期会话，违背“不在 URL/前端放凭据”的 Goal 约束。
- 草案已完全撤销并重建容器；当前未认证 Reader Caddy 恢复 Readeck 默认 303/401 边界。公网发布只能在真正的设备身份层完成后进行。

### Cloudflare Access 可实现免 Readeck 密码，但激活存在金融门禁

- 官方 Access 自托管应用默认拒绝；正确顺序是先创建 Access application/policy，再创建 Tunnel route，并由 `cloudflared` 校验 Access token/AUD。
- 邮件 OTP 可让允许的邮箱在新设备上完成一次性授权，会话期间无需输入 Readeck 用户名和密码；Reader Caddy 只应把允许身份映射到固定本机用户，不转发外部管理员组。
- 当前 Cloudflare Zero Trust Free 结账页为 `$0/月`，但必须勾选“允许未来超额用量收费”才能激活。该动作属于金融授权，未获用户明确确认前不能执行；Tunnel/DNS 因此保持未创建，避免裸 Readeck 短暂暴露。

### Obsidian 实机与同步幂等证据完成

- 真实笔记在 Obsidian 阅读视图同屏显示“我的笔记”、收藏状态、划线摘录、批注、原文对应高亮和原图。
- 连续运行同步两次均为 `Obsidian 更新 0 篇`，样本 SHA-256 与 mtime 在前/中/后三次读数完全一致。
- 真实截图为 `docs/images/06-obsidian-高亮批注笔记.png`；未修改 `readeck_inbox` 之外的业务笔记内容。

## 技术决策

| 决策 | 选择 | 原因 | 替代方案 | 状态 |
| --- | --- | --- | --- | --- |
| WeRSS 浏览器 | WebKit | 与固定镜像实际能力一致 | Firefox（当前不可用） | accepted |
| 兼容 RSS 公网边界 | Caddy `.atom` matcher + 随机前缀 | 保留其他 RSS 阅读器兼容能力，但不再是主链路 | 公开 WeRSS | accepted-optional |
| 网络 | Caddy 使用 host-ingress 发布回环端口并通过内部 feed-proxy 访问 WeRSS；WeRSS 额外使用 internet | Docker Desktop 对仅 internal 网络不建立端口发布；仍保持服务隔离与回环绑定 | 将 feed-proxy 改为非 internal | accepted |
| SECRET_KEY | 由 WeRSS 生成到 `data/.secret_key` | 减少日志中的环境秘密 | 注入 `.env` | accepted |
| 阅读器 | 自托管 Readeck | 免费开源，支持收藏、高亮、批注和全文库 | Folo Basic | accepted |
| 入库 | 自有 reading-sync API/Markdown 桥接 | 可测试、幂等、保护人工区，不依赖付费集成 | Folo/Clipper | accepted |
| Readeck 公网 | Cloudflare Access OTP + 独立 Tunnel + Reader Caddy | 授权设备免 Readeck 密码，匿名会话不能读取私人内容，且不暴露 WeRSS | 自建设备配对运行时 / 仅本机 | pending-user-financial-approval |
| Vault 层级 | Archive processed source inbox | 符合 SummerOS 晋升链路 | 直接 Knowledge | accepted |
| 图片 | v1 不自动本地化 | 避免附件污染 | 全量下载 | accepted |

## 待确认问题

| 问题 | 当前判断 | Owner | 截止点 |
| --- | --- | --- | --- |
| 是否拥有公众号运营权限？ | 已确认；WeRSS 显示已授权且 Token 有效 | user | done |
| Docker 协议/权限是否完成？ | App 安装后需用户操作 | user | 本机 smoke 前 |
| Cloudflare Tunnel 是否完成？ | 账号授权完成；Zero Trust Free 超额收费授权待用户确认，Access/Tunnel/DNS 尚未创建 | user + coordinator | 公网 smoke 前 |
| Readeck 是否稳定？ | 本机 95 篇、真实高亮和 Obsidian 幂等样本通过；72 小时/7 天待观察 | user + coordinator | 完成判断前 |
