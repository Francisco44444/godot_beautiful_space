# Pantalla grande: luz nula y perfiles de reconstrucción

El modo inicial sigue siendo **Nativo**. Esta revisión añade una optimización de
iluminación y dos perfiles **opcionales** para ventanas grandes. El objetivo de
100–120 FPS generales sigue pendiente. Los perfiles reducen resolución interna:
no se presenta su ganancia como una optimización gratuita ni como calidad idéntica.

## Luz que no aporta nada

El sol o la luna con energía exactamente cero dejan de participar en el render.
Forward+ conservaba su cálculo de iluminación aunque esa contribución fuese cero.
Los discos visuales son nodos independientes y siguen visibles cuando corresponde.
No se aplica tolerancia: todo aporte positivo diminuto o negativo permanece.

Se recorrieron 12.289 fases, incluidos dos relevos de sombras y energías diminutas.
Cinco defectos inyectados demostraron que la prueba detecta cambios incorrectos.
En cinco vistas diurnas, nocturnas y de crepúsculo a 2560×1440, la comparación
contra ambas luces presentes dio diferencias máximas de 1–2/255 y p99 ≤1/255;
las repeticiones de control también presentan ruido temporal de esa magnitud.
El contador variable de FPS se excluyó del cálculo, conservando todo el escenario.
No se atribuye una ganancia porcentual nativa a este cambio: la última medición
quedó interferida por una prueba simultánea de Vigo y se descartó.

## Elegir fluidez

En **Esc → Gráficos → Renderizado 3D**, o en **Z**, se puede elegir:

- **Nativo:** resolución completa; valor inicial y al restaurar ajustes.
- **Equilibrado:** escala interna 0,77; pierde nitidez en detalles finos como hierba.
- **Más fluido:** escala interna 2/3; prioriza FPS con una pérdida mayor de nitidez.

La interfaz permanece a resolución completa. Se conserva como mínimo una entrada
3D de 1280×720: al reducir la ventana se limita la escala y, si hace falta, se
vuelve a nativo sin olvidar la preferencia. Cambiar de tamaño con el ratón vuelve
a aplicar el perfil mediante una señal; no se añadió ningún proceso por fotograma.
El ajuste persiste entre partidas y ambos menús comparten la elección.

Se utiliza MetalFX espacial si el dispositivo lo soporta; en los demás dispositivos
Forward+ se usa FSR1 espacial. Sin Forward+, o sin pantalla gráfica, se conserva
nativo. No se modifican LOD, sombras, densidad, distancia, iluminación ni MSAA.
En particular, el umbral LOD permanece constante respecto a la resolución final;
multiplicarlo por la escala incrementaría geometría y distorsionaría la comparación.

## Medición a 2560×1440

Mac M2 Pro, Metal/Forward+, Godot 4.7.1, ventana en primer plano, VSync desactivada,
100 fotogramas de calentamiento y 240 realmente dibujados por variante. Cámara y
posición fijas; IA, animaciones e interfaz activas. Física del héroe detenida para
impedir que vecinos lo empujen. El ciclo solar avanza 1/60 s por dibujo; el viento
usa TIME real. LOD 400 m, umbral 0,85, MSAA 0, misma oclusión y densidad. Los datos
se terminaron a las 02:32 locales, antes de la otra prueba de Vigo iniciada 06:12.
Nativo es la media de los controles inicial y final de cada vista.

| Vista | Nativo | Equilibrado | Más fluido | Ganancia respecto a nativo |
|---|---:|---:|---:|---:|
| Bosque | 35.54 | 41.28 | 44.49 | +16.1% / +25.2% |
| Villa | 56.20 | 66.46 | 72.89 | +18.2% / +29.7% |
| Puerto | 44.88 | 55.62 | 62.10 | +23.9% / +38.4% |

Cifras en FPS de este Mac; no describen todos los escenarios ni constituyen una
medición en Windows. MetalFX temporal y FSR2 también se probaron, con el mismo
umbral LOD: en estas escenas su pase adicional de movimiento compensó el ahorro
y no se adoptaron. Con FSR1 espacial a 2/3 se obtuvieron 44,38, 72,60 y 61,88 FPS
respectivamente; su compatibilidad no demuestra el rendimiento de un PC Windows.

## Comprobaciones y alternativas descartadas

Se inspeccionaron capturas de bosque, villa, puerto, noche y crepúsculo en nativo,
MetalFX y FSR1. La reconstrucción conserva el escenario, pero sus bordes finos no
son idénticos. Los dos menús se comprobaron en ventanas reales de 1280×720 y
2560×1440, incluyendo desplazamiento y botón Volver dentro de la pantalla.

`render_profiles_test.gd` cubre 3.588 límites de tamaño impar, modos, mínimo interno
y reservas; cinco mutantes reales fallaron por sus asertos. La prueba integrada
cubre persistencia, ajustes antiguos/incorrectos, Z/Gráficos, redimensionado real y
retorno nativo; seis mutantes adicionales detectaron sus defectos. Ambas se añaden
a CI. Las pruebas existentes de VSync, configuración y transición celeste pasan.

También se midieron variantes que no se incorporaron por falta de ganancia útil:
especular de vegetación, caché de color por raíz, descarte alpha de árboles,
ruido macro del terreno y cinco lecturas de sus mapas de color constantes.
La última variante verificó en GPU las 100 capas y todos sus mipmaps: rindió
aproximadamente 0–1%, insuficiente para añadir una nueva caché y su invalidación.
No se eliminaron texturas, reflejos, vegetación ni sistemas de aventura por intuición.

Evidencias locales en `generated/reviews/2026-11-13/`: `reconstruccion-espacial`,
`reconstruccion-calidad`, `perfiles-render`, `perfiles-integracion`, `luces-cero`,
`pbr-raices`, `macro-ruido-diagnostico` y `color-map-diagnostico`.

Referencias primarias: [escalado en Godot](https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html),
[Viewport](https://docs.godotengine.org/en/4.7/classes/class_viewport.html),
[umbral LOD normalizado por salida](https://github.com/godotengine/godot/blob/4.7.1-stable/servers/rendering/renderer_viewport.cpp#L303).

Cooperativo comprobado con procesos reales por ENet: combate autoritativo,
respuesta del invitado y simulación/movimiento con seis menús en ambos jugadores.
