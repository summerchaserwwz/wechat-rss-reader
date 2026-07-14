# 关键流程

Context Doc Type: critical-flows
Owner: coordinator
Source Evidence: `README.md`; `compose.yaml`; `scripts/`; task findings
Last Verified: 2026-07-14
Confidence: high

## 启动

`init-secrets -> Docker 首次启动 -> compose pull/up -> verify --local -> Chrome 登录/扫码`。

## 公网发布

`Tailscale Running -> funnel approval -> configure-funnel -> 更新 RSS_BASE_URL -> 重建 WeRSS -> verify --public`。

## 阅读与提升

`Folo 未读 -> Starred -> 保存到 folo_inbox -> 取消 Starred/已读 -> Obsidian 批注 -> 新建 Knowledge/Output 衍生条目`。

## 备份恢复

`停止原本运行的 WeRSS -> 原子打包 data + .env -> 恢复原状态 -> 独立目录解压 -> SQLite integrity -> 不同 project/端口启动 -> 关闭测试实例`。

## 失败诊断

先确认 Atom 是否更新；只有 Atom 已更新而 Folo 未显示时，才归类为 Folo 刷新问题。
