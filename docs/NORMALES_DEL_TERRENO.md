# Normales constantes del terreno — 12 de noviembre de 2026

## Trabajo que se estaba repitiendo en GPU

Las siete capas normales reales de Terrain3D son imágenes RGBA8 de 1024²,
con diez mipmaps. Todos sus texeles, incluidos los mipmaps, valen exactamente
`(127, 127, 255, 255)`, y sus siete profundidades normales valen cero.
El shader completo seguía leyendo la matriz de normales y declarando el mapeo
normal aunque estas capas no aportasen relieve.

La especialización sustituye las dos lecturas `textureGrad` de esa matriz por
el valor exacto `127/255, 127/255, 1, 1` y conserva la normal geométrica
normalizada. Mantiene el cálculo de mezcla, AO, rugosidad, albedo y todos los
uniformes de Terrain3D. Usar `0,5` en vez de `127/255` cambiaría los datos de
entrada; por eso se comprueban también los cuatro canales.

## Comprobación y reserva

Se validan la matriz GPU real, su número de capas, las profundidades subidas al
material y todos los bytes de cada imagen. No se deduce la cantidad a partir de
los descriptores: en este proyecto `get_texture_count()` y `get_texture_list()`
devuelven cero en ejecución mientras la GPU conserva siete capas.

La comprobación sucede después del dibujo inicial y al notificarse cambios en
las texturas o el material. No hay `_process`, `_physics_process` ni lecturas de
texturas al mover la cámara: la prueba conserva el contador de revisiones
durante cien fotogramas con desplazamiento. Las trece revisiones de las
capturas tardaron **43,1–76,7 ms** en validar y preparar el shader; es trabajo
por cambio de recursos, no por fotograma, y no mide toda la compilación GPU.

Un píxel o mipmap distinto, una profundidad distinta de cero, una cantidad o
formato desconocidos o una estructura de shader no reconocida recuperan el
material completo. La ruta se limita a Forward+ con GPU real; el servidor sin
ventana mantiene el original. Un shader personalizado activo se respeta y uno
inactivo se conserva al desactivar la especialización.

La oclusión horneada admite esta especialización porque conserva íntegros los
vértices, alturas y agujeros. Se comprueban el gestor real, el material activo
y el código exacto verificado. Una edición posterior deja de ser compatible;
los demás shaders siguen excluidos. La prueba reprodujo primero la
incompatibilidad con la oclusión y ahora exige conservar su recurso de
**149 568 índices** en la isla con las cuatro grutas.

## FPS del cambio integrado

Mac M2 Pro, Godot 4.7.1, Metal Forward+, 1600 × 900, escala 1, MSAA 0,
LOD 400 m y umbral 0,85, VSync desactivada. Vegetación, sombras, IA, HUD y
oclusión activos. El héroe permanece fijo, con su física desactivada para que
los vecinos no lo desplacen; la vista móvil desplaza la cámara. El sol o la luna
se fijan en fase 1,08 o 4,10 y se repite el reloj del viento.

Una ventana nativa en primer plano, sin otra carga de pruebas, alterna
nuevo/original/original/nuevo en cada vista. Cada tanda calienta cien
fotogramas y mide **240 realmente dibujados**. La tabla muestra la media de dos
tandas por variante; los p95 también se promedian.

| Vista | FPS original | FPS nuevo | Mejora media | p95 original / nuevo |
| --- | ---: | ---: | ---: | ---: |
| Bosque, cámara fija | 48.24 | 49.30 | +2.18 % | 22.55 / 22.10 ms |
| Bosque, cámara en movimiento | 46.82 | 47.92 | +2.35 % | 28.52 / 27.53 ms |
| Villa Robledal | 76.15 | 78.09 | +2.54 % | 15.06 / 14.67 ms |
| Puerto Alba | 64.53 | 67.13 | +4.03 % | 17.15 / 16.61 ms |
| Bosque, noche | 48.05 | 49.11 | +2.22 % | 22.56 / 22.10 ms |
| Tenebroso, día | 61.60 | 67.59 | +9.73 % | 16.61 / 16.72 ms |
| Tenebroso, noche | 61.51 | 67.58 | +9.86 % | 16.57 / 16.78 ms |

La mayor mejora media es **9,86 %** en Tenebroso de noche. Su p95 sigue en torno
a 16,7 ms y sube ligeramente; la subida de FPS medios no acredita una mejora
de todos los fotogramas. **El objetivo general de 100–120 FPS sigue pendiente.**
Estas cifras corresponden a este Mac y a estas vistas, no a Windows ni a
combate sostenido. No se reduce resolución, vegetación, sombras, distancias,
relieve ni geometría visible.

## Calidad y regresiones

Se guardaron **52 capturas** de trece casos: Puerto Alba, Robledal, bosque,
raíces, nieve y Tenebroso de día y noche, además de viento de tormenta. Cada
caso compara original, repetición de control, optimizado y restaurado. Se
inspeccionaron visualmente bosque antes/después, nieve y Tenebroso nocturno.
Las 52 capturas conservan oclusión y exactamente una fuente de sombras
solar/lunar.

La diferencia media RGB optimizado/original queda por debajo de **0,0332 sobre
255**, con p99 máximo de un nivel. No son imágenes idénticas bit a bit: también
hay variación entre controles. En Tenebroso nocturno las luciérnagas dejan un
0,0156 % de píxeles con diferencias mayores de dos niveles, comparable al
0,0152 % del control y al 0,0157 % del restaurado.

Pasan la nueva prueba `terrain_normals_test.gd` con y sin GPU, la oclusión con y
sin GPU, hierba, materiales de árboles, los 12 289 pasos de relevo solar/lunar,
luciérnagas, entradas e interiores de las cuatro grutas. La nueva prueba está
añadida a CI. Se inyectaron **17 defectos**: canales RGBA, mipmaps, formato,
profundidad, cantidad, estructura, valor constante, ruta headless, shader
ajeno, restauración, conservación del shader anterior, actividad continua,
notificación de texturas y confianza de un shader editado. Todos terminan por
su aserto previsto, sin errores de compilación; las fuentes se restauran por
SHA-256.

También pasan anfitrión e invitado ENet reales: combate, combo, recursos,
cuatro grutas, puertas y seis ventanas. Combate y ventanas se repiten con un
invitado gráfico. Es una comprobación local entre dos procesos, no una prueba
WAN con ocho jugadores.

Los datos locales están en `generated/reviews/2026-11-12/normales-terreno/`,
`normales-terreno-integradas/` y `normales-terreno-integradas-calidad/`. Las
sondas se archivan con su fuente y SHA-256 y se retiran de `tools/diagnostics/`.

## Experimentos descartados

Omitir viento y color en raíces de hierba ya descartadas no dio ganancia en
cuatro vistas: las medias variaron entre −0,34 % y −0,02 %. No se incorpora.
El análisis de cortezas encontró superficies abiertas en sus LOD; no se
fuerza el descarte de caras traseras porque podría crear huecos. La variante
que sólo sustituía las lecturas normales ofreció menos mejora que eliminar
también el mapeo de profundidad cero.
