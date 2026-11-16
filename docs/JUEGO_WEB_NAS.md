# Senderos en el navegador

Dirección estable: https://franfuco4444.synology.me:24573/senderos/jugar/

La web de descargas conserva el ZIP completo con el ejecutable de Windows como
opción principal, y añade un acceso al juego de navegador. El instalador sigue
siendo una alternativa. Cada publicación web vive en una carpeta independiente;
el acceso estable cambia sólo después de verificar todos sus archivos por SHA-256.

## Juego y conexión

Chrome, Edge, Firefox o Safari actuales en un ordenador con teclado y ratón.
Pulsa «Entrar en Aeloria». La descarga inicial del mundo es de unos 570 MiB;
posteriormente se construyen la vegetación y los habitantes. WASD mueve al héroe,
el ratón mira, Espacio salta, E interactúa y Esc abre el menú.

En Esc → Multijugador, crea una sala y comparte su código de seis caracteres.
Los invitados lo introducen en el mismo menú. Ocho jugadores como máximo. Las
versiones descargables nuevas ofrecen «Crear sala por código» y la conexión por
código en Avanzado. La conexión ENet por IP sigue disponible en escritorio.

El anfitrión conserva la autoridad sobre el mundo. El NAS retransmite paquetes
opacos de las mismas RPC; no interpreta personajes, guardados ni misiones. Al
cerrar el anfitrión se cierra la sala. Se rechazan versiones distintas y mensajes
entre invitados que intenten eludir al anfitrión. Las colas de salida están
limitadas por participante: un cliente lento no bloquea a los demás.

## HTTPS y red local

El certificado corresponde a `franfuco4444.synology.me`, no a `192.168.0.25`.
Usar `https://192.168.0.25:24573/` produce un error de certificado. El juego
necesita un contexto seguro; el acceso HTTP local al servidor de descargas no
sustituye al acceso HTTPS del juego.

En una red cuyo router no admite retorno NAT, configura el DNS local para que
`franfuco4444.synology.me` resuelva a `192.168.0.25`. Conserva el mismo nombre y
puerto HTTPS, por lo que el certificado y el WebSocket siguen siendo válidos.
No se debe desactivar la comprobación del certificado.

## Servicio del NAS

`server/senderos_web` contiene un relay aiohttp independiente de Lightsaber y Vigo.
La activación añade el servicio `senderos-coop` y una ubicación `/senderos/coop/`
al nginx existente. Comparte el HTTPS 24573; no abre un puerto nuevo a Internet.
La cuenta del contenedor carece de privilegios y usa un sistema de archivos de
sólo lectura. El script realiza copias previas y comprueba nginx antes de recargar.

Una vez copiados esos archivos a `/volume1/homes/francisco4/senderos-web-coop`,
la activación se ejecuta como root desde DSM o mediante sudo:

```sh
/bin/bash /volume1/homes/francisco4/senderos-web-coop/activar_en_nas.sh
```

`/senderos/coop/healthz` devuelve estado, número de salas y participantes; no
publica los códigos. Ya se ha instalado y comprobado en el NAS.

## Compilar y publicar

Godot 4.7.1, plantilla oficial `web_dlink_nothreads_release.zip`, Terrain3D 1.0.2.
El navegador usa Compatibility/WebGL2 y un solo hilo. Windows y Mac conservan
Forward+. Los materiales del terreno y de la hierba compactan el mapa de regiones
de 16 a 4 KiB para entrar en los bloques mínimos de WebGL2. Se mantienen las 100
regiones del mundo y se reserva espacio para 128 ubicaciones. El shader conserva
alturas, agujeros y mezclas originales. La niebla volumétrica se sustituye por
niebla de distancia sólo en Compatibility. La luz web evita la saturación del
renderizador de navegador.

Los OBJ que Godot importa no se conservan como texto en el PCK. La biblioteca
`generated/modelos_obj_runtime.res` incluye 333 mallas con sus colores originales;
el cargador las duplica cuando falta el archivo fuente. Para regenerarla:

```sh
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/hornear_obj_runtime.gd
```

El flujo de GitHub genera el ZIP web junto al de Windows. Tras una release:

```sh
bash tools/publicar_web_nas.sh VERSION --subir
```

Ese script descarga, comprueba y publica ambas versiones. Para una prueba web
local ya exportada, sin tocar las descargas de Windows:

```sh
bash tools/publicar_juego_web_nas.sh IDENTIFICADOR dist/web-game
```

## Comprobaciones del 16 de noviembre de 2026

- Navegador real: terreno, hierba, personaje, casas, movimiento y sala por código.
- Navegador anfitrión + Godot invitado con el mundo real pasando por el NAS:
  dos jugadores, tres estados del mundo recibidos y una réplica remota.
- Relay del NAS: ocho plazas, rechazo de versión incompatible, rechazo de
  suplantación, cierre de invitados al salir el anfitrión y RPC fiable de 16 KB.
- Certificado verificado y WebSocket cifrado mediante el proxy HTTPS público;
  la comprobación local usa resolución hacia la IP LAN y conserva el nombre TLS.
- Acceso desde Internet: página y descarga completa comprobadas. El navegador
  remoto de prueba se cerró tras la descarga; no se pudo confirmar allí el mundo
  3D. La comprobación visual de la partida se hizo en el navegador de este Mac.
- Regresión ENet y prueba de interfaz cooperativa con dos procesos: correctas.
- Prueba de atmósfera de escritorio y de accesorios exportados: correctas.
- Tres defectos inyectados y detectados: exceso del bloque WebGL, materiales
  compartidos entre accesorios y noveno jugador admitido.

Limitaciones: la primera carga es grande; la exportación web tiene menor margen
de rendimiento que las versiones nativas. Las mediciones del navegador local
no acreditan 60 FPS ni el rendimiento de la GTX 1060. El modo pacífico de aventura,
los nuevos rompecabezas y la construcción de refugios continúan pendientes.
