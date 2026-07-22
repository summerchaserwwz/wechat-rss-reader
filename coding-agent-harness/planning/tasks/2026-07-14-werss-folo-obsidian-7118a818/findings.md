# WeRSS Folo Obsidian 阅读系统 - 发现记录

## 研究发现

### 手机阅读库应使用克制的小圆角层级，不应使用玻璃大卡片或全直角

- 截图中的主要视觉负担不是颜色，而是四层重复容器：页面边距、圆角面板、圆角列表卡片、圆角底栏。手机宽度下每层边界都在争夺注意力，也让同屏文章数过低。
- 全部改成 0px 直角会让触控界面显得僵硬。最终按 `awesome-design-md` Cursor 参考使用 4/6/8/10px 半径阶梯：标签最小、紧凑行次之、输入和按钮再大一级、主面板最大，但不超过 10px。深度只用背景差和 1px hairline，不使用阴影或玻璃材质。
- 公众号列表与文章列表是同级浏览状态，适合完整的双向横滑；正文是更深一层的阅读状态，只保留左边缘返回并先保存进度。将两种手势分域后，列表横滑不会侵入正文，正文手势也不会误改列表筛选。
- 手势需要横向方向锁和阈值：垂直位移先超过横向且大于 12px 时立即取消，只有符合方向且横向达到 64px 才切页。412px 视口中实测纵向 124px 不切页，双向横滑均跟手并到达目标。

### Android 浏览器体验应拆成“可安装外壳”和“正文全屏”两层

- Web App manifest 的 `display: standalone` 负责从桌面图标启动时去掉地址栏；阅读中的全屏按钮再调用 Fullscreen API，负责当前会话即时进入无浏览器栏的沉浸模式。两者并存，既不要求第三方阅读 App，也不依赖用户每次手动切换浏览器界面。
- 手机上的长按选区会与浏览器原生菜单、Readeck 标注器和滚动手势竞争。用户已明确放弃手机划线/笔记，因此移动端用透明滚动层接管正文纵向滚动并禁用长按选择，桌面端仍保留原生划线与批注能力。
- 左边缘返回只在正文视图、起点不超过 28 px 且横向位移至少 72 px 时触发；普通纵向阅读和文章列表都不绑定滑动。返回动作先按当前滚动位置计算并保存进度，再通过 History API 回到时间线，避免手势返回丢失阅读位置。
- “已读”不是独立复制数据：`read_progress >= 100` 进入已读栏目，其他文章进入默认未读栏目；阅读到 80% 自动记为 100%，也可在设置中手动标为已读。

### Reader 无法滚动来自 iframe 输入链，卡顿来自整列重建

- 真实浏览器红线确认：选定文章的嵌入正文 `scrollHeight=5170`、`clientHeight=514`，直接设置 `scrollTop` 可以到 640，但鼠标滚轮和 PageDown 后仍为 0；因此不是正文高度不足，而是浏览器输入没有驱动同源 iframe 的滚动根节点。
- 初始收件箱同时创建 218 个文章节点，收藏、阅读进度和标签变化又会整列重建并逐行重绑监听；时间线与正文面板的 `backdrop-filter` 还会增加滚动重绘成本。
- 修复使用 iframe 内受控纵向滚动和键盘滚动，不把连续值写入应用状态；初始时间线限制为 60 篇并在接近底部时分批增加，文章在 hover/focus 时预取，正文主题完成后再移除骨架。Playwright 复测滚轮从 0 到 720，初始 DOM 为 60，390px 下无横向溢出。
- Readeck 原生 annotator 仍负责 API 和选区锚点。其控制器把默认颜色单独保存在 `colorValue`，只设置透明 radio 的 `checked` 不会改变提交值，实际仍会保存 `yellow`；Reader 现在通过原生 click 同步为 `none`，并由真实拦截请求确认 payload。Enter 映射到 create/update，空笔记保存纯划线，Shift+Enter 保留换行。
- Readeck 会把“从正文开始、在正文外结束”的 Range 规范化到正文最后一个文本节点，因此一次拖出边界可能变成整篇标注；真实鼠标拖选后又会派发 click，若此时过早聚焦 textarea，原生 outside-click 还会把刚出现的 annotator 立即关闭。Reader 在 Readeck 微任务前拒绝越界/近半篇误选，使用 Custom Highlight 保留待确认划线，并延后 48ms 聚焦输入框。
- 公众号栏折叠状态保存在浏览器本地；全屏阅读同时隐藏两栏和顶部导航，并在浏览器允许时进入 Fullscreen API。Esc、`F` 或再次点击可以退出。

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

### 嵌入正文不能只依赖固定 bundle 路径刷新样式

- 现象：Reader Caddy 重建后，公网 iframe 已获得 `reader-embed` class，但固定 `/assets/bundle.1cd17fd7.css` 仍可能被浏览器或 Cloudflare 复用旧响应，导致 Readeck 顶栏与侧栏继续显示。
- 修复：固定主题响应增加浏览器/CDN `no-store`；Reader 外壳在 iframe load 后注入带版本号的同源 `/reader-assets/embed.css`，该文件只负责嵌入布局与 Petdex 深色变量，不复制 Readeck 的标注逻辑。
- 验证：公网 Chrome 计算样式确认 `.layout-topnav`、`.bookmark-sidebar`、`.bookmark-topbar` 为 `display:none`，`.bookmark-container` 与 `.bookmark-content` 占满 iframe；原生 `.annotator` 未隐藏，划线与批注能力保持由 Readeck 管理。

### Reader 状态已通过同一篇真实文章形成闭环

- 样本《Prompt Engineering 已死，任务合同当立》原有 1 条持久划线和非空批注；Reader API 操作后同时具备收藏、价值 5、主题“任务合同”和已读 100%。
- 手工已读按钮在当前页面即时从 0 变 100，刷新后仍显示“标为未读”。把样本重置为未读后，Playwright 在同源 iframe 滚动到 85%，Reader 通过 900 ms 防抖自动写回 100%，证明 80% 阈值不是只存在于静态代码。
- Obsidian 同一文件写入受控 `reader_value/reader_tags`；人工 `rating/topics` 和“我的笔记”分别以独立摘要验证前后相同，第二次同步全文件摘要不变。

### 发布到 Reader 延迟门禁已有四个自动样本

- `observations/readeck-stability.tsv` 在自动同步后保留了当时的 `werss_latest` 与 `latest_loaded`；这比事后读取 Readeck `updated` 更可靠，因为收藏、已读或标签修改也会更新 `updated`。
- 交叉解析 WeRSS 发布时间与来源后得到 4 个样本、3 个公众号：29.4、15.5、40.2、24.6 分钟，全部小于 70 分钟。
- 该证据证明每小时抓取加 5 分钟同步在当前样本下满足近实时目标，但不改变“微信无 Webhook、不能宣传秒级”的边界。

### 无秘密截图使用临时本机身份环境

- 为避免把真实 Cloudflare 会话、邮箱或凭据写入截图和自动化配置，验收时创建一次性本机 Reader Caddy：使用固定假邮箱身份，只连接现有内部 Readeck 网络，不创建 DNS、Tunnel 或 Access 对象。
- Playwright 通过本机回环端口生成 1440×900 与 390×844 截图；会话和临时容器在截图后删除。正式公网 Access 与 live Caddy 配置未改变。

### URL Token 不是可接受的免密码设备授权

- 未提交草案曾通过 URL 携带静态 Token 写一年期 Cookie，并把固定管理员身份转发给 Readeck。
- 该方案会让秘密进入浏览器历史、代理日志和截图；Cookie 也不绑定用户、设备或短期会话，违背“不在 URL/前端放凭据”的 Goal 约束。
- 草案已完全撤销并重建容器；当前未认证 Reader Caddy 恢复 Readeck 默认 303/401 边界。公网发布只能在真正的设备身份层完成后进行。

### Cloudflare Access 公网免 Readeck 密码已完成实测

- 官方 Access 自托管应用默认拒绝；正确顺序是先创建 Access application/policy，再创建 Tunnel route，并由 `cloudflared` 校验 Access token/AUD。
- 邮件 OTP 可让允许的邮箱在新设备上完成一次性授权，会话期间无需输入 Readeck 用户名和密码；Reader Caddy 只应把允许身份映射到固定本机用户，不转发外部管理员组。
- 用户明确授权后已按“Access 先于 Tunnel”完成：Zero Trust Free、精确邮箱 Allow、OTP、一周会话、Managed OAuth、独立 `wechat-rss` Tunnel、DNS 和 LaunchAgent。
- 无 Cookie 的 `curl` 对 Reader/API/Feed 得到 Access `401/403`；已授权 Chrome 直接进入 101 篇文章库，无 Readeck 登录表单；授权后的 `/feed/all.atom` 由 Readeck 返回 404。
- 首次部署发现 `cloudflared tunnel list --output json` 在无结果时返回 `null`，不是空数组；脚本已用 `(. // [])` 兼容并完成真实创建。

### Obsidian 实机与同步幂等证据完成

- 真实笔记在 Obsidian 阅读视图同屏显示“我的笔记”、收藏状态、划线摘录、批注、原文对应高亮和原图。
- 连续运行同步两次均为 `Obsidian 更新 0 篇`，样本 SHA-256 与 mtime 在前/中/后三次读数完全一致。
- 真实截图为 `docs/images/06-obsidian-高亮批注笔记.png`；未修改 `readeck_inbox` 之外的业务笔记内容。
- `公众号精选.base` 已在 Obsidian 1.12.7 实机横向验证九列；截图为 `docs/images/08-obsidian-Base.png`。

### WeRSS 管理公网必须使用独立 Access 应用和 AUD

- 用户需要在手机或外网追加公众号，因此“管理端只允许部署 Mac 本机访问”不再满足产品目标；但直接公开 `127.0.0.1:8001` 或和 Reader 共用 AUD 都会扩大权限边界。
- 已创建 `WeRSS 公众号管理` 自托管 Access 应用，精确邮箱 Allow、一周会话；Tunnel 保留 Reader ingress，并新增 `werss.sumerchaser.top -> 127.0.0.1:8083`，两条 ingress 分别校验自己的 AUD。
- WeRSS 专用 Caddy 非目标 Host 返回 404，目标 Host 缺 Access 身份返回 403；公网匿名根/API 被 Access 拦截，已授权 Chrome 到达 WeRSS 原生登录页。原生管理登录继续作为第二层保护。

### Reader 主动刷新不能直接操作 SQLite 或 Docker

- 浏览器点击“检查新文章”需要从公网 Reader 安全触发全部公众号抓取，再继续 reading-sync；浏览器不能持有 WeRSS Access Key，Caddy 也不应访问 Docker socket。
- 最终控制端只监听 `127.0.0.1:8787`，校验 POST、Host、Origin、Access 精确邮箱/JWT 和 Caddy 注入的内部密钥；它调用 WeRSS 支持的 Access Key API，并轮询任务队列。
- 控制端实现 10 分钟冷却、single-flight、连续两次失败暂停和 `200013` 立即暂停。真实点击已完成 `checking_werss -> syncing_reader -> complete`，12 个公众号任务完成，本轮新增 0 篇，没有触发微信风控。

### 设计优化使用高密度阅读工作台而非营销页规则

- `design-taste-frontend` 明确主要面向 landing/portfolio，不直接覆盖高密度产品 UI；本项目只采用其审计、色彩一致性、材料、交互状态、响应式与预检原则，不套营销页 Hero/Bento 结构。
- 设计参数锁定 `DESIGN_VARIANCE 4 / MOTION_INTENSITY 3 / VISUAL_DENSITY 8`。最终为近黑 `#070b14`、钴蓝 `#2f7cf6`、青蓝环境光和克制半透明磨砂；删除旧紫色与遮挡式选区。
- 真实桌面 Chrome 已验证三栏层级、顶部 6 个 Tab、行内收藏、价值/主题和刷新状态；临时选区与持久批注都使用透明底、淡绿 `#8ad4a8` 虚线下划线。新增公众号弹窗已改为 Access 保护的公网 WeRSS 主入口，并保留部署 Mac 本机备用入口。

### Apple 控件语言只能适配到阅读交互，不能降低信息密度

- `awesome-design-md` 的 Apple 参考强调 SF Pro/system 字体、单一行动蓝、18px 圆角、胶囊按钮、克制边框/阴影和 `saturate(180%) blur(20px)` 材质；这些规则已用于批注框、原位笔记、字号 Dock 和导出弹窗。
- 公众号阅读仍需要来源、时间线、正文同时可见，因此保留 Folo 式三栏和 Petdex 科技蓝环境光，没有复制 Apple 营销页的大留白与单列 Hero。
- 批注避让采用浏览器选区矩形与可视口剩余空间计算，优先右、左、上、下并钳制到边界；这比固定居中更能保证选中文字始终可见。

### 划线笔记保留两条独立、可解释的 Markdown 出口

- 服务器权威路径仍是 `reading-sync` 每 5 分钟把收藏或含高亮/批注的完整文章逐篇写入 SummerOS Archive，并保护人工区；不改变现有可靠契约。
- Reader 新增的汇总出口只处理划线笔记：可直接下载 Markdown，或使用 File System Access API 选择本机目录写入。目录句柄保存在当前浏览器 IndexedDB，不把绝对路径或 API Token发送到服务端。
- 移动端或不支持目录授权的浏览器自动保留下载路径；因此“可改默认路径”不会破坏跨浏览器可用性，也不会把 Vault 文件系统权限扩大到后端。

### 公开仓库必须发布集成层，不能发布运行状态

- 可公开范围是固定镜像 Compose、Reader UI、同步与刷新脚本、Caddy、LaunchAgent 模板、示例环境、文档和脱敏截图；微信授权、文章数据库、阅读状态、真实密码、Token、Access AUD 和 Tunnel 凭据全部留在 ignored 本机路径。
- 域名、WeRSS 用户名、Obsidian Inbox 和 LaunchAgent HOME 已从个人硬编码改为 `.env` 或安装时替换。公共模板使用 `example.com` 和随机强密码，不复制维护者当前的本机弱密码选择。
- 推送前当前文件与完整 Git 历史均扫描常见 GitHub Token、私钥、WeRSS Access Key 模式；`.env`、数据、备份、observations、sync-state、secrets 和 cloudflared 路径均验证被 Git 忽略。

### 笔记同步助手到 Reader 是目录桥接，不是双向改写

- 第三方插件负责“微信好友/云端 → Obsidian Markdown 与附件”，本项目只读它的专用目录并把外部原文链接加入 Readeck；Reader 的已读、收藏、划线和标签不会反写第三方云端。
- 插件 API Key 只保存在独立 Vault 的插件 `data.json`，权限为 `600`，不得复制进 `.env`、日志或公开仓库。官方 v3.1.2 安装包的 `main.js` 与厂商当前 HTTPS 文件摘要一致，静态检查未发现 shell、`child_process` 或动态 `eval`。
- macOS LaunchAgent 无法可靠读取 Documents 下的该 Vault；迁移完整 Vault 到 `~/Obsidian/obs-wechat-syn` 并更新 Obsidian 注册表后，5 分钟后台扫描恢复正常。

### Readeck 重定向和 Markdown 图片都必须参与幂等边界

- Readeck 加载外部链接后会把公开 API 的 `url` 更新为重定向终点；仅用当前 URL 去重会在下一轮再次创建同一原始链接。同步器新增 `helper_map`，创建书签后、等待正文前即持久化 `source_url → bookmark_id`，解析超时也不会重复创建。
- 合并微信消息笔记会包含无扩展名图片 CDN；只按 `.png/.jpg` 后缀过滤会把图片误当文章。提取器先移除 Markdown 图片，并拒绝已确认的图片 CDN；调试期间产生的 66 个图片条目和 14 个重复副本均经“本轮创建、未读、未收藏、无批注”断言后清理。
- 最终 74 个唯一文章链接与 Reader 74 个 loaded 条目一一对应；重复运行扫描 85 次引用时 created/labeled/failed 均为 0。

### 微信消息原文与 Cloudflare 调度是两个独立边界

- 旧同步器会扫描 `微信消息/`，但只提取外部 URL；因此消息链接已经进入 Reader，而无 URL 的每日消息没有任何 Reader 条目。新实现按 `#### 标题 + ## 时间` 拆分消息块，以相对路径和规范化内容摘要生成稳定 synthetic URL，140/140 条消息一次性回填，第二轮新增为 0。
- 消息 HTML 在本机转义后直接提交给 Readeck，不让 Readeck 或 Cloudflare 重新抓取本机 Vault；原始 Markdown、附件和插件密钥不上传 Cloudflare。Reader 状态仍由 Readeck 持有，目录桥接不反写第三方同步助手。
- Cloudflare 无法直接读取 Mac 本地 Obsidian 文件，正确边界是 Workflow 负责计划、持久状态与指数退避，Access Service Token 负责机器身份，Tunnel 只把请求送到现有 Caddy，本机回环控制端执行 `reading-sync`。
- 当前 Wrangler OAuth 可以部署 Workers/Workflows，但没有 Access Service Token/policy 写权限。为了不制造同步空窗，live Access 门禁完成前保留 WeRSS 原生 Cron 与 5 分钟 LaunchAgent；切换时必须先验证 `sync`/`start` 实例，再停用两者，不能双调度长期并存。

### 手机正文的透明滚动层只能在确认手势后接管指针

- 为解决 Android iframe 惯性滚动，正文和列表使用父级透明触摸层；旧实现会在 `pointerdown` 立即捕获指针，导致返回、文章行和正文结尾按钮只有按压反馈而不触发点击。
- 列表与左边缘返回现在都延迟到确认横向移动后才调用 `setPointerCapture`。正文透明层继续承担纵向滚动，但普通点击会按坐标转发给受控的 `[data-reader-action]` 或正文链接。
- Readeck 原生底部表单不再作为 Reader 状态入口；Reader 接管收藏/归档按钮并统一调用书签 API，避免 iframe 表单状态与父级列表状态分叉。归档同时写 `is_archived` 和 `read_progress=100`，与“默认未读、归档进入已读栏目”的产品语义保持一致。

## 技术决策

| 决策 | 选择 | 原因 | 替代方案 | 状态 |
| --- | --- | --- | --- | --- |
| WeRSS 浏览器 | WebKit | 与固定镜像实际能力一致 | Firefox（当前不可用） | accepted |
| 兼容 RSS 公网边界 | Caddy `.atom` matcher + 随机前缀 | 保留其他 RSS 阅读器兼容能力，但不再是主链路 | 公开 WeRSS | accepted-optional |
| 网络 | Caddy 使用 host-ingress 发布回环端口并通过内部 feed-proxy 访问 WeRSS；WeRSS 额外使用 internet | Docker Desktop 对仅 internal 网络不建立端口发布；仍保持服务隔离与回环绑定 | 将 feed-proxy 改为非 internal | accepted |
| SECRET_KEY | 由 WeRSS 生成到 `data/.secret_key` | 减少日志中的环境秘密 | 注入 `.env` | accepted |
| 阅读器 | 自托管 Readeck | 免费开源，支持收藏、高亮、批注和全文库 | Folo Basic | accepted |
| 入库 | 自有 reading-sync API/Markdown 桥接 | 可测试、幂等、保护人工区，不依赖付费集成 | Folo/Clipper | accepted |
| Readeck 公网 | Cloudflare Access OTP + 独立 Tunnel + Reader Caddy | 授权设备免 Readeck 密码，匿名会话不能读取私人内容，且不暴露 WeRSS | 自建设备配对运行时 / 仅本机 | accepted-live |
| Vault 层级 | Archive processed source inbox | 符合 SummerOS 晋升链路 | 直接 Knowledge | accepted |
| 图片 | v1 不自动本地化 | 避免附件污染 | 全量下载 | accepted |

## 待确认问题

| 问题 | 当前判断 | Owner | 截止点 |
| --- | --- | --- | --- |
| 是否拥有公众号运营权限？ | 已确认；WeRSS 显示已授权且 Token 有效 | user | done |
| Docker 协议/权限是否完成？ | App 安装后需用户操作 | user | 本机 smoke 前 |
| Cloudflare Tunnel 是否完成？ | 已完成 Access、独立 Tunnel、DNS、LaunchAgent、授权/匿名浏览器边界和公网 smoke | user + coordinator | done |
| Readeck 是否稳定？ | 当前 118 篇去重文章、真实高亮和 Obsidian 幂等样本通过；72 小时/7 天待观察 | user + coordinator | 完成判断前 |

### Android 静态资源版本必须在最终样式落定后再提升

- Reader 静态资源使用 5 分钟浏览器缓存；同一个 `?v=` 下继续修改 CSS 或 JS 时，Android 浏览器会稳定显示上一份资源，即使服务端文件已经更新。
- 每个 UI 切片应在最终编辑完成后统一提升 CSS/JS 查询版本，并由 `verify-reader-ui.sh` 锁定版本；浏览器回归需重新加载后检查实际计算样式，不能只看仓库源码。
- 高密度移动列表不应使用逐条描边圆角卡片。作者色适合落在小标签、渐隐谱线和轻微铺底，行本体保持无边框、无圆角，既能区分来源又不会形成厚重卡片墙。
- 当十六色来源同时出现在一屏时，彩色铺底、双色谱线和底栏彩条会叠加成视觉噪声。更稳妥的层级是：中性背景与行分隔负责结构，作者 Tag 负责识别，2px 低透明度纯色短线只做快速扫视锚点。

### 微信动态媒体必须区分已缓存 GIF 与脚本驱动的视频

- 最新本机 Readeck 压缩归档中已经缓存 263 个 GIF、视频文件为 0；抽样通过 Reader 的同源资源路径返回 `200 image/gif`，因此普通 GIF 不应通过放宽外域 CSP 来修复。
- 最新 WeRSS 1048 篇源文章中，原始 `content` 有 190 篇包含 `<video>`，但优先入库的 `content_html` 已将这些标签清理为 0；这些标签的 `src` 多为空，由微信公众号页面脚本在原文环境中补齐，Readeck 无法可靠重建直接播放地址。
- Reader 保持 `img-src`、`media-src` 和 `frame-src` 的同源边界，避免把不受控外域播放器嵌入私人阅读器。正确降级是提供安全的“打开微信原文”入口，让微信的原始脚本与播放器处理视频和视频化动图。
- 原文入口必须出现在正文第一屏，而不只藏在桌面顶栏或手机设置中。Reader 在同源 iframe 加载后幂等注入紧凑提示，真实文章 DOM 已确认入口位于标题之后、正文之前；普通静态 HTML 继续由 Readeck 清洗后呈现。

### 手机左滑返回与文字选择必须按模式分流

- 阅读模式由父级透明滚动层接收手势，可以让正文任意位置的左滑与纵向滚动通过方向阈值自然分流；确认横向移动前不能捕获指针，避免普通点击和惯性滚动失效。
- 划线模式下横向拖动本身就是文字选择，不能继续把整段正文当作返回手势区。正文中间区域应完全让给原生选区，只在最右侧 32px 保留左滑返回，既不牺牲划线流畅度，也保留退出路径。
- Readeck `DELETE /api/bookmarks/{bookmark_id}/annotations/{annotation_id}` 返回 204。删除成功后直接解除当前 `rd-annotation` 包裹并同步本地 annotation 状态，可避免重载正文和滚动位置跳变；失败时保留原划线并恢复可点击状态。

### Cloudflare Free 不能直接 schedule Workflow，但可用 Cron Trigger 创建 Workflow

- Cloudflare Free 部署带 `workflows[].schedules` 时会拒绝：scheduled Workflows 需要付费 Workers 计划。
- 两个 Workers Cron Trigger 仍可免费使用。正确的兼容架构是 Cron Trigger 只创建带确定性 ID 的 Workflow 实例，长轮询、重试和状态持久化仍由 Workflow 承担。
- 实际部署后，`sync` 以 5 分钟间隔稳定完成；`start` 实例已真实触发 WeRSS 队列、持续轮询并完成新增正文。因此不需要为本项目升级 Cloudflare 套餐。

### 控制端不能把普通连续失败永久锁死

- WeRSS 原生 Cron 和 Cloudflare 同一分钟抓取会导致并发失败；旧控制端累计两次失败后永久返回 409，即使队列和机器身份均健康。
- 普通失败现在只记录次数并交给下一轮计划任务重试；只有微信授权失效会保留 `auth_required`。5 分钟同步不能清除该标志，因此用户点击刷新仍会收到二维码而不是被成功同步状态掩盖。
- Cloudflare 接管时应将 WeRSS 任务维持为启用但把原生 Cron 停放到低频表达式；完全 disable 会同时禁用受保护的手工/机器 `start` 调用。
