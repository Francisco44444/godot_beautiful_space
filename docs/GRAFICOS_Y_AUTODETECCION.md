# Gráficos ajustables y detección del equipo

## Problema y alcance

El equipo comunicado por el jugador es un i7-8700, 16 GB de RAM y una GTX 1060 de
3 GB, con unos 10 FPS a 2560×1440. No se ha medido físicamente ese PC. Los datos
siguientes son del Mac M2 Pro, Godot 4.7.1, Metal y Forward+.

Un bosque estilizado puede seguir siendo caro: la vista medida dibuja unos
4,80 millones de triángulos visibles y otros 2,54 millones en sombras. La hierba,
el horizonte, el sombreado por píxel y el posprocesado cuentan aunque cada
objeto individual sea low-poly. No hay evidencia nueva que permita atribuir
esos 10 FPS de Windows a un script concreto.

Esta versión añade controles reales y perfiles reversibles. Reducir resolución,
densidad, distancia de sombras o efectos cambia la calidad: las ganancias entre
perfiles no se presentan como una optimización de aspecto idéntico.

## Uso

En `Esc → Gráficos` o `Z` se puede elegir Automática, Alta, Equilibrada,
Rendimiento o Personalizada. Automática es el valor inicial en Windows y Mac. «Detectar configuración del equipo» vuelve a medir;
hay que cerrar los menús y jugar unos segundos. El objetivo automático puede
ser 60, 90 o 120 FPS; es una preferencia, no una garantía.

Ambos paneles comparten y guardan:

- Pantalla completa o ventana y resolución de ventana.
- Límite de FPS: 30, 60, 90, 120, 144, 200, 240 o sin límite; VSync independiente.
- Escala 3D personalizada entre 35 y 100 %, con interfaz a resolución completa.
- Sombras desactivadas o atlas de 1024, 2048 y 4096; distancia de 50 a 480 m.
- Densidad de pradera al 50, 75 o 100 %, manteniendo altura, color y viento.
- Horizonte de árboles entre 2 y 5,2 km y distancia de detalle entre 180 y 900 m.
- Niebla volumétrica desactivada, ligera o completa.
- SSAO y resplandor por separado; suavizado desactivado, FXAA, MSAA 2× o 4×.

Cambiar un detalle selecciona Personalizada y cancela la calibración pendiente.
Alta recupera el aspecto completo. Por defecto el límite es 120 FPS para evitar
trabajo sin límite; se puede cambiar. El panel muestra el nombre de la GPU que
Godot está utilizando y permite copiar un diagnóstico con API, salida, escala,
FPS y opciones. No envía datos automáticamente.

| Perfil | Escala 3D a 1440p | Sombras | Pradera | Efectos |
| --- | --- | --- | --- | --- |
| Alta | 100 % | 4096, 480 m, 4 cascadas | 100 % | Completos |
| Equilibrada | 77 % | 2048, 180 m, 2 cascadas | 75 % | SSAO y resplandor; niebla ligera |
| Rendimiento | 50 % | 1024, 100 m, 2 cascadas | 50 % | Sin SSAO, resplandor ni niebla volumétrica |
| Mínima automática | 37,5 % efectivo | Sin sombras | 50 % | Sin SSAO, resplandor ni niebla volumétrica |

Equilibrada mantiene el horizonte de 5,2 km y detalle hasta 260 m. Rendimiento
lo limita a 3,2 km y detalle hasta 180 m. La reconstrucción usa MetalFX espacial
cuando está disponible y FSR1 en el otro caso. Los perfiles existentes conservan
su mínimo de entrada de 1280×720; la escala personalizada permite 960×540 como
mínimo. Por eso en una ventana pequeña la escala efectiva puede superar la
solicitada. El control muestra la escala efectiva y se actualiza al redimensionar.

## Cómo se mide y se guarda

`configuracion_visual.gd` aplica cambios por señales, sin recorrer el bosque o
los materiales por fotograma. El ciclo solar respeta la opción de sombras en
las dos luces, por lo que el relevo sol/luna no vuelve a activarlas.

La calibración empieza en Equilibrada, deja calentar el render y recoge el
percentil 75. Sólo toma muestras con el juego en primer plano, sin pausa,
menús, mapa ni diálogo; descarta tirones de carga de más de 500 ms. Cuando el
motor ofrece tiempos GPU se usan junto al trabajo CPU. En esta versión Metal
ha devuelto cero para el temporizador GPU: se usa entonces el tiempo entre
fotogramas, distinguiendo la espera deliberada de VSync y del límite de FPS.
Una pantalla limitada a 60 Hz o un límite elegido de 30 FPS no bastan para
clasificar el equipo como lento. Sin información GPU tampoco se asciende a Alta
por una falsa lectura de coste cero.

El resultado se guarda por GPU, renderizador, sistema, tamaño de ventana,
objetivo y versión. El último escalón automático añade sombras desactivadas,
horizonte de 2 km y escala solicitada de 35 %, respetando el mínimo interno de
960×540; a 1440p supone 37,5 %. Al cambiar el tamaño se espera a que termine el arrastre
antes de medir otra vez. La calibración por fotograma se desactiva al acabar. Un temporizador de un
segundo mantiene la vigilancia durante la partida, también al arrancar con una
configuración guardada. Cuenta fotogramas realmente dibujados y tiempo real.
Baja un escalón si al menos el 80 % de una ventana de seis segundos queda por
debajo del 98 % del objetivo (tolerancia para no confundir 59,9 con falta de
potencia). Después espera ocho segundos antes de acumular una nueva ventana.
No acumula pausas, menús, pérdida de foco ni bloqueos de carga. Respeta un límite
voluntario de FPS o la frecuencia con VSync; tampoco sube y baja la calidad
continuamente. Si se alcanza Mínima y el equipo sigue lento, lo indica sin
prometer unos FPS que el hardware no puede dar. Elegir un ajuste manual detiene
la vigilancia. La lógica pura de muestreo mide aproximadamente 1,62 microsegundos
por llamada en el Mac, sin contar el resto del callback ni el renderizado. Los scripts de pruebas no arrancan una calibración
implícita; una sonda nativa sí verifica el botón explícito.

La configuración pasa al esquema 3. Se conserva una resolución de 1280×720
escogida en el esquema 2; sólo el antiguo valor inicial del esquema 1 se migra a
1600×900. Los campos nuevos inválidos o no finitos se acotan o recuperan un valor
seguro.

## Mediciones del 15 de noviembre de 2026

Salida real 2560×1440, sin VSync ni límite, cámara y hora diurna fijas. El mundo,
los enemigos, las animaciones y el HUD siguen activos. El héroe permanece inmóvil
e inmune: se comprueban posición y 100 puntos de vida para excluir reapariciones.
Cada variante calienta 80 fotogramas y mide 120 realmente dibujados; al terminar
se repite Alta como control. No se ejecuta otra prueba Godot simultáneamente.

| Vista | Alta: FPS / p95 ms | Equilibrada: FPS / p95 ms | Rendimiento: FPS / p95 ms | Alta repetida: FPS |
| --- | --- | --- | --- | --- |
| Villa | 53,5 / 20,6 | 77,9 / 15,9 | 113,7 / 11,2 | 53,8 |
| Bosque | 40,8 / 26,6 | 51,5 / 21,3 | 78,3 / 15,8 | 39,9 |

Los triángulos de sombra en el bosque bajan de 2,54 millones a 0,61 y 0,34
millones, respectivamente. En una medición aislada, dejar sólo la mitad de
briznas reduce los visibles de 4,81 a 3,94 millones: el índice cambia geometría
real y no se limita a ocultar píxeles en el shader.

La densidad modifica sólo el índice del `ArrayMesh`, conservando su RID,
búferes de posición, raíces, colores, altura y límites de viento. Los parches,
los árboles, sus identificadores persistentes y las colisiones no se regeneran.
Al volver al 100 % se recuperan las superficies originales completas.

También se ejecutó la autodetección real en el bosque con límite de 60 FPS:
Equilibrada midió 19,83 ms de p75 y Rendimiento 16,83 ms, seleccionándose este
último. Se verificó que no acumula muestras con Esc abierto, que persiste la
huella y que una elección manual detiene el proceso.

Las capturas de Esc y Z a 1280×720 muestran controles desplazables y botones
accesibles; se revisaron además los tres perfiles de día y de noche, con las
luciérnagas presentes. Registros, JSON y capturas quedan localmente en
`generated/reviews/2026-11-15/`.

## Comprobaciones y límites

`graphics_quality_test.gd` verifica decisiones con y sin temporizadores GPU,
VSync, límite a 30 FPS, saturación CPU, presentación lenta, percentiles,
validación, migración y escala personalizada. `graphics_controls_test.gd`
comprueba ambos menús, persistencia, índice y RID de hierba, sombras de sol y
luna, efectos, MSAA, límite de FPS, LOD sincronizado y recuperación de Alta.
Las dos pruebas y `adaptive_graphics_test.gd`, que comprueba la vigilancia
continua, se incluyen en la compilación automática.

Se inyectan fallos de VSync, densidad, sombras, control LOD y horizonte y se comprueba que fallan por el
aserto previsto, con restauración posterior. La prueba de controles se ejecuta
también con la GPU nativa. Las regresiones cubren pradera, vegetación, cielo,
transición celeste, ajustes, actividad LOD y cooperativo entre procesos reales.

Los FPS del Mac no predicen los de la GTX 1060. El objetivo general de 100–120
FPS sigue pendiente, especialmente a 1440p nativos en bosque. La siguiente
medición de Windows debe incluir el diagnóstico del juego para confirmar GPU,
API, escala efectiva y opciones; no se presupone que esté usando la GTX.


### Comprobación de la vigilancia continua en 0.1.28

Se recorre el arranque con la huella del equipo guardada y se comprueba que el
temporizador queda activo sin pulsar Detectar. En una ventana real del Mac se
simula una caída a 10 FPS usando un límite de prueba externo a los ajustes:
no degrada con Esc pausado, baja de Equilibrada a Rendimiento al jugar y conserva
ese nivel cuando se retira la limitación y la ventana recupera unos 114 FPS.
Una segunda caída llega a Mínima; el descenso queda acotado, el aviso se retira
al recuperarse y un ajuste manual detiene el temporizador. Esta simulación
verifica decisiones, no demuestra una mejora de 10 a 114 FPS causada por la
calidad ni mide el PC Windows. Se revisaron las capturas del nivel mínimo y del
estado automático; los datos quedan en `generated/reviews/2026-11-15/vigilancia-continua/`.

Las pruebas adicionales detectaron siete defectos inyectados: descenso
prematuro, descenso omitido, tirón aislado, pausa ignorada, pérdida de una caída
que cruza ventanas, nivel guardado recortado y modo inicial manual.
