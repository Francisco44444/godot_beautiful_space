# Armas y combo — 12 de noviembre de 2026

- [x] Espada con el filo orientado hacia fuera.
- [x] Hacha y antorcha sujetas al descansar y caminar.
- [x] Tajo al pulsar y combo de tres golpes con clics sucesivos.

## Agarre y transiciones

La orientación se corrige al equipar con un cuarto de vuelta sobre el eje largo;
no añade un corrector por fotograma. El giro no altera el porte longitudinal ni
la estabilización de la muñeca al caminar. La antorcha conserva su vertical y el
gesto de linterna en reposo.

Había tres problemas adicionales: se colocaba el mango con la escala del objeto
anterior; las transiciones perdían la corrección de escala de las piezas
medievales; sus mangos no estaban en el mismo origen de exportación. Ahora cada
pieza conserva escala y punto de empuñadura en la mano, al pasar a la espalda y
al desenvainar. La claymore ya no se sujeta bajo el pomo, y el hacha guardada no
crece hasta el suelo.

Diez piezas comprobadas, incluyendo las variantes de ambos packs. Las 48 poses
de espada, hacha y antorcha en los ocho héroes conservan el mango a menos de
0,002 m del agarre; máximo medido **0,000000030 m**. El producto escalar del filo
hacia delante queda por encima de **0,887**; la antorcha se mantiene vertical.

## Clics y remate

El tajo empieza al pulsar, sin pasar por carga ni esperar a soltar. Se guardan
hasta dos clics anticipados para completar A → B → C durante la animación. Un clic durante el envainado espera el viaje
y desenvaina para golpear. Los
clics excedentes no dejan una fila ilimitada de golpes. Tras una pausa vuelve
A; abrir una ventana, cambiar de equipo o ponerse en guardia descarta la entrada
pendiente.

Mantener el botón conserva la fuerza especial: primero sale el tajo y, al
terminar su recuperación y seguir pulsando, empieza la carga. Soltar una carga
completa ejecuta el giro. Los clics breves no levantan restos, viento ni
oscurecen el cielo.

El remate C estaba excluido porque heredaba el giro de la pelvis del esqueleto
fuente mientras las piernas del héroe seguían mirando al frente. La misma
revisión detectó el giro heredado en A y B. Ahora se elimina en los
tres tajos en modo de tren superior. Se comprueban **504 poses procesadas**,
21 por tajo y héroe, con las piernas caminando y un giro relativo máximo de
**31,45°**. Se comprueba durante `modification_processed`, como
requiere [la documentación de Godot](https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html#signals): fuera de esa señal se lee la pose
restaurada y el aserto no detectaría el defecto.

## Cooperativo y comprobaciones

El ensayo ENet descubrió que una carga confirmada podía llegar mientras la
réplica terminaba el tajo anterior. Ahora la siguiente acción autorizada
sustituye esa recuperación visual; la validación de cadencia del anfitrión se
conserva. Los tres tajos se representan en ambos sentidos, con dos procesos
reales. También pasan las seis ventanas, cancelación de carga/arco/guardia,
daño autoritativo, giro, flechas, recursos y las cuatro grutas. El último ensayo
con invitado Metal mantiene un error de posición asentada inferior a 0,000261 m
en este recorrido local.

Pruebas nuevas en CI: `weapon_grip_test.gd`, `melee_input_test.gd`,
`slash_retarget_test.gd` y `combat_animation_handoff_test.gd`. Se mantienen las
comprobaciones físicas y visuales de `weapon_system_test.gd`,
`medieval_combat_test.gd` y `hero_moves_test.gd`; las pruebas de carga esperan
ahora el tajo inicial antes de medir la misma postura y tormenta.

Se reintrodujeron doce defectos en la entrada, el combo, los agarres, la escala,
el remate y el relevo remoto: todos terminaron por su aserto previsto, sin
errores de compilación, y las fuentes se restauraron con el mismo SHA-256.
La duodécima inyección aísla el giro de B con el contrato ampliado.
La ampliación de las pruebas reprodujo además la torsión de A y el clic
perdido durante el envainado antes de aplicar sus correcciones.

Capturas Metal de 1600 × 900: 30 antes y 30 después para los agarres; 52 para los
tres tajos y el remate en los ocho héroes. Datos y registros locales en
`generated/reviews/2026-11-12/armas/`. Las sondas están archivadas y retiradas.

## Control de FPS

Mac M2 Pro, Godot 4.7.1 Metal Forward+, 1600 × 900, escala 1, MSAA 0,
LOD 400 m, VSync desactivada, sombras y mundo completo. Jugador, IA, HUD y
animaciones activos; sol fijo en fase 1,08 y reloj de viento repetido.
Cuatro procesos nativos separados, orden anterior/nuevo/nuevo/anterior;
100 fotogramas de calentamiento y 240 realmente dibujados por vista y tanda.
Se comparan las cinco fuentes cambiadas frente a 0.1.19.

| Vista | FPS 0.1.19 | FPS nuevos | p95 anterior / nuevo |
| --- | ---: | ---: | ---: |
| Bosque, fija | 48.77 | 48.75 | 22.26 / 22.31 ms |
| Bosque, en movimiento | 47.95 | 47.63 | 27.43 / 27.67 ms |
| Robledal | 77.81 | 77.71 | 14.77 / 14.82 ms |
| Tenebroso | 61.57 | 61.66 | 16.64 / 16.61 ms |

Son medias de dos tandas por versión, también para los p95. El mayor descenso
medio queda en el recorrido del bosque, por debajo de un 0,7 %. Este control
no representa combate sostenido ni una medición de Windows.

Este cambio corrige el combate y sus poses. No acredita una mejora general de
FPS; el objetivo de 100–120 FPS sigue pendiente. No cambia hierba, sombras,
resolución ni distancias de dibujo. Las pruebas de red son locales entre dos
procesos: no sustituyen una validación WAN con ocho jugadores.
