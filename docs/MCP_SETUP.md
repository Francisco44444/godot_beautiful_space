# Integración opcional Godot MCP

El juego no depende del MCP para abrirse ni ejecutarse. Esta integración sirve para que Codex pueda consultar y manipular el árbol de escenas y controlar el editor en futuras fases.

Se propone [ee0pdt/Godot-MCP](https://github.com/ee0pdt/Godot-MCP), un proyecto comunitario con licencia MIT. No es un componente oficial de Godot ni de OpenAI.

## 1. Instalar requisitos

- Godot 4.7.1 (la copia local ya está en `tools/runtime/Godot.app`).
- Node.js 18 o posterior y npm.
- Git.

## 2. Instalar el servidor y el addon

Desde la raíz del proyecto:

```bash
chmod +x tools/install_godot_mcp.sh
./tools/install_godot_mcp.sh
```

El script clona el servidor en `tools/godot-mcp`, compila TypeScript y copia el addon a `addons/godot_mcp`. Las dependencias quedan ignoradas por Git; el código externo no se mezcla con el código del juego.

## 3. Activar el addon en Godot

1. Abre `project.godot` con Godot.
2. Ve a **Proyecto > Ajustes del proyecto > Plugins**.
3. Activa **Godot MCP**.
4. En el panel **Godot MCP Server**, conserva el puerto `9080` y pulsa **Start Server**.

Este paso se hace dentro del editor porque Godot debe importar primero el addon y mostrar cualquier error de compatibilidad.

## 4. Conectar Codex

Codex permite añadir servidores STDIO desde la app, la extensión o la CLI. La forma más directa es:

```bash
codex mcp add godot-mcp --env MCP_TRANSPORT=stdio -- node "/Users/francisco/Documents/Juego de paisajes/tools/godot-mcp/server/dist/index.js"
codex mcp list
```

Después reinicia Codex. En la app también se puede usar **Ajustes > MCP servers > Add server**, elegir **STDIO** y registrar el mismo comando. Codex comparte esta configuración entre la app, la CLI y la extensión que usen el mismo host.

Alternativamente, para limitar la configuración a este repositorio, se puede crear `.codex/config.toml` en un proyecto marcado como confiable:

```toml
[mcp_servers.godot-mcp]
command = "node"
args = ["/Users/francisco/Documents/Juego de paisajes/tools/godot-mcp/server/dist/index.js"]
cwd = "/Users/francisco/Documents/Juego de paisajes"
startup_timeout_sec = 20

[mcp_servers.godot-mcp.env]
MCP_TRANSPORT = "stdio"
```

## Diagnóstico rápido

- Si Codex no muestra herramientas: reinicia Codex tras añadir el servidor.
- Si el servidor no conecta: confirma que el panel del addon está iniciado en el puerto `9080`.
- Si `node` no existe: instala Node.js 18+ y repite el script.
- Si el addon falla al cargar: revisa la salida inferior de Godot y la compatibilidad anunciada por el repositorio antes de continuar.

