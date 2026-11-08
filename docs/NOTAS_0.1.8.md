# Senderos del Horizonte 0.1.8

- Descarte individual de parches de hierba en Forward+, conservando mallas,
  altura, densidad, color del terreno, materiales, viento y fundidos.
- Límites calculados con los extremos reales del relieve, incluidos picos
  interiores y cruces de región; margen para tormenta, pisadas y ondas.
- Identidades estables, reutilización de instancias y cache de alturas acotado.
  La fuente invisible se actualiza con la última distribución antes de restaurarse.
- En el Apple M2 Pro medido, Puerto y bosque ganan alrededor de un 6 % de FPS.
  La villa gana un 5,8 % con cámara fija y un 3,6 % en movimiento. En esta
  última vista el p95 empeora 0,51 ms: queda trabajo de estabilidad de CPU.
- Prueba de límites y restauración ejecutada en headless y con Metal, más
  comparaciones visuales de día, noche, pendientes y movimiento.

Las cifras corresponden a las cámaras y ajustes documentados. El objetivo de
100–120 FPS sigue pendiente; no son mediciones de Windows. La web del NAS
mantiene el ZIP completo con el ejecutable como descarga principal y el
instalador como alternativa.
