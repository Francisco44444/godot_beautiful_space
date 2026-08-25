#!/usr/bin/env python3
"""Read or update the version shared by Godot and the Windows executable."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:\.\d+)?$")


def read_current(project_file: Path) -> str:
    match = re.search(r'^config/version="([^"]+)"$', project_file.read_text(encoding="utf-8"), re.MULTILINE)
    if match is None:
        raise SystemExit(f"No se encontró config/version en {project_file}")
    return match.group(1)


def replace_once(path: Path, pattern: str, replacement: str) -> None:
    source = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"No se pudo actualizar exactamente una entrada en {path}")
    path.write_text(updated, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--version")
    action.add_argument("--print-current", action="store_true")
    action.add_argument("--print-next-patch", action="store_true")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    project_file = args.root / "project.godot"
    export_file = args.root / "export_presets.cfg"
    current = read_current(project_file)

    if args.print_current:
        print(current)
        return
    if args.print_next_patch:
        major, minor, patch = (int(part) for part in current.split(".")[:3])
        print(f"{major}.{minor}.{patch + 1}")
        return

    version = args.version
    if version is None or VERSION_RE.fullmatch(version) is None:
        parser.error("la versión debe ser numérica: 0.1.2 o 0.1.2.3")

    windows_version = version if version.count(".") == 3 else f"{version}.0"
    replace_once(project_file, r'^config/version="[^"]+"$', f'config/version="{version}"')
    replace_once(export_file, r'^application/file_version="[^"]+"$', f'application/file_version="{windows_version}"')
    replace_once(export_file, r'^application/product_version="[^"]+"$', f'application/product_version="{windows_version}"')
    print(version)


if __name__ == "__main__":
    main()
