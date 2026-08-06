# Terreno estilizado

Estos albedos originales se generaron para sustituir los antiguos materiales PBR de Terrain3D y mantener la misma lectura visual que los modelos low-poly de Quaternius.

- `quaternius_grass_albedo_seamless.png`: pradera verde pintada con variación amplia.
- `quaternius_path_albedo_seamless.png`: tierra ocre compactada.
- `quaternius_rock_albedo_seamless.png`: piedra clara con musgo verde.
- `island_sand_albedo_seamless.png`: arena dorada facetada para el desierto y las playas.
- `island_snow_albedo_seamless.png`: nieve alpina facetada para las montañas del norte.

Cada tile final mide 1024 x 1024 píxeles. Se construyó una versión de repetición exacta mediante cuadrantes espejados y recorte central; sus archivos `.import` activan mipmaps para evitar parpadeo a distancia. Terrain3D usa solo el albedo y rugosidad alta: no hay normal ni height fotográficos.

Las cinco imágenes se generaron mediante la herramienta integrada de generación de imágenes de OpenAI. Pradera, tierra y roca usaron la captura objetivo como referencia de paleta; arena y nieve se pidieron como superficies cenitales low-poly compatibles con Quaternius. Todos los prompts exigen superficies mates, sin objetos, texto ni marcas de agua. Los PNG sin sufijo `_seamless` son los maestros generados antes del acondicionamiento para repetición.
