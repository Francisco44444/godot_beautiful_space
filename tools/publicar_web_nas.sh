#!/usr/bin/env bash
# Los ZIP se verifican antes de publicar los enlaces. Cada archivo del NAS se
# sustituye por renombrado, después de comprobar su SHA-256.
set -euo pipefail
version="${1:-}"
modo="${2:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ -n "$modo" && "$modo" != "--subir" ]]; then
  echo "Uso: $0 VERSION [--subir]" >&2
  exit 2
fi
raiz="$(cd "$(dirname "$0")/.." && pwd)"
cd "$raiz"
origen="dist/releases/$version"
preparado="dist/web/senderos-$version"
base_url="${SENDEROS_BASE_URL:-https://franfuco4444.synology.me:24573/senderos}"
nas_ssh="${SENDEROS_NAS_SSH:-francisco4@192.168.0.25}"
nas_dir="${SENDEROS_NAS_DIR:-/volume1/homes/francisco4/saber-updates/publico/senderos}"
paquete="SenderosDelHorizonte-Windows-x86_64-$version.zip"
instalador="SenderosDelHorizonte-Instalador.zip"
if [[ ! "$nas_dir" =~ ^/[a-zA-Z0-9/_-]+/senderos$ ]] || [[ ! "$base_url" =~ ^https://[a-zA-Z0-9.:-]+/senderos$ ]]; then
  echo "La carpeta y URL deben identificar la web de Senderos." >&2
  exit 2
fi
mkdir -p "$origen" "$preparado/assets"
for archivo in "$paquete" "$instalador" version.json; do
  if [[ ! -f "$origen/$archivo" ]]; then
    echo "Descargando $archivo de la release v${version}…"
    gh release download "v$version" --repo Francisco44444/godot_beautiful_space --pattern "$archivo" --dir "$origen"
  fi
done
python3 - "$version" "$origen" "$preparado" <<'PY'
import hashlib,json,re,shutil,sys,zipfile
from pathlib import Path
version,origen,preparado=sys.argv[1:]
origen=Path(origen); preparado=Path(preparado)
manifiesto=json.loads((origen/'version.json').read_text())
if manifiesto['version']!=version: raise SystemExit('El manifiesto no corresponde a la versión solicitada.')
nombre=f'SenderosDelHorizonte-Windows-x86_64-{version}.zip'
archivo=origen/nombre
digest=hashlib.sha256()
with archivo.open('rb') as entrada:
    for bloque in iter(lambda:entrada.read(1024*1024),b''): digest.update(bloque)
if archivo.stat().st_size!=manifiesto['windows']['size_bytes'] or digest.hexdigest()!=manifiesto['windows']['sha256']:
    raise SystemExit('El ZIP no coincide con el tamaño y SHA-256 publicados.')
with zipfile.ZipFile(archivo) as z:
    try:
        with z.open('SenderosDelHorizonte.exe') as ejecutable:
            if ejecutable.read(2)!=b'MZ': raise SystemExit('El ZIP no contiene un ejecutable Windows válido.')
    except KeyError:
        raise SystemExit('Falta SenderosDelHorizonte.exe en el ZIP del juego completo.')
with zipfile.ZipFile(origen/'SenderosDelHorizonte-Instalador.zip') as z:
    if not {'Instalar.bat','ActualizarYJugar.ps1'}.issubset(z.namelist()) or z.testzip(): raise SystemExit('El instalador está incompleto.')
for archivo in Path('website').rglob('*'):
    if archivo.is_file():
        destino=preparado/archivo.relative_to('website')
        destino.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(archivo,destino)
# El enlace inicial también debe servir la versión publicada sin JavaScript.
pagina=preparado/'index.html'
html=pagina.read_text()
html=re.sub(r'SenderosDelHorizonte-Windows-x86_64-\d+\.\d+\.\d+\.zip',nombre,html)
html=re.sub(r'(data-version>Alfa )\d+\.\d+\.\d+',lambda coincidencia:coincidencia[1]+version,html)
pagina.write_text(html)
for archivo in [nombre,'SenderosDelHorizonte-Instalador.zip']: shutil.copy2(origen/archivo,preparado/archivo)
# La misma página debe descargar desde el NAS tanto por HTTPS público como por
# su dirección local, sin depender de que el router admita retorno NAT.
manifiesto['windows']['url']=nombre
(preparado/'version.json').write_text(json.dumps(manifiesto,ensure_ascii=False,indent=2)+'\n')
print('Paquete e instalador verificados; web preparada en',preparado)
PY
if [[ "$modo" != "--subir" ]]; then
  echo "Añade --subir para publicar en $base_url/"
  exit 0
fi
ssh -n -o BatchMode=yes "$nas_ssh" "mkdir -p '$nas_dir/assets'"
subir() {
  local relativo="$1"
  if [[ ! "$relativo" =~ ^[a-zA-Z0-9/_.-]+$ ]] || [[ "$relativo" == *..* ]]; then exit 2; fi
  local hash_archivo
  hash_archivo="$(shasum -a 256 "$preparado/$relativo" | awk '{print $1}')"
  local carpeta="${relativo%/*}"
  if [[ "$carpeta" == "$relativo" ]]; then carpeta=""; fi
  # SSH no debe consumir la lista de assets que lee el bucle de publicación.
  ssh -n -o BatchMode=yes "$nas_ssh" "mkdir -p '$nas_dir/$carpeta'"
  echo "Subiendo ${relativo}…"
  ssh -o BatchMode=yes "$nas_ssh" "cat > '$nas_dir/$relativo.upload'" < "$preparado/$relativo"
  ssh -n -o BatchMode=yes "$nas_ssh" "cd '$nas_dir' && printf '%s  %s\n' '$hash_archivo' '$relativo.upload' | sha256sum -c - && chmod 644 '$relativo.upload' && mv '$relativo.upload' '$relativo'"
}
subir "$paquete"
subir "$instalador"
while IFS= read -r archivo; do subir "${archivo#website/}"; done < <(rg --files website/assets)
subir style.css
subir app.js
subir version.json
subir index.html
echo "Web publicada: $base_url/"
