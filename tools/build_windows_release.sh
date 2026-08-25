#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 VERSION [URL_DEL_PAQUETE]"
  exit 2
fi

release_version="$1"
package_url="${2:-PACKAGE_URL_PENDING_UPLOAD}"
project_root="${0:A:h:h}"
godot_bin="$project_root/tools/runtime/Godot.app/Contents/MacOS/Godot"
template_bin="$project_root/tools/export_templates/windows_release_x86_64.exe"
payload_dir="$project_root/dist/windows_payload"
release_dir="$project_root/dist/releases/$release_version"

if [[ ! -x "$godot_bin" ]]; then
  echo "No se encontro Godot en tools/runtime/Godot.app"
  exit 1
fi
if [[ ! -f "$template_bin" ]]; then
  echo "Falta la plantilla Windows: tools/export_templates/windows_release_x86_64.exe"
  exit 1
fi

rm -rf "$payload_dir" "$release_dir"
mkdir -p "$payload_dir" "$release_dir"
"$godot_bin" --headless --path "$project_root" --export-release "Windows Desktop" "$payload_dir/SenderosDelHorizonte.exe"
echo "$release_version" > "$payload_dir/version.txt"

package_path="$release_dir/SenderosDelHorizonte-Windows-x86_64-$release_version.zip"
(cd "$payload_dir" && zip -q -r -X "$package_path" .)
python3 "$project_root/tools/make_release_manifest.py" \
  --version "$release_version" \
  --package "$package_path" \
  --url "$package_url" \
  --output "$release_dir/version.json"

installer_stage="$release_dir/installer"
mkdir -p "$installer_stage"
cp "$project_root/distribution/windows/ActualizarYJugar.ps1" "$installer_stage/"
cp "$project_root/distribution/windows/Instalar.ps1" "$installer_stage/"
cp "$project_root/distribution/windows/Instalar.bat" "$installer_stage/"
cp "$project_root/distribution/windows/Jugar.bat" "$installer_stage/"
cp "$project_root/distribution/windows/channel.json" "$installer_stage/"
installer_path="$release_dir/SenderosDelHorizonte-Instalador.zip"
if grep -q "PENDING" "$project_root/distribution/windows/channel.json"; then
  installer_path="$release_dir/SenderosDelHorizonte-Instalador-PENDIENTE-PUBLICACION.zip"
fi
(cd "$installer_stage" && zip -q -r -X "$installer_path" .)

echo "Release preparada en $release_dir"
shasum -a 256 "$package_path" "$installer_path"
