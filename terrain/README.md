# Terreno de la Fase 2

El contenido de `data/` ha sido generado con `tools/generate_terrain.gd` y Terrain3D 1.0.2. Incluye 16 regiones de 256×256 vértices con `vertex_spacing = 9.765625`, lo que representa una isla exacta de 10×10 km. Usa cinco tiles originales estilizados: pradera, sendero, roca con musgo, arena y nieve.

Los albedos finales viven en `assets/textures/stylized_terrain`. Son tiles 1024² preparados para repetición exacta y no usan normal, height ni microdetalle PBR, de modo que el suelo mantenga la misma lectura low-poly que los modelos Quaternius.

Para regenerarlo de forma determinista:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/generate_terrain.gd
```

El mapa cubre 100 km² desde `(-5000, -5000)` hasta `(5000, 5000)`. La costa baja bajo el nivel del mar, ocho rutas enlazan seis villas y el sendero inicial conserva el mirador `(98, -110)` a unos 24 metros de altura.
