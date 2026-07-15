# Folo 风格 Reader UI 差距审计

审计日期：2026-07-15

基线提交：`14f27c5`

参考：Folo Desktop `1.11.0` 的信息架构、Petdex 的近黑/靛蓝/磨砂视觉语言、当前公网 Reader 实机页面。只借鉴布局与设计语言，不复制品牌资产。

## 基线计数

| 项目 | 当前值 | 证据 |
| --- | ---: | --- |
| 启用公众号 | 12 | `data/we_mp_rss.db` 只读查询 |
| WeRSS 文章 | 107 | `data/we_mp_rss.db` 只读查询 |
| Readeck 文章 | 103 | `readeck-data/data/db.sqlite3` 只读查询 |
| 自动抓取 | `17 * * * *` | WeRSS `message_tasks` |
| Reader 同步 | 300 秒 | `com.summer.wechat-rss-reading-sync.plist` |
| Reader 顶部 Tab | 6 | 公网 Reader 实机 DOM 与 `reader-ui/index.html` |

微信没有文章 Webhook，因此本系统的“近实时”定义为：每小时第 17 分钟自动抓取，正文就绪后由 5 分钟同步任务进入 Reader；不宣称秒级更新。

## 八类差距

| 类别 | 当前证据 | Folo 参考 | 目标行为 | 实现位置 | 验收证据 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 布局 | 原公网 Reader 是侧栏加整页列表 | Folo Desktop 使用来源、时间线、内容持续并列的高密度工作区 | 桌面固定为来源栏 220–260px、时间线 360–440px、正文占剩余宽度；移动端逐级进入 | `reader-ui/`、`Caddyfile.reader` | 公网 Chrome 实机、`verify-reader-ui.sh` | 已实现 |
| 顶部导航 | 原有入口分散在 Readeck 左侧 | Folo 把内容类型和未读筛选放在高可见位置 | 顶部固定“收件箱、未读、收藏、划线、高价值、订阅”，显示数量并支持 1–6 快捷键 | `reader-ui/app.js`、`reader-ui/styles.css` | DOM、快捷键代码与实机页面 | 已实现 |
| 收藏 | 原收藏动作藏在 Readeck 行尾或正文工具栏 | Folo 时间线保留直接操作 | 每行和正文工具栏都显示星标；单击或 `S` 切换，失败回滚，刷新后保留 | `reader-ui/app.js` | Readeck API 与实机页面 | 已实现 |
| 已读状态 | 原列表缺少明确未读/阅读中反馈 | Folo 使用橙色未读点和独立未读视图 | `0 / 1–99 / 100` 分别显示未读、阅读中、已读；80% 自动已读，并可手工反转 | `reader-ui/app.js` | API 持久化、计数即时更新 | 已实现 |
| 订阅追加 | 新增公众号必须由受保护的本机管理端完成 | Folo 来源栏直接显示订阅与未读计数 | “订阅”页展示来源、文章数、未读、最近抓取和健康；部署 Mac 可打开本机 WeRSS，公网不暴露管理端 | `reader-ui/`、`scripts/reading-sync.py` | 状态 JSON 已通过；N→N+1 仍为人工门禁 | 部分完成 |
| 抓取反馈 | 原 Reader 不显示计划和最后同步 | Folo 时间线有刷新和即时状态反馈 | 明示每小时抓取、5 分钟同步、最后成功时间、最新文章与异常状态 | `scripts/reading-sync.py`、`reader-ui/app.js` | 2.16 分钟真实样本、三次完整小时周期；72h/7d 待观察 | 部分完成 |
| 价值标签 | 原价值评分和主题只能进入 Obsidian 后填写 | Folo 的信息流强调筛选和重要性排序 | 正文工具栏设置 1–5 价值与主题；使用 `价值/N`、`主题/名称` Readeck 标签；高价值页显示 4–5 | `reader-ui/app.js`、`scripts/reading-sync.py`、公众号精选 Base | 标签 API、Obsidian `reader_value/reader_tags` | 已实现 |
| 移动端 | 原移动端缺少三栏到单栏的明确导航状态 | Folo 移动端按来源、时间线、正文逐级进入 | 390px 下单栏，显示明确返回按钮；收藏、已读、价值和批注仍可触达 | `reader-ui/styles.css`、`reader-ui/app.js` | 既有 390×844 实机验收、响应式规则 | 已实现 |

## Petdex 视觉适配

- 画布：近黑底色叠加靛蓝主环境光与极弱橙色状态光。
- 面板：只对来源栏、顶部导航、时间线和正文外壳使用半透明磨砂，正文纸面保持稳定对比度。
- 边界：使用低对比冷色细边框、顶部高光和轻阴影，不复制 Petdex 的 Logo、角色卡片或品牌素材。
- 语义色：靛蓝用于导航与当前选择；橙色只保留给未读、收藏和价值等状态反馈。

## API 可行性结论

固定 Readeck `0.22.3` 已核验以下受支持 API：

- `PATCH /api/bookmarks/<id>`：`is_marked`、`read_progress`、`labels`、`add_labels`、`remove_labels`。
- `GET /api/bookmarks/<id>/article`：返回带现有划线标记的正文 HTML。
- `GET /api/bookmarks/annotations`：返回批注及其 `bookmark_id`。
- 批注创建、更新、删除由 Readeck 原生阅读页继续承担，避免在本项目复制其 DOM selector 算法。

公网 Reader 继续使用 Cloudflare Access 身份映射和同源 Readeck 会话；浏览器不接收 API Token。WeRSS 订阅写操作继续只存在于 `127.0.0.1:8001`。
