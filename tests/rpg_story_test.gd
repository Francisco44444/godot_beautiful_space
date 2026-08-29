extends SceneTree

## Valida que la campaña no sea sólo texto: los 200 pasos, habitantes,
## monstruos, grutas, diálogo y pista persistente deben estar conectados.


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
	var gates := get_nodes_in_group("rpg_cave_gate")
	if npcs.size() != 24 or enemies.size() != 48 or gates.size() != 4:
		_fail("El mundo narrativo debe materializar 24 NPC, 48 enemigos y 4 puertas: %d/%d/%d." % [npcs.size(), enemies.size(), gates.size()])
		return
	if runtime.generated_cave_count != 4 or runtime.generated_gate_count != 4:
		_fail("Las cuatro puertas no están integradas en cuatro grutas físicas.")
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
	if network_enemies.size() != 48:
		_fail("El anfitrión no puede sincronizar los 48 enemigos.")
		return

	world.get_node("AmbientAudio").call("_exit_tree")
	world.queue_free()
	for _frame in 5:
		await process_frame
	print("RPG STORY TEST OK: 8 capítulos, 200 objetivos, 24 NPC, 48 monstruos, 4 grutas, diálogo, pistas y guardado.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
