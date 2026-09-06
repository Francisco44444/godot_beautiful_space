# Senderos del Horizonte

Aventura medieval en tercera persona. Godot 4.7.1, GDScript, Terrain3D. Isla de
12×12 km. Arte low-poly de los packs CC0 de Quaternius.

**El código y los comentarios van en español.** Los comentarios explican POR QUÉ,
con la cifra medida cuando la hay — no qué hace la línea de al lado.

## Cómo ejecutar

Godot va incluido en el repositorio. No hay que instalar nada.

```bash
# Una prueba (sale con código 0 si pasa)
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/NOMBRE.gd

# Comprobar que un script compila
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script res://scripts/NOMBRE.gd

# Ver el juego (abre ventana; sirve para capturar pantalla)
tools/runtime/Godot.app/Contents/MacOS/Godot --path . --script res://tools/diagnostics/NOMBRE.gd

# Recorrido de jefes: F1..F5 ir a cada jefe, F6 equipo alto, F7 curar, F8 ficha
tools/recorrido_jefes.sh
```

**Tras crear un script con `class_name` nuevo hay que reimportar**, o el resto del
proyecto no lo ve:

```bash
tools/runtime/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit-after 90 >/dev/null 2>&1
```

`timeout` NO existe en este zsh. El mundo tarda ~8 s en construirse, así que una
prueba que lo instancia ronda el minuto: no la mates antes de tiempo.

## Trampas del proyecto

Cada una de estas costó horas de depuración. No hay que volver a pagarlas.

- **Terrain3D sólo genera colisión de suelo cerca del jugador.** Cualquier cosa
  que se mueva por física lejos del héroe **se cae al vacío**. Medido: los 48
  enemigos originales caídos a los 10 s, el peor 513 m. Los enemigos, los jefes y
  los vecinos escriben su posición a mano y pegan la Y a
  `terrain.data.get_height(...)`. La fauna (`quaternius_wildlife.gd`) ya lo hacía.
- **La firma del caché de vegetación NO incluye los radios de los claros.**
  Ampliar un claro no invalida `generated/vegetation_layout_cache.res`: los
  árboles viejos brotan dentro de las casas nuevas sin avisar. Al tocar un claro
  hay que subir `LAYOUT_CACHE_SCHEMA`, rehornear con `-- --bake-vegetation` y
  actualizar el número que asierta `tests/vegetation_test.gd`.
- **Los dos packs de armas están a escalas distintas.** La espada del pack RPG
  mide 2,30 m y la claymore del pack medieval 6,59 m. Por eso el juego sólo
  importaba los 5 escudos del medieval. La corrección por pieza vive en
  `InventoryManager.MESH_SCALE_FIX`.
- **El panel de diálogo de historia PAUSA el árbol.** Abrirlo en el primer
  fotograma dejaba la partida congelada y los tweens del mundo (la caída de un
  árbol talado) no llegaban a correr nunca.
- **Las piezas de muro del kit no están centradas en su espesor** (van de
  z = −0,314 a +0,0925) y su **+Z local es la cara buena**, la que mira a la
  calle. El giro de una pieza depende del LADO de la celda, no de la orientación
  de la arista.
- **`Skeleton3D` procesa sus modificadores en orden de árbol**, no por
  `process_priority`: `library_animation` tiene que nacer antes que
  `weapon_arm_modifier` o le borra las correcciones.
- **En heredocs de bash con `<<'EOF'`, `\n` hay que escribirlo sin doblar.** Un
  `\\n` acaba como barra invertida literal en el texto del juego.
- **Un script de sonda nunca debe usar `_initialize()` con `await`.** El bucle
  principal no arranca hasta que esa función retorna, así que el `await` se queda
  colgado para siempre y el proceso no imprime nada (Godot además almacena la
  salida en búfer, así que ni siquiera se ve dónde se paró). El patrón bueno es
  el de `tests/`: `_init()` + `call_deferred("_run_test")`.
- **El panel de diálogo pausa el árbol.** Cualquier prueba que llame a
  `answer_dialogue` a pelo tiene que despausar a mano; en juego lo hace el HUD.
- **Unas partículas sin `visibility_aabb` no se ven, aunque existan.** El motor
  las recorta y no avisa: la sonda confirmaba el nodo emitiendo, visible y en su
  sitio, y en pantalla no había nada. Copiar la caja de `weapon_charge_effect.gd`.
- **GDScript no infiere el tipo en un `for` sobre un literal.** `for x in [1.0, 2.0]`
  da un error de compilación al usar `x` en un `:=`. Usar `PackedFloat32Array([...])`
  o anotar el tipo.

## Arquitectura

### Historia — tres capas separadas, y no hay que mezclarlas

| Capa | Fichero | Qué es | Dónde se ve |
|---|---|---|---|
| **Campaña** | `rpg_campaign.gd` | 5 actos, 5 jefes, 5 nombres | Seguidor (bloque HISTORIA) |
| **Encargos** | `rpg_sidequests.gd` | 18 secundarias con negociación | Seguidor (bloque ENCARGOS) |
| **Exploración** | `rpg_story_catalog.gd` + `exploration_manager.gd` | 200 zonas en 8 capítulos | Sólo el diario (`L`) |

Mezclarlas en la misma línea del HUD fue un error que ya se corrigió: contaban
cosas distintas y no se entendía nada.

**El hilo:** las campanas de Aeloria sujetaban algo; cada una llevaba grabado el
nombre de quien la fundió; alguien raspó los nombres. Vaelor es lo que queda de
una persona sin nombre. Hay un quinto nombre raspado — el del héroe — y por eso
nadie de la isla le llama nunca por él.

**La estructura NO es lineal.** El Acto I es prólogo obligatorio; los tres del
medio se abren **a la vez** y se hacen en cualquier orden; el V pide los cuatro
nombres. `RPGCampaign.open_acts()` devuelve los abiertos, que pueden ser tres.

**Diálogo con memoria** (`rpg_dialogue.gd`): cada conversación es saludo + cuerpo
+ indicaciones + coletilla, y las cuatro dependen de cuántas veces habéis hablado
(`_met`), cuántos encargos le has resuelto (`_helped`) y cómo le contestaste
(`_regard`). Tres respuestas por conversación: **humilde** rebaja lo que piden,
**altivo** lo sube y paga más pero **no te dicen dónde buscar ni el punto débil
del jefe**. Todo se guarda en la partida.

### Combate

- `rpg_enemy.gd` — cinco estilos por bioma: embestida (valle), pisotón con onda
  (nieve), espinas a distancia (desierto), parpadeo a la espalda (bosque
  tenebroso), guardia frontal (castillo). Duermen a más de 140 m del héroe.
- `rpg_boss.gd` — fases, anticipación telegrafiada, ventana de vulnerabilidad
  (×3 daño) y una **mecánica exigida** por jefe: escudo, arco, carga, esquiva y
  las cuatro. Nacen **sellados** hasta que su acto se abre.
- `rpg_bestiary.gd` — especies, escalones por distancia a Puerto Alba, guaridas,
  guarniciones de castillo y las cinco arenas.
- `rpg_forge.gd` — escaleras de mejora. La espada tiene 6 grados (daño 3→13) y
  **cada grado se paga con el cristal de un bioma distinto**: subir de arma
  obliga a cruzar la isla.
- `kill_cam.gd` — cámara lenta del golpe final en tres intensidades. **Mide el
  tiempo en segundos reales** (`delta / Engine.time_scale`), o a escala 0,2 la
  escena se queda colgada.

Vida y vigor máximos **suben** al cerrar un acto (+25/+18), al mejorar en la
forja (+6/+5) y al cumplir un encargo (+5/+4). Al caer, despiertas en la villa
más cercana **con la mitad de la vida**.

### Edificios

`building_solver.gd` resuelve la geometría en **celdas enteras de 2 m antes de
instanciar nada**, así que dos cuerpos no pueden pisarse: no es que se evite, es
que no se puede expresar. `building_assembler.gd` instancia el plan.
`building_recipes.gd` son las casas; `building_catalog.gd`, qué pieza va en cada
sitio. Todo lo que se pisa cuelga de `Estructura`; lo que sólo se mira, de
`Decorado`, y **la cubierta no lleva colisión**.

## Assets

```
assets/quaternius/
  store_bundle/glTF/                        casas y villa del Medieval Village MegaKit
  Modular Medieval Buildings - Jul 2017/OBJ/ murallas, torreones, puente
  Ultimate Monsters/{Big,Blob,Flying}/glTF/  50 criaturas
  Ultimate RPG Items Pack - Aug 2019/OBJ/    armas, pociones, gemas, llaves
  Medieval Weapons Pack by @Quaternius/OBJ/  espadas, escudos, arcos, lanza
  Fantasy Props MegaKit/Exports/glTF/        braseros, cadenas, jaulas, oro
  Stylized Nature MegaKit[Standard]/glTF/    rocas, árboles muertos, losas
  ultimate_animated_characters/glTF/         50 personajes
```

## Cómo trabajar aquí

1. **Medir, no suponer.** Cada afirmación sobre el mundo sale de una sonda
   ejecutada, no de leer el código. Los scripts de diagnóstico van en
   `tools/diagnostics/` **y se borran al terminar**.
2. **Verificar mirando.** Un cambio visual se comprueba con captura de pantalla,
   no dando por hecho que compila igual a que se ve bien.
3. **La prueba es el contrato.** Al cambiar un diseño a propósito (dos escaleras
   en vez de una), se reescribe el aserto por el equivalente NUEVO — nunca se
   relaja ni se borra. Un contador que busca un nodo que ya no existe vale
   siempre 0 y comparado contra 0 pasa siempre: eso es peor que borrar el aserto.
4. **Una prueba que nunca ha fallado no prueba nada.** Al escribir un invariante,
   inyectar el defecto y comprobar que lo caza.
5. Las pruebas nuevas se añaden a `.github/workflows/windows-build.yml`.
