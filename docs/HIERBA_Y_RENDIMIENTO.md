# Primera pasada de paisaje y rendimiento — 7 de noviembre de 2026

## Dirección y referencias

Senderos conserva el arte low-poly. Duelo de Sables es la referencia de paisaje,
vegetación y aventura; Vigo se consulta para técnicas de rendimiento y red,
sin trasladar su dirección semirrealista.

Leídos `CLAUDE.md` de los tres proyectos, el diario `hierba_briznas.md` de Sables,
su guía de grutas y la guía `mundo_rendimiento.md` de Vigo. La hierba actual de
Sables ya no usa tarjetas: son triángulos opacos con densidad por distancia.
Las mediciones históricas de esos juegos no se presentan como cifras de Senderos.

## Implementado

- `shaders/meadow_blades.gdshader`: un triángulo opaco por brizna. Sin `discard`
  ni transparencia. Un único varying de color y albedo calculado en el vértice.
- El color comparte el array GPU de albedos, los tintes y las escalas UV de
  Terrain3D; además lee el mapa de color del terreno. No se introduce una
  paleta verde independiente ni otra copia de las texturas.
- Altura cercana **0,90–1,34 m antes de escala**, media 0,90–1,34 y lejana
  0,80–1,14. Los parches originales se escalan aproximadamente entre 0,88 y 1,16.
- Parche cercano: **12.000 briznas**; medio: 1.200; lejano: 192. Radio 11 m.
  La capa cercana inicial tenía 6.000: el usuario pidió duplicar densidad,
  subir altura y posteriormente otro 15 % de altura.
- Relevo cercano a **16–28 m**; medio a lejano a 120–160 m; final a 210–260 m.
  La densidad por píxel disminuye con el cuadrado de la distancia y las hojas
  supervivientes tienen un ensanche limitado a 1,8 / 1,35 / 1,15 según capa.
  Los anchos medios y lejanos son 0,05–0,09 y 0,075–0,13 m antes del ensanche
  y la escala del parche. Así desaparecen las siluetas triangulares anchas.
  El sorteo depende de la raíz en el mundo.
- Los triángulos retirados colapsan los tres vértices al mismo punto. No se
  colapsan a una línea: en Sables eso producía NaN y discos negros con glow.
- Se conserva el viento, la pisada del personaje y la reacción a tormentas y
  ondas de combate. Las tres capas se pegan a las alturas de Terrain3D.
- Las hojas retiradas por distancia evitan lecturas de mapas y cálculos de
  viento. `skip_hidden_work` permite medir el control desde la utilidad de captura.
- Los campos cercano y medio reservan 4.096 instancias y actualizan
  `visible_instance_count`; sólo crecerían si la capacidad fuese insuficiente.
  Se evita realocar el búfer al caminar. Los MultiMesh del dispersor tienen
  interpolación física desactivada, como en Vigo.

## Por qué había verde sin hierba dentro de las villas

Había dos exclusiones diferentes: el reparto horneado omitía el círculo entero
reservado para el arbolado de cada villa; después, al leerlo, se eliminaba
cualquier parche cuyo radio rozase una parcela de `VillageLayout.occupies`.
La reserva de una parcela no equivale a la planta ocupada por su casa.

Ahora se conservan los 220.000 registros de hierba del cache y se complementan
sus huecos urbanos con **1.555 parches** deterministas. Antes se descartaban
2.181 registros al cargar, de modo que se pasa de **217.819 a 221.555 parches**
en el mundo. El bosque y su cache de esquema 12 no se rehornean ni se mueven:
el complemento urbano es independiente de la distribución horneada.

Cada casa publica sus rectángulos de planta baja y el contorno de su rampa.
El dispersor rasteriza esas superficies, los caminos de acceso y las calles
en una máscara R8 de 4096² para la isla de 12 km: **16 MiB**, unos 2,93 m por
texel. Se consulta por raíz en las tres capas. El mapa de control del terreno
limita además la hierba al suelo verde. Las parcelas completas y los grandes
círculos de villa dejan de recortar las briznas. La prueba encuentra 107 casas
protegidas y 1.576 centros de parche permitidos a menos de 300 m de Villa Robledal.

## Medidas de esta sesión

**Nota del 8 de noviembre:** las utilidades antiguas creaban otra cámara sin
reenlazarla con Terrain3D. Sus medidas se conservan como controles históricos,
no como referencia de FPS con el detalle actual del terreno. Véase
[la corrección de entradas y hierba](ENTRADAS_Y_HIERBA.md).

Mac con Apple M2 Pro, Metal Forward+, utilidad `tests/grass_visual_capture.gd`.
Una sola ejecución gráfica a la vez. Misma selección de pradera y cámara.
No son medidas de toda la isla ni del ejecutable Windows.

| Configuración | FPS con hierba | Control sin hierba | Primitivas con hierba |
| --- | ---: | ---: | ---: |
| Antes: tarjetas y exclusiones amplias | 57,4 | 67,2 | 4.350.592 |
| Briznas altas, densas y villas, trabajo completo del shader, tanda 1 | 54,0 | 67,8 | 3.423.504 |
| Mismo control, tanda 2 | 53,9 | 66,1 | 3.423.504 |
| Briznas altas, densas y villas, shader optimizado, tanda 1 | 56,9 | 67,7 | 3.423.504 |
| Mismo optimizado, tanda 2 | 56,4 | 66,5 | 3.423.504 |

El cambio de shader recupera unos 2,7 FPS entre configuraciones con la misma
geometría. Frente al aspecto original se sostiene aproximadamente el rendimiento
con más altura, densidad cercana y cobertura urbana; **no se afirma una mejora
general de FPS**. El coste restante también se ve en el control sin hierba.

La cámara elevada de Villa Robledal mide 48,0 FPS con hierba y 54,5 sin ella,
con 5,10 / 3,89 millones de primitivas y 3.286 / 3.250 dibujos respectivamente.
Son otra cámara y otra carga: no comparar directamente con la tabla de pradera.
La villa tiene margen de mejora en geometría y número de dibujos.

## Verificar

```bash
# Headless necesita un log escribible fuera de user:// en este sandbox.
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --log-file /private/tmp/senderos-vegetation-engine.log --path . --script res://tests/vegetation_test.gd
# Debe FALLAR: inyecta hierba dentro de las casas en la copia de la máscara.
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --log-file /private/tmp/senderos-negative-engine.log --path . --script res://tests/vegetation_test.gd -- --break-urban-mask
# Visual y A/B: ambas capturas incluyen otro control con las tres capas ocultas.
tools/runtime/Godot.app/Contents/MacOS/Godot --path . --script res://tests/grass_visual_capture.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --path . --script res://tests/grass_visual_capture.gd -- --grass-full-work
```

`vegetation_test.gd` ya forma parte del workflow de Windows. La inyección
`--break-urban-mask` falló en Puerto AlbaHouse00 como se esperaba; la prueba
normal pasó. Ahora comprueba
también briznas opacas, alturas, raíces compartidas, máscara en plantas y rampas,
parches urbanos libres y reutilización del búfer al viajar a la villa.
También pasaron `runtime_stability_test.gd` (dos viajes LOD) y
`combat_impact_test.gd` (impactos y efectos). El test de estabilidad compara
ahora instancias activas, no la capacidad reservada del búfer.

## Continuación de aventura y rendimiento

La siguiente pasada ya convierte los cuatro fondos decorativos en grutas
explorables y añade el ciervo de ámbar y luciérnagas nocturnas. Véase
[GRUTAS_Y_LUCES.md](GRUTAS_Y_LUCES.md). Las pruebas de recorrido detectaron
salidas bloqueadas por labios del techo y se corrigieron antes de entregar.

La pasada del 8 de noviembre mide el mundo completo, retiene la cartografía
y mejora la presentación de avatares a partir de las técnicas de red de Vigo.
Véase [RENDIMIENTO_Y_COOPERATIVO.md](RENDIMIENTO_Y_COOPERATIVO.md) para las cifras,
pruebas y pendientes de GPU, simulación distante y combate compartido.

## Cola de mejoras solicitadas

- [x] **Transiciones día ↔ noche (solicitadas el 7 de noviembre de 2026).**
  Corregido el salto de dirección de las sombras del sol y la luna mediante
  fundido de opacidad y sincronización atómica. Verificado en ambos sentidos
  con secuencias de cámara fija y 12.289 muestras; se conservan la noche,
  el día y un solo mapa direccional. Véase [LUZ_Y_CPU.md](LUZ_Y_CPU.md).
