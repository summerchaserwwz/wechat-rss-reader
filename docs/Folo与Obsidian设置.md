# Folo 与 Obsidian 设置

## Folo 角色

Folo 只负责：

- 统一浏览公众号更新。
- 快速筛选、Starred 和标记已读。
- 把精选文章保存为 Obsidian Markdown。

永久高亮、批注、双链和知识综合放在 Obsidian。不要把 Folo 的阅读状态误当成知识处理状态。

## Folo 测试订阅

先添加：

```text
<RSS_BASE_URL>feed/all.atom
<RSS_BASE_URL>feed/<公众号ID>.atom
```

分类名：`微信公众号测试`。

72 小时门禁通过后：

1. 将正式订阅标记为“私密关注”。
2. 需要按单公众号管理时再导入 WeRSS OPML。
3. 开启 Folo Basic 试用/订阅和桌面端 Obsidian 集成。
4. 目标目录选 `02_Archive/02_DailyProcessed/reading/folo_inbox`。
5. 保存后由本机后台任务自动运行 `./scripts/prepare-obsidian-inbox.py --min-age 30`，把文章整理成“日期-标题 + 我的笔记 + 原文”的同页结构；后台任务每分钟检查一次。

## 元数据约定

Folo 自动字段保持原样：

```yaml
url:
author:
publishedAt:
description:
tags:
feedTitle:
feedUrl:
```

人工字段：

```yaml
reading_status: 待读
rating:
topics: []
promote_to: 无
reviewed_at:
saved_at:
```

取值：

- `reading_status`：`待读`、`已批注`、`已提升`。
- `rating`：留空或整数 `1–5`。
- `topics`：YAML 列表。
- `promote_to`：`无`、`Knowledge`、`Output`。
- `reviewed_at`：完成批注时填写日期时间。
- `saved_at`：进入收件箱的日期，由整理脚本填写。

`已提升` 只能在衍生笔记真实建立并引用原文后填写。

## 固定阅读动作

1. Folo 未读表示尚未浏览。
2. Starred 表示准备入库。
3. 点击“保存到 Obsidian”，确认文件出现。
4. 保存成功后取消 Starred、标记已读。
5. 在仓库运行 `./scripts/prepare-obsidian-inbox.py`；脚本不会覆盖同名文件，也不会重复插入笔记区。
6. 在 Obsidian 原文中用 `==关键句==` 高亮，在顶部“我的笔记”记录判断。
7. 更新人工字段。

## Folo 中文界面

Folo 的“设置 → 通用 → 语言”已是“简体中文”。首页的 `AI`、`Science`、`Developer` 和英文文章是未登录状态自带的演示订阅及其原文，不是语言设置失效，也不是 WeRSS 导入内容。登录并订阅中文公众号 Feed 后，阅读列表的标题和正文会来自公众号原文；第三方英文原文不会被界面语言自动翻译。

## Archive 与提升边界

- `folo_inbox` 是人工筛选后的 processed source inbox，仍是 Archive 证据层。
- “已批注”不自动等于 Digest 或 Knowledge。
- 提升到 Knowledge：创建新的综合条目，引用原文章路径，并更新 Knowledge 的 `index.md` 与 `log.md`；原文不移动。
- 提升到 Output：创建脱敏草稿，不直接公开整篇原文。
- 对外分享前删除包含随机 RSS 地址的 `feedUrl`。

## 图片与附件

v1 不自动下载图片。只有评级 4–5 或准备提升到 Knowledge/Output 的文章，才单独本地化附件，以免污染 Vault 附件结构。
