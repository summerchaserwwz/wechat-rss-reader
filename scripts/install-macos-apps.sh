#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] || die "本脚本只支持 Apple Silicon macOS"
require_command curl
require_command hdiutil
require_command ditto
require_command openssl

download_dir="$ROOT_DIR/downloads"
mkdir -p "$download_dir"

docker_dmg="$download_dir/Docker-arm64.dmg"
folo_version="1.11.0"
folo_dmg="$download_dir/Folo-${folo_version}-macos-arm64.dmg"
folo_sha512="ZyFCXEMVhfbdrL5opfE6MZy8go7IrM38EVQngEDxjz/4vzrsArbYr9FtuhIcfwNOp8htWNN+OwsU0uFFLT10Sg=="

download() {
  local url="$1"
  local destination="$2"
  if [[ ! -f "$destination" ]]; then
    curl -fL --retry 3 --continue-at - -o "$destination" "$url"
  fi
}

copy_app_from_dmg() {
  local dmg="$1"
  local app_name="$2"
  local destination="/Applications/$app_name"
  local mount_dir

  if [[ -d "$destination" ]]; then
    printf '%s 已存在，跳过复制。\n' "$destination"
    return 0
  fi

  mount_dir="$(mktemp -d /tmp/wechat-rss-dmg.XXXXXX)"
  hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount_dir" >/dev/null
  if [[ ! -d "$mount_dir/$app_name" ]]; then
    hdiutil detach "$mount_dir" >/dev/null || true
    die "DMG 中未找到 $app_name"
  fi
  ditto "$mount_dir/$app_name" "$destination"
  hdiutil detach "$mount_dir" >/dev/null
  rmdir "$mount_dir" 2>/dev/null || true
  codesign --verify --deep --strict "$destination"
  printf '已复制并验证签名：%s\n' "$destination"
}

download "https://desktop.docker.com/mac/main/arm64/Docker.dmg" "$docker_dmg"
download "https://github.com/RSSNext/Folo/releases/download/desktop/v${folo_version}/Folo-${folo_version}-macos-arm64.dmg" "$folo_dmg"

actual_folo_sha512="$(openssl dgst -sha512 -binary "$folo_dmg" | openssl base64 -A)"
[[ "$actual_folo_sha512" == "$folo_sha512" ]] || die "Folo DMG SHA512 校验失败"

copy_app_from_dmg "$docker_dmg" "Docker.app"
copy_app_from_dmg "$folo_dmg" "Folo.app"

printf '\n应用已放入 /Applications，但仍有人工门禁：\n'
printf '1. 首次打开 Docker Desktop，阅读并接受协议，完成推荐设置和管理员授权。\n'
printf '2. 首次打开 Folo，通过 Gatekeeper 后登录账户。\n'
