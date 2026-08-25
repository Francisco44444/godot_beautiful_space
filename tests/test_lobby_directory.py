#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "server" / "lobby_directory" / "lobby_server.py"
SPEC = importlib.util.spec_from_file_location("lobby_server", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
LOBBY = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = LOBBY
SPEC.loader.exec_module(LOBBY)


class LobbyDirectoryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        LOBBY.TRUST_PROXY = False
        cls.server = LOBBY.LobbyServer(("127.0.0.1", 0), LOBBY.RoomDirectory(20))
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def request(self, method: str, path: str, payload=None, token: str = ""):
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(self.base + path, data=body, headers=headers, method=method)
        with urllib.request.urlopen(request, timeout=2) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None

    def test_room_lifecycle_and_authorization(self) -> None:
        status, created = self.request(
            "POST",
            "/v1/rooms",
            {
                "name": "Bosque de Lúa",
                "host_name": "Lúa",
                "port": 24567,
                "players": 1,
                "max_players": 8,
                "game_version": "0.1.0",
            },
        )
        self.assertEqual(status, 201)
        room = created["room"]
        token = created["lease_token"]
        self.assertEqual(room["address"], "127.0.0.1")
        self.assertNotIn("lease_token", room)

        _, listing = self.request("GET", "/v1/rooms")
        self.assertEqual(len(listing["rooms"]), 1)
        self.assertEqual(listing["rooms"][0]["name"], "Bosque de Lúa")

        with self.assertRaises(urllib.error.HTTPError) as unauthorized:
            self.request("PATCH", f"/v1/rooms/{room['id']}", {"players": 2}, "incorrecto")
        self.assertEqual(unauthorized.exception.code, 401)

        _, heartbeat = self.request(
            "PATCH", f"/v1/rooms/{room['id']}", {"players": 2}, token
        )
        self.assertEqual(heartbeat["room"]["players"], 2)
        status, _ = self.request("DELETE", f"/v1/rooms/{room['id']}", token=token)
        self.assertEqual(status, 204)
        _, listing = self.request("GET", "/v1/rooms")
        self.assertEqual(listing["rooms"], [])

    def test_rejects_invalid_room(self) -> None:
        with self.assertRaises(urllib.error.HTTPError) as invalid:
            self.request(
                "POST",
                "/v1/rooms",
                {"port": 70000, "players": 1, "max_players": 8, "game_version": "dev"},
            )
        self.assertEqual(invalid.exception.code, 400)


if __name__ == "__main__":
    unittest.main()
