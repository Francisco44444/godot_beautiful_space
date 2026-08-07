# Senderos del Horizonte

Aventura medieval en tercera persona construida con Godot 4.7, GDScript y Terrain3D. La dirección visual del juego es ahora coherente con los packs estilizados CC0 de Quaternius: protagonista, caballo, fauna, bosque, plantas, rocas y arquitectura comparten el mismo lenguaje artístico.

## Estado actual

- Protagonista `Cowboy_Male` de Quaternius con sombrero y bigote, piel recoloreada a un naranja humano y animaciones de reposo, caminar, correr, saltar y atacar.
- Biblioteca local completa de 50 personajes glTF del *Ultimate Animated Character Pack*.
- Cuchillo del *Survival Pack* visible, ataque cuerpo a cuerpo, ventana de impacto y objetos rompibles.
- Caballo animado de Quaternius con reposo, paso y galope; jinete sentado sobre la silla y montaje reversible.
- Seis animales Quaternius —ciervos, zorro, lobo y venado— que detectan al jugador y se apartan.
- Cámara orbital abierta: 10 m a pie y 16 m al montar, con transición suave y mayor campo visual.
- Isla Terrain3D de 10×10 km —100 km²— dividida en 16 regiones con costa, cordillera nevada, desierto, praderas, riscos y ocho caminos conectados.
- Cinco tiles originales low-poly: pradera, sendero, roca, arena y nieve, sin microdetalle PBR fotográfico.
- Senderos abrazados por un bosque masivo de 24.000 árboles Quaternius, además de cuatro reservas forestales profundas; más del 99% son verdes y los rojos quedan como acento excepcional.
- Sotobosque Quaternius con 110.000 hierbas animadas por brisa y ráfagas, 10.000 arbustos, 10.000 helechos y plantas, 8.000 flores, 2.200 setas, 3.000 rocas y 12.000 guijarros, concentrados visualmente junto a las rutas.
- Rutas estrechas de tierra y tres calzadas mixtas reforzadas con 9.000 piezas de piedra Quaternius.
- Todos los grupos numerosos usan `MultiMesh` dividido por celdas y descarte por distancia.
- Seis villas y ocho caseríos rurales con 54 casas de unos 11×19 m; diez tienen tres plantas, todas poseen acceso a ras del terreno y hastiales cerrados, además de calles, faroles nocturnos y tres castillos construidos con el *Medieval Village MegaKit* de Quaternius.
- Risco y fortaleza estilizados con módulos Quaternius; la cascada, poza y río han sido retirados.
- Ciclo completo de día, atardecer y noche con una luna low-poly de 176 m, textura original de cráteres, iluminación y sombras; durante el día se retira por completo del render para evitar artefactos negros.
- Mar low-poly animado rodeando la isla, playas facetadas y tres bancos de niebla regional en bosques y zonas tenebrosas.
- Minimap superior permanente y mapa completo con pueblos, castillos, bosques, biomas y posición del jugador mediante `M`.
- Música ambiental, viento, pájaros y cuatro sonidos de cascos.

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
| Atacar con cuchillo | Clic izquierdo | Botón superior |
| Montar / desmontar | `E` junto a Brisa | Botón izquierdo |
| Galopar | `Mayús` + dirección | Stick + pulsación |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |
| Abrir / cerrar mapa de la isla | `M` | — |
| Viajar a Dunas / Nieve / Villa / Bosque | `1` / `2` / `3` / `4` | — |

El objetivo es seguir el sendero hasta el mirador. Si el personaje cae fuera del escenario, reaparece en el inicio.

## Dirección visual Quaternius

`VegetationScatter` carga los modelos glTF del *Stylized Nature Mega Kit* en tiempo de ejecución y extrae sus mallas conservando los materiales originales. Los árboles adultos forman bandas densas a ambos lados de los ocho caminos y cuatro reservas forestales; los árboles retorcidos rojos no superan el 1% del total. La hierba usa un shader de deformación con movimiento base muy leve y ráfagas periódicas. Los elementos cercanos a las rutas y una muestra del bosque profundo reciben colisiones simplificadas, mientras la geometría distante permanece en `MultiMesh` para conservar rendimiento.

`MedievalSetDressing` monta seis villas, ocho caseríos, 54 casas y tres castillos. Cada vivienda parte de un módulo Quaternius 8×14 ampliado a unos 11×19 m, con dos o tres pisos visuales, suelo interior, paredes físicas independientes, dos hastiales completos y un hueco de puerta de 2,7 m realmente atravesable. La cota de cada suelo se calcula en la puerta para que el umbral quede a ras del terreno. El antiguo hito de la cascada —incluidos sus tejados flotantes y su muro de rocas— se eliminó por completo.

Los personajes se encuentran en `assets/quaternius/ultimate_animated_characters/glTF`; el juego usa `Cowboy_Male` y sustituye en ejecución únicamente su material `Skin`, preservando ojos, bigote, cabello y ropa. Quedan disponibles aldeanos, trabajadores, vikingos, elfos, goblins, magos, piratas, ninjas y otras variantes para NPC futuros. Los animales viven en `assets/quaternius/ultimate_animated_animals`.

El *Survival Pack - Sept 2020* está disponible en `assets/quaternius/Survival Pack - Sept 2020`; el cuchillo activo se construye directamente desde su OBJ y no depende de cachés locales de importación. La *Universal Animation Library 2* está en `assets/animations` para acciones futuras; la locomoción actual usa las animaciones del propio caballero, aceleradas para sincronizar pies y velocidad.

## Terreno y atmósfera

Terrain3D utiliza cinco tiles de albedo originales en `assets/textures/stylized_terrain`: pradera, sendero ocre, roca con musgo, arena dorada y nieve alpina. Están diseñados a 1024², preparados para repetición exacta y deliberadamente prescinden de normal/height fotográficos. Las 16 regiones usan una separación de vértices de 9,765625 m para representar exactamente 100 km² con geometría low-poly y LOD. Los senderos se estrechan a una banda nominal de 5–13 m; algunos permanecen de tierra y otros reciben una capa discontinua de piedra. El escenario añade mar facetado animado, sol diurno geométrico y opaco, cielo procedural sin disco negro, luna texturizada luminosa, ciclo nocturno, estrellas, tonemapping ACES, niebla global y bancos locales en bosques.

La textura lunar original está en `assets/textures/moon/moon_craters_lowpoly.png` y se generó como albedo estilizado para envolver la esfera 3D, no como una imagen plana de la luna sobre el cielo.

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
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/island_world_test.gd
```

La prueba de vegetación valida los 50 personajes, la fauna reactiva, el caballo, las 188.200 instancias principales, las calzadas, el viento de la hierba, los bosques densos, las celdas `MultiMesh`, las colisiones y el reparto de color. `island_world_test.gd` comprueba los 100 km², ocho rutas, mapa con `M`, viaje rápido 1–4, 54 casas transitables, umbrales, pisos y hastiales; `atmosphere_test.gd` valida la visibilidad independiente del sol y la luna.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada y no afecta al juego.

## Estructura

```text
assets/     packs Quaternius CC0, materiales Terrain3D y audio original
addons/     Terrain3D
scenes/     escenas de Godot
scripts/    jugabilidad y sistemas visuales
shaders/    efectos visuales
terrain/    regiones y configuración Terrain3D
tests/      pruebas headless
tools/      utilidades y runtime local ignorado por Git
```

## Licencias

El código original se distribuye bajo MIT. Quaternius y ambientCG se usan bajo CC0; Terrain3D bajo MIT. Los nuevos tiles estilizados, la música y los ambientes son originales del proyecto. Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No se incluyen recursos extraídos de Nintendo ni de ningún videojuego comercial.
