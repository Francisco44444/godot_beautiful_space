# Terreno de la Fase 2

El contenido de `data/` ha sido generado con `tools/generate_terrain.gd` y Terrain3D 1.0.2. Incluye cuatro regiones de 256×256 metros, material y tres tiles originales estilizados: pradera, sendero y roca con musgo.

Los albedos finales viven en `assets/textures/stylized_terrain`. Son tiles 1024² preparados para repetición exacta y no usan normal, height ni microdetalle PBR, de modo que el suelo mantenga la misma lectura low-poly que los modelos Quaternius.

Para regenerarlo de forma determinista:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/generate_terrain.gd
```

El mapa cubre 512×512 metros. El valle discurre aproximadamente de sur a norte; el sendero comienza cerca de `(0, 190)` y termina en el mirador `(98, -110)`, a unos 24 metros de altura.
