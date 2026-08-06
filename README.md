# Senderos del Horizonte

Aventura medieval en tercera persona construida con Godot 4.7, GDScript y Terrain3D. La dirección visual del juego es ahora coherente con los packs estilizados CC0 de Quaternius: protagonista, caballo, fauna, bosque, plantas, rocas y arquitectura comparten el mismo lenguaje artístico.

## Estado actual

- Protagonista `Knight_Golden_Male` de Quaternius con animaciones de reposo, caminar, correr, saltar y atacar.
- Biblioteca local completa de 50 personajes glTF del *Ultimate Animated Character Pack*.
- Cuchillo del *Survival Pack* visible, ataque cuerpo a cuerpo, ventana de impacto y objetos rompibles.
- Caballo animado de Quaternius con reposo, paso y galope; jinete sentado sobre la silla y montaje reversible.
- Seis animales Quaternius —ciervos, zorro, lobo y venado— que detectan al jugador y se apartan.
- Cámara orbital abierta: 10 m a pie y 16 m al montar, con transición suave y mayor campo visual.
- Terrain3D con cuatro regiones, colinas, valle, sendero ocre, colisión y tres tiles originales totalmente estilizados, sin microdetalle PBR fotográfico.
- Escenario explorado de extremo a extremo, con 760 árboles Quaternius y colisión física: más del 99% son verdes y los rojos quedan como acento excepcional.
- Sotobosque Quaternius con 14.000 hierbas, 1.500 flores, 620 arbustos, 520 helechos y plantas, 190 setas, 220 rocas y 720 guijarros.
- Todos los grupos numerosos usan `MultiMesh` dividido por celdas y descarte por distancia.
- Tres pequeños pueblos con ocho casas, cercas, carros, cajas y ruinas construidos con el *Medieval Village MegaKit* de Quaternius.
- Risco y fortaleza estilizados con módulos Quaternius; la cascada, poza y río han sido retirados.
- Ciclo solar continuo y cielo procedural con solo dos capas ligeras de nubes deformadas y desplazadas por shader en la GPU, sin bóveda UV ni costura vertical.
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

El objetivo es seguir el sendero hasta el mirador. Si el personaje cae fuera del escenario, reaparece en el inicio.

## Dirección visual Quaternius

`VegetationScatter` carga los modelos glTF del *Stylized Nature Mega Kit* en tiempo de ejecución y extrae sus mallas conservando los materiales originales. Los árboles adultos forman bosques separados por praderas y un corredor despejado de más de 22 m; los árboles retorcidos rojos no superan el 1% del total. Los árboles y las rocas reciben colisiones simplificadas.

`MedievalSetDressing` monta tres aldeas repartidas entre los extremos del mapa con ocho casas, carros, cercas, enredaderas y cajas rompibles del *Medieval Village MegaKit*. `EpicLandmark` reutiliza rocas y módulos arquitectónicos Quaternius para formar un risco coronado por una fortaleza.

Los personajes se encuentran en `assets/quaternius/ultimate_animated_characters/glTF`; el juego usa el caballero dorado, pero quedan disponibles aldeanos, trabajadores, vikingos, elfos, goblins, magos, piratas, ninjas y otras variantes para NPC futuros. Los animales viven en `assets/quaternius/ultimate_animated_animals`.

El *Survival Pack - Sept 2020* está disponible en `assets/quaternius/Survival Pack - Sept 2020`; el cuchillo activo se construye directamente desde su OBJ y no depende de cachés locales de importación. La *Universal Animation Library 2* está en `assets/animations` para acciones futuras; la locomoción actual usa las animaciones del propio caballero, aceleradas para sincronizar pies y velocidad.

## Terreno y atmósfera

Terrain3D utiliza tres tiles de albedo originales en `assets/textures/stylized_terrain`: pradera, sendero ocre y roca con musgo. Están diseñados a 1024², preparados para repetición exacta y deliberadamente prescinden de normal/height fotográficos para conservar la lectura low-poly de Quaternius. El escenario usa cielo procedural, iluminación cálida, tonemapping ACES, niebla volumétrica ligera y dos capas de nubes animadas.

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

La prueba de vegetación valida los 50 personajes, la fauna reactiva, el caballo, las 18.530 instancias visuales, los tres pueblos, las celdas `MultiMesh`, las colisiones, el reparto de color y la extensión completa del escenario.

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
