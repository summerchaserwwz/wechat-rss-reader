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
- P1：Cloudflare 账号授权已完成，但 Zero Trust Free 激活页要求勾选未来超额用量收费授权；等待用户对该金融授权作明确选择。Tunnel/DNS 和公网入口在 Access 建立前保持未发布。
- P1：公众号资格/授权、12 个来源和每小时任务已完成；72 小时/7 天近实时观察仍是时间门禁。
- P2：Obsidian UI 截图已完成；Base 实机列验证仍待最终收口。
- P2：Docker Desktop 为 Caddy 发布回环端口需要非 internal bridge，因此 Caddy 具备出站能力；已用只读根、`no-new-privileges`、仅保留 `NET_BIND_SERVICE` 和固定无动态上游的 Caddyfile 降低风险。

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
