# Grutas y recuerdos del bosque — 7 de noviembre de 2026

La revisión del 8 de noviembre une la portada con una bóveda de piedra,
cierra las costuras del terreno y corrige el seguimiento de cámara de
Terrain3D. Véanse [las entradas y la hierba](ENTRADAS_Y_HIERBA.md).

La revisión del 10 de noviembre separa la física de los jugadores y las luces
de la vista local, y corrige los disparos remotos bajo una bóveda. Véanse las
[mediciones y pruebas de grutas en cooperativo](GRUTAS_EN_COOPERATIVO.md).

## Qué puede jugarse

Las cuatro puertas anteriores ya llevan a interiores: vestíbulo descendente,
tres cámaras conectadas en lazo y un ramal lateral con relicario. Cada gruta
ofrece tres voces de Aeloria; escucharlas permite restituir un recuerdo y
recibir dos lingotes. El relicario oculto da dos cristales verdes una sola vez.
Las cuatro paletas son esmeralda, hielo, ámbar y amatista.

| Acceso en el mapa M | Coordenadas X/Z | Llave |
| --- | --- | --- |
| Gruta de las Raíces | −2530 / 1090 | Key1 |
| Observatorio Sepultado | 690 / −3370 | Key2 |
| Santuario bajo la Arena | 2750 / 1700 | Key3 |
| Cámara sin Eco | 4700 / −1450 | Key4 |

El santuario antiguo estaba a −278,25 m: se trasladó a terreno accesible,
medido a 43,97 m. La Cámara sin Eco se trasladó desde la costa baja a una cota
medida de 322,93 m. Esto evita entradas bajo el mar y el umbral de rescate del
jugador a −12 m. Las llaves y la campaña principal siguen siendo las existentes.

Al noreste de Puerto Alba, junto a **(78, 60)**, una cinta inicia **El ciervo de
ámbar**. Vuelve de noche y camina tras el ciervo y las luces: el animal espera
si te alejas más de 22 m o corres a más de 6 m/s. La búsqueda evita los troncos
con un AStarGrid2D de 2 m, construido al aceptar la misión o cargarla. La meta
es un claro con una flor de memoria; recogerla con E concede tres cristales.
El diario L y el bloque BOSQUE del seguidor conservan el objetivo.

El ciervo usa el Stag animado de Quaternius, con su textura original para
conservar ojos, hocico y variación del pelaje, un material dorado con ribete
luminoso y una luz cálida sin sombras. Al llegar, se despide durante 1,8 s
entre destellos; las luces del claro vuelven las noches posteriores.

## La integración con el terreno es real

La primera entrada expuesta parecía un tubo. La siguiente tenía faldones
rectos pintados de verde y rocas a la cota anterior; ambas se descartaron tras
la revisión visual del usuario.

Ahora **los laterales son el heightmap de Terrain3D**, esculpido con
`set_height` en un contorno de anchura variable. Conservan su material de suelo,
colisión y hierba, que lee esas mismas alturas. No hay malla verde añadida.
Sólo el camino central y la arquitectura rígida usan mallas de piedra.

El agujero del terreno se limita a la transición al interior cubierto. La
rampa solapa ese borde y el suelo de la gruta. Se actualizan alturas y controles
y se vuelven a enlazar los RID en los materiales de hierba; conservar un RID
antiguo dejaba briznas sobre los agujeros. La máscara excluye el pavimento,
no toda la ladera. Se han retirado las rocas decorativas que quedaban flotando.

Los árboles que invadían el acceso se ocultan junto a su colisión, sin marcar
una tala, dar botín ni modificar el cache horneado. Los corredores se aplican
al cargar el mundo y se mantienen al cambiar de ranura. Fuera de esos accesos
no cambia la distribución de árboles.

## Coste y límites de lo medido

- Una única malla horneada compartida por las cuatro grutas: **22.974 triángulos**,
  alrededor de 2,1 MiB con normales por cara. El circuito de referencia mide
  **272,77 m**, más el desvío del secreto. Se comparten también las formas de
  colisión; no se evalúa ningún SDF al jugar.
- La colisión se activa por cualquier jugador preparado a menos de 240 m de
  su centro. Las seis luces sin sombras (dos antorchas y cuatro interiores)
  atienden al héroe y la cámara local. El decorado numeroso usa MultiMesh.
- Luciérnagas: **112** en los bosques del valle por la noche, **48** junto al
  guía y **256** en el claro descubierto. Son quads instanciados; deriva,
  parpadeo y ascenso se calculan en GPU. La CPU comprueba el ambiente cada
  0,3 s y recoloca el enjambre ambiental al desplazarse más de 12 m.
- Controles visuales con Apple M2 Pro y Metal, cámara nocturna fija: con/sin
  enjambres, 42,07 / 42,10 FPS y 42,03 / 42,05 FPS en dos tandas. Una tanda
  posterior dio 41,42 / 41,42. Son diferencias dentro del ruido del banco,
  **no una mejora general de FPS**. La cámara y la carga son diferentes de las
  medidas de pradera de `HIERBA_Y_RENDIMIENTO.md`.
- No se han bajado resolución, alcance de árboles, sombras globales ni población.
  La reforma de la red y un perfil de rendimiento de toda la isla siguen fuera
  de esta pasada. La prueba nueva es de partida local; no valida un recorrido
  cooperativo con varios equipos.

## Persistencia y comprobaciones

`RPGStoryRuntime` guarda `wonders` dentro del estado compartido del mundo:
voces escuchadas, recuerdos restituidos, secretos, fase del ciervo y punto de
la ruta. Cambiar de ranura vacía el estado anterior. Las puertas también se
cierran al cargar una partida donde aún no se abrieron. Las recompensas
comprueban su identificador persistente antes de conceder objetos.

`tests/wonders_test.gd` recorre las cuatro grutas con una cápsula de 1,8 m,
sin salto: cámaras, secreto y regreso al exterior. Comprueba además voces,
recompensas únicas, restauración del estado, espera del ciervo ante distancia
y carrera, llegada al claro, flor y apagado diurno de luciérnagas. Comprueba
que la ladera se haya esculpido y no sea un agujero tapado con una malla verde.
Está añadida a `.github/workflows/windows-build.yml`.

La prueba detectó realmente labios del techo que impedían salir: el vestíbulo
abierto ahora pertenece al terreno y el pavimento, y el SDF empieza bajo la
ladera. La inyección `--break-cave-floor` también falló al quitar los suelos,
como corresponde. Pasaron las pruebas de historia, vegetación, crónica y
ranura completa. Esta última requiere permiso para escribir en `user://` en
el sandbox; crea y borra sólo la ranura `TestGuardadoCodex`.

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --log-file /private/tmp/wonders-engine.log --path . --script res://tests/wonders_test.gd
# Control que DEBE FALLAR:
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --log-file /private/tmp/wonders-negative-engine.log --path . --script res://tests/wonders_test.gd -- --break-cave-floor
# Rehornear fuera del juego (numpy):
python3 tools/bake_adventure_caves.py
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --log-file /private/tmp/cave-pack-engine.log --path . --script res://tools/pack_adventure_cave.gd
```

El empaquetador borra el JSON intermedio. Sólo `generated/caves/hollow.res`
se necesita en el juego; no se exportan las herramientas ni las pruebas.
