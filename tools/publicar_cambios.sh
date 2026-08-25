#!/usr/bin/env bash

set -euo pipefail

mode="${1:-}"
version="${2:-}"
message="${3:-}"
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if [[ "$mode" != "prueba" && "$mode" != "release" ]]; then
  echo "Uso: $0 prueba - MENSAJE" >&2
  echo "   o: $0 release VERSION MENSAJE" >&2
  exit 2
fi
if [[ -z "$message" ]]; then
  echo "Escribe una descripción del cambio." >&2
  exit 2
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "El repositorio todavía no tiene configurado el remoto origin." >&2
  exit 1
fi

if [[ "$mode" == "release" ]]; then
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "La versión debe tener el formato 0.1.2" >&2
    exit 2
  fi
  tag="v$version"
  if git show-ref --verify --quiet "refs/tags/$tag" || \
      git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    echo "La etiqueta $tag ya existe. Elige una versión nueva." >&2
    exit 1
  fi
fi

echo
echo "Archivos que se incluirán:"
git status --short
echo
if [[ "$mode" == "release" ]]; then
  echo "Se publicará la actualización oficial v$version."
else
  echo "Se generará una compilación de prueba; los jugadores no se actualizarán."
fi
printf 'Escribe PUBLICAR para continuar: '
read -r confirmation
if [[ "$confirmation" != "PUBLICAR" ]]; then
  echo "Operación cancelada."
  exit 1
fi

if [[ "$mode" == "release" ]]; then
  python3 tools/set_project_version.py --version "$version" >/dev/null
fi

git add -A
git diff --cached --check -- . ':(exclude)assets/**' ':(exclude)distribution/windows/**'
if ! git diff --cached --quiet; then
  if [[ "$mode" == "release" ]]; then
    git commit -m "release: v$version - $message"
  else
    git commit -m "change: $message"
  fi
fi

git push origin HEAD:main

if [[ "$mode" == "release" ]]; then
  git tag -a "$tag" -m "$message"
  git push origin "$tag"
  echo "GitHub está generando y publicando $tag automáticamente."
else
  echo "GitHub está generando una compilación de prueba automáticamente."
fi
