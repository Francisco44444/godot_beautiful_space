# Directorio de partidas de Senderos

Servicio HTTP efímero para anunciar partidas ENet. No retransmite datos del
juego ni sustituye al puerto UDP del anfitrión.

- `GET /healthz`: estado del servicio.
- `GET /v1/rooms`: salas activas con plazas disponibles.
- `POST /v1/rooms`: crea una sala y devuelve su credencial privada.
- `PATCH /v1/rooms/{id}`: renueva el latido y la ocupación.
- `DELETE /v1/rooms/{id}`: retira la sala.

El contenedor solo publica HTTP en `127.0.0.1:24569`. En Synology debe colocarse
detrás de un proxy inverso HTTPS. La URL prevista para el juego es:

```text
https://franfuco4444.synology.me:24568/v1
```

La regla externa `24568/TCP` apunta al proxy HTTPS del NAS; el proxy reenvía a
`http://127.0.0.1:24569`. El UDP `24567` pertenece a la partida ENet, no a esta API.

El segundo enlace `192.168.0.25:24570` es un acceso HTTP exclusivamente local y
no se abre en el router. El juego lo detecta antes de elegir endpoint para evitar
el fallo de NAT loopback. Cuando una sala llega por ese enlace, el servicio
publica `franfuco4444.synology.me` como dirección ENet para que los invitados de
Internet reciban el destino correcto.

## Arranque automático en Synology

El servicio cuenta con dos niveles de recuperación:

1. `restart: unless-stopped` vuelve a levantar el contenedor cuando Docker se
   reinicia.
2. `senderos-lobby-boot.sh`, instalado como
   `/usr/local/etc/rc.d/S99senderos-lobby.sh`, inicia Container Manager, espera
   a que Docker esté listo y ejecuta `docker compose up -d` durante el arranque
   de DSM.

La entrada persistente se instala una sola vez desde el NAS:

```sh
cd /volume1/homes/francisco4/senderos-lobby
sudo sh install_nas_autostart.sh
```

El diagnóstico queda en `/var/log/senderos-lobby-autostart.log`. Para comprobar
el estado manualmente:

```sh
sudo /usr/local/etc/rc.d/S99senderos-lobby.sh status
```
