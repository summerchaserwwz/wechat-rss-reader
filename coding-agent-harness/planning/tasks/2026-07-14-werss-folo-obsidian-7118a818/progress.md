# WeRSS Folo Obsidian 阅读系统 - 进度

## 状态：进行中

`## 状态` 是受控机器字段，只能使用以下值之一：

- `未开始`
- `计划中`
- `进行中`
- `审查中`
- `已阻塞`
- `已完成`

不要把 `计划审阅中`、`等待 coordinator pass`、`本地审查就绪` 等细粒度协作状态写入本字段。
这些状态应记录到进度记录、残余或协调者交接中。

## 进度记录

证据使用 `type:path:summary` 格式。

允许的 `type`：`command`, `diff`, `fixture`, `screenshot`, `review`, `report`。

证据较长或数量较多时，不要粘贴全文；放入 `artifacts/INDEX.md` 并在这里引用 ID。

### [YYYY-MM-DD HH:MM] - [阶段名称]

- 做了什么：[具体操作]
- 验证结果：[运行了什么检查，结果如何]
- 下一步：[下一步动作]
- 证据：[type:path:summary]

## 残余

- P1：固定 WeRSS 摘要的 arm64 manifest 实际为 AMD64 文件系统；本机功能可通过 Rosetta 运行，但 RG-002 原生 ARM64 硬门禁失败。需要用户选择接受模拟运行或授权维护自建原生镜像。
- P1：公众号资格/授权、12 个来源和每小时任务已完成；72 小时/7 天近实时观察仍是时间门禁。
- P1：Reader 的“新增公众号”安全入口与自动出现逻辑已实现，但 Goal 指定的“新增一个用户选定公众号，来源 N→N+1”仍需用户给出目标公众号并在本机 WeRSS 完成受控添加。
- P2：Docker Desktop 为 Caddy 发布回环端口需要非 internal bridge，因此 Caddy 具备出站能力；已用只读根、`no-new-privileges`、仅保留 `NET_BIND_SERVICE` 和固定无动态上游的 Caddyfile 降低风险。

### [2026-07-15 19:06] - Petdex 半透明磨砂视觉重构

- 做了什么：直接检查 `petdex.dev` 的真实页面与计算样式，将 Reader 从分散蓝紫光的后台面板感改成上部钴蓝环境光、下部近黑画布；来源栏和顶部导航使用高透明磨砂，时间线与正文使用更稳定的深色表面阶梯。统一 24px 大面板、16px 文章卡和胶囊按钮，并将主操作改为白色高对比胶囊。同步更新嵌入正文的 SF Pro/苹方排版、引用块、代码块、图片圆角和选区反馈。
- 验证结果：授权公网 Reader 在默认桌面视口真实显示 12 个来源、104 篇文章和三栏正文；390×844 下时间线、正文、价值/主题工具栏和新增公众号弹窗均无横向溢出。手机弹窗继续不渲染本机 WeRSS 链接。正文原生划线与批注组件未被替换。Shell、JS、Compose、diff 检查、10 个 unittest、`verify.sh --reader-public`、`verify-reader-ui.sh` 和 Harness 全部通过。
- 下一步：整个任务仍等待用户选定公众号 12→13 与 72 小时/7 天时间门禁，视觉切片本身已完成。
- 证据：command:Chrome public Reader desktop/mobile visual audit:Petdex glass、article typography、mobile dialog pass；command:static+10 unittest+public/UI+Harness:pass；diff:reader-ui/styles.css,embed.css,index.html,app.js:surface ladder、glass、type and cache bust

### [2026-07-15 18:18] - Reader 六图、真实状态闭环与恢复验收

- 做了什么：建立不修改 Cloudflare/DNS 的临时本机 Reader Caddy 与 Playwright 会话，在 1440×900 和 390×844 真实视口生成收件箱、顶部 Tab、一键收藏、订阅页、价值标签、移动端共 6 张无秘密截图。对真实文章《Prompt Engineering 已死，任务合同当立》补齐价值 5、主题“任务合同”和已读状态；复用其既有持久划线与非空批注，完成收藏、标签、已读和 Obsidian 同步闭环。收藏临时测试文章后刷新仍持久，随后在 Readeck 回滚收藏；样本文章重置为未读后滚动 85%，900 ms 防抖后自动回到 100%。
- 验证结果：Readeck API 确认样本 `is_marked=true`、`read_progress=100`、仅一个 `价值/5`、包含 `主题/任务合同`，并存在 text/note 均非空的 annotation。Obsidian 已写入 `reader_value: 5` 与 `reader_tags: 任务合同`；两次同步中人工字段摘要和“我的笔记”摘要完全不变，第二次全文件 SHA-256 不变。稳定性观察交叉计算出 4 篇、3 个公众号的发布到 Reader 延迟为 29.4、15.5、40.2、24.6 分钟，均不超过 70 分钟。新备份 `20260715-181655` 与独立恢复 `20260715-181736` 通过：104 篇文章、1 收藏、1 篇含批注、三个 SQLite、Reader UI、Access 403/403 与模拟身份 200/200 均恢复成功。
- 下一步：运行最终全量命令并提交本切片；随后只剩用户选定公众号 N→N+1、72 小时/7 天项目级时间门禁、最终审查和人工确认。
- 证据：screenshot:docs/images/09-reader-folo-inbox.png:1440×900 三栏正文；screenshot:docs/images/10-reader-top-tabs.png:6 Tab 数量与活动态；screenshot:docs/images/11-reader-one-click-favorite.png:列表/正文双收藏；screenshot:docs/images/12-reader-subscriptions.png:来源与抓取状态；screenshot:docs/images/13-reader-value-tags.png:价值 5 与主题；screenshot:docs/images/14-reader-mobile.png:390×844 单栏正文；command:Playwright API/UI + Readeck API + Obsidian hash:E2E pass；command:backup 20260715-181655 + restore 20260715-181736:pass

### [2026-07-15 18:44] - 新增公众号桌面/手机安全分流

- 做了什么：补齐“新增公众号”对话框的设备分流。桌面端明确说明链接只访问当前设备的 `127.0.0.1`，并保留“在部署 Mac 打开 WeRSS”；手机或触屏设备隐藏该链接，只提示回到部署 Mac 完成添加，避免用户在手机上误开自己的 localhost。
- 验证结果：临时本机假身份 Reader 在 1440px 下显示唯一的本机 WeRSS 链接；缩到 390×844 后通过快捷键 6 进入订阅页，打开对话框只出现手机说明，DOM 中没有“在部署 Mac 打开 WeRSS”链接。临时 Playwright 会话和 Caddy 容器已删除，公网 Access/DNS/Tunnel 未修改。
- 下一步：等待用户给出一个新公众号名称，在 WeRSS 受控 UI 完成 12→13 并验证自动出现；72 小时/7 天观察继续。
- 证据：command:Playwright desktop/mobile feed-dialog audit:desktop local link present、mobile link absent and explanation present；diff:reader-ui/index.html,app.js,styles.css:device-safe subscription flow

### [2026-07-15 17:11] - Petdex 磨砂 Reader 与沉浸正文

- 做了什么：保留 Folo 三栏阅读信息架构，将公网 Reader 改为 Petdex 方向的近黑/靛蓝环境光、半透明磨砂面板、冷色细边框和紧凑元数据；靛蓝用于导航，橙色只保留未读、收藏与价值状态。为嵌入正文新增独立同源 `embed.css`，隐藏 Readeck 自带顶栏、侧栏和信息栏，同时保留原生划线与批注组件；固定主题 CSS 增加浏览器与 CDN `no-store`，避免容器重启后的旧样式缓存。
- 验证结果：授权 Chrome 公网页面显示 6 个顶部 Tab、12 个来源和 103 篇文章；正文 iframe 的 `.layout-topnav`、`.bookmark-sidebar`、`.bookmark-topbar` 计算样式均为 `display:none`，正文容器占满 iframe，`scrollWidth` 等于 viewport。10 个 unittest、Compose、Shell、`verify.sh --reader-public`、`verify-reader-ui.sh` 和 `git diff --check` 全部通过。
- 下一步：等待用户视觉确认；继续 72 小时/7 天稳定性观察和最终人工门禁，不提前关闭整个任务。
- 证据：command:Chrome public Reader DOM/computed-style audit:103 articles、immersive iframe pass；command:python3 unittest + verify public/UI:pass；diff:reader-ui/styles.css,reader-ui/embed.css,Caddyfile.reader:Petdex glass and cache-safe embed

### [2026-07-15 14:04] - Cloudflare 公网与 Obsidian Base 实机验收

- 做了什么：经用户明确授权启用 Zero Trust Free；创建精确邮箱 Allow、OTP 与一周会话的 self-hosted Access 应用；启用 Managed OAuth；授权 `cloudflared` 后创建独立 `wechat-rss` Tunnel、`reader.sumerchaser.top` DNS 和 LaunchAgent。修复 `cloudflared tunnel list` 在首次无 Tunnel 时返回 JSON `null` 导致脚本退出的问题。已授权 Chrome 直接进入 Reader，并在 Obsidian 实机横向检查 Base 全部九列。
- 验证结果：`verify.sh --reader-public` 退出 0；无 Access 请求的 Reader/API/Feed 全部被边缘拦截，授权页面无需 Readeck 用户名密码，授权后的 `/feed/all.atom` 为 Readeck 404。Tunnel 4 条活动连接，LaunchAgent running。WeRSS 12 源、105 篇文章、101 篇合格正文均唯一映射到 101 篇 Readeck。Cloudflare 后备份和独立恢复通过：三个 SQLite、1 用户、101 文章、1 收藏、1 含批注、作用域 Tunnel 凭据通过，账户 `cert.pem` 未进入备份。Obsidian Base 显示文章、作者、公众号、时间、收纳日期、状态、评分、主题和提升去向。
- 下一步：运行最终静态/单测/Harness/秘密扫描并提交本切片；小时与每日自动化继续真实等待 72 小时和第 7 天，不能提前关闭任务。
- 证据：command:./scripts/verify.sh --reader-public:exit 0；command:cloudflared/launchctl:4 active connections、running；screenshot:docs/images/07-cloudflare-公网阅读器.png:公网免 Readeck 密码文章库；screenshot:docs/images/08-obsidian-Base.png:人工处理字段；command:backup 20260715-140025 + restore 20260715-140113:pass

### [2026-07-15 11:00] - 新 Goal 启动基线

- 做了什么：按新目标重新读取项目规则、当前 Harness 任务与 `awesome-design-md`；以只读查询枚举启用来源、文章、Readeck 状态、同步映射和测试数量；保护现有 9 个与 Reader 改造相关的 dirty 路径。
- 验证结果：12 个公众号均启用；WeRSS 共 99 篇、其中 98 篇有正文；Readeck 95 篇均 loaded，1 篇收藏、1 篇含高亮/批注；同步映射 90 条；现有 unittest 8 个。未完成门禁为 Cloudflare Tunnel/DNS 与免密码设备授权、公网安全冒烟、桌面/移动阅读 UI、稳定性 observation TSV、Obsidian UI 截图和 72 小时/第 7 天时间证据。
- 下一步：审查当前 Reader/Caddy/Cloudflare dirty 改动，确定不公开私人内容的免密码设备授权方案，并完成本机 UI 静态与实机验证。
- 证据：command:sqlite3 -readonly:12 feeds、99/98 WeRSS articles、95 Readeck bookmarks、1 marked、1 annotated、90 sync mappings；command:rg tests:8 unittest；command:harness status --json .:active task、9 dirty paths

### [2026-07-15 11:59] - 阅读器 UI、批注持久化与 Obsidian 实机闭环

- 做了什么：按 Apple 编辑型产品设计约束重构 Reader Caddy 主题；定位并修复 CSP 阻止 CSS `@import` 导致 Readeck 基础样式完全失效的问题，改为容器启动时拼接固定 Readeck CSS 与本地主题；真实文章中重新打开已有划线批注；在 Obsidian 阅读视图打开真实同步文章并保存实机截图。撤销未提交的 URL Token/一年 Cookie 解锁草案，恢复默认拒绝未认证访问。
- 验证结果：桌面正文 736 px、17 px 字号、1.8 行高、macOS 中文系统字体优先；1440×900 与 390×844 均无横向溢出；持久划线为 2 px 下划线，刷新后批注仍在。真实 Obsidian 笔记同时显示“我的笔记”、收藏状态、摘录、批注和原文对应高亮。双重运行同步均为 WeRSS 99、Readeck 新增 0、Obsidian 更新 0；样本 SHA-256 与 mtime 三次读数完全一致。
- 下一步：取得 Cloudflare Zero Trust Free 金融授权决策；若允许则建立 Access OTP、Tunnel/DNS 和公网安全验收，若不允许则停在本机并与用户选择新的免密码设备授权运行时。继续真实时间稳定性观察。
- 证据：screenshot:docs/images/03-reader-桌面文章库.png:新版桌面文章库；screenshot:docs/images/04-reader-移动端正文.png:390×844 正文；screenshot:docs/images/05-reader-划线批注.png:选区、下划线与批注；screenshot:docs/images/06-obsidian-高亮批注笔记.png:人工笔记、摘录、批注、原文；command:reading-sync twice + shasum/stat:hash/mtime stable

### [2026-07-15 11:59] - 稳定性观察首条记录

- 做了什么：将旧 Folo 观察脚本改为只读 Readeck 链路快照，不读取密钥；创建权限 600 的 ignored `observations/readeck-stability.tsv` 首条记录。
- 验证结果：12 个启用公众号、99 篇 WeRSS/98 篇标记有正文、95 篇 Readeck、1 收藏、1 含批注、95 条同步映射；WeRSS/Readeck healthy，Reader Caddy running，同步状态 ok，Cron `17 * * * *` 启用。
- 下一步：自动化继续记录；满 72 小时验证至少三次连续周期，第 7 天形成最终判断，不提前关闭门禁。
- 证据：command:./scripts/record-observation.sh:首条 snapshot 写入 ignored TSV；report:wechat-rss-stability-watch:8 天自动化 active

### [2026-07-15 12:16] - Access 本机拒绝态与主题恢复修复

- 做了什么：移除不安全的 URL Token/长期 Cookie 草案；将公网 Reader 改为只接受 Cloudflare Access 注入的精确邮箱与 JWT，且 Access 未就绪时保持 403；Tunnel 配置脚本新增“先建 Access、再建 Tunnel/DNS”的硬门禁。发现恢复包漏掉 `reader-theme/` 会导致 Reader Caddy 无法启动后，扩展备份与恢复契约并增加主题文件和 Caddy 就绪断言。
- 验证结果：本机 Host 保持 Readeck 原生 303/401；模拟公网 Host 在无 Access 身份时为 403/403；配置脚本在 `CF_ACCESS_READY` 未启用时于任何外部写入前退出。包含主题的备份 `20260715-120731` 在独立目录恢复成功：三个 SQLite integrity check、1 用户、95 文章、1 收藏、1 含批注、API Token 和两个 Caddy 均通过。
- 下一步：对最终 Access/Caddy matcher 重新创建备份并完成独立恢复；重跑全部静态、本机、Harness 与秘密扫描。金融授权获得前不创建 Cloudflare Access/Tunnel/DNS。
- 证据：command:curl Reader local/public Host:303/401 与 403/403；command:configure-cloudflare-tunnel.sh:pre-write fail-closed；command:backup 20260715-120731 + restore 20260715-120824:pass

### [2026-07-15 12:18] - 最终本机配置回归

- 做了什么：针对最终 Access matcher 和恢复断言重新创建一致性备份，并在独立 Compose project、独立网络和端口恢复；重跑 Shell、8 个 unittest、Compose、Harness、diff 和本机安全 smoke。
- 验证结果：备份 `20260715-121728` 与恢复目录 `20260715-121812` 通过；三个 SQLite integrity check、1 用户、95 文章、1 收藏、1 含批注、API Token、Reader 主题、Feed Caddy、本机 303/401 和公网 Host 无身份 403/403 均通过。静态/单测/Harness/diff 全部通过；`verify --local` 只在已知 WeRSS `x86_64` 原生架构硬门禁返回 1。
- 下一步：完成 Base 列验证；等待用户明确选择是否激活 Zero Trust Free，允许后才创建 Access、Tunnel/DNS 和执行公网 smoke；自动化继续积累 72 小时/第 7 天证据。
- 证据：command:backup 20260715-121728 + restore 20260715-121812:pass；command:bash/unittest/compose/harness/diff:pass；command:verify --local:security pass, R-002 fail

### [2026-07-15 12:34] - 小时抓取证据审计与采样加密

- 做了什么：提交检查点后复核四个容器、12 个启用来源、WeRSS/Readeck 计数和 observation TSV；逐源聚合确认 12/12 均至少有 5 篇文章。审计小时调度时间戳时发现 12:17 周期与一致性备份停机重叠，只处理 1 个来源，因此明确不把该轮计为连续成功周期。新增 `wechat-rss-hourly-observation` 自动化，以每小时第 25 分钟连续采样 73 次，保留原有 8 天每日最终判断。
- 验证结果：工作区在提交 `a749531` 后干净；WeRSS/Readeck healthy，12 个来源、99/98 篇 WeRSS、95 篇 Readeck、1 收藏、1 含批注、95 映射；观察 TSV 现有 2 条，均为 sync ok。日志时间戳证明 10:17、11:17、12:17 均触发，但 12:17 被备份中断，下一次完整候选为 13:17。
- 下一步：从 13:25 自动采样验证完整周期，累计三次连续成功结果；观察到新增文章时核对其在下一次 5 分钟同步周期进入 Readeck且无重复。
- 证据：command:SQLite aggregate:12/12 sources have articles、counts stable；command:safe log timestamp aggregation:10:17/11:17/12:17 triggered；report:wechat-rss-hourly-observation:ACTIVE, 73 hourly runs

### [2026-07-15 12:38] - 免 Readeck 密码的本机身份映射演练

- 做了什么：扩展独立恢复演练，在不改 live `.env`、不使用真实邮箱或 Cloudflare 凭据的前提下，临时启用 Readeck forwarded auth，并向 Reader Caddy 注入假的已验证 Access 身份头。
- 验证结果：模拟公网 Host 无身份时根路径/API 仍为 403/403；精确测试邮箱加 JWT 头时根路径跟随跳转后为 200、`/api/bookmarks` 为 200，直接进入既有 `summer` 用户且不需要 Readeck 登录表单。恢复目录 `20260715-123743` 同时保持三个 SQLite、95 文章、收藏、批注、API Token、Feed 和主题验证通过。
- 下一步：真实公网仍必须由 `cloudflared` 的 team/AUD 校验和 Cloudflare Access 精确邮箱策略保护；获得金融授权后再做无痕与已授权 Chrome 实机验收。
- 证据：command:./scripts/restore-test.sh:403/403 anonymous and 200/200 simulated Access identity, restore pass

### [2026-07-15 12:43] - 全量同步映射纳入本机硬验收

- 做了什么：跨 WeRSS、同步状态和 Readeck 三个 SQLite 交叉核对 95 条文章映射，并将同一断言并入 `verify.sh --local`：正文门槛、文章/书签唯一性、孤儿、URL 错配以及 12 个启用公众号覆盖率。
- 验证结果：95 篇达到正文门槛的 WeRSS 文章全部且唯一映射到 95 篇 Readeck 书签；0 个 WeRSS/Readeck 孤儿、0 个 URL 错配；12/12 个启用公众号均有可用正文和 Readeck 映射。更新后的本机验收打印同步映射通过，随后仍只在已知 WeRSS `x86_64` 门禁返回 1。
- 下一步：小时采样继续验证新增文章在 5 分钟同步周期后的零遗漏/零重复；不把静态全量一致性替代真实时间门禁。
- 证据：command:./scripts/verify.sh --local:12 feeds、95 unique mappings pass, R-002 fail only

### [2026-07-15 12:47] - 真实新增文章 5 分钟同步延迟证据

- 做了什么：以最新合格 WeRSS 正文的就绪时间与对应 Readeck 书签 `updated` 时间交叉计算真实加载延迟；扩展 `record-observation.sh`，在保留旧行的同时迁移 TSV 表头，今后自动记录合格正文数、重复/缺失映射、最新就绪/加载时间和延迟。
- 验证结果：最新真实文章于 10:19:13 在 WeRSS 就绪，10:21:22 在 Readeck 完成加载，延迟 2.16 分钟；对应 95 条映射仍为 0 重复、0 缺失。`observations/readeck-stability.tsv` 已无损迁移为 22 列，前两条历史行保留，第三条包含该延迟证据。
- 下一步：继续等待并记录三个不受维护停机影响的连续小时抓取周期；出现更新时由同一字段持续验证 5 分钟内加载和零重复。
- 证据：command:cross-SQLite ready/load timestamps:2.16 minutes；command:record-observation.sh:22 columns、95 eligible、0 duplicate、0 missing

### [2026-07-15 12:52] - 三次连续小时抓取结果完成

- 做了什么：读取上游任务追踪器源码确认其“失败”计数实际包含“成功抓取但本轮 0 篇新文章”，不能作为网络/抓取异常；随后只对容器日志做时间与结果聚合，不保存或输出原始日志、公众号名称和环境变量。
- 验证结果：09:17、10:17、11:17 三个连续计划周期均完成 12/12 个公众号，`获取文章失败` 与 `任务执行异常` 均为 0；本轮有新增内容的来源数分别为 3、1、0。10:17 周期产生的最新合格文章已由前一条证据证明在 2.16 分钟内进入 Readeck且零重复。12:17 周期因维护备份中断仍保留为无效样本，不影响此前三次连续完整证据。
- 下一步：三周期与 5 分钟同步门禁已满足；小时/每日自动化继续积累 72 小时和第 7 天证据，任何后续异常仍按回归处理。
- 证据：command:safe completion-block aggregation:09:17/10:17/11:17 each total=12, fetch_errors=0, task_exceptions=0；report:/app/jobs/mps.py tracker semantics inspected

### [2026-07-16 00:00] - WeRSS 独立 Access 与公网管理入口

- 做了什么：在用户已授权的 Cloudflare 账户中创建 `WeRSS 公众号管理` 自托管 Access 应用和精确邮箱策略；从应用页安全读取 AUD 写入 ignored `.env`；保留 Reader ingress，在独立 `wechat-rss` Tunnel 新增 `werss.sumerchaser.top -> 127.0.0.1:8083`，两条 ingress 使用各自 AUD。LaunchAgent 首次重载出现 macOS I/O 错误，未删除外部对象，重试 bootstrap 后恢复活动连接。
- 验证结果：`verify --reader-public` 与 `verify-werss-public.sh` 均通过；无 Cookie 的 Reader/API/Feed 与 WeRSS 根/API 被 Access 拦截；本机 WeRSS Caddy 非目标 Host 404、缺身份 403；已授权 Chrome 到达 `https://werss.sumerchaser.top/login?redirect=/` 的 WeRSS 原生中文登录页。现有 Reader 无回归。
- 下一步：扩展架构、操作说明、备份恢复与最终审查证据；72 小时/7 天时间门禁继续运行。
- 证据：command:configure-cloudflare-tunnel.sh:DNS route + ingress validate；command:cloudflared tunnel info:active darwin_arm64 connector；command:verify public scripts:pass；browser:authorized WeRSS title and host verified

### [2026-07-16 00:15] - 科技蓝阅读 UI 与主动刷新闭环

- 做了什么：按 `design-taste-frontend` 的审计和预检原则，把 Reader 锁定为 `4/3/8` 高密度工作台；移除旧紫色，统一近黑科技蓝磨砂、中文文案、淡绿透明虚线选区/持久批注；新增 Access 保护的公网 WeRSS 入口与本机备用入口。实现并安装只监听 `127.0.0.1:8787` 的主动刷新控制端，同时修复 Caddyfile 变化必须 `--force-recreate reader-caddy`。
- 验证结果：14 个 unittest、Shell、Compose 和 `verify-reader-ui.sh` 通过；真实桌面 Chrome 显示 6 个 Tab、107 篇文章、行内收藏、价值 5/主题标签和划线文章。实际点击“检查新文章”完成 `checking_werss -> syncing_reader -> complete`，12 个公众号全部处理，新增 0 篇，未出现 `200013`，界面显示抓取/同步时间与冷却剩余。
- 下一步：运行包含新 Caddy、控制端和凭据的真实备份/独立恢复；跑全量回归、秘密扫描和对抗审查。
- 证据：command:python3 unittest:14 pass；command:verify-reader-ui.sh:pass；browser:desktop/list/article/highlight/feed-dialog/refresh states；command:local refresh status monitor:complete

### [2026-07-16 00:33] - 新架构备份恢复与全量回归

- 做了什么：重新生成无秘密的 1440×900 与 390×844 科技蓝截图，替换旧紫色证据；执行包含第三个 Caddy、主动刷新控制端/凭据、Reader UI 和 Tunnel 双 ingress 的一致性备份与独立恢复；更新 README、教程、Folo 差距审计、Architecture/Integration/System Map、Regression SSoT 和任务材料。
- 验证结果：备份 `20260716-002238`、独立恢复 `20260716-002339` 通过，三个 SQLite、1 用户、107 篇文章、1 收藏、1 篇含批注、Reader/WeRSS 双 Access Caddy、主动刷新凭据与 Tunnel 作用域配置均恢复；14 unittest、Shell、Compose、4 plist、Reader UI、公网 Reader、公网 WeRSS、Harness、diff、秘密忽略和主按钮 5.33:1 对比度全部通过。`verify --local` 只在已知 WeRSS `x86_64` residual 返回 1。
- 下一步：执行 L1 对抗审查，关闭新增安全 finding；保持 72 小时/7 天门禁进行中，不提交最终人工确认。
- 证据：command:backup/restore:pass；command:regression matrix:pass except R-002；screenshot:docs/images/09-14 blue desktop/mobile；command:preflight:no old purple/no em dash/contrast AA

## 协调者交接（Coordinator，启用模块并行时填写）

- Global sync status：pending-coordinator-pass / synced / n/a
- Registry update needed：[module key, step, status, branch, updated / 不适用]
- Harness Ledger update needed：[task plan path, review path, closeout status / 不适用]
- 负责人：coordinator / 不适用

### [2026-07-14 02:09] - task-start

- 做了什么：开始实施部署包、本机运行时、Funnel、Folo 与 Obsidian 全链路
- 验证结果：已记录
- 下一步：继续执行
- 证据：n/a

### [2026-07-14 15:56] - EXEC-02 本机运行时与故障收敛

- 做了什么：安装并启动官方签名的 Docker Desktop 4.82.0 与 Folo 1.11.0；拉取固定镜像；启动 WeRSS/Caddy；定位上游伪 ARM64 manifest；修复 Docker Desktop 对纯 internal 网络不建立 published port 的 Caddy 可达性问题。
- 验证结果：WeRSS healthy；8001/8080 仅绑定 `127.0.0.1`；管理端 `200`；Caddy 根、随机前缀根、API、POST、路径穿越均 `404`；随机 Atom `200` 且 `xmllint` 通过。`verify --local` 完整执行后仅因容器实际 `x86_64` 返回 1，RG-002 保持 fail。
- 下一步：用户对 ARM64 路径作显式决策；确认公众号运营资格后再启用 Funnel，并在 Chrome 完成微信扫码与 3 个试验源。
- 证据：command:./scripts/verify.sh --local:安全/Feed 断言通过，原生架构断言按预期失败；report:coding-agent-harness/planning/tasks/2026-07-14-werss-folo-obsidian-7118a818/findings.md:BUILDPLATFORM 根因与对照实验

### [2026-07-14 15:45] - RG-004 备份与独立恢复

- 做了什么：短暂停止 live WeRSS 创建权限为 600 的完整备份，在独立目录、不同 Compose project 与随机端口启动恢复实例。
- 验证结果：归档校验、SQLite `PRAGMA integrity_check=ok`、恢复实例管理端、Caddy 根路径 404 与随机 Feed 200 均通过；测试实例已清理。备份包含 `wx.lic` 与 `.secret_key`，尚无 `key.lic`。
- 下一步：完成真实微信授权后再次备份并验证订阅、文章、登录用户和授权状态。
- 证据：command:./scripts/backup.sh && ./scripts/restore-test.sh:独立恢复通过并清理测试栈

### [2026-07-14 16:20] - Caddy 深防御与复审

- 做了什么：对 Docker Desktop `internal` 网络端口发布修复进行只读对抗复审；记录普通 bridge 的 P2 出站残余；Caddy 删除默认 capabilities，仅保留镜像二进制执行所需的 `NET_BIND_SERVICE`；补充 HEAD 与非 Atom 断言，并只在严格 Feed 白名单内兼容 WeRSS 的 HEAD 405。
- 验证结果：复审无 P0/P1；合法 GET/HEAD 为 200 且 HEAD 响应体为 0；POST/PUT/PATCH/DELETE/OPTIONS 和非 `.atom` 均 404；Caddy 只读根、`no-new-privileges`、capability 限制生效。最终配置再次完成备份和独立恢复演练。
- 下一步：保留 P2 深防御 residual；进入用户资格与架构决策门禁。
- 证据：review:network_fix_review:两轮只读复审无阻塞 finding；command:./scripts/verify.sh --local:全部安全断言通过后仅由原生架构门禁返回 1；command:./scripts/backup.sh && ./scripts/restore-test.sh:最终配置恢复通过

### [2026-07-14 16:57] - GATE-QUAL 微信授权与真实订阅

- 做了什么：用户确认拥有公众号运营权限并在 WeRSS 完成授权；后台显示 Token 有效。用户添加 12 个公众号；创建并应用“公众号每两小时自动更新”任务，Cron 为 `17 */2 * * *`，留空公众号范围表示作用于全部来源。
- 验证结果：SQLite 有 12 个 feed、45 篇文章、1 个启用任务；已有 5 个公众号成功入库文章，聚合 Atom 输出 20 条合法 entry。其余来源等待定时任务和风控间隔继续抓取。
- 下一步：用户明确批准 Tailscale Funnel 公网权限；批准后写入公开 `RSS_BASE_URL`、执行 RG-003，并在已登录的 Folo 中添加聚合源。
- 证据：command:sqlite3 -readonly data/we_mp_rss.db:12 feeds、45 articles、任务已启用；command:xmllint /tmp/wechat-rss-all.atom:20 entries；screenshot:WeRSS UI:公众号列表、授权有效与自动任务配置

### [2026-07-14 17:38] - 中文界面、补抓与 Obsidian 批注流

- 做了什么：确认 Folo 通用设置的界面语言已经是“简体中文”，识别首页英文目录为未登录演示订阅；触发全部公众号抓取并通过任务队列跟踪实际进度；为 SummerOS 收件箱实现日期命名、同页“我的笔记 + 划线与摘录 + 原文”、人工字段补齐和不覆盖保护，并安装每 60 秒运行的本机 LaunchAgent。
- 验证结果：Folo 设置页中文字段可见；抓取期间文章由 45 增至 83，12/12 个公众号均已有文章，队列无待处理项且最后一个公众号仍在完成正文抓取；整理器 3 个 unittest 全通过，覆盖日期重命名、幂等和同名不覆盖；LaunchAgent 运行副本位于用户本地数据目录，最近退出码为 0，规避 macOS 对 Documents 目录的后台访问限制。
- 下一步：等待最后一个正文抓取任务自然结束；用户解锁 Mac、登录 Folo 并明确批准 Funnel 后配置公网 Feed；得到首个真实 Folo 导出样本后执行 RG-008 五类样本。
- 证据：command:python3 -m unittest discover -s tests -v:3 tests pass；command:launchctl print gui/$UID/com.summer.wechat-rss-obsidian-inbox:last exit code 0；command:task-queue/main/status + sqlite3:83 articles/12 sources，0 pending；diff:scripts/prepare-obsidian-inbox.py:日期/批注/高亮布局和不覆盖保护

### [2026-07-14 23:38] - Folo 登录与 Cloudflare 路径预检

- 做了什么：确认 Folo 桌面端已登录；检查 Obsidian 集成、私有订阅与计划状态；只读检查用户 Cloudflare 账户中的域名和现有 Tunnel；安装官方签名的原生 ARM64 `cloudflared` 2026.7.1 到用户本地命令目录。
- 验证结果：WeRSS 当前 12 个源、91 篇文章且 12/12 均有内容；Folo 当前为 Free，Obsidian 集成开关禁用，私有订阅不可用；Cloudflare 账户有 `sumerchaser.top`，现有 `sumerchaser-knowledge-gate` Tunnel 离线且属于其他用途，不复用；`cloudflared` 为 Cloudflare Developer ID 签名的 arm64 二进制。
- 下一步：取得用户对创建 `wechat-rss` Tunnel、绑定 `rss.sumerchaser.top` 的即时确认；另行取得 Folo Basic 试用/订阅的金融确认后，才能启用私有订阅与 Obsidian 一键保存。
- 证据：screenshot:Folo 设置/计划:Free、第三方集成禁用；screenshot:Cloudflare Dashboard:Tunnel 列表与 `sumerchaser.top`；command:cloudflared --version + file + codesign:2026.7.1 arm64，Cloudflare Inc. 签名；command:sqlite3 data/we_mp_rss.db:12 feeds、91 articles

### [2026-07-15 00:25] - 开源 Readeck 主链路落地

- 做了什么：放弃依赖 Folo Basic 的主链路；部署固定摘要 Readeck 0.22.3；创建中文管理员、最小权限 API Token 和 5 分钟 LaunchAgent；实现 WeRSS 全量正文回填与收藏/高亮筛选入库。
- 验证结果：Readeck 原生 `aarch64`，仅绑定 `127.0.0.1:8002`；WeRSS 94 篇中 90 篇完整正文已进入 Readeck且 loaded；4 篇正文未就绪；LaunchAgent 最近退出码 0。
- 下一步：真实高亮/批注/Obsidian 样本与人工区保护。
- 证据：command:Readeck API/SQLite:90 bookmarks、state 0；command:launchctl print:reading sync exit 0；screenshot:docs/images/01-readeck-公众号文章库.png

### [2026-07-15 00:50] - Readeck 高亮、批注与 Obsidian 不覆盖

- 做了什么：在真实公众号文章创建收藏、高亮和批注；同步成 Obsidian 原文笔记；在人工区填写五条真实判断后再次同步。
- 验证结果：高亮为 `==给弱模型写步骤，给强模型写责任。==`，批注同时存在于摘录区和原文脚注；重复同步日志为“更新 0 篇”；同步前后 SHA-256 一致，人工 frontmatter 和“我的笔记”完整保留。
- 下一步：用户解锁后补 Obsidian UI screenshot；补充复杂排版样本。
- 证据：screenshot:docs/images/02-readeck-划线批注.png；command:reading-sync + shasum:hash stable；fixture:SummerOS/readeck_inbox/真实文章

### [2026-07-15 00:51] - 每小时近实时调度

- 做了什么：短暂停止 WeRSS，创建修改前 SQLite 备份，将任务从 `17 */2 * * *` 改为 `17 * * * *`，任务名改为“公众号每小时自动更新”，随后重启。
- 验证结果：任务状态 1；WeRSS 恢复 healthy；管理端仍仅绑定 `127.0.0.1:8001`。
- 下一步：观察 72 小时/7 天真实新文章延迟。
- 证据：command:sqlite3 message_tasks + docker compose ps:hourly cron and healthy

### [2026-07-15 01:05] - Reader Caddy、Cloudflare 与恢复扩展

- 做了什么：新增仅回环 `127.0.0.1:8082` 的 Readeck 专用 Caddy；准备独立 `wechat-rss` Cloudflare Tunnel/DNS/LaunchAgent 脚本；扩展备份恢复覆盖 Readeck、API Token、实际同步状态和可选 Tunnel 作用域凭据；更新中文教程与架构 SSoT。
- 验证结果：本机 Reader Caddy 根路径返回 303 登录跳转，匿名 `/api/bookmarks` 返回 401；Cloudflare 外部对象尚未创建，符合 action-time 确认边界。
- 下一步：静态/本机/恢复全量 rerun；用户解锁和确认 Cloudflare 后完成 live gate。
- 证据：command:curl 127.0.0.1:8082:303/401；diff:compose/Caddy/scripts/docs/harness

### [2026-07-15 01:18] - 扩展备份恢复与最终本机回归

- 做了什么：对最终配置重新执行一致性备份和独立恢复；恢复实例额外验证实际 API Token；重跑 8 个 unittest、Shell/Compose/plist、Harness、秘密扫描和本机安全 smoke。
- 验证结果：三个 SQLite integrity_check 均为 ok；恢复出 1 个用户、90 篇文章、1 个收藏、1 篇含批注；API Token 在恢复 Readeck 返回 200；WeRSS Feed、Reader Caddy 303/401 通过；8 tests 与 Harness 通过。`verify --local` 只因已知 WeRSS `x86_64` residual 返回 1，其前置安全检查全部通过。
- 下一步：用户解锁 Mac 完成 Obsidian screenshot；确认 Cloudflare 持久授权后执行公网 live smoke；随后填 final review/walkthrough。
- 证据：command:backup 20260715-012116 + restore 20260715-012211:pass；command:unittest/bash/compose/plutil/harness:pass；command:verify --local:security pass, R-002 fail

### [2026-07-15 01:22] - 容器出网隔离复审修复

- 做了什么：最终安全复审发现 WeRSS 与 Readeck 复用普通出网 bridge；拆分为 `werss-internet` 与 `readeck-internet`，随后重建服务并重新执行备份恢复。
- 验证结果：WeRSS 仅连接 `feed-proxy + werss-internet`；Readeck 仅连接 `reading + readeck-internet`；WeRSS 容器无法解析 `readeck`；Reader Caddy 仍返回 303/401；同步幂等为更新 0；最终恢复再次通过。
- 下一步：仅剩 Obsidian UI、Cloudflare live 和时间门禁。
- 证据：command:docker inspect networks + getent:isolated；command:restore 20260715-012211:pass

### [2026-07-15 01:28] - 72 小时/7 天自动稳定性巡检

- 做了什么：创建本项目本机自动化 `wechat-rss-stability-watch`，连续 8 天每日只读检查 Compose、WeRSS/Readeck 计数、同步日志和 Reader Caddy 303/401，并写入 ignored observation TSV。
- 验证结果：自动化已在 Codex App 中激活；提示词明确禁止读取/输出秘密、修改 Cloudflare/DNS、提交 Git或处理付款。
- 下一步：用每日证据完成 72 小时和 7 天门禁；异常时修复并重跑。
- 证据：report:Codex automation wechat-rss-stability-watch:ACTIVE, 8 daily runs

### [2026-07-16 15:18] - Apple 磨砂划线笔记与可配置导出

- 做了什么：修复品牌栏直接显示 Cron、划线后正文变黑和原生批注框遮挡选区；将批注工具改为紧凑 Apple 磨砂浮层并动态避让选区；保存后自动定位划线并显示原位笔记卡；加入按条聚合的“划线笔记”、右侧字号控件、打开后自动进入阅读中、Markdown 下载和浏览器侧可选 Obsidian 目录。
- 验证结果：1440×900 真实浏览器中选区文字保持 `rgb(203, 217, 232)`、背景透明，340px 批注框与选区相隔 11px；真实创建批注后数量递增、自动定位且只显示 1 个原位笔记卡，删除测试批注后数量恢复；字号 17→18px 跨刷新保存；3 条真实划线导出的 Markdown 含 3 个摘录、来源、原文链接和笔记；390×844 无父页面横向溢出，移动笔记卡完整收纳。回归期间 WeRSS 增至 124 篇，第一次公网验收按设计发现同步滞后并失败；运行正式同步器后 118 篇去重可用正文全部唯一进入 Reader，第二次公网验收通过。
- 下一步：完成全量静态/单元/Compose/Caddy/Harness 回归；整个任务仍等待 72 小时/7 天观察与最终人工确认。
- 证据：screenshots:docs/images/05-reader-划线批注.png,docs/images/15-reader-划线笔记与字号.png；command:Playwright desktop/mobile/create-save-delete/export/font E2E；command:verify-reader-ui.sh + verify.sh --reader-public:pass

### [2026-07-16 15:53] - 账号迁移与 GitHub 公开发布准备

- 做了什么：按用户要求把当前 WeRSS 管理登录迁移为 `summer`，本机密码单独保存在 ignored `.env`；将仓库从单机配置泛化为可公开复用模板，域名、管理员用户名、Obsidian Inbox 和 LaunchAgent HOME 均可配置；新增酷炫 README、部署指南、Security Policy、MIT License、GitHub CI、账号迁移脚本和 Readeck Token 安全保存脚本；创建公开 GitHub 仓库 `summerchaserwwz/wechat-rss-reader`。
- 验证结果：新 WeRSS 账号实际登录成功，旧用户名拒绝；本机 Compose 和 `.env.example` Compose 均通过；14 个 unittest、Shell、Node、4 个 plist、Reader UI、公网 Reader/WeRSS、README 22 个本地链接、Harness 与秘密扫描通过；最终备份 `20260716-155105` 和独立恢复 `20260716-155153` 通过，恢复出 118 篇文章、收藏、4 篇含批注、双 Access Caddy、主动刷新和同步状态。
- 下一步：提交全部集成改动，推送分支，创建 Draft PR 并核验远端 README/CI；72 小时/7 天时间门禁仍独立继续。
- 证据：repository:https://github.com/summerchaserwwz/wechat-rss-reader；command:secret scan + full test matrix + backup/restore:pass
