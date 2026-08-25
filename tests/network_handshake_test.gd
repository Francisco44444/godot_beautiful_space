extends SceneTree

## Prueba de integración en dos procesos:
##   godot ... --script res://tests/network_handshake_test.gd -- --host --port=24681
##   godot ... --script res://tests/network_handshake_test.gd -- --client --port=24681
## Prueba del aforo (un host y siete procesos cliente):
##   godot ... --script res://tests/network_handshake_test.gd -- --capacity-host --port=24682
##   Ejecutar siete clientes con --capacity-client --client-id=1..7 y el mismo puerto.

class DummyPlayer:
	extends CharacterBody3D
	var equipped_slot := 0
	var network_yaw := 0.0

	func get_network_facing_yaw() -> float:
		return network_yaw

var _settings: Node
var _session: Node
var _remote_states: Dictionary = {}
var _port := 24681


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings = root.get_node_or_null("GameSettings")
	_session = root.get_node_or_null("NetworkSession")
	if _settings == null or _session == null:
		push_error("No se cargaron los singletons de sesión.")
		quit(2)
		return
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--port="):
			_port = int(argument.trim_prefix("--port="))
	if "--capacity-host" in arguments:
		await _run_capacity_host()
	elif "--capacity-client" in arguments:
		await _run_capacity_client()
	elif "--host" in arguments:
		await _run_host()
	elif "--client" in arguments:
		await _run_client()
	else:
		push_error("Usa --host o --client.")
		quit(2)


func _run_capacity_host() -> void:
	var error: Error = _session.call("host_game", _port)
	if error != OK:
		push_error("No se pudo crear el host de aforo: %s" % error_string(error))
		quit(1)
		return
	if not await _wait_for_players(8, 15.0):
		push_error("El servidor no llegó a registrar siete invitados de prueba.")
		_session.call("leave_session")
		quit(1)
		return
	if root.get_multiplayer().get_peers().size() != 7:
		push_error("El aforo no coincide con 1 anfitrión + 7 invitados.")
		_session.call("leave_session")
		quit(1)
		return
	await create_timer(4.0).timeout
	_session.call("leave_session")
	print("NETWORK CAPACITY HOST OK: roster máximo total de 8 (1 + 7).")
	quit(0)


func _run_capacity_client() -> void:
	var client_id := OS.get_process_id()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--client-id="):
			client_id = int(argument.trim_prefix("--client-id="))
	_settings.call("set_player_identity", "InvitadoAforo%d" % client_id, client_id % 8, false)
	var error: Error = _session.call("join_game", "127.0.0.1", _port)
	if error != OK:
		push_error("No se pudo iniciar el cliente de aforo: %s" % error_string(error))
		quit(1)
		return
	if not await _wait_for_players(8, 15.0):
		push_error("El cliente no recibió el roster máximo de ocho jugadores.")
		_session.call("leave_session")
		quit(1)
		return
	# Escalonar los cierres evita que siete procesos abandonen exactamente en el
	# mismo tick, una situación artificial que ensucia la salida interna de ENet.
	await create_timer(0.5 + float(client_id) * 0.2).timeout
	_session.call("leave_session")
	print("NETWORK CAPACITY CLIENT OK: roster de 8 recibido.")
	quit(0)


func _run_host() -> void:
	_settings.call("set_player_identity", "AnfitriónTest", 2, false)
	_session.connect("remote_state_received", Callable(self, "_on_remote_state_received"))
	var dummy := _make_dummy(Vector3(11.0, 2.0, -7.0), 0.75, Vector3(2.0, 0.0, -1.0), 2)
	var error: Error = _session.call("host_game", _port)
	if error != OK:
		push_error("No se pudo crear el host: %s" % error_string(error))
		quit(1)
		return
	if not await _wait_for_players(2, 10.0):
		push_error("El host no recibió al invitado.")
		_session.call("leave_session")
		quit(1)
		return
	if not await _wait_for_remote_state(Vector3(-19.0, 3.0, 14.0), 10.0):
		push_error("El host no recibió el estado remoto del invitado.")
		_session.call("leave_session")
		quit(1)
		return
	# Mantener el host vivo unos fotogramas garantiza que el cliente reciba el
	# último estado y pueda cerrar primero de manera limpia.
	await create_timer(0.5).timeout
	_session.call("leave_session")
	dummy.queue_free()
	print("NETWORK HOST OK: roster, estado remoto y cierre ENet verificados.")
	quit(0)


func _run_client() -> void:
	_settings.call("set_player_identity", "InvitadoTest", 5, false)
	_session.connect("remote_state_received", Callable(self, "_on_remote_state_received"))
	var dummy := _make_dummy(Vector3(-19.0, 3.0, 14.0), -1.25, Vector3(-3.0, 0.0, 2.0), 4)
	var error: Error = _session.call("join_game", "127.0.0.1", _port)
	if error != OK:
		push_error("No se pudo iniciar el cliente: %s" % error_string(error))
		quit(1)
		return
	if await _wait_for_players(2, 10.0):
		var roster: Dictionary = _session.call("get_roster")
		var found_host := false
		var found_client := false
		for identity in roster.values():
			found_host = found_host or String(identity.name) == "AnfitriónTest"
			found_client = found_client or String(identity.name) == "InvitadoTest"
		if found_host and found_client and await _wait_for_remote_state(Vector3(11.0, 2.0, -7.0), 10.0):
			# El primer estado del cliente puede llegar antes que su identidad y el
			# servidor lo descarta correctamente. Dejamos varios ticks posteriores.
			await create_timer(0.5).timeout
			_session.call("leave_session")
			dummy.queue_free()
			print("NETWORK CLIENT OK: roster y estado del anfitrión sincronizados por UDP.")
			quit(0)
			return
	push_error("El cliente no recibió el roster completo.")
	_session.call("leave_session")
	quit(1)


func _wait_for_players(count: int, timeout_seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) / 1000.0 < timeout_seconds:
		if int(_session.call("get_player_count")) >= count:
			return true
		await process_frame
	return false


func _make_dummy(position: Vector3, yaw: float, movement: Vector3, slot: int) -> DummyPlayer:
	var dummy := DummyPlayer.new()
	dummy.position = position
	dummy.network_yaw = yaw
	dummy.velocity = movement
	dummy.equipped_slot = slot
	dummy.add_to_group("local_player")
	root.add_child(dummy)
	return dummy


func _on_remote_state_received(
	peer_id: int,
	position: Vector3,
	_yaw: float,
	_velocity: Vector3,
	_equipped_slot: int
) -> void:
	_remote_states[peer_id] = position


func _wait_for_remote_state(expected_position: Vector3, timeout_seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) / 1000.0 < timeout_seconds:
		for position in _remote_states.values():
			if (position as Vector3).distance_to(expected_position) < 0.01:
				return true
		await process_frame
	return false
