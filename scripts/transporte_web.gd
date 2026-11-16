extends MultiplayerPeerExtension

## El NAS sólo transporta paquetes; las mismas RPC y validaciones del juego
## siguen ejecutándose en el anfitrión. Funciona también desde Windows y Mac.
signal sala_lista(codigo: String)
signal fallo(mensaje: String)
const MAX_PAQUETE := 65536
const CABECERA := 8
var socket := WebSocketPeer.new()
var codigo_sala := ""
var anfitrion := false
var _id := 1
var _estado := MultiplayerPeer.CONNECTION_DISCONNECTED
var _destino := 0
var _canal := 0
var _modo := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _rechazar := false
var _recibidos: Array[Dictionary] = []
var _inicio := 0

func conectar(url: String, crear: bool, codigo: String, version: String) -> Error:
	anfitrion = crear
	_id = 1
	_estado = MultiplayerPeer.CONNECTION_CONNECTING
	_inicio = Time.get_ticks_msec()
	socket.inbound_buffer_size = 4 * 1024 * 1024
	socket.outbound_buffer_size = 4 * 1024 * 1024
	var direccion := "%s?accion=%s&sala=%s&version=%s" % [url, "crear" if crear else "unir", codigo.uri_encode(), version.uri_encode()]
	var error := socket.connect_to_url(direccion)
	if error != OK: _estado = MultiplayerPeer.CONNECTION_DISCONNECTED
	return error

func _poll() -> void:
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_estado = MultiplayerPeer.CONNECTION_DISCONNECTED
		return
	if _estado == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() - _inicio > 15000:
		fallo.emit("El NAS no responde; vuelve a intentarlo")
		_close()
		return
	while socket.get_available_packet_count() > 0:
		var paquete := socket.get_packet()
		if socket.was_string_packet():
			var mensaje = JSON.parse_string(paquete.get_string_from_utf8())
			if not mensaje is Dictionary: continue
			match String(mensaje.get("tipo", "")):
				"bienvenida":
					_id = int(mensaje.id)
					codigo_sala = String(mensaje.sala)
					_estado = MultiplayerPeer.CONNECTION_CONNECTED
					sala_lista.emit(codigo_sala)
					if not anfitrion: peer_connected.emit(1)
				"entra":
					if anfitrion: peer_connected.emit(int(mensaje.id))
				"sale":
					if anfitrion: peer_disconnected.emit(int(mensaje.id))
				"error":
					fallo.emit(String(mensaje.get("mensaje", "No se pudo abrir la sala")))
					_close()
		elif paquete.size() > CABECERA and paquete.size() <= MAX_PAQUETE + CABECERA:
			if _recibidos.size() >= 4096:
				fallo.emit("La conexión no puede seguir el ritmo de la partida")
				_close()
				return
			_recibidos.append({"origen":paquete.decode_s32(0), "canal":int(paquete[4]), "modo":int(paquete[5]), "datos":paquete.slice(CABECERA)})

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _estado != MultiplayerPeer.CONNECTION_CONNECTED: return ERR_UNCONFIGURED
	if buffer.size() > MAX_PAQUETE: return ERR_OUT_OF_MEMORY
	var paquete := PackedByteArray()
	paquete.resize(CABECERA)
	paquete.encode_s32(0, _destino)
	paquete[4] = _canal
	paquete[5] = _modo
	paquete.append_array(buffer)
	return socket.send(paquete, WebSocketPeer.WRITE_MODE_BINARY)

func _get_available_packet_count() -> int: return _recibidos.size()
func _get_packet_script() -> PackedByteArray: return _recibidos.pop_front().datos if not _recibidos.is_empty() else PackedByteArray()
func _get_packet_peer() -> int: return int(_recibidos[0].origen) if not _recibidos.is_empty() else 0
func _get_packet_channel() -> int: return int(_recibidos[0].canal) if not _recibidos.is_empty() else 0
func _get_packet_mode() -> MultiplayerPeer.TransferMode: return _recibidos[0].modo if not _recibidos.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _get_connection_status() -> MultiplayerPeer.ConnectionStatus: return _estado
func _get_max_packet_size() -> int: return MAX_PAQUETE
func _get_unique_id() -> int: return _id
func _is_server() -> bool: return anfitrion
func _is_server_relay_supported() -> bool: return false
func _get_transfer_channel() -> int: return _canal
func _get_transfer_mode() -> MultiplayerPeer.TransferMode: return _modo
func _set_target_peer(peer: int) -> void: _destino = peer
func _set_transfer_channel(channel: int) -> void: _canal = clampi(channel, 0, 255)
func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void: _modo = mode
func _is_refusing_new_connections() -> bool: return _rechazar
func _set_refuse_new_connections(enable: bool) -> void: _rechazar = enable
func _disconnect_peer(peer: int, _force: bool) -> void:
	if anfitrion and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify({"tipo":"expulsar", "id":peer}))
func _close() -> void:
	socket.close()
	_estado = MultiplayerPeer.CONNECTION_DISCONNECTED
	_recibidos.clear()
