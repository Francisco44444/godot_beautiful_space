extends Node

## Cliente del tablón público de partidas alojado en el Synology. El tráfico
## del juego continúa usando ENet/UDP; esta API solo anuncia y descubre salas.

signal rooms_changed(rooms: Array)
signal directory_status_changed(message: String)

const DEFAULT_API_URL := "https://franfuco4444.synology.me:24568/v1"
const LAN_API_URL := "http://192.168.0.25:24570/v1"
const HEARTBEAT_FALLBACK_SECONDS := 15.0
const MAX_RESPONSE_BYTES := 256 * 1024

var api_base_url := DEFAULT_API_URL
var rooms: Array = []
var _list_request: HTTPRequest
var _lease_request: HTTPRequest
var _endpoint_probe: HTTPRequest
var _effective_api_url := DEFAULT_API_URL
var _endpoint_ready := false
var _pending_refresh := false
var _pending_room_name := ""
var _lease_operation := ""
var _hosted_room_id := ""
var _lease_token := ""
var _heartbeat_interval := HEARTBEAT_FALLBACK_SECONDS
var _heartbeat_elapsed := 0.0
var _last_room_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_list_request = _make_request("RoomListRequest")
	_list_request.request_completed.connect(_on_list_completed)
	_lease_request = _make_request("RoomLeaseRequest")
	_lease_request.request_completed.connect(_on_lease_completed)
	_endpoint_probe = _make_request("LanEndpointProbe")
	_endpoint_probe.timeout = 1.2
	_endpoint_probe.request_completed.connect(_on_endpoint_probe_completed)
	NetworkSession.session_ended.connect(_on_session_ended)
	NetworkSession.roster_changed.connect(_on_roster_changed)
	_probe_endpoint()


func _process(delta: float) -> void:
	if _hosted_room_id.is_empty() or NetworkSession.session_mode != NetworkSession.SessionMode.HOST:
		return
	_heartbeat_elapsed += delta
	if _heartbeat_elapsed >= _heartbeat_interval:
		_heartbeat_elapsed = 0.0
		_send_heartbeat()


func refresh_rooms() -> void:
	if not _endpoint_ready:
		_pending_refresh = true
		return
	if not _request_available(_list_request):
		_list_request.cancel_request()
	var error := _list_request.request(
		_api_url("/rooms"),
		["Accept: application/json", "Cache-Control: no-cache"],
		HTTPClient.METHOD_GET
	)
	if error != OK:
		directory_status_changed.emit("No se pudo consultar el tablón: %s" % error_string(error))


func publish_room(room_name: String) -> void:
	if NetworkSession.session_mode != NetworkSession.SessionMode.HOST:
		directory_status_changed.emit("Primero hay que crear la partida local")
		return
	if not _endpoint_ready:
		_pending_room_name = room_name
		directory_status_changed.emit("Comprobando la conexión con el NAS…")
		return
	if not _hosted_room_id.is_empty():
		_last_room_name = _clean_room_name(room_name)
		_send_heartbeat()
		return
	if not _request_available(_lease_request):
		_lease_request.cancel_request()
	_last_room_name = _clean_room_name(room_name)
	_lease_operation = "create"
	var body := JSON.stringify({
		"name": _last_room_name,
		"host_name": GameSettings.player_name,
		"port": NetworkSession.get_active_port(),
		"players": NetworkSession.get_player_count(),
		"max_players": NetworkSession.MAX_PLAYERS,
		"game_version": _game_version(),
	})
	var error := _lease_request.request(
		_api_url("/rooms"),
		["Accept: application/json", "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		_lease_operation = ""
		directory_status_changed.emit("La partida funciona, pero no pudo anunciarse: %s" % error_string(error))
	else:
		directory_status_changed.emit("Publicando la expedición en el NAS…")


func unpublish_room() -> void:
	if _hosted_room_id.is_empty() or _lease_token.is_empty():
		_clear_lease()
		return
	if not _request_available(_lease_request):
		_lease_request.cancel_request()
	_lease_operation = "delete"
	var error := _lease_request.request(
		_api_url("/rooms/%s" % _hosted_room_id),
		_authorized_headers(),
		HTTPClient.METHOD_DELETE
	)
	if error != OK:
		_clear_lease()


func get_rooms() -> Array:
	return rooms.duplicate(true)


func get_room(index: int) -> Dictionary:
	if index < 0 or index >= rooms.size():
		return {}
	return (rooms[index] as Dictionary).duplicate(true)


func is_compatible(room: Dictionary) -> bool:
	return String(room.get("game_version", "")) == _game_version()


func _send_heartbeat() -> void:
	if _hosted_room_id.is_empty() or _lease_token.is_empty() or not _request_available(_lease_request):
		return
	_lease_operation = "heartbeat"
	var body := JSON.stringify({
		"players": NetworkSession.get_player_count(),
		"name": _last_room_name,
	})
	var error := _lease_request.request(
		_api_url("/rooms/%s" % _hosted_room_id),
		_authorized_headers(),
		HTTPClient.METHOD_PATCH,
		body
	)
	if error != OK:
		_lease_operation = ""


func _on_list_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		rooms.clear()
		rooms_changed.emit(get_rooms())
		directory_status_changed.emit("Tablón no disponible; usa Avanzado si estás en la misma red")
		return
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if not payload is Dictionary or int(payload.get("schema", 0)) != 1 or not payload.get("rooms", []) is Array:
		directory_status_changed.emit("El tablón devolvió una respuesta no válida")
		return
	rooms.clear()
	for raw_room in payload.rooms:
		if raw_room is Dictionary and _valid_public_room(raw_room):
			rooms.append((raw_room as Dictionary).duplicate(true))
	rooms_changed.emit(get_rooms())
	directory_status_changed.emit(
		"%d partida%s activa%s" % [rooms.size(), "" if rooms.size() == 1 else "s", "" if rooms.size() == 1 else "s"]
	)


func _on_endpoint_probe_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_endpoint_ready = true
	_effective_api_url = LAN_API_URL if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 else api_base_url
	if _pending_refresh:
		_pending_refresh = false
		refresh_rooms()
	if not _pending_room_name.is_empty():
		var room_name := _pending_room_name
		_pending_room_name = ""
		publish_room(room_name)


func _on_lease_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var operation := _lease_operation
	_lease_operation = ""
	if operation == "delete":
		_clear_lease()
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if operation == "create":
			directory_status_changed.emit("La partida está creada, pero el NAS no pudo anunciarla")
		elif response_code in [401, 404]:
			_clear_lease()
		return
	if operation == "create":
		var payload = JSON.parse_string(body.get_string_from_utf8())
		if not payload is Dictionary or not payload.get("room", {}) is Dictionary:
			directory_status_changed.emit("El NAS no confirmó la publicación")
			return
		_hosted_room_id = String((payload.room as Dictionary).get("id", ""))
		_lease_token = String(payload.get("lease_token", ""))
		_heartbeat_interval = clampf(float(payload.get("heartbeat_interval_seconds", HEARTBEAT_FALLBACK_SECONDS)), 5.0, 30.0)
		_heartbeat_elapsed = 0.0
		if _hosted_room_id.is_empty() or _lease_token.is_empty():
			_clear_lease()
			directory_status_changed.emit("El NAS devolvió una credencial incompleta")
			return
		directory_status_changed.emit("Partida publicada en el NAS · %d/%d jugadores" % [NetworkSession.get_player_count(), NetworkSession.MAX_PLAYERS])


func _on_session_ended() -> void:
	unpublish_room()


func _on_roster_changed(_roster: Dictionary) -> void:
	if not _hosted_room_id.is_empty():
		_heartbeat_elapsed = _heartbeat_interval


func _make_request(node_name: String) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.name = node_name
	request.timeout = 8.0
	request.download_file = ""
	request.accept_gzip = true
	request.body_size_limit = MAX_RESPONSE_BYTES
	add_child(request)
	return request


func _request_available(request: HTTPRequest) -> bool:
	return request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED


func _authorized_headers() -> PackedStringArray:
	return PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _lease_token,
	])


func _api_url(path: String) -> String:
	return _effective_api_url.trim_suffix("/") + path


func _probe_endpoint() -> void:
	var error := _endpoint_probe.request(
		LAN_API_URL.trim_suffix("/v1") + "/healthz",
		["Accept: application/json", "Cache-Control: no-cache"],
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_endpoint_ready = true
		_effective_api_url = api_base_url


func _game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _clean_room_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while "  " in clean:
		clean = clean.replace("  ", " ")
	if clean.is_empty():
		clean = "Expedición de %s" % GameSettings.player_name
	return clean.left(40)


func _valid_public_room(room: Dictionary) -> bool:
	return (
		not String(room.get("id", "")).is_empty()
		and not String(room.get("address", "")).is_empty()
		and int(room.get("port", 0)) in range(1, 65536)
		and int(room.get("players", 0)) >= 1
		and int(room.get("max_players", 0)) in range(2, NetworkSession.MAX_PLAYERS + 1)
	)


func _clear_lease() -> void:
	_hosted_room_id = ""
	_lease_token = ""
	_lease_operation = ""
	_heartbeat_interval = HEARTBEAT_FALLBACK_SECONDS
	_heartbeat_elapsed = 0.0
