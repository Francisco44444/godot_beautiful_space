extends Node

## Sesión cooperativa ENet para un anfitrión y hasta siete invitados. El mundo
## sigue siendo jugable sin conexión; al crear o unirse, este singleton replica
## identidad, posición, orientación, velocidad y objeto equipado de cada héroe.

signal session_started(mode_name: String)
signal session_ended()
signal session_status_changed(message: String)
signal roster_changed(roster: Dictionary)
signal remote_state_received(peer_id: int, position: Vector3, yaw: float, velocity: Vector3, equipped_slot: int)

enum SessionMode {
	OFFLINE,
	HOST,
	CONNECTING,
	CLIENT,
}

const PORT := 24567
const MAX_PLAYERS := 8
const CHARACTER_COUNT := 8
const STATE_SEND_RATE := 15.0
const WORLD_LIMIT := 6200.0

var session_mode := SessionMode.OFFLINE
var players: Dictionary = {}
var _peer: ENetMultiplayerPeer
var _state_accumulator := 0.0
var _active_port := PORT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		settings.connect("identity_changed", Callable(self, "_on_local_identity_changed"))
	_set_offline_roster()


func _physics_process(delta: float) -> void:
	if session_mode not in [SessionMode.HOST, SessionMode.CLIENT]:
		return
	_state_accumulator += delta
	if _state_accumulator < 1.0 / STATE_SEND_RATE:
		return
	_state_accumulator = 0.0
	var local_players := get_tree().get_nodes_in_group("local_player")
	if local_players.is_empty():
		return
	var player := local_players[0] as CharacterBody3D
	if player == null:
		return
	var peer_id := multiplayer.get_unique_id()
	var yaw := float(player.call("get_network_facing_yaw"))
	var equipped_slot := int(player.get("equipped_slot"))
	if session_mode == SessionMode.HOST:
		_broadcast_state(peer_id, player.global_position, yaw, player.velocity, equipped_slot)
	else:
		_server_receive_state.rpc_id(1, player.global_position, yaw, player.velocity, equipped_slot)


func play_offline() -> void:
	leave_session()
	session_started.emit("solo")
	session_status_changed.emit("Partida individual lista")


func host_game(port_value: int = PORT) -> Error:
	if not _is_valid_port(port_value):
		session_status_changed.emit("Puerto no válido: %d" % port_value)
		return ERR_INVALID_PARAMETER
	leave_session()
	_peer = ENetMultiplayerPeer.new()
	# create_server cuenta clientes remotos; anfitrión + 7 invitados = 8.
	var error := _peer.create_server(port_value, MAX_PLAYERS - 1)
	if error != OK:
		_peer = null
		session_status_changed.emit("No se pudo abrir el puerto UDP %d: %s" % [port_value, error_string(error)])
		return error
	_active_port = port_value
	multiplayer.multiplayer_peer = _peer
	session_mode = SessionMode.HOST
	players = {1: _local_identity()}
	_emit_roster()
	session_started.emit("anfitrión")
	session_status_changed.emit("Partida creada · puerto UDP %d · 1/%d jugadores" % [_active_port, MAX_PLAYERS])
	return OK


func join_game(address: String, port_value: int = PORT) -> Error:
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		clean_address = "127.0.0.1"
	if not _is_valid_port(port_value):
		session_status_changed.emit("Puerto no válido: %d" % port_value)
		return ERR_INVALID_PARAMETER
	leave_session()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(clean_address, port_value)
	if error != OK:
		_peer = null
		session_status_changed.emit("No se pudo iniciar la conexión: %s" % error_string(error))
		return error
	_active_port = port_value
	multiplayer.multiplayer_peer = _peer
	session_mode = SessionMode.CONNECTING
	session_status_changed.emit("Conectando con %s:%d…" % [clean_address, _active_port])
	return OK


func leave_session() -> void:
	var was_networked := session_mode != SessionMode.OFFLINE
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_mode = SessionMode.OFFLINE
	_active_port = PORT
	_state_accumulator = 0.0
	_set_offline_roster()
	if was_networked:
		session_ended.emit()


func get_roster() -> Dictionary:
	return players.duplicate(true)


func get_identity(peer_id: int) -> Dictionary:
	if players.has(peer_id):
		return (players[peer_id] as Dictionary).duplicate(true)
	return {"name": "Aventurero %d" % peer_id, "character_index": 0}


func get_player_count() -> int:
	return players.size()


func get_active_port() -> int:
	return _active_port


func get_mode_name() -> String:
	match session_mode:
		SessionMode.HOST:
			return "Anfitrión"
		SessionMode.CONNECTING:
			return "Conectando"
		SessionMode.CLIENT:
			return "Invitado"
	return "Individual"


func is_networked() -> bool:
	return session_mode in [SessionMode.HOST, SessionMode.CLIENT]


func get_lan_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if ":" in address or address.begins_with("127.") or address == "0.0.0.0":
			continue
		result.append(address)
	return result


func _on_connected_to_server() -> void:
	session_mode = SessionMode.CLIENT
	var identity := _local_identity()
	_server_register_identity.rpc_id(1, String(identity.name), int(identity.character_index))
	session_started.emit("invitado")
	session_status_changed.emit("Conectado al anfitrión")


func _on_connection_failed() -> void:
	leave_session()
	session_status_changed.emit("No se pudo conectar con el anfitrión")


func _on_server_disconnected() -> void:
	leave_session()
	session_status_changed.emit("El anfitrión cerró la partida")


func _on_peer_connected(peer_id: int) -> void:
	if session_mode == SessionMode.HOST:
		session_status_changed.emit("Jugador %d conectado; esperando identidad…" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if players.erase(peer_id):
		_emit_roster()
	if session_mode == SessionMode.HOST:
		# El peer aún puede figurar en MultiplayerAPI durante esta señal. Diferir
		# un frame evita enviar al canal ENet que acaba de cerrarse.
		call_deferred("_broadcast_roster")


func _on_local_identity_changed(name_value: String, index_value: int) -> void:
	var local_id := multiplayer.get_unique_id() if session_mode != SessionMode.OFFLINE else 1
	players[local_id] = {"name": name_value, "character_index": index_value}
	_emit_roster()
	if session_mode == SessionMode.HOST:
		_broadcast_roster()
	elif session_mode == SessionMode.CLIENT:
		_server_register_identity.rpc_id(1, name_value, index_value)


@rpc("any_peer", "call_remote", "reliable")
func _server_register_identity(name_value: String, index_value: int) -> void:
	if not multiplayer.is_server() or session_mode != SessionMode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	if not players.has(sender) and players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	players[sender] = {
		"name": _sanitize_network_name(name_value),
		"character_index": clampi(index_value, 0, CHARACTER_COUNT - 1),
	}
	_emit_roster()
	_broadcast_roster()
	session_status_changed.emit("%s se unió · %d/%d jugadores" % [players[sender].name, players.size(), MAX_PLAYERS])


@rpc("authority", "call_remote", "reliable")
func _client_sync_roster(network_roster: Dictionary) -> void:
	players.clear()
	for raw_peer_id in network_roster:
		var identity := network_roster[raw_peer_id] as Dictionary
		players[int(raw_peer_id)] = {
			"name": _sanitize_network_name(String(identity.get("name", "Aventurero"))),
			"character_index": clampi(int(identity.get("character_index", 0)), 0, CHARACTER_COUNT - 1),
		}
	_emit_roster()


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _server_receive_state(position: Vector3, yaw: float, velocity: Vector3, equipped_slot: int) -> void:
	if not multiplayer.is_server() or session_mode != SessionMode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or not players.has(sender) or not _is_valid_state(position, yaw, velocity, equipped_slot):
		return
	remote_state_received.emit(sender, position, yaw, velocity, equipped_slot)
	_broadcast_state(sender, position, yaw, velocity, equipped_slot)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _client_receive_state(peer_id: int, position: Vector3, yaw: float, velocity: Vector3, equipped_slot: int) -> void:
	if peer_id == multiplayer.get_unique_id() or not _is_valid_state(position, yaw, velocity, equipped_slot):
		return
	remote_state_received.emit(peer_id, position, yaw, velocity, equipped_slot)


func _is_valid_state(position: Vector3, yaw: float, velocity: Vector3, equipped_slot: int) -> bool:
	if (
		is_nan(position.x) or is_nan(position.y) or is_nan(position.z)
		or is_inf(position.x) or is_inf(position.y) or is_inf(position.z)
		or is_nan(yaw) or is_inf(yaw)
	):
		return false
	if absf(position.x) > WORLD_LIMIT or absf(position.z) > WORLD_LIMIT or absf(position.y) > 1800.0:
		return false
	if velocity.length() > 90.0:
		return false
	return equipped_slot >= 0 and equipped_slot <= 4


func _is_valid_port(port_value: int) -> bool:
	return port_value >= 1 and port_value <= 65535


func _broadcast_roster() -> void:
	if session_mode != SessionMode.HOST or not multiplayer.is_server():
		return
	for raw_peer_id in players:
		var peer_id := int(raw_peer_id)
		if peer_id != 1 and _is_peer_ready(peer_id):
			_client_sync_roster.rpc_id(peer_id, players)


func _broadcast_state(
	source_peer_id: int,
	position: Vector3,
	yaw: float,
	velocity: Vector3,
	equipped_slot: int
) -> void:
	if session_mode != SessionMode.HOST or not multiplayer.is_server():
		return
	for raw_peer_id in players:
		var target_peer_id := int(raw_peer_id)
		if target_peer_id == 1 or target_peer_id == source_peer_id:
			continue
		if _is_peer_ready(target_peer_id):
			_client_receive_state.rpc_id(
				target_peer_id,
				source_peer_id,
				position,
				yaw,
				velocity,
				equipped_slot
			)


func _is_peer_ready(peer_id: int) -> bool:
	if _peer == null or peer_id not in multiplayer.get_peers():
		return false
	var packet_peer := _peer.get_peer(peer_id)
	return packet_peer != null and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED


func _local_identity() -> Dictionary:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return {"name": "Aventurero", "character_index": 0}
	return {"name": String(settings.get("player_name")), "character_index": int(settings.get("character_index"))}


func _set_offline_roster() -> void:
	players = {1: _local_identity()}
	_emit_roster()


func _emit_roster() -> void:
	roster_changed.emit(get_roster())


func _sanitize_network_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while "  " in clean:
		clean = clean.replace("  ", " ")
	if clean.is_empty():
		clean = "Aventurero"
	return clean.left(24)
