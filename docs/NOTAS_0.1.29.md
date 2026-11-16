# Senderos del Horizonte 0.1.29

- Juego de navegador servido desde el NAS, con pantalla de entrada, progreso de descarga y acceso a pantalla completa.
- Terreno y hierba adaptados a los límites de WebGL2 sin cambiar sus alturas ni colores; iluminación y niebla específicas para navegador.
- Salas por código para hasta ocho participantes, compatibles entre navegador y nuevas versiones de escritorio. Conserva la conexión clásica por IP.
- Relay independiente en el NAS, anfitrión con autoridad, control de versión y colas limitadas por participante.
- Accesorios OBJ incluidos como mallas en la exportación, manteniendo geometría y materiales propios.
- Las releases incluyen el ZIP web; la publicación en el NAS actualiza el juego de navegador y las descargas de Windows.

Probado con navegador real, mundo completo con anfitrión web e invitado Godot,
RPC entre dos procesos por el NAS, ocho plazas, desconexiones y certificado HTTPS.
Regresiones de ENet, interfaz cooperativa y atmósfera correctas. El ZIP completo
con .exe sigue siendo la descarga principal; el instalador es alternativo.

La primera carga web ronda 570 MiB y el rendimiento depende del navegador y la
gráfica. El nuevo modo de aventura pacífica y los nuevos puzles siguen pendientes.

[Detalles y comprobaciones](JUEGO_WEB_NAS.md).
