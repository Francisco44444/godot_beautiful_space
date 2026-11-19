# Senderos del Horizonte 0.1.38

- El juego exportado reconoce los **124 objetos** del catálogo, con nombres
  de archivo correctos, iconos e inventario inicial. Esto afecta al equipo,
  la munición, los botines y las recompensas que usan el catálogo.
- Las partidas de una exportación anterior recuperan las piezas iniciales
  que quedaron referenciadas sin el objeto correspondiente. La barra rápida
  muestra los iconos de las armas y el contador de flechas sin depender de
  los emojis del sistema.
- Las villas reutilizan los suelos y las cubiertas ya preparadas. En una
  prueba de montaje con 107 casas, el tiempo baja de **1,66 a 1,50 s**,
  con la misma geometría y las mismas colisiones.
- Se conservan la mejora de rendimiento de las panorámicas y el reinicio
  cooperativo de Las Campanas Blancas de la versión 0.1.37.

La compilación comprueba el catálogo y los iconos dentro de los paquetes de Windows y web.
El ZIP completo de Windows incluye el ejecutable, y el instalador queda
disponible como alternativa. La publicación en el NAS sigue pendiente.
