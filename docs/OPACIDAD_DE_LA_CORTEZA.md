# Cortezas opacas sin recorte de hojas — 10 de noviembre de 2026

## Cambio conservado

El shader del bosque aplicaba `discard` según el alfa del albedo a todas las
superficies. Las cortezas normales y retorcidas usan imágenes completamente
opacas; las hojas sí contienen huecos y necesitan ese recorte.

Al construir los materiales se consulta cada textura una vez. Una imagen que
`Image.detect_alpha()` clasifica como `ALPHA_NONE` usa la variante sin recorte.
Las hojas, imágenes desconocidas y formatos que no se pueden descomprimir
conservan la variante recortada. Se comparten dos programas entre los
materiales, con los mismos albedos, tintes, viento y parámetros de tormenta.
En el mundo actual pasan a la variante opaca **30 de los 60 materiales**;
se inspeccionan **cinco texturas distintas**, dos opacas y tres con alfa.

La comprobación se realiza durante la construcción, sin trabajo nuevo por
fotograma. La caché termina al reconstruir los materiales para poder reevaluar
una textura recargada. Se descomprime una **copia**: `get_image()` puede devolver
la imagen compartida del recurso importado, cuyo formato y bytes se conservan.

Se mantienen las mallas, instancias, densidad y altura de hierba, distancias,
LOD, sombras, recorte de hojas, colores y recorrido del viento.

## FPS del mundo completo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, **1600×900**, escala 1, MSAA 0,
VSync desactivado y sin límite. LOD común 400 m y umbral 0,85. Cámara de 62°,
desplazada (7; 3,6; 9) y mirando hacia (0; 1,2; −10), enlazada a Terrain3D.
Héroe y ciclo solar detenidos; IA, animaciones y HUD activos.

Por vista se alterna anterior/nuevo/nuevo/anterior, con 100 fotogramas de
calentamiento y 240 medidos por tanda. Se comprueba que los 240 se dibujen.
El movimiento recorre una órbita de 12×8 m, con oscilación vertical de 0,7 m.
Día en fase 1,08 y noche en 4,1; se conserva y registra el mapa de sombras
solar o lunar que corresponda. Una sola prueba gráfica a la vez.

| Vista | FPS anteriores | FPS nuevos | Cambio | p95 anterior / nuevo |
| --- | ---: | ---: | ---: | ---: |
| Puerto, fija | 62,14 | 63,89 | +2,8 % | 16,70 / 17,29 ms |
| Villa, fija | 76,40 | 77,45 | +1,4 % | 14,95 / 14,80 ms |
| Bosque verde, fija | 47,18 | 48,70 | +3,2 % | 22,91 / 22,22 ms |
| Bosque verde, movimiento | 46,24 | 47,78 | +3,3 % | 27,93 / 27,49 ms |
| Bosque verde, noche | 46,72 | 48,38 | +3,5 % | 23,11 / 22,28 ms |
| Tenebroso, movimiento | 63,10 | 63,29 | +0,3 % | 17,96 / 17,83 ms |

Son medias de dos tandas por modo, también para el p95. El Tenebroso queda
prácticamente igual. En Puerto aumenta el FPS medio, pero empeora el p95: no
se afirma una mejora de todos los percentiles. Dos recorridos previos dieron
ganancias de aproximadamente 2–3 % en bosque; la tabla recoge la implementación
definitiva que conserva intactos los recursos importados.

La mejora es modesta y corresponde a estas cámaras y este Mac. **El objetivo
general de 100–120 FPS sigue pendiente**; no son mediciones de Windows ni una
reducción demostrada del tiempo GPU por pase. Metal no proporciona aquí ese
cronómetro independiente.

## Imagen, pruebas y cooperativo

Se comparan **13 vistas**: Puerto, villa, bosque verde, acceso de Raíces, nieve y
Tenebroso de día y noche, más bosque verde con viento de tormenta. Se congelan
actores, animaciones y tiempo de shaders; cada vista captura original,
control, nuevo y original restaurado. Las tres capturas originales coinciden
exactamente en las trece vistas.

Frente al programa nuevo, el percentil 99 del cambio por canal vale **0** en
todas ellas. La mayor diferencia RGB media es **0,00475 sobre 255**; como máximo
**0,0498 %** de los píxeles cambia más de dos niveles en algún canal. Las imágenes
no son idénticas: las diferencias son pequeñas y aparecen en el rasterizado.
Se revisaron las capturas y se conservan las hojas, siluetas, sombras y viento.

`tree_material_test.gd` comprueba alfa uniforme, un hueco de un píxel, alfa
parcial, RGB sin alfa, textura desconocida, los cinco albedos importados y la
conservación de sus bytes. Una textura controlada cuenta las lecturas y permite
cambiar la imagen del mismo recurso para verificar caché y reconstrucción.
También prueba las variantes compartidas en tres tintes de bioma y el viento
de tormenta. Pasa en headless y con Metal, y está incluida en CI.

Doce defectos inyectados hacen fallar sus controles: mirar sólo el primer
píxel, omitir descompresión o copia, perder cualquiera de las dos cachés de
resultado, usar rutas vacías como identidad, aceptar imágenes desconocidas,
seleccionar siempre una variante, duplicar el programa o los shaders y
arrastrar la caché entre reconstrucciones. Las fuentes restauradas vuelven a
pasar la prueba positiva.

Pasan además el render individual del bosque, vegetación completa, recursos
y transición solar/lunar. El cooperativo se prueba con dos procesos ENet y
cliente Metal: tres golpes con instantáneas periódicas, caída, tocón y
restauración; también combate y cuatro disparos dentro de grutas. Se revisan
las cuatro capturas de tala y restauración. No se modifica el protocolo ni
se amplía con esto la validación a WAN u ocho máquinas.

Datos, fuentes de sondas retiradas, inyecciones, registros y capturas quedan
en `generated/reviews/2026-11-10/opacidad-troncos/`, una carpeta local ignorada
que no se exporta con el juego.
