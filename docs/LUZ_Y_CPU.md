# Relevo sol/luna y CPU de los vecinos — 8 de noviembre de 2026

El cambio de dirección de las sombras era brusco: al llegar al umbral de
relevo, una luna que ya alumbraba sustituía de golpe al mapa de sombras solar.
El color y la energía eran continuos; las sombras conservaban toda su opacidad.

Ahora `IslandEnvironment.sincronizar_luz_celeste` desvanece la sombra solar
cuando la luz diurna baja de 0,28 a 0,10. La lunar aparece gradualmente después
del relevo, entre 0,42 y 0,95 del factor nocturno. En el instante de cambiar de
dirección ambas opacidades son prácticamente cero. Sigue activo un solo mapa
direccional. En pleno día y plena noche la opacidad vuelve a 1 y se conservan
intensidades, colores y distancia de sombras.

`World` sincroniza ese estado en la misma llamada que actualiza la luz solar;
la luna ya no espera a su siguiente `_process` para recibir el cambio. También
se conserva la sincronización al aplicar la hora recibida del anfitrión.

## Verificación visual de ambos sentidos

Se capturaron 48 fotogramas alrededor de cada relevo, con cámara fija en Villa
Robledal, a 960×540 y pasos de 1/24 s. Se asentó primero la reproyección de
niebla durante 80 fotogramas. Actores y tiempo de shaders quedan congelados para
comparar el paisaje; las luces y el cielo siguen la fase solar de cada muestra.
Se desactiva explícitamente cada nodo y se verifican las transformaciones de
354 cuerpos en cada captura. El control reproduce la opacidad 1 anterior sobre
la misma escena.

| Cambio medio RGB al cruzar el relevo, escala 0–255 | Antes | Ahora |
| --- | ---: | ---: |
| Anochecer | 2,354 | 0,766 |
| Amanecer | 1,392 | 0,750 |

La subida excepcional del fotograma del relevo desaparece; la variación restante
incluye el cambio gradual de cielo y luz. Estas cifras corresponden a esa
cámara, no son una valoración general de calidad visual.

Vídeos comparados y fotogramas en
`generated/reviews/2026-11-08/luz-y-vecinos/`:

- `anochecer-antes-ahora.mp4` y `amanecer-antes-ahora.mp4`.
- `anochecer-relevo.png` y `amanecer-relevo.png`: los dos lados del umbral.
- `verificacion.json`: configuración, tandas y resultados numéricos completos.

La prueba `celestial_transition_test.gd` recorre **12.289 muestras**, encuentra
los dos relevos y exige continuidad sin esperar un fotograma. El cambio máximo
del vector de sombra ponderado justo en el relevo queda en **0,000097**.
Comprueba además sombras completas de día y noche, energía lunar 0,72 y un solo
mapa activo. `--break-shadow-fade` reintroduce la opacidad brusca y falla.

## Evitación de vecinos con el mismo resultado

Los 87 vecinos se comparaban todos contra todos cada paso de física. Una rejilla
de celdas de 2 m limita la consulta a las nueve celdas que pueden contener a
alguien a menos de 2 m. Los candidatos se ordenan por su índice original y la
rejilla se actualiza después de cada movimiento: se conserva el orden de suma
y el vecino siguiente ve las posiciones que ya han cambiado este tick.

El cambio mantiene población, rutas, oficios, animaciones, colisión y frecuencia
de simulación. En una prueba de 192 vecinos, 5.760 consultas, el cálculo pasa
de **240,34 a 25,56 ms**, unas 9,4 veces más rápido. Ese microbenchmark sólo mide
las consultas; el coste real del mundo incluye también mantener la rejilla.

Mundo completo en Apple M2 Pro, Metal Forward+, 1600×900, VSync desactivado, sin
límite de FPS, misma calidad y cámaras que la pasada anterior. Tandas alternadas
anterior/nuevo/nuevo/anterior, 240 fotogramas después de 60 de calentamiento:

| Cámara | Física anterior | Física nueva | FPS anteriores | FPS nuevos |
| --- | ---: | ---: | ---: | ---: |
| Puerto Alba | 3,429 ms | 2,089 ms | 49,16 | 49,14 |
| Villa Robledal | 3,424 ms | 2,188 ms | 60,47 | 61,21 |

Se ahorra aproximadamente **un 36–39 % del tiempo de física**. En Puerto el
p95 de fotograma pasa de 23,49 a 22,16 ms. El FPS medio apenas cambia: el render
sigue marcando el siguiente límite. **Los 200 FPS siguen pendientes.**

`village_avoidance_test.gd` compara 384 fuerzas con la implementación anterior,
incluyendo bordes negativos, distintas alturas y vecinos que cruzan celdas
antes de que les toque moverse a otros. `--break-avoidance-grid` omite una celda
y falla. El recorrido real `village_folk_test.gd` conserva 87 vecinos, 19 m de
marcha media, cero cruces de muros, cuatro oficios y el jinete.

## Experimentos de render y siguiente trabajo

Los controles de diagnóstico identifican sombras y SSAO como costes relevantes:
en Puerto se midieron 48,90 FPS completos, 60,82 sin sombras y 55,41 sin SSAO;
en la villa, 60,42 / 71,02 / 69,46. Quitar nubes sólo recuperó unos 2–3 FPS y
el océano apenas influyó en estas cámaras. Son controles de coste, no ajustes
que se hayan aplicado al juego.

Se ensayó oclusión con 5.594 paneles dentro de los muros ciegos de 107 casas.
Los dos modelos de muro pasaron 672 rayos de comprobación cada uno sin huecos
en la zona utilizada. La prueba ganó alrededor de 0,8 FPS en la villa y aumentó
el coste CPU de render. Se descarta por ahora; no se añade al mundo.

Pasaron las pruebas de evitación, transición celestial, recorrido de vecinos,
atmósfera completa y multijugador. Las dos pruebas nuevas están en el workflow
de Windows; su ejecución local se hizo en macOS.

La siguiente pasada de rendimiento debe centrarse en geometría, profundidad y
sombras del render. Continúan también los pendientes de combate cooperativo,
interés espacial y conexión WAN de `RENDIMIENTO_Y_COOPERATIVO.md`.
