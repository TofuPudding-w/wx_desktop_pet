#!/usr/bin/env bash
# Pinned official Godot toolchain; downloads stay outside Git history.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ "${1:-}" != "" && "${1:-}" != "--engine-only" && "${1:-}" != "--all-platforms" ]]; then
  echo 'Usage: tools/setup_godot.sh [--engine-only|--all-platforms]' >&2
  exit 2
fi
mkdir -p .tools/downloads .tools/godot .tools/templates
base=https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable
fetch() {
  local name="$1" digest="$2" target=".tools/downloads/$1"
  if [[ ! -f "$target" ]]; then
    curl -fL --retry 3 --connect-timeout 20 --max-time 900 "$base/$name" -o "$target.partial"
    mv -- "$target.partial" "$target"
  fi
  echo "$digest  $target" | sha256sum --check --status
}
fetch Godot_v4.6.1-stable_linux.x86_64.zip cecd0cb6b55e931318a9d7237dc4197d69ea914966787a454808523626e2789f
unzip -oq .tools/downloads/Godot_v4.6.1-stable_linux.x86_64.zip -d .tools/godot
chmod +x .tools/godot/Godot_v4.6.1-stable_linux.x86_64
if [[ "${1:-}" != "--engine-only" ]]; then
  fetch Godot_v4.6.1-stable_export_templates.tpz e6d372afd4fdfaae9571eb5e3568afcd96ce6db9a569244034154faf0ac69875
  for kind in release debug; do
    unzip -p .tools/downloads/Godot_v4.6.1-stable_export_templates.tpz "templates/linux_${kind}.x86_64" > ".tools/templates/linux_${kind}.x86_64"
    chmod +x ".tools/templates/linux_${kind}.x86_64"
  done
  if [[ "${1:-}" == "--all-platforms" ]]; then
    for name in windows_debug_x86_64.exe windows_release_x86_64.exe macos.zip; do
      unzip -p .tools/downloads/Godot_v4.6.1-stable_export_templates.tpz "templates/$name" > ".tools/templates/$name"
    done
  fi
fi
.tools/godot/Godot_v4.6.1-stable_linux.x86_64 --version
