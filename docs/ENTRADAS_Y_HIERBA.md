# Entrada de piedra y briznas lejanas — 8 de noviembre de 2026

## Causas y corrección

El azul de la entrada procedía de aberturas hacia el exterior. El arco estaba
separado del comienzo de la gruta horneada y el recorte del terreno era más
ancho que el pasadizo. Además, las cámaras creadas después de iniciar el mundo
no actualizaban la cámara que seguía Terrain3D. Esto podía dejar el detalle del
terreno lejos del observador y ampliar los huecos visibles.

`world.gd` sincroniza la cámara activa con Terrain3D cuando cambia. Se usa la
API `set_camera`, verificada en el complemento instalado; véase también la
[documentación de cámara de Terrain3D](https://terrain3d.readthedocs.io/en/stable/api/class_terrain3d.html#class-terrain3d-method-set-camera).

La portada está unida a un vestíbulo de piedra con paredes, bóveda y colisión
continuas hasta el interior. El volumen de cierre incluye margen para las
celdas del terreno, cuyos vértices están separados 4,6875 m. El relieve exterior
es Terrain3D, con su colisión y su hierba. Se conserva el terreno situado encima
de la bóveda y se retiran las celdas que cruzan la zona de paso. La máscara de
vegetación distingue la cubierta del pavimento inferior. Un remate de roca
maciza sigue las alturas del terreno alrededor del recorte y cierra la
diferencia entre su borde renderizado y el mapa de controles. Dos antorchas sin
sombras acompañan la portada y se apagan por distancia junto a las otras luces.

La hierba lejana compensaba la reducción de densidad multiplicando el ancho
hasta cinco veces. El modelo lejano podía llegar a 3,4 m de ancho antes de la
escala del parche. Ahora los tres anchos máximos, incluido el ensanche, son
0,117 / 0,1215 / 0,1495 m antes de escala. La altura y las 12.000 briznas del
parche cercano se conservan; el relevo se desplaza de 12–22 a 16–28 m.

## Medición de la hierba

Control A/B de mallas y parámetros vegetales con el mismo mundo, terreno y
cámara correcta. M2 Pro, Metal Forward+, 1600×900, escala 3D 1, MSAA 0, TAA
desactivado, sin VSync ni límite de FPS. Orden anterior/nuevo/nuevo/anterior,
180 fotogramas tras 75 de calentamiento. La ventana de precarga de 44 m es
común a ambos controles. No es una comparación del ejecutable antiguo entero.

| Vista | FPS del control | FPS nuevos | p95 del control | p95 nuevo |
| --- | ---: | ---: | ---: | ---: |
| Claro con casas | 72,35 | 70,38 | 15,83 ms | 16,23 ms |
| Villa | 66,15 | 65,59 | 17,02 ms | 17,16 ms |
| Entrada | 58,75 | 57,73 | 17,29 ms | 17,70 ms |

Extender el detalle cercano tiene un coste pequeño en estas vistas: alrededor
de 0,1–0,4 ms de p95. Esta pasada corrige el aspecto; no se presenta como una
ganancia de FPS. El objetivo de 100–120 FPS continúa pendiente. Las mediciones
anteriores con otra cámara de terreno no se mezclan con estas.

## Verificación

`cave_entrance_test.gd` comprueba las cuatro bocas, la cubierta y 24 rayos
laterales que deben chocar con piedra. También verifica el seguimiento de una
cámara nueva. Está incluido en el workflow de Windows. `wonders_test.gd`
recorre las cuatro grutas, sus secretos y el regreso sin saltar.

`vegetation_test.gd` comprueba los anchos de las mallas reales, el límite de
ensanche, la distancia de relevo y los contratos de densidad, altura y villas.
`act_cinematic_test.gd` comprueba que el terreno toma la cámara de la cinemática
y recupera la de juego al terminar.

Se inyectaron tres defectos: retirar la colisión del vestíbulo, recuperar la
anchura anterior de las briznas medias y omitir la sincronización de cámara.
Las tres pruebas fallaron como correspondía y las fuentes se restauraron.
Los resultados y capturas se guardan en
`generated/reviews/2026-11-08/entrada/`.
