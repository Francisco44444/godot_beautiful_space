#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 VERSION URL_DEL_PAQUETE [NOTAS]" >&2
  exit 2
fi

release_version="$1"
package_url="$2"
release_notes="${3:-Nueva versión de Senderos del Horizonte}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
template_bin="$project_root/tools/export_templates/windows_release_x86_64.exe"
payload_dir="$project_root/dist/windows_payload"
release_dir="$project_root/dist/releases/$release_version"

if [[ ! -x "$godot_bin" ]]; then
  echo "No se encontró el editor de Godot en $godot_bin" >&2
  exit 1
fi
if [[ ! -f "$template_bin" ]]; then
  echo "Falta la plantilla Windows: $template_bin" >&2
  exit 1
fi

rm -rf "$payload_dir" "$release_dir"
mkdir -p "$payload_dir" "$release_dir"

"$godot_bin" --headless --path "$project_root" \
  --export-release "Windows Desktop" \
  "$payload_dir/SenderosDelHorizonte.exe"
printf '%s\n' "$release_version" > "$payload_dir/version.txt"

package_path="$release_dir/SenderosDelHorizonte-Windows-x86_64-$release_version.zip"
(cd "$payload_dir" && zip -q -r -X "$package_path" .)

python3 "$project_root/tools/make_release_manifest.py" \
  --version "$release_version" \
  --package "$package_path" \
  --url "$package_url" \
  --notes "$release_notes" \
  --output "$release_dir/version.json"

installer_stage="$release_dir/installer"
mkdir -p "$installer_stage"
cp "$project_root/distribution/windows/ActualizarYJugar.ps1" "$installer_stage/"
cp "$project_root/distribution/windows/Instalar.ps1" "$installer_stage/"
cp "$project_root/distribution/windows/Instalar.bat" "$installer_stage/"
cp "$project_root/distribution/windows/Jugar.bat" "$installer_stage/"
cp "$project_root/distribution/windows/channel.json" "$installer_stage/"
installer_path="$release_dir/SenderosDelHorizonte-Instalador.zip"
(cd "$installer_stage" && zip -q -r -X "$installer_path" .)

echo "Release preparada en $release_dir"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$package_path" "$release_dir/version.json" "$installer_path"
else
  shasum -a 256 "$package_path" "$release_dir/version.json" "$installer_path"
fi
