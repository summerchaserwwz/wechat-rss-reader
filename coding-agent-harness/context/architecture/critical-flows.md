# 关键流程

Context Doc Type: critical-flows
Owner: coordinator
Source Evidence: `README.md`; `compose.yaml`; `scripts/reading-sync.py`; task progress
Last Verified: 2026-07-15
Confidence: high

## 启动

`init-secrets -> compose up -> init-readeck -> install-reading-sync -> verify --local`。

## 抓取与阅读

`WeRSS 每小时抓取 -> 完整正文进入 Readeck -> 用户收藏/高亮/批注 -> 5 分钟同步到 readeck_inbox`。

## 公网发布

`Reader Caddy 本机 303/401 -> 用户确认 Cloudflare 持久授权 -> 创建独立 Tunnel/DNS -> LaunchAgent -> verify --reader-public`。

## 知识提升

`Archive 原文 + 我的笔记 -> 新建 Knowledge/Output 衍生条目 -> 原文保持 Archive`。

## 备份恢复

`停止 WeRSS/Readeck -> 打包两套数据/API Token/实际同步状态 -> 恢复原状态 -> 独立端口启动 -> 验证 Feed、用户、文章、收藏、批注`。

## 失败诊断

依次判断：WeRSS 是否有文章、正文是否完整、Readeck 是否入库、文章是否收藏/高亮、同步 LaunchAgent 是否退出 0。
