#!/usr/bin/env bash
# Publicación atómica: primero todos los archivos, después el enlace estable.
set -euo pipefail
id="${1:-}"
origen="${2:-dist/web-game}"
if [[ ! "$id" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,60}$ ]]; then echo 'Uso: publicar_juego_web_nas.sh IDENTIFICADOR [CARPETA]' >&2; exit 2; fi
raiz="$(cd "$(dirname "$0")/.." && pwd)"
cd "$raiz"
nas="${SENDEROS_NAS_SSH:-francisco4@192.168.0.25}"
destino=/volume1/homes/francisco4/saber-updates/publico/senderos/jugar
python3 - "$origen" "$id" <<'PY'
from pathlib import Path
import hashlib,json,sys
carpeta=Path(sys.argv[1])
for nombre in ['index.html','index.js','index.pck','index.wasm','index.side.wasm','libterrain.web.release.wasm32.wasm']:
 if not (carpeta/nombre).is_file() or (carpeta/nombre).stat().st_size<100: raise SystemExit('Falta el archivo web '+nombre)
archivos={}
for p in sorted(carpeta.iterdir()):
 if p.is_file() and p.name not in ['sha256sum.txt','compilacion.json']:
  if not all(c.isalnum() or c in '._-' for c in p.name): raise SystemExit('Nombre de archivo web no permitido')
  digest=hashlib.sha256()
  with p.open('rb') as entrada:
   for bloque in iter(lambda:entrada.read(1024*1024),b''):digest.update(bloque)
  archivos[p.name]={'bytes':p.stat().st_size,'sha256':digest.hexdigest()}
(carpeta/'compilacion.json').write_text(json.dumps({'id':sys.argv[2],'archivos':archivos},indent=2)+'\n')
(carpeta/'sha256sum.txt').write_text(''.join(f"{datos['sha256']}  {nombre}\n" for nombre,datos in archivos.items()))
PY
paquete="/private/tmp/senderos-web-$id.tgz"
COPYFILE_DISABLE=1 tar -czf "$paquete" -C "$origen" .
hash="$(shasum -a 256 "$paquete" | awk '{print $1}')"
ssh -n -o BatchMode=yes "$nas" "mkdir -p '$destino'"
ssh -o BatchMode=yes "$nas" "cat > '$destino/.$id.tgz.upload'" < "$paquete"
ssh -n -o BatchMode=yes "$nas" "set -e; cd '$destino'; printf '%s  %s\n' '$hash' '.$id.tgz.upload' | sha256sum -c -; test ! -e '$id'; mkdir '.$id.preparando'; tar -xzf '.$id.tgz.upload' -C '.$id.preparando'; cd '.$id.preparando'; sha256sum -c sha256sum.txt; cd ..; chmod -R a+rX '.$id.preparando'; mv '.$id.preparando' '$id'; rm '.$id.tgz.upload'"
printf '%s\n' "<!doctype html><html lang=es><meta charset=utf-8><meta http-equiv=refresh content=\"0;url=./$id/\"><title>Senderos del Horizonte</title><a href=\"./$id/\">Entrar en Senderos del Horizonte</a></html>" | ssh -o BatchMode=yes "$nas" "cat > '$destino/index.html.upload' && chmod 644 '$destino/index.html.upload' && mv '$destino/index.html.upload' '$destino/index.html'"
echo 'Juego web publicado: https://franfuco4444.synology.me:24573/senderos/jugar/'
