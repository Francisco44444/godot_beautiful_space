#!/usr/bin/env python3
"""Levanta un anfitrión y un invitado Godot en el mismo contexto de red."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import socket
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]


def find_godot(explicit: str | None) -> Path:
    candidates = [
        explicit,
        os.environ.get("GODOT_BIN"),
        str(ROOT / "tools/runtime/Godot.app/Contents/MacOS/Godot"),
        str(ROOT / ".ci/godot/Godot_v4.7.1-stable_linux.x86_64"),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    raise FileNotFoundError("No se encontró Godot; usa --godot /ruta/al/binario")


def available_udp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot")
    args = parser.parse_args()
    godot = find_godot(args.godot)
    port = available_udp_port()
    base = [
        str(godot),
        "--headless",
        "--rendering-method",
        "gl_compatibility",
        "--path",
        str(ROOT),
        "--script",
        "res://tests/network_handshake_test.gd",
        "--",
    ]
    host = subprocess.Popen(
        base + ["--host", f"--port={port}"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        time.sleep(0.8)
        client = subprocess.run(
            base + ["--client", f"--port={port}"],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=25,
            check=False,
        )
        host_output, _ = host.communicate(timeout=25)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        host.terminate()
        try:
            host.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            host.kill()
        raise

    combined = host_output + "\n" + client.stdout
    if host.returncode != 0 or client.returncode != 0:
        print(combined, file=sys.stderr)
        return 1
    if "NETWORK HOST OK" not in host_output or "NETWORK CLIENT OK" not in client.stdout:
        print(combined, file=sys.stderr)
        return 1
    print("NETWORK HANDSHAKE TEST OK: anfitrión e invitado intercambian roster y estado UDP.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
