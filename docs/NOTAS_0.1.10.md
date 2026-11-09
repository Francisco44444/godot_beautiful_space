# Senderos del Horizonte 0.1.10

- Descarte por cámara de los 3.360 árboles secos del Bosque Tenebroso:
  se evita enviar el color de ejemplares fuera de pantalla dentro de grupos
  que todavía eran visibles.
- Se conservan las mallas, materiales, distancias, caja y LOD de cada grupo,
  así como sus sombras completas y los índices de tala y sincronización.
- En las cámaras medidas del M2 Pro, el bosque tenebroso pasa de 49,67 a
  56,55 FPS en reposo y de 50,43 a 56,59 en movimiento. Puerto y bosque
  verde se mantienen prácticamente iguales.
- Verificación visual de día, noche, órbitas y giros bruscos; prueba de
  matrices con Metal, estabilidad del mundo y cooperativo con procesos reales.

Las mediciones y sus límites están en [Oclusión del bosque](OCLUSION_BOSQUE.md).
El objetivo de 100–120 FPS en todo el recorrido sigue pendiente. La oclusión
dinámica entre copas continúa en investigación. La web del NAS mantiene
el ZIP completo con el ejecutable como descarga principal.
