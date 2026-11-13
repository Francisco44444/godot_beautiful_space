# Caché del cielo y pantalla grande — 12 de noviembre de 2026

Se evita reenviar cuatro colores exactamente idénticos al cielo. Esos setters
invalidaban su radiancia en GPU. Sun y MoonLight pasan a LIGHT_ONLY porque los
astros visibles son mallas y el disco procedural ya tiene ángulo cero.
Se conservan ProceduralSkyMaterial, radiancia 512, paleta, luces y sombras.

El velo omite ruido cuando su alfa será exactamente cero. Se conservan valores
positivos diminutos, colores, emisión y detalle. Sólo se retira su prepasada
opaca: alfa máximo 0,94 frente al umbral 0,99 de Forward+4.7.1.

## Mediciones

M 2 Pro, Metal Forward+, escala 3 D 1, MSAA 0, LOD 400 m/0,85, VSync 0. IA, HUD,
vegetación, niebla y sombras activos; física del héroe desactivada para evitar
que los vecinos lo empujen. El sol avanza 1/60 s por fotograma. Se repite el reloj
del viento. Cuatro procesos alternan 0.1.21/nuevo/nuevo/0.1.21 con 100 fotogramas
de calentamiento y 240 realmente dibujados por vista. Tabla: media de dos tandas.
Se verifica el tamaño GPU nativo:1600×900 o 2560×1440, sin reescalado.

| Vista y ancho | FPS 0.1.21 | FPS nuevos | Mejora |
| --- | ---: | ---: | ---: |
| bosque_1600 | 46.67 | 51.61 | +10.60 % |
| bosque_2560 | 31.22 | 34.62 | +10.90 % |
| villa_1600 | 68.41 | 84.96 | +24.19 % |
| villa_2560 | 44.57 | 55.03 | +23.47 % |
| puerto_1600 | 60.95 | 69.94 | +14.76 % |
| puerto_2560 | 38.48 | 43.61 | +13.34 % |

El bosque a 2560×1440 sigue en 34,62 FPS: **el objetivo general 100–120 sigue
pendiente**. Las cifras son de este Mac; no se extrapolan a GPU Windows.

## Calidad y comprobaciones

52 capturas a 2560×1440: trece casos de Puerto, Robledal, bosque, raíces, nieve
y Tenebroso, día/noche y viento de tormenta. Se comparan original, control,
nuevo y restaurado. Se inspeccionaron Puerto antes/después, bosque y nieve.
Máxima diferencia RGB media 0,0335/255 y p 99 de un nivel; hay cambios puntuales
hasta 14 niveles, máximo 0,00236% de píxeles con diferencia mayor de 2. No son
imágenes idénticas. Se conservan densidad, altura, geometría, distancias,
resolución, reflejos y sombras.

cloud_transparency_test prueba 80 entradas con GPU, color/glow y profundidad
calibrada (contraste 35/255): diferencia máxima 0. sky_radiance_test exige cielo
nativo 512, paletas, energías, sombras,200 repeticiones sin subir uniformes y
12.289 fases continuas. Ambas pruebas están en CI. Se detectaron 22 defectos
inyectados por sus asertos, sin errores de compilación; fuentes restauradas por
SHA 256. Pasan relevo solar/lunar, luciérnagas, maravillas/grutas y cooperativo
ENet real con invitado gráfico para combate y seis ventanas.

Evidencias locales en generated/reviews/2026-11-12/: cielo-nubes-final,
cielo-cache, pantalla-grande-nubes, fps-ciclo-vivo-final y
cielo-nubes-calidad-final. Las nueve sondas se archivan y se retiran.

## Experimentos no incorporados

SSAO ya usaba media resolución; calidad Low apenas mejoró. Se conserva el
SSAO. El ensayo de quitar Apple de la exclusión de prepasada tampoco mostró
ganancia consistente. Se conserva radiancia 512 frente a 128/filtrado rápido.
La variante que oculta luces de energía cero mostró aproximadamente 2–3% extra,
pero permanece como prototipo pendiente de integración y calidad completa.

Window informó textura 4096×2304 por su getter escalado; get_image y el formato
GPU confirmaron 2560×1440. No se modificó el estiramiento por ese contador.
Los controles iniciales sin sombras fueron inválidos: el entorno las reactivaba;
no se usan. Ocultar Terrain 3 D no equivale a retirar los suelos arquitectónicos.

Fuentes del mecanismo:
[MaterialStorage 4.7.1](https://github.com/godotengine/godot/blob/4.7.1-stable/servers/rendering/renderer_rd/storage_rd/material_storage.cpp),
[SkyRenderer 4.7.1](https://github.com/godotengine/godot/blob/4.7.1-stable/servers/rendering/renderer_rd/environment/sky.cpp),
[Forward+4.7.1](https://github.com/godotengine/godot/blob/4.7.1-stable/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp).
