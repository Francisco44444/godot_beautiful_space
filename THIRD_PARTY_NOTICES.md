# Avisos de terceros

## Terrain3D 1.0.2-stable

- Proyecto: Terrain3D, de Tokisan Games y colaboradores.
- Fuente: <https://github.com/TokisanGames/Terrain3D>
- Versión integrada: `v1.0.2-stable`, publicada el 19 de mayo de 2026.
- Licencia: [MIT](https://github.com/TokisanGames/Terrain3D/blob/v1.0.2-stable/LICENSE.txt).
- Copia de la licencia: `addons/terrain_3d/LICENSE.txt`.

Se distribuye el addon binario oficial sin modificar dentro de `addons/terrain_3d`. Los mapas, texturas procedurales, escenas y scripts específicos de *Senderos del Horizonte* no proceden del demo de Terrain3D.

## Medieval Knight | Sculpture | Game ready — héroe visible

- Autor: by__Rx.
- Fuente: <https://sketchfab.com/3d-models/medieval-knight-sculpture-game-ready-6cdd055b4afa41eb9360dbbfe75c7f10>.
- Recurso integrado: `assets/models/realistic_hero/medieval_knight_by_rx_1k.glb` y sus nueve texturas PNG 1K.
- Licencia: [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
- Registro local: `assets/models/realistic_hero/SOURCES.md`.

Este es el cuerpo visible del protagonista. Godot ajusta su escala en la escena y el proyecto añade fuera del GLB una espada CC0, balanceo de desplazamiento y un ataque procedural. El modelo conserva su animación de reposo importada; no se afirma que disponga actualmente de un conjunto completo de animaciones jugables retargeteadas.

## Horse — caballo visible

- Autor: Henry S.
- Fuente: <https://sketchfab.com/3d-models/horse-a6f860e43e364619bccb174a1ac7d0c9>.
- Recurso integrado: `assets/models/realistic_horse/horse_henry_s_1k.glb` y sus ocho texturas PNG 1K.
- Licencia: [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
- Registro local: `assets/models/realistic_horse/SOURCES.md`.

Este GLB es la representación visible de Brisa. La integración ajusta escala y orientación en Godot, selecciona las animaciones importadas de reposo, paso y galope según la velocidad y añade física, montaje y audio sin atribuir esas ampliaciones al autor del modelo.

## Mesh2Motion — paquetes de animación humana

- Proyecto: Mesh2Motion.
- Repositorio: <https://github.com/Mesh2Motion/mesh2motion-app>.
- Recursos integrados: `human-base-animations.glb`, `human-addon-animations.glb` y sus paletas de color en `assets/animations/mesh2motion`.
- Fuentes directas: [paquete base](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/static/animations/human-base-animations.glb) y [paquete adicional](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/static/animations/human-addon-animations.glb).
- Licencia de los recursos artísticos: [CC0 1.0 Universal](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/LICENSE-CC0.MD).
- Registro local: `assets/animations/mesh2motion/SOURCES.md`.

La declaración oficial cubre expresamente modelos 3D, archivos Blender, rigs y animaciones; el código de la aplicación usa una [licencia MIT separada](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/LICENSE-MIT.MD). Este proyecto sólo incluye los paquetes artísticos. Permanecen disponibles para inspección y retargeting, pero no están asignados al héroe visible del mundo principal.

## Pine trees pack (lowpoly, game ready, LODs) — arbolado visible

- Autor: LOLIPOP (`@lolipop_1707`).
- Fuente: <https://sketchfab.com/3d-models/pine-trees-pack-lowpoly-game-ready-lods-e1e9c07b8e2e445c943fec660beefba2>.
- Recurso integrado: variante GLB con texturas 1K en `assets/models/realistic_pines`.
- Licencia: [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
- Registro local: `assets/models/realistic_pines/SOURCES.md`.

El juego combina las superficies de corteza y follaje del LOD1 de nueve pinos adultos, corrige el eje Z-up del paquete y los distribuye mediante `MultiMesh`. La selección de LOD, la corrección de orientación, el scattering, las colisiones y la optimización son adaptaciones del proyecto y no implican respaldo del autor.

## Farm Animals Pack — caballo legado no activo

- Autor: Quaternius.
- Fuente oficial: <https://quaternius.com/packs/farmanimal.html>
- Espejo de descarga: <https://opengameart.org/content/lowpoly-animated-farm-animal-pack>
- Recurso integrado: `assets/models/horse/Horse.fbx`.
- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) / dominio público.
- Copia de la licencia: `assets/models/horse/LICENSE-CC0.txt`.

El archivo se conserva como recurso legado, pero la escena principal ya no lo referencia ni lo muestra. El caballo visible actual es *Horse*, de Henry S, documentado arriba.

## LowPoly Animated Knight — rig legado y espada

- Autor: Quaternius.
- Fuente: <https://opengameart.org/content/lowpoly-animated-knight>
- Recursos integrados: `assets/models/medieval_hero/KnightCharacter.fbx` y `Sword.fbx`.
- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) / dominio público.
- Copia del aviso: `assets/models/medieval_hero/LICENSE-CC0.txt`.

`KnightCharacter.fbx` permanece cargado pero oculto como rig técnico heredado. `Sword.fbx` aporta la espada visible añadida en tiempo de ejecución al nuevo héroe de by__Rx. El caballero de Quaternius no es el cuerpo que se muestra actualmente en pantalla. Ningún recurso reproduce a Link ni usa diseños, modelos o texturas de Nintendo.

## Medieval Village MegaKit — arquitectura y atrezo

- Autor: Quaternius.
- Fuente oficial: <https://quaternius.com/packs/medievalvillagemegakit.html>
- Espejo: <https://opengameart.org/content/medieval-village-megakit>
- Recursos integrados: selección de muros, cubierta, puerta, escalera, cercas, carro, cajas y vegetación trepadora en `assets/models/medieval_village`.
- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) / dominio público.
- Copia del aviso: `assets/models/medieval_village/LICENSE-CC0.txt`.

Los archivos y la escena de decorado se conservan en el repositorio, pero `scenes/world.tscn` ya no instancia `MedievalSetDressing`; la fortaleza activa procede de Poly Haven.

## Poly Haven — materiales PBR

- [Forest Ground 03](https://polyhaven.com/a/forrest_ground_03), de Rob Tuytel.
- [Mossy Cobblestone](https://polyhaven.com/a/mossy_cobblestone), de Sơn Nguyễn.
- [Mossy Rock](https://polyhaven.com/a/mossy_rock), de Rob Tuytel.
- [Metal Plate](https://polyhaven.com/a/metal_plate), de Dimitrios Savva; conservado como material auxiliar, no como material del caballero visible actual.
- Mapas integrados: albedo, normal OpenGL y rugosidad a 1K; `Metal Plate` incluye además el mapa metálico.
- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) / dominio público; consulta también la [licencia de Poly Haven](https://polyhaven.com/license).
- Registro local: `assets/textures/cc0/polyhaven/SOURCES.md`.

## Poly Haven — decorado fotorrealista

| Recurso | Uso en el juego |
| --- | --- |
| [Fir Sapling](https://polyhaven.com/a/fir_sapling) | Recurso legado conservado; el bosque activo usa los pinos de LOLIPOP |
| [Grass Medium 01](https://polyhaven.com/a/grass_medium_01) | Matas de hierba PBR |
| [Grass Bermuda 01](https://polyhaven.com/a/grass_bermuda_01) | Césped ligero de relleno cercano |
| [Fern 02](https://polyhaven.com/a/fern_02) | Helechos del sotobosque |
| [Shrub 03](https://polyhaven.com/a/shrub_03) | Arbustos del sotobosque |
| [Rock Moss Set 01](https://polyhaven.com/a/rock_moss_set_01) | Rocas escaneadas con musgo |
| [Mountainside](https://polyhaven.com/a/mountainside) | Macizo principal del acantilado y la cascada |
| [Rock Face 01](https://polyhaven.com/a/rock_face_01) | Paredes rocosas y ribera de la poza |
| [Dead Tree Trunk](https://polyhaven.com/a/dead_tree_trunk) | Troncos caídos |
| [Tree Stump 01](https://polyhaven.com/a/tree_stump_01) | Tocones y raíces |
| [Modular Fort 01](https://polyhaven.com/a/modular_fort_01) | Fortaleza de la cornisa |
| [Kloofendal Misty Morning](https://polyhaven.com/a/kloofendal_misty_morning) | HDRI alternativo incluido |
| [Kloppenheim 06 Pure Sky](https://polyhaven.com/a/kloppenheim_06_puresky) | HDRI activo del amanecer |

- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) / dominio público; consulta también la [licencia de Poly Haven](https://polyhaven.com/license).
- Registro local: `assets/models/photorealistic/SOURCES.md`.

## ambientCG — materiales Terrain3D

- [Ground 037](https://ambientcg.com/view?id=Ground037): pradera húmeda, musgo y tierra.
- [Ground 030](https://ambientcg.com/view?id=Ground030): sendero de tierra, hierba y guijarros.
- [Rock 063](https://ambientcg.com/view?id=Rock063): laderas y roca erosionada.
- Mapas integrados: color, desplazamiento, normal OpenGL, oclusión ambiental y rugosidad a 1K; para Terrain3D se derivan los paquetes albedo+altura y normal+rugosidad.
- Licencia: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) / dominio público; consulta también la [información de licencia de ambientCG](https://docs.ambientcg.com/license/).
- Registro local: `assets/textures/cc0/ambientcg/SOURCES.md`.

La geometría de la cascada, la poza y el río, sus sombreadores, las partículas, la niebla localizada y `assets/audio/original/waterfall.ogg` son contenido original del proyecto; no proceden de estos paquetes de terceros.

No se han incorporado modelos, texturas, música ni otros recursos de videojuegos comerciales.
