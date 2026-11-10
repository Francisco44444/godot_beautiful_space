# Senderos del Horizonte

Aventura medieval en tercera persona construida con Godot 4.7, GDScript y Terrain3D. La dirección visual del juego es ahora coherente con los packs estilizados CC0 de Quaternius: protagonista, caballo, fauna, bosque, plantas, rocas y arquitectura comparten el mismo lenguaje artístico.

## Estado actual

- Cuatro grutas subterráneas explorables con ruinas medievales, rampas y taludes de césped, cámaras enlazadas, voces de Aeloria y relicarios secretos persistentes.
- El ciervo de ámbar: una cinta al noreste de Puerto Alba inicia un recorrido nocturno entre luces; el ciervo espera si te retrasas y se despide entre destellos al llegar al claro. Luciérnagas en los bosques de noche, animadas en GPU. [Diseño, pruebas y límites](docs/GRUTAS_Y_LUCES.md).

- Protagonista animado de Quaternius, seleccionable entre ocho aventureros, con piel recoloreada a un tono humano y animaciones de reposo, caminar, correr, saltar y atacar.
- Biblioteca local completa de 50 personajes glTF del *Ultimate Animated Character Pack*.
- Perfil de jugador persistente con nombre y ocho héroes Quaternius seleccionables al entrar o desde `Z`.
- Inventario persistente con todos los objetos del *Ultimate RPG Items Pack*: armas sustituibles, armaduras, llaves, pociones, libros, minerales, monedas y tesoros. Sólo se incorporan los cinco escudos del *Medieval Weapons Pack*.
- Barra rápida de aventura: `1` espada, `2` hacha, `3` arco y `4` antorcha. Cada objeto se sujeta por su empuñadura real dentro del hueso de la mano, así que acompaña al brazo en toda la animación.
- Combate cuerpo a cuerpo con carga: un clic corto da un tajo; mantener el botón alza el arma y desata una tormenta —el viento arrecia sobre hierba y copas, el cielo se apaga y caen rayos sobre el filo, cada vez más seguidos— hasta que al soltar estalla un ataque giratorio de 360°. La tormenta acompaña al giro y se disipa con él, y su oscurecimiento se aplica como un factor que consume el ciclo día/noche a través del grupo `atmosphere_storm`: escribir el sol directamente no servía, porque el ciclo lo recalcula cada fotograma y borraba el efecto que golpea todo lo que rodea al héroe y tumba la hierba de todo el ruedo. La tormenta guarda los valores originales del sol y del entorno y los restituye al terminar, así que un ataque interrumpido no deja el mundo a oscuras. La postura de recarga **no sale de ningún fotograma de la biblioteca**: se construye. El brazo se extiende al **costado derecho** con el codo algo flexionado —160°, medido: recto del todo se leía como una tabla— y el filo toma la misma dirección, así que brazo y hoja alargan la silueta 2.8 m del hombro a la punta, horizontales. El brazo libre acompaña: su húmero cae **paralelo al eje del tronco inclinado** —se calcula a partir del propio ángulo de inclinación, así que lo sigue solo— con el codo abierto al costado, El codo se abre 0.30 m del eje del hombro, así que el húmero se despega de la axila y el brazo queda **en ala**; el antebrazo sube separado del cuerpo apuntando 40° a su izquierda, con el puño 0.54 m por delante del héroe y 0.66 m a su costado, a la altura del pecho: brazo en tensión. Húmero y antebrazo reciben cada uno su propia dirección, en dos tramos: doblar el codo con un ángulo sobre un eje no daba posiciones intermedias —el puño saltaba de pegado al torso a un brazo de distancia sin nada en medio— y hacía falta poder colocarlo. Apuntando el húmero al costado el brazo salía recto y el héroe quedaba en cruz. Y el tronco hace dos cosas: se inclina 20° y **gira hacia su derecha**, retrasando el hombro armado 0.12 m respecto al libre, que es como se recoge la fuerza antes de soltarla. La descarga es un **salto**: el héroe se eleva 0.69 m, se va hacia su derecha, completa la vuelta en el aire y aterriza justo al cerrarla —a los 0.70 s, con el remolino en 0.78 s—, con su amortiguado de caída. El remolino conserva la misma postura de la carga: lo que barre el círculo es el giro del cuerpo, no un movimiento del brazo. Antes tomaba prestado un fotograma de la biblioteca al soltar y el arma se iba hacia arriba justo en el gesto que el jugador está mirando; ahora el filo no se desvía ni 12° entre la carga y el giro, y la prueba lo comprueba fotograma a fotograma. Se probaron antes tres fotogramas de la biblioteca y ninguno servía: el 2.50 de `Sword_Heavy_Combo` deja el codo a 120° y el brazo se lee como una L; el 0.30 de `Sword_Regular_A` lo deja a 156° pero cruzando por detrás del hombro, donde atravesaba 0.23 m el escudo colgado; y estirar el brazo entero en vertical lo dejaba como una tabla. Construida a mano, la postura sale exacta y el filo se mantiene donde se le pida con cualquier ajuste del brazo, porque la muñeca se corrige en último lugar. Solo se transfiere el brazo armado —hombro, codo y muñeca—: al pasarle también la columna, el retargeting doblaba el tronco medio metro, mucho más que los 0.23 m del fotograma original, y el héroe quedaba plegado por la mitad. El agachado se pone aparte, con una flexión explícita del abdomen de 15° que adelanta la cabeza 0.34 m y la baja 0.23 m: un solo número que ajustar y un resultado medible. El orden de las correcciones importa: primero la flexión del tronco —que arrastra el hombro—, luego el estirado del brazo, y por último la alineación del arma, que es la última palabra sobre la muñeca. Al revés, cada giro del brazo desviaba el filo tantos grados como midiese. Como nada de eso toca las piernas, los pies siguen dando pasos —más lentos— mientras acumula fuerza. El vendaval tiene su propio término de doblado en los shaders de hierba y de árbol (`storm_bend`): subir `gust_strength` no servía, porque ese factor solo actúa en la cresta del ciclo natural de rachas, que llega una vez por minuto, y durante una carga de dos segundos la vegetación no se movía —0.05 m de barrido en la hierba y 0.09 m en las copas—. Ahora la tormenta barre 0.52 m la hierba y 0.88 m las copas, medidos.
- Animaciones de la *Universal Animation Library 2* retargeteadas al rig de Quaternius mediante [library_animation.gd](scripts/library_animation.gd). La biblioteca usa un esqueleto de estilo Unreal (`upperarm_r`, `hand_r`, `spine_02`…) con otra pose de bind, así que no se copian rotaciones: se transfiere el *delta global* de cada hueso respecto a una pose de referencia equivalente en cada rig (`Idle_No_Loop` en la biblioteca, `Idle` en el héroe). Solo se aplica el tren superior, de modo que las piernas siguen con la locomoción propia y el héroe puede atacar en movimiento. Las 43 animaciones de la biblioteca están importadas y disponibles sobre el héroe, catalogadas en `Player.GESTURES` con su ritmo y con si se apoderan del tren inferior; cualquiera se puede pedir por nombre con `play_gesture()`. Las que tienen un disparo natural salen solas: los tajos alternos (`Sword_Regular_A` y `B`), la guardia con escudo (`Idle_Shield_Loop`) o con espada cuando no hay escudo (`Sword_Block`), la tala con el hacha (`TreeChopping`), el gancho a mano desnuda (`Melee_Hook`), el golpe recibido (`Hit_Knockback`, o `Idle_Shield_Break` si estaba cubriéndose), abrir un cofre (`Chest_Open`), recoger una reliquia (`Farm_Harvest`), asentir al hablar con un habitante (`Yes`), la antorcha en alto al detenerse (`Idle_Lantern`) y los brazos cruzados tras unos segundos quieto (`Idle_FoldArms`). El resto —deslizamientos, saltos de la biblioteca, trepada, faenas de campo, gestos de conversación y las poses de criatura— quedan en el catálogo a la espera de la mecánica que las pida. Dos que se probaron y se descartaron: el tercer tajo (`Sword_Regular_C`) hacía girar al héroe sobre sí mismo como si no tuviera tronco, y el arco de salto de `NinjaJump_*` se ha retirado en favor del salto propio del personaje. Los gestos de reposo **no** desactivan la corrección de muñeca —la necesitan—: sin ella la antorcha quedaba de canto y apuntando al frente, y solo se veía su sombra. Y esa corrección es **completa** para la antorcha, no parcial como para la espada: una antorcha se lleva a plomo, quieto o andando, y al 62% se quedaba a medio camino entre la vertical y lo que dijera el brazo. Medido: 0.0° de la vertical quieto, andando en cualquier punto de la zancada, corriendo y con el gesto de reposo, con la llama siempre a más de 0.70 m de la cabeza. La espada conserva la corrección parcial, que es lo que le deja acompañar el braceo. `Skeleton3D` procesa sus modificadores en **orden de árbol**, no por `process_priority`: la biblioteca tiene que nacer antes que el corrector del brazo o le borra la flexión del tronco y la corrección de muñeca.
- Porte medieval del equipo: el escudo redondo de madera cuelga de la espalda y el botón derecho lo pasa al antebrazo —desapareciendo de la espalda— para cubrirse, reduciendo el daño recibido. La tabla se adelanta 0.46 m a la mano a lo largo de su propio eje frontal, así que el puño queda 0.26 m por detrás de su cara trasera y no ensartado en ella. Al cubrirse el héroe se encoge: una flexión explícita del abdomen adelanta la cabeza 0.35 m tras el escudo, porque `Idle_Shield` lo deja completamente erguido —0.01 m, medido— y no se leía como protección. Correr un rato sin combatir envaina el arma a la espalda, sobre el escudo, y volver a atacar la desenvaina y encadena el golpe. El arma no se teletransporta: el brazo la lleva. Mientras la malla viaja al agarre trasero se recorre el arranque de `Sword_Regular_A`, que sube la mano 0.41 m y la echa 0.71 m hacia la espalda, y al revés al desenvainar. Solo se toca el brazo armado, así que el héroe puede seguir corriendo mientras la guarda, que es justo cuando ocurre. Cambiar de arma manda la anterior a la espalda mientras se saca la nueva desde allí.
- Esquiva lateral: con la tecla de esquiva mantenida el héroe se mueve de costado sin girar el cuerpo, y saltar en ese momento lanza una voltereta hacia el lado pulsado.
- A caballo el jinete acompasa su postura a la zancada real de la montura —lee su fase y su marcha— y sujeta las riendas con las dos manos: al galope se levanta de la silla y se echa adelante.
- En el desierto pasa **una brisa de polvo cada tanto**: rachas de unos cuatro segundos separadas por diez o quince, que arrastran arena a ras de suelo alrededor del héroe con una campana de entrada y salida y una dirección distinta cada vez. Entre racha y racha no hay nada —una nube permanente se leería como niebla, no como viento— y fuera del desierto no aparece: el bioma lo resuelve `VegetationScatter.biome_at()`. El polvo es pálido, no del color de la arena: del tono del suelo no se distinguía sobre las dunas. Y cada mota lleva un degradado radial, porque sin él las partículas eran rectángulos de bordes duros y el efecto se leía como un puñado de cartas volando. [desert_breeze.gd](scripts/desert_breeze.gd) **no** escribe el viento de la vegetación: ese canal lo gobierna la tormenta de la fuerza especial, y compartirlo acabaría en el mismo enredo que tuvo el sol con el ciclo día/noche.
- Y **remolinos de arena** recorriendo las dunas, que es lo que le da inquietud a un bioma que por lo demás es una extensión quieta. El embudo es geometría propia y facetada —anillos de siete lados apilados, 126 triángulos— y no un billboard, así que gira de verdad; se retuerce más de una vuelta completa en sus catorce metros de altura, cada anillo mete su propio mordisco al radio para que no salga un cono perfecto, y cada cara lleva su tinte: sin ese contraste entre facetas contiguas la geometría se leía lisa. Va teñido con la arena del propio bioma —la duna mide R=1.00 G=0.82 B=0.39 en pantalla— y arrastra arena suelta en la base. Nacen solo sobre terreno de desierto, hasta tres a la vez, se desplazan sobre la duna y se deshacen; y se retiran si el héroe se aleja. [dust_devil.gd](scripts/dust_devil.gd)
- La carga de la fuerza especial levanta un torbellino alrededor del héroe, así que el ventarrón se ve también sobre piedra o lejos de los árboles, no solo donde hay vegetación que doblar. Lo que arrastra depende del bioma, que resuelve `VegetationScatter.biome_at()` con los mismos criterios que reparten la vegetación: hojas verdes en el valle, hojas oscuras en el Bosque Tenebroso, brisa blanca en la nieve y polvo en el desierto. **Nada de la tormenta arranca con un clic**: por debajo de un umbral de carga —0.34, unas dos décimas de mantenido— no hay viento, ni oscurecimiento, ni rayos, ni restos. La intensidad entraba antes con una curva acelerada y el primer fotograma de cualquier tajo ya movía la hierba y apagaba el cielo. Medido: un clic de hasta 0.17 s deja el viento en 0.000 m y la luz intacta; manteniendo, el vendaval entra a los 0.27 s y llega a 0.52 m a los 0.67 s. La carga no lleva barra: la propia tormenta indica cuánta fuerza se acumula.
- Interfaz unificada en `scripts/ui_theme.gd`: una sola paleta y unas fábricas de estilo comunes para pantalla de carga, menú de pausa, ajustes, vestíbulo, barra rápida, inventario, diario y avisos. Antes cada panel construía su propio recuadro con una docena de ámbares distintos y bordes de grosores dispares. El mapa conserva su estilo propio.
- El braceo del paseo se conserva íntegro con el arma en la mano: solo la muñeca recibe una corrección parcial (`weapon_carry_stabilization`) para que la espada bascule con el paso sin dar bandazos. Sin ella el arma se movía 36° por zancada; con corrección total quedaba clavada al mundo y perdía toda la vida.
- El arco se tensa manteniendo el clic, activa una cámara de hombro diagonal y **dispara al punto exacto de la retícula**: la flecha sale elevada, con el ángulo de tiro bajo que compensa la caída —`tan(θ) = (v² − √(v⁴ − g(g·d² + 2h·v²))) / (g·d)`—, porque disparando en línea recta acababa muy por debajo del punto marcado: a 179 m de la retícula caía 151 m, medido, y el punto de mira no indicaba nada. Mientras se apunta, una marca de impacto sustituye a la retícula del centro y se coloca donde la flecha va a clavarse de verdad, integrando la misma parábola y trazando el terreno; se pone ámbar cuando llega justo al punto apuntado y frío cuando se queda corta, así que el alcance se lee sin ningún número. El alcance es `v²/g`: entre 64 m con un toque y 219 m a tensado completo. Un clic corto también dispara, con menos potencia. Toda la línea de tiro —ancla, flecha y empuñadura— es colineal y vive al costado del arco, de modo que el disparo no queda oculto detrás del torso. La flecha describe una parábola visible, deja una cinta continua construida en coordenadas del mundo que dibuja la dirección del disparo, y se queda clavada siete segundos donde impacta. La cámara de puntería sigue puesta un instante tras soltar para poder seguir el vuelo.
- Caballo animado de Quaternius con reposo, paso y galope; jinete sentado sobre la silla y montaje reversible.
- Fauna Quaternius repartida entre el mundo y 23 retos de bestiario, con alpacas, toros, vacas, ciervos, burros, zorros, caballos, perros, venados y lobos.
- Cámara orbital abierta: 10 m a pie y 16 m al montar, con transición suave y mayor campo visual.
- Mundo Terrain3D de 12×12 km —144 km²— dividido en 100 regiones de 256² puntos, con costa asimétrica, península oriental, cordillera nevada, desierto, praderas, riscos y diez caminos conectados.
- Cinco tiles originales low-poly: pradera, sendero, roca, arena y nieve, sin microdetalle PBR fotográfico.
- Bosque masivo de 52.000 árboles Quaternius, ahora un 32% más altos: una retícula irregular de 54 m garantiza cobertura sobre 7.755 celdas verdes y el resto del presupuesto forma reservas profundas y acompaña rutas. Los ejemplares azul petróleo forman el Bosque Tenebroso y los árboles rojos quedan por debajo del 1%. En la cordillera, los pinos pasan gradualmente de verdes a mixtos y finalmente blancos según la altura.
- Hierba de briznas opacas adaptada de Duelo de Sables: un triángulo por hoja, altura cercana de 0,90–1,34 m antes de escala y 12.000 briznas por parche cercano. Comparte el albedo GPU, el tinte y el mapa de color de Terrain3D; conserva viento, pisada y reacción al combate. Tres capas con densidad por distancia y búferes reutilizables. Las zonas verdes de las villas también tienen hierba; las plantas de las casas, rampas y calles se protegen con una máscara de 16 MB. [Diseño y verificaciones](docs/HIERBA_Y_RENDIMIENTO.md).
- Los diez caminos entre regiones son de tierra. `quaternius_rock` queda reservado para dos calles interiores entre las casas de cada villa grande: se pinta en Terrain3D sustituyendo la hierba, con una variante UV compactada y sin cintas ni piedras 3D superpuestas.
- Todos los grupos numerosos usan `MultiMesh` dividido en celdas espaciales con ancla y AABB propios. Los glTF/OBJ se cargan mediante el importador de Godot y el umbral LOD del `Viewport` gobierna sistemáticamente personajes, fauna, edificios, objetos y decorado. Árboles y hierba añaden reemplazos explícitos por celda: malla completa o proxy, nunca ambas. Los árboles lejanos usan una silueta facetada de 31–94 triángulos, sin sombras, visible hasta 5,2 km.
- Seis villas y ocho caseríos rurales con 54 casas de unos 12,4×21,7 m y 4,8 m por planta; diez tienen tres plantas. Todas poseen acceso a ras del terreno y escaleras `Stair_Interior_Simple` que cambian de lado en cada planta. Peldaños y pasamanos comparten exactamente inicio, final e inclinación; una cuña física invisible enlaza las superficies de ambos pisos —también en planta baja—, sin rampas ni placas visuales superpuestas.
- Tres castillos monumentales de 126 x 100 m construidos con `Modular Medieval Buildings - Jul 2017`: murallas de 18 m, cuatro torres exteriores, dos portones con rampas continuas desde el terreno y una torre-palacio escalonada de diez plantas, 40 estancias, diez zonas temáticas y tres torres de hasta 70 m. Sus 18 tramos de escalera alternan el sentido planta a planta y mantienen sus ejes libres de arcos decorativos. La décima planta es una `Torre Mirador` abierta al cielo, sin tejado ni fachadas, con terraza panorámica y cuatro parapetos físicos. Las demás torres usan colisión exacta sobre su malla, sin cajas sólidas invisibles en arcos o interiores.
- Risco y fortaleza estilizados con módulos Quaternius; la cascada, poza y río han sido retirados.
- Ciclo completo de día, atardecer y noche con una luna low-poly de 176 m, textura original de cráteres, iluminación y sombras; durante el día se retira por completo del render para evitar artefactos negros. Las sombras se desvanecen antes del relevo sol/luna y aparecen gradualmente después, conservando un solo mapa direccional. [Secuencias visuales y ahorro de CPU de vecinos](docs/LUZ_Y_CPU.md).
- Mar low-poly animado rodeando la isla, playas facetadas y seis bancos de niebla regional en bosques y zonas tenebrosas; solo se procesan los dos más cercanos que correspondan a la posición y altura de la cámara. Al subir la marea, jugador y caballo son empujados de forma progresiva hacia la cota seca más próxima para que una ría no pueda dejarlos atrapados.
- Cartografía retenida: el marcador y el objetivo se actualizan cada frame y el relieve se reconstruye cuando cambia. La cámara medida de Villa Robledal pasa de 51,7 a 60,7 FPS con la misma calidad. Los compañeros remotos usan muestras con hora, búfer adaptativo y animaciones de suelo/salto sincronizadas. [Mediciones, pruebas y trabajo pendiente](docs/RENDIMIENTO_Y_COOPERATIVO.md).
- Descarte individual del color y las sombras de los árboles completos en Forward+, con sus índices de tala conservados. La pasada de sombras mejora un 8,8–9,4 % Puerto Alba y un 2,3–2,6 % Villa Robledal en las cámaras medidas del Mac. [Mediciones y comparaciones de día y noche](docs/SOMBRAS_DEL_BOSQUE.md). El objetivo de 100–120 FPS sigue pendiente.
- El selector LOD evita recorrer las celdas otra vez cuando el foco sigue quieto. [Auditoría de scripts, nodos y mediciones de CPU](docs/AUDITORIA_SCRIPTS.md): unos 0,6–0,8 ms menos de GDScript por fotograma en las vistas en reposo; el siguiente trabajo sigue en vecinos distantes y render.
- Descarte de hierba por parche con límites del relieve, identidades estables y reserva de instancias: alrededor de un 6 % más de FPS en las cámaras medidas de Puerto y bosque, conservando la vegetación. [Resultados, imágenes y límites de estabilidad de la villa](docs/HIERBA_POR_PARCHES.md).
- Oclusión estática de las 107 viviendas respetando puertas, ventanas y escaleras: +5,4 % de FPS en la villa en movimiento y +32,9 % en el interior medido. [Mediciones, comprobaciones visuales y límites](docs/OCLUSION_EDIFICIOS.md).
- Descarte por cámara de los árboles secos con sombras completas: alrededor de un 12–14 % más de FPS en las cámaras medidas del Bosque Tenebroso. [Resultados y ensayo de oclusión entre copas](docs/OCLUSION_BOSQUE.md).
- Las laderas ocultan objetos tapados por el terreno mediante un recurso horneado que respeta las grutas. [FPS, imágenes y pruebas de invalidación](docs/OCLUSION_TERRENO.md).
- Detalle automático individual para evitar el exceso dentro de grupos de árboles grandes y VSync configurable desde ambos menús. [Mediciones y controles gráficos](docs/DETALLE_DE_ARBOLES_Y_VSYNC.md).
- Recepción cooperativa de recursos por cambios: conserva golpes y caídas y evita reconstruir las colisiones del bosque a cada estado. [Coste del receptor y tala entre dos procesos](docs/RECURSOS_EN_COOPERATIVO.md).
- Colisiones de troncos por celdas para reducir los bloqueos al talar y restaurar, conservando sus triángulos originales. [Tiempos de actualización y fotogramas](docs/COLISIONES_LOCALES_DEL_BOSQUE.md).
- Grutas con física activa para invitados lejanos y flechas que distinguen la bóveda del terreno. [Pruebas entre procesos, coste y límites](docs/GRUTAS_EN_COOPERATIVO.md).
- Puertas de las cuatro grutas compartidas: un compañero con su propia llave abre el acceso para la expedición y los invitados que se incorporan después. Confirmación fiable, restauración y rechazo de estados antiguos. [Pruebas ENet, coste y límites del progreso compartido](docs/PUERTAS_EN_COOPERATIVO.md).
- Cortezas opacas sin recorte de hojas, conservando vegetación, sombras y viento. [FPS y comparaciones visuales](docs/OPACIDAD_DE_LA_CORTEZA.md).
- Portadas unidas a la gruta mediante piedra continua, remate contra el terreno y antorchas; hierba lejana fina y relevo cercano a 16–28 m. [Causas de los huecos azules, pruebas y coste medido](docs/ENTRADAS_Y_HIERBA.md).
- Estados cooperativos comprimidos sin pérdida y repartidos en bloques de hasta 1.000 bytes, con recepción completa y rechazo de estados antiguos. [Tráfico medido y pruebas ENet](docs/RED_ESTADOS.md).
- HUD despejado con el minimapa activo al comenzar: `N` alterna la leyenda de controles, `B` el minimapa, `M` el mapa completo, `0` los créditos y `Z` abre la configuración. El panel Z pausa la partida, muestra todas las asignaciones, ofrece cuatro resoluciones, VSync y distancia de detalle entre 180 y 900 m. Se puede desplazar para acceder a todos los controles a 720p.
- Menú de pausa completo con `Esc`: continuar, guardar, cargar partidas, controles, gráficos, sonido, multijugador y salir. `Esc` cierra primero la ventana actual y retrocede por los submenús antes de reanudar el juego.
- Guardado automático de posición, orientación, inventario, equipo, flechas, retos explorados, hora, marea y caballo. En solitario se restaura automáticamente el último punto; en cooperativo el anfitrión guarda cada dos minutos una ranura identificada por los nombres de los jugadores y conserva por separado los objetos de cada héroe.
- Inventario visual en cuadrícula con iconos, cantidades y equipo resaltado. La barra de aventura es compacta y la barra rápida usa botones con los iconos reales del arma; `H` llama al caballo.
- Diario de 200 desafíos de aventura: visitas a casas, aldeas y castillos reales, descubrimiento de animales, cofres, tala, minería de rubíes, reliquias, amanecer y atardecer. `L` abre la lista, `E` interactúa y cada logro autoguarda; al elegir una entrada, el mapa señala su destino.
- Cooperativo ENet para un anfitrión y hasta siete invitados. El Synology mantiene un tablón HTTPS de partidas activas con nombre, anfitrión, versión y ocupación; crear una expedición la anuncia con latidos y los invitados se unen con un clic, sin escribir la IP. La sala replica identidades, personaje elegido, posición, orientación, velocidad y objeto equipado. El anfitrión es autoridad de fauna, sol, luna y mareas, y distribuye ese estado a los invitados; `9` permite saltar directamente al Bosque Tenebroso durante las pruebas.
- Combate cooperativo con tajos y flechas resueltos por el anfitrión, armas propias, carga y giro, escudo y esquiva visibles en los compañeros. Enemigos y jefes pueden atacar a cualquier héroe de la expedición; las corazas y fases se sincronizan. Comprobado con dos procesos ENet reales. [Pruebas, medida de CPU y límites pendientes](docs/COMBATE_COOPERATIVO.md).
- Exportación Windows x86-64 con instalador ligero y lanzador de actualizaciones: consulta el manifiesto estable de GitHub Releases, verifica tamaño y SHA-256, cambia de versión de forma transaccional y conserva la última instalación válida si no hay conexión.
- Música adaptativa de FiftySounds: `The Hill that Knows your Voice` en el valle, `Promise` dentro de la zona nevada y `Ashes` en el desierto, con transiciones suaves y reproducción en bucle. Viento, pájaros y cuatro sonidos de cascos completan la mezcla; la atribución se consulta con `0`.

## Abrir y jugar

En macOS, haz doble clic en `Jugar.command` o ejecútalo desde Terminal:

```bash
./Jugar.command
```

El lanzador utiliza Godot 4.7.1 desde `tools/runtime/Godot.app`. Para abrir el editor:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --editor --path .
```

Dentro del editor, `F5` ejecuta el proyecto completo.

### Jugar en Windows

Descarga el **ZIP completo** desde la [web del NAS](https://franfuco4444.synology.me:24573/senderos/),
extrae todos sus archivos y abre `SenderosDelHorizonte.exe`. Mantén el ejecutable,
el `.pck` y la DLL de Terrain3D dentro de la misma carpeta.

Como alternativa, [SenderosDelHorizonte-Instalador.zip](https://github.com/Francisco44444/godot_beautiful_space/releases/latest/download/SenderosDelHorizonte-Instalador.zip)
incluye `Instalar.bat` y crea un acceso directo que comprueba las actualizaciones
antes de abrir el juego. La versión alfa no está firmada y Windows puede mostrar
SmartScreen; para una distribución pública habrá que firmar el ejecutable.

El lobby consulta `https://franfuco4444.synology.me:24568/v1` y muestra las
expediciones activas. Para jugar por Internet, el PC anfitrión aún debe permitir y
redirigir el puerto UDP `24567`; el NAS evita compartir la IP, pero no sustituye
el transporte ENet. Dentro de la misma red puede usarse la IP local desde el
apartado Avanzado. Esta primera capa todavía no incluye migración de anfitrión,
relay/NAT traversal ni sincronización autoritativa de futuras misiones.

### Publicar cambios sin compilar manualmente

La web de descarga de Senderos se prepara desde `website/` y se publica en la
carpeta `/senderos/` del NAS. Tras generar una release, se actualiza con
`bash tools/publicar_web_nas.sh VERSION --subir`.
[ZIP completo, copia verificada y publicación de la web](docs/WEB_DE_DESCARGA.md).

Después de editar el proyecto, haz doble clic en `PublicarCambios.command`. La
opción 1 sube un cambio y deja un ejecutable de prueba en GitHub Actions; la
opción 2 crea una actualización oficial que los lanzadores detectarán. GitHub
descarga Godot 4.7.1, prueba, exporta, calcula el SHA-256 y publica los archivos
sin utilizar este Mac para compilar. Consulta
[`docs/AUTOMATIC_BUILDS.md`](docs/AUTOMATIC_BUILDS.md).

## Controles

| Acción | Teclado / ratón | Mando |
| --- | --- | --- |
| Caminar | `WASD` o flechas | Stick izquierdo |
| Correr | `Mayús` | Pulsar stick izquierdo |
| Saltar (0.89 m, con caída más rápida que la subida) | `Espacio` | Botón inferior |
| Equipar espada / hacha / arco / antorcha | `1` / `2` / `3` / `4` | — |
| Cubrirse con el escudo | Mantener clic derecho | Botón lateral |
| Moverse de costado | Mantener `Ctrl` + `A` / `D` | Gatillo |
| Voltereta lateral | `Ctrl` + `A` / `D` + `Espacio` | Gatillo + salto |
| Tajo cuerpo a cuerpo (combo de tres) | Clic izquierdo corto, encadenando | Botón superior |
| Gancho a mano desnuda | Clic izquierdo sin arma equipada | Botón superior |
| Ataque giratorio cargado (con tormenta) | Mantener el clic hasta llenar la carga y soltar | Botón superior |
| Tensar y disparar el arco | Mantener el clic y soltar | Botón superior |
| Interactuar / explorar / montar / desmontar | `E` | Botón izquierdo |
| Abrir inventario | `I` | — |
| Galopar | `Mayús` + dirección | Stick + pulsación |
| Orbitar cámara | Mover ratón | — |
| Cerrar ventana / menú de pausa | `Esc` | — |
| Llamar al caballo | `H` | — |
| Mostrar / ocultar controles | `N` | — |
| Mostrar / ocultar minimapa | `B` | — |
| Abrir / cerrar mapa de la isla | `M` | — |
| Abrir / cerrar créditos y atribuciones | `0` | — |
| Abrir configuración gráfica | `Z` | — |
| Viajar a Dunas / Nieve / Villa / Bosque | `5` / `6` / `7` / `8` | — |
| Viajar al Bosque Tenebroso | `9` | — |
| Abrir diario de 200 desafíos | `L` | — |

La exploración ya no impone el antiguo objetivo del mirador; las rutas quedan libres para incorporar la futura historia. Si el personaje cae fuera del escenario, reaparece en el inicio.

## Dirección visual Quaternius

`VegetationScatter` carga los `PackedScene` importados del *Stylized Nature Mega Kit*, conservando materiales y los LOD generados por Godot. Los árboles adultos se reparten entre caminos, ocho reservas forestales y todas las praderas verdes; el Bosque Tenebroso añade una gran masa azul petróleo y los árboles retorcidos rojos no superan el 1% del total. Por defecto, cada celda cambia atómicamente del árbol completo a una silueta facetada a 340 m, y esta continúa hasta 5,2 km sin sombras. No hay intervalo de solapamiento ni referencias de distancia al origen del mapa. La hierba usa parches fijos con tres densidades de briznas triangulares opacas; el relevo se sortea por raíz en el mundo y los búferes cercanos se reutilizan al mover la cámara. El panel Z permite desplazar el corte común entre 180 y 900 m; al mismo tiempo ajusta `Viewport.mesh_lod_threshold` para todos los modelos importados. Un shader preserva los troncos y cubre de blanco las copas, helechos y arbustos de la alta montaña; la pradera se excluye de la nieve; una probabilidad continua crea una franja mixta a media altura y desaparece por completo en cotas bajas. La hierba conserva su movimiento base y las ráfagas. Los elementos cercanos a las rutas y una muestra del bosque profundo reciben colisiones simplificadas.

`MedievalSetDressing` monta seis villas, ocho caseríos, 54 casas y tres castillos. Cada vivienda parte de un módulo Quaternius 8×14 ampliado uniformemente a unos 12,4×21,7 m, con 4,8 m de altura por planta. Las 64 plantas superiores incorporan suelo visual y físico, un hueco ajustado, `Stair_Interior_Simple`, `Stair_Interior_Rails`, cuñas transitables invisibles y barandillas físicas alrededor del vacío. Los peldaños y pasamanos se escalan por separado a una longitud común entre forjados, eliminando `Stair_Interior_SolidExtended`, su lateral triangular y cualquier rampa o revestimiento visible bajo la escalera. Cada tramo alterna su sentido y una cuña convexa enlaza la cara superior exacta del piso inferior con la del superior, sin salto, placa ni bordillo. La primera planta utiliza expresamente la cota de cimentación o patio, distinta de los demás forjados. Todas las casas conservan paredes físicas independientes, dos hastiales completos y un hueco de puerta de 3,1 m realmente atravesable. Cada castillo ocupa un recinto de 126×100 m y contiene una ciudadela de diez pisos con dos escaleras protegidas por planta y aperturas limpias sin arcos sobre la trayectoria. La última planta queda abierta como `Torre Mirador`, con suelo completo, acceso por ambas escaleras, parapeto físico perimetral y cielo despejado. Su explanada se divide alrededor de dos corredores de portón, enlazados mediante rampas de piedra a ras del terreno, y las torres sustituyen las antiguas cajas macizas por colisiones trimesh que siguen sus huecos reales. La vegetación, incluidos los árboles secos de detalle, respeta las huellas de casas, patios y fortalezas. El antiguo hito de la cascada —incluidos sus tejados flotantes y su muro de rocas— se eliminó por completo.

Los personajes se encuentran en `assets/quaternius/ultimate_animated_characters/glTF`; el juego ofrece ocho opciones y sustituye en ejecución únicamente su material `Skin`, preservando ojos, cabello y ropa. Quedan disponibles aldeanos, trabajadores, vikingos, elfos, goblins, magos, piratas, ninjas y otras variantes para NPC futuros. Los animales viven en `assets/quaternius/ultimate_animated_animals`.

El catálogo de aventura se genera desde todos los OBJ de `Ultimate RPG Items Pack - Aug 2019`; los cofres y reliquias pueden entregar cualquiera de sus recompensas válidas. Espadas, hachas, arcos y escudos nuevos sustituyen automáticamente al modelo anterior de su categoría. La antorcha procede del *Survival Pack* y únicamente el objeto seleccionado aparece unido al hueso `Fist.R`; la brújula se ha retirado. La *Universal Animation Library 2* está en `assets/animations` y sus 43 movimientos se aplican al héroe por retargeting; la locomoción base sigue usando las animaciones del propio personaje, sincronizadas con su desplazamiento. Los ocho avatares del multijugador comparten rig —23 huesos, mismos nombres, misma pose de reposo y mismos ejes de mano—, así que agarres, IK, poses y gestos valen igual para el que elija cada jugador.

## Terreno y atmósfera

Terrain3D utiliza seis albedos originales en `assets/textures/stylized_terrain`: pradera, sendero ocre, roca con musgo, arena dorada, nieve alpina y caliza de cantil. Una séptima variante reutiliza `quaternius_rock` con escala UV 0,18 para las calles compactas. La caliza se asigna automáticamente a pendientes litorales superiores a 48° y a cualquier pared interior de 55° o más, evitando superficies verticales verdes; una barrera invisible de 4,6 m sigue las cornisas costeras, con pasos abiertos en los descensos transitables. Los diez caminos insulares usan `quaternius_path`; la piedra solo forma dos ejes cortos dentro de cada villa grande y sustituye el material de hierba en el mapa de control. No existe ninguna malla vial flotante. Las 100 regiones de 256² puntos usan una separación de 4,6875 m y cubren 144 km², conservando continuos bordes, curvas y cruces. El escenario añade mar facetado con mareas, rías que se llenan y vacían, horizonte curvo, sol y luna low-poly, día dos veces más largo que la noche, tres capas móviles de nubes y bancos locales de niebla. El sol visual se mantiene a 20 km de la cámara —detrás de toda la isla— conservando su tamaño angular, para que ninguna montaña parezca atravesarlo. La niebla global se limita a 920 m y las seis zonas regionales se transmiten con un presupuesto máximo de dos. En el mapa, el océano ocupa todo el exterior sin marco negro ni falsa franja amarilla, y el pico blanco del marcador rojo gira con la orientación real del héroe.

La textura lunar original está en `assets/textures/moon/moon_craters_lowpoly.png` y se generó como albedo estilizado para envolver la esfera 3D, no como una imagen plana de la luna sobre el cielo.

El relieve se puede regenerar de forma determinista con:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/generate_terrain.gd
```

La regeneración sustituye el relieve y el mapa de control, por lo que debe ejecutarse antes de cualquier retoque manual que se quiera conservar.

## Pruebas

Las comprobaciones principales se ejecutan con:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/vegetation_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/epic_landmark_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_stability_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/settings_menu_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/island_world_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/stair_traversal_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/exploration_manager_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/exploration_integration_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/multiplayer_test.gd
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/save_game_ui_test.gd
python3 tests/test_lobby_directory.py -v
python3 tests/test_network_handshake.py
```

`test_network_handshake.py` levanta anfitrión e invitado en el mismo contexto y
comprueba automáticamente el roster y la réplica UDP; el modo de aforo de
`network_handshake_test.gd` permite además levantar un anfitrión y siete clientes
reales. Consulta el encabezado de ese test para los comandos manuales.
`lobby_directory_test.gd` levanta una sala contra el servidor Python local y
comprueba publicar, listar, compatibilidad de versión y retirada automática.

La prueba de vegetación valida los 50 personajes, la fauna, el caballo, las 207.200 instancias principales, los 52.000 proxies arbóreos, las 110.000 hierbas dispersas con proxy exclusivo, la distribución lejos de caminos, las calles `quaternius_rock`, el gradiente nevado, los LOD importados, los AABB por celda y las colisiones. `adventure_system_test.gd` recorre catálogo, cofres, bestiario, tala, troncos, minería, rubíes, sustitución de armas, escudos, arco, proyectil legible y estela; `exploration_integration_test.gd` valida los 200 desafíos, el mapa y el autoguardado. `save_game_ui_test.gd` cubre la restauración completa de posición, inventario, retos y mundo, además de Esc, pausa, minimapa, inventario en cuadrícula y llamada del caballo. `runtime_stability_test.gd` viaja entre biomas y demuestra que no se crean celdas ni coinciden modelos completos y proxies. `player_movement_test.gd` comprueba andar, correr y que el salto no sea un globo: el ápice por debajo de 1.15 m y la bajada más rápida que la subida, porque a 1.43 m y más de un segundo en el aire el héroe parecía descender flotando de pie. `settings_menu_test.gd` comprueba Z, las cuatro resoluciones y el corte LOD 180–900 m. `atmosphere_test.gd` valida cielo, luna, mar, cascadas, niebla, que las rachas de polvo solo pasen en el desierto —con descanso entre ellas y corte al salir— y que los remolinos nazcan sobre desierto, giren, sean low poly de verdad y se retiren al alejarse; `audio_test.gd` comprueba las tres canciones, sus loops, los límites de nieve y desierto, la mezcla ambiental y los cascos; `medieval_combat_test.gd` comprueba el inventario `1–4`, que cada arma se sujete por su empuñadura dentro del hueso de la mano y siga su rotación, la orientación del arco y los impactos; `weapon_system_test.gd` cubre el tajo corto, la carga sin congelar las piernas, el giro de 360° que alcanza a los objetivos de delante y de detrás, la onda que tumba la hierba, el vaivén acompasado del arma al caminar, la potencia proporcional al tensado, que el disparo salga elevado y no recto y se clave a menos de 1.5 m del punto marcado contra un blanco a 34 m, la cinta de estela que dibuja el vuelo hasta clavarse, la postura de recarga con el codo entre 145° y 175° y la hoja prolongando el brazo a menos de 15°, el brazo libre flexionado por debajo de 110° con el puño sobre el codo, separado del torso y con el codo abierto de la axila, el húmero paralelo al tronco, el tronco girado, que la descarga despegue del suelo y aterrice, el filo horizontal al costado derecho, la punta abierta más de 1.5 m, el tronco inclinado, que el arma no se mueva del sitio al soltar y ni el brazo ni la hoja atravesando la cabeza o el escudo de la espalda, que la carga sostenida descargue varios rayos, que envainar suba la mano al hombro y la eche a la espalda, que un clic corto no levante restos ni viento ni oscurezca el cielo y un mantenido sí, el barrido real del vendaval sobre hierba y copas, los cuatro biomas con su paleta de restos, que el escudo quede por delante de la mano con el héroe encogido tras él, y que todo lo anterior funcione con los ocho personajes del multijugador; `hero_moves_test.gd` cubre el escudo colgado a la espalda, la guardia con el botón derecho —incluida su absorción de daño, que la tabla se adelante a la mano y que use la pose de la biblioteca de animaciones—, el envainado automático al correr, el desenvainado al atacar, la voltereta lateral con su desplazamiento hacia el lado pulsado, los 43 movimientos de la biblioteca resueltos sobre el héroe y sus disparadores —gancho sin arma, tala con el hacha, golpe acusado y gestos de cuerpo entero que devuelven el control al tronco al terminar—; `island_world_test.gd` comprueba los 144 km², `N`/`B`/`M`/`0`, la atribución de FiftySounds, viaje rápido `5–8`, 54 casas, 64 plantas superiores, tres fortalezas completas y sus miradores abiertos al cielo. `stair_traversal_test.gd` mueve una cápsula idéntica al héroe, sin salto, por una escalera doméstica, una de la ciudadela y el portón exterior hasta alcanzar el patio.

Terrain3D 1.0.2 emite en Godot 4.7 un aviso de compatibilidad sobre `instance_reset_physics_interpolation()`. Es una llamada interna aún soportada y no afecta al juego.

## Estructura

```text
assets/     packs Quaternius CC0, materiales Terrain3D y audio con licencias registradas
addons/     Terrain3D
scenes/     escenas de Godot
scripts/    jugabilidad y sistemas visuales
shaders/    efectos visuales
terrain/    regiones y configuración Terrain3D
tests/      pruebas headless
tools/      utilidades y runtime local ignorado por Git
```

## Licencias

El código original se distribuye bajo MIT. Quaternius y ambientCG se usan bajo CC0; Terrain3D bajo MIT. `The Hill that Knows your Voice`, `Promise` y `Ashes` requieren atribución a FiftySounds; el viento, los pájaros, los cascos y los nuevos tiles estilizados son originales del proyecto. Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No se incluyen recursos extraídos de Nintendo ni de ningún videojuego comercial.
