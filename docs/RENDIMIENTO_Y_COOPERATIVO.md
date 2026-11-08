# Rendimiento y presentación cooperativa — 8 de noviembre de 2026

Se midió el mundo completo y se revisó `scripts/red/xogo_red.gd` de Vigo como
referencia de red. El arte sigue siendo el de esta aventura low-poly.

## Cartografía retenida y FPS medidos

`IslandMapView` reconstruía costa, nueve intersecciones poligonales de biomas,
relieve, caminos y rótulos en cada fotograma. Ahora un Control hijo conserva
esos comandos de CanvasItem. El padre dibuja posición, rumbo y objetivo cada
frame. Cambiar de tamaño, ampliar el mapa, crear grutas o acumular más de 0,02
de marea renueva la cartografía. Esa tolerancia de marea equivale como máximo a
0,06 píxeles de anchura de ría. Un mapa oculto deja de solicitar dibujos.

Mac Apple M2 Pro, Metal Forward+, 1600×900, escala 3D 1, MSAA 0, VSync desactivado
y sin límite de FPS. Cámara fija de 62°, a (7; 3,6; 9) del héroe, mirando hacia
(0; 1,2; −10); ciclo solar detenido y avance físico del héroe congelado. IA y animaciones del
mundo normales. Cada tanda mide
180 fotogramas después de 40 de calentamiento; se alterna reconstruir/cache/cache/
reconstruir dentro del mismo proceso. El control solicita reconstruir el fondo
cada frame para reproducir el trabajo anterior. No se modifican los ajustes
visuales entre tandas.

| Lugar | Reconstruir 1 | Cache 1 | Cache 2 | Reconstruir 2 |
| --- | ---: | ---: | ---: | ---: |
| Puerto Alba | 48,85 | 49,11 | 49,19 | 48,77 |
| Villa Robledal | 51,49 | 60,76 | 60,62 | 51,93 |

En esta cámara de la villa la media pasa de **51,71 a 60,69 FPS: +17,4 %**.
Puerto Alba apenas cambia: allí queda un límite de render. No son cifras de
Windows ni de toda la isla. **Todavía no se han alcanzado 200 FPS.**

La captura del mapa completo anterior y la del nuevo tienen **cero píxeles
diferentes**, comparadas a la vez en dos SubViewport de 900×720. La altura,
densidad y cobertura de hierba, sombras, resolución y distancias del mundo
se conservan. Los datos de las tandas y la captura quedan en
`generated/reviews/2026-11-08/`.

También se probó evitar inversiones de matriz en el shader de las briznas y
omitir el viento de sus raíces. El A/B dio 73,48/73,91 FPS con el original y
73,94/73,96 con la variante: la diferencia no separa una ganancia del ruido.
Se conserva el shader original de la pasada anterior.

## Compañeros remotos

Antes se perseguía el último paquete con un lerp exponencial, a 60 pasos de
física por segundo. Ahora cada muestra lleva la hora del emisor y si el héroe
está en el suelo. El anfitrión conserva esos datos al retransmitirla.

`network_motion.gd` adapta estas técnicas de Vigo a los avatares ENet:

- Historia limitada a 40 muestras y búfer que se adapta entre 100 y 450 ms.
- Reloj de presentación continuo y corrección gradual de su ritmo. La posición
  se presenta cada fotograma, también en pantallas de 144 o 240 Hz.
- Curvas de Hermite con tangentes monótonas por eje, orientación por el giro
  corto y rechazo de muestras antiguas.
- Predicción durante 180 ms sin datos y frenada durante otros 120 ms. Después
  se detiene; recuperar paquetes corrige el error de forma gradual.
- Los saltos grandes de posición y las pausas largas de recepción reinician
  la historia, en lugar de dibujar un viaje a través de la isla.

Había además un defecto visible: las réplicas no tienen colisión, por lo que
`is_on_floor()` siempre era falso y caminaban con la pose de salto. La animación
usa ahora el estado de suelo de la muestra presentada. Se comprobaron capturas
de andar → saltar → aterrizar con latencia y pérdidas.

El anfitrión valida tala/minería con **la última posición recibida**, separada
de la posición presentada con retraso. La prueba cubre tanto dibujo cercano
con muestra lejana como dibujo lejano con muestra cercana. También se rechazan
velocidades no finitas y posiciones/orientaciones no finitas en guardados de red.

La prueba numérica usa envío a 15 Hz, relojes con distinto origen, 60 ms de
latencia, hasta 120 ms adicionales de jitter, 20 % de pérdidas y cortes breves.
En movimiento recto a 6 m/s, render a 60 Hz, el percentil 95 del cambio de
velocidad pasa de 449,51 a 1,81 m/s²; el retraso medio es 295 ms. Es una traza
sintética reproducible, no una medición de Internet. También pasa a 30, 144 y
240 Hz. La conexión real entre dos procesos locales prueba el transporte ENet,
las marcas de tiempo, el estado de suelo y la petición fiable de tala.

El protocolo de avatar añade dos argumentos: todos los participantes deben
usar esta compilación. Se mantienen las frecuencias nominales de 15 Hz para
avatares y 5 Hz para el estado del mundo.

## Verificación

```bash
GODOT=tools/runtime/Godot.app/Contents/MacOS/Godot
$GODOT --headless --log-file /private/tmp/mapa.log --path . --script res://tests/island_map_cache_test.gd
$GODOT --headless --log-file /private/tmp/movimiento-red.log --path . --script res://tests/network_motion_test.gd
$GODOT --headless --log-file /private/tmp/cooperativo.log --path . --script res://tests/multiplayer_test.gd
python3 tests/test_network_handshake.py
```

Pasaron `island_map_cache_test`, `network_motion_test`, `multiplayer_test`,
`player_movement_test`, `island_world_test` y el intercambio ENet de dos
procesos. Las dos pruebas nuevas forman parte del workflow de Windows. Las inyecciones
`--break-map-cache`, `--break-network-motion` y `--break-remote-floor` fallan
al reintroducir sus respectivos defectos.

La pasada siguiente corrige el relevo de sombras sol/luna y acelera la
evitación de vecinos conservando sus trayectorias. Véase
[LUZ_Y_CPU.md](LUZ_Y_CPU.md) para las nuevas medidas y los vídeos.

## Cola para las próximas pasadas

La pasada de [RENDER_DEL_BOSQUE.md](RENDER_DEL_BOSQUE.md) añade descarte por
ejemplar conservando sombras y detalle. Puerto mejora un 3–4 %; la villa
apenas cambia. Incluye la corrección del control de suelo para retirar también
la calzada independiente. El objetivo actual es 100–120 FPS con la calidad
conservada; los 200 ya no son un requisito.

La pasada posterior de [SOMBRAS_DEL_BOSQUE.md](SOMBRAS_DEL_BOSQUE.md) extiende
esa representación a las sombras. Con la cámara y la fase de luz comprobadas,
Puerto mejora otro 8,8–9,4 % y la villa un 2,3–2,6 % frente a la ruta anterior.
Las medidas históricas no se suman entre sí: utilizan configuraciones y
cámaras distintas. Continúa pendiente la referencia de Windows.

- Medir y reducir los dibujos y el coste GPU de edificios/sombras sin retirar
  elementos ni bajar resolución o densidad. En la cámara de la villa siguen
  dibujándose unos 5 millones de primitivas y 3.900 llamadas.
- Dormir la actividad distante de vecinos y sus esqueletos conservando horarios
  y aspecto al aproximarse; el control sin actividad reduce unos 2 ms de física.
- Continuar el combate cooperativo: los golpes, flechas, guardia y esquiva
  ya están resueltos y probados entre
  dos procesos. Véase [COMBATE_COOPERATIVO.md](COMBATE_COOPERATIVO.md).
  Quedan progreso compartido, incorporaciones tardías, monturas, equipo
  defensivo exacto e interpolación de enemigos y fauna.
- Validar clientes que simulan a menos de 15 FPS y alinear el reloj de emisión
  con sus pasos de física agrupados. La derivada presentada ya está limitada
  para que dos marcas de tiempo casi iguales no produzcan velocidades enormes.
- Reducir tráfico del estado mundial por interés espacial: se serializan los
  260 enemigos a 5 Hz para todos. Probar ocho participantes y una conexión WAN;
  la prueba de dos procesos locales no sustituye esa validación.
- Continuar aventura y secretos de las grutas con el estilo de Duelo de Sables.
