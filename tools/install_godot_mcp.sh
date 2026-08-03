#!/usr/bin/env bash
set -euo pipefail

# Instala la integración comunitaria ee0pdt/Godot-MCP dentro de este proyecto.
# Requisitos: Git, Node.js 18+ y npm.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MCP_DIR="$PROJECT_DIR/tools/godot-mcp"
ADDON_DIR="$PROJECT_DIR/addons/godot_mcp"

if ! command -v node >/dev/null 2>&1; then
	printf '%s\n' "Falta Node.js 18 o posterior: https://nodejs.org/"
	exit 1
fi

if [ -e "$MCP_DIR" ]; then
	printf '%s\n' "Ya existe $MCP_DIR; no se ha sobrescrito."
	exit 1
fi

git clone --depth 1 https://github.com/ee0pdt/Godot-MCP.git "$MCP_DIR"
npm --prefix "$MCP_DIR/server" install
npm --prefix "$MCP_DIR/server" run build

mkdir -p "$PROJECT_DIR/addons"
cp -R "$MCP_DIR/addons/godot_mcp" "$ADDON_DIR"

printf '\n%s\n' "Instalación preparada. Continúa en docs/MCP_SETUP.md."
printf '%s\n' "Servidor: $MCP_DIR/server/dist/index.js"

