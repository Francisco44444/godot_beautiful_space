# Evaluación de la versión jugable de navegador — 14-11-2026

Se descarta por ahora añadir una **versión web completa equivalente** a todas
las releases. El usuario autorizó descartarla si no resultaba viable. La web de
descarga del NAS sigue sirviendo el ZIP Windows y el instalador alternativo.
La decisión es práctica para el estado actual del juego; no afirma que Godot
sea incapaz de crear juegos web ni que Terrain3D carezca de binarios WebAssembly.

## Qué se comprobó

El proyecto incluye bibliotecas web de Terrain3D, pero sólo tiene configurada la
exportación Windows y el cooperativo utiliza `ENetMultiplayerPeer`. En el NAS hay
un relay WebSocket de Sables/Vigo; reutilizar su existencia no convierte los RPC
de Senderos en compatibles con su protocolo. Ese relay admite cuatro jugadores,
límites de mensajes y descarte de estados antiguos: no es un reemplazo directo
del transporte fiable/no fiable de las expediciones de hasta ocho jugadores.

La prueba gráfica local con Godot 4.7.1 y `gl_compatibility` carga las cien
regiones de terreno y las 107 viviendas. Se captura el mundo, no sólo un menú.
El motor registra:

```
ERROR: shader type fog not supported in OpenGL renderer
```

La niebla volumétrica regional de la aventura no puede conservarse usando ese
shader en este renderizador. También habría que revisar y adaptar las rutas de
optimización del render y el aspecto completo de cada bioma, gruta y fase de luz.
La prueba con Forward+ termina sin errores de script/shader.

Se intentó una comparación de rendimiento, pero se observó otro proceso de Vigo
renderizando a 3024×1740 durante la comparación. **Las cifras de ambas muestras
se invalidan y no se publican como medida de rendimiento web ni nativo.** La
prueba local de OpenGL tampoco equivale a medir WebGL en un navegador moderno.

No se ha exportado ni validado una compilación WebAssembly en navegador, y no se
ha desplegado una partida web en el NAS. No se presenta como funcional un enlace
que sólo cargue la portada o carezca de cooperativo.

## Alcance de la decisión

Godot requiere WebGL 2.0 para la exportación web. La documentación de Terrain3D
califica sus exportaciones web de experimentales. Los navegadores no ofrecen el
transporte UDP/ENet que utiliza actualmente Senderos: Godot ofrece WebSocket y
WebRTC, con distintas necesidades de transporte y servidor.

Conservar los escenarios, la iluminación y las garantías de la expedición exige
una adaptación gráfica y de red con pruebas propias; no basta con añadir un
preset y subir archivos. Esta revisión mantiene el trabajo en Mac/Windows y la
publicación nativa comprobada. No se añade una promesa de despliegue jugable web
automático al script de releases.

Las sondas y capturas se archivan localmente en
`generated/reviews/2026-11-14/web-viabilidad/`, y las sondas se retiran del código.

Referencias primarias consultadas:

- [Exportación web de Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
- [Plataformas y renderizadores de Terrain3D](https://github.com/TokisanGames/Terrain3D/blob/main/doc/docs/platforms.md).
- [WebSocket en Godot](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).
