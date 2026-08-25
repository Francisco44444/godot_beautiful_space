#!/usr/bin/env python3
"""Generate the immutable metadata consumed by the Windows launcher."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--package", required=True, type=Path)
    parser.add_argument("--url", default="PACKAGE_URL_PENDING_UPLOAD")
    parser.add_argument("--notes", default="Nueva version de Senderos del Horizonte")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    if re.fullmatch(r"\d+\.\d+\.\d+(?:\.\d+)?", args.version) is None:
        parser.error("la version debe ser numerica, por ejemplo 0.1.0")

    package_bytes = args.package.read_bytes()
    manifest = {
        "schema": 1,
        "channel": "alpha",
        "version": args.version,
        "published_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "minimum_launcher_version": "1.0.0",
        "notes": args.notes,
        "windows": {
            "architecture": "x86_64",
            "executable": "SenderosDelHorizonte.exe",
            "url": args.url,
            "sha256": hashlib.sha256(package_bytes).hexdigest(),
            "size_bytes": len(package_bytes),
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
