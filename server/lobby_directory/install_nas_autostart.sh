#!/bin/sh

set -eu

SOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BOOT_SOURCE="$SOURCE_DIR/senderos-lobby-boot.sh"
BOOT_TARGET="/usr/local/etc/rc.d/S99senderos-lobby.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecuta este instalador con sudo." >&2
  exit 1
fi

if [ ! -f "$BOOT_SOURCE" ]; then
  echo "No se encuentra $BOOT_SOURCE" >&2
  exit 1
fi

mkdir -p /usr/local/etc/rc.d
install -m 0755 "$BOOT_SOURCE" "$BOOT_TARGET"

echo "Entrada de arranque instalada en $BOOT_TARGET"
"$BOOT_TARGET" start
"$BOOT_TARGET" status
echo "Autoarranque de Senderos Lobby configurado correctamente."
