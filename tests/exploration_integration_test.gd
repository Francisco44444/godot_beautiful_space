extends SceneTree

const TEST_SAVE := "user://exploration_integration_test.json"


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_cleanup()
	var exploration := root.get_node_or_null("ExplorationManager")
	if exploration == null or int(exploration.call("get_zone_count")) != 200:
		_fail("No se cargó el catálogo global de 200 zonas.")
		return
	var original_save := String(exploration.get("save_path"))
	exploration.set("save_path", TEST_SAVE)
	exploration.call("clear_progress", false)

	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 5:
		await process_frame
	var hud := world.get_node("HUD")
	var progress := hud.get_node_or_null("ExplorationProgress") as Control
	var bar := progress.find_child("ExplorationProgressBar", true, false) as ProgressBar if progress != null else null
	var journal := hud.get_node_or_null("ExplorationJournal") as Control
	var list := journal.find_child("ExplorationZoneList", true, false) as ItemList if journal != null else null
	if progress == null or bar == null or journal == null or list == null or int(bar.max_value) != 200:
		_fail("El HUD no muestra barra y diario de exploración completos.")
		return

	var zones: Array = exploration.call("get_zones")
	for zone_variant in zones:
		var terrain_zone := zone_variant as Dictionary
		var terrain_position: Vector3 = terrain_zone.position
		var slope := float(exploration.call("_terrain_slope", Vector2(terrain_position.x, terrain_position.z)))
		if is_nan(terrain_position.y) or terrain_position.y < 1.0 or slope > 0.73:
			_fail("Una zona de exploración no quedó anclada a terreno transitable: %s (y=%.2f, pendiente=%.3f)." % [terrain_zone.id, terrain_position.y, slope])
			return
	# Los retos de acción (fauna, cofres, tala...) no pueden completarse sólo
	# llegando y pulsando E. La integración del aviso se prueba con una visita.
	var first: Dictionary = {}
	for zone_variant in zones:
		var candidate := zone_variant as Dictionary
		if String(candidate.get("requirement", "")) == "visit":
			first = candidate
			break
	if first.is_empty():
		_fail("El catálogo no contiene ninguna visita confirmable con E.")
		return
	var player := world.get_node("Player") as Player
	player.global_position = first.position
	exploration.call("update_player_position", player.global_position)
	var prompt := hud.get_node("ExplorationPrompt") as Label
	await process_frame
	if not prompt.visible or String(first.name) not in prompt.text:
		_fail("Llegar a una zona no muestra el aviso de pulsar E.")
		return
	if not bool(player.call("_confirm_nearby_exploration")):
		_fail("La interacción prioritaria del jugador no confirmó la zona.")
		return
	await process_frame
	if int(exploration.call("get_completed_count")) != 1 or int(bar.value) != 1 or not FileAccess.file_exists(TEST_SAVE):
		_fail("E no actualizó barra, progreso y autoguardado.")
		return

	hud.call("_set_exploration_journal_open", true)
	if not journal.visible or not paused or list.item_count != 200:
		_fail("L no dispone de un listado pausado con las 200 zonas.")
		return
	hud.call("_on_exploration_item_clicked", 10, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	var full_map := hud.get_node("FullMap") as Control
	if journal.visible or paused or not full_map.visible or (exploration.call("get_selected_zone") as Dictionary).is_empty():
		_fail("Pulsar una entrada no abre el mapa con objetivo seleccionado.")
		return

	var dawn := exploration.call("get_zone", "zone_199_amanecer") as Dictionary
	exploration.call("update_time_of_day", "Día")
	player.global_position = dawn.position
	exploration.call("update_player_position", player.global_position)
	var daytime_nearby := exploration.call("get_nearby_zone") as Dictionary
	if not daytime_nearby.is_empty() and String(daytime_nearby.id) == "zone_199_amanecer":
		_fail("El reto del amanecer se habilitó a plena luz del día.")
		return
	exploration.call("update_time_of_day", "Amanecer")
	exploration.call("update_player_position", player.global_position)
	var dawn_nearby := exploration.call("get_nearby_zone") as Dictionary
	if String(dawn_nearby.get("id", "")) != "zone_199_amanecer" or not bool(player.call("_confirm_nearby_exploration")) or int(exploration.call("get_completed_count")) != 2:
		_fail("El amanecer no cuenta como una de las 200 exploraciones.")
		return

	var audio := world.get_node("AmbientAudio") as AmbientAudio
	audio.music.stop()
	audio.snow_music.stop()
	audio.desert_music.stop()
	audio.wind.stop()
	audio.birds.stop()
	world.queue_free()
	exploration.set("save_path", original_save)
	exploration.call("load_progress")
	_cleanup()
	for _frame in 4:
		await process_frame
	print("EXPLORATION INTEGRATION TEST OK: barra, L, mapa, E, eventos y guardado conectados.")
	quit(0)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = TEST_SAVE + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	paused = false
	_cleanup()
	push_error(message)
	quit(1)
