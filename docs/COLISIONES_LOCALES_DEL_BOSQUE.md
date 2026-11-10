# Colisiones locales del bosque — 0.1.14

Una tala real seguía reconstruyendo la malla física de todos los troncos
seleccionados: 5.343 prismas y 64.116 triángulos en el mundo medido. El
diagnóstico separó unos 10 ms de generación de vértices y unos 30 ms de
actualización nativa de la gran forma cóncava.

Se aplica la idea de limitar la actualización física por sectores, presente
en `Vigo game godot/docs/diario/mundo_rendimiento.md`. Se conservan los prismas
y el arte propios de Senderos. El registro se agrupa ahora en **572 celdas
de 256 m**, con un máximo de 93 troncos por celda y 31 en su percentil 95.
Cada celda tiene un cuerpo estático y una forma cóncava con las dos caras
activas. No se recortan los prismas que cruzan un borde.

Los vértices se preparan al registrar la distribución. Un índice de recurso
a celdas identifica qué formas deben actualizarse al talar, restaurar o
reservar el acceso a una gruta. Los ids compartidos actualizan todas sus
celdas. Repetir la unión de talas y reservas no vuelve a construir formas.
Las celdas vacías se desactivan; las retiradas dejan de colisionar antes de
su liberación. Un alta tardía invalida el registro.

Las formas conservan sus máscaras y los mismos triángulos. La ventana de
320 colisiones cercanas sigue cubriendo los demás árboles al aproximarse.
No cambian las mallas visibles, hierba, iluminación, sombras, rutas de
personajes, ids cooperativos ni formato de las partidas. El gestor no tiene
callbacks de proceso o física por fotograma.

## Coste de un cambio

Mundo completo, Apple M2 Pro, Godot 4.7.1. Se alterna la representación
anterior/nueva/nueva/anterior, con 40 bajas y altas por tanda sobre un recurso
de la celda más cargada, que contiene 93 troncos:

| Actualización de colisión | Anterior | Por celda |
|---|---:|---:|
| Media de las dos tandas | 42,001 ms | 0,590 ms |
| Media de sus p95 | 43,657 ms | 0,661 ms |

Es aproximadamente **71 veces menos tiempo en esta operación**, no una
multiplicación de los FPS del juego. Una comparación completa encuentra
exactamente los mismos **64.116 triángulos**, incluidos vértices y orientación,
antes de medir. Se comparan los bytes de cada triángulo sin depender del
orden entre celdas.

## Fotogramas del mundo completo

Metal Forward+, 1600×900, escala 3D 1, MSAA 0, VSync desactivado, sin límite
de FPS, distancia de detalle 400 m y umbral 0,85. Sol en fase 1,08 comprobada,
sombras activas. Héroe detenido; IA, animaciones y HUD activos. Cámara de
62° a (7; 3,6; 9), mirando hacia (0; 1,2; −10), enlazada con Terrain3D.
El bosque usa una órbita de 12×8 m y oscilación vertical de 0,7 m.

Se alternan ambas rutas dentro del mismo mundo: quedan creadas las dos
representaciones y se activa sólo su colisión correspondiente. La referencia
reproduce la función de la malla completa de 0.1.13. Cada tanda calienta 100
fotogramas; se comprueba que todos los medidos se dibujan. No se leen imágenes
durante las muestras.

La prueba con cambios mide 720 fotogramas por tanda y alterna la baja/alta de
un tronco cada 60, sin retirar su malla visible. La llamada incluye renovar
la ventana de colisiones cercanas, como el final de una tala real. Es una
reproducción del trabajo físico; la tala completa se comprueba aparte entre
dos procesos ENet.

| Cámara con cambios | FPS anterior | FPS por celda | p99 anterior | p99 por celda |
|---|---:|---:|---:|---:|
| Puerto, fija | 60,21 | 62,33 | 54,81 ms | 17,95 ms |
| Villa, fija | 72,21 | 75,62 | 55,80 ms | 16,13 ms |
| Bosque verde, movimiento | 45,20 | 46,44 | 57,15 ms | 28,63 ms |

Se toma también el máximo de los dos fotogramas de cada evento, con doce
eventos por tanda. La media de sus p95 pasa de 58,86 a 17,05 ms en Puerto,
de 60,47 a 16,13 ms en la villa y de 67,50 a 28,11 ms en el bosque. La llamada
con renovación de ventana pasa de 42,93–44,48 a 0,67–0,85 ms de media.

La tanda sin cambios mide 240 fotogramas por modo:

| Cámara en reposo | FPS anterior | FPS por celda |
|---|---:|---:|
| Puerto, fija | 62,57 | 62,58 |
| Villa, fija | 75,86 | 75,68 |
| Bosque verde, movimiento | 46,45 | 46,27 |

Las medias sin cambios apenas varían, menos del 0,4 % en estas muestras. El
p99 de la villa en reposo varía de 15,28 a 16,06 ms; esta tanda no demuestra
una mejora uniforme de los percentiles. El avance principal está en reducir
el bloqueo durante las actualizaciones físicas. El coste gráfico general y
el objetivo de 100–120 FPS siguen pendientes. Son medidas del Mac; falta la
referencia de rendimiento en Windows.

## Verificación

`forest_collision_test.gd` compara los triángulos exactos de 185 prismas y un
alta posterior con el criterio original. Comprueba bordes negativos, un
tronco que cruza celda, ids compartidos, talas y reservas superpuestas,
partidas con muchos ids, altas, reducción y retirada de la distribución.
Rayos nativos y un `CharacterBody3D` comprueban bloqueo, paso tras talar y
bloqueo al restaurar. La retirada se verifica también en el mismo fotograma.

`resource_replication_test.gd` mantiene el contrato de recursos y exige que
cada celda afectada se actualice una vez por lote. Comprueba también un alta
tardía a través del registro real de vegetación y un rayo en el mundo. La
prueba de vegetación valida todos los cuerpos y formas de las celdas, sus
triángulos y la ventana física de árboles cercanos. La prueba nueva se añade
al workflow de Windows.

Se inyectaron **doce defectos**: capa no sólida, geometría no subida, celda
vacía todavía activa, activación omitida, id compartido incompleto, negativos
truncados, reservas omitidas en ambas rutas, registro tardío obsoleto, cuerpo
retirado activo, estadísticas antiguas y alta del mundo sin invalidación.
Todos fallan donde corresponde; las fuentes se restauran después.

La pasada final pasa física, recursos en headless y Metal, vegetación
completa, movimiento del héroe, guardado y cooperación real. No registra
errores de script en esas siete comprobaciones. En el cliente Metal se
inspeccionan cuatro capturas: árbol intacto, caída, tocón y restauración. Los
tres golpes cruzan dos, dos y tres estados del mundo, respectivamente.
Las capturas de 0.1.13 se conservan y las nuevas quedan en esta entrega.

Los datos y fuentes de las sondas retiradas quedan en
`generated/reviews/2026-11-10/colisiones-troncos/`. El diagnóstico previo de
la malla única y la distribución por tamaños está en la carpeta homónima
de `generated/reviews/2026-11-09/`.
