# Senderos del Horizonte 0.1.7

- Sombras de los árboles completas mediante instancias individuales, con sus
  mallas, viento, materiales y detalle conservados. En las cámaras medidas del
  Mac mejora un 8,8–9,4 % Puerto Alba y un 2,3–2,6 % Villa Robledal frente a
  la ruta anterior. Comparaciones de día, noche y movimiento verificadas.
- El selector de vegetación conserva el resultado cuando el foco y la distancia
  no han cambiado. El perfil de scripts en reposo baja aproximadamente un 23 %
  en tres zonas. Esto reduce trabajo de CPU; no equivale a un 23 % más de FPS.
- Enemigos y jefes evitan consultar dos veces la posición autoritativa al
  calcular el mismo vector hacia su objetivo.
- Comprobaciones de cache, actualización forzada, nuevas celdas y cambios de
  distancia añadidas a la compilación de Windows.
- Auditoría de los 73 scripts, actividad distante, guardado periódico y tamaño
  del árbol documentada con mediciones de tres zonas.
- La web del NAS ofrece el ZIP completo con el ejecutable como descarga
  principal. Sus enlaces iniciales también corresponden a la versión publicada
  cuando JavaScript está desactivado; el instalador sigue como alternativa.

Las mediciones de rendimiento son de Apple M2 Pro y las cámaras documentadas;
100–120 FPS sigue siendo un objetivo pendiente. La hierba, la resolución,
la iluminación y las distancias de dibujo se conservan. Continúan pendientes
el progreso cooperativo compartido y la validación WAN con ocho participantes.
