# Senderos del Horizonte

Prototipo de aventura y exploración contemplativa en tercera persona, construido con Godot 4.7 y GDScript. Esta primera entrega contiene las Fases 0 y 1: cimientos técnicos y personaje a pie sobre un terreno plano de prueba.

## Estado actual

- Proyecto Godot 4.7.1 con Jolt Physics.
- Personaje `CharacterBody3D` con colisión, gravedad, salto, marcha y carrera.
- Cámara orbital suave con `SpringArm3D` para evitar atravesar obstáculos.
- Suelo plano y dos rocas primitivas para comprobar colisiones.
- HUD mínimo con los controles.
- Sin assets, modelos, música o texturas de terceros; toda la geometría actual usa primitivas de Godot y el icono es original.

Terrain3D se incorporará en la Fase 2, después de validar esta base jugable, como pide la planificación del proyecto.

## Abrir y jugar

La versión oficial 4.7.1 descargada para verificar el proyecto está en `tools/runtime/Godot.app` y no se guarda en Git.

1. Abre `tools/runtime/Godot.app`.
2. En el administrador de proyectos, pulsa **Importar** y selecciona `project.godot` en esta carpeta.
3. Abre el proyecto y pulsa **F6** para ejecutar la escena actual o **F5** para ejecutar el proyecto completo.

También se puede arrancar desde Terminal:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --path .
```

## Controles

| Acción | Teclado / ratón | Mando |
| --- | --- | --- |
| Caminar | `WASD` o flechas | Stick izquierdo |
| Correr | `Mayús` | Pulsar stick izquierdo |
| Saltar | `Espacio` | Botón inferior |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |
| Recuperar cámara | Clic dentro del juego | — |

Si el personaje cae fuera del escenario, reaparece automáticamente en el punto inicial.

## Pruebas

Se han ejecutado con Godot 4.7.1:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit-after 3
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/player_movement_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 180
```

La primera comprueba importación y sintaxis; la segunda, la estructura de escena y el mapa de entrada; la tercera simula avance y salto; la última mantiene el juego vivo durante tres segundos para detectar errores de ejecución.

## Estructura

```text
assets/     futuros modelos, texturas y audio con licencia libre
addons/     addons de Godot (Terrain3D llegará en la Fase 2)
docs/       documentación adicional, incluido MCP
scenes/     escenas `.tscn`
scripts/    código GDScript comentado
tests/      pruebas ejecutables en modo headless
tools/      utilidades y runtimes locales ignorados por Git
```

## Godot MCP

La instalación opcional está preparada y explicada en [docs/MCP_SETUP.md](docs/MCP_SETUP.md). El addon no se activa automáticamente porque es código externo comunitario y primero debe importarse y revisarse dentro del editor.

## Licencias y procedencia

El código original de este repositorio se distribuye con licencia MIT; consulta [LICENSE](LICENSE). Los futuros recursos de terceros deberán registrarse con autor, URL y licencia antes de incorporarse. No se permite material extraído de Nintendo ni de ningún juego comercial.

