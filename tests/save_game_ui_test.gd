extends SceneTree

const TEST_PLAYER := "TestGuardadoCodex"


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var settings := root.get_node("GameSettings")
	var inventory := root.get_node("InventoryManager")
	var exploration := root.get_node("ExplorationManager")
	var saves := root.get_node("SaveGameManager")
	settings.call("set_player_identity", TEST_PLAYER, 2, false)
	inventory.autosave_enabled = false
	inventory.call("reset_inventory_for_tests", false)
	exploration.autosave_enabled = false
	exploration.call("clear_progress", false)
	_cleanup_slots()
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _frame in 6:
		await process_frame
	var hud := world.get_node("HUD")
	var minimap := hud.get_node("MiniMap") as Control
	if not minimap.visible:
		_fail("El minimapa no comienza activo.")
		return
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	hud.call("_unhandled_input", cancel)
	var pause := hud.get_node_or_null("PauseMenu") as Control
	if pause == null or not pause.visible or not paused:
		_fail("Esc no abre el menú de pausa convencional.")
		return
	hud.call("_unhandled_input", cancel)
	if pause.visible or paused:
		_fail("Esc no cierra el menú de pausa y continúa.")
		return
	var inventory_event := InputEventKey.new()
	inventory_event.physical_keycode = KEY_I
	inventory_event.pressed = true
	hud.call("_unhandled_input", inventory_event)
	var grid := hud.find_child("InventoryGrid", true, false) as GridContainer
	if grid == null or not bool(hud.call("is_inventory_open")) or grid.get_child_count() < 5:
		_fail("El inventario no es una cuadrícula con cantidades.")
		return
	hud.call("_unhandled_input", cancel)
	if bool(hud.call("is_inventory_open")) or paused:
		_fail("Esc no cierra primero la ventana de inventario.")
		return

	var player := world.get_node("Player") as Player
	var horse := world.get_node("Horse") as Horse
	world.call("call_horse_to_player")
	if not horse.call("is_coming_when_called"):
		_fail("El botón H no puede llamar al caballo.")
		return
	var saved_position := Vector3(143.0, 22.0, -87.0)
	player.global_position = saved_position
	inventory.call("add_item", "Coin", 9, false)
	var first_zone := String((exploration.call("get_zones") as Array)[0].id)
	exploration.call("apply_save_state", {"discovered_ids": [first_zone], "selected_zone_id": first_zone}, false)
	world.set("sun_cycle_radians", 2.14)
	world.get_node("IslandEnvironment").set("tide_phase", 1.42)
	if not bool(saves.call("save_current_game", "prueba")):
		_fail("No se pudo crear la ranura completa.")
		return
	var test_slot := ""
	for slot_value in saves.call("list_slots"):
		var slot := slot_value as Dictionary
		if TEST_PLAYER in String(slot.display_name):
			test_slot = String(slot.path)
			break
	if test_slot.is_empty():
		_fail("La ranura no usa el nombre del jugador.")
		return
	player.global_position = Vector3.ZERO
	inventory.call("reset_inventory_for_tests", false)
	exploration.call("clear_progress", false)
	world.set("sun_cycle_radians", 0.2)
	if not bool(saves.call("load_slot", test_slot)):
		_fail("No se pudo cargar la ranura.")
		return
	await process_frame
	if player.global_position.distance_to(saved_position) > 0.05:
		_fail("La partida no restauró la posición del jugador.")
		return
	if int(inventory.call("get_count", "Coin")) != 9 or not bool(exploration.call("is_discovered", first_zone)):
		_fail("La partida no restauró inventario y zonas exploradas.")
		return
	if absf(float(world.get("sun_cycle_radians")) - 2.14) > 0.02:
		_fail("La partida no restauró el estado de sol/luna.")
		return
	var audio := world.get_node("AmbientAudio") as AmbientAudio
	for stream in [audio.music, audio.snow_music, audio.desert_music, audio.wind, audio.birds]:
		(stream as AudioStreamPlayer).stop()
	world.queue_free()
	await process_frame
	inventory.autosave_enabled = true
	exploration.autosave_enabled = true
	settings.call("reset_defaults", false)
	_cleanup_slots()
	print("SAVE/UI TEST OK: Escape, cuadrícula, minimapa, caballo y ranura completa operativos.")
	quit(0)


func _cleanup_slots() -> void:
	var directory := DirAccess.open("user://savegames")
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if TEST_PLAYER.to_lower() in file_name.to_lower():
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegames/" + file_name))
		file_name = directory.get_next()
	directory.list_dir_end()


func _fail(message: String) -> void:
	paused = false
	_cleanup_slots()
	push_error(message)
	quit(1)
