# Puertas de gruta compartidas — 10 de noviembre de 2026

## Fallo reproducido y comportamiento nuevo

Con dos mundos completos conectados por ENet, el invitado tenía la llave de
Raíces y abría su puerta. La del anfitrión seguía cerrada y un rayo físico
continuaba chocando contra ella. El anfitrión no tenía esa llave.

Ahora las cuatro puertas pertenecen al estado del mundo. Un compañero que
lleve la llave puede abrir el acceso para la expedición, aunque el anfitrión
esté lejos y no tenga esa llave. Quien entra después recibe las puertas ya
abiertas, sin necesitar copias de las llaves. Las llaves no se consumen.

El anfitrión valida la identidad de la puerta, la conexión preparada, la
distancia de interacción, el tipo y la cantidad de la llave declarada por su
propietario, y la revisión de la partida. La intención lleva la posición y
el inventario actuales: no espera a la instantánea de guardado de cuatro
segundos. El inventario aceptado se conserva antes de guardar la apertura.
Abrir un acceso provoca el guardado habitual del mundo, si está habilitado.

La posición y el inventario siguen perteneciendo al cliente, como en el
movimiento y el guardado cooperativos existentes. Estas comprobaciones no
son un sistema antitrampas que certifique cómo se consiguió cada objeto.

## Mensajes y restauración

La petición y su confirmación usan un canal fiable del gestor de puertas.
La apertura se notifica de forma fiable a todos los compañeros conectados,
también cuando la inicia el anfitrión. Además se comunica mediante el estado del mundo;
el pulso de cinco estados por segundo permite recuperar un envío perdido e
incorporar invitados nuevos.

Una confirmación fiable puede adelantarse a una instantánea que todavía
mostraba la puerta cerrada. Dentro de la misma revisión se conserva la
apertura; sólo una carga con una revisión nueva permite volver a cerrarla.
Se rechazan estados y peticiones correspondientes a revisiones anteriores.

Las instantáneas repetidas no reinician el movimiento de la puerta ni repiten
sus eventos. Al restaurar una puerta se cancela el tween anterior, se coloca
la hoja en su posición final y se recupera su colisión. Así una animación
pendiente no puede volver a levantar una puerta recién cerrada por la carga.

El gestor nuevo conserva las declaraciones RPC de `NetworkSession`: los RPC
de puertas viven en su propio nodo. Un cliente que todavía no haya recibido
la capacidad del anfitrión muestra un aviso al intentar abrir. Para compartir
las puertas, todos los participantes deben usar esta versión; no se ha
validado una partida completa mezclando versiones.

## Coste medido

Godot 4.7.1, Apple M2 Pro, mundo completo en modo headless. Cuatro tandas de
50.000 llamadas por operación, sin tráfico de red durante la medición:

| Operación sobre las cuatro puertas | Media |
| --- | ---: |
| Construir su estado | 3,09 µs |
| Recibir un estado cerrado sin cambios | 7,75 µs |

El gestor no tiene procesamiento por fotograma ni de física. Los estados se
añaden al pulso cooperativo existente, sin crear otro temporizador.

En la instantánea completa medida, la inclusión de puertas aumenta el estado
de 45.460 a 45.772 bytes sin comprimir y de 4.350 a 4.458 bytes con Zstandard.
Siguen siendo **cinco paquetes**, todos dentro del límite del transporte.
La diferencia es **108 bytes por estado**, aproximadamente 540 bytes/s por
invitado a cinco estados/s, sin contar las cabeceras comunes del protocolo.
Las peticiones y confirmaciones fiables sólo se envían al interactuar.

Esta pasada corrige el cooperativo; no acredita una mejora general de FPS.
El objetivo de 100–120 FPS conservando la calidad sigue pendiente. Se
mantienen los materiales, las mallas, el viento, la hierba y la iluminación.

## Comprobaciones

- `gate_state_test.gd`: rayo físico real, identidad y tipos, repetición de
  instantáneas, cancelación de animación, carga abierta y cerrada, estados de
  revisiones antiguas, orden entre canales y límite de tamaño de la intención.
- `test_cooperative_gate.py`: anfitrión e invitado en procesos Godot completos
  y un tercer proceso que entra después. Abre las cuatro puertas con la
  interacción normal del héroe; comprueba las colisiones en ambos mundos y
  el inventario conservado por el anfitrión. El invitado tardío no lleva llaves.
- Rechazo por ENet de siete intenciones inválidas: sin llave, llave distinta,
  distancia excesiva, posición no finita, tipo de posición incorrecto, puerta
  inexistente y revisión previa a una carga.
- Aísla las confirmaciones fiables desconectando en el invitado el receptor de
  instantáneas del mundo, tanto para abrir desde el anfitrión como desde el
  invitado. Comprueba además el envío inmediato por el transporte real, con el
  pulso periódico temporalmente desactivado. La carga y la incorporación tardía
  conservan la recuperación periódica normal.
- Simula la pérdida de una apertura en el invitado: su nueva petición recupera
  el estado mediante la respuesta individual, sin repetir el evento del anfitrión.
- Cliente gráfico Metal con capturas de las cuatro puertas cerradas y abiertas;
  inspección de la animación y del hueco que permite acceder a cada interior.
- Dieciocho defectos inyectados y detectados mediante fallos de aserto, sin
  depender de errores de compilación: identidad, colisiones, animación,
  tamaño del paquete, revisiones, orden entre canales, estado omitido, llave,
  inventario ajeno, distancia, confirmación individual, aviso fiable al grupo,
  envío inmediato e inventario conservado para guardar. Los fuentes se
  restauran y los controles positivos vuelven a pasar.
- Regresiones de actividad física y disparos en las grutas, recorrido de
  aventura, guardado y menús, combate y tala cooperativos, y conexión UDP real.

Las pruebas nuevas se ejecutan en CI. Las evidencias completas se conservan
localmente en `generated/reviews/2026-11-10/puertas-cooperativas/`, fuera de la
exportación. Las sondas de diagnóstico se archivan y se retiran al terminar.

Las comprobaciones de red se hacen en un mismo equipo. No sustituyen una
prueba de latencia WAN, pérdida de paquetes y ocho máquinas. Las voces,
recuerdos, recompensas y la ruta del ciervo conservan su comportamiento actual;
esta revisión comparte las puertas, no todo el progreso narrativo de la sesión.
