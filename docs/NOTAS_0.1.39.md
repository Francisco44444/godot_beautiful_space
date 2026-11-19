# Senderos del Horizonte 0.1.39

- La calidad automática puede probar **Equilibrada con la escala Más fluida**
  antes de pasar a Rendimiento. Conserva la vegetación, las sombras, la
  oclusión ambiental, el resplandor y la niebla del perfil Equilibrada.
- La escala se guarda y también se puede ajustar tras una caída sostenida
  durante la partida. Las ventanas y renderizadores donde ambas escalas
  coinciden pasan directamente al siguiente nivel.
- La prueba de exportación sigue verificando los 124 objetos y la recuperación
  del equipo inicial en guardados anteriores. Las mejoras de panorámica,
  carga de las villas y cooperativo de 0.1.37 y 0.1.38 están incluidas.

## Prueba de calidad automática

Bosque Tenebroso, Apple M2 Pro, salida 2560×1440, VSync desactivado y objetivo
de 60 FPS. Las muestras de la escala intermedia mantuvieron **64–66 FPS**.
Alta nativa ronda los 42 FPS en esa cámara. Equilibrada al 77 % rondaba
los 59,5 FPS y bajaba a Rendimiento al 50 % con el criterio anterior.

La escala intermedia renderiza el mundo a aproximadamente 1707×960 para
esa salida. La interfaz sigue usando toda la resolución. Los 100–120 FPS
en Alta y la medición en una GTX 1060 a 1440p siguen pendientes.

El ZIP de Windows incluye el ejecutable y el paquete de datos. También
están disponibles el instalador alternativo y el ZIP web para el NAS.
