# Auditoría de scripts y actividad — 8 de noviembre de 2026

Se inventariaron los 73 archivos GDScript de `scripts/`, sus callbacks y
temporizadores. Se perfiló el mundo real en Puerto Alba, Villa
Robledal y Bosque Umbrío, con jugador sin entradas, cámara normal, IA,
animaciones, HUD y ciclo solar activos. El segundo recorrido atraviesa
`startup.tscn`: el cargador se libera y no permanece procesando detrás del mundo.

Hay **51 tipos de script adjuntos** al árbol; **31 archivos registran llamadas**
durante este recorrido en reposo. El contador de nodos huérfanos vale **cero**
en las tres zonas. Los catálogos y scripts de herramientas guardados en disco
no equivalen a un callback ejecutándose cada fotograma.
El [inventario por archivo](INVENTARIO_SCRIPTS.md) recoge los nodos, callbacks
habilitados y tiempo propio de cada uno; un catálogo sin callbacks no consume
tiempo continuo por existir en disco.

## Costes encontrados

Perfilador nativo de GDScript, Apple M2 Pro, Godot 4.7.1, Metal Forward+,
1600×900, LOD común 400 m, VSync desactivado y sin límite de FPS. Se calientan
140 fotogramas al cargar y 90 después de viajar; se registran 360 por zona.
Se suman tiempos **propios** por archivo, sin duplicar el tiempo de sus
subllamadas. Se excluye la corrutina de espera de la sonda, cuyo acumulado
incluye tiempo de pared suspendida. El perfilador añade coste: estas cifras
sirven para localizar actividad, no para prometer FPS.

| Script, antes del cambio | Puerto | Villa | Bosque |
| --- | ---: | ---: | ---: |
| `village_folk.gd` | 0,81 ms | 0,73 ms | 1,12 ms |
| `vegetation_scatter.gd` | 0,65 ms | 0,54 ms | 0,76 ms |
| `rpg_enemy.gd` | 0,33 ms | 0,33 ms | 0,43 ms |
| `player.gd` | 0,25 ms | 0,23 ms | 0,31 ms |
| `island_map.gd` | 0,16 ms | 0,16 ms | 0,17 ms |
| `world.gd` | 0,10 ms | 0,11 ms | 0,13 ms |

- Los **87 vecinos** siguen caminando y resolviendo colisiones cuando el héroe
  está en otro lugar. Se conservan sus rutas y horarios; esta actividad es la
  siguiente prioridad de simulación distante.
- La vegetación repetía aproximadamente **5.360 llamadas al selector de
  visibilidad por revisión**, cada 0,12 s, incluso con el foco quieto. La
  posición era la misma y el resultado no cambiaba.
- Los 260 enemigos siguen entrando en su callback de física para comprobar
  autoridad y distancia, aunque la mayoría esté dormida. Además se consultaba
  dos veces la posición del objetivo al formar el mismo vector XZ.
- HUD, minimapa, entorno, audio, red y modificadores de pose aparecen en el
  perfil. En este recorrido no se observa en ellos un bucle dominante comparable
  al de vecinos o vegetación. Falta repetir el perfil con combate sostenido y
  ocho participantes.

## Corrección conservada

El selector LOD conserva el resultado mientras no cambien el foco XZ ni la
distancia configurada. Moverse, cambiar la distancia, solicitar una actualización
forzada o registrar una celda nueva renueva el cálculo. Cambiar sólo la altura
no repite un corte que usa distancias XZ. El viento, las transiciones por hoja,
la reacción al jugador y las ondas de combate continúan en sus shaders.

Los enemigos y jefes consultan una vez la posición autoritativa del objetivo
al formar ese vector. Conservan comprobaciones, alcance y autoridad de combate.

| Tiempo propio de todos los scripts | Antes | Después | Ahorro |
| --- | ---: | ---: | ---: |
| Puerto | 2,72 ms/fotograma | 2,10 ms/fotograma | 22,8 % |
| Villa | 2,49 ms/fotograma | 1,91 ms/fotograma | 23,1 % |
| Bosque | 3,41 ms/fotograma | 2,63 ms/fotograma | 23,0 % |

El perfil posterior corresponde a la corrección del selector; la pequeña
limpieza de consultas de enemigos se hizo después y no se le atribuye una
ganancia de FPS.

Sin perfilador, una revisión repetida pasa de unos **3,1 ms a menos de 2 µs**.
Se alternó recorrer/cache/cache/recorrer en el mundo completo: 80 revisiones
para el control, 4.000 para el cache, y tandas de 240 fotogramas tras 60 de
calentamiento para comprobar FPS. La cámara se desacopla del SpringArm3D,
usa 62° y queda enlazada con Terrain3D; jugador y ciclo solar se detienen,
con IA, animaciones y HUD activos.

| Cámara fija, sin perfilador | FPS antes | FPS después |
| --- | ---: | ---: |
| Puerto | 53,18 | 53,15 |
| Villa | 65,31 | 66,38 |
| Bosque | 42,77 | 42,72 |

El ahorro de CPU **no se convierte en un aumento general de FPS** en estas
vistas. Puerto y bosque quedan prácticamente iguales; la villa mejora un
1,6 %. El coste del render continúa pendiente y el objetivo de 100–120 FPS
todavía no está alcanzado.

## Guardado periódico

Las mediciones anteriores desactivan los guardados para no modificar partidas
del usuario ni mezclar la E/S con el coste continuo. Se midió después el
guardado completo hacia una ranura temporal, con dos llamadas de calentamiento
y doce muestras, sin modificar los archivos del jugador. Se excluye el listado
del catálogo de ranuras: es una prueba del guardado del mundo, no de su menú.

| Estado del mundo | Tamaño JSON | Media | p95 |
| --- | ---: | ---: | ---: |
| Estado actual de la prueba | 4.692 bytes | 0,56 ms | 0,60 ms |
| Prueba sintética con 50.000 árboles consumidos | 1.570.109 bytes | 32,17 ms | 34,41 ms |

Es un coste puntual cada 30 s en solitario y 120 s en cooperativo, no la causa
de los FPS bajos constantes de estas vistas. La segunda fila es una prueba
extrema de crecimiento de la partida, no una sesión normal observada. El
escritor actual serializa en el hilo principal, escribe un temporal y después
lo lee y vuelve a escribir el destino. Queda pendiente reducir esa duplicación
y separar la E/S conservando la recuperación de partidas. No se ha sustituido
por un supuesto renombrado atómico multiplataforma: la implementación de
[Godot 4.7 para Windows](https://github.com/godotengine/godot/blob/4.7/drivers/windows/dir_access_windows.cpp#L288)
borra primero el destino al renombrar archivos distintos. Hace falta comprobar
la sustitución y recuperación en Windows antes de tocar este sistema.

## Tamaño del árbol y siguiente revisión

El mundo registra **87.177 nodos**. `MedievalSetDressing` contiene 72.582,
`VegetationScatter` 9.256 y `RPGStoryRuntime` 4.215. La arquitectura concentra
la mayor parte del árbol: conviene estudiar sus jerarquías importadas,
superficies y colisiones, conservando edificios, interiores y detalle. Este
recuento no se presenta por sí solo como tiempo de CPU.

Se ensayó además representar los parches de hierba individualmente, con cajas
que usan los extremos reales de sus mapas de altura. El prototipo da una
ganancia moderada con cámara fija, pero queda pendiente verificar imágenes,
movimiento, pendientes y coste de actualización antes de integrarlo.

## Verificación

`lod_activity_test.gd` verifica 100 revisiones quietas sin recorrer las celdas,
movimiento, altura, actualización forzada, ajuste normal y exportado, altas
tardías y foco del jugador cuando no hay cámara. Se inyectaron cuatro defectos
reales: desactivar el cache, ignorar el forzado, ignorar el ajuste exportado y
no invalidar al registrar una celda. Los cuatro producen el fallo esperado;
el código restaurado pasa. La prueba está en el workflow de Windows.

También pasan la prueba completa de vegetación y la prueba cooperativa con
dos procesos reales: 17 etapas de autoridad, impactos, bloqueo, esquiva,
proyectiles, armas, muerte y recompensa. No aparecieron advertencias de MTU.
Se inspeccionaron las capturas de las tres cámaras tras el cambio de cache.

Inventarios, perfiles, medidas y capturas quedan en
`generated/reviews/2026-11-08/scripts/`. Las sondas temporales se borran al
finalizar, como exige `CLAUDE.md`.
