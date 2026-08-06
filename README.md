# Senderos del Horizonte

Aventura medieval en tercera persona construida con Godot 4.7, GDScript y Terrain3D. La dirección visual del juego es ahora coherente con los packs estilizados CC0 de Quaternius: protagonista, caballo, fauna, bosque, plantas, rocas y arquitectura comparten el mismo lenguaje artístico.

## Estado actual

- Protagonista `Knight_Golden_Male` de Quaternius con `Idle`, `Walk`, `Run`, `Jump` y `SwordSlash`.
- Biblioteca local completa de 50 personajes glTF del *Ultimate Animated Character Pack*.
- Espada visible, ataque cuerpo a cuerpo, ventana de impacto y objetos rompibles.
- Caballo animado de Quaternius con reposo, paso y galope; montaje y desmontaje reversibles.
- Seis animales Quaternius distribuidos por el valle: ciervos, zorro, lobo y venado.
- Cámara orbital más abierta: 7,4 m a pie y 12 m al montar, con transición suave.
- Terrain3D con cuatro regiones, colinas, valle, sendero ocre, colisión y tres materiales CC0 de ambientCG teñidos con una paleta más estilizada.
- Bosque determinista con 1.050 árboles Quaternius y colisión física.
- Sotobosque Quaternius con 18.000 hierbas, 1.800 flores, 800 arbustos, 650 helechos y plantas, 260 setas, 280 rocas y 520 guijarros.
- Todos los grupos numerosos usan `MultiMesh` dividido por celdas y descarte por distancia.
- Posada, cercas, carro, cajas y ruinas construidos con el *Medieval Village MegaKit* de Quaternius.
- Cascada animada de 38 m, poza, río, rocío, niebla y fortaleza estilizada con módulos Quaternius.
- Cielo procedural luminoso con varias capas de nubes en movimiento.
- Música ambiental, viento, pájaros, cascada y cuatro sonidos de cascos.

## Abrir y jugar

En macOS, haz doble clic en `Jugar.command` o ejecútalo desde Terminal:

```bash
./Jugar.command
```

El lanzador utiliza Godot 4.7.1 desde `tools/runtime/Godot.app`. Para abrir el editor:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --editor --path .
```

Dentro del editor, `F5` ejecuta el proyecto completo.

## Controles

| Acción | Teclado / ratón | Mando |
| --- | --- | --- |
| Caminar | `WASD` o flechas | Stick izquierdo |
| Correr | `Mayús` | Pulsar stick izquierdo |
| Saltar | `Espacio` | Botón inferior |
| Atacar | Clic izquierdo | Botón superior |
| Montar / desmontar | `E` junto a Brisa | Botón izquierdo |
| Galopar | `Mayús` + dirección | Stick + pulsación |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |

El objetivo es seguir el sendero hasta el mirador. Si el personaje cae fuera del escenario, reaparece en el inicio.

## Dirección visual Quaternius

`VegetationScatter` carga los modelos glTF del *Stylized Nature Mega Kit* en tiempo de ejecución y extrae sus mallas conservando los materiales originales. Los árboles adultos se reparten en masas densas a ambos lados del sendero; la ruta, el inicio, el caballo y el mirador conservan claros jugables. Los árboles y las rocas reciben colisiones simplificadas.

`MedievalSetDressing` monta una pequeña posada con arquitectura, carro, cercas, enredaderas y cajas rompibles del *Medieval Village MegaKit*. `EpicLandmark` reutiliza rocas y módulos arquitectónicos Quaternius para integrar la cascada y la fortaleza en la misma estética.

Los personajes se encuentran en `assets/quaternius/ultimate_animated_characters/glTF`; el juego usa el caballero dorado, pero quedan disponibles aldeanos, trabajadores, vikingos, elfos, goblins, magos, piratas, ninjas y otras variantes para NPC futuros. Los animales viven en `assets/quaternius/ultimate_animated_animals`.

Los formatos duplicados y los antiguos packs fotorrealistas se han retirado del árbol importable. Se conserva una copia recuperable local en `archive/legacy_assets_2026-08-06`, ignorada por Git y por Godot.

## Terreno y atmósfera

Terrain3D utiliza [Ground 037](https://ambientcg.com/view?id=Ground037), [Ground 030](https://ambientcg.com/view?id=Ground030) y [Rock 063](https://ambientcg.com/view?id=Rock063), todos CC0. El escenario usa cielo procedural, iluminación cálida, tonemapping ACES, niebla volumétrica ligera y nubes animadas.

El relieve se puede regenerar de forma determinista con:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/generate_terrain.gd
```

La regeneración sustituye el relieve y el mapa de control, por lo que debe ejecutarse antes de cualquier retoque manual que se quiera conservar.

## Pruebas

Las comprobaciones principales se ejecutan con:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/vegetation_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/epic_landmark_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_stability_test.gd
```

La prueba de vegetación valida los 50 personajes, la fauna, el caballo, las 23.360 instancias visuales, las celdas `MultiMesh`, las colisiones y el corredor libre del sendero.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada y no afecta al juego.

## Estructura

```text
assets/     packs Quaternius CC0, materiales Terrain3D y audio original
addons/     Terrain3D
scenes/     escenas de Godot
scripts/    jugabilidad y sistemas visuales
shaders/    agua, cascada y efectos
terrain/    regiones y configuración Terrain3D
tests/      pruebas headless
tools/      utilidades y runtime local ignorado por Git
```

## Licencias

El código original se distribuye bajo MIT. Quaternius y ambientCG se usan bajo CC0; Terrain3D bajo MIT. La música, los ambientes y los sombreadores de agua son originales del proyecto. Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No se incluyen recursos extraídos de Nintendo ni de ningún videojuego comercial.
