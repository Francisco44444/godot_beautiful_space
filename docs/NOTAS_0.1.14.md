# Senderos del Horizonte 0.1.14

- Colisión del bosque por celdas: talar o restaurar un árbol actualiza su
  sector y conserva sólidos los demás troncos.
- Se mantienen exactamente los triángulos físicos, la vegetación visible,
  iluminación, sombras e identificadores de recursos y partidas.
- Pruebas de rayos y movimiento real, reservas de grutas, ids compartidos,
  altas tardías, restauración y cooperación entre dos procesos.

En el M2 Pro, actualizar el sector más cargado pasa de **42,00 a 0,59 ms**.
En la prueba gráfica con un cambio cada 60 fotogramas, el p99 baja de unos
**55–57 ms a 16–29 ms**, según la zona. En reposo los FPS apenas varían; el
objetivo general de 100–120 FPS sigue pendiente.

[Mediciones y comprobaciones](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.14/docs/COLISIONES_LOCALES_DEL_BOSQUE.md).
La web mantiene el ZIP completo con el .exe como descarga principal y el
instalador con actualizaciones como alternativa.
