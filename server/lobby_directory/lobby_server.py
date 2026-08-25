#!/usr/bin/env python3
"""Directorio efímero de partidas para Senderos del Horizonte.

El servicio no transporta el juego: publica salas ENet activas y las elimina
cuando dejan de enviar latidos. La dirección de unión se obtiene de la conexión
HTTP, nunca de un valor arbitrario enviado por el cliente.
"""

from __future__ import annotations

import hmac
import ipaddress
import json
import os
import re
import secrets
import threading
import time
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlsplit


SCHEMA = 1
GAME_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:\.\d+)?$")
ROOM_ID_RE = re.compile(r"^[A-Za-z0-9_-]{8,32}$")
MAX_BODY_BYTES = 8 * 1024
MAX_ROOMS = int(os.environ.get("LOBBY_MAX_ROOMS", "256"))
ROOM_TTL_SECONDS = int(os.environ.get("LOBBY_ROOM_TTL", "50"))
HEARTBEAT_SECONDS = int(os.environ.get("LOBBY_HEARTBEAT", "15"))
TRUST_PROXY = os.environ.get("LOBBY_TRUST_PROXY", "1") == "1"
LOCAL_PUBLIC_ADDRESS = os.environ.get("LOBBY_LOCAL_PUBLIC_ADDRESS", "").strip()


class ApiError(Exception):
    def __init__(self, status: HTTPStatus, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def _clean_text(value: Any, maximum: int, fallback: str) -> str:
    text = " ".join(str(value or "").split())[:maximum]
    return text or fallback


def _clean_address(value: str) -> str:
    candidate = value.strip()
    if candidate.startswith("::ffff:"):
        candidate = candidate[7:]
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError as error:
        raise ApiError(HTTPStatus.BAD_REQUEST, "Dirección de red no válida") from error


def _clean_join_address(value: str) -> str:
    candidate = value.strip().lower().rstrip(".")
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        if len(candidate) > 253 or re.fullmatch(r"(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", candidate) is None:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Nombre público de unión no válido")
        return candidate


def _join_address_for_source(source: str) -> str:
    clean_source = _clean_address(source)
    if LOCAL_PUBLIC_ADDRESS and ipaddress.ip_address(clean_source).is_private:
        return _clean_join_address(LOCAL_PUBLIC_ADDRESS)
    return clean_source


def _integer(payload: dict[str, Any], key: str, minimum: int, maximum: int) -> int:
    try:
        value = int(payload.get(key))
    except (TypeError, ValueError) as error:
        raise ApiError(HTTPStatus.BAD_REQUEST, f"{key} no es un entero") from error
    if value < minimum or value > maximum:
        raise ApiError(HTTPStatus.BAD_REQUEST, f"{key} fuera de rango")
    return value


@dataclass
class Room:
    room_id: str
    lease_token: str
    name: str
    host_name: str
    address: str
    port: int
    players: int
    max_players: int
    game_version: str
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)

    def public(self) -> dict[str, Any]:
        return {
            "id": self.room_id,
            "name": self.name,
            "host_name": self.host_name,
            "address": self.address,
            "port": self.port,
            "players": self.players,
            "max_players": self.max_players,
            "game_version": self.game_version,
            "age_seconds": max(0, int(time.time() - self.created_at)),
        }


class RoomDirectory:
    def __init__(self, room_ttl_seconds: int = ROOM_TTL_SECONDS) -> None:
        self.room_ttl_seconds = max(20, room_ttl_seconds)
        self._rooms: dict[str, Room] = {}
        self._lock = threading.Lock()

    def _prune_locked(self) -> None:
        deadline = time.time() - self.room_ttl_seconds
        expired = [room_id for room_id, room in self._rooms.items() if room.updated_at < deadline]
        for room_id in expired:
            del self._rooms[room_id]

    def list_rooms(self) -> list[dict[str, Any]]:
        with self._lock:
            self._prune_locked()
            rooms = [room.public() for room in self._rooms.values() if room.players < room.max_players]
        rooms.sort(key=lambda room: (room["game_version"], room["players"], room["name"]), reverse=True)
        return rooms

    def create_room(self, payload: dict[str, Any], address: str) -> tuple[Room, str]:
        port = _integer(payload, "port", 1, 65535)
        players = _integer(payload, "players", 1, 8)
        max_players = _integer(payload, "max_players", 2, 8)
        if players > max_players:
            raise ApiError(HTTPStatus.BAD_REQUEST, "players supera max_players")
        game_version = _clean_text(payload.get("game_version"), 16, "0.0.0")
        if GAME_VERSION_RE.fullmatch(game_version) is None:
            raise ApiError(HTTPStatus.BAD_REQUEST, "game_version no válida")
        with self._lock:
            self._prune_locked()
            if len(self._rooms) >= MAX_ROOMS:
                raise ApiError(HTTPStatus.SERVICE_UNAVAILABLE, "El directorio está lleno")
            room_id = secrets.token_urlsafe(9)
            while room_id in self._rooms:
                room_id = secrets.token_urlsafe(9)
            lease_token = secrets.token_urlsafe(32)
            room = Room(
                room_id=room_id,
                lease_token=lease_token,
                name=_clean_text(payload.get("name"), 40, "Expedición sin nombre"),
                host_name=_clean_text(payload.get("host_name"), 24, "Aventurero"),
                address=_join_address_for_source(address),
                port=port,
                players=players,
                max_players=max_players,
                game_version=game_version,
            )
            self._rooms[room_id] = room
        return room, lease_token

    def heartbeat(self, room_id: str, lease_token: str, payload: dict[str, Any]) -> Room:
        with self._lock:
            self._prune_locked()
            room = self._authorized_room_locked(room_id, lease_token)
            players = _integer(payload, "players", 1, room.max_players)
            room.players = players
            if "name" in payload:
                room.name = _clean_text(payload.get("name"), 40, room.name)
            room.updated_at = time.time()
            return room

    def remove(self, room_id: str, lease_token: str) -> None:
        with self._lock:
            room = self._authorized_room_locked(room_id, lease_token)
            del self._rooms[room.room_id]

    def _authorized_room_locked(self, room_id: str, lease_token: str) -> Room:
        room = self._rooms.get(room_id)
        if room is None:
            raise ApiError(HTTPStatus.NOT_FOUND, "Sala no encontrada")
        if not lease_token or not hmac.compare_digest(room.lease_token, lease_token):
            raise ApiError(HTTPStatus.UNAUTHORIZED, "Credencial de sala no válida")
        return room


class LobbyHandler(BaseHTTPRequestHandler):
    server_version = "SenderosLobby/1.0"

    @property
    def directory(self) -> RoomDirectory:
        return self.server.directory  # type: ignore[attr-defined]

    def do_GET(self) -> None:
        path = urlsplit(self.path).path.rstrip("/")
        if path == "/healthz":
            self._json(HTTPStatus.OK, {"status": "ok", "schema": SCHEMA})
            return
        if path == "/v1/rooms":
            self._json(
                HTTPStatus.OK,
                {"schema": SCHEMA, "rooms": self.directory.list_rooms(), "server_time": int(time.time())},
            )
            return
        self._error(ApiError(HTTPStatus.NOT_FOUND, "Ruta no encontrada"))

    def do_POST(self) -> None:
        if urlsplit(self.path).path.rstrip("/") != "/v1/rooms":
            self._error(ApiError(HTTPStatus.NOT_FOUND, "Ruta no encontrada"))
            return
        try:
            room, lease_token = self.directory.create_room(self._read_json(), self._client_address())
            self._json(
                HTTPStatus.CREATED,
                {
                    "schema": SCHEMA,
                    "room": room.public(),
                    "lease_token": lease_token,
                    "heartbeat_interval_seconds": HEARTBEAT_SECONDS,
                },
            )
        except ApiError as error:
            self._error(error)

    def do_PATCH(self) -> None:
        try:
            room_id = self._room_id_from_path()
            room = self.directory.heartbeat(room_id, self._bearer_token(), self._read_json())
            self._json(HTTPStatus.OK, {"schema": SCHEMA, "room": room.public()})
        except ApiError as error:
            self._error(error)

    def do_DELETE(self) -> None:
        try:
            room_id = self._room_id_from_path()
            self.directory.remove(room_id, self._bearer_token())
            self.send_response(HTTPStatus.NO_CONTENT)
            self._headers("text/plain; charset=utf-8", 0)
            self.end_headers()
        except ApiError as error:
            self._error(error)

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._headers("text/plain; charset=utf-8", 0)
        self.send_header("Allow", "GET, POST, PATCH, DELETE, OPTIONS")
        self.end_headers()

    def _room_id_from_path(self) -> str:
        parts = urlsplit(self.path).path.strip("/").split("/")
        if len(parts) != 3 or parts[:2] != ["v1", "rooms"] or ROOM_ID_RE.fullmatch(parts[2]) is None:
            raise ApiError(HTTPStatus.NOT_FOUND, "Sala no encontrada")
        return parts[2]

    def _bearer_token(self) -> str:
        authorization = self.headers.get("Authorization", "")
        return authorization[7:] if authorization.startswith("Bearer ") else ""

    def _client_address(self) -> str:
        forwarded = self.headers.get("X-Forwarded-For", "") if TRUST_PROXY else ""
        return forwarded.split(",")[0].strip() if forwarded else self.client_address[0]

    def _read_json(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Content-Length no válido") from error
        if length <= 0 or length > MAX_BODY_BYTES:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Cuerpo vacío o demasiado grande")
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ApiError(HTTPStatus.BAD_REQUEST, "JSON no válido") from error
        if not isinstance(payload, dict):
            raise ApiError(HTTPStatus.BAD_REQUEST, "Se esperaba un objeto JSON")
        return payload

    def _json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self._headers("application/json; charset=utf-8", len(body))
        self.end_headers()
        self.wfile.write(body)

    def _error(self, error: ApiError) -> None:
        self._json(error.status, {"schema": SCHEMA, "error": error.message})

    def _headers(self, content_type: str, content_length: int) -> None:
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(content_length))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")

    def log_message(self, format_string: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), format_string % args), flush=True)


class LobbyServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], directory: RoomDirectory | None = None) -> None:
        self.directory = directory or RoomDirectory()
        super().__init__(address, LobbyHandler)


def main() -> None:
    host = os.environ.get("LOBBY_HOST", "0.0.0.0")
    port = int(os.environ.get("LOBBY_PORT", "8080"))
    server = LobbyServer((host, port))
    print(f"Senderos lobby escuchando en {host}:{port}", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
