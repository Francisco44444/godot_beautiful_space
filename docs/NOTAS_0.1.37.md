# Senderos del Horizonte 0.1.37

- Los árboles lejanos reutilizan vértices idénticos. Las seis mallas conservan
  cada triángulo, normal y color, con 58–60 % menos vértices almacenados.
- Cuando se baja de la tabla el último corredor de Las Campanas Blancas,
  los invitados reciben de inmediato la retirada de los tres mensajeros y
  pueden volver a empezar la carrera.
- El ZIP completo de Windows incluye el ejecutable. El instalador es
  alternativo y el ZIP web queda preparado para la próxima subida al NAS.

## Medición en la cumbre

Apple M2 Pro, calidad Alta, 2560×1440 nativos y VSync desactivado. Cuatro series
alternadas de 220 fotogramas con la misma cámara.

| Panorámica desde Cumbres Blancas | 0.1.36 | 0.1.37 |
|---|---:|---:|
| FPS medios, mediana de dos series | 46,0 | 50,5 |
| Tiempo de fotograma, percentil 95 | 21,86 ms | 19,84 ms |
| Triángulos visibles | 4.060.551 | 4.060.551 |
| Triángulos de sombras | 1.796.796 | 1.796.796 |

Las pruebas verifican los 59.312 árboles, el renderizado del bosque y la
geometría de los seis modelos lejanos. La mejora del 9,7 % corresponde a esta
vista del Mac. El objetivo de 100–120 FPS y la medición en la GTX 1060 a
1440p siguen pendientes.
