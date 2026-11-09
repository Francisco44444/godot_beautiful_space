# Senderos del Horizonte 0.1.12

- LOD individual de los árboles para evitar detalle excesivo dentro de
  grupos grandes, conservando población, frondosidad, materiales, alcance,
  configuración de sombras e identificadores cooperativos.
- VSync configurable desde **Esc → Gráficos** y **Z**, con elección
  persistente y sincronizada entre ambos menús. Permanece activada por defecto.
- Panel Z desplazable para mantener accesibles sus controles a 720p.
- Comparaciones de día, ocaso, noche y tormenta; prueba de índices LOD con
  Metal, controles de ventana reales y combate cooperativo con dos procesos.

En el M2 Pro a 1600×900, sin VSync, el bosque verde pasa de **46,01 a
47,15 FPS** con cámara fija y de **45,35 a 46,48 FPS** con movimiento:
aproximadamente un **2,5 %**. Las demás zonas medidas apenas cambian.

[Mediciones y comprobaciones](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.12/docs/DETALLE_DE_ARBOLES_Y_VSYNC.md).
El objetivo general de 100–120 FPS sigue pendiente. La web mantiene el ZIP
completo con el .exe como descarga principal y el instalador como alternativa.
