# Laderas como oclusores — 0.1.11

El terreno de la isla participa ahora en la oclusión nativa de Godot. Una
ladera puede retirar del render objetos completamente tapados por ella. Se
mantienen las mallas, materiales, distancias, densidad y altura de la hierba,
el viento y las sombras configuradas.

## Geometría y carga

`oclusion_terreno.gd` carga un `ArrayOccluder3D` de **49.856 triángulos**,
horneado con el filtro mínimo de
[Terrain3D.bake_mesh](https://terrain3d.readthedocs.io/en/stable/api/class_terrain3d.html#class-terrain3d-method-bake-mesh).
El plano de cada triángulo se comprueba contra todas las muestras de altura
de su huella y se baja cuando cruza una depresión. Se añaden dos metros de
margen bajo el suelo. Los agujeros excluyen su celda y las vecinas; también
se rechazan los bordes sin región y las alturas no finitas.

El recurso se prepara **después de esculpir las cuatro grutas**. Esa
construcción es diferida: validar durante `_ready` del mundo usaría todavía
la isla sin accesos. `RPGStoryRuntime.terreno_preparado` marca el momento de
enlazarlo. Se comprueban las alturas y controles completos, coordenadas de
regiones, versión y configuración de malla mediante SHA-256.

La firma ordena una copia de las ubicaciones. El array devuelto por Terrain3D
comparte su almacenamiento nativo: ordenarlo directamente cambia los índices
de regiones sin cambiar sus capas de textura. La prueba detecta ese defecto.

Hornear tarda unos **10,4 s** en este M2 Pro y se hace fuera del juego. El
recurso comprimido ocupa aproximadamente **661 KiB**. Su validación inicial
ronda **160 ms**. No se añade un callback de proceso ni de física. El coste
nativo de oclusión sí está incluido en las mediciones de FPS.

Una modificación de mapas, regiones, material asignado o visibilidad del
terreno retira el oclusor inmediatamente. Un cache que no coincide conserva
la representación anterior del juego. Los shaders de desplazamiento
desconocidos y la teselación no se admiten. Headless y otros renderizadores
conservan la ruta anterior.

Para regenerar tras cambiar alturas, agujeros o grutas:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /private/tmp/senderos-horneado.log \
  --script res://tools/hornear_oclusion_terreno.gd
```

## Medición

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 3D 1, MSAA 0,
LOD común 400 m, VSync desactivado y sin límite de FPS. Fase solar 1,08
aplicada y comprobada. Héroe detenido; IA, animaciones y HUD activos.

Las cámaras y la órbita de 12×8 m son las de
[la revisión anterior del bosque](OCLUSION_BOSQUE.md). Se alterna
original/nuevo/nuevo/original: 100 fotogramas de calentamiento y 240 medidos
por tanda. Se comprueba que se dibujan todos los fotogramas. No se leen
imágenes durante la medición. Las cifras son medias de dos tandas por modo.

| Vista | FPS antes | FPS después | Cambio | p95 antes | p95 después |
| --- | ---: | ---: | ---: | ---: | ---: |
| Tenebroso, fija | 56,62 | 61,15 | +8,0 % | 19,267 ms | 16,739 ms |
| Tenebroso, movimiento | 56,80 | 62,41 | +9,9 % | 22,858 ms | 18,198 ms |
| Puerto, fija | 57,15 | 62,50 | +9,4 % | 18,328 ms | 16,489 ms |
| Puerto, movimiento | 56,87 | 61,21 | +7,6 % | 19,412 ms | 17,704 ms |
| Villa, movimiento | 69,96 | 74,19 | +6,0 % | 17,474 ms | 16,648 ms |
| Bosque verde, movimiento | 45,29 | 45,46 | +0,4 % | 28,540 ms | 28,355 ms |

Son resultados de estas cámaras del Mac; no son FPS de Windows. El bosque
verde sigue siendo una prioridad y el objetivo general de 100–120 FPS
continúa pendiente. Esta oclusión usa el terreno; los huecos móviles entre
hojas siguen requiriendo otra solución.

## Imagen y comprobaciones

Se comparan 48 vistas: diez posiciones exteriores de día y noche, tres
cámaras de cada gruta en ambas fases y cuatro controles adicionales con
tormenta máxima. Se congelan actores, partículas y tiempo de los shaders;
se compara original/control/nuevo con 70 fotogramas de calentamiento.
La guardia comprueba también los fotogramas realmente dibujados.

La mayor diferencia media nueva es **0,02518 RGB sobre 255**, frente a
0,02587 del control. El p99 máximo es 1. Hay diferencias puntuales:
hasta 62 en un canal y 71 píxeles por encima de 10 en una imagen de
1.440.000 píxeles. Las imágenes no son idénticas. Se inspeccionaron el
contacto de las 48 vistas y comparaciones de exteriores, portadas e
interiores: conservan las siluetas, las superficies y las sombras observadas.

`terrain_occlusion_test.gd` comprueba depresiones entre muestras LOD,
agujeros interiores, bordes ausentes, coordenadas negativas, margen,
inmutabilidad del orden de regiones, firma, invalidación y ausencia de
callbacks continuos. También valida el recurso publicado contra el mundo
con las cuatro grutas. Pasa en ARM y x86 headless y en Metal; este último
comprueba además la activación desde la ruta gráfica del mundo.

Siete defectos reales producen fallos: admitir agujeros, saltar la protección
de regiones, ignorar depresiones, eliminar el margen, aceptar firmas antiguas,
conservar el oclusor tras editar alturas y ordenar el array nativo. La fuente
restaurada vuelve a pasar. La prueba forma parte del workflow de Windows.

Pasan también vegetación completa, entradas, voces, secretos, regreso de
las cuatro grutas sin saltar, guía nocturno y recompensas persistentes.
El combate cooperativo pasa sus 17 etapas con dos procesos ENet reales,
sin advertencias de MTU.

Medidas, imágenes y defectos inyectados quedan en
`generated/reviews/2026-11-09/`. Los ensayos iniciales con geometría plana
y las capturas con una posición incorrecta del personaje se guardan como
descartados; no se usan como verificación final. Las sondas se retiran al
terminar.
