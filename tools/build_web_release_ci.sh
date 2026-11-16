#!/usr/bin/env bash
set -euo pipefail
version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then echo 'Versión web no válida' >&2; exit 2; fi
cd "$(dirname "$0")/.."
godot="${GODOT_BIN:-tools/runtime/Godot.app/Contents/MacOS/Godot}"
mkdir -p dist/web-game "dist/releases/$version"
"$godot" --headless --path . --export-release 'Web NAS' dist/web-game/index.html
python3 - "$version" <<'PY'
from pathlib import Path
import hashlib,json,sys,zipfile
version=sys.argv[1]; origen=Path('dist/web-game'); destino=Path('dist/releases')/version
with zipfile.ZipFile(destino/f'SenderosDelHorizonte-Web-{version}.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(origen.iterdir()):
  if p.is_file():z.write(p,p.name)
archivo=destino/f'SenderosDelHorizonte-Web-{version}.zip'
print('WEB BUILD OK:',archivo,archivo.stat().st_size,'bytes')
PY
