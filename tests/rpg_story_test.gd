extends SceneTree

## Valida que la campaña no sea sólo texto: los 200 pasos, habitantes,
## monstruos, grutas, diálogo y pista persistente deben estar conectados.


## 180 de patrullas, guaridas y guarniciones, más 4 centinelas por arena en la
## única cuesta subible: sin ellos llegar al jefe es andar mucho, no costar.
const APPROACH_GUARDS_PER_ARENA := 4
## Derivado del bestiario, no a mano: sembrar una guarida para que un encargo
## pueda cumplirse no puede obligar a venir aquí a cambiar un número, ni —peor—
## dejar el aserto pasando por casualidad.
var expected_enemies := _roaming_enemies() \
	+ RPGBestiary.ARENAS.size() * APPROACH_GUARDS_PER_ARENA


func _roaming_enemies() -> int:
	var total := RPGBestiary.patrol_points(VegetationScatter.ROAD_NETWORK, 150.0, 11.0).size()
	for lair in RPGBestiary.LAIRS:
		total += int(lair["count"])
	for garrison in RPGBestiary.GARRISONS:
		total += int(garrison["count"])
	return total
const EXPECTED_BOSSES := 5
const EXPECTED_FORGES := 6
## Ningún bioma puede quedarse sin criaturas que peleen a su manera.
const MIN_PER_STYLE := 10


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 7:
		await process_frame

	var exploration := root.get_node_or_null("ExplorationManager")
	var runtime := world.get_node_or_null("RPGStoryRuntime") as Node
	var hud := world.get_node_or_null("HUD")
	if exploration == null or runtime == null or hud == null:
		_fail("Falta ExplorationManager, RPGStoryRuntime o HUD.")
		return

	var chapters := exploration.call("get_story_chapters") as Array
	var objectives := exploration.call("get_story_objectives") as Array
	if chapters.size() != 8 or objectives.size() != 200:
		_fail("La campaña debe tener 8 capítulos y 200 objetivos: %d/%d." % [chapters.size(), objectives.size()])
		return
	var orders := {}
	for objective_value in objectives:
		var objective := objective_value as Dictionary
		var order := int(objective.get("story_order", 0))
		if order < 1 or order > 200 or orders.has(order):
			_fail("El orden narrativo no es una secuencia única de 1 a 200.")
			return
		orders[order] = true
		for key in ["chapter_title", "description", "reward_preview", "story_beat"]:
			if String(objective.get(key, "")).strip_edges().is_empty():
				_fail("Un objetivo narrativo carece de %s." % key)
				return
	if orders.size() != 200:
		_fail("No se cubren las 200 posiciones de la historia.")
		return
	for chapter_value in chapters:
		var chapter := chapter_value as Dictionary
		if String(chapter.get("title", "")).is_empty() or String(chapter.get("summary", "")).length() < 30:
			_fail("Un capítulo no tiene título o argumento suficiente.")
			return

	var npcs := get_nodes_in_group("rpg_npc")
	var enemies := get_nodes_in_group("rpg_enemy")
	var bosses := get_nodes_in_group("rpg_boss")
	var anvils := get_nodes_in_group("rpg_anvil")
	var gates := get_nodes_in_group("rpg_cave_gate")
	# El bestiario pasó de 48 criaturas clavadas en doce puntos fijos —todas a
	# más de 300 m del héroe y ninguna junto a un camino— a un reparto por las
	# diez rutas, guaridas de bosque y guarniciones de castillo.
	if npcs.size() != 24 or enemies.size() != expected_enemies or gates.size() != 4:
		_fail("El mundo narrativo debe materializar 24 NPC, %d enemigos y 4 puertas: %d/%d/%d." % [
			expected_enemies, npcs.size(), enemies.size(), gates.size()])
		return
	if bosses.size() != EXPECTED_BOSSES or anvils.size() != EXPECTED_FORGES:
		_fail("Deben existir %d jefes de acto y %d herrerías: %d/%d." % [
			EXPECTED_BOSSES, EXPECTED_FORGES, bosses.size(), anvils.size()])
		return

	# Los cinco estilos de combate tienen que estar vivos. Antes los diez modelos
	# compartían una única conducta y la nieve se jugaba igual que el desierto.
	var styles := {}
	for creature in enemies:
		styles[int(creature.style)] = int(styles.get(int(creature.style), 0)) + 1
	if styles.size() != 5:
		_fail("Sólo hay %d estilos de combate de los cinco que definen los biomas: %s." % [
			styles.size(), styles])
		return
	for style in 5:
		if int(styles.get(style, 0)) < MIN_PER_STYLE:
			_fail("El estilo %d sólo lo usan %d criaturas; hacen falta al menos %d." % [
				style, int(styles.get(style, 0)), MIN_PER_STYLE])
			return

	# Y ninguna criatura puede estar cayéndose. Terrain3D no genera colisión de
	# suelo lejos del jugador y con gravedad los 48 originales se desplomaban:
	# medido, los 48 caídos a los diez segundos, el peor 513,6 m.
	var terrain := world.get_node("Terrain3D") as Terrain3D
	for creature in enemies:
		var here: Vector3 = (creature as Node3D).global_position
		var ground: float = terrain.data.get_height(Vector3(here.x, 0.0, here.z))
		if is_nan(ground):
			continue
		if absf(here.y - ground) > 1.2:
			_fail("%s está a %.1f m de la cota del terreno: se está cayendo." % [
				creature.name, absf(here.y - ground)])
			return

	# Sólo el jefe del acto en curso está despierto. Sin este cerrojo se podía ir
	# derecho al último con la espada de partida.
	var awake := 0
	for boss in bosses:
		if not bool(boss.sealed):
			awake += 1
	if awake != 1:
		_fail("Debe haber exactamente un jefe despierto y hay %d." % awake)
		return
	if runtime.generated_cave_count != 4 or runtime.generated_gate_count != 4:
		_fail("Las cuatro puertas no están integradas en cuatro grutas físicas.")
		return
	for gate_id in ["roots", "frost", "sun", "echo"]:
		var cave := runtime.get_node_or_null("Cave_%s" % gate_id) as StaticBody3D
		if cave == null or cave.get_node_or_null("HollowCollision") == null or cave.get_node_or_null("ApproachCollision") == null or float(cave.get_meta("route_length",0.0)) < 200:
			_fail("Una gruta no tiene recorrido, suelo y colisión continua explorables.")
			return
	var character_variants := {}
	for npc_value in npcs:
		var npc := npc_value as Node
		character_variants[String(npc.get("character_file"))] = true
		if npc.get("visual") == null or npc.get_node_or_null("NPCName") == null or not npc.is_in_group("adventure_interactable"):
			_fail("Un habitante no tiene modelo, identidad visible o interacción.")
			return
	if character_variants.size() < 16:
		_fail("Los habitantes no son suficientemente diversos: %d aspectos." % character_variants.size())
		return
	for enemy_value in enemies:
		var enemy := enemy_value as Node
		if not ResourceLoader.exists(String(enemy.get("monster_path"))) or not enemy.is_in_group("melee_target"):
			_fail("Un enemigo no usa Ultimate Monsters o no recibe golpes.")
			return

	var story_hint := hud.get_node_or_null("PersistentStoryHint") as PanelContainer
	var story_dialogue := hud.get_node_or_null("StoryDialogue") as ColorRect
	if story_hint == null or story_dialogue == null or hud.get("story_hint_label") == null:
		_fail("Falta la pista narrativa persistente o el diálogo.")
		return
	hud.call("_set_story_hint_expanded", true)
	if not bool(story_hint.get_meta("expanded", false)) or story_hint.size.y < 250.0:
		_fail("P no puede desplegar la pista completa.")
		return
	hud.call("_set_story_hint_expanded", false)

	var player := world.get_node("Player") as Player
	var first_npc := npcs[0] as Node
	if not bool(first_npc.call("interact", player)) or not bool(hud.get("story_dialogue_open")) or not story_dialogue.visible:
		_fail("Hablar con un NPC no abre el diálogo narrativo.")
		return
	hud.call("_set_story_dialogue_open", false)

	var first_gate := gates[0] as Node
	first_gate.call("open_gate", null, false)
	var save_state: Dictionary = runtime.call("get_save_state") as Dictionary
	if not bool(first_gate.get("opened")) or (save_state.get("gates", []) as Array).size() != 4 or not save_state.has("health"):
		_fail("Las puertas y la vida no quedan incluidas en el guardado de campaña.")
		return
	var network_enemies: Array = runtime.call("get_network_enemy_state") as Array
	# Los jefes también se sincronizan: en cooperativo los dos jugadores tienen
	# que ver la misma barra de vida y el mismo sello.
	if network_enemies.size() != expected_enemies + EXPECTED_BOSSES:
		_fail("El anfitrión sincroniza %d criaturas y deberían ser %d." % [
			network_enemies.size(), expected_enemies + EXPECTED_BOSSES])
		return

	world.get_node("AmbientAudio").call("_exit_tree")
	world.queue_free()
	for _frame in 5:
		await process_frame
	print("RPG STORY TEST OK: 8 capítulos, 200 objetivos, 24 NPC, %d monstruos en cinco estilos, %d jefes sellados salvo el del acto en curso, %d herrerías, 4 grutas, diálogo, pistas y guardado." % [expected_enemies, EXPECTED_BOSSES, EXPECTED_FORGES])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
