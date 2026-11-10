# Grutas activas para la expedición — 10 de noviembre de 2026

## Dos fallos reproducidos

En 0.1.14 la colisión de cada gruta sólo atendía al héroe local. Con el
anfitrión a **2.658 m** de Raíces y un invitado preparado dentro, un rayo
atravesaba su suelo: capa de colisión **0**. Activar la capa manualmente hacía
que el mismo rayo tocara la gruta. El cliente conservaba su propio suelo, pero
la simulación autoritativa del anfitrión perdía esa roca.

Además, la protección de flechas remotas frente al terreno lejano confundía
el aire de la gruta con tierra. En el mismo punto, el disparo local avanzaba
**3,002 m** en 0,1 s; el remoto se clavaba tras **0,101 m**. El heightmap estaba
19 m por encima del origen y no representa el hueco bajo la bóveda.

## Activación y disparos

La física atiende al héroe local y a los invitados que ya han recibido su
primera muestra de posición. Para cada invitado cuenta tanto la posición
autoritativa como la representación interpolada: una sostiene el combate y
la otra puede ir unos instantes por detrás. Se mantiene el radio de **240 m**
y la comprobación cada **350 ms**. Al marcharse o desconectarse el último
participante, la gruta vuelve a desactivar su capa.

Las luces se comprueban aparte: héroe local o cámara activa próxima. Un
invitado lejano conserva el suelo sin encender las luces para el anfitrión.
Una cámara libre que entra en la gruta conserva su iluminación aunque el
héroe se haya quedado fuera. Hay **seis luces por gruta**: dos antorchas en
la entrada y cuatro interiores, todas sin sombras.

Cuando una flecha remota queda bajo la altura del terreno, una consulta
vertical comprueba si tiene encima la bóveda física de una gruta. En ese
caso sigue usando el barrido normal contra paredes, suelo y objetivos. La
protección del heightmap continúa activa en terreno macizo; no basta con
estar dentro de una caja aproximada de la gruta.

No cambian las mallas, materiales, densidad de hierba, sombras ni alcance
visual. La revisión conserva los circuitos, voces y secretos existentes.

## Mediciones

Apple M2 Pro, Godot 4.7.1. El coste siguiente corresponde al **barrido completo
de las cuatro grutas**, forzando una actualización en cada llamada, no a un
fotograma entero. Cada modalidad tiene dos tandas de 10.000 barridos en orden
ABBA; el máximo de ocho jugadores se representa con siete réplicas reales de
`Player`, sin tráfico de red durante esta medición.

| Participantes | Coste medio nuevo |
| --- | ---: |
| Un jugador lejos | 3,13 µs |
| Ocho jugadores lejos | 12,56 µs |
| Ocho repartidos por las grutas | 6,39 µs |

La consulta nativa de bóveda tarda **2,30 µs** de media en 20.000 llamadas
positivas en Raíces. Sólo se utiliza cuando el disparo remoto quedaría bajo
la cota del heightmap. Estas cifras no miden una sesión WAN de ocho equipos.

Control gráfico separado, Metal Forward+, **1600×900**, escala 1, MSAA 0,
VSync desactivado, LOD a 400 m y umbral 0,85. Sol en 1,08 radianes, sombras
activas. IA, animación y HUD siguen funcionando; el héroe no camina. En el
bosque se desplaza la cámara. Por zona, ABBA con 100 fotogramas de calentamiento
y 240 medidos por tanda; se comprueba que los 240 se dibujen realmente.
Se alterna el callback anterior y el nuevo en el mismo mundo, sin otros
procesos de pruebas pesadas simultáneos.

| Zona | FPS anteriores | FPS nuevos |
| --- | ---: | ---: |
| Puerto Alba | 62,58 | 62,72 |
| Villa | 76,85 | 76,89 |
| Bosque en movimiento | 46,47 | 46,52 |

Las diferencias quedan dentro del ruido del banco: **no es una mejora general
de FPS**. Los 100–120 FPS siguen pendientes. Esta pasada evita errores físicos
del cooperativo con un coste pequeño y mantiene la calidad existente.

## Comprobaciones y límites

- `cave_activity_test.gd`: cuatro grutas reales, rayos y cápsulas sobre el
  suelo, réplica todavía sin muestra, posición autoritativa distinta de la
  visible, cámara libre, salida y desconexión. Compara la trayectoria local y
  remota hasta el impacto contra roca. Comprueba terreno exterior real y una
  cota de terreno controlada sobre cada bóveda nativa, para que esa protección
  se pruebe incluso donde la ladera real queda más baja.
- `test_cooperative_combat.py`: dos procesos completos por ENet. El invitado
  entra en las cuatro grutas, apunta, tensa y dispara con el arco del juego.
  El anfitrión permanece lejos, confirma cuatro impactos de tres puntos,
  suelo presente y luces apagadas; al salir se comprueba la desactivación.
  Conserva también las pruebas anteriores de combate, tala y restauración.
- Se inyectan once defectos: activación sólo local, réplicas sin muestra,
  pérdida de cualquiera de las dos posiciones, luces remotas, cámara ignorada,
  colisión siempre activa y dos errores de protección del terreno. Los dos
  fallos originales se repiten también entre procesos reales.
- Capturas Metal de las cuatro paletas y la entrada, incluidas vistas antes y
  después de la activación por cámara. La iluminación del héroe al explorar
  mantiene los parámetros existentes.

La prueba de red usa dos procesos en el mismo equipo; no valida latencia WAN,
pérdida de paquetes ni ocho máquinas. Tampoco añade autoridad compartida de
llaves, voces, recuerdos o recompensas: su sincronización durante la sesión
sigue pendiente. Esos datos se conservan en el guardado del mundo.

Las sondas, sus fuentes retiradas y los datos completos quedan en la carpeta
local ignorada `generated/reviews/2026-11-10/grutas-cooperativas/`; no se exportan
con el juego. La prueba nueva se ejecuta también en la compilación de CI.
