#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
engine="${GODOT_BIN:-godot}"
version="$("$engine" --version)"
if [[ "$version" != 4.6.1.stable* ]]; then
  echo "需要 Godot 4.6.1.stable，当前为 $version" >&2
  exit 1
fi
for template in .tools/templates/linux_release.x86_64 .tools/templates/linux_debug.x86_64; do
  [[ -f "$template" ]] || { echo "缺少 $template；请按 README 提取 4.6.1 导出模板。" >&2; exit 1; }
done
package=dist/CPPet-v0.1.0-Linux-x64
mkdir -p "$package/licenses"
"$engine" --headless --editor --path . --import --quit
"$engine" --headless --path . --export-release 'Linux x86_64' "$package/CPPet.x86_64"
cp run.sh "$package/run.sh"
cp docs/RELEASE_README.txt "$package/README.txt"
cp docs/VALIDATION.md "$package/VALIDATION.md"
cp assets/fonts/LICENSE.txt "$package/licenses/Droid-Apache-2.0.txt"
cp assets/fonts/NOTICE.txt "$package/licenses/Droid-NOTICE.txt"
cp docs/GODOT-LICENSE.txt "$package/licenses/GODOT-LICENSE.txt"
cp docs/GODOT-THIRD-PARTY.json "$package/licenses/GODOT-THIRD-PARTY.json"
cp docs/THIRD_PARTY.md "$package/licenses/THIRD_PARTY.md"
chmod +x "$package/CPPet.x86_64" "$package/run.sh"
python3 tools/package_linux.py
