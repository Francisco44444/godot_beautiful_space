# Senderos del Horizonte 0.1.13

- El invitado deja de restaurar todo el bosque y sus colisiones a cada estado
  recibido. Se actualizan sólo los recursos destruidos o restaurados.
- Los golpes parciales de tala sobreviven a las actualizaciones periódicas;
  una confirmación conserva la caída del árbol y su tocón.
- Las correcciones cancelan roturas pendientes y evitan callbacks que oculten
  un recurso ya restaurado o produzcan botín después de la corrección.
- Prueba cooperativa ampliada con tres golpes entre instantáneas, caída y
  restauración compartida entre dos procesos reales.

En la reproducción del receptor a 5 Hz, M2 Pro a 1600×900, Puerto pasa de
52,27 a 63,67 FPS y la villa de 61,17 a 76,87 FPS. El p95 de fotograma baja
de unos 56–59 ms a 14–16 ms. Son mediciones del receptor con estados
reproducidos; el objetivo general de 100–120 FPS sigue pendiente.

[Mediciones y pruebas](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.13/docs/RECURSOS_EN_COOPERATIVO.md).
La web ofrece el ZIP completo con el .exe como descarga principal y el
instalador con actualizaciones como alternativa.
