extends SceneTree

class ControlRed:
	extends Node
	var recibido := false
	var confirmado := false
	@rpc("any_peer", "call_remote", "reliable", 4)
	func pedir(datos: Dictionary) -> void:
		if not multiplayer.is_server() or multiplayer.get_remote_sender_id() <= 1: return
		recibido = datos.posicion == Vector3(13, 27, -8) and datos.bloque.size() == 16000 and datos.bloque[15999] == 71
		confirmar.rpc_id(multiplayer.get_remote_sender_id(), recibido)
	@rpc("authority", "call_remote", "reliable", 4)
	func confirmar(valor: bool) -> void: confirmado = valor
	@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
	func terminar() -> void:
		if multiplayer.is_server(): confirmado = true

func _init() -> void: call_deferred("_comprobar")
func _comprobar() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--host" in args
	var codigo := ""
	var archivo := "/private/tmp/senderos_sala_prueba.txt"
	var url := "ws://127.0.0.1:8770/senderos/coop/ws"
	for arg in args:
		if arg.begins_with("--sala="): codigo = arg.trim_prefix("--sala=")
		if arg.begins_with("--archivo="): archivo = arg.trim_prefix("--archivo=")
		if arg.begins_with("--url="): url = arg.trim_prefix("--url=")
	var sesion := root.get_node("NetworkSession")
	root.get_node("GameSettings").set_player_identity("PruebaWebHost" if host else "PruebaWebInvitado", 1, false)
	var control := ControlRed.new()
	control.name = "ControlWeb"
	root.add_child(control)
	var error: Error = sesion.host_web(url) if host else sesion.join_web(codigo, url)
	if error != OK: push_error("No se inició la conexión web"); quit(1); return
	var inicio := Time.get_ticks_msec()
	var enviado := false
	var publicado := false
	while Time.get_ticks_msec() - inicio < 20000:
		await process_frame
		if host and not publicado and sesion.is_host():
			FileAccess.open(archivo, FileAccess.WRITE).store_string(sesion.get_web_room_code())
			publicado = true
		if not host and sesion.session_mode == sesion.SessionMode.CLIENT and not enviado:
			var bloque := PackedByteArray()
			bloque.resize(16000)
			bloque.fill(71)
			control.pedir.rpc_id(1, {"posicion":Vector3(13,27,-8), "bloque":bloque})
			enviado = true
		if not host and control.confirmado:
			control.terminar.rpc_id(1)
			await create_timer(0.5).timeout
			print("WEB_COOP_CLIENT_OK id=%s roster=%s" % [root.get_multiplayer().get_unique_id(), sesion.get_player_count()])
			sesion.leave_session()
			quit(0)
			return
		if host and control.recibido and control.confirmado and sesion.get_player_count() == 2:
			print("WEB_COOP_HOST_OK sala=%s roster=2 RPC 16000 bytes y canales 1/4" % sesion.get_web_room_code())
			await create_timer(0.8).timeout
			sesion.leave_session()
			quit(0)
			return
	push_error("La RPC web no completó el viaje: host=%s, modo=%s, peers=%s" % [host,sesion.session_mode,root.get_multiplayer().get_peers()])
	quit(1)
