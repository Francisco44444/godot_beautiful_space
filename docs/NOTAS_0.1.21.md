# Senderos del Horizonte 0.1.21

- Terreno más eficiente: se evita muestrear siete mapas normales constantes y
  procesar un mapeo sin relieve, tras verificar sus datos reales en GPU.
- La especialización conserva la oclusión de laderas, entradas de grutas,
  hierba, sombras, nieve, materiales y distancias de dibujo.
- Entre un 2,18 % y un 9,86 % más de FPS medios en las siete vistas medidas en
  Mac M2 Pro; Tenebroso pasa de unos 61,6 a 67,6 FPS. El objetivo general de
  100–120 FPS sigue pendiente y no se extrapola a Windows.
- Comprobaciones gráficas de día/noche y cooperativo con procesos reales.

[Pruebas, capturas y mediciones](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.21/docs/NORMALES_DEL_TERRENO.md).
La web mantiene el ZIP completo con el .exe como descarga principal y el
instalador como alternativa.
