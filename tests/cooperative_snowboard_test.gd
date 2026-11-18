extends SceneTree
class ControlNieve:
	extends Node
	signal respuesta(nombre: String, datos: Dictionary)
	var consultar: Callable
	@rpc("any_peer","call_remote","reliable",4)
	func pedir(nombre: String) -> void:
		if multiplayer.is_server():recibir.rpc_id(multiplayer.get_remote_sender_id(),nombre,consultar.call(nombre))
	@rpc("authority","call_remote","reliable",4)
	func recibir(nombre: String, datos: Dictionary) -> void:respuesta.emit(nombre,datos)
var m: Node3D
var c: Node
var sesion: Node
var control: ControlNieve
var respuestas := {}
var fin := false
func _init() -> void:call_deferred("_probar")
func exigir(valor: bool, texto: String) -> bool:
	if valor:return true
	push_error(texto);quit(1);return false
func esperar(condicion: Callable, limite: int = 10000) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio<limite:
		if condicion.call():return true
		await process_frame
	return false
func consultar(nombre: String) -> Dictionary:
	respuestas.erase(nombre);control.pedir.rpc_id(1,nombre)
	if not await esperar(func():return respuestas.has(nombre)):exigir(false,"No responde el control del anfitrión");return {}
	return respuestas[nombre]
func _probar() -> void:
	var host := "--host" in OS.get_cmdline_user_args();var tarde := "--late" in OS.get_cmdline_user_args()
	var puerto := 24877;var url := "";var sala := "";var archivo := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):puerto = int(a.trim_prefix("--port="))
		if a.begins_with("--web-url="):url = a.trim_prefix("--web-url=")
		if a.begins_with("--sala="):sala = a.trim_prefix("--sala=")
		if a.begins_with("--archivo="):archivo = a.trim_prefix("--archivo=")
	root.get_node("GameSettings").set_player_identity("NieveHost" if host else ("NieveTardia" if tarde else "NieveInvitado"),0,false)
	for n in ["InventoryManager","ExplorationManager"]:root.get_node(n).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	m = load("res://scenes/world.tscn").instantiate();root.add_child(m);current_scene = m;root.get_node("SaveGameManager").bind_world(null)
	for i in 12:await process_frame
	paused = false;c = m.get_node("RPGStoryRuntime").aventura_pacifica.descenso
	control = ControlNieve.new();control.name = "ControlNieve";control.consultar = Callable(self,"_estado");control.respuesta.connect(func(n: String,d: Dictionary):respuestas[n] = d);m.add_child(control)
	sesion = root.get_node("NetworkSession")
	var error: Error
	if url.is_empty():error = sesion.host_game(puerto) if host else sesion.join_game("127.0.0.1",puerto)
	else:error = sesion.host_web(url) if host else sesion.join_web(sala,url)
	if not exigir(error==OK,"No se abre la sesión de nieve"):return
	if host:
		m.player.set_physics_process(false);m.player.global_position = Vector3(0,800,0)
		if not url.is_empty():
			if not await esperar(func():return not sesion.get_web_room_code().is_empty()):exigir(false,"No se crea la sala web");return
			FileAccess.open(archivo,FileAccess.WRITE).store_string(sesion.get_web_room_code())
		print("SNOW HOST READY")
		if not await esperar(func():return fin,350000):exigir(false,"No acaba la prueba de nieve");return
		await create_timer(0.4).timeout;print("SNOW HOST PASS")
	elif tarde:
		if not await esperar(func():return c.records.has("NieveInvitado")):exigir(false,"El invitado tardío pierde la clasificación");return
		if not exigir(c.carreras.is_empty() and not m.player.en_tabla_nieve and not c.is_physics_processing() and c.rivales.bots.size()==3,"El invitado tardío hereda una carrera terminada"):return
		await consultar("fin");print("SNOW LATE CLIENT PASS")
	else:
		if not await esperar(func():return sesion.get_player_count()==2):exigir(false,"No conecta el invitado");return
		await create_timer(0.6).timeout;sesion.set("_save_snapshot_accumulator",-1000000.0)
		c._pedir_inicio.rpc_id(1);await create_timer(0.5).timeout
		if not exigir(not m.player.en_tabla_nieve,"Se acepta empezar desde lejos"):return
		m.player.global_position = c.puertas[0];m.player.velocity = Vector3.ZERO
		await create_timer(0.7).timeout
		var inventario := root.get_node("InventoryManager");var antes: int = inventario.get_count("Crystal3")
		if not exigir(m.player._interact_with_adventure_object(),"La interacción normal no encuentra las tablas"):return
		if not await esperar(func():return m.player.en_tabla_nieve and not c.carreras.is_empty()):exigir(false,"El servidor no autoriza la salida del invitado");return
		Input.action_press("sprint");Input.action_press("move_forward")
		if not await esperar(func():return c.rivales.tiempo>=0,6000):exigir(false,"No termina la cuenta atrás compartida");return
		await create_timer(1.5).timeout
		var datos := await consultar("pausar")
		if not exigir(datos.tabla_invitado and datos.agachado and datos.rivales==3,"El anfitrión no ve la tabla del invitado"):return
		Input.action_press("move_forward")
		var inicio := Time.get_ticks_msec()
		while c.movimiento!=null and Time.get_ticks_msec()-inicio<240000:
			var id := str(m.multiplayer.get_unique_id());var i: int = c.carreras.get(id,{}).get("puerta",1)
			Input.action_release("sprint")
			if i in [3,4]:Input.action_press("sprint")
			var t: Vector3 = c.puertas[mini(i,c.puertas.size()-1)]-m.player.global_position
			var giro := angle_difference(c.movimiento.rumbo,atan2(-t.x,-t.z))
			var salida_curva: Vector3 = c.puertas[mini(i+1,c.puertas.size()-1)]-c.puertas[mini(i,c.puertas.size()-1)]
			var entrada_curva: Vector3 = c.puertas[mini(i,c.puertas.size()-1)]-c.puertas[maxi(i-1,0)]
			var cerrada: bool = entrada_curva.normalized().dot(salida_curva.normalized())<0.75
			var frenar: bool = absf(giro)>0.60 or (cerrada and t.length()<32 and c.movimiento.rapidez>17)
			Input.action_release("move_forward");Input.action_release("move_back")
			Input.action_press("move_back" if frenar else "move_forward")
			Input.action_release("sprint")
			if not frenar and absf(giro)<0.25:Input.action_press("sprint")
			Input.action_release("move_left");Input.action_release("move_right")
			if absf(giro)>0.035:Input.action_press("move_left" if giro>0 else "move_right")
			await physics_frame
		for a in ["move_forward","move_back","move_left","move_right","sprint"]:Input.action_release(a)
		if not await esperar(func():return c.records.has("NieveInvitado") and inventario.get_count("Crystal3")==antes+3):exigir(false,"El invitado no completa o cobra el descenso real");return
		datos = await consultar("reanudar")
		if not exigir(datos.reloj_nieve>100 and datos.marca>0 and datos.carreras==0 and not datos.tabla_invitado and datos.cristales==antes+3,"El anfitrión pierde marca, tabla o premio inmediato"):return
		if not await esperar(func():return not c.rivales.activa and not c.is_physics_processing(),60000):exigir(false,"La carrera de los mensajeros no termina o deja actividad de fondo");return
		print("SNOW CLIENT PASS")
	sesion.leave_session();quit(0)
func _estado(nombre: String) -> Dictionary:
	if nombre=="pausar":paused = true
	elif nombre=="reanudar":paused = false
	elif nombre=="fin":fin = true
	var tabla := false;var agachado := false
	for p in m.network_players.get_children():
		tabla = tabla or p.en_tabla_nieve;agachado = agachado or p.postura_nieve.x>0.8
	var d: Dictionary = sesion.get_party_save_states().get("NieveInvitado",{})
	return {"rivales":c.rivales.bots.size(),"reloj_nieve":c.rivales.tiempo,"agachado":agachado,"tabla_invitado":tabla,"carreras":c.carreras.size(),"marca":float(c.records.get("NieveInvitado",0)),"cristales":d.get("inventory",{}).get("items",{}).get("Crystal3",0)}
