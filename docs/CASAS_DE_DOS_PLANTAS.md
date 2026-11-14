# Viviendas de planta baja, primera y tejado

La 0.1.25 limita las viviendas a **dos plantas habitables y cubierta**, según
la aclaración del jugador. Robledal solicitaba casas de tres, cuatro y cinco
plantas; otros edificios de reunión y algunos caseríos también superaban las
dos plantas. Ahora las 107 viviendas tienen planta baja y primera; las alas
bajas conservan una planta y sus propios faldones.

El límite se aplica tanto en `BuildingRecipes` como al construir la vivienda.
Las peticiones antiguas de más pisos quedan limitadas antes de resolver el plan,
instanciar piezas, amueblar interiores y publicar sus metadatos. Las recetas del
taller, incluido el solar, respetan el mismo máximo. Las tres siluetas de las
viviendas, sus parcelas, accesos y habitantes se conservan. Los castillos usan
su propio generador y mantienen su altura.

## Censo real de las viviendas

Godot 4.7.1, mundo completo instanciado antes y después. Se cuentan todas las
mallas y colisiones descendientes de las 107 viviendas, incluidos sus interiores.
Los triángulos son los del detalle completo de las mallas; no son el contador de
triángulos visibles de una cámara.

| Medida | Antes | Ahora | Retirados |
|---|---:|---:|---:|
| Plantas por vivienda principal | 2–5 | 2 | — |
| Nodos de malla | 17.020 | 9.621 | 7.399 |
| Triángulos de detalle completo | 6.666.129 | 3.883.357 | 2.782.772 |
| Colisiones | 23.715 | 11.223 | 12.492 |

Las viviendas usan un 41,7 % menos de triángulos de detalle completo. La bajada
no se presenta como un porcentaje de FPS: cambia también la geometría que se ve
entre las casas y sus oclusores. Siguen pendientes una comparación FPS aislada
de este cambio y el objetivo general de 100–120 FPS.

## Comprobaciones

- Se inspeccionan seis pares de capturas nativas: Robledal desde arriba, su calle
  y Puerto Alba, de día y de noche.
- El solver limita peticiones de 0, 1, 2, 3, 5 y 100 plantas. Se mide la altura
  del plan de sus cuerpos, además del metadato de la vivienda.
- La prueba del mundo comprueba las 107 viviendas, 214 tramos de escalera,
  2.544 celdas de forjado, 570 hastiales y los tres castillos.
- El recorrido físico entra y sale por las puertas de Robledal y sube y baja
  sin saltar por las tres recetas. La cobertura se elige por receta para que
  todas se recorran aunque compartan el mismo número de plantas.
- Geometría sin solapes, accesos, cubierta y LOD se verifican de nuevo. Los
  quince recortes de tejado siguen usando el recurso LOD de la 0.1.24.
- Un mutante que permite tres plantas falla por la aserción del límite; al
  restaurar dos plantas vuelve a pasar. La prueba del mundo se añade a CI.

Evidencia local archivada en
`generated/reviews/2026-11-14/casas-dos-plantas/`. Las sondas temporales se retiran
antes del commit. Esta entrega incluye también las correcciones de pradera,
agarre del hacha y crepúsculo de la 0.1.24.
