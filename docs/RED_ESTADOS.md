# Estados cooperativos pequeños — 8 de noviembre de 2026

Los estados completos del mundo y de los vecinos se comprimen sin pérdida con
Zstandard y se envían en bloques de **hasta 1.000 bytes**, incluida su cabecera.
Antes, el estado de los vecinos provocaba el aviso de ENet de 4.051 bytes sobre
una MTU de 1.392. La prueba real de combate ya no produce ese aviso.

`estado_fragmentado.gd` conserva los tipos y la precisión de `var_to_bytes`.
Cada bloque identifica su secuencia, índice, cantidad y tamaños. Sólo se aplica
un estado cuando llegan todas sus partes. Una pérdida mantiene el estado
anterior hasta completar otro; un estado atrasado no hace retroceder el mundo.
Cada productor conserva su secuencia, para que los vecinos no invaliden partes
del mundo al compartir canal.

El canal 2 utiliza ahora `unreliable`, con la ordenación en esta capa. Godot
advierte que los paquetes de tamaños distintos en `unreliable_ordered` pueden
descartarse al adelantar unos a otros; véase la [documentación de canales y
modos de transferencia](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#channels).
Las acciones fiables de combate y el movimiento de los héroes conservan sus
canales anteriores.

El receptor limita a cuatro estados pendientes, valida las cabeceras antes de
reservar memoria y caduca las partes antiguas al recibir nuevos datos. Los
límites son 8 MiB por estado sin comprimir y 2 MiB comprimidos. Cambiar de
sesión reinicia las secuencias. El anfitrión prepara cada estado una vez para
todos los invitados y omite esa preparación si está solo.

## Medición

Mundo real, Godot 4.7.1, Mac M2 Pro; ocho preparaciones de calentamiento y 200
preparaciones por caso. Los bytes nuevos incluyen las cabeceras de esta capa,
pero no las cabeceras RPC, ENet, UDP o IP.

| Estado | Serialización anterior | Bytes nuevos | Reducción | Bloques | CPU de preparación |
| --- | ---: | ---: | ---: | ---: | ---: |
| Mundo completo | 45.460 B | 4.489 B | 90,1 % | 5 | 265,92 µs |
| Vecinos de Robledal | 3.996 B | 882 B | 77,9 % | 1 | 26,29 µs |

No se omiten actores, no se cuantizan posiciones ni se bajan las frecuencias.
Son medidas de tráfico de aplicación y del coste de preparar un estado;
**no son una ganancia de FPS**. El objetivo gráfico de 100–120 FPS sigue
pendiente y no se alcanza con este cambio de transporte.

## Pruebas

- `state_transport_test.gd`: estado con 265 enemigos y 50.000 ids de recursos,
  igualdad exacta tras comprimir/descomprimir, orden inverso, duplicados,
  pérdida de partes, estados viejos, memoria acotada, cabeceras inválidas y
  reinicio de sesión.
- `test_cooperative_combat.py`: dos procesos ENet con el mundo real y las 17
  etapas de combate; exige además que no aparezca el aviso de MTU.
- `multiplayer_test.gd`: lobby, réplicas, inventario y tala autoritativa.

Se cambió temporalmente el tamaño máximo a 1.600 bytes: falló el contrato de
1.000. Se retiró la guarda de secuencias: falló la prevención de retrocesos.
Ambas fuentes se restauraron. La prueba nueva está incluida en Windows CI.
Datos locales: `generated/reviews/2026-11-08/transporte/`.

Continúan pendientes el interés espacial, enviar cambios persistentes en vez
de repetir listas completas y la validación WAN con ocho participantes. La
reordenación y pérdida deterministas no sustituyen esa prueba de Internet.
