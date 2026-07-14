#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

failures=0
warnings=0

pass() { printf '[通过] %s\n' "$*"; }
note_warn() { printf '[待处理] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '[失败] %s\n' "$*"; failures=$((failures + 1)); }

[[ "$(uname -s)" == "Darwin" ]] && pass "运行环境为 macOS" || fail "本部署包当前只验证 macOS"
[[ "$(uname -m)" == "arm64" ]] && pass "CPU 架构为 arm64" || fail "CPU 架构不是 arm64"

[[ -d /Applications/Google\ Chrome.app ]] && pass "Google Chrome 已安装" || note_warn "请安装 Google Chrome，用于首次微信扫码授权"
[[ -d /Applications/Obsidian.app ]] && pass "Obsidian 已安装" || note_warn "请安装 Obsidian"
[[ -d /Applications/Docker.app ]] && pass "Docker Desktop 已复制到 /Applications" || note_warn "Docker Desktop 尚未安装"
if [[ -x "$HOME/.local/bin/cloudflared" ]]; then
  pass "cloudflared 已安装"
else
  note_warn "cloudflared 尚未安装；仅影响外网 Readeck，不影响本机阅读"
fi

if [[ -f "$ENV_FILE" ]]; then
  pass ".env 已生成"
  [[ "$(stat -f '%Lp' "$ENV_FILE")" == "600" ]] && pass ".env 权限为 600" || fail ".env 权限不是 600"
else
  note_warn "尚未运行 scripts/init-secrets.sh"
fi

if command -v docker >/dev/null 2>&1; then
  pass "docker CLI 可用"
  if docker info >/dev/null 2>&1; then
    pass "Docker daemon 正在运行"
  else
    note_warn "Docker Desktop 尚未完成首次启动"
  fi
else
  note_warn "docker CLI 尚不可用；启动 Docker Desktop 后会安装 CLI"
fi

vault="/Users/summer/Obsidian/SummerOS"
[[ -d "$vault" ]] && pass "SummerOS Vault 存在" || fail "未找到 SummerOS Vault"

printf '\n资格硬门禁（必须由你本人确认）：\n'
printf '1. 你能登录 mp.weixin.qq.com，并拥有至少一个公众号或服务号的管理员/运营者权限。\n'
printf '2. 微信扫码后能选择该公众号或服务号；普通个人微信关注列表不满足条件。\n'
printf '3. 如需外网阅读，你接受通过 Cloudflare Tunnel 公开 Readeck 登录页；WeRSS 管理端仍仅本机可见。\n'

if (( failures > 0 )); then
  exit 1
fi

if (( warnings > 0 )); then
  exit 2
fi
