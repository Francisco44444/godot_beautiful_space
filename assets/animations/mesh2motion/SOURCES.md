# Procedencia de las animaciones de Mesh2Motion

Los paquetes de esta carpeta proceden del repositorio oficial [Mesh2Motion/mesh2motion-app](https://github.com/Mesh2Motion/mesh2motion-app):

- `human-base-animations.glb`: [fuente directa](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/static/animations/human-base-animations.glb).
- `human-addon-animations.glb`: [fuente directa](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/static/animations/human-addon-animations.glb).
- Los PNG `human-base-animations_color-palette.png` y `human-addon-animations_color-palette.png` acompañan la importación local de esos GLB.

## Licencia verificada

La carpeta local no incluía inicialmente una copia independiente de licencia. La verificación se hizo en el repositorio oficial el 3 de agosto de 2026:

- El [README de Mesh2Motion](https://github.com/Mesh2Motion/mesh2motion-app#licenses) separa el código y la plataforma, bajo MIT, de los recursos artísticos 3D, bajo CC0.
- [LICENSE-CC0.MD](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/LICENSE-CC0.MD) declara expresamente que los modelos 3D, archivos Blender, rigs y animaciones se publican bajo **CC0 1.0 Universal**.
- El código de la aplicación usa una [licencia MIT separada](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/LICENSE-MIT.MD); no se ha incorporado código de la aplicación a esta carpeta.

Por tanto, los dos paquetes GLB de animación se registran como [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). La atribución no es obligatoria, pero se conserva esta ficha para facilitar la trazabilidad.

## Uso actual

Los paquetes están incluidos para inspección y futuras pruebas de retargeting. No están asignados actualmente al héroe visible de `scenes/world.tscn`, por lo que no se presentan como su conjunto activo de animaciones jugables.
