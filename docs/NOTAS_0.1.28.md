# Senderos del Horizonte 0.1.28

- Automática está activa por defecto en Windows y Mac y sigue vigilando al jugar, también al cargar una configuración guardada.
- Si los FPS quedan bajos durante una ventana móvil de seis segundos, baja un escalón, espera a que se estabilice y vuelve a comprobar. Deja de bajar al recuperar el objetivo.
- Ignora pausas, menús, pérdida de foco, bloqueos de carga y tirones aislados; respeta VSync y los límites de FPS elegidos.
- Añade un último escalón Mínima si Rendimiento no basta: sin sombras, horizonte de 2 km y menor escala 3D, manteniendo la interfaz a resolución completa.
- Los ajustes manuales detienen la vigilancia. El nivel elegido se guarda; alcanzar el mínimo sin lograr el objetivo se indica en el panel.
- Comprobado con ventana real, caída controlada a 10 FPS, recuperación, pausa, arranque guardado y elección manual; siete fallos inyectados detectados por las pruebas.

[Funcionamiento, pruebas y límites](https://github.com/Francisco44444/godot_beautiful_space/blob/v0.1.28/docs/GRAFICOS_Y_AUTODETECCION.md).
La prueba de lentitud usa un límite artificial para verificar el comportamiento: no es una medición de la GTX 1060. El hardware puede impedir llegar a 60 FPS incluso con el nivel mínimo. ZIP completo con .exe como descarga principal; instalador como alternativa.
