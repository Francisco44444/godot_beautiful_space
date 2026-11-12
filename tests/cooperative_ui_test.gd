extends SceneTree

class Pulso:
	extends Node
	var pasos := 0
	func _physics_process(_delta: float) -> void: pasos += 1

class ControlRed:
	extends Node
	signal respuesta(datos: Dictionary)
	var consultar := Callable()
	@rpc("any_peer","call_remote","reliable",4)
	func pedir(orden: String) -> void:
		if multiplayer.is_server():
			var datos: Dictionary = await consultar.call(orden)
			devolver.rpc_id(multiplayer.get_remote_sender_id(),datos)
	@rpc("authority","call_remote","reliable",4)
	func devolver(datos: Dictionary) -> void: respuesta.emit(datos)

var mundo: Node3D
var jugador: Player
var hud: Node
var sesion: Node
var control: ControlRed
var pulso: Pulso
var respuesta: Dictionary = {}
var anfitrion := false
var terminado := false
var capturas := false
var tajos_locales: Array[String] = []
var tajos_replicados := {}

func _init() -> void: call_deferred("_probar")

func _probar() -> void:
	var puerto := 24702
	anfitrion = "--host" in OS.get_cmdline_user_args()
	capturas = "--capture" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): puerto = int(arg.trim_prefix("--port="))
	root.get_node("GameSettings").set_player_identity("MenuHost" if anfitrion else "MenuInvitado",0,false)
	for nombre in ["InventoryManager","ExplorationManager"]: root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	current_scene = mundo
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	jugador = mundo.get_node("Player")
	jugador.attack_started.connect(func(_numero: int): tajos_locales.append(jugador.get_library_animation()))
	mundo.get_node("NetworkPlayers").child_entered_tree.connect(_registrar_replica)
	hud = mundo.get_node("HUD")
	mundo.get_node("RPGStoryRuntime").set("_damage_cooldown",1000000000.0)
	mundo.sun_cycle_radians = 1.08
	mundo._update_sun_cycle(0.0)
	if capturas:
		root.get_node("GameSettings").set_resolution(Vector2i(1600,900),false)
		root.always_on_top = true
		root.show()
	pulso = Pulso.new()
	mundo.add_child(pulso)
	control = ControlRed.new()
	control.name = "ControlInterfaz"
	# El control de prueba recibe órdenes incluso con el defecto original;
	# el pulso y todos los actores conservan el modo normal de la escena.
	control.process_mode = Node.PROCESS_MODE_ALWAYS
	control.consultar = Callable(self,"_orden")
	control.respuesta.connect(func(datos: Dictionary): respuesta = datos)
	mundo.add_child(control)
	sesion = root.get_node("NetworkSession")
	var error: Error = sesion.host_game(puerto) if anfitrion else sesion.join_game("127.0.0.1",puerto)
	if error!=OK: _fallar("No se pudo iniciar ENet."); return
	if anfitrion:
		print("UI HOST READY")
		var inicio := Time.get_ticks_msec()
		while not terminado and Time.get_ticks_msec()-inicio<180000: await process_frame
		if not terminado: _fallar("El invitado no terminó la prueba de menús."); return
		await create_timer(0.5).timeout
		print("UI HOST PASS")
	else:
		if not await _esperar(func(): return sesion.get_player_count()==2 and mundo.get_node("NetworkPlayers").get_node_or_null("Peer_1")!=null):
			_fallar("No llegó la expedición real."); return
		await create_timer(1.0).timeout
		if not await _recorrer(): return
		print("UI CLIENT PASS")
		sesion.leave_session()
		# Una desconexión con el inventario abierto recupera la pausa individual.
		if not paused or not jugador.entrada_interfaz_bloqueada: _fallar("Salir de la expedición no recupera la pausa individual."); return
		_abrir("inventario",false)
	sesion.leave_session()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit(0)

func _abrir(ventana: String, abrir: bool) -> void:
	match ventana:
		"dialogo":
			if abrir:
				for memoria in get_nodes_in_group("cave_memory"):
					if memoria.memory_id=="forest:start":
						jugador.global_position = memoria.global_position+Vector3(1,0.1,0)
						memoria.interact(jugador)
						break
			else: hud._set_story_dialogue_open(false)
		"inventario": hud._set_inventory_open(abrir)
		"diario": hud._set_exploration_journal_open(abrir)
		"ajustes": hud._set_settings_open(abrir)
		"vestibulo": hud._set_lobby_open(abrir)
		"pausa": hud.pause_menu.set_open(abrir)
	if abrir:
		Input.action_release("attack")
		Input.action_release("block")

func _orden(orden: String) -> Dictionary:
	if orden.begins_with("abrir:"): _abrir(orden.trim_prefix("abrir:"),true)
	elif orden.begins_with("cerrar:"): _abrir(orden.trim_prefix("cerrar:"),false)
	elif orden=="caminar":
		Input.action_press("move_right")
		await create_timer(0.4).timeout
		Input.action_release("move_right")
		# La posición de referencia se toma después de frenar, no al soltar la
		# tecla mientras el héroe todavía recorre medio metro por su inercia.
		await create_timer(0.4).timeout
	elif orden.begins_with("gesto:"): await _preparar_gesto(orden.trim_prefix("gesto:"))
	elif orden=="combo": await _completar_combo()
	elif orden=="fin": terminado = true
	var replicados := {}
	var gestos := {}
	for nodo in mundo.get_node("NetworkPlayers").get_children():
		if nodo is Player:
			replicados[String(nodo.name)] = [nodo.global_position.x,nodo.global_position.y,nodo.global_position.z]
			gestos[String(nodo.name)] = _gestos(nodo)
	return {"pausa":paused,"pasos":pulso.pasos,"sol":mundo.sun_cycle_radians,"bloqueado":jugador.entrada_interfaz_bloqueada,"replicas":replicados,"gestos_replicas":gestos,"gestos":_gestos(jugador),"posicion":[jugador.global_position.x,jugador.global_position.y,jugador.global_position.z],"tajos":tajos_locales,"tajos_replicados":tajos_replicados}

func _registrar_replica(nodo: Node) -> void:
	if not nodo is Player: return
	var actor := nodo as Player
	var nombre := String(actor.name)
	tajos_replicados[nombre] = []
	actor.attack_started.connect(func(_numero: int): tajos_replicados[nombre].append(actor.get_library_animation()))

func _completar_combo() -> void:
	Input.action_release("attack")
	jugador.equip_item(1)
	jugador.draw_weapon()
	await create_timer(0.9).timeout
	tajos_locales.clear()
	for i in 3:
		Input.action_press("attack")
		for paso in 2: await physics_frame
		Input.action_release("attack")
		for paso in 2: await physics_frame
	if not await _esperar(func(): return tajos_locales.size()>=3 and not jugador.is_attacking):
		_fallar("Los clics reales no completan el combo cooperativo.")
	await create_timer(0.5).timeout

func _gestos(actor: Player) -> Dictionary:
	return {"arco":actor.is_drawing_bow,"carga":actor.is_charging_attack(),"guardia":actor.is_guarding}

func _preparar_gesto(tipo: String) -> void:
	Input.action_release("attack")
	Input.action_release("block")
	jugador.equip_item(3 if tipo=="arco" else 1)
	if tipo!="arco": jugador.draw_weapon()
	await create_timer(0.9).timeout
	Input.action_press("block" if tipo=="guardia" else "attack")
	if tipo=="carga":
		if not await _esperar(func(): return jugador.is_charging_attack()):
			_fallar("Mantener el botón tras el tajo no prepara la carga.")
			return
	await create_timer(0.15).timeout

func _consultar(orden: String) -> bool:
	respuesta = {}
	control.pedir.rpc_id(1,orden)
	if not await _esperar(func(): return not respuesta.is_empty()): _fallar("No llegó la orden de prueba "+orden); return false
	return true

func _recorrer() -> bool:
	var cadena := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
	await _completar_combo()
	if not await _consultar("estado"): return false
	var id_local := "Peer_%d" % sesion.multiplayer.get_unique_id()
	if tajos_locales!=cadena or respuesta.tajos_replicados.get(id_local,[])!=cadena:
		_fallar("El anfitrión no representa los tres tajos reales del invitado."); return false
	if not await _consultar("combo"): return false
	if respuesta.tajos!=cadena or tajos_replicados.get("Peer_1",[])!=cadena:
		_fallar("El invitado no representa los tres tajos reales del anfitrión."); return false
	print("COOPERATIVE COMBO PASS: clics reales A/B/C en ambos sentidos.")
	for ventana in ["dialogo","inventario","diario","ajustes","vestibulo","pausa"]:
		if not await _consultar("abrir:"+ventana): return false
		if bool(respuesta.pausa) or not bool(respuesta.bloqueado): _fallar("El menú del anfitrión detiene la expedición: "+ventana); return false
		var pasos := int(respuesta.pasos)
		var sol := float(respuesta.sol)
		var inicial := jugador.global_position
		Input.action_press("move_right")
		await create_timer(0.4).timeout
		Input.action_release("move_right")
		await create_timer(0.6).timeout
		if not await _consultar("estado"): return false
		if int(respuesta.pasos)<=pasos+10 or float(respuesta.sol)<=sol:
			_fallar("La física o el reloj del anfitrión se detienen en "+ventana); return false
		if _distancia_plana(inicial,jugador.global_position)<0.5:
			_fallar("El compañero no puede caminar mientras el anfitrión lee."); return false
		var pos: Array = respuesta.replicas.get("Peer_%d" % sesion.multiplayer.get_unique_id(),[])
		if pos.size()!=3 or _distancia_plana(Vector3(pos[0],pos[1],pos[2]),jugador.global_position)>0.25:
			_fallar("La réplica del invitado se congela detrás del menú del anfitrión."); return false
		var dato := {"ventana":ventana,"pasos_host":int(respuesta.pasos)-pasos,"avance_sol":float(respuesta.sol)-sol,"movimiento_invitado":_distancia_plana(inicial,jugador.global_position),"error_replica_invitado":_distancia_plana(Vector3(pos[0],pos[1],pos[2]),jugador.global_position)}
		if not await _consultar("cerrar:"+ventana): return false
		_abrir(ventana,true)
		if paused or not jugador.entrada_interfaz_bloqueada: _fallar("El menú del invitado congela su mundo."); return false
		var local_pasos := pulso.pasos
		var replica := mundo.get_node("NetworkPlayers/Peer_1") as Player
		inicial = replica.global_position
		if not await _consultar("caminar"): return false
		await create_timer(0.6).timeout
		var host := Vector3(respuesta.posicion[0],respuesta.posicion[1],respuesta.posicion[2])
		if pulso.pasos<=local_pasos+10 or _distancia_plana(inicial,replica.global_position)<0.5 or _distancia_plana(host,replica.global_position)>0.25:
			_fallar("El invitado deja de ver caminar al anfitrión mientras lee."); return false
		dato["pasos_invitado"] = pulso.pasos-local_pasos
		dato["movimiento_host"] = _distancia_plana(inicial,replica.global_position)
		dato["error_replica_host"] = _distancia_plana(host,replica.global_position)
		await _capturar(ventana)
		_abrir(ventana,false)
		print("COOPERATIVE UI WINDOW PASS ",JSON.stringify(dato))
	for tipo in ["carga","arco","guardia"]:
		await _preparar_gesto(tipo)
		if not _gestos(jugador)[tipo]: _fallar("El invitado no inicia el gesto de control "+tipo); return false
		await create_timer(0.25).timeout
		if not await _consultar("estado"): return false
		var id := "Peer_%d" % sesion.multiplayer.get_unique_id()
		if not bool(respuesta.gestos_replicas.get(id,{}).get(tipo,false)): _fallar("No llega el gesto del invitado "+tipo); return false
		_abrir("inventario",true)
		Input.action_release("attack")
		Input.action_release("block")
		await create_timer(0.3).timeout
		if not await _consultar("estado"): return false
		if bool(respuesta.gestos_replicas.get(id,{}).get(tipo,true)): _fallar("El menú no cancela el gesto remoto del invitado "+tipo); return false
		_abrir("inventario",false)
		if not await _consultar("gesto:"+tipo): return false
		if not bool(respuesta.gestos[tipo]): _fallar("El anfitrión no inicia el gesto de control "+tipo); return false
		await create_timer(0.25).timeout
		var replica := mundo.get_node("NetworkPlayers/Peer_1") as Player
		if not _gestos(replica)[tipo]: _fallar("No llega el gesto del anfitrión "+tipo); return false
		if not await _consultar("abrir:inventario"): return false
		await create_timer(0.3).timeout
		if _gestos(replica)[tipo]: _fallar("El menú no cancela el gesto remoto del anfitrión "+tipo); return false
		if not await _consultar("cerrar:inventario"): return false
		print("COOPERATIVE UI CANCEL PASS ",tipo)
	_abrir("inventario",true)
	return await _consultar("fin")

func _distancia_plana(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _capturar(nombre: String) -> void:
	if not capturas: return
	for i in 8: await process_frame
	RenderingServer.force_draw(false,0.0)
	var carpeta := "res://generated/reviews/2026-11-12/armas/enet/imagenes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	assert(root.get_texture().get_image().save_png(carpeta.path_join(nombre+".png"))==OK)

func _esperar(condicion: Callable) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio<10000:
		if condicion.call(): return true
		await process_frame
	return false

func _fallar(mensaje: String) -> void:
	Input.action_release("move_right")
	Input.action_release("attack")
	Input.action_release("block")
	paused = false
	push_error(mensaje)
	quit(1)
