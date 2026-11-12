# Menús durante la expedición — 12 de noviembre de 2026

## El bloqueo reproducido

En 0.1.18, leer una memoria, abrir el inventario, el diario, los ajustes, el
vestíbulo o el menú pausaba el árbol del juego. En el anfitrión eso detenía
también la física, la IA y la presentación de los compañeros. La sesión ENet
seguía enviando paquetes desde su singleton, pero la simulación estaba parada.

La prueba inicial falla realmente al abrir un diálogo en modo anfitrión.
La corrección conserva la pausa en solitario y mientras se conecta; una
sesión anfitrión o invitado mantiene activa la expedición.

## Control local y continuidad

Las seis ventanas comparten una decisión de pausa. Cerrar una no libera los
controles si otra sigue abierta. Crear o abandonar una sesión actualiza esa
decisión con la ventana abierta. El menú distingue «MENÚ DE PAUSA» de «MENÚ
DE EXPEDICIÓN» e indica que la expedición continúa.

Se bloquean las entradas del héroe y la montura locales. La gravedad, los
impactos, los gestos ya iniciados y las animaciones continúan. Abrir una
ventana cancela el arco tensado y la carga pendiente sin gastar flechas;
el clic o Espacio que la cierra no se transforma en una nueva acción.
Los atajos de equipo, viaje, cámara y llamada del caballo quedan protegidos.
El equipamiento sigue pudiéndose cambiar con las casillas del inventario.

No se añaden gestores con actividad por fotograma ni un protocolo de interfaz,
y su estado no se guarda. Las cancelaciones utilizan las acciones fiables de
combate existentes. El cambio usa las señales de las ventanas y la
sesión, más una comprobación de entrada en los controladores existentes.
No modifica las mallas, hierba, luces, sombras, resolución o distancias.

## Comprobaciones

`modal_pause_test.gd` comprueba las seis ventanas en modo individual,
anfitrión e invitado; ventanas superpuestas; inicio y fin de sesión; teclas,
gravedad, montura, cargas y clic de cierre. Con Metal prueba también que la
cámara no gire detrás de una ventana. Se incluye en el workflow de Windows.

Veintidós defectos deliberados fallan con el aserto esperado, incluyendo
pausa global, pérdida de pausa individual, bloqueo local omitido, ventanas
superpuestas, cambios de sesión, gravedad detenida, atajos, cámara, cargas,
guardia, clic de cierre y una cancelación de carga que no se enviaba al otro
proceso. Se restauran los fuentes y el control completo con
Metal vuelve a pasar. El atajo H se reprodujo además antes de corregirlo:
llamaba a Brisa desde el inventario.

`test_cooperative_ui.py` abre dos mundos reales por ENet. Cada una de las
seis ventanas se abre primero en el anfitrión y después en el invitado.
El otro jugador camina mediante las entradas normales, se comprueba la
presentación de su réplica, el avance del reloj y los pasos de física.
La referencia de posición se toma tras frenar, para no confundir la inercia
del personaje con un error de réplica. También comprueba volver a solitario
con el inventario abierto. El recorrido forma parte del workflow de Windows.

Además, se tensan el arco, la carga y la guardia en ambos jugadores y se
comprueba que abrir el inventario los cancele en su réplica remota. Omitir
el envío de reposo hace fallar el control ENet; restaurarlo vuelve a pasar.
En la pasada gráfica final se registran entre 54 y 68 pasos de física del anfitrión
durante cada intervalo de observación; el invitado registra entre 85 y 89.
Son intervalos de duración distinta. Tras frenar, el mayor error plano entre
la posición observada y su réplica es inferior a 0,000147 m en esta prueba local.

Las pruebas gráficas guardan seis capturas del cliente Metal. Las cifras de
su contador no se usan como banco de FPS: se están ejecutando dos procesos
y se fuerzan capturas para revisar las ventanas.

## FPS con las ventanas cerradas

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 1, MSAA 0,
VSync 0 y LOD de 400 m con umbral 0,85. Una sola instancia gráfica en primer
plano. Héroe con física activa, quieto y protegido del daño; IA, HUD y
animaciones activos. Fase solar 1,08 fija y sombras activas. El viento de
árboles y hierba repite el mismo reloj por fotograma en ambos programas.

Se ejecutan las seis fuentes de 0.1.18 y las nuevas, en procesos completos
separados: nuevo/anterior/anterior/nuevo. Cada vista calienta 100 fotogramas
y mide 240 realmente dibujados. La cámara móvil recorre una elipse de
12×8 m con oscilación vertical de 0,7 m. Las fuentes se restauran por hash.

| Vista | FPS 0.1.18 | FPS nuevos | p95 anterior / nuevo |
| --- | ---: | ---: | ---: |
| Bosque, fija | 45,11 | 45,68 | 24,78 / 24,58 ms |
| Bosque, movimiento | 41,17 | 43,42 | 33,73 / 31,13 ms |
| Villa Robledal, fija | 67,90 | 68,84 | 17,43 / 17,13 ms |
| Tenebroso, fija | 54,98 | 55,28 | 20,13 / 20,78 ms |

No se acredita una mejora general de FPS. La serie preliminar en orden
inverso tenía diferencias de signo opuesto y variación entre sus controles;
se conserva aparte. La versión final evita una asignación y una variable
temporal en cada paso normal de física. Esta tabla describe el Mac y estas
vistas, sin extrapolar a Windows ni atribuir una ganancia estable al control
de entrada. El objetivo de 100–120 FPS sigue pendiente.

Pasan también guardado e interfaz individual, armas, gestos del héroe,
aventura y grutas, combate y puertas por ENet, luciérnagas y relevo solar/lunar.

Las mediciones, controles, registros y fuentes de las sondas retiradas quedan
en `generated/reviews/2026-11-12/menus-cooperativos/`, fuera del juego exportado.
Las pruebas ENet son locales; no acreditan una conexión WAN con ocho equipos.
El progreso narrativo compartido del ciervo y las memorias sigue pendiente.
