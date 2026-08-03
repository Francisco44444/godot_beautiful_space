# Procedencia de los pinos realistas

Esta carpeta contiene la variante GLB con texturas 1K del arbolado adulto usado en el valle.

- Título original: *Pine trees pack (lowpoly, game ready, LODs)*.
- Autor: LOLIPOP (`@lolipop_1707`).
- Fuente: <https://sketchfab.com/3d-models/pine-trees-pack-lowpoly-game-ready-lods-e1e9c07b8e2e445c943fec660beefba2>.
- Licencia: [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
- Archivo descargado: `pine_trees_lolipop_1k.glb`.
- Texturas: los PNG `pine_trees_lolipop_1k_*.png` fueron extraídos automáticamente del GLB por el importador de Godot.

## Atribución

Este trabajo usa *Pine trees pack (lowpoly, game ready, LODs)*, de LOLIPOP, disponible en Sketchfab bajo CC BY 4.0. La atribución al autor, el enlace a la fuente y el enlace a la licencia deben conservarse al redistribuir el modelo o una obra que lo incorpore.

## Integración y modificaciones

- `VegetationScatter` selecciona nueve variantes adultas de aproximadamente 10 a 30 metros.
- Para equilibrar calidad y rendimiento, combina las superficies Bark y Clusters del LOD1 de cada variante.
- Se corrige la orientación Z-up del paquete a Y-up de Godot.
- El proyecto añade distribución determinista por celdas `MultiMesh`, escalado, rotación, distancias de visibilidad y colisiones simplificadas.

Estas adaptaciones no implican respaldo ni afiliación por parte de LOLIPOP o Sketchfab.
