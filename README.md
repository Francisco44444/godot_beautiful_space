# Senderos del Horizonte

Prototipo de aventura y exploración contemplativa en tercera persona, construido con Godot 4.7, GDScript y Terrain3D. Están terminadas las Fases 0 a 4: cimientos técnicos, personaje a pie, paisaje explorable, atmósfera de atardecer y montura.

## Estado actual

- Proyecto Godot 4.7.1 con Jolt Physics.
- Personaje `CharacterBody3D` con colisión, gravedad, salto, marcha y carrera.
- Caballo placeholder original llamado Brisa, con física, paso, trote y galope.
- Máquina de estados `ON_FOOT` / `MOUNTED`, con montaje y desmontaje reversible.
- Animación procedural de patas y cuerpo, sin modelos ni animaciones de terceros.
- Cámara orbital suave con `SpringArm3D`; al montar aumenta progresivamente altura, distancia y campo de visión.
- Terrain3D 1.0.2 integrado, con cuatro regiones y colisión dinámica.
- Mapa de 512×512 metros con valle, colinas de hasta 40 metros y límites elevados.
- Sendero ocre de pendiente controlada hasta una meseta-mirador situada a 24 metros.
- Objetivo con distancia y confirmación al alcanzar el mirador.
- Renderizado Forward+ con cielo procedural de atardecer y tonemapping ACES.
- Sol bajo cálido, relleno ambiental azulado y sombras largas sobre el valle.
- Niebla volumétrica ligera y bruma localizada bajo la cota del mirador.
- Resplandor sutil en el sol y la baliza del destino.
- HUD mínimo con los controles.
- Las texturas del terreno son originales y procedurales; no se usan recursos de juegos comerciales.

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
| Montar / desmontar | `E` junto a Brisa | Botón izquierdo |
| Galopar montado | `Mayús` + dirección | Pulsar stick izquierdo + dirección |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |
| Recuperar cámara | Clic dentro del juego | — |

Si el personaje cae fuera del escenario, reaparece automáticamente en el punto inicial.

El objetivo de esta fase es seguir el sendero visible desde el punto inicial hasta el mirador. La distancia restante aparece en la parte superior de la pantalla.

## Montar a caballo

Brisa espera unos metros por delante del punto inicial. Acércate hasta que aparezca el aviso y pulsa `E`. Mientras estás montado, `WASD` o las flechas guían al caballo y `Mayús` activa el galope. Pulsa `E` de nuevo para desmontar a un lado de la montura.

El placeholder está construido únicamente con primitivas de Godot. `Player` conserva la máquina de estados, mientras `Horse` controla su propia física; esto permite sustituir más adelante el modelo visual sin rehacer la mecánica.

## Luz y atmósfera

La Fase 3 usa `WorldEnvironment` con un `ProceduralSkyMaterial`, un sol rasante y niebla volumétrica. La niebla global aporta profundidad a larga distancia; el nodo `ValleyMist` concentra una capa más visible en la parte baja del valle, de modo que la llegada elevada al mirador queda despejada.

La escena requiere el renderizador **Forward+** para mostrar la niebla volumétrica. Godot puede recurrir a Compatibility en equipos sin Metal, Vulkan o Direct3D 12, pero en ese caso el juego seguirá siendo jugable con una atmósfera visual más sencilla.

## Editar el terreno

Terrain3D ya está activado como plugin. Al abrir `scenes/world.tscn`, selecciona el nodo `Terrain3D` para mostrar sus herramientas de esculpido y pintura. Los datos editables están en `terrain/data`.

El paisaje base se puede regenerar de forma determinista con:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/generate_terrain.gd
```

La regeneración reemplaza el relieve y las texturas procedurales actuales, por lo que debe usarse antes de hacer retoques manuales que se quieran conservar.

## Pruebas

Se han ejecutado con Godot 4.7.1:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit-after 3
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/player_movement_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/terrain_route_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/atmosphere_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/mounting_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 180
```

La primera comprueba importación y sintaxis; la segunda valida Terrain3D, caballo, mirador, estructura, atmósfera y controles; la tercera simula avance y salto; la cuarta mide toda la pendiente del sendero y aterriza al personaje sobre la tarima; la quinta valida Forward+, cielo procedural, luz y niebla; la sexta monta, abre la cámara, galopa y desmonta; la última mantiene el juego vivo durante tres segundos para detectar errores de ejecución.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada; no afecta al juego ni a las pruebas.

## Estructura

```text
assets/     futuros modelos, texturas y audio con licencia libre
addons/     Terrain3D y futuros addons de Godot
docs/       documentación adicional, incluido MCP
scenes/     escenas `.tscn`
scripts/    código GDScript comentado
tests/      pruebas ejecutables en modo headless
terrain/    regiones, material, texturas y vista previa del relieve
tools/      utilidades y runtimes locales ignorados por Git
```

## Godot MCP

La instalación opcional está preparada y explicada en [docs/MCP_SETUP.md](docs/MCP_SETUP.md). El addon no se activa automáticamente porque es código externo comunitario y primero debe importarse y revisarse dentro del editor.

## Licencias y procedencia

El código original de este repositorio se distribuye con licencia MIT; consulta [LICENSE](LICENSE). Terrain3D también usa licencia MIT y está registrado en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Los futuros recursos de terceros deberán registrar autor, URL y licencia antes de incorporarse. No se permite material extraído de Nintendo ni de ningún juego comercial.
