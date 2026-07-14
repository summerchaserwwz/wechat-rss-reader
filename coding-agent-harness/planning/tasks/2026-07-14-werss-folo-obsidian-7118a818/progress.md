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
- P1：公众号运营资格、微信扫码、3 个试验源、Funnel 首次批准、Folo 登录与 72 小时/7 天观察仍是人工/时间门禁。
- P1：独立备份恢复已通过，但完成真实微信授权后仍需复验 `key.lic`、登录用户与授权状态。
- P2：Docker Desktop 为 Caddy 发布回环端口需要非 internal bridge，因此 Caddy 具备出站能力；已用只读根、`no-new-privileges`、仅保留 `NET_BIND_SERVICE` 和固定无动态上游的 Caddyfile 降低风险。

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
