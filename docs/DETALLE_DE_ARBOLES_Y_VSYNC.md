# Detalle de árboles y VSync — 0.1.12

Los árboles completos ya se descartan por ejemplar. Sin embargo, la
compensación de su LOD seguía tomando como referencia la caja del MultiMesh
original: cuando esa caja contiene la cámara, podía mantener al máximo
árboles bastante alejados dentro del mismo grupo.

Se conserva esa referencia hasta el presupuesto automático de cada árbol.
El límite acompaña el umbral de pantalla del Viewport cuando cambia la
calidad, incluso con la cámara quieta. El cambio permite usar los índices
LOD importados de Godot; no sustituye las mallas por otras siluetas ni retira
árboles. Las poses, materiales, alcance, configuración de sombras, hierba,
colisiones e identificadores de tala y red se conservan.

La selección se apoya en el
[LOD automático de Godot](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)
y su [sesgo por instancia](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-lod-bias).
El presupuesto nuevo no introduce más error geométrico que el de un píxel
allí donde la referencia anterior pedía mayor detalle. Las zonas que ya
usaban una representación más ligera conservan su selección.

## FPS del mundo completo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 3D 1, MSAA 0,
LOD común 400 m y umbral 0,85. Fase solar 1,08 aplicada y comprobada.
Héroe detenido; IA, animaciones y HUD activos. Se mantienen la oclusión del
terreno de 0.1.11 y las optimizaciones anteriores.

Se alterna referencia/nuevo/nuevo/referencia con 100 fotogramas de
calentamiento y 240 medidos por tanda. Se comprueba que se dibujan todos.
La cámara y la órbita de 12×8 m son las descritas en
[OCLUSIÓN_BOSQUE](OCLUSION_BOSQUE.md). No hay lecturas de imágenes durante
las muestras. VSync se desactiva mediante el nuevo ajuste, sin guardar
opciones del jugador.

| Zona y cámara | Referencia FPS | Nuevo FPS | Cambio |
|---|---:|---:|---:|
| Bosque verde, fija | 46,01 | 47,15 | +2,48 % |
| Bosque verde, movimiento | 45,35 | 46,48 | +2,49 % |
| Tenebroso, fija | 61,11 | 61,42 | +0,51 % |
| Tenebroso, movimiento | 62,54 | 62,65 | +0,16 % |
| Puerto, fija | 62,41 | 62,84 | +0,69 % |
| Puerto, movimiento | 61,23 | 61,63 | +0,65 % |
| Villa, movimiento | 74,69 | 74,71 | +0,03 % |

El resultado apreciable de esta tanda es aproximadamente un 2,5 % en el
bosque verde. Los cambios menores del resto se consideran variación de la
medición. El p95 de tiempo de fotograma del bosque pasa de 23,55 a 22,88 ms
con cámara fija y de 28,38 a 27,98 ms con movimiento.

Es una mejora moderada de estas cámaras del Mac. No son FPS medidos en
Windows y el objetivo general de 100–120 FPS sigue pendiente.

## Comparación visual

Se comparan 42 vistas estáticas: dos posiciones por zona en bosque verde,
gruta de las raíces, Puerto, villa, nieve y Tenebroso; día, ocaso y noche;
además de tormenta máxima en el bosque verde. Cada vista tiene original,
control y nuevo. Se congelan actores, partículas y tiempo de shaders.

El mayor cambio RGB medio nuevo es **0,03832 sobre 255**, frente a 0,03606
del control; p99 máximo de 1 en ambos. Hay diferencias puntuales de bordes:
hasta 215 en un canal y 182 píxeles por encima de 10 en una imagen de
1.440.000 píxeles. Las imágenes no son idénticas. Se revisaron comparaciones
de bosque, vegetación cercana y menús; se conservan la frondosidad y las
siluetas observadas.

Se añaden 48 posiciones en movimiento con el código final: ocho pasos de
órbita, incluido un giro brusco, en bosque verde y Tenebroso; día, ocaso y
noche con tormenta máxima. Original, control y nuevo se capturan tras dos
fotogramas dibujados por paso. El mayor cambio medio es 0,03999 sobre 255
en el nuevo y 0,03921 en el control; p99 máximo de 1 en ambos. Hay hasta
198 píxeles por encima de 10 en el nuevo frente a diez en el control. Se
inspeccionó también el par con mayor diferencia media. Se conserva la
vegetación observada, con diferencias puntuales de bordes.

## Controles de VSync

**Esc → Gráficos** y el panel **Z** ofrecen «Sincronizar con la pantalla
(VSync)». La opción permanece activada por defecto, también al cargar una
instalación antigua. Desactivarla permite medir sin el límite de frecuencia
de la pantalla; la capacidad de renderizado de cada escena sigue determinando
sus FPS. La elección se guarda en la configuración y ambos menús se
sincronizan sin reenviar eventos.

El panel Z permite desplazarse si el contenido no cabe. Se inspeccionaron
seis capturas reales a 1280×720 y 1600×900: principio y final del panel Z,
y la página de Gráficos. Los controles y el botón de cierre son accesibles.

## Pruebas y límites

`forest_render_test.gd` verifica 3.000 cotas de error con movimiento entre
revisiones, ambas proyecciones, cambio de calidad con cámara quieta, vuelta
al control anterior, reserva, capas, sombras e índices de tala. En Metal,
un recurso de LOD conocido produce doce triángulos de cerca, uno de lejos
y doce al volver al criterio anterior. Omitir el comando real a la GPU
provoca el fallo previsto, aunque las variables de GDScript sigan correctas.
Se detectan también otros seis defectos de selección, límites y cache.

`vsync_settings_test.gd` comprueba guardado y recarga, configuración antigua,
valores iniciales, restauración, ambos menús y liberación de controles al
cambiar de página. La pasada gráfica comprueba el modo de la ventana real.
Se inyectaron seis defectos: no guardar, no cargar, valor inicial incorrecto,
no restaurar, botón sin conectar y ventana sin actualizar. Todos fallan;
la fuente restaurada pasa. Una prueba adicional detectó y permitió corregir
un mensaje del panel Z que quedaba obsoleto al cambiar VSync desde Gráficos.
Ambas pruebas están en el workflow de Windows.

El combate cooperativo vuelve a pasar 17 etapas entre dos procesos ENet
reales. El recorrido local no equivale a validar ocho equipos por Internet.
El trabajo de interés espacial y la medición WAN siguen pendientes.

Se descartó aplicar un sesgo uniforme a todos los árboles: aumentaba el
detalle de grupos que ya tenían menos y reducía FPS. El tope más agresivo
de 0,25 sólo se usa en el diagnóstico. Los archivos de las sondas se retiran
al terminar y quedan sus fuentes y resultados en
`generated/reviews/2026-11-09/lod-*`.
