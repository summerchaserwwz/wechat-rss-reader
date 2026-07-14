# WeRSS + Folo + Obsidian 公众号阅读系统

本仓库把微信公众号文章接入一条可维护的阅读链路：

```text
公众号运营者授权 -> 本机 WeRSS -> 只读 Caddy -> Tailscale Funnel
-> Folo 浏览和筛选 -> Obsidian Archive 收件箱 -> 批注、双链与知识提升
```

管理后台始终只监听 `127.0.0.1:8001`。公网只暴露随机长路径下的 `GET/HEAD /feed/*.atom`；登录页、API、导出接口和其他方法全部返回 `404`。

## 已锁定边界

- WeRSS 使用 SQLite，本机 Docker 部署。
- WeRSS 镜像固定为用户指定摘要。该摘要虽然声明 `linux/arm64`，但上游构建错误使其实际文件系统仍为 AMD64；当前会通过 Rosetta 运行，尚未满足原生 ARM64 验收。
- Caddy 固定为 `2.11.4-alpine` 的多架构摘要。
- Folo 是云服务客户端，不自托管；Folo 负责浏览和筛选，不承担永久划线批注。
- 精读、划线、批注、双链和知识提升统一在 Obsidian 完成。
- 不使用 WeRSS 的 `EXPORT_MARKDOWN` 自动导出能力。
- 固定镜像只包含 WebKit 浏览器运行时，因此实际配置为 `BROWSER_TYPE=webkit`。若强制写成 Firefox，配置会与镜像能力不一致，正文抓取可能失败。
- WeRSS 启动时会打印环境变量。不要公开或转发 `docker compose logs`；其中可能包含 Bootstrap 密码、授权加密键和随机 Feed 前缀。

### 已知上游 ARM64 阻塞

固定 WeRSS 摘要的三个上游 Dockerfile 都使用了 `FROM --platform=$BUILDPLATFORM`。在 AMD64 CI runner 上发布多架构镜像时，arm64 与 amd64 manifest 因而复用了同一组 AMD64 layer；`uname -m`、`dpkg` 和 ELF 检查均能复现。Docker Desktop 本身没有问题，官方 ARM64 Alpine/Debian 对照镜像会正确返回 `aarch64`。

`scripts/verify.sh` 会先完成端口、Caddy、HTTP 方法、路径穿越和 Atom XML 检查，最后仍以非零退出阻断“原生 ARM64”验收。不要删除这个断言。后续必须显式选择：接受固定摘要的 Rosetta 模拟运行，或改为维护基于固定上游源码提交的自建原生 ARM64 镜像。

## 0. 资格硬门禁

继续部署前，你必须同时满足：

1. 能登录 [微信公众平台](https://mp.weixin.qq.com/)。
2. 拥有至少一个公众号或服务号的管理员/运营者权限。
3. 微信扫码时能选择该公众号或服务号；普通个人微信关注列表不能作为 WeRSS 授权来源。
4. 接受随机长路径下的只读 RSS 可以被公网访问。

先运行环境诊断：

```bash
cd /Users/summer/Documents/wechat-rss
./scripts/doctor.sh
```

如果第 1–3 条不成立，停止 WeRSS/Funnel 部署，改用“Folo 打开原文 -> Obsidian Web Clipper”或其他来源方案。

## 1. 安装本机应用

准备脚本会从官方来源下载 Apple Silicon 版本，把 `Docker.app` 和 `Folo.app` 复制到 `/Applications`，并校验 Folo SHA512 与两个 App 的代码签名：

```bash
./scripts/install-macos-apps.sh
```

之后需要你本人完成：

- 首次打开 Docker Desktop，阅读并接受服务协议，选择推荐设置，按 macOS 提示授权。
- 首次打开 Folo，通过 Gatekeeper 后登录或注册。
- 在菜单栏启动并连接 Tailscale。

脚本不会替你接受 Docker 法律协议，也不会代办 Folo 登录或付费。

## 2. 初始化密钥与本机服务

生成一次性 Bootstrap 密码、稳定授权加密键和 48 hex 随机 Feed 前缀：

```bash
./scripts/init-secrets.sh
```

脚本不会覆盖已有 `.env`。生成后：

- `.env` 权限为 `600`。
- `data/`、`backups/`、`observations/` 权限为 `700`。
- 所有目录都被 Git 忽略。

Docker Desktop 完成首次启动后运行：

```bash
docker compose pull
docker compose up -d
docker compose ps
curl -fsS http://127.0.0.1:8001/ >/dev/null
```

本机完整冒烟：

```bash
./scripts/verify.sh --local
```

该脚本会验证：

- Compose 配置可解析，且不会把密码打印到终端。
- WeRSS 容器原生运行在 `aarch64`。
- Caddyfile 通过官方 `caddy validate`。
- 8001 与 8080 都只绑定 `127.0.0.1`。
- 管理端返回 `200`。
- Caddy 根路径、API、POST 和路径穿越请求返回 `404`。
- 随机路径下的聚合 Atom Feed 返回 `200` 且 XML 合法。

当前固定 WeRSS 摘要会使最后的原生架构检查失败；此前的安全与 Feed 检查仍会完整执行并输出结果。

## 3. 首次登录与微信授权

用 Chrome 打开：

```text
http://127.0.0.1:8001
```

Bootstrap 用户名固定为 `werss_admin`。只在你自己的终端查看初始密码：

```bash
awk -F= '$1 == "WERSS_BOOTSTRAP_PASSWORD" { print $2 }' .env
```

登录后立即在 WeRSS UI 中改成另一组新密码。WeRSS 对已有用户不会在重启时用环境变量重置密码，因此 `.env` 中的 Bootstrap 密码之后只是失效的初始化值。

微信授权步骤：

1. 使用 Chrome，不用 Safari 完成首次扫码。
2. 扫码后选择自己管理的公众号或服务号。
3. 先添加 3 个近期每天或隔天更新的精选公众号。
4. 搜索和添加操作之间间隔 30–60 秒，降低微信 `200013` 风控概率。
5. 检查标题、发布时间、正文和图片。
6. 创建定时任务 `17 */2 * * *`，保存后点击“应用”。

本机 Feed：

```text
http://127.0.0.1:8001/feed/all.atom
http://127.0.0.1:8001/feed/<公众号ID>.atom
```

## 4. 只读公网 RSS

当前 Tailscale 已有 tailnet 身份，但服务可能处于 `Stopped`。先从菜单栏连接，再执行：

```bash
./scripts/configure-funnel.sh
```

首次启用 Funnel 时，Tailscale 可能打开管理网页，要求账号 Owner/Admin 批准 HTTPS 与 Funnel 权限。批准后重新运行脚本。

脚本成功后会：

1. 将本机 `127.0.0.1:8080` 交给 Funnel。
2. 动态读取当前节点的 `*.ts.net` DNS 名称。
3. 生成 `https://<host>/<FEED_PREFIX>/`，保留末尾 `/`。
4. 写入 `.env` 的 `RSS_BASE_URL`。
5. 重建 WeRSS 容器。
6. 执行公网安全验收。

需要回滚公网入口时：

```bash
./scripts/disable-funnel.sh
```

随机 Feed 前缀等同于 bearer secret，不是真正鉴权。不要放进公开笔记、截图、Issue 或日志。若泄露，轮换 `FEED_PREFIX`、更新 `RSS_BASE_URL`、重建服务并在 Folo 重新订阅。

## 5. Folo 小规模试验

先使用免费账户，不要立即购买 Basic。

Folo 当前已设置为“设置 → 通用 → 语言 → 简体中文”。未登录首页里的 `AI`、`Science`、`Developer` 和英文文章是 Folo 自带演示订阅，不是 WeRSS 内容，也不是汉化失败；登录并加入公众号 Feed 后，实际阅读内容取决于公众号原文语言。

从 `.env` 读取基地址，然后在 Folo 添加：

```text
<RSS_BASE_URL>feed/all.atom
<RSS_BASE_URL>feed/<一个公众号ID>.atom
```

建立分类“微信公众号测试”，连续观察至少 72 小时，并在 7 天后做最终判断：

- WeRSS 定时抓取成功。
- Atom XML 已出现新文章。
- Folo 无需取消订阅或重新添加即可显示新文章。
- 从 WeRSS 入库到 Folo 出现不超过 12 小时。

每次观察可记录：

```bash
./scripts/record-observation.sh <公众号ID> <聚合源在Folo状态> <单源在Folo状态>
```

记录写入被忽略且权限为 `600` 的 `observations/folo-stability.tsv`，不会公开随机 Feed URL。

判断规则：

- 聚合源和单源都稳定：导入 WeRSS OPML，按单公众号管理。
- 只有聚合源稳定：使用 `/feed/all.atom`，或以后按 WeRSS 标签建立主题聚合源。
- RSS 已更新但 Folo 未更新：归类为 Folo 刷新问题。
- 两者都停止更新：不购买 Basic；保留 WeRSS，改用本地抓取型阅读器。

## 6. Folo -> Obsidian

只有 72 小时门禁通过后，才启用 Folo Basic 试用或订阅，并在桌面版开启 Obsidian 集成。

目标目录：

```text
/Users/summer/Obsidian/SummerOS/02_Archive/02_DailyProcessed/reading/folo_inbox
```

仓库实施时会同时建立：

- `reading/公众号精选.base`
- `reading/README.md`
- `reading/公众号文章批注模板.md`
- `reading/folo_inbox/README.md`

Folo 正式订阅标记为“私密关注”。保存到 Obsidian 后：

1. 确认 Markdown 文件出现。
2. 本机后台每分钟执行一次整理任务（可用 `./scripts/install-obsidian-watcher.sh` 重装）。它会按发布日期重命名，补齐人工字段，并在同一文件的原文上方加入“我的笔记”和“划线与摘录”；重复执行不会重复插入，同名目标存在时不会覆盖。需要立刻整理时也可手工运行 `./scripts/prepare-obsidian-inbox.py`。
3. 在 Folo 取消 Starred、标记已读。
4. 在 Obsidian 原文中使用 `==关键句==` 高亮，在顶部记录自己的判断。
5. 补充 `reading_status`、`rating`、`topics`、`promote_to`、`reviewed_at`。

原文始终留在 Archive。值得提升时，新建综合后的 Knowledge 条目或脱敏 Output 草稿，并引用原文；不要把整篇公众号文章直接移动到 Knowledge。

Folo 保存的 `feedUrl` 含随机 RSS 地址。任何公开发布或分享前必须删除该字段。

不购买 Basic 时的免费备用路径：

```text
Folo 打开原文 -> Obsidian Web Clipper -> 同一 folo_inbox
```

## 7. 备份与恢复

每周以及每次升级前执行：

```bash
./scripts/backup.sh
```

脚本会仅在 WeRSS 原本运行时短暂停止它，打包：

- `data/`：SQLite、`data/.secret_key`、`key.lic`/`wx.lic`、Redis 持久化数据与缓存。
- `.env`：Bootstrap 值、`SAFE_LIC_KEY`、Feed 前缀、RSS 基地址。
- Compose、Caddy 与操作说明。

归档权限为 `600`，目录权限为 `700`。

独立恢复演练：

```bash
./scripts/restore-test.sh
```

脚本会解压到独立目录，运行 SQLite `PRAGMA integrity_check`，再用不同 Compose project 和随机本机端口启动恢复实例；不会覆盖 live data。测试实例会关闭，恢复目录保留用于审计。

## 8. 升级流程

不安装 Watchtower，不追随 `latest`。

固定流程：

1. `./scripts/backup.sh`
2. 从官方 registry 获取候选镜像的多架构 digest。
3. 在独立恢复目录或临时 Compose 项目验证 ARM64、登录、Feed、正文与 Caddy 安全边界。
4. 修改 `compose.yaml` 的 digest。
5. `docker compose pull && docker compose up -d`
6. `./scripts/verify.sh --public`
7. 保留旧 digest；失败时改回旧 digest并重建。

## 9. 日常维护

- 每周检查一次微信授权状态。
- 每周备份；升级前额外备份。
- 不向他人分享 WeRSS 容器日志。
- Folo 导出文件公开前删除 `feedUrl`。
- Mac 经常休眠导致漏抓时，把同一 Compose 与 `data/` 迁移到 NAS/云服务器，不长期禁用睡眠掩盖问题。
- v1 不自动下载图片。只有评级 4–5 或准备提升的文章，才单独本地化附件。

完整验收矩阵见 [docs/验收清单.md](docs/验收清单.md)，Folo/Obsidian 操作约定见 [docs/Folo与Obsidian设置.md](docs/Folo与Obsidian设置.md)。
