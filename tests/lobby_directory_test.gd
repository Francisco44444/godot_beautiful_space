extends SceneTree

## Integración real contra server/lobby_directory/lobby_server.py:
##   LOBBY_TRUST_PROXY=0 LOBBY_PORT=24690 python3 server/lobby_directory/lobby_server.py
##   godot ... --script res://tests/lobby_directory_test.gd

const API_URL := "http://127.0.0.1:24690/v1"
const GAME_PORT := 24691

var _directory: Node
var _session: Node
var _last_status := ""
var _room_updates := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_directory = root.get_node_or_null("LobbyDirectory")
	_session = root.get_node_or_null("NetworkSession")
	if _directory == null or _session == null:
		_fail("Faltan los singletons de red y directorio.")
		return
	_directory.api_base_url = API_URL
	_directory.directory_status_changed.connect(func(message: String) -> void: _last_status = message)
	_directory.rooms_changed.connect(func(_rooms: Array) -> void: _room_updates += 1)

	_directory.refresh_rooms()
	if not await _wait_for_room_updates(1, 5.0) or not (_directory.get_rooms() as Array).is_empty():
		_fail("El tablón local no comenzó vacío.")
		return

	var host_error: Error = _session.host_game(GAME_PORT)
	if host_error != OK:
		_fail("No se pudo crear el anfitrión de prueba.")
		return
	_directory.publish_room("Expedición de integración")
	if not await _wait_for_status("publicada", 5.0):
		_fail("El NAS de prueba no confirmó la publicación: %s" % _last_status)
		return

	_directory.refresh_rooms()
	if not await _wait_for_room_updates(2, 5.0):
		_fail("No llegó la lista publicada.")
		return
	var rooms := _directory.get_rooms() as Array
	if rooms.size() != 1:
		_fail("Se esperaba exactamente una sala publicada.")
		return
	var room := rooms[0] as Dictionary
	if (
		String(room.name) != "Expedición de integración"
		or int(room.port) != GAME_PORT
		or not bool(_directory.is_compatible(room))
	):
		_fail("La sala publicada perdió nombre, puerto o versión: %s" % JSON.stringify(room))
		return

	_session.leave_session()
	await create_timer(0.3).timeout
	_directory.refresh_rooms()
	if not await _wait_for_room_updates(3, 5.0) or not (_directory.get_rooms() as Array).is_empty():
		_fail("La sala no se retiró al cerrar el anfitrión.")
		return
	print("LOBBY DIRECTORY TEST OK: publicar, listar, unir por metadatos y retirar funcionan.")
	quit(0)


func _wait_for_status(fragment: String, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_seconds:
		if fragment.to_lower() in _last_status.to_lower():
			return true
		await process_frame
	return false


func _wait_for_room_updates(expected: int, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_seconds:
		if _room_updates >= expected:
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	if _session != null:
		_session.leave_session()
	push_error(message)
	quit(1)
