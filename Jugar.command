#!/bin/zsh

# Lanzador rápido de Senderos del Horizonte para macOS.
# Puede abrirse con doble clic o ejecutarse desde Terminal.

set -u

SCRIPT_DIR="${0:A:h}"
GODOT_BIN="$SCRIPT_DIR/tools/runtime/Godot.app/Contents/MacOS/Godot"

if [[ ! -x "$GODOT_BIN" ]]; then
	print -u2 "No se encontró el ejecutable de Godot en:"
	print -u2 "$GODOT_BIN"
	print -u2 "Revisa que tools/runtime/Godot.app siga dentro del proyecto."
	read "?Pulsa Intro para cerrar..."
	exit 1
fi

cd "$SCRIPT_DIR" || exit 1
exec "$GODOT_BIN" --path "$SCRIPT_DIR" "$@"
