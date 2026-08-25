#!/bin/sh

# Arranque persistente para Synology DSM. DSM ejecuta los scripts de
# /usr/local/etc/rc.d con los argumentos start/stop durante el ciclo del NAS.

PROJECT_DIR="/volume1/homes/francisco4/senderos-lobby"
DOCKER_BIN="/var/packages/ContainerManager/target/usr/bin/docker"
SYNO_PKG="/usr/syno/bin/synopkg"
LOG_FILE="/var/log/senderos-lobby-autostart.log"
MAX_ATTEMPTS=60

log_message() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"
}

start_lobby() {
  log_message "Iniciando Container Manager y Senderos Lobby"

  "$SYNO_PKG" start ContainerManager >> "$LOG_FILE" 2>&1 || true

  attempt=0
  while [ "$attempt" -lt "$MAX_ATTEMPTS" ]; do
    if "$DOCKER_BIN" info >/dev/null 2>&1; then
      break
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
    log_message "ERROR: Docker no estuvo disponible tras 120 segundos"
    return 1
  fi

  if [ ! -f "$PROJECT_DIR/compose.yaml" ]; then
    log_message "ERROR: no existe $PROJECT_DIR/compose.yaml"
    return 1
  fi

  cd "$PROJECT_DIR" || return 1
  "$DOCKER_BIN" compose up -d >> "$LOG_FILE" 2>&1
  result=$?
  if [ "$result" -eq 0 ]; then
    log_message "Senderos Lobby iniciado correctamente"
  else
    log_message "ERROR: docker compose terminó con código $result"
  fi
  return "$result"
}

stop_lobby() {
  log_message "Deteniendo Senderos Lobby"
  if "$DOCKER_BIN" info >/dev/null 2>&1 && [ -f "$PROJECT_DIR/compose.yaml" ]; then
    cd "$PROJECT_DIR" || return 1
    "$DOCKER_BIN" compose stop >> "$LOG_FILE" 2>&1 || true
  fi
}

case "${1:-start}" in
  start)
    start_lobby
    ;;
  stop)
    stop_lobby
    ;;
  restart)
    stop_lobby
    start_lobby
    ;;
  status)
    "$DOCKER_BIN" inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}} {{.HostConfig.RestartPolicy.Name}}' senderos-lobby
    ;;
  *)
    echo "Uso: $0 {start|stop|restart|status}" >&2
    exit 2
    ;;
esac
