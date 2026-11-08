# Senderos del Horizonte 0.1.9

- Las 107 viviendas aportan oclusión estática al motor para evitar dibujar
  instancias completamente ocultas detrás de paredes, cubierta y suelos.
- Se conservan los triángulos originales y los huecos de puertas, ventanas
  y escaleras. La preparación se hace una vez al cargar el mundo.
- En las cámaras medidas del M2 Pro, la villa en movimiento pasa de 66,90
  a 70,48 FPS; el umbral, de 80,82 a 97,34; el interior, de 94,61 a 125,72.
  Puerto y bosque no presentan una mejora significativa con esta técnica.
- Verificación visual de día, noche y movimiento, prueba de huecos con Metal
  y headless, recorridos físicos de las casas y combate cooperativo real.

Las cifras corresponden a las cámaras y ajustes documentados en
[Oclusión de edificios](OCLUSION_EDIFICIOS.md). El objetivo de 100–120 FPS
en todo el recorrido sigue pendiente; no son mediciones de Windows.
La web del NAS mantiene el ZIP completo con el ejecutable como descarga
principal y el instalador como alternativa.
