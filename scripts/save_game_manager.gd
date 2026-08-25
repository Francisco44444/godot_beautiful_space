extends Node

## Ranuras completas de aventura. Una ranura individual usa el nombre del
## jugador; una cooperativa ordena los nombres de todos sus integrantes para que
## el mismo grupo encuentre siempre la misma partida, sin depender del peer_id.

signal save_completed(slot_path: String, display_name: String)
signal load_completed(slot_path: String, display_name: String)
signal slots_changed(slots: Array)
signal status_changed(message: String)

const SAVE_VERSION := 2
const SAVE_DIRECTORY := "user://savegames"
const AUTOSAVE_SECONDS := 120.0
const SOLO_AUTOSAVE_SECONDS := 30.0

var _world: Node
var _autosave_elapsed := 0.0
var _last_slot_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	NetworkSession.session_started.connect(_on_session_started)
	NetworkSession.roster_changed.connect(func(_roster: Dictionary) -> void: slots_changed.emit(list_slots()))


func _process(delta: float) -> void:
	if not is_instance_valid(_world) or NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		return
	_autosave_elapsed += delta
	var interval := AUTOSAVE_SECONDS if NetworkSession.is_networked() else SOLO_AUTOSAVE_SECONDS
	if _autosave_elapsed >= interval:
		_autosave_elapsed = 0.0
		save_current_game("autoguardado")


func bind_world(world: Node) -> void:
	_world = world
	_autosave_elapsed = 0.0


func save_current_game(reason: String = "manual") -> bool:
	if not is_instance_valid(_world) or NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		status_changed.emit("Solo el anfitrión puede guardar la expedición cooperativa")
		return false
	var identities := _party_identities()
	var slot_path := _slot_path_for_identities(identities)
	var party_states := NetworkSession.get_party_save_states() if NetworkSession.is_networked() else {}
	var local_state := _world.call("get_local_player_save_state") as Dictionary
	party_states[String(GameSettings.player_name)] = local_state
	var players: Array[Dictionary] = []
	for identity_value in identities:
		var identity := identity_value as Dictionary
		var player_name := String(identity.get("name", "Aventurero"))
		var state: Dictionary = (party_states.get(player_name, {}) as Dictionary).duplicate(true)
		state["name"] = player_name
		state["character_index"] = int(identity.get("character_index", 0))
		players.append(state)
	var exploration := get_node_or_null("/root/ExplorationManager")
	var payload := {
		"schema_version": SAVE_VERSION,
		"display_name": _display_name(identities),
		"reason": reason,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"players": players,
		"world": _world.call("get_shared_world_save_state"),
		"exploration": exploration.call("get_save_state") if exploration != null else {},
	}
	if not _write_json(slot_path, payload):
		status_changed.emit("No se pudo escribir la partida")
		return false
	_last_slot_path = slot_path
	var display := String(payload.display_name)
	status_changed.emit("✓ Partida guardada · %s" % display)
	save_completed.emit(slot_path, display)
	slots_changed.emit(list_slots())
	return true


func load_slot(slot_path: String) -> bool:
	if NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		status_changed.emit("El anfitrión debe cargar la partida")
		return false
	var payload := _read_payload(slot_path)
	if payload.is_empty() or not is_instance_valid(_world):
		status_changed.emit("La ranura no se pudo leer")
		return false
	_world.call("apply_shared_world_save_state", payload.get("world", {}))
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration != null:
		exploration.call("apply_save_state", payload.get("exploration", {}), true)
	var party_by_name: Dictionary = {}
	for value in payload.get("players", []):
		if value is Dictionary:
			var state := (value as Dictionary).duplicate(true)
			party_by_name[String(state.get("name", "Aventurero"))] = state
	NetworkSession.set_loaded_party_states(party_by_name)
	var local_state: Dictionary = party_by_name.get(GameSettings.player_name, {})
	if not local_state.is_empty():
		_world.call("apply_local_player_save_state", local_state)
	_last_slot_path = slot_path
	_autosave_elapsed = 0.0
	var display := String(payload.get("display_name", slot_path.get_file().get_basename()))
	status_changed.emit("✓ Partida cargada · %s" % display)
	load_completed.emit(slot_path, display)
	return true


func load_latest_for_current_party() -> bool:
	var expected := _slot_path_for_identities(_party_identities())
	return load_slot(expected) if FileAccess.file_exists(expected) else false


func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		return result
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "json":
			var path := SAVE_DIRECTORY + "/" + file_name
			var payload := _read_payload(path)
			if not payload.is_empty():
				result.append({
					"path": path,
					"display_name": String(payload.get("display_name", file_name.get_basename())),
					"saved_at_unix": int(payload.get("saved_at_unix", 0)),
					"player_count": (payload.get("players", []) as Array).size(),
				})
		file_name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.saved_at_unix) > int(b.saved_at_unix))
	return result


func get_autosave_seconds() -> float:
	return AUTOSAVE_SECONDS


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(_world):
		save_current_game("cierre")


func _on_session_started(mode_name: String) -> void:
	_autosave_elapsed = 0.0
	# En solitario la identidad basta para elegir sin ambigüedad. En cooperativo
	# se carga desde el menú cuando ya está reunido el grupo de jugadores.
	if mode_name == "solo":
		call_deferred("load_latest_for_current_party")


func _party_identities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in NetworkSession.get_roster().values():
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	if result.is_empty():
		result.append({"name": GameSettings.player_name, "character_index": GameSettings.character_index})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return result


func _slot_path_for_identities(identities: Array[Dictionary]) -> String:
	var names := PackedStringArray()
	for identity in identities:
		names.append(_safe_key(String(identity.get("name", "Aventurero"))))
	var prefix := "coop" if NetworkSession.is_networked() else "solo"
	return "%s/%s_%s.json" % [SAVE_DIRECTORY, prefix, "__".join(names)]


func _display_name(identities: Array[Dictionary]) -> String:
	var names := PackedStringArray()
	for identity in identities:
		names.append(String(identity.get("name", "Aventurero")))
	return "Expedición de %s" % " + ".join(names) if NetworkSession.is_networked() else "Aventura de %s" % names[0]


func _safe_key(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		result += character if character in "abcdefghijklmnopqrstuvwxyz0123456789-_" else "_"
	while "__" in result:
		result = result.replace("__", "_")
	return result.strip_edges().left(32) if not result.strip_edges().is_empty() else "aventurero"


func _write_json(path: String, payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	var reader := FileAccess.open(temporary, FileAccess.READ)
	if reader == null:
		return false
	var encoded := reader.get_as_text()
	reader = null
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(encoded)
	output.flush()
	output = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return true


func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", -1)) != SAVE_VERSION:
		return {}
	return parsed as Dictionary
