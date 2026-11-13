# Senderos del Horizonte 0.1.23

- Sol y luna de energía cero dejan de consumir cálculo de iluminación; sus discos y transiciones se conservan.
- Perfiles opcionales Nativo, Equilibrado y Más fluido en Esc → Gráficos y Z; Nativo sigue siendo el valor inicial.
- A 2560×1440 en este Mac, reconstrucción espacial: bosque 35,54→41,28/44,49 FPS; villa 56,20→66,46/72,89; puerto 44,88→55,63/62,10.
- Los perfiles reconstruyen desde menor resolución 3D y pueden perder nitidez; la interfaz permanece a resolución completa.
- Persistencia, ambos menús, redimensionado, mínimo interno y valores de reserva comprobados, con nuevas pruebas en CI.

[Mediciones y límites](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.23/docs/PERFILES_PANTALLA_GRANDE.md).
El objetivo general de 100–120 FPS sigue pendiente; Windows necesita medición real.
ZIP completo con .exe como descarga principal, instalador como alternativa.

Cooperativo comprobado con procesos reales por ENet: combate autoritativo,
respuesta del invitado y simulación/movimiento con seis menús en ambos jugadores.
