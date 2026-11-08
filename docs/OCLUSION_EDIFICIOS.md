# Oclusión de las viviendas — 8 de noviembre de 2026

El mundo no tenía oclusores y el descarte por oclusión estaba desactivado,
comprobado durante la ejecución de 0.1.8. Ahora las 107 viviendas ensambladas
aportan sus caras opacas estáticas al sistema nativo de Godot. Los edificios
pueden ocultar instancias que quedan completamente detrás de ellos.

Se toma como referencia técnica el filtrado de geometría opaca de Vigo,
sin trasladar su estilo visual. La implementación usa
[ArrayOccluder3D](https://docs.godotengine.org/en/stable/classes/class_arrayoccluder3d.html)
y el [descarte por oclusión de Godot](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

## Geometría y coste

`BuildingAssembler` marca paredes, cubierta, escaleras y baldosas estáticas.
`oclusion_edificios.gd` conserva sus triángulos originales de al menos 0,4 m²
locales; omitir las caras pequeñas reduce cobertura y resulta conservador.
No sustituye la vivienda por una caja: puertas, ventanas y huecos del forjado
permanecen abiertos. Las poses de las baldosas salen del mismo productor que
sube las matrices al MultiMesh. La composición se hace en coordenadas locales,
antes de aplicar la posición, giro y escala de cada vivienda.

Se rechazan materiales transparentes, de una sola cara, con fundido, billboard,
proximity fade o grow, shaders desconocidos, sobrescrituras por instancia,
geometría animada y piezas con distancia de desaparición. Sólo entran piezas
marcadas en la capa principal. La decoración y los castillos montados por la
ruta antigua quedan fuera. El oclusor es hijo de la casa y hereda su visibilidad.
El contrato actual es de estructura estática: no se hornean puertas móviles.

El resultado contiene 181.772 triángulos en 107 oclusores. Se construye una
sola vez, después de ajustar las casas al terreno. En la ejecución de rendimiento,
la preparación en GDScript tarda 153,717 ms y usa 31 entradas de cache de malla.
Esta cifra no incluye la construcción interna del BVH del motor ni mide toda
la carga inicial. El auxiliar no añade callbacks por fotograma. Headless omite
la construcción automática de oclusores.

## Medición del mundo completo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 3D 1, MSAA 0,
LOD común 400 m, VSync desactivado y sin límite de FPS. Se conserva la hierba
por parches de 0.1.8. Cámara de 62°, sincronizada con Terrain3D; fase solar
1,08 aplicada y comprobada antes de detener el ciclo. Héroe detenido;
IA, animaciones y HUD activos durante las mediciones.

Se alterna sin/con/con/sin oclusión sobre el mismo mundo, con 80 fotogramas
de calentamiento y 240 medidos por tanda. La cámara de la villa también recorre
una órbita de 12×8 m y oscila 0,7 m en altura. Las cifras son las medias de dos
tandas por modo; los percentiles corresponden a tiempos reales de fotograma.

| Vista | FPS sin | FPS con | Cambio | p95 sin | p95 con |
| --- | ---: | ---: | ---: | ---: | ---: |
| Puerto, fija | 56,80 | 56,80 | 0,0 % | 18,960 ms | 18,926 ms |
| Villa, fija | 69,86 | 71,66 | +2,6 % | 16,132 ms | 15,812 ms |
| Villa, movimiento | 66,90 | 70,48 | +5,4 % | 17,950 ms | 17,286 ms |
| Bosque, fija | 45,81 | 45,83 | +0,04 % | 23,764 ms | 23,695 ms |
| Umbral | 80,82 | 97,34 | +20,4 % | 14,319 ms | 12,328 ms |
| Interior | 94,61 | 125,72 | +32,9 % | 12,915 ms | 9,444 ms |
| Ventana | 85,97 | 97,75 | +13,7 % | 13,675 ms | 12,258 ms |

La mejora se concentra donde las casas ocultan geometría. Puerto y bosque no
presentan una mejora significativa con esta técnica. El p99 del bosque varía
de 24,090 a 24,152 ms; estas medidas no demuestran una mejora uniforme de todos
los fotogramas. Alcanzar 100–120 FPS en todo el recorrido sigue pendiente.
No se extrapolan los resultados de este Mac a Windows.

## Imagen y comprobaciones

Se comparan 16 vistas de día y noche: Puerto, Villa, bosque, umbral, interior,
ventana y dos escaleras. Se detienen actores, animaciones, modificadores de
esqueleto y tiempo de los shaders; se oculta el HUD para que su contador de FPS
no altere la comparación. Dos controles sin oclusión coinciden exactamente en
las 16 vistas. Con oclusión, el mayor cambio RGB medio es 0,001506 sobre 255,
con percentil 99 igual a cero. No son imágenes idénticas: hay variaciones pequeñas
de iluminación en algunos bordes de tejados, con un máximo puntual de 62.

También se comparan 36 posiciones al atravesar una puerta, acercarse a una
ventana y subir dos escaleras. Los controles presentan variación temporal de
hasta tres por canal. El mayor cambio RGB medio con oclusión es 0,009247 sobre
255 y el percentil 99 máximo es cero. Un destello aislado alcanza 237 en un
canal. Se inspeccionaron imágenes contiguas y ampliaciones de los bordes:
se conservan las siluetas y las vistas a través de los huecos, sin desapariciones
amplias de geometría en estos recorridos.

`building_occlusion_test.gd` comprueba huecos reales, baldosas separadas por
una escalera, composición local, transparencia, cache, capas, visibilidad,
marcado estático e idempotencia. Se ejecuta en headless y Metal; este último
verifica las matrices reales del MultiMesh, que el backend dummy no devuelve.
Nueve defectos introducidos en las fuentes provocan sus fallos esperados,
incluida una subida errónea de matrices detectada con Metal. Restaurado el
código, pasan ambas rutas. La prueba se incluye en el workflow de Windows.

Pasan además el solver, la medición de edificios montados, la vegetación
completa, 58 puertas recorridas en ambos sentidos y 18 tramos de escalera
subidos y bajados sin saltar. El combate cooperativo completa sus 17 etapas
entre dos procesos reales por ENet.

Los datos de prototipos, la medición definitiva y las poses de cámara se guardan
en `generated/reviews/2026-11-08/oclusion/`. Las sondas se retiran al finalizar.
