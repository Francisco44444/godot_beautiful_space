# Bosque Tenebroso: descarte y trabajo oculto

## Mejora integrada en 0.1.10

Los 3.360 árboles secos del Bosque Tenebroso seguían dibujándose en grupos
grandes. Aunque parte de un grupo entrase en la cámara, se enviaban también
sus árboles situados fuera de ella. Ahora `render_arboles_secos.gd` compacta
el pase de color con los ejemplares cuyos volúmenes intersectan la cámara.

Se conservan la malla, los materiales, las distancias, la caja original del
grupo y su selección de LOD. El MultiMesh original sigue produciendo las
sombras completas. La copia de color no proyecta sombras y sólo cambia su
prefijo de instancias visibles; no se compactan los índices de la fuente.
Las colisiones, el registro de recursos y los identificadores cooperativos
siguen usando la fuente original.

Las cajas individuales incluyen giro, escala y un margen local de 5 cm.
Sólo se admite geometría estática con materiales estándar: se rechazan
shaders de desplazamiento desconocidos, billboard, grow y fundidos por objeto.
Las poses de tala llegan desde el mismo productor que modifica el MultiMesh.
Una modificación tardía vuelve temporalmente al color original de esa celda,
para que el tween no adelante la sombra un fotograma respecto a la imagen.

Una cámara quieta reutiliza el resultado. Al moverse, sólo se vuelve a subir
un grupo si cambian sus miembros visibles o sus poses. Las matrices se envían
en un buffer por grupo. Fuera de todos los rangos forestales se descarta el
conjunto con una sola comprobación. Headless y otros renderizadores conservan
la ruta original.

## FPS normales, con el mundo activo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 3D 1, MSAA 0,
LOD común 400 m, VSync desactivado y sin límite de FPS. Fase solar 1,08
aplicada y comprobada. Héroe detenido; IA, animaciones y HUD activos.
Las mediciones incluyen las optimizaciones anteriores de hierba y edificios.

Cámara de 62°, desplazada (7; 3,6; 9) desde el héroe y mirando hacia
(0; 1,2; −10). En movimiento recorre una órbita de 12×8 m y oscila 0,7 m
en altura. El punto tenebroso es (4380; −1320), con cámara inicial en
(4387; 396,0938; −1311).

Se alterna original/nuevo/nuevo/original: 100 fotogramas de calentamiento y
240 medidos por tanda. Se comprueba que se dibujan los 240 fotogramas de
cada muestra. Las cifras son medias de dos tandas por modo.

| Vista | FPS original | FPS nuevo | Cambio | p95 original | p95 nuevo |
| --- | ---: | ---: | ---: | ---: | ---: |
| Tenebroso, fija | 49,67 | 56,55 | +13,9 % | 22,139 ms | 19,286 ms |
| Tenebroso, movimiento | 50,43 | 56,59 | +12,2 % | 25,338 ms | 23,091 ms |
| Puerto, movimiento | 56,66 | 56,85 | +0,3 % | 19,578 ms | 19,281 ms |
| Bosque verde, movimiento | 45,14 | 45,17 | +0,1 % | 28,463 ms | 28,548 ms |

La revisión final del bosque incluye la protección para poses tardías. Los
controles de Puerto y bosque verde proceden del recorrido completo anterior;
no muestran una mejora significativa. El p95 del bosque verde varía 0,085 ms.
El gestor cuesta aproximadamente 1,13 ms de CPU por fotograma en la órbita
tenebrosa, 0,005 ms en reposo y 0,003–0,004 ms fuera de su región. En el
primer envío recorría las 174 celdas incluso lejos del bosque: la comprobación
del conjunto eliminó ese coste innecesario.

Son resultados de este Mac y estas cámaras. El objetivo de 100–120 FPS en
todo el juego sigue pendiente; no son mediciones de Windows.

## Imagen y pruebas

Se comparan ocho vistas estáticas y 72 posiciones en movimiento: dos puntos
del este, Puerto y bosque verde, de día y noche. Los recorridos incluyen
giros bruscos que muestran árboles antes situados detrás de la cámara.
Se congelan actores, animaciones, partículas y tiempo de los shaders; el
cielo sigue la cámara con delta cero y se comprueba la fase de día o noche.

Los controles estáticos varían hasta 0,04486 de RGB medio sobre 255 y los
nuevos hasta 0,05397, con p99 máximo de 1 en ambos casos. En movimiento,
el mayor cambio medio nuevo es 0,05925 y el p99 máximo es 1; los controles
alcanzan 0,04769 y p99 de 1. Hay diferencias puntuales de iluminación: hasta
130 en un canal y 116 píxeles por encima de 10 en una imagen de 1.440.000
píxeles. Las imágenes no son idénticas. Se inspeccionaron comparaciones
contiguas: se mantienen las siluetas, cobertura y sombras en estas vistas.

`dry_tree_render_test.gd` comprueba frustum, giro de cámara, retorno desde
fuera de la región, índices originales, matrices, caja y LOD del grupo,
visibilidad, restauración y poses tardías. Se ejecuta en headless y Metal;
este último verifica las matrices enviadas a la GPU. Diez defectos reales
provocan los fallos esperados y la fuente restaurada vuelve a pasar.
La prueba forma parte del workflow de Windows.

Pasan también vegetación completa, estabilidad de dos viajes LOD y combate
cooperativo de 17 etapas entre dos procesos reales.

## Oclusión entre copas: investigación pendiente

El descarte integrado es por cámara. Ocultar árboles que quedan detrás de
otros exige respetar los huecos de las hojas y el viento. La textura normal
analizada tiene un 76,7 % de píxeles por debajo del umbral alfa del shader;
las texturas de pino y árbol tenebroso rondan el 70,7–70,9 %.

Un ensayo toma la profundidad real de la escena, incluyendo máscaras alfa,
terreno y hierba. Se calibra con una superficie a nueve metros, se amplían
dos píxeles las cajas proyectadas y se añade margen de profundidad. En la
instantánea tenebrosa aparecen 458 árboles completamente ocultos entre las
692 cajas que intersectan la pantalla: 70 del bosque principal y 388 secos.

Con actores y viento congelados, combinar ese descarte con el de cámara
mejora aproximadamente un 20 % el ensayo fuera de pantalla. Cada fotograma
se fuerza y se lee de la GPU: esos tiempos incluyen la lectura y no son
FPS interactivos. Los tiempos GPU independientes no están disponibles en
este backend, que devuelve cero. Se verifican las imágenes antes y después.

La máscara sólo sirve para esa cámara y ese instante. No se publica como
oclusor permanente: faltan actualización en movimiento, viento, revelado al
talar y conservación de sombras de objetos ocultos. Tampoco se usan cajas
macizas para sustituir el follaje. El prototipo de troncos con viento detenido
aportaba sólo un 0,8–1,8 % en las posiciones verdes probadas.

Otro ensayo quedó invalidado al taparse la ventana: el contador avanzaba sin
dibujar todos los fotogramas. La guardia detectó 22 dibujados de 360. Sus
cifras no se usan. Las mediciones normales de la tabla sí verifican todos
los fotogramas y no realizan lecturas de imagen durante las muestras.

Datos y comparaciones quedan en `generated/reviews/2026-11-08/secos-definitivo/`
y los ensayos previos en las carpetas de profundidad y oclusión del bosque.
Las sondas se retiran al finalizar.
