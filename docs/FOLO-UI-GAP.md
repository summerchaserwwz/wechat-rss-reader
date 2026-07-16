# Folo 风格 Reader UI 差距审计

审计日期：2026-07-15

基线提交：`14f27c5`

参考：Folo Desktop `1.11.0` 的信息架构、Petdex 的近黑/科技蓝/磨砂视觉语言、当前公网 Reader 实机页面。只借鉴布局与设计语言，不复制品牌资产。

## 基线计数

| 项目 | 当前值 | 证据 |
| --- | ---: | --- |
| 启用公众号 | 12 | `data/we_mp_rss.db` 只读查询 |
| WeRSS 文章 | 124 | `data/we_mp_rss.db` 只读查询 |
| Readeck 去重文章 | 118 | `readeck-data/data/db.sqlite3` 只读查询 |
| 自动抓取 | `17 * * * *` | WeRSS `message_tasks` |
| Reader 同步 | 300 秒 | `com.summer.wechat-rss-reading-sync.plist` |
| Reader 顶部 Tab | 6 | 公网 Reader 实机 DOM 与 `reader-ui/index.html` |

微信没有文章 Webhook，因此本系统的“近实时”定义为：每小时第 17 分钟自动抓取，正文就绪后由 5 分钟同步任务进入 Reader；不宣称秒级更新。

## 八类差距

| 类别 | 当前证据 | Folo 参考 | 目标行为 | 实现位置 | 验收证据 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 布局 | 原公网 Reader 是侧栏加整页列表 | Folo Desktop 使用来源、时间线、内容持续并列的高密度工作区 | 桌面固定为来源栏 220–260px、时间线 360–440px、正文占剩余宽度；移动端逐级进入 | `reader-ui/`、`Caddyfile.reader` | `images/09-reader-folo-inbox.png`、`images/14-reader-mobile.png`、`verify-reader-ui.sh` | 已实现 |
| 顶部导航 | 原有入口分散在 Readeck 左侧 | Folo 把内容类型和未读筛选放在高可见位置 | 顶部固定“收件箱、未读、收藏、划线笔记、高价值、订阅”，显示数量并支持 1–6 快捷键 | `reader-ui/app.js`、`reader-ui/styles.css` | `images/10-reader-top-tabs.png`、快捷键静态断言 | 已实现 |
| 收藏 | 原收藏动作藏在 Readeck 行尾或正文工具栏 | Folo 时间线保留直接操作 | 每行和正文工具栏都显示星标；单击或 `S` 切换，失败回滚，刷新后保留 | `reader-ui/app.js` | `images/11-reader-one-click-favorite.png`；收藏 1→2、刷新仍为 2、回滚为 1 | 已实现 |
| 已读状态 | 原列表缺少明确未读/阅读中反馈 | Folo 使用橙色未读点和独立未读视图 | 打开后自动进入阅读中；`0 / 1–99 / 100` 分别显示未读、百分比、已读；80% 自动已读，并可手工反转 | `reader-ui/app.js` | 真实样本打开后出现进度；滚动 85% 自动回到 100；刷新仍显示“标为未读” | 已实现 |
| 订阅追加 | 新增公众号必须由受保护的管理端完成 | Folo 来源栏直接显示订阅与未读计数 | “订阅”页展示来源、文章数、未读、最近抓取和健康；新增弹窗直达独立 Access 保护的公网 WeRSS，部署 Mac 保留本机备用入口 | `reader-ui/`、`Caddyfile.werss-public`、Cloudflare Tunnel | 桌面/手机均可打开 `werss.sumerchaser.top`；匿名根/API 被 Access 拦截；授权 Chrome 到达 WeRSS 原生登录页 | 已实现 |
| 抓取反馈 | 原 Reader 不显示计划和最后同步 | Folo 时间线有刷新和即时状态反馈 | 明示每小时抓取、5 分钟同步、最后成功时间、最新文章与异常状态；允许受保护地手工检查新文章 | `scripts/reading-sync.py`、`scripts/reader-refresh-control.py`、`reader-ui/app.js` | `images/12-reader-subscriptions.png`；真实点击完成全部公众号抓取与 reading-sync；4 篇/3 来源发布到 Reader 为 15–41 分钟 | 已实现 |
| 价值标签 | 原价值评分和主题只能进入 Obsidian 后填写 | Folo 的信息流强调筛选和重要性排序 | 正文工具栏设置 1–5 价值与主题；使用 `价值/N`、`主题/名称` Readeck 标签；高价值页显示 4–5 | `reader-ui/app.js`、`scripts/reading-sync.py`、公众号精选 Base | `images/13-reader-value-tags.png`；刷新后高价值 1；Obsidian 受控字段与人工字段摘要稳定 | 已实现 |
| 移动端 | 原移动端缺少三栏到单栏的明确导航状态 | Folo 移动端按来源、时间线、正文逐级进入 | 390px 下单栏，显示明确返回按钮；收藏、已读、价值和批注仍可触达 | `reader-ui/styles.css`、`reader-ui/app.js` | 既有 390×844 实机验收、响应式规则 | 已实现 |
| 划线笔记 | Readeck 原生批注弹层居中且遮挡正文，缺少集中摘录视图 | 长文阅读器应让摘录可回看、可定位 | 批注框自动避让选区；保存后定位原文并显示笔记卡；顶部按条集中摘录、批注、来源 | `reader-ui/app.js`、`reader-ui/embed.css` | `images/05-reader-划线批注.png`、`images/15-reader-划线笔记与字号.png`；真实新增/定位/删除回归 | 已实现 |
| 字号与导出 | 原正文不可快速调字号，划线没有独立 Markdown 出口 | 阅读设置与摘录出口应常驻但低干扰 | 右侧 `A+ / A-` 持久字号；划线笔记下载 Markdown，或选择本机 Obsidian 目录直接写入 | `reader-ui/` | 字号 17→18px 持久化；3 条真实摘录导出含 3 个来源、链接和笔记 | 已实现 |

## Petdex 环境光与 Apple 控件适配

- 画布：采用 Petdex 首页的上部钴蓝环境光、下部近黑画布关系，不再叠加分散的多色光斑。
- 面板：来源栏和顶部导航使用 22px blur 的半透明磨砂；时间线与正文外壳降低透明度，避免长文阅读时背景干扰。
- 边界：大面板统一 20px 圆角，文章卡统一 13px 圆角，操作按钮统一胶囊形；深度主要由近黑表面阶梯、细边框与顶部内高光形成。
- 字体：界面和嵌入正文优先使用 macOS 的 SF Pro 与苹方；正文改为无衬线、较高行距，并为引用、代码块、图片和文本选区提供一致样式。
- 语义色：钴蓝只用于当前选择和主操作；橙色只用于未读、收藏和价值；淡绿虚线只用于临时选区、持久划线和成功状态。
- 交互控件：按 Apple 控件语言采用 SF Pro/苹方、18px 圆角、胶囊按钮、`saturate(180%) blur(20px)` 磨砂与克制阴影；保持阅读器所需的高密度三栏，而不是复制营销页布局。
- 边界声明：只借鉴视觉语言，不复制 Petdex 或 Apple 的 Logo、角色卡片、文案与品牌素材。

## 自动链路延迟样本

以下样本使用 `observations/readeck-stability.tsv` 在当次自动同步后记录的 Reader 加载时间，并与 WeRSS 文章发布时间交叉计算；没有把后续人工收藏、已读或标签修改时间当作首次出现时间。

| 公众号 | 发布时间（Asia/Shanghai） | Reader 出现 | 延迟 |
| --- | --- | --- | ---: |
| 卡尔的AI沃茨 | 07-15 09:52 | 07-15 10:21 | 29.4 分钟 |
| 新智元 | 07-15 13:32 | 07-15 13:47 | 15.5 分钟 |
| 量子位 | 07-15 14:42 | 07-15 15:22 | 40.2 分钟 |
| 量子位 | 07-15 16:55 | 07-15 17:19 | 24.6 分钟 |

样本覆盖 4 篇、3 个公众号，全部不超过 70 分钟。微信没有 Webhook，本结果只证明当前每小时抓取加 5 分钟同步的近实时目标，不代表秒级更新。

## API 可行性结论

固定 Readeck `0.22.3` 已核验以下受支持 API：

- `PATCH /api/bookmarks/<id>`：`is_marked`、`read_progress`、`labels`、`add_labels`、`remove_labels`。
- `GET /api/bookmarks/<id>/article`：返回带现有划线标记的正文 HTML。
- `GET /api/bookmarks/annotations`：返回批注及其 `bookmark_id`。
- 批注创建、更新、删除由 Readeck 原生阅读页继续承担，避免在本项目复制其 DOM selector 算法。

公网 Reader 继续使用 Cloudflare Access 身份映射和同源 Readeck 会话；浏览器不接收 API Token。WeRSS 管理通过独立 Access 应用/AUD 暴露专用 Caddy，原始服务仍只存在于 `127.0.0.1:8001`。
