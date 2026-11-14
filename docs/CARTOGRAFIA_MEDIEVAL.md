# Carta medieval y minimapa local — 0.1.26

La carta cambia las manchas saturadas y los puntos de colores por tinta sobre
pergamino claro, tipografía serif, símbolos de villas, fortalezas y grutas,
bosques grabados, montañas rayadas, rosa de los vientos, escala y leyenda.
Los caminos, costa, rías, puntos de interés y entradas de grutas conservan sus
coordenadas. Las manchas de bioma son orientativas; no se presentan como curvas
de nivel medidas del terreno.

El minimapa muestra ahora los alrededores del héroe, centrado en su posición y
con el norte arriba. La flecha indica el rumbo y los objetivos lejanos se marcan
en el borde. El mapa completo conserva la visión de la isla, su destino del
diario y las teclas M/B. Se ajusta a la ventana y mantiene una escala uniforme
en los dos ejes. El velo de lectura atenúa el paisaje detrás de la carta.

## Coste y caché

El minimapa utiliza un `SubViewport` 2D de 2048×2048, con transparencia y sin
escena 3D. Sólo se rasteriza al invalidar la carta por tamaño, cambio de modo,
marea acumulada superior a 0,02 o altas/bajas de grutas. Mientras se camina o
gira se desplaza una textura dentro de una ventana recortada; la costa, caminos,
símbolos y relieve no se vuelven a dibujar en el atlas.

La carta completa conserva los comandos de CanvasItem. Su viewport auxiliar
permanece desactivado a 2×2; no reserva otro atlas grande para la misma interfaz.
Cuando el mapa está oculto no actualiza sus marcadores.

Prueba gráfica nativa en el Mac, con 300 movimientos y giros:

| Medida | Resultado |
|---|---:|
| Reconstrucciones del atlas al moverse | 0 |
| Textura GPU antes/después | mismo hash |
| Mediana de la llamada de actualización CPU | 38 μs |
| Percentil 95 de esa llamada | 73 μs |
| Datos de color de la textura | 16.777.216 bytes |

Estos tiempos miden la llamada de actualización del minimapa, **no el renderizado
completo de la interfaz ni del juego**, y no son una promesa de FPS. El atlas
consume 16 MiB de datos de color, además de recursos internos del motor y fuentes.
El objetivo general de 100–120 FPS sigue pendiente.

## Verificación

`island_map_cache_test.gd`, ya incluido en CI, comprueba posición y rumbo,
transformación del atlas, caché quieta, marea, grutas tardías, ocultar/reabrir,
escala uniforme, rótulos sin superposición y ajuste a una ventana pequeña.
Los mutantes reconstruyen la costa en cada movimiento, invierten el
desplazamiento de la textura o permiten nombres superpuestos: cada defecto
se detecta por su aserción. Se ejecuta también con GPU nativa.

Se revisan capturas de la carta y el minimapa por separado y sobre el juego,
incluida una ventana menor. Las pruebas de integración del diario y del mundo
siguen pasando. Las evidencias y sondas retiradas se archivan localmente en
`generated/reviews/2026-11-14/cartografia-medieval/`.

## Fuentes incluidas

Cinzel y Crimson Pro se distribuyen sin modificar, con sus licencias completas
en `assets/fonts/cartografia/` y atribución en los créditos del juego. El filtro
de exportación incluye los textos OFL en el paquete.

- [Cinzel, repositorio de Google Fonts](https://github.com/google/fonts/tree/main/ofl/cinzel).
- [Crimson Pro, repositorio de Google Fonts](https://github.com/google/fonts/tree/main/ofl/crimsonpro).
