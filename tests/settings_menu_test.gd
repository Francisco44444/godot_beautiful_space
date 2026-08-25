extends SceneTree

## Valida el panel Z, sus controles reales y la conexión entre resolución,
## distancia visual, LOD importado global y HLOD exclusivo de vegetación.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var game_settings := root.get_node_or_null("GameSettings")
	if game_settings == null:
		_fail("No se cargó el singleton de configuración.")
		return
	game_settings.call("reset_defaults", false)
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in range(4):
		await process_frame
	var player_model_root := world.get_node("Player/Visual/ModelRoot") as Node3D
	var horse_model_root := world.get_node("Horse/Visual/ModelRoot") as Node3D
	var wildlife_root := world.get_node("QuaterniusWildlife") as Node3D
	if (
		player_model_root.get_child_count() == 0
		or horse_model_root.get_child_count() == 0
		or wildlife_root.get_child_count() == 0
		or not bool(player_model_root.get_child(0).get_meta("loaded_via_project_importer", false))
		or not bool(horse_model_root.get_child(0).get_meta("loaded_via_project_importer", false))
		or not bool(wildlife_root.get_child(0).get_meta("loaded_via_project_importer", false))
	):
		_fail("Personaje, caballo o fauna se saltan el importador y su LOD automático.")
		return

	var hud := world.get_node("HUD")
	var overlay := hud.get_node_or_null("SettingsOverlay") as Control
	var controls: RichTextLabel
	var resolution_selector: OptionButton
	var lod_slider: HSlider
	if overlay != null:
		controls = overlay.find_child("AssignedControls", true, false) as RichTextLabel
		resolution_selector = overlay.find_child("ResolutionSelector", true, false) as OptionButton
		lod_slider = overlay.find_child("LodDistanceSlider", true, false) as HSlider
	if overlay == null or controls == null or resolution_selector == null or lod_slider == null:
		_fail("El HUD no construye el panel completo de configuración.")
		return
	if overlay.visible or bool(hud.call("is_settings_open")):
		_fail("El panel Z debe comenzar cerrado.")
		return

	var has_z := false
	for input_event in InputMap.action_get_events("settings"):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			if key_event.physical_keycode == KEY_Z or key_event.keycode == KEY_Z:
				has_z = true
				break
	if not has_z:
		_fail("La acción settings no está asignada físicamente a la tecla Z.")
		return

	# El minimapa comienza activo y conserva esa preferencia aunque el panel lo tape.
	var minimap := hud.get_node("MiniMap") as Control
	if not minimap.visible:
		_fail("El minimapa debe comenzar activo.")
		return
	var minimap_event := InputEventKey.new()
	minimap_event.physical_keycode = KEY_B
	minimap_event.pressed = true
	hud.call("_unhandled_input", minimap_event)
	if minimap.visible:
		_fail("B no desactivó el minimapa.")
		return
	hud.call("_unhandled_input", minimap_event)
	if not minimap.visible:
		_fail("B no pudo reactivar el minimapa.")
		return
	var settings_event := InputEventAction.new()
	settings_event.action = "settings"
	settings_event.pressed = true
	hud.call("_unhandled_input", settings_event)
	if not overlay.visible or not bool(hud.call("is_settings_open")) or not paused or minimap.visible:
		_fail("Z no abre el panel, pausa el juego y oculta los overlays incompatibles.")
		return
	if (
		"1 Espada" not in controls.text
		or "3 Arco" not in controls.text
		or "I Inventario" not in controls.text
		or "Correr / galopar" not in controls.text
		or "Configuración" not in controls.text
		or resolution_selector.item_count != 4
		or lod_slider.min_value > 180.0
		or lod_slider.max_value < 900.0
	):
		_fail("El panel Z no muestra controles, resoluciones o distancia LOD completos.")
		return

	game_settings.call("set_resolution", Vector2i(1600, 900), false)
	if game_settings.get("resolution") != Vector2i(1600, 900) or "1600" not in resolution_selector.get_item_text(resolution_selector.selected):
		_fail("El selector no refleja la resolución elegida.")
		return
	game_settings.call("set_lod_distance", 620.0, false)
	var scatter := world.get_node("VegetationScatter") as VegetationScatter
	if (
		absf(float(world.get("lod_distance_metres")) - 620.0) > 0.01
		or absf(scatter.lod_switch_distance - 620.0) > 0.01
		or absf(lod_slider.value - 620.0) > 0.01
		or absf(get_root().mesh_lod_threshold - 340.0 / 620.0) > 0.01
		or not bool(world.get_meta("systematic_mesh_lod", false))
	):
		_fail("La distancia elegida no gobierna conjuntamente el LOD global y vegetal.")
		return

	hud.call("_unhandled_input", settings_event)
	if overlay.visible or bool(hud.call("is_settings_open")) or paused or not minimap.visible:
		_fail("Z no cierra el panel y restaura el minimapa elegido.")
		return

	game_settings.call("reset_defaults", false)
	var audio := world.get_node("AmbientAudio") as AmbientAudio
	audio.music.stop()
	audio.snow_music.stop()
	audio.desert_music.stop()
	audio.wind.stop()
	audio.birds.stop()
	world.queue_free()
	for _frame in range(8):
		await process_frame
	print("SETTINGS MENU TEST OK: Z, cuatro resoluciones y LOD global 180–900 m conectados.")
	quit(0)


func _fail(message: String) -> void:
	paused = false
	var game_settings := root.get_node_or_null("GameSettings")
	if game_settings != null:
		game_settings.call("reset_defaults", false)
	push_error(message)
	quit(1)
