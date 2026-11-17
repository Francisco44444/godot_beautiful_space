# Senderos del Horizonte 0.1.31

Aventura sin enemigos pasa a ser el modo inicial. Se elige en **Esc → Partida**;
Combate conserva la campaña original. Las partidas anteriores mantienen su modo.

- Cinco actos basados en observar y resolver: secuencia de semillas, contrapesos,
  orientación de espejos, válvulas de agua y campanas con nombres.
- Los 18 encargos tienen relatos y entregas obtenibles sin combatir. Hay
  escondrijos de llaves antes de las cuatro puertas de las grutas.
- Tres dianas que responden a flechas reales y un paso de nueve saltos sobre
  basalto en la Caldera. Caer devuelve al inicio sin perder vida.
- Refugios de seis troncos, construidos por anfitrión o invitados sobre terreno
  seco y despejado. El refugio compartido permite descansar y guardar un punto
  de regreso personal.
- Puzles y refugios compartidos, recompensas del invitado, protección frente a
  interacciones lejanas e incorporación tardía comprobados con procesos reales,
  tanto por ENet como por el servicio WebSocket del NAS.
- Progreso separado al alternar Aventura y Combate. La carga compartida se aplica
  antes de recuperar el punto de descanso de cada personaje.
- Los nuevos mecanismos son estáticos y funcionan por interacción; no añaden
  búsquedas ni actualizaciones continuas por fotograma. El navegador evita crear
  geometría de oclusión que su renderizador no utiliza.

Comprobaciones locales: campaña completa, 18 entregas, llaves, flechas, nueve
saltos con cápsula y gravedad reales, guardado, ambos modos, controles gráficos,
navegador y cooperativo con invitado tardío. Tres defectos introducidos a propósito
confirmaron que las pruebas detectan el modo inicial incorrecto, un acto
irresoluble y una entrega que no se guarda al recogerla.
La publicación oficial ejecuta además las regresiones antes de generar paquetes.

Medición orientativa en este Mac M2 Pro, ventana 2560×1440, VSync desactivado:
Alta a resolución nativa ronda **45–69 FPS** en las tres vistas examinadas;
Automática ronda **64–92 FPS**, ajustando sombras, densidad de hierba y resolución
interna. Son configuraciones diferentes: no es una ganancia gratuita ni una
medición de la GTX 1060. El objetivo de 100–120 FPS sigue pendiente.

Se publican Windows y Web. El ZIP completo con `.exe` sigue siendo la descarga
principal y el instalador es alternativo. Las salas por código requieren la misma versión.
