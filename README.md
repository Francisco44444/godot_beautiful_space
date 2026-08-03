# Senderos del Horizonte

Juego de aventura y exploración medieval en tercera persona, construido con Godot 4.7, GDScript y Terrain3D. Las Fases 0 a 6 forman una vertical jugable con protagonista, combate, montura, valle, vegetación, arquitectura y paisaje sonoro, ahora renovada con terreno y decorado PBR CC0 y modelos visibles de mayor detalle.

## Estado actual

- Proyecto Godot 4.7.1 con Jolt Physics.
- Héroe visible basado en *Medieval Knight | Sculpture | Game ready*, de by__Rx (Sketchfab, CC BY 4.0), con materiales 1K, esqueleto y reposo importado.
- Combate con clic izquierdo o mando, ataque visible procedural, arco de espada, ventana de impacto y recuperación.
- Brisa usa el modelo realista *Horse*, de Henry S (Sketchfab, CC BY 4.0), con esqueleto y animaciones reales de reposo, paso y galope.
- Máquina de estados `ON_FOOT` / `MOUNTED`, con montaje y desmontaje reversible.
- Cámara orbital suave con `SpringArm3D`; al montar aumenta progresivamente altura, distancia y campo de visión.
- Terrain3D 1.0.2 integrado, con cuatro regiones, colisión dinámica y tres capas PBR CC0 de ambientCG: pradera húmeda, sendero natural y roca erosionada.
- Mapa de 512×512 metros con valle, colinas de hasta 40 metros y límites elevados.
- Sendero ocre de pendiente controlada hasta una meseta-mirador situada a 24 metros.
- Objetivo con distancia y confirmación al alcanzar el mirador.
- Renderizado Forward+ con HDRI 2K CC0 de Poly Haven, tonemapping ACES, sol bajo y relleno ambiental frío.
- Sol bajo cálido, relleno ambiental azulado y sombras largas sobre el valle.
- Niebla volumétrica ligera y bruma localizada bajo la cota del mirador.
- Resplandor sutil en el sol y la baliza del destino.
- Bosque determinista con 720 pinos adultos game-ready de LOLIPOP, 170 rocas PBR, 7.000 matas de hierba, 32.000 briznas Bermuda, 800 helechos, 900 arbustos y 42 troncos o tocones.
- Vegetación agrupada por celdas en `MultiMesh`, con LOD y distancias de visibilidad; los 720 árboles y las 170 rocas tienen colisión física.
- Hito paisajístico con acantilado fotorrealista, cascada animada de 38 metros, rocío, niebla, poza, río y audio 3D.
- Fortaleza modular CC0 de Poly Haven sobre la cornisa, compuesta por torres, muros, puerta, colisión simplificada y balizas luminosas.
- Corredor libre de árboles alrededor del sendero, del inicio, de Brisa y del mirador.
- Música ambiental original de 48 segundos con entrada suave y bucle continuo.
- Capas originales de viento y aves, mezcladas de forma independiente.
- Cuatro cascos alternos en audio 3D, sincronizados con paso, trote y galope.
- Mezcla adaptativa: al ganar velocidad sube el viento y se abren espacio la música y los pájaros.
- HUD mínimo con los controles.
- Modelos visibles con sus materiales 1K de origen; espada CC0 de Quaternius y sombreadores de agua, música y ambientes creados para el proyecto. No se usan recursos de juegos comerciales.

## Abrir y jugar

### Lanzamiento rápido en macOS

La forma más rápida es hacer doble clic en `Jugar.command`. El lanzador abre directamente la escena principal con la copia local de Godot; el primer arranque puede tardar mientras importa los recursos PBR. También puede ejecutarse desde Terminal:

```bash
./Jugar.command
```

El lanzador espera encontrar Godot 4.7.1 en `tools/runtime/Godot.app`. Ese runtime local se usa para verificar el proyecto y no se guarda en Git.

### Abrir el editor

Para editar el proyecto con ese mismo runtime:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --editor --path .
```

Dentro del editor, **F6** ejecuta la escena actual y **F5** el proyecto completo.

## Controles

| Acción | Teclado / ratón | Mando |
| --- | --- | --- |
| Caminar | `WASD` o flechas | Stick izquierdo |
| Correr | `Mayús` | Pulsar stick izquierdo |
| Saltar a pie | `Espacio` | Botón inferior |
| Atacar con espada a pie | Clic izquierdo | Botón superior |
| Montar / desmontar | `E` junto a Brisa | Botón izquierdo |
| Galopar montado | `Mayús` + dirección | Pulsar stick izquierdo + dirección |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |
| Recuperar cámara | Clic dentro del juego | — |

Si el personaje cae fuera del escenario, reaparece automáticamente en el punto inicial.

El objetivo de esta fase es seguir el sendero visible desde el punto inicial hasta el mirador. La distancia restante aparece en la parte superior de la pantalla.

## Montar a caballo

Brisa espera unos metros por delante del punto inicial. Acércate hasta que aparezca el aviso y pulsa `E`. Mientras estás montado, `WASD` o las flechas guían al caballo y `Mayús` activa el galope. Pulsa `E` de nuevo para desmontar a un lado de la montura.

El caballo visible es [*Horse*, de Henry S](https://sketchfab.com/3d-models/horse-a6f860e43e364619bccb174a1ac7d0c9), bajo CC BY 4.0. El GLB conserva un esqueleto real y animaciones importadas; `Horse` controla la física y selecciona reposo, paso o galope según la velocidad. El ancla del jinete acompaña la zancada y los cascos se sincronizan con la velocidad.

## Renovación visual PBR

Terrain3D usa [Ground 037](https://ambientcg.com/view?id=Ground037) para la pradera húmeda, [Ground 030](https://ambientcg.com/view?id=Ground030) para el sendero y [Rock 063](https://ambientcg.com/view?id=Rock063) para las laderas. Los tres materiales son CC0 de ambientCG. Cada capa combina albedo con altura y normal OpenGL con rugosidad para que Terrain3D mezcle también el relieve.

`VegetationScatter` usa una semilla fija. El arbolado procede de [*Pine trees pack (lowpoly, game ready, LODs)*, de LOLIPOP](https://sketchfab.com/3d-models/pine-trees-pack-lowpoly-game-ready-lods-e1e9c07b8e2e445c943fec660beefba2), bajo CC BY 4.0: se combinan corteza y follaje del LOD1 de nueve variantes adultas de 10 a 30 metros. Dos tipos de hierba, helechos, arbustos, rocas con musgo, troncos y tocones son mallas PBR CC0 de [Poly Haven](https://polyhaven.com/). Las instancias se reparten por celdas `MultiMesh`, con descarte por distancia y colisión en árboles y rocas.

El hito del extremo norte del valle combina los recursos [Mountainside](https://polyhaven.com/a/mountainside), [Rock Face 01](https://polyhaven.com/a/rock_face_01) y [Modular Fort 01](https://polyhaven.com/a/modular_fort_01), también CC0. La cascada, la poza y el río se construyen en Godot con geometría ligera, sombreadores propios, partículas, niebla localizada y el bucle original `waterfall.ogg`; la fortaleza utiliza seis módulos seleccionados del paquete de Poly Haven.

El héroe y el caballo visibles conservan los materiales 1K incluidos en sus paquetes de Sketchfab. [Metal Plate](https://polyhaven.com/a/metal_plate) y los materiales medievales anteriores permanecen como recursos auxiliares, pero no sustituyen los materiales del caballero visible. Los mapas empaquetados se preparan con:

```bash
python3 tools/prepare_medieval_materials.py
```

## Protagonista y combate

El cuerpo visible es [*Medieval Knight | Sculpture | Game ready*, de by__Rx](https://sketchfab.com/3d-models/medieval-knight-sculpture-game-ready-6cdd055b4afa41eb9360dbbfe75c7f10), bajo CC BY 4.0. Conserva su esqueleto y su animación de reposo importada. La respuesta visual al desplazamiento aplica un balanceo ligero sobre la pose; todavía no se presenta como un conjunto completo de animaciones retargeteadas de caminar, correr y saltar.

La espada visible procede del paquete CC0 de Quaternius y se instala en `RealisticSwordGrip` al arrancar. El ataque se genera proceduralmente durante 0,78 segundos: el torso acompaña el golpe y la espada recorre un arco amplio, mientras el área de daño solo se activa en la ventana útil. El antiguo caballero de Quaternius permanece cargado pero oculto como rig técnico heredado; no es el modelo que se ve en pantalla.

Los paquetes `human-base-animations.glb` y `human-addon-animations.glb` de [Mesh2Motion](https://github.com/Mesh2Motion/mesh2motion-app) están incluidos bajo CC0 para inspección y trabajo de retargeting. No están asignados actualmente al héroe visible de la escena principal. La antigua escena de posada `MedievalSetDressing` también permanece en el repositorio, pero el mundo principal ya no la instancia: el gran decorado activo es la cascada con la fortaleza de Poly Haven.

## Música y sonido ambiental

`AmbientAudio` mezcla tres capas largas: `horizon_theme.ogg`, `valley_wind.ogg` y `distant_birds.ogg`. Los buses `Music`, `Ambience` y `SFX` permiten ajustar cada familia por separado y aplican una reverberación ligera distinta a la música y al valle.

Los cascos viven en un `AudioStreamPlayer3D` dentro de Brisa. La velocidad controla intervalo, volumen y tono; cuatro impactos alternados evitan una repetición mecánica. Al desmontar o detenerse, el emisor deja de disparar sonidos.

La cascada añade un emisor ambiental 3D en la base del salto, con atenuación por distancia para integrarse con el viento y las aves al aproximarse al acantilado.

Toda la música y los efectos son composición y síntesis originales, generadas de forma determinista con:

```bash
python3 tools/generate_audio.py
```

La regeneración requiere Python con NumPy y FFmpeg. Los bucles finales se guardan como Ogg Vorbis y los impactos cortos como WAV.

## Luz y atmósfera

`WorldEnvironment` usa el HDRI CC0 [Kloppenheim 06 Pure Sky](https://polyhaven.com/a/kloppenheim_06_puresky), un sol rasante y niebla volumétrica. La niebla global aporta profundidad a larga distancia; `ValleyMist` concentra una capa más visible en la parte baja del valle y la cascada añade su propio volumen de bruma.

La escena requiere el renderizador **Forward+** para mostrar la niebla volumétrica. Godot puede recurrir a Compatibility en equipos sin Metal, Vulkan o Direct3D 12, pero en ese caso el juego seguirá siendo jugable con una atmósfera visual más sencilla.

## Editar el terreno

Terrain3D ya está activado como plugin. Al abrir `scenes/world.tscn`, selecciona el nodo `Terrain3D` para mostrar sus herramientas de esculpido y pintura. Los datos editables están en `terrain/data`.

El paisaje base se puede regenerar de forma determinista con:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/generate_terrain.gd
```

La regeneración sustituye el relieve y el mapa de control, pero preserva `terrain/data/assets.tres` y `terrain/data/material.tres`, incluidas las capas PBR configuradas. Debe ejecutarse antes de retoques manuales de altura o pintura de control que se quieran conservar.

## Pruebas

Se han ejecutado con Godot 4.7.1:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit-after 3
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/player_movement_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/terrain_route_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/atmosphere_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/mounting_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/vegetation_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/audio_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/medieval_combat_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/epic_landmark_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_stability_test.gd
```

Las pruebas cubren importación, Terrain3D, ruta, atmósfera, movimiento, montura, audio, dispersión de vegetación, colisiones, visibilidad y esqueleto de los modelos realistas, animación real del caballo, reposo importado del héroe, arco procedural de la espada, impactos y el hito de cascada y fortaleza. La prueba de estabilidad mantiene además el juego vivo para detectar errores de ejecución.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada; no afecta al juego ni a las pruebas.

## Estructura

```text
assets/     modelos y animaciones CC0/CC BY 4.0, texturas PBR y contenido original
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

El código original de este repositorio se distribuye con licencia MIT; consulta [LICENSE](LICENSE). Terrain3D (MIT), Quaternius, Poly Haven, ambientCG y las animaciones de Mesh2Motion (CC0), además del héroe de by__Rx, el caballo de Henry S y los pinos de LOLIPOP (CC BY 4.0), están registrados con enlaces directos en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). También hay registros locales para el [héroe](assets/models/realistic_hero/SOURCES.md), el [caballo](assets/models/realistic_horse/SOURCES.md), los [pinos](assets/models/realistic_pines/SOURCES.md) y las [animaciones de Mesh2Motion](assets/animations/mesh2motion/SOURCES.md). La música, los ambientes —incluida la cascada— y los sombreadores de agua son obras originales del proyecto. No se permite material extraído de Nintendo ni de ningún juego comercial.
