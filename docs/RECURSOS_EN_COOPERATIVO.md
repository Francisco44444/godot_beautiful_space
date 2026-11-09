# Recursos cooperativos sin restauraciones repetidas — 0.1.13

Cada instantánea del mundo recibida por el invitado llamaba a
`apply_save_state` en vegetación y aventura. Ocurría a 5 Hz, aunque no hubiera
cambiado ningún recurso. La vegetación reconstruía la colisión unificada del
bosque y la ventana de troncos, restauraba recursos, borraba daño parcial y
cancelaba animaciones de golpes y caídas.

La recepción usa ahora `apply_network_resource_state`: normaliza los ids
destruidos y aplica únicamente las altas y restauraciones. Un lote de cambios
reconstruye la colisión una vez; repetirlo no vuelve a tocar matrices,
colisiones ni tocones. El orden y los ids repetidos no cambian el resultado.
Los recursos ajenos al cambio conservan su daño y animación. Una confirmación
que coincide con la tala local mantiene la caída que ya está en curso.

Una restauración autoritativa cancela la animación pendiente de ese recurso.
Las roturas de misión se registran para impedir que su callback oculte después
un árbol restaurado o produzca botín. Los árboles y vetas restaurados recuperan
sus tres puntos de salud. Cargar una partida conserva la restauración completa
y cancela las roturas pendientes, incluso si sus ids coinciden con el mundo.

La frecuencia, los paquetes completos y la validación autoritativa de
herramienta y distancia se conservan. No cambia la geometría, vegetación,
materiales, resolución ni iluminación del juego.

## Coste de reaplicar el mismo estado

Mundo completo, Apple M2 Pro, Godot 4.7.1. Tres llamadas de calentamiento y
100 medidas por sistema, con la lista de destrucciones inicialmente vacía:

| Operación aislada | Restauración completa | Actualización de red |
|---|---:|---:|
| Vegetación, media | 40,692 ms | 0,00044 ms |
| Vegetación, p95 | 40,905 ms | 0,001 ms |
| Aventura, media | 0,120 ms | 0,00043 ms |

Se registran 63.477 entradas de árboles cosechables, 101 recursos ambientales
y 115 recursos de aventura en este arranque. La prueba comprueba también que
se conservan el daño parcial y el Tween del golpe. Son llamadas sin cambios:
una destrucción o restauración real puede seguir requiriendo reconstruir la
colisión del bosque. Ese coste puntual y las listas de destrucciones muy
grandes requieren trabajo posterior.

## Fotogramas del receptor

Se reproducen instantáneas completas del mundo a 5 Hz dentro de una sola
ventana de cliente. Se alternan restauración completa/nuevo/nuevo/restauración
completa, con 100 fotogramas de calentamiento y 240 medidos por tanda. Los
240 se comprueban como dibujados. La función de control reproduce el receptor
anterior; se mantienen los demás sistemas del mundo en modo invitado.

Metal Forward+, 1600×900, escala 3D 1, MSAA 0, VSync desactivado, sin límite
de FPS, LOD común 400 m y umbral 0,85. Sol en fase 1,08 comprobada, sombras
activas. Cámara de 62° a (7; 3,6; 9) del héroe, mirando hacia (0; 1,2; −10),
enlazada con Terrain3D. En bosque se usa la órbita de 12×8 m y oscilación
vertical de 0,7 m. No se leen imágenes durante las muestras.

| Cámara | FPS control | FPS nuevo | p95 control | p95 nuevo |
|---|---:|---:|---:|---:|
| Puerto, fija | 52,27 | 63,67 | 58,54 ms | 16,39 ms |
| Villa, fija | 61,17 | 76,87 | 56,20 ms | 13,82 ms |
| Bosque verde, movimiento | 38,37 | 46,56 | 67,81 ms | 27,05 ms |

La llamada completa al receptor pasa de 42,87–43,86 ms a 0,64–0,70 ms de
media, incluyendo clima, fauna y enemigos. Esta reproducción aísla el coste
del receptor: no mide latencia de Internet ni FPS de Windows. Las cifras
corresponden al invitado con estos estados y cámaras; el objetivo general de
100–120 FPS sigue pendiente.

## Comprobaciones

`resource_replication_test.gd` carga el mundo y entrega los estados por la
señal real de sesión. Comprueba daño parcial, animaciones, cambios
independientes por id, orden, duplicados, ids desconocidos, tocones,
reconstrucciones por lote y las caras retiradas de la colisión nativa. En
Metal verifica las matrices ocultas y restauradas de árboles y recursos.
También prueba la caída confirmada, la corrección antes de producir botín y
que la carga de partida siga restableciendo el mundo completo.

La prueba cooperativa de combate añade una tala con **tres golpes**, dejando
que lleguen al menos dos estados del mundo entre golpes. Usa dos procesos
ENet con el mundo real, hacha, petición fiable, validación del anfitrión,
caída, tocón y restauración compartida. El ejecutor exige las marcas de ambos
procesos y rechaza errores de script y advertencias de MTU. La misma prueba
puede ejecutarse con cliente gráfico y capturas mediante
`--capture-resources`. Las dos comprobaciones forman parte de Windows CI.

Se inspeccionaron cuatro capturas de un cliente Metal conectado al anfitrión:
antes de talar, caída, tocón y árbol restaurado. En esa pasada llegaron dos,
dos y tres estados completos después de los tres golpes, respectivamente.

Se inyectaron seis defectos: receptor anterior, colisión sin actualizar,
tocón sin retirar, callback tardío sin cancelar, carga incompleta y
restauración de matrices omitida. Los seis fallan en el punto previsto; el
último requiere Metal. Reintroducir el receptor anterior también hace fallar
la prueba ENet real porque las instantáneas borran el daño parcial. Las
fuentes se restauran después de cada inyección.

La pasada local final vuelve a pasar recursos en headless y Metal, aventura,
guardado e interfaz, multijugador y combate/tala ENet. No registra errores de
script en esas seis comprobaciones. La prueba gráfica del cliente verifica
además el ciclo completo de tala y restauración.

Se descartó el experimento de actualizar vecinos lejanos a 15 Hz: sus cambios
de FPS, alrededor del 0,2–0,3 %, y de física no separaban una ganancia clara
de la variación observada. Sus rutas, animaciones y frecuencia original siguen
activas. Los datos del experimento están en
`generated/reviews/2026-11-09/vecinos-distantes/`.

Medidas, capturas, defectos y fuentes de las sondas retiradas quedan en
`generated/reviews/2026-11-09/recursos-red/`. Continúan pendientes el interés
espacial, la validación WAN con ocho participantes y el coste gráfico general.
