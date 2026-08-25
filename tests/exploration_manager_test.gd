extends SceneTree

## Prueba aislada: no depende de que ExplorationManager esté registrado como
## autoload y usa una ruta de guardado exclusiva del proceso de test.

const TEST_SAVE_PREFIX := "user://exploration_manager_test_"

var _save_path := ""


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_save_path = "%s%d.json" % [TEST_SAVE_PREFIX, OS.get_process_id()]
	_cleanup_test_files()
	var manager_script := load("res://scripts/exploration_manager.gd") as GDScript
	if manager_script == null:
		_fail("No se pudo cargar ExplorationManager.")
		return
	var manager: Node = manager_script.new()
	manager.save_path = _save_path
	manager.auto_load_on_ready = false
	manager.auto_track_local_player = false
	root.add_child(manager)
	manager.call("initialize", false)

	var zones: Array = manager.call("get_zones")
	if zones.size() != 200 or int(manager.call("get_zone_count")) != 200:
		_fail("El catálogo no contiene exactamente 200 zonas.")
		return
	var ids := {}
	var biome_counts := {}
	var event_count := 0
	for raw_zone in zones:
		var zone := raw_zone as Dictionary
		for required_key in ["id", "name", "position", "description", "type", "biome", "radius", "requires_event"]:
			if not zone.has(required_key):
				_fail("Una zona no contiene el campo obligatorio %s." % required_key)
				return
		var zone_id := String(zone.id)
		if ids.has(zone_id):
			_fail("Hay identificadores de zona duplicados: %s." % zone_id)
			return
		ids[zone_id] = true
		var point: Vector3 = zone.position
		var angle := atan2(point.z, point.x)
		if point.length() > float(manager.call("_coast_radius_at_angle", angle)) - 150.0:
			_fail("La zona %s quedó fuera de la isla navegable." % zone_id)
			return
		biome_counts[String(zone.biome)] = int(biome_counts.get(String(zone.biome), 0)) + 1
		if String(zone.type) == "evento":
			event_count += 1
	if event_count != 2 or not ids.has("zone_199_amanecer") or not ids.has("zone_200_atardecer"):
		_fail("Amanecer y atardecer no están incluidos dentro de las 200 zonas.")
		return
	for required_biome in ["pradera", "bosque", "nieve", "desierto", "costa", "montaña", "tenebroso", "poblado"]:
		if int(biome_counts.get(required_biome, 0)) <= 0:
			_fail("El catálogo no reparte zonas por el bioma %s." % required_biome)
			return

	# La generación debe ser idéntica entre instancias, sin depender de RNG global.
	var deterministic_manager: Node = manager_script.new()
	deterministic_manager.save_path = _save_path + ".other"
	deterministic_manager.auto_load_on_ready = false
	deterministic_manager.auto_track_local_player = false
	root.add_child(deterministic_manager)
	deterministic_manager.call("initialize", false)
	var deterministic_zones: Array = deterministic_manager.call("get_zones")
	for index in zones.size():
		if zones[index].id != deterministic_zones[index].id or zones[index].position != deterministic_zones[index].position:
			_fail("El catálogo no es determinista en el índice %d." % index)
			return

	# Acercarse no completa nada: hace falta confirmar, como lo hará la tecla E.
	var first_zone := zones[0] as Dictionary
	manager.call("update_player_position", Vector3(5900.0, 0.0, 5900.0))
	if not (manager.call("get_nearby_zone") as Dictionary).is_empty() or not (manager.call("confirm_current_zone") as Dictionary).is_empty():
		_fail("Se pudo completar una zona sin estar dentro de su radio.")
		return
	manager.call("update_player_position", first_zone.position)
	if manager.call("is_discovered", first_zone.id) == true or manager.call("can_confirm_current_zone") != true:
		_fail("La proximidad completó automáticamente la zona o no habilitó E.")
		return
	var confirmed := manager.call("confirm_current_zone") as Dictionary
	if confirmed.is_empty() or manager.call("is_discovered", first_zone.id) != true or int(manager.call("get_completed_count")) != 1:
		_fail("La confirmación de la zona mediante la API de E falló.")
		return
	if not FileAccess.file_exists(_save_path):
		_fail("Descubrir una zona no produjo autoguardado.")
		return

	# El camino real de entrada también exige la acción interact (E por defecto).
	var second_zone := zones[1] as Dictionary
	manager.call("update_player_position", second_zone.position)
	var interact_event := InputEventAction.new()
	interact_event.action = &"interact"
	interact_event.pressed = true
	manager.call("_unhandled_input", interact_event)
	if manager.call("is_discovered", second_zone.id) != true or int(manager.call("get_completed_count")) != 2:
		_fail("La acción interact no confirmó la zona cercana.")
		return

	# Un evento exige simultáneamente su mirador, la franja horaria y E.
	var dawn_zone := manager.call("get_zone", "zone_199_amanecer") as Dictionary
	manager.call("update_player_position", dawn_zone.position)
	var before_dawn := manager.call("get_nearby_zone") as Dictionary
	if not before_dawn.is_empty() and String(before_dawn.id) == "zone_199_amanecer":
		_fail("El amanecer estaba disponible fuera de su franja horaria.")
		return
	manager.call("update_time_of_day", "Amanecer")
	manager.call("update_player_position", dawn_zone.position)
	if manager.call("can_confirm_current_zone") != true:
		_fail("El evento de amanecer no se activó en su mirador.")
		return
	manager.call("confirm_current_zone")
	if int(manager.call("get_completed_count")) != 3:
		_fail("El amanecer no cuenta dentro del progreso de 200 zonas.")
		return

	if manager.call("select_zone", "zone_200_atardecer", true) != true:
		_fail("No se pudo seleccionar una zona como objetivo del mapa.")
		return
	var selected := manager.call("get_selected_zone") as Dictionary
	if String(selected.id) != "zone_200_atardecer" or manager.call("get_selected_world_position") != selected.position:
		_fail("La selección no expone el objetivo para mapa/HUD.")
		return

	# La nueva instancia recupera tanto progreso como objetivo seleccionado.
	var loaded_manager: Node = manager_script.new()
	loaded_manager.save_path = _save_path
	loaded_manager.auto_load_on_ready = false
	loaded_manager.auto_track_local_player = false
	root.add_child(loaded_manager)
	loaded_manager.call("initialize", true)
	if int(loaded_manager.call("get_completed_count")) != 3 or String((loaded_manager.call("get_selected_zone") as Dictionary).id) != "zone_200_atardecer":
		_fail("La carga versionada no restauró progreso y selección.")
		return

	# Un principal corrupto debe caer de forma segura al backup válido.
	var corrupt := FileAccess.open(_save_path, FileAccess.WRITE)
	corrupt.store_string("{esto no es json")
	corrupt = null
	var recovered_manager: Node = manager_script.new()
	recovered_manager.save_path = _save_path
	recovered_manager.auto_load_on_ready = false
	recovered_manager.auto_track_local_player = false
	root.add_child(recovered_manager)
	recovered_manager.call("initialize", true)
	if int(recovered_manager.call("get_completed_count")) < 1:
		_fail("La carga segura no recuperó el backup tras corromper el guardado principal.")
		return

	manager.queue_free()
	deterministic_manager.queue_free()
	loaded_manager.queue_free()
	recovered_manager.queue_free()
	_cleanup_test_files()
	print("EXPLORATION MANAGER TEST OK: 200 zonas deterministas, E, eventos, selección y autoguardado seguro.")
	quit(0)


func _cleanup_test_files() -> void:
	for suffix in ["", ".bak", ".tmp", ".other", ".other.bak", ".other.tmp"]:
		var path: String = _save_path + String(suffix)
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	_cleanup_test_files()
	push_error(message)
	quit(1)
