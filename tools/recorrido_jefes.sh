#!/bin/bash
# Lanza el juego en modo recorrido de jefes.
#   F1..F5  ir al jefe del acto I..V     F6  equipo de grado alto
#   F7      vida al máximo               F8  ficha del jefe cercano
cd "$(dirname "$0")/.."
exec tools/runtime/Godot.app/Contents/MacOS/Godot --path . \
  --script res://tools/diagnostics/boss_tour.gd
