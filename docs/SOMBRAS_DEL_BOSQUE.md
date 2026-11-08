# Sombras por árbol — 8 de noviembre de 2026

`render_bosque.gd` usa ahora las mismas instancias individuales para el color y
las sombras de los árboles completos en Forward+. Cada ejemplar conserva su
malla, materiales, pose, viento y compensación de LOD. El motor puede descartar
los ejemplares por separado al preparar cada mapa de sombras.

Los MultiMesh conservan sus índices de tala y su selección por celdas. Mientras
la ruta individual está activa, su máscara de render vale cero: sus sombras
no se dibujan una segunda vez. Las instancias reciben la máscara original,
guardada antes del cambio. Desactivar la ruta o retirar una celda restaura
sus capas y ajuste de sombras. La reserva de instancias sigue reutilizándose.
Headless y los otros renderizadores conservan su ruta de MultiMesh.

`establecer_sombras_individuales(false)` mantiene el control de la pasada
anterior: color individual y sombras del MultiMesh. Permite comparar ambas
rutas sin cambiar árboles, hierba, luz, resolución o distancias.

## Medición del mundo completo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, **1600×900**, escala 3D 1, MSAA 0,
VSync desactivado y sin límite de FPS; distancia LOD común de 400 m, conservada
de los ajustes cargados. Cámara de 62°, desplazada del héroe
(7; 3,6; 9), mirando hacia (0; 1,2; −10). Se desacopla del SpringArm3D para
que su colisión no la recoloque; se comprueba su posición y el enlace de
Terrain3D en cada tanda. Héroe y ciclo solar detenidos; HUD, IA y animaciones
del mundo activos.

Cada comparación alterna anterior/nuevo/nuevo/anterior. Se calientan 120
fotogramas al cambiar de lugar y otros 60 antes de cada tanda de 240. El día
usa fase solar 1,08; la noche, 4,1. El recorrido móvil repite una elipse con
radios de 5 y 4 m durante los 240 fotogramas. Se promedian las dos tandas de cada ruta,
también para el percentil 95.

| Cámara | FPS anteriores | FPS nuevos | p95 anterior | p95 nuevo |
| --- | ---: | ---: | ---: | ---: |
| Puerto, día fija | 49,85 | 54,22 | 21,88 ms | 20,04 ms |
| Puerto, día movimiento | 50,08 | 54,65 | 21,89 ms | 19,86 ms |
| Puerto, noche fija | 49,59 | 54,23 | 22,01 ms | 20,12 ms |
| Villa, día fija | 63,70 | 65,18 | 17,22 ms | 17,13 ms |
| Villa, día movimiento | 64,93 | 66,59 | 17,36 ms | 17,18 ms |
| Villa, noche fija | 63,12 | 64,73 | 17,41 ms | 17,07 ms |

Puerto mejora **8,8–9,4 %**; la villa, **2,3–2,6 %**. El objetivo de
100–120 FPS sigue pendiente. Estas cifras corresponden a este Mac y estas
cámaras; falta medir el ejecutable de Windows.

Las estadísticas de primitivas y llamadas aumentan con la ruta individual:
en Puerto de día fijo pasan aproximadamente de 5,38 a 7,69 millones y de
2.067 a 2.415 llamadas. La ganancia se conserva en tiempo real de fotograma.
No se presenta como una reducción de triángulos ni de llamadas. El controlador
Metal devuelve cero para el cronómetro GPU, por lo que no se utiliza como
medida. El coste CPU de render también queda registrado para compararlo en
otros equipos.

## Calidad y pruebas

Se compararon Puerto, Villa Robledal y bosque de día y noche: seis vistas,
con actores y TIME de shaders detenidos. Cada vista captura anterior/anterior/
nuevo/anterior, con 80 fotogramas de asentamiento y la misma fase de dibujo.
Se comprueba que las fases sean realmente diurna y nocturna y que sus imágenes
sean diferentes.

Los controles cambian como máximo un nivel de un canal RGB. Entre la ruta
anterior y la nueva, el percentil 99 del cambio por píxel es cero en las seis
vistas. La mayor fracción de píxeles que cambia más de dos niveles es
**0,0535 %**. Se revisaron las imágenes contiguas: se conservan las siluetas,
la cobertura y las sombras, con pequeñas diferencias de detalle y rasterizado
en sus bordes.

`forest_render_test.gd` conserva las 3.000 cotas de detalle, la cámara
ortogonal, la reserva y la actualización por índice durante la tala. Ahora
verifica además que no se dupliquen sombras, que se restauren las máscaras
originales al desactivar o retirar una celda y que se pueda registrar de nuevo
sin acumular instancias ni conexiones. Se inyectaron dos defectos reales en el
código: dejar la celda visible y no restaurar sus capas. Ambos hicieron fallar
la prueba; el código restaurado vuelve a pasar.

También pasan `vegetation_test.gd` (59.312 árboles y 221.555 parches de hierba)
y `celestial_transition_test.gd` (12.289 muestras y dos relevos sin salto).
La prueba ampliada del bosque ya forma parte del workflow de Windows.

Los resultados, método, inyecciones y comparaciones visuales están en
`generated/reviews/2026-11-08/fotograma/`. Las sondas de diagnóstico se retiran
al finalizar, como exige `CLAUDE.md`.

El siguiente experimento debe estudiar el descarte de parches individuales de
hierba antes del shader, con cajas que incluyan relieve, viento e interacciones.
Se mantienen también pendientes el progreso cooperativo compartido y la prueba
WAN con ocho participantes de `RENDIMIENTO_Y_COOPERATIVO.md`.
