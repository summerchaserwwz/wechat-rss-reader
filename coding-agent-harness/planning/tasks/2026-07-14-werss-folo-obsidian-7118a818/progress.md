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
- P1：Reader 的“新增公众号”安全入口和 12→13 来源自动出现已完成；新增来源的长期稳定性继续纳入 72 小时/7 天观察。
- P1：Cloudflare Workflow 的实现、dry-run 与本机机器链路通过；Access Service Token/Service Auth policy、live deploy 和双 Cron 切换仍需 Access 写权限，在此之前保留本机兜底。
- P2：Docker Desktop 为 Caddy 发布回环端口需要非 internal bridge，因此 Caddy 具备出站能力；已用只读根、`no-new-privileges`、仅保留 `NET_BIND_SERVICE` 和固定无动态上游的 Caddyfile 降低风险。

### [2026-07-20 03:46] - 手机列表 awesome-design 小圆角与双向滑动

- 做了什么：依据用户手机截图撤掉公众号页、文章列表和底部导航的 18-20px 大圆角、玻璃渐变、发光阴影与宽松卡片间距；按用户点名的 `awesome-design-md` Cursor 参考改为 4px 标签、6px 紧凑行、8px 输入/按钮、10px 主面板的克制层级，保留近黑底、细边框和无阴影。公众号行压到 42px，普通文章行压到 66-78px。新增公众号列表向左滑进入文章列表、文章列表向右滑返回公众号列表的跟手交互，64px 阈值过滤误触，正文既有左边缘返回不变。
- 验证结果：412×915 Chromium 实测主面板/底栏 10px、行 6px、标签 4px；双向滑动过程 transform 分别达到 `+120px/-125px` 并完成 `timeline -> sources -> timeline`；纵向 124px 动作保持在 timeline；普通文章行 66-78px。23 个 Python 单测、Node、Shell、Compose、Reader UI、公网 Access、安全映射和 Harness 全部通过。
- 下一步：用户在 Android Chrome/PWA 实际确认视觉密度和手势手感；项目级时间与架构 residual 不变。
- 证据：screenshot:output/playwright/android-reader/awesome-rounded-sources.png:awesome-design 公众号列表；screenshot:output/playwright/android-reader/awesome-rounded-timeline.png:小圆角紧凑标签文章列表；command:Playwright 412x915 pane swipe/vertical guard/layout metrics:pass；command:unittest+static+verify-reader-ui+reader-public+harness:pass

### [2026-07-20 03:02] - Android 应用式全屏阅读收口

- 做了什么：按用户最终取舍把手机端收敛为阅读、收藏和已读管理；默认进入“未读”，100% 文章归入“已读”。正文顶栏固定显示返回、全屏、收藏、设置四个小图标；移除手机右下角字号/划线悬浮条，把字号与“标为已读”放进设置。新增 Android 可安装 Web App manifest 与 192/512 图标，独立窗口不显示地址栏；正文支持左边缘滑动返回，并在返回前保存当前进度，列表不绑定滑动手势。
- 验证结果：412×915 真实 Chromium 中四个顶栏入口可见，Fullscreen API 返回 `fullscreen=true`，手机阅读 Dock 为 `display:none`；从正文左缘滑动返回时间线，拦截到离开前提交 `read_progress=58`。23 个 Python 单测、Shell、Compose、Node、manifest/图标、Reader UI、本机/公网 Access 边界和 Harness 全部通过。
- 下一步：用户在 Android Chrome 从“阅读设置 → 安装到桌面”完成一次安装并确认系统级返回手势手感；项目级时间与架构 residual 不变。
- 证据：command:Playwright 412x915 fullscreen/edge-swipe/progress probe:fullscreen true、dock hidden、read_progress 58、returned timeline；screenshot:output/playwright/android-reader/immersive-mobile.png:Android 沉浸正文；command:unittest+shell+compose+verify-reader-ui+verify reader-public+harness:pass；diff:reader-ui/index.html,styles.css,app.js,manifest.webmanifest,icons,scripts/verify-reader-ui.sh:Android app-like reader

### [2026-07-17 16:29] - 微信消息原文回填与 Cloudflare Workflow 调度链

- 做了什么：核对同步助手 Vault 后确认旧同步器只导入微信消息里的外链，不导入消息原文。新增按消息块拆分、稳定内容指纹、安全 HTML 渲染和独立状态映射；把 140 条微信消息回填 Reader。新增 Cloudflare Workflow：5 分钟 `sync`、每小时第 17 分钟 `start`、持久轮询与指数退避；Caddy 增加 Access JWT + 独立调度密钥的机器入口，刷新控制端增加不触发 WeRSS 的同步动作。补齐 WeRSS 原生 Cron/本机 LaunchAgent 安全切换与回滚脚本。
- 验证结果：140 条消息、140 个唯一 key、空内容 0；live Readeck 首轮新入 140、失败 0，第二轮新入 0；本机模拟 Access Service Token 经 Reader Caddy 触发 `syncing_reader -> complete`，回环端口不变。修复同步助手外链先于 WeRSS 出现时缺正式来源标签的升级路径后，14 个公众号、160 篇可用正文全部且唯一映射。23 个 Python 单测、4 个 Node Workflow 测试、Shell、Compose、Caddy validate、Reader/WeRSS 公网安全验证、Harness 和 Wrangler 4.111.0 dry-run 通过。当前 Wrangler 身份无 Access policy 写权限，未部署会立即启用的 live schedule，也未停用本机两个兜底。
- 下一步：用具备 Access 写权限的控制台/API 创建 Service Token 和 `Service Auth` policy；设置三个 Worker secret，部署并验证一次 `sync`/`start`，再停用 WeRSS 原生 Cron 与本机 5 分钟 LaunchAgent。
- 证据：command:reading-sync live + Readeck API:140/140 imported、rerun created 0；command:local Caddy machine smoke:syncing_reader -> complete；command:python/node/shell/compose/caddy/wrangler dry-run:pass；diff:reading-sync、refresh-control、Caddy、Workflow、tests、docs
- No-commit reason：工作树已有本轮开始前的 Reader UI、同步助手与任务账本重叠改动；未替用户混合 stage/commit，Harness 保持 dirty-state 警告。

### [2026-07-17 15:36] - Reader 划线消失、黄色全选与纯划线修复

- 做了什么：沿 Readeck 压缩后的原生 annotator 控制器定位三处交互缺陷：视觉勾选透明 radio 不会更新内部 `colorValue`；选区从正文拖出时会被扩到正文末尾；真实鼠标拖选后的 click 会在 textarea 过早聚焦后误关弹窗。改为触发原生透明选项、在原生微任务前拒绝越界或覆盖近半篇的选区、用 Custom Highlight 保留淡绿待确认划线，并延后 48ms 自动聚焦。笔记可留空，Enter 确认纯划线或划线加笔记，Shift+Enter 只换行。
- 验证结果：真实鼠标拖选 13 字后 annotator 保持 `display:flex`、textarea 已聚焦、待确认 Highlight 为 1；空笔记 Enter 的拦截请求为 `color:none,note:""`。笔记场景 Shift+Enter 后请求数仍为 0且 textarea 保留换行，随后 Enter 请求为 `color:none,note:"一条笔记\n"`。构造从正文跨到 body 的 3718 字误选后选区归零、annotator 不显示且无 pending Highlight。左栏收起后正文 716→968px，滚轮 0→680、PageDown →1249，全屏为 1440×900。全部 POST/PATCH 在浏览器层拦截，未写真实数据。
- 下一步：等待用户在公网 Reader 实际拖选确认手感；项目级 72 小时/7 天、WeRSS 原生 ARM64 和最终人工确认门禁不变。
- 证据：command:Playwright real mouse drag/empty-note/note/unsafe-range/layout/scroll/fullscreen probes:pass；diff:reader-ui/app.js,embed.css,index.html,scripts/verify-reader-ui.sh:annotation interaction fix

### [2026-07-17 14:59] - Reader 滚动、性能与沉浸阅读修复

- 做了什么：用真实 Playwright 构造正文滚轮红线，确认 iframe 有 5170px 内容但滚轮和 PageDown 后仍停在 0；修复 iframe 纵向输入链，加入鼠标、PageDown/PageUp、方向键、空格、Home/End 支持。把初始时间线从全部 218 篇改为 60 篇渐进加载，移除滚动面板 blur，加入 hover/focus 正文预取和无闪烁骨架。新增公众号栏折叠、本地记忆、应用沉浸模式与浏览器全屏。批注框隐藏 5 个颜色选项、标签和按钮，默认透明划线，自动聚焦输入框，Enter 调用 Readeck 原生保存，Shift+Enter 换行。
- 验证结果：同一浏览器红线由“滚轮后 0”变为 720；折叠后正文宽度 556→808，浏览器全屏后正文为 1280×720 且两栏隐藏；快速批注颜色区/按钮 `display:none`、透明项选中、Enter 命中原生 create。390×844 的外层 `scrollWidth=390`，iframe 无横向溢出且可滚动。18 个 unittest、Node、Shell、Compose、diff、`verify-reader-ui.sh`、公网 Access 回归和 Harness 通过。`verify.sh --local` 只在既有 WeRSS x86_64/Rosetta 硬门禁失败，与本切片无关且继续保留为 P1 residual。
- 下一步：等待用户在公网 Reader 实际阅读确认手感；项目级 72 小时/7 天、WeRSS 原生 ARM64 和最终人工确认门禁不变。
- 证据：command:Playwright iframe scroll/layout/annotation/mobile probes:0→720、60 DOM、fullscreen true、Enter native create、390px no overflow；command:node+shell+compose+diff+18 unittest+verify-reader-ui+reader-public+harness:pass；diff:reader-ui/index.html,styles.css,embed.css,app.js,scripts/verify-reader-ui.sh:immersive reader slice

### [2026-07-17 14:22] - 笔记同步助手接入 Reader 独立分组

- 做了什么：核对第三方官方教程和 v3.1.2 安装包，完成静态安全审计后在独立 `obs-wechat-syn` Vault 安装并启用插件；配置专用文章、微信消息、附件与图片目录、5 分钟自动同步和启动同步。为避开 macOS LaunchAgent 对 Documents 的后台权限限制，将完整 Vault 迁移到 `/Users/summer/Obsidian/obs-wechat-syn`。扩展 `reading-sync`，只读取 Markdown 外部链接并在 Reader 建立“Obsidian同步助手”虚拟分组，不改 WeRSS SQLite。
- 验证结果：插件密钥已配置但未进入 Git，配置文件权限 `600`；初次云同步完成 195 篇，当前落盘 69 个 Markdown 和 514 张图片，图片补齐由插件继续重试。同步器最终从消息与文章笔记提取 74 个真实文章链接，Reader 74/74 loaded；清理导入调试期间的 14 个重复副本和 66 个图片 CDN 条目。增加原始 URL 持久映射、重定向幂等和图片过滤后，重复运行扫描 85 条引用时新增 0、补标签 0、失败 0。Playwright 实页点击分组后显示 74 张卡片；11 个同步单测、Node、Shell、Compose、Reader UI、公网 Access、diff 与 13 个公众号/148 篇合格正文映射检查通过。
- 下一步：第三方插件按 5 分钟周期继续补齐剩余图片；项目级 72 小时/7 天、WeRSS 原生 ARM64 和最终人工确认门禁不变。
- 证据：command:plugin checksum/static audit + Obsidian config inspection:enabled、key configured、mode 600、300s/startup；command:reading-sync idempotency rerun:85 scanned、0 created、0 labeled、0 failed；command:Readeck API:74 helper bookmarks、74 loaded；command:Playwright Reader filter:Obsidian同步助手 74、74 article cards；command:python3 unittest:11 pass

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

### [2026-07-16 15:53] - 账号迁移与 GitHub 公开发布

- 做了什么：按用户要求把当前 WeRSS 管理登录迁移为 `summer`，本机密码单独保存在 ignored `.env`；将仓库从单机配置泛化为可公开复用模板，域名、管理员用户名、Obsidian Inbox 和 LaunchAgent HOME 均可配置；新增酷炫 README、部署指南、Security Policy、MIT License、GitHub CI、账号迁移脚本和 Readeck Token 安全保存脚本；创建公开 GitHub 仓库 `summerchaserwwz/wechat-rss-reader`。
- 验证结果：新 WeRSS 账号实际登录成功，旧用户名拒绝；本机 Compose 和 `.env.example` Compose 均通过；14 个 unittest、Shell、Node、4 个 plist、Reader UI、公网 Reader/WeRSS、README 22 个本地链接、Harness 与秘密扫描通过；最终备份 `20260716-155105` 和独立恢复 `20260716-155153` 通过，恢复出 118 篇文章、收藏、4 篇含批注、双 Access Caddy、主动刷新和同步状态。提交 `f414553` 已推到功能分支和默认 `main`；远端 README、部署、安全、Reader 和同步文件已读取核验，两个 GitHub CI run 均成功。
- 下一步：72 小时/7 天时间门禁继续；完成后执行最终对抗审查、walkthrough 和人工确认。
- 证据：repository:https://github.com/summerchaserwwz/wechat-rss-reader；commit:f414553；actions:29481551970,29481511814 success；command:secret scan + full test matrix + backup/restore:pass

### [2026-07-20 04:36] - Android 极光磨砂、作者谱线与归档操作

- 做了什么：手机来源/文章列表改为无圆角外壳的半透明极光磨砂，内部保持 8px 紧凑行；公众号名称稳定哈希到六组低饱和彩虹色，文章行加入两端渐隐的柔和作者谱线；正文右上角新增归档，结尾收藏/归档改为等宽并排。
- 验证结果：Playwright 412×915 实机尺寸验证来源、时间线、正文顶栏和结尾操作；同一作者颜色稳定，外层 `border-radius=0`、`backdrop-filter=blur(34px)`；原失败点击坐标仍命中透明滚动层，但已转发为 `PATCH /api/bookmarks/{id}`，载荷为 `is_archived=true, read_progress=100`；HTTPS Origin 同值 PATCH 返回 200。23 个 unittest、Reader UI、公网 Reader、Shell/Node/Compose、Harness 均通过。
- 下一步：整个项目时间门禁继续。
- 证据：commit:ae47a46；actions:29702882151 success；screenshots:output/playwright/android-reader/aurora-spectrum-{sources,timeline,reader-end-actions}.png；command:Playwright archive regression + curl HTTPS-Origin PATCH + verify-reader-ui + verify --reader-public + harness:pass

### [2026-07-20 06:41] - Taste 无卡片彩谱列表纠偏

- 做了什么：按真实手机截图撤除文章行与公众号行的描边圆角卡片，改为开放式连续列表、彩色渐隐分隔和柔和左侧谱线；作者色从六组扩展为十六组，并在当前十六个来源中做碰撞消解；静态资源提升到 CSS v25 / JS v30，避免手机继续命中同版本旧缓存。
- 验证结果：Playwright 412×915 实测文章列表右滑进入公众号列表、公众号列表左滑返回文章列表；当前 16 个来源得到 16 个不同 tone；来源外壳、文章外壳、来源行和文章行圆角均为 0px，文章行边框为 0px。23 个 unittest、Reader UI、公网 Reader、Shell/Node/Compose、Harness 均通过。
- 提交边界：只提交 `reader-ui/{app.js,index.html,styles.css}` 与 `scripts/verify-reader-ui.sh`；本文件已有其他未提交改动，因此本条随工作区保留，不混入 UI 提交。
- 证据：commit:f649ec6；actions:29706629156 success；screenshots:output/playwright/android-reader/taste-rainbow-{sources,timeline}-final-v2.png；command:Playwright swipe/computed-style audit + verify-reader-ui + verify --reader-public + harness:pass

### [2026-07-20 06:49] - 干净底色与柔和纯色谱线

- 做了什么：移除手机底色的极光径向渐变、文章与来源行的彩色铺底、底栏彩色短线；保留十六色作者 Tag，将来源与文章谱线改为 2px 低透明度纯色短线，无渐变、无光晕；CSS 缓存版本提升到 v26。
- 验证结果：Playwright 412×915 计算样式确认 `bodyBackgroundImage=none`、`rowBackgroundImage=none`、`lineBackgroundImage=none`、`lineBoxShadow=none`、线宽 2px/透明度 0.46；文章与来源截图均为干净深色底。23 个 unittest、Reader UI、公网 Reader、Shell/Node/Compose、Harness 均通过。
- 提交边界：本条随已有 dirty Harness 主账本保留；Git 提交只包含 Reader 样式、缓存版本和相应回归断言。
- 证据：screenshots:output/playwright/android-reader/clean-frost-{timeline,sources}.png；command:Playwright computed-style audit + verify-reader-ui + verify --reader-public + harness:pass

### [2026-07-20 07:14] - 正文左滑返回与手机纯划线闭环

- 做了什么：正文返回手势改为从右向左滑动，超过 72px 后保存当前进度并回到文章列表；修正重载后遗留 Reader history 导致回到旧文章的问题。手机阅读设置新增划线模式，拖选文字自动保存为绿色虚线；点按已有划线直接删除并就地还原正文，不再弹笔记框。划线模式中间区域优先文字选择，只在最右侧 32px 保留返回手势。
- 验证结果：Playwright 412×915 实测左滑进入 ready 状态并回到 `timeline`，history 同步归一为列表；手机设置入口可开启划线模式并自动收起；模拟删除精确命中当前 annotation、DOM 原位解除包裹且无 popover。经 Reader Access 实际链路创建一条临时纯划线后，DELETE 返回 204 并完成清理。23 个 unittest、Reader UI、公网 Reader、Shell/Node/Compose、Harness 均通过。
- 提交边界：本条随已有 dirty Harness 主账本保留；Git 提交只包含 Reader UI 与对应验证脚本。
- 证据：command:Playwright swipe/history/selection-conflict/delete audit；command:Reader Access temporary annotation create/delete 204；command:unittest + verify-reader-ui + verify --reader-public + harness:pass

### [2026-07-21 14:40] - Cloudflare 免费调度上线与长队列修复

- 做了什么：创建 Reader 专用 Access Service Token 与 `Service Auth` policy，设置三个 Worker secret 并部署 `wechat-reader-sync-scheduler`。Cloudflare 免费计划不支持 Workflow 原生 schedule，改用两个免费 Cron Trigger 创建幂等 Workflow 实例：每 5 分钟 `sync`，每小时第 17 分钟 `start`。控制端把总等待上限提升到 6 小时，并以队列进展而非固定 30 分钟判断停滞；普通失败不再永久暂停。微信授权失效保留 `auth_required`，网页刷新会拉起二维码，扫码后继续抓取。WeRSS 原生 Cron 已停放到闰年表达式，保留机器和手工受保护调用。
- 验证结果：Access Service Token 经 Tunnel、Reader Caddy 和 `127.0.0.1:8787` 返回 200；live `start` Workflow `dd4ee30a-a036-46a1-83e8-bc1ff2105c2d` 持续轮询 5 分钟后成功，新增 2 篇文章；后续自动 `start` 实例与 5 分钟 `sync` 连续成功。Reader 从 1083 增至 1089。12 个刷新控制 Python 测试、7 个 Worker Node 测试、Reader UI、本机/公网 Access、WeRSS 公网与 Harness 通过。临时 Access 管理 API Token 已从 Cloudflare 和本机撤销；运行时 Service Token/policy 文件为 600。
- residual：`verify.sh --local` 仍会因上游 WeRSS arm64 manifest 实际装入 AMD64 filesystem 而返回失败；该已知 Rosetta 性能风险不影响本次 Cloudflare 调度功能。72 小时/7 天观察与最终人工确认仍需真实时间。
- 证据：command:Wrangler deploy/instances describe；command:machine Access POST 200；command:task queue 8→0；command:verify-reader-ui/reader-public/werss-public/harness；command:sqlite/Reader counters。

### [2026-07-21 14:20] - Reader 首屏按需分页与即时归档返回

- 做了什么：首屏从“追随全部书签/批注分页后再渲染”改为只读取最新 100 篇书签并立即呈现；列表到达底部或进入尚未命中的来源/筛选时才继续请求下一页。批注首批独立读取，后续空闲补齐。归档改为本地乐观更新后即时关闭正文并回到列表，远端 PATCH 失败才回滚。JavaScript 资源版本提升到 v37，避免移动端命中旧缓存。
- 验证结果：隔离浏览器重放 1,100 篇、每页 120ms 延迟时，修复前首屏需要 12 个书签分页请求；修复后首屏稳定为 60 行和 1 个书签请求，显式加载后才产生第 2 个请求。390×844 无横向溢出、列表可滚动；手机尺寸下打开第一篇并归档后，`mobileView=timeline`、正文隐藏、列表直接显示第二篇。现有 Reader UI 静态与模拟 Access 运行时验证通过，运行中 Reader Caddy 已提供新逻辑。
- 证据：command:Playwright fixture pagination/mobile archive regression；command:./scripts/verify-reader-ui.sh；command:node --check reader-ui/app.js；command:bash -n scripts/verify-reader-ui.sh。

### [2026-07-21 15:00] - Reader Markdown 排版预设

- 做了什么：右侧正文新增可持久化的三套排版预设，桌面顶栏和手机“阅读设置”均可切换。深色专注保留紧凑低干扰阅读，石墨笔记使用宋体型正文和较舒展行距，浅色稿纸采用低对比纸面、较窄行宽和安静的编辑器式层级。预设同步调整 Markdown 标题、段落、引文、代码块、表格、图片边界与批注颜色，不改变原有划线、滚动或阅读进度逻辑。
- 验证结果：隔离真实文章结构的 iframe 中确认预设属性会同步写入父界面与正文文档；石墨笔记正文宽度 768px、宋体型字体和 1.8 行距生效，浅色稿纸宽度 704px、纸面背景和顶栏选择器深色文字均通过实际截图复核。390×844 手机设置可切换预设，正文无横向溢出且父级滚动保持可用。Reader UI 静态与模拟 Access 运行时验证通过。
- 证据：command:Playwright desktop/mobile preset switch and computed-style audit；screenshot:.playwright-cli/page-2026-07-21T15-00-09-759Z.png；command:./scripts/verify-reader-ui.sh；command:node --check reader-ui/app.js。

### [2026-07-22 01:33] - 微信视频与动态媒体原文回退

- 做了什么：排查 WeRSS 原始正文、Readeck 归档和 Reader CSP 后，确认已缓存 GIF 可同源播放，而微信脚本驱动的视频/视频化动图在 `content_html` 净化阶段丢失。桌面正文顶栏新增“原文”，手机“阅读设置”新增“打开微信原文，播放视频和动图”；只接受 `http/https` URL，并用 `target=_blank` 与 `rel=noopener` 安全打开原始文章。
- 验证结果：1167 个 Readeck 归档中检出 254 个 GIF，抽样 Reader 资源返回 `200 image/gif`；WeRSS 原始正文有 186 篇 `<video>`、净化正文为 0 篇。Playwright 在真实 Reader 数据上验证桌面和 390×844 手机入口均打开对应 `mp.weixin.qq.com` 标签页，且没有“浏览器阻止新窗口”误报。静态资源提升为 JS v40，运行中 Reader Caddy 已回读新版本。
- 证据：command:SQLite raw/sanitized media counts + archive MIME probe；command:Playwright desktop/mobile original-media action；screenshot:.playwright-cli/page-2026-07-21T17-32-11-646Z.png；command:node --check + bash -n + ./scripts/verify-reader-ui.sh。

### [2026-07-22 16:24] - 正文首屏原文媒体入口

- 做了什么：把原文媒体入口从顶栏和手机设置进一步前移到每篇正文标题后的第一屏；微信文章明确提示视频和视频化动图需在原文播放，普通 GIF 继续留在阅读版。非微信网页使用通用“打开原网页”文案。入口只接受现有 `http/https` 原始地址，使用新窗口与 `noopener`，不放宽 Reader 的外域脚本或媒体 CSP。
- 验证结果：回归检查先稳定失败于“正文开头没有原文媒体入口”，实现后通过。最新 WeRSS 1048 篇中原始 HTML 含视频 190 篇、优先入库 HTML 为 0；Readeck 归档包含 263 个 GIF、视频文件为 0，GIF 抽样经 Reader 返回 `200 image/gif`。Playwright 在真实微信文章 iframe 中确认提示位于标题之后、正文之前，链接准确指向对应 `mp.weixin.qq.com` 原文；412px 手机截图无横向溢出。JavaScript 提升到 v41，嵌入样式提升到 v16。
- 证据：command:WeRSS SQLite media count + Readeck ZIP inventory + Reader GIF MIME probe；command:Playwright real iframe snapshot；screenshot:output/playwright/android-reader/.playwright-cli/page-2026-07-22T08-22-24-372Z.png；command:node --check + ./scripts/verify-reader-ui.sh + git diff --check。

### [2026-07-22 17:35] - 新版双端演示素材与公众号更新稿

- 做了什么：基于真实 Reader 数据完成桌面版与 390×844 手机版的新版截图和完整操作录屏，覆盖三栏阅读、全屏、排版预设、图片/GIF、视频原文入口与手机阅读设置；使用公众号技术文章写作规范整理《我把公众号阅读器重做了一遍》，正文内嵌演示图片并链接双端视频，同时从 README 增加统一入口。
- 验证结果：桌面 MP4 为 1440×900、60.2 秒，手机 MP4 为 390×844、52.87 秒；两段 H.264 视频均完成逐帧解码检查，全部文章相对媒体链接存在，截图尺寸与视觉内容经联系表复核。Reader UI、29 个 Python 单元测试、7 个 Cloudflare Worker 测试、Shell/Compose/Harness 均通过；`verify.sh --local` 仅保留既有 WeRSS AMD64/Rosetta 架构门禁。
- residual：本次只生成公众号成稿，不代替人工登录公众号后台发布；72 小时/7 天观察与最终人工确认仍需真实时间。
- 证据：article:docs/wechat/公众号阅读器新版更新实录.md；media:docs/media/reader-v2/；command:ffprobe + ffmpeg full decode + link existence audit + project verification matrix。
