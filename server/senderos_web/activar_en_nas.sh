#!/bin/bash
# Ejecutar una sola vez como root desde el Programador de tareas de DSM.
set -euo pipefail
base=/volume1/homes/francisco4/saber-updates
servicio=/volume1/homes/francisco4/senderos-web-coop
if [ "$(id -u)" != 0 ]; then echo 'Ejecuta esta tarea como root en DSM.' >&2; exit 1; fi
cd "$base"
test -f compose.antes-senderos-web.yaml || cp -p compose.yaml compose.antes-senderos-web.yaml
test -f nginx.antes-senderos-web.conf || cp -p nginx.conf nginx.antes-senderos-web.conf
python3 - <<'PY'
from pathlib import Path
p=Path('compose.yaml');s=p.read_text()
if '\n  senderos-coop:' not in s:
 s=s.replace('services:\n','''services:
  senderos-coop:
    image: senderos-coop:local
    build: /volume1/homes/francisco4/senderos-web-coop
    container_name: senderos-coop
    restart: unless-stopped
    read_only: true
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
    mem_limit: 128m
    pids_limit: 32
''',1)
p.write_text(s)
p=Path('nginx.conf');s=p.read_text()
if 'location /senderos/coop/' not in s:
 s=s.replace('    location /multiplayer/ {','''    location /senderos/coop/ {
        set $senderos_relay senderos-coop:8080;
        proxy_pass http://$senderos_relay;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        proxy_buffering off;
    }

    location /multiplayer/ {''',1)
p.write_text(s)
PY
/usr/local/bin/docker-compose config --quiet
/usr/local/bin/docker-compose up -d --build senderos-coop
# DSM puede haber creado el servidor con otro nombre de proyecto Compose.
# Compartir su red real evita un 502 aunque ambas carpetas coincidan.
redes=$(/usr/local/bin/docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' saber-updates)
for red in $redes; do
 if ! /usr/local/bin/docker inspect -f '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' senderos-coop | /bin/grep -q "$red"; then
  /usr/local/bin/docker network connect --alias senderos-coop "$red" senderos-coop
 fi
done
/usr/local/bin/docker logs --tail 30 senderos-coop > /volume1/homes/francisco4/senderos-web-coop/arranque.log 2>&1
chmod 644 /volume1/homes/francisco4/senderos-web-coop/arranque.log
if ! /usr/local/bin/docker exec saber-updates nginx -t; then
 cp -p nginx.antes-senderos-web.conf nginx.conf
 echo 'Se ha restaurado la configuración anterior; revisa el error.' >&2
 exit 1
fi
/usr/local/bin/docker exec saber-updates nginx -s reload
echo 'Cooperativo Senderos activado. Los otros juegos conservan sus servicios.'
