# Bosque y medición completa del suelo — 8 de noviembre de 2026

**Pasada posterior:** [SOMBRAS_DEL_BOSQUE.md](SOMBRAS_DEL_BOSQUE.md) extiende el
descarte individual a las sombras, con la cámara enlazada a Terrain3D y
comparaciones nuevas de día, noche y movimiento. Este documento conserva el
control histórico de color individual y sombras en MultiMesh.

El objetivo acordado es buscar **100–120 FPS conservando la calidad**. Esta
pasada consigue una mejora modesta en Puerto Alba; la villa sigue prácticamente
igual. No se ha alcanzado todavía ese objetivo.

**Corrección posterior de cámara:** se detectó que Terrain3D podía seguir la
cámara anterior al abrir una vista de revisión. Las tandas de este documento
son controles históricos con esa configuración; no representan la nueva
referencia de FPS con el terreno correctamente centrado. El seguimiento de
cámara y las entradas se corrigen en [ENTRADAS_Y_HIERBA.md](ENTRADAS_Y_HIERBA.md).

## Cambio aplicado

`render_bosque.gd` representa el color de los árboles completos mediante
instancias de RenderingServer. Forward+ puede descartarlas individualmente y
agrupar las que comparten malla y material. Los MultiMesh originales conservan
las sombras, los índices de tala y las referencias persistentes. Los proxies
lejanos mantienen su funcionamiento anterior. El modo headless y los otros
renderizadores usan la ruta original.

La selección automática de LOD depende de la distancia a la caja y de la
escala del objeto. Cambiar de MultiMesh a ejemplares altera ambos valores.
Se compensa el sesgo para permitir, como máximo, el error geométrico anterior.
Se conserva un margen de cámara de 2 m y se reparten las revisiones entre
fotogramas. Un salto de posición fuerza la revisión inmediata. Véanse la
[selección de LOD de Godot](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html#using-mesh-lod-with-multimesh-and-particles)
y su [agrupación automática en Forward+](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html#use-automatic-instancing).

Las instancias se reutilizan por malla al cambiar de celda. En este recorrido
la reserva alcanza **3.701 instancias**, para un mundo que conserva los
**59.312 árboles registrados**. No se crea un nodo de escena por árbol. La
tala, ocultación y restauración actualizan el ejemplar correspondiente; las
copas tienen un margen de descarte que cubre el viento máximo. Las instancias
se liberan al salir del mundo.

## Rendimiento del mundo completo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, **1600×900**, escala 3D 1, MSAA 0,
VSync desactivado y sin límite de FPS. Cámara de 62°, posición relativa al
héroe (7; 3,6; 9), mirando hacia (0; 1,2; −10). Héroe y ciclo solar detenidos;
IA y animaciones del mundo normales. Tandas anterior/nuevo/nuevo/anterior,
240 fotogramas después de 70 de calentamiento. Se repite con una trayectoria
de cámara de 5×4 m. Resolución, vegetación, distancias, iluminación y sombras
son las mismas en ambos casos.

| Lugar y cámara | FPS anteriores | FPS nuevos | p95 anterior | p95 nuevo |
| --- | ---: | ---: | ---: | ---: |
| Puerto, fija | 48,05 | 49,51 | 22,68 ms | 21,94 ms |
| Puerto, movimiento | 48,25 | 50,12 | 22,67 ms | 21,80 ms |
| Villa, fija | 63,11 | 63,55 | 17,39 ms | 17,36 ms |
| Villa, movimiento | 63,97 | 64,49 | 17,47 ms | 17,47 ms |

Son las medias de las dos tandas de cada modo; el p95 también es la media de
sus dos percentiles. Puerto mejora aproximadamente **3–4 %** y reduce el
tiempo de los fotogramas lentos. La variación de la villa es inferior al 1 %:
se considera prácticamente sin cambio. Son medidas de estas cámaras en este
Mac, no una promesa para todas las zonas o equipos.

El primer intento de integración concentraba las revisiones de detalle al
mover la cámara y empeoraba el p95 de la villa. Se sustituyó por revisiones
repartidas antes de conservar el cambio. Datos finales en
`generated/reviews/2026-11-08/bosque/rendimiento.json`.

## Comparación visual

Se congelan actores, animaciones y tiempo de shaders. Se capturan Puerto,
Villa Robledal y bosque de día y de noche; además, un árbol durante la tala,
oculto y restaurado: **nueve escenas**. Cada una registra tres controles
originales y una imagen nueva, con 80 fotogramas de asentamiento y la misma
fase de fotograma.

Los tres controles coinciden exactamente en cada escena. Frente al nuevo
render, el percentil 99 del cambio por píxel es **0** en las nueve vistas.
El mayor cambio RGB medio es **0,0466 sobre 255**; la mayor fracción de píxeles
con algún canal que cambia más de 2 es **0,1221 %**. Se revisaron las imágenes
contiguas: se conservan paisaje, siluetas, sombras y vegetación, con diferencias
pequeñas de detalle y rasterizado. Las imágenes no son idénticas.

La ocultación del árbol produce una imagen distinta de su restauración; el
control no está comparando dos estados en los que el árbol ya faltaba. Capturas,
hojas contiguas y resultados en
`generated/reviews/2026-11-08/bosque/calidad/`.

## Corrección de la prueba del suelo

En Villa Robledal, `CalleEmpedrada` es una malla independiente de Terrain3D.
Ocultar sólo Terrain3D dejaba ese empedrado visible. Se repitió el control
ocultando por separado la calzada y, después, calzada y terreno juntos:

| Control temporal de la villa | FPS |
| --- | ---: |
| Mundo completo | 63,47 |
| Sin calzada | 59,12 |
| Sin Terrain3D | 70,47 |
| Sin Terrain3D ni calzada | 69,42 |

Retirar una superficie deja ver otras: estos resultados **no son costes
sumables**. La calzada también tapa terreno que hay debajo. Las retiradas
pertenecen al diagnóstico; el juego conserva ambos suelos. Datos y captura
del control corregido en `generated/reviews/2026-11-08/arquitectura/`.

## Pruebas y siguientes pasos

`forest_render_test.gd` verifica 3.000 cotas de detalle con movimiento entre
revisiones, cámara ortogonal, sombras conservadas, reserva acotada, tala por
índice, actualización con cámara quieta y saltos que superan el presupuesto
por fotograma. Retirar temporalmente la compensación y retirar la revisión
inmediata de un salto produjeron los fallos previstos. La prueba se incluye
en el workflow de Windows.

Pasan también `vegetation_test`, `multiplayer_test`, `island_world_test` y el
recorrido de combate ENet real entre dos procesos. La distribución, las villas
y los estados de recursos conservan sus contratos anteriores. Resultados en
`generated/reviews/2026-11-08/bosque/regresiones.json` y `enet.json` (17 etapas).
La prueba de red sigue mostrando el aviso previo de estados de vecinos de
4.051 bytes frente a una MTU de 1.392; repartir esos estados continúa pendiente.

Se ensayaron lotes manuales de arquitectura y variantes del shader vegetal.
Los lotes pequeños empeoraron el rendimiento; las variantes de shader no
ofrecieron una mejora suficiente para adoptarlas. Una unión de arquitectura
alcanzó el límite de superficies: se descarta y sus cifras no constituyen una
comparación válida de calidad equivalente.

El siguiente margen importante sigue en el bosque: estudiar representaciones
intermedias con atlas de los propios árboles, comparadas al moverse y con luz
solar/lunar. Mantener las sombras y el aspecto debe formar parte de esa prueba.
Continúan además el tráfico de red por interés espacial y la validación WAN
con ocho participantes de `COMBATE_COOPERATIVO.md`.
