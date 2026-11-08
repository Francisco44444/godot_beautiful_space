# Hierba por parches — 8 de noviembre de 2026

La pasada posterior a 0.1.7 conserva las briznas, altura, densidad, materiales,
color del terreno, fundidos y distancias de los campos cercano y medio.
Forward+ puede descartar cada parche antes de ejecutar su shader, en lugar
de enviar todo el MultiMesh de la ventana si su caja toca la cámara.

## Representación y límites

`render_hierba.gd` crea instancias de RenderingServer con la misma malla y
transformación. El motor las agrupa por malla/material. Se añade un gestor
al árbol, sin crear un nodo por parche. Las instancias se reutilizan al
desplazarse y al cambiar de vista; los parches repetidos conservan su identidad.
Los otros renderizadores y el modo headless mantienen la ruta original.

La caja de cada parche usa los extremos de todos los píxeles de altura de
su huella, con una muestra adicional alrededor para el filtrado. Incluye
picos interiores, coordenadas negativas y cruces de región. Se calculan los
desplazamientos con la base y escala de la malla, y se incluyen las raíces
sin adaptar para regiones ausentes. Un margen horizontal de cinco metros
cubre la suma máxima actual de brisa, racha, tormenta, pisada y onda: 4,255 m.
Los descensos de la hoja también forman parte del volumen.

El cache conserva como máximo 2.048 huellas y se invalida cuando cambian los
mapas de altura o de regiones de Terrain3D. Las identidades de la distribución
estática permiten conservar los parches que permanecen en la ventana sin
volver a multiplicar y comparar todas sus matrices. La fuente invisible se
sincroniza con la distribución más reciente antes de restaurarla.
La reserva alcanza 1.139 instancias en el recorrido medido.

Se usan las API de [RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)
y los mapas y señales de [Terrain3DData](https://github.com/TokisanGames/Terrain3D/blob/main/doc/api/class_terrain3ddata.rst).

## Medición del mundo completo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 3D 1, MSAA 0,
LOD común 400 m, VSync desactivado y sin límite de FPS. Cámara de 62° a
(7; 3,6; 9) del héroe, mirando hacia (0; 1,2; −10); enlazada con Terrain3D.
Fase solar 1,08 aplicada y comprobada antes de detener el ciclo. Héroe
detenido; IA, animaciones y HUD activos.

Se alterna original/nuevo/nuevo/original, con 80 fotogramas de calentamiento
y 240 medidos por tanda. Se repite con una trayectoria de cámara de
12×8 m de radio y 0,7 m de oscilación vertical, que fuerza renovaciones
de ventana. Los percentiles corresponden a tiempos reales de fotograma.

| Lugar y cámara | FPS anteriores | FPS nuevos | Cambio | p95 anterior | p95 nuevo |
| --- | ---: | ---: | ---: | ---: | ---: |
| Puerto, fija | 53.59 | 56.94 | +6.2 % | 20.24 ms | 18.85 ms |
| Puerto, movimiento | 53.14 | 56.36 | +6.1 % | 21.23 ms | 19.50 ms |
| Villa, fija | 65.37 | 69.15 | +5.8 % | 17.02 ms | 16.40 ms |
| Villa, movimiento | 63.74 | 66.01 | +3.6 % | 18.05 ms | 18.56 ms |
| Bosque, fija | 43.19 | 45.76 | +6.0 % | 25.27 ms | 23.74 ms |
| Bosque, movimiento | 42.59 | 45.11 | +5.9 % | 29.54 ms | 28.46 ms |

Son medias de las dos tandas de cada modo. Puerto y bosque mejoran alrededor
de un 6 %; la villa mejora un 5,8 % con cámara fija y un 3,6 % en movimiento.
En esta última cámara el p95 todavía empeora 0,51 ms, aunque la media y el
p99 mejoran. La villa fija también presenta variación en el p99; estas
medidas no demuestran una mejora uniforme de los fotogramas lentos.
El objetivo de 100–120 FPS sigue pendiente y no se extrapola a Windows.

El primer prototipo mejoraba la media pero empeoraba los fotogramas lentos
de la villa en movimiento. Esa versión no se publica: se sustituyó la
comparación de matrices por identidades estables y se evitó actualizar la
fuente invisible antes de repetir la medición.

## Imagen y pruebas

Se congelan actores, animaciones, modificadores de esqueleto y tiempo de los
shaders. Cada vista registra tres controles originales y una imagen nueva,
con 80 fotogramas de asentamiento y la misma fase de fotograma: Puerto,
Villa y Bosque de día y noche, pendiente, cruce de región y deformación
máxima de hierba. La fase solar se comprueba con `daylight_factor`.
La comparación en movimiento registra dos recorridos originales y uno nuevo.

Los tres controles estáticos coinciden exactamente en las nueve vistas. El
mayor cambio RGB medio frente al render nuevo es 0,0888 sobre 255 y el mayor
percentil 99 es 2. En movimiento se comparan 27 posiciones: los controles
originales presentan variación temporal de hasta 2 por canal; el nuevo alcanza
un cambio RGB medio máximo de 0,2539 y un percentil 99 máximo de 3. Las imágenes
no son idénticas. Se inspeccionaron comparaciones contiguas: se conservan la
cobertura, las siluetas y el detalle, con diferencias pequeñas de iluminación.

`grass_render_test.gd` comprueba extremos interiores de altura, bordes
negativos, regiones ausentes, 34.560 vértices con viento y escala, cache
acotado, duplicados, reserva, identidades, visibilidad, cambios de altura
y restauración de la última distribución. Se ejecuta tanto en headless como
con Metal. El backend dummy devuelve identidad al consultar las matrices de
MultiMesh; la lectura real se verifica con Metal y mediante las capturas.
La prueba se incluye en el workflow de Windows.
Se inyectaron trece defectos reales y los trece producen su fallo esperado,
incluida la falta de subida de matrices, detectada con Metal. El código
restaurado pasa en headless y con Metal. Pasan además la vegetación completa
y el combate cooperativo de 17 etapas entre dos procesos reales.

Datos, capturas, controles e inyecciones de defectos quedan en
`generated/reviews/2026-11-08/hierba/`. Las sondas se retiran al finalizar.
La referencia de Windows y el objetivo de 100–120 FPS siguen pendientes.
