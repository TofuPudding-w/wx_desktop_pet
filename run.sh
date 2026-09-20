#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ -z "${DISPLAY:-}" ]]; then
  echo '需要 X11/XWayland DISPLAY；请从桌面会话启动。' >&2
  exit 1
fi
if [[ -x ./CPPet.x86_64 ]]; then
  exec ./CPPet.x86_64 --display-driver x11 "$@"
fi
engine="${GODOT_BIN:-godot}"
if ! command -v "$engine" >/dev/null 2>&1; then
  echo '未找到 Godot 4.6.1。设置 GODOT_BIN=/path/to/godot，或使用 dist 中的独立程序。' >&2
  exit 1
fi
exec "$engine" --path "$PWD" --display-driver x11 "$@"
