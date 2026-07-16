# 部署指南

本文把整套系统拆成三个可独立验收的阶段：本机阅读、Obsidian 联动、Cloudflare 私有外网。建议按顺序完成，不要一开始就开放公网。

## 1. 本机阅读

### 要求

- Apple Silicon macOS；项目当前在该环境完成真实验证。
- Docker Desktop、Chrome、Git、`curl`、`sqlite3`。
- 至少一个公众号或服务号的管理员/运营者权限。普通微信关注列表不能作为 WeRSS 授权来源。

### 启动

```bash
git clone https://github.com/summerchaserwwz/wechat-rss-reader.git
cd wechat-rss-reader
./scripts/doctor.sh
./scripts/init-secrets.sh
docker compose pull
docker compose up -d
./scripts/init-readeck.sh
```

`.env` 首次生成后不会被脚本覆盖，且已被 Git 忽略。至少检查：

```dotenv
WERSS_ADMIN_USERNAME=werss_admin
WERSS_BOOTSTRAP_PASSWORD=<随机强密码>
OBSIDIAN_INBOX_DIR=/绝对路径/你的Vault/reading/readeck_inbox
READECK_PUBLIC_HOSTNAME=reader.example.com
WERSS_PUBLIC_HOSTNAME=werss.example.com
```

本机入口：

| 地址 | 用途 |
| --- | --- |
| `http://127.0.0.1:8001` | WeRSS 授权、公众号和任务管理 |
| `http://127.0.0.1:8002` | Readeck 故障恢复入口 |
| `http://127.0.0.1:8082` | 自定义三栏 Reader |

在 WeRSS 中完成扫码，添加少量公众号，再建立 `17 * * * *` 定时任务。搜索和添加之间保留 30–60 秒；出现微信 `200013` 时停止高频操作。

已初始化后需要修改 WeRSS 管理账号：

```bash
./scripts/change-werss-admin.sh <新用户名>
```

脚本会先创建一致性备份，再更新账号并重启相关服务。公开部署不要使用弱密码。

## 2. Obsidian 联动

### 创建 Readeck Token

在 Readeck 用户设置里创建只用于本项目的 API Token，并仅授予书签读写权限。然后运行：

```bash
./scripts/save-readeck-token.sh
./scripts/install-reading-sync.sh
```

脚本每 5 分钟执行一次：

1. WeRSS 中已有完整正文的文章全部去重写入 Readeck。
2. 只有已收藏或包含高亮/批注的文章写入 `OBSIDIAN_INBOX_DIR`。
3. 机器区可以刷新；人工 frontmatter 和“我的笔记”区永不覆盖。

手工立即同步：

```bash
/usr/bin/python3 ~/.local/share/wechat-rss/reading-sync.py
```

全部文章都写入 Obsidian：

```bash
/usr/bin/python3 ~/.local/share/wechat-rss/reading-sync.py --sync-all
```

不建议长期使用 `--sync-all`，否则 Vault 会快速膨胀。

## 3. Cloudflare 私有外网

准备两个域名，例如：

```text
reader.example.com  -> Reader
werss.example.com   -> WeRSS 管理
```

在 Cloudflare Zero Trust 中为两个域名分别创建 Self-hosted Access Application：

- 使用精确邮箱 Allow 策略。
- 禁止 `Include Everyone`。
- Reader 与 WeRSS 使用不同的 Application Audience `AUD`。

把以下内容写入本机 `.env`：

```dotenv
READECK_PUBLIC_HOSTNAME=reader.example.com
WERSS_PUBLIC_HOSTNAME=werss.example.com
CF_ACCESS_READY=true
CF_ACCESS_TEAM_NAME=<你的 team name>
CF_ACCESS_AUD=<Reader AUD>
CF_WERSS_ACCESS_READY=true
CF_WERSS_ACCESS_AUD=<WeRSS AUD>
CF_ACCESS_EMAIL=<唯一允许邮箱>
```

安装官方 `cloudflared` 后运行：

```bash
./scripts/configure-cloudflare-tunnel.sh
./scripts/install-reader-refresh-control.sh
./scripts/verify.sh --reader-public
./scripts/verify-werss-public.sh
```

Tunnel 只连接回环端口：Reader `127.0.0.1:8082`，WeRSS `127.0.0.1:8083`。匿名请求必须在 Cloudflare 或本机 Caddy 被拒绝。

## 验证与维护

```bash
# 静态和本机验证
bash -n scripts/*.sh
docker compose config --quiet
python3 -m unittest discover -s tests -v
./scripts/verify-reader-ui.sh

# 一致性备份与独立恢复
./scripts/backup.sh
./scripts/restore-test.sh
```

升级固定顺序：备份、验证新镜像摘要、修改 Compose、启动、冒烟、保留旧摘要回滚。不要安装 Watchtower，也不要跟随 `latest`。

## Linux/NAS 说明

Compose 服务本身可迁移，但本仓库的后台同步和 Tunnel 守护当前使用 macOS LaunchAgent。迁移到 Linux/NAS 时，把以下三个任务改成 `systemd` 或 NAS 任务计划：

- `reading-sync.py`：每 5 分钟。
- `reader-refresh-control.py`：常驻，仅监听 `127.0.0.1:8787`。
- `cloudflared tunnel run`：常驻。
