# Senderos del Horizonte

Aventura medieval en tercera persona construida con Godot 4.7, GDScript y Terrain3D. La dirección visual del juego es ahora coherente con los packs estilizados CC0 de Quaternius: protagonista, caballo, fauna, bosque, plantas, rocas y arquitectura comparten el mismo lenguaje artístico.

## Estado actual

- Protagonista animado de Quaternius, seleccionable entre ocho aventureros, con piel recoloreada a un tono humano y animaciones de reposo, caminar, correr, saltar y atacar.
- Biblioteca local completa de 50 personajes glTF del *Ultimate Animated Character Pack*.
- Perfil de jugador persistente con nombre y ocho héroes Quaternius seleccionables al entrar o desde `Z`.
- Inventario persistente con todos los objetos del *Ultimate RPG Items Pack*: armas sustituibles, armaduras, llaves, pociones, libros, minerales, monedas y tesoros. Sólo se incorporan los cinco escudos del *Medieval Weapons Pack*.
- Barra rápida de aventura: `1` espada, `2` hacha, `3` arco y `4` antorcha. El arco se tensa manteniendo el clic, activa una cámara de apuntado y consume una flecha física al soltar.
- Caballo animado de Quaternius con reposo, paso y galope; jinete sentado sobre la silla y montaje reversible.
- Fauna Quaternius repartida entre el mundo y 23 retos de bestiario, con alpacas, toros, vacas, ciervos, burros, zorros, caballos, perros, venados y lobos.
- Cámara orbital abierta: 10 m a pie y 16 m al montar, con transición suave y mayor campo visual.
- Mundo Terrain3D de 12×12 km —144 km²— dividido en 100 regiones de 256² puntos, con costa asimétrica, península oriental, cordillera nevada, desierto, praderas, riscos y diez caminos conectados.
- Cinco tiles originales low-poly: pradera, sendero, roca, arena y nieve, sin microdetalle PBR fotográfico.
- Bosque masivo de 52.000 árboles Quaternius, ahora un 32% más altos: una retícula irregular de 54 m garantiza cobertura sobre 7.755 celdas verdes y el resto del presupuesto forma reservas profundas y acompaña rutas. Los ejemplares azul petróleo forman el Bosque Tenebroso y los árboles rojos quedan por debajo del 1%. En la cordillera, los pinos pasan gradualmente de verdes a mixtos y finalmente blancos según la altura.
- Sotobosque Quaternius con el reparto disperso original: 110.000 hierbas animadas por brisa y ráfagas, 10.000 arbustos, 10.000 helechos y plantas, 8.000 flores, 2.200 setas, 3.000 rocas y 12.000 guijarros. Ya no existe una alfombra móvil que regenere miles de matas al caminar. Cada hierba tiene en la misma celda un proxy opaco de dos triángulos para la distancia, pero solo una de las dos representaciones puede estar activa. Hierba, helechos y arbustos también reciben nieve gradual en alta montaña.
- Los diez caminos entre regiones son de tierra. `quaternius_rock` queda reservado para dos calles interiores entre las casas de cada villa grande: se pinta en Terrain3D sustituyendo la hierba, con una variante UV compactada y sin cintas ni piedras 3D superpuestas.
- Todos los grupos numerosos usan `MultiMesh` dividido en celdas espaciales con ancla y AABB propios. Los glTF/OBJ se cargan mediante el importador de Godot y el umbral LOD del `Viewport` gobierna sistemáticamente personajes, fauna, edificios, objetos y decorado. Árboles y hierba añaden reemplazos explícitos por celda: malla completa o proxy, nunca ambas. Los árboles lejanos usan una silueta facetada de 31–94 triángulos, sin sombras, visible hasta 5,2 km.
- Seis villas y ocho caseríos rurales con 54 casas de unos 12,4×21,7 m y 4,8 m por planta; diez tienen tres plantas. Todas poseen acceso a ras del terreno y escaleras `Stair_Interior_Simple` que cambian de lado en cada planta. Peldaños y pasamanos comparten exactamente inicio, final e inclinación; una cuña física invisible enlaza las superficies de ambos pisos —también en planta baja—, sin rampas ni placas visuales superpuestas.
- Tres castillos monumentales de 126 x 100 m construidos con `Modular Medieval Buildings - Jul 2017`: murallas de 18 m, cuatro torres exteriores, dos portones con rampas continuas desde el terreno y una torre-palacio escalonada de diez plantas, 40 estancias, diez zonas temáticas y tres torres de hasta 70 m. Sus 18 tramos de escalera alternan el sentido planta a planta y mantienen sus ejes libres de arcos decorativos. La décima planta es una `Torre Mirador` abierta al cielo, sin tejado ni fachadas, con terraza panorámica y cuatro parapetos físicos. Las demás torres usan colisión exacta sobre su malla, sin cajas sólidas invisibles en arcos o interiores.
- Risco y fortaleza estilizados con módulos Quaternius; la cascada, poza y río han sido retirados.
- Ciclo completo de día, atardecer y noche con una luna low-poly de 176 m, textura original de cráteres, iluminación y sombras; durante el día se retira por completo del render para evitar artefactos negros.
- Mar low-poly animado rodeando la isla, playas facetadas y seis bancos de niebla regional en bosques y zonas tenebrosas; solo se procesan los dos más cercanos que correspondan a la posición y altura de la cámara. Al subir la marea, jugador y caballo son empujados de forma progresiva hacia la cota seca más próxima para que una ría no pueda dejarlos atrapados.
- HUD despejado por defecto: `N` alterna la leyenda de controles, `B` el minimapa, `M` el mapa completo, `0` los créditos y `Z` abre la configuración. El panel Z pausa la partida, muestra todas las asignaciones, ofrece cuatro resoluciones y permite elegir entre 180 y 900 m antes del LOD.
- Diario de 200 desafíos de aventura: visitas a casas, aldeas y castillos reales, descubrimiento de animales, cofres, tala, minería de rubíes, reliquias, amanecer y atardecer. `L` abre la lista, `E` interactúa y cada logro autoguarda; al elegir una entrada, el mapa señala su destino.
- Cooperativo ENet para un anfitrión y hasta siete invitados. El Synology mantiene un tablón HTTPS de partidas activas con nombre, anfitrión, versión y ocupación; crear una expedición la anuncia con latidos y los invitados se unen con un clic, sin escribir la IP. La sala replica identidades, personaje elegido, posición, orientación, velocidad y objeto equipado; `9` permite saltar directamente al Bosque Tenebroso durante las pruebas.
- Exportación Windows x86-64 con instalador ligero y lanzador de actualizaciones: consulta el manifiesto estable de GitHub Releases, verifica tamaño y SHA-256, cambia de versión de forma transaccional y conserva la última instalación válida si no hay conexión.
- Música adaptativa de FiftySounds: `The Hill that Knows your Voice` en el valle, `Promise` dentro de la zona nevada y `Ashes` en el desierto, con transiciones suaves y reproducción en bucle. Viento, pájaros y cuatro sonidos de cascos completan la mezcla; la atribución se consulta con `0`.

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

### Instalar en Windows

Descarga [SenderosDelHorizonte-Instalador.zip](https://github.com/Francisco44444/godot_beautiful_space/releases/latest/download/SenderosDelHorizonte-Instalador.zip), extráelo y ejecuta `Instalar.bat`. El instalador
crea un acceso directo en el escritorio; a partir de ahí, ese acceso comprueba las
actualizaciones antes de abrir el juego. La versión alfa no está firmada y Windows
puede mostrar SmartScreen; para una distribución pública habrá que firmar el
ejecutable.

El lobby consulta `https://franfuco4444.synology.me:24568/v1` y muestra las
expediciones activas. Para jugar por Internet, el PC anfitrión aún debe permitir y
redirigir el puerto UDP `24567`; el NAS evita compartir la IP, pero no sustituye
el transporte ENet. Dentro de la misma red puede usarse la IP local desde el
apartado Avanzado. Esta primera capa todavía no incluye migración de anfitrión,
relay/NAT traversal ni sincronización autoritativa de futuras misiones.

### Publicar cambios sin compilar manualmente

Después de editar el proyecto, haz doble clic en `PublicarCambios.command`. La
opción 1 sube un cambio y deja un ejecutable de prueba en GitHub Actions; la
opción 2 crea una actualización oficial que los lanzadores detectarán. GitHub
descarga Godot 4.7.1, prueba, exporta, calcula el SHA-256 y publica los archivos
sin utilizar este Mac para compilar. Consulta
[`docs/AUTOMATIC_BUILDS.md`](docs/AUTOMATIC_BUILDS.md).

## Controles

| Acción | Teclado / ratón | Mando |
| --- | --- | --- |
| Caminar | `WASD` o flechas | Stick izquierdo |
| Correr | `Mayús` | Pulsar stick izquierdo |
| Saltar | `Espacio` | Botón inferior |
| Equipar espada / hacha / arco / antorcha | `1` / `2` / `3` / `4` | — |
| Atacar o tensar/disparar el arco | Clic izquierdo; mantener y soltar con arco | Botón superior |
| Interactuar / explorar / montar / desmontar | `E` | Botón izquierdo |
| Abrir inventario | `I` | — |
| Galopar | `Mayús` + dirección | Stick + pulsación |
| Orbitar cámara | Mover ratón | — |
| Liberar ratón | `Esc` | — |
| Mostrar / ocultar controles | `N` | — |
| Mostrar / ocultar minimapa | `B` | — |
| Abrir / cerrar mapa de la isla | `M` | — |
| Abrir / cerrar créditos y atribuciones | `0` | — |
| Abrir configuración gráfica | `Z` | — |
| Viajar a Dunas / Nieve / Villa / Bosque | `5` / `6` / `7` / `8` | — |
| Viajar al Bosque Tenebroso | `9` | — |
| Abrir diario de 200 desafíos | `L` | — |

La exploración ya no impone el antiguo objetivo del mirador; las rutas quedan libres para incorporar la futura historia. Si el personaje cae fuera del escenario, reaparece en el inicio.

## Dirección visual Quaternius

`VegetationScatter` carga los `PackedScene` importados del *Stylized Nature Mega Kit*, conservando materiales y los LOD generados por Godot. Los árboles adultos se reparten entre caminos, ocho reservas forestales y todas las praderas verdes; el Bosque Tenebroso añade una gran masa azul petróleo y los árboles retorcidos rojos no superan el 1% del total. Por defecto, cada celda cambia atómicamente del árbol completo a una silueta facetada a 340 m, y esta continúa hasta 5,2 km sin sombras. No hay intervalo de solapamiento ni referencias de distancia al origen del mapa. La hierba usa la misma población dispersa para su malla completa y su proxy de dos triángulos, con cambio más cercano y sin regeneración al mover la cámara. El panel Z permite desplazar el corte común entre 180 y 900 m; al mismo tiempo ajusta `Viewport.mesh_lod_threshold` para todos los modelos importados. Un shader preserva los troncos y cubre de blanco las copas, hierbas, helechos y arbustos de la alta montaña; una probabilidad continua crea una franja mixta a media altura y desaparece por completo en cotas bajas. La hierba conserva su movimiento base y las ráfagas. Los elementos cercanos a las rutas y una muestra del bosque profundo reciben colisiones simplificadas.

`MedievalSetDressing` monta seis villas, ocho caseríos, 54 casas y tres castillos. Cada vivienda parte de un módulo Quaternius 8×14 ampliado uniformemente a unos 12,4×21,7 m, con 4,8 m de altura por planta. Las 64 plantas superiores incorporan suelo visual y físico, un hueco ajustado, `Stair_Interior_Simple`, `Stair_Interior_Rails`, cuñas transitables invisibles y barandillas físicas alrededor del vacío. Los peldaños y pasamanos se escalan por separado a una longitud común entre forjados, eliminando `Stair_Interior_SolidExtended`, su lateral triangular y cualquier rampa o revestimiento visible bajo la escalera. Cada tramo alterna su sentido y una cuña convexa enlaza la cara superior exacta del piso inferior con la del superior, sin salto, placa ni bordillo. La primera planta utiliza expresamente la cota de cimentación o patio, distinta de los demás forjados. Todas las casas conservan paredes físicas independientes, dos hastiales completos y un hueco de puerta de 3,1 m realmente atravesable. Cada castillo ocupa un recinto de 126×100 m y contiene una ciudadela de diez pisos con dos escaleras protegidas por planta y aperturas limpias sin arcos sobre la trayectoria. La última planta queda abierta como `Torre Mirador`, con suelo completo, acceso por ambas escaleras, parapeto físico perimetral y cielo despejado. Su explanada se divide alrededor de dos corredores de portón, enlazados mediante rampas de piedra a ras del terreno, y las torres sustituyen las antiguas cajas macizas por colisiones trimesh que siguen sus huecos reales. La vegetación, incluidos los árboles secos de detalle, respeta las huellas de casas, patios y fortalezas. El antiguo hito de la cascada —incluidos sus tejados flotantes y su muro de rocas— se eliminó por completo.

Los personajes se encuentran en `assets/quaternius/ultimate_animated_characters/glTF`; el juego ofrece ocho opciones y sustituye en ejecución únicamente su material `Skin`, preservando ojos, cabello y ropa. Quedan disponibles aldeanos, trabajadores, vikingos, elfos, goblins, magos, piratas, ninjas y otras variantes para NPC futuros. Los animales viven en `assets/quaternius/ultimate_animated_animals`.

El catálogo de aventura se genera desde todos los OBJ de `Ultimate RPG Items Pack - Aug 2019`; los cofres y reliquias pueden entregar cualquiera de sus recompensas válidas. Espadas, hachas, arcos y escudos nuevos sustituyen automáticamente al modelo anterior de su categoría. La antorcha procede del *Survival Pack* y únicamente el objeto seleccionado aparece unido al hueso `Fist.R`; la brújula se ha retirado. La *Universal Animation Library 2* está en `assets/animations` para acciones futuras; la locomoción actual usa las animaciones del propio personaje, sincronizadas con su desplazamiento.

## Terreno y atmósfera

Terrain3D utiliza seis albedos originales en `assets/textures/stylized_terrain`: pradera, sendero ocre, roca con musgo, arena dorada, nieve alpina y caliza de cantil. Una séptima variante reutiliza `quaternius_rock` con escala UV 0,18 para las calles compactas. La caliza se asigna automáticamente a pendientes litorales superiores a 48° y a cualquier pared interior de 55° o más, evitando superficies verticales verdes; una barrera invisible de 4,6 m sigue las cornisas costeras, con pasos abiertos en los descensos transitables. Los diez caminos insulares usan `quaternius_path`; la piedra solo forma dos ejes cortos dentro de cada villa grande y sustituye el material de hierba en el mapa de control. No existe ninguna malla vial flotante. Las 100 regiones de 256² puntos usan una separación de 4,6875 m y cubren 144 km², conservando continuos bordes, curvas y cruces. El escenario añade mar facetado con mareas, rías que se llenan y vacían, horizonte curvo, sol y luna low-poly, día dos veces más largo que la noche, tres capas móviles de nubes y bancos locales de niebla. El sol visual se mantiene a 20 km de la cámara —detrás de toda la isla— conservando su tamaño angular, para que ninguna montaña parezca atravesarlo. La niebla global se limita a 920 m y las seis zonas regionales se transmiten con un presupuesto máximo de dos. En el mapa, el océano ocupa todo el exterior sin marco negro ni falsa franja amarilla, y el pico blanco del marcador rojo gira con la orientación real del héroe.

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
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/settings_menu_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/island_world_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/stair_traversal_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/exploration_manager_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/exploration_integration_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/multiplayer_test.gd
python3 tests/test_lobby_directory.py -v
```

`network_handshake_test.gd` se ejecuta en dos terminales —`--host` y
`--client` con el mismo `--port`—; su modo de aforo levanta un anfitrión y siete
clientes reales. Consulta el encabezado del propio test para los comandos.
`lobby_directory_test.gd` levanta una sala contra el servidor Python local y
comprueba publicar, listar, compatibilidad de versión y retirada automática.

La prueba de vegetación valida los 50 personajes, la fauna, el caballo, las 207.200 instancias principales, los 52.000 proxies arbóreos, las 110.000 hierbas dispersas con proxy exclusivo, la distribución lejos de caminos, las calles `quaternius_rock`, el gradiente nevado, los LOD importados, los AABB por celda y las colisiones. `adventure_system_test.gd` recorre catálogo, cofres, bestiario, tala, troncos, minería, rubíes, sustitución de armas, escudos, arco y flechas; `exploration_integration_test.gd` valida los 200 desafíos, el mapa y el autoguardado. `runtime_stability_test.gd` viaja entre biomas y demuestra que no se crean celdas ni coinciden modelos completos y proxies. `settings_menu_test.gd` comprueba Z, las cuatro resoluciones y el corte LOD 180–900 m. `audio_test.gd` comprueba las tres canciones, sus loops, los límites de nieve y desierto, la mezcla ambiental y los cascos; `medieval_combat_test.gd` comprueba el inventario `1–4`, el socket de mano, las poses y los impactos; `island_world_test.gd` comprueba los 144 km², `N`/`B`/`M`/`0`, la atribución de FiftySounds, viaje rápido `5–8`, 54 casas, 64 plantas superiores, tres fortalezas completas y sus miradores abiertos al cielo. `stair_traversal_test.gd` mueve una cápsula idéntica al héroe, sin salto, por una escalera doméstica, una de la ciudadela y el portón exterior hasta alcanzar el patio.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada y no afecta al juego.

## Estructura

```text
assets/     packs Quaternius CC0, materiales Terrain3D y audio con licencias registradas
addons/     Terrain3D
scenes/     escenas de Godot
scripts/    jugabilidad y sistemas visuales
shaders/    efectos visuales
terrain/    regiones y configuración Terrain3D
tests/      pruebas headless
tools/      utilidades y runtime local ignorado por Git
```

## Licencias

El código original se distribuye bajo MIT. Quaternius y ambientCG se usan bajo CC0; Terrain3D bajo MIT. `The Hill that Knows your Voice`, `Promise` y `Ashes` requieren atribución a FiftySounds; el viento, los pájaros, los cascos y los nuevos tiles estilizados son originales del proyecto. Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No se incluyen recursos extraídos de Nintendo ni de ningún videojuego comercial.
