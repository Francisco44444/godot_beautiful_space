# Senderos del Horizonte 0.1.17

- Las cuatro puertas de gruta se abren para toda la expedición cuando un
  compañero usa su propia llave. Los invitados nuevos recuperan los accesos
  abiertos, con su colisión correcta.
- Confirmación fiable de las aperturas y protección frente a estados
  retrasados y peticiones anteriores a una carga de partida.
- Restaurar una puerta cancela su animación anterior; los estados repetidos
  conservan el movimiento de apertura y sus eventos.
- Comprobación con procesos ENet reales, cliente gráfico Metal y controles de
  colisión, inventario y mensajes inválidos.

El gestor no añade procesamiento por fotograma. En el mundo medido, las cuatro
puertas suman 108 bytes comprimidos por estado; conservan los cinco paquetes
del transporte. Esta revisión mejora el cooperativo, sin acreditar una subida
general de FPS. Los 100–120 FPS siguen siendo un objetivo pendiente.

[Mediciones, pruebas y límites](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.17/docs/PUERTAS_EN_COOPERATIVO.md).
El ZIP completo con el .exe continúa como descarga principal de la web;
el instalador permanece como alternativa.
