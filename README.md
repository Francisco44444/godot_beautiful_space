# Senderos del Horizonte

Juego de aventura y exploración medieval en tercera persona, construido con Godot 4.7, GDScript y Terrain3D. Las Fases 0 a 6 forman ya una vertical jugable con protagonista, combate, montura, valle, vegetación, arquitectura y paisaje sonoro.

## Estado actual

- Proyecto Godot 4.7.1 con Jolt Physics.
- Aventurero medieval original CC0, con esqueleto, materiales PBR de lana y cuero, espada equipada y animaciones de reposo, marcha, carrera, salto y ataque.
- Combate con clic izquierdo o mando, ventana de impacto, recuperación y cajas rompibles de dos golpes.
- Caballo CC0 llamado Brisa, con esqueleto y animaciones de reposo, paso, trote y galope.
- Máquina de estados `ON_FOOT` / `MOUNTED`, con montaje y desmontaje reversible.
- Material triplanar de pelaje con albedo, normal y rugosidad originales.
- Cámara orbital suave con `SpringArm3D`; al montar aumenta progresivamente altura, distancia y campo de visión.
- Terrain3D 1.0.2 integrado, con cuatro regiones y colisión dinámica.
- Mapa de 512×512 metros con valle, colinas de hasta 40 metros y límites elevados.
- Sendero ocre de pendiente controlada hasta una meseta-mirador situada a 24 metros.
- Objetivo con distancia y confirmación al alcanzar el mirador.
- Renderizado Forward+ con cielo procedural de atardecer y tonemapping ACES.
- Sol bajo cálido, relleno ambiental azulado y sombras largas sobre el valle.
- Niebla volumétrica ligera y bruma localizada bajo la cota del mirador.
- Resplandor sutil en el sol y la baliza del destino.
- Bosque determinista de 420 pinos, 190 rocas y 6.200 matas de hierba.
- Dibujado por `MultiMesh` y distancias de visibilidad; los 420 árboles y las 190 rocas tienen colisión física.
- Posada modular, carro, cercas, cajas rompibles y ruinas construidos con 38 piezas CC0 y 36 cuerpos sólidos.
- Corredor libre de árboles alrededor del sendero, del inicio, de Brisa y del mirador.
- Música ambiental original de 48 segundos con entrada suave y loop continuo.
- Capas originales de viento y aves, mezcladas de forma independiente.
- Cuatro cascos alternos en audio 3D, sincronizados con paso, trote y galope.
- Mezcla adaptativa: al ganar velocidad sube el viento y se abren espacio la música y los pájaros.
- HUD mínimo con los controles.
- Terreno y roca con mapas PBR CC0 de Poly Haven; materiales propios para vestuario, corteza, ramas y pelaje. No se usan recursos de juegos comerciales.

## Abrir y jugar

La versión oficial 4.7.1 descargada para verificar el proyecto está en `tools/runtime/Godot.app` y no se guarda en Git.

La forma más rápida en macOS es hacer doble clic en `Jugar.command`. También puede ejecutarse desde Terminal:

```bash
./Jugar.command
```

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
| Atacar con espada | Clic izquierdo | Botón superior |
| Montar / desmontar | `E` junto a Brisa | Botón izquierdo |
| Galopar montado | `Mayús` + dirección | Pulsar stick izquierdo + dirección |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |
| Recuperar cámara | Clic dentro del juego | — |

Si el personaje cae fuera del escenario, reaparece automáticamente en el punto inicial.

El objetivo de esta fase es seguir el sendero visible desde el punto inicial hasta el mirador. La distancia restante aparece en la parte superior de la pantalla.

## Montar a caballo

Brisa espera unos metros por delante del punto inicial. Acércate hasta que aparezca el aviso y pulsa `E`. Mientras estás montado, `WASD` o las flechas guían al caballo y `Mayús` activa el galope. Pulsa `E` de nuevo para desmontar a un lado de la montura.

El modelo animado procede del paquete CC0 de Quaternius. `Player` conserva la máquina de estados, mientras `Horse` controla su propia física y selecciona `Idle`, `WalkSlow`, `Walk` o `Run` según la velocidad. El material de pelaje se proyecta en los tres ejes para evitar estiramientos en una malla sin UV.

## Vegetación y materiales

`VegetationScatter` usa una semilla fija para reconstruir siempre el mismo decorado. Los troncos, las ramas recortadas con alfa, las rocas y la hierba se agrupan en cuatro `MultiMeshInstance3D`; la densidad visual no implica crear miles de nodos. Cada árbol y cada roca visible tiene colisión.

Pradera, sendero adoquinado y roca usan albedo, normal y rugosidad CC0 de Poly Haven. La corteza, las agujas, el pelaje y los materiales de vestuario son propios. Los mapas combinados normal/roughness se preparan con:

```bash
python3 tools/prepare_medieval_materials.py
```

## Combate y ambientación medieval

El protagonista usa el esqueleto y las animaciones del caballero CC0 de Quaternius. La espada se enlaza en tiempo de ejecución al hueso `Palm.R`; el área de daño solo se activa durante la parte útil de la animación. Las cajas cercanas al carro y al mirador reaccionan al primer golpe y se rompen con el segundo.

`MedievalSetDressing` coloca de forma determinista una posada de entramado, cubierta de tejas, carro, cercas, cajas y restos de muros. Cada elemento sólido recibe una forma de colisión simplificada para mantener la física estable sin usar colisión cóncava compleja.

## Música y sonido ambiental

`AmbientAudio` mezcla tres capas largas: `horizon_theme.ogg`, `valley_wind.ogg` y `distant_birds.ogg`. Los buses `Music`, `Ambience` y `SFX` permiten ajustar cada familia por separado y aplican una reverberación ligera distinta a la música y al valle.

Los cascos viven en un `AudioStreamPlayer3D` dentro de Brisa. La velocidad controla intervalo, volumen y tono; cuatro impactos alternados evitan una repetición mecánica. Al desmontar o detenerse, el emisor deja de disparar sonidos.

Toda la música y los efectos son composición y síntesis originales, generadas de forma determinista con:

```bash
python3 tools/generate_audio.py
```

La regeneración requiere Python con NumPy y FFmpeg. Los loops finales se guardan como Ogg Vorbis y los impactos cortos como WAV.

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
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/vegetation_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/audio_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/medieval_combat_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_stability_test.gd
```

Las pruebas validan importación, Terrain3D, ruta, atmósfera, movimiento, montura, audio, densidades, las 610 colisiones del bosque y las rocas, el esqueleto del héroe, la espada enlazada, sus animaciones, impactos, cajas rompibles y decorado medieval. La prueba de estabilidad mantiene además el juego vivo para detectar errores de ejecución.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada; no afecta al juego ni a las pruebas.

## Estructura

```text
assets/     modelos CC0, texturas PBR CC0 y contenido original del proyecto
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

El código original de este repositorio se distribuye con licencia MIT; consulta [LICENSE](LICENSE). Terrain3D (MIT), los modelos de Quaternius (CC0) y los materiales de Poly Haven (CC0) están registrados en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). La música, los ambientes y los materiales de vestuario son obras originales del proyecto. No se permite material extraído de Nintendo ni de ningún juego comercial.
