#!/bin/bash

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root" || exit 1

echo "Senderos del Horizonte — publicación automática"
echo
echo "1) Subir cambios y generar un ejecutable de prueba"
echo "2) Publicar una actualización oficial para los jugadores"
echo
printf "Elige 1 o 2: "
read -r choice
printf "Describe brevemente los cambios: "
read -r message

if [[ "$choice" == "1" ]]; then
  ./tools/publicar_cambios.sh prueba - "$message"
  result=$?
elif [[ "$choice" == "2" ]]; then
  suggested="$(python3 tools/set_project_version.py --print-next-patch)"
  printf "Número de versión [%s]: " "$suggested"
  read -r version
  version="${version:-$suggested}"
  ./tools/publicar_cambios.sh release "$version" "$message"
  result=$?
else
  echo "Opción no válida."
  result=2
fi

echo
if [[ "$result" -eq 0 ]]; then
  echo "Operación enviada a GitHub correctamente."
else
  echo "La publicación no se completó. Revisa el mensaje anterior."
fi
printf "Pulsa Intro para cerrar."
read -r _
exit "$result"
