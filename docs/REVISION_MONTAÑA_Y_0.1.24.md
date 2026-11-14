# Montaña, vegetación, hacha y crepúsculo — 0.1.24

La panorámica desde la ladera nevada está limitada principalmente por el
renderizado. La geometría low-poly de cada objeto no evita el coste de miles de
objetos, millones de triángulos, sombras y píxeles cuando se ve gran parte de la
isla. Esta revisión reduce el detalle distante de los tejados que habían perdido
su LOD al recortarse, retira las plantas pequeñas solicitadas y corrige el agarre
del hacha y el valle oscuro del crepúsculo. El objetivo general de 100–120 FPS
sigue pendiente.

## Diagnóstico en este Mac

Godot 4.7.1, Metal Forward+, M2 Pro, 2560×1440 nativos, escala 1, sin MSAA ni
VSync, con oclusión activa. Misma fase diurna y cámara para cada comparación.
Las cifras son fotogramas dibujados, con calentamiento previo. No son mediciones
de Windows ni una garantía para cualquier equipo. No se midió temperatura;
el calentamiento descrito por el jugador no demuestra por sí solo un fallo de
scripts o una limitación térmica.

| Cámara o intervención diagnóstica | FPS | Triángulos visibles | Dibujos de color |
|---|---:|---:|---:|
| Subida, cota 315 m | 56,9 | 1.478.904 | 120 |
| Ladera, cota 440 m, mirando abajo | 49,3 | 226.876 | 26 |
| Misma ladera, mirando al sur | 39,4 | 5.305.922 | unos 2.483 |
| Panorámica con lógica y animaciones detenidas | 39,7 | sin cambio relevante | sin cambio relevante |
| Panorámica sin edificios, sólo diagnóstico | 45,8 | 3.233.579 | 892 |
| Panorámica sin árboles, sólo diagnóstico | 48,5 | 2.666.517 | — |

Detener la lógica desactiva 1.722 entradas de nodos, incluidas entradas que ya
estaban inactivas; **no significa que hubiera 1.722 scripts ejecutándose**.
La física baja de unos 2,4 a 0,74 ms, pero los FPS apenas cambian. Ocultar el mar
tampoco mejora esta cámara. Los costes de ocultar categorías no son aditivos:
pueden aparecer objetos que antes quedaban tapados.

La arquitectura y los árboles sí merecen trabajo adicional. Las copas tienen
huecos; un oclusor macizo que los tape por completo puede borrar objetos que
el jugador debería ver. La oclusión de terreno y edificios existente se conserva.
Mirar una vista sencilla cerca no describe el coste de una panorámica.

Prueba local: `generated/reviews/2026-11-14/montana/montana-desglose.json`.
Las pruebas FPS se hicieron sin otra instancia del juego; la actividad del
sistema varía y las series antiguas de otros días no son controles válidos.

## Tejados con detalle por distancia

`BuildingAssembler._clip_roof_surface()` generaba recortes sin índices y sin
niveles de detalle. Quince formas únicas se reutilizan en 624 piezas de tejado.
Ahora se cargan 41 niveles precalculados desde un recurso comprimido de unos
58 KiB. En la panorámica de cierre:

| Mediana de dos muestras ABBA, 240 fotogramas por muestra | Original | Con LOD |
|---|---:|---:|
| FPS a 2560×1440 | 39,14 | 40,28 |
| Triángulos visibles | 5.308.434 | 4.890.302 |
| Triángulos de sombras | 3.121.878 | 3.121.878 |

Son **418.132 triángulos visibles menos**, aproximadamente un **2,9 % más de
FPS en esta cámara**, conservando resolución y sombras. Otra serie más amplia
da ganancias pequeñas en villa y puerto; no se presenta como una mejora general
del 2,9 %. Los dibujos pueden aumentar ligeramente al dividirse los lotes por
nivel. No hay promesa de 100–120 FPS tras este cambio.

Sólo se añaden índices. Los buffers originales de posiciones, normales, UV y
atributos se conservan byte por byte. El detalle cercano mantiene todos sus
triángulos, materiales y colisiones. No hay generación de LOD ni búsqueda por
fotograma: el trabajo se hace al construir las quince formas compartidas.

Una firma de geometría valida cada registro. Un caché ausente, una forma editada,
índices inválidos o un material con shader desconocido recuperan la malla
completa. La firma redondea sólo su entrada a 0,0001 para tolerar pequeñas
variaciones de importación entre plataformas; no redondea el modelo.

Para reconstruir tras editar las cubiertas:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/hornear_lod_tejados.gd -- --hornear-lod-tejados
```

La comparación visual incluye 48 capturas, seis cámaras de día y de noche con
controles repetidos. El percentil 99 de diferencia RGB es como máximo 1/255.
Hay cambios pequeños en aristas de tejados lejanos; las imágenes no son idénticas.
La peor fracción de píxeles con diferencia superior a 10/255 es 0,0993 %.
La prueba nativa confirma que los 41 niveles llegan a la GPU.

Pruebas locales: `generated/reviews/2026-11-14/tejados-lod-cierre/` y
`generated/reviews/2026-11-14/tejados-calidad/`.

## Pradera y agarre del hacha

Se conserva una sola biblioteca de hierba: las briznas procedurales elegidas,
con su altura, densidad, viento, interacción y color del suelo. Se retiran las
cuatro variantes antiguas y las bibliotecas de helechos, arbustos, flores y
setas, junto con sus nodos y dibujos. El reparto conserva 221.555 parches de
hierba y 59.312 árboles completos.

El arranque consume la misma secuencia aleatoria de las plantas retiradas sin
crear sus elementos. Tres semillas verificadas conservan exactamente el estado
final del generador; los árboles posteriores y sus identidades de tala/guardado
no cambian por esta limpieza. No se atribuye a la retirada una ganancia de FPS
que no se haya aislado con un control equivalente.

El agarre anterior del hacha estaba junto a la muñeca, fuera del volumen de la
mano. Su ancla pasa de `(0, 0.105, 0)` a `(0, 0.25, 0.015)` en el espacio del
hueso. La prueba usa los vértices ligados a `Fist.R` para verificar la palma
real. Se revisan 48 poses de ocho personajes, piezas de los dos packs, caminar,
reposo y desenfundar; también se inspeccionan capturas nativas. Espada y antorcha
conservan sus ajustes.

## Entrada gradual de la luna

La iluminación lunar esperaba hasta el último 11 % de claridad diurna. El bosque
se oscurecía demasiado y volvía a iluminarse. La luna aporta luz gradualmente
durante el crepúsculo; su disco, las estrellas y el relevo de sombras conservan
sus curvas. Hay un solo mapa direccional y la noche mantiene energía lunar 0,72.

En veinte capturas nativas emparejadas de bosque y villa, la noche final difiere
como máximo 1/255 por canal. En la región de suelo del bosque, la luminancia
lineal media mínima entre las fases muestreadas pasa de 0,00399 a 0,04538;
la noche final queda en 0,05219. Esta región y estas fotos no representan todas
las superficies de la isla. La prueba analítica recorre 12.289 fases y verifica
la iluminación de una superficie horizontal, además de la continuidad del relevo
sol/luna en ambos sentidos.

Pruebas locales: `generated/reviews/2026-11-14/crepusculo-calidad/`.

## Verificación y límites

`roof_lod_test.gd` se añade a CI. Las regresiones cubren geometría y materiales
completos, caché ausente/corrupto/editado, agarre en la palma, ausencia de plantas
retiradas, luz y sombras. Se inyectan fallos reales para comprobar que los nuevos
invariantes fallan por su aserción. Las sondas temporales se archivan en las
pruebas locales y se retiran de `tools/diagnostics/` antes del commit.

El combate cooperativo se comprueba con dos procesos ENet reales. No hay cambios
de protocolo ni de autoridad en esta entrega. El ZIP Windows y el recurso LOD
empaquetado se comprueban antes de publicar la web del NAS.

Se descartan los prototipos de caché de normales del terreno y recorte del mar:
sus resultados no justifican incorporarlos. Siguen pendientes el rendimiento
panorámico general y una medición de FPS en hardware Windows real.
