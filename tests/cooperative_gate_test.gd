extends SceneTree

class ControlPuerta:
	extends Node
	signal recibido(nombre: String, datos: Dictionary)
	var consultar := Callable()
	@rpc("any_peer", "call_remote", "reliable", 4)
	func pedir(nombre: String = "estado") -> void:
		if multiplayer.is_server(): responder.rpc_id(multiplayer.get_remote_sender_id(), nombre, consultar.call(nombre))
	@rpc("authority", "call_remote", "reliable", 4)
	func responder(nombre: String, datos: Dictionary) -> void: recibido.emit(nombre, datos)

var mundo: Node3D
var jugador: Player
var puerta: RPGCaveGate
var sesion: Node
var control: ControlPuerta
var respuesta: Dictionary = {}
var respuestas: Dictionary = {}
var anfitrion := false
var terminado := false
var aperturas: Dictionary = {}
var camara: Camera3D

func _init() -> void: call_deferred("_probar")
func _probar() -> void:
	var puerto := 24701
	anfitrion = "--host" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): puerto = int(arg.trim_prefix("--port="))
	var tardio := "--late" in OS.get_cmdline_user_args()
	root.get_node("GameSettings").set_player_identity("PuertaHost" if anfitrion else ("PuertaTardia" if tardio else "PuertaInvitado"), 0, false)
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	var inventario := root.get_node("InventoryManager")
	inventario.reset_inventory_for_tests(false)
	for llave in ["Key1", "Key2", "Key3", "Key4"]:
		var cantidad: int = inventario.get_count(llave)
		if cantidad > 0: inventario.remove_item(llave, cantidad, false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	current_scene = mundo
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	jugador = mundo.get_node("Player")
	jugador.set_physics_process(false)
	for enemigo in get_nodes_in_group("rpg_enemy") + get_nodes_in_group("rpg_boss"): enemigo.set_physics_process(false)
	if "--capture" in OS.get_cmdline_user_args():
		root.get_node("GameSettings").set_resolution(Vector2i(1600, 900), false)
		root.always_on_top = true
		root.show()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		OS.low_processor_usage_mode = false
		mundo.get_node("HUD").hide()
		mundo.get_node("CameraRig").set_process(false)
		mundo.get_node("CameraRig").set_physics_process(false)
		camara = Camera3D.new()
		mundo.add_child(camara)
		camara.current = true
		camara.fov = 62
	for nodo in get_nodes_in_group("rpg_cave_gate"):
		aperturas[nodo.gate_id] = 0
		nodo.gate_opened.connect(func(id: String, _llave: String): aperturas[id] = int(aperturas[id]) + 1)
		if nodo.gate_id == "roots": puerta = nodo
	if puerta == null: _fallar("Falta la puerta real de Raíces."); return
	jugador.global_position = Vector3(0, 800, 0) if anfitrion else puerta.to_global(Vector3(0, 0.6, 2.8))
	control = ControlPuerta.new()
	control.name = "ControlPuerta"
	control.consultar = Callable(self, "_estado")
	control.recibido.connect(func(nombre: String, datos: Dictionary): respuestas[nombre] = datos)
	mundo.add_child(control)
	sesion = root.get_node("NetworkSession")
	var error: Error = sesion.host_game(puerto) if anfitrion else sesion.join_game("127.0.0.1", puerto)
	if error != OK: _fallar("No se pudo abrir ENet."); return
	if anfitrion:
		print("GATE HOST READY")
		var inicio := Time.get_ticks_msec()
		while not terminado and Time.get_ticks_msec() - inicio < 120000: await process_frame
		if not terminado: _fallar("No terminó el recorrido de puertas."); return
		await create_timer(0.4).timeout
		print("GATE HOST PASS")
	else:
		if not await _esperar(func(): return sesion.get_player_count() == 2): _fallar("No llegó el anfitrión."); return
		# La intención de apertura debe conservar el inventario antes del guardado;
		# la instantánea de cuatro segundos no puede ocultar una omisión.
		sesion.set("_save_snapshot_accumulator", -1000000.0)
		await create_timer(0.7).timeout
		if tardio:
			if not await _esperar(func():
				for nodo in get_nodes_in_group("rpg_cave_gate"):
					if not nodo.opened: return false
				return true): _fallar("La incorporación tardía no recupera las puertas abiertas."); return
			for nodo in get_nodes_in_group("rpg_cave_gate"):
				if _bloquea(nodo) or inventario.has_item(nodo.key_item_id): _fallar("El invitado tardío necesita llaves o conserva una colisión cerrada."); return
			if not await _consultar("fin"): return
			print("GATE LATE CLIENT PASS")
		else:
			if not await _recorrer(): return
			print("GATE CLIENT PASS")
	sesion.leave_session()
	quit(0)

func _estado(nombre: String = "estado") -> Dictionary:
	var inmediato := true
	if nombre == "host_abrir":
		# Aislar el envío inmediato: el pulso periódico no puede rescatarlo.
		sesion.set("_world_state_accumulator", -1000000.0)
		var secuencia: int = sesion.get("_transporte_mundo").get("_secuencia")
		jugador.global_position = puerta.to_global(Vector3(0, 0.6, 2.8))
		root.get_node("InventoryManager").add_item("Key1", 1)
		puerta.interact(jugador)
		root.get_node("InventoryManager").remove_item("Key1", 1, false)
		jugador.global_position = Vector3(0, 800, 0)
		inmediato = int(sesion.get("_transporte_mundo").get("_secuencia")) > secuencia
	elif nombre == "restaurar":
		# La carga usa la recuperación periódica normal; sólo la apertura anterior
		# aislaba un envío inmediato por el canal no fiable del mundo.
		sesion.set("_world_state_accumulator", 0.0)
		mundo.get_node("RPGStoryRuntime").apply_save_state({"gates":[]})
		sesion.broadcast_world_state_now()
	elif nombre == "pulso_normal": sesion.set("_world_state_accumulator", 0.0)
	elif nombre == "fin": terminado = true
	var estados := {}
	for nodo in get_nodes_in_group("rpg_cave_gate"):
		estados[nodo.gate_id] = {"abierta":nodo.opened, "solida":_bloquea(nodo), "aperturas":aperturas[nodo.gate_id], "altura":nodo.get_node("SealedDoor").position.y}
	var instantaneas: Dictionary = sesion.get_party_save_states()
	var invitado: Dictionary = instantaneas.get("PuertaInvitado", {})
	return {"ok":true, "puertas":estados, "llave_host":root.get_node("InventoryManager").has_item("Key1"), "objetos_invitado":invitado.get("inventory", {}).get("items", {}), "envio_inmediato":inmediato}

func _bloquea(acceso: RPGCaveGate) -> bool:
	var a := acceso.to_global(Vector3(0, 1.5, 1.5))
	var b := acceso.to_global(Vector3(0, 1.5, -1.5))
	var hit := mundo.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
	return hit.get("collider") == acceso

func _consultar(nombre: String) -> bool:
	respuestas.erase(nombre)
	control.pedir.rpc_id(1, nombre)
	if not await _esperar(func(): return respuestas.has(nombre)): _fallar("No llega la consulta " + nombre); return false
	respuesta = respuestas[nombre]
	return true

func _recorrer() -> bool:
	var inventario := root.get_node("InventoryManager")
	var gestor := mundo.get_node("PuertasCooperativas")
	if not await _esperar(func(): return int(gestor.get("_revision_host")) >= 0): _fallar("No se recibió la revisión del mundo."); return false
	# La primera apertura debe llegar por el canal fiable, incluso sin aplicar
	# ninguna instantánea del mundo; se comprueba aparte que ésta se emite.
	sesion.world_state_received.disconnect(Callable(mundo, "_on_network_world_state_received"))
	if not await _consultar("host_abrir"): return false
	if not bool(respuesta.envio_inmediato): _fallar("La apertura no comunica un estado inmediato del mundo."); return false
	if not await _esperar(func(): return puerta.opened): _fallar("La apertura del anfitrión no llega al invitado sin llave."); return false
	sesion.world_state_received.connect(Callable(mundo, "_on_network_world_state_received"))
	var revision_vieja := int(gestor.get("_revision_host"))
	if not await _consultar("restaurar"): return false
	if not await _esperar(func(): return not puerta.opened and int(gestor.get("_revision_host")) != revision_vieja): _fallar("La carga no restituye la puerta cerrada."); return false
	await create_timer(1.3).timeout
	if not _bloquea(puerta) or not is_equal_approx(puerta.get_node("SealedDoor").position.y, 2.0): _fallar("El tween viejo reabre una puerta restaurada."); return false
	puerta.interact(jugador)
	await create_timer(0.35).timeout
	if puerta.opened: _fallar("Se abre una puerta sin llave local."); return false
	for defecto in ["sin_llave", "llave_erronea", "distancia", "posicion_invalida", "tipo_invalido", "id_inexistente", "revision_vieja"]:
		var estado: Dictionary = sesion._local_save_snapshot(jugador)
		estado.inventory.items = {"Key1":1}
		var revision := int(gestor.get("_revision_host"))
		var id := puerta.gate_id
		match defecto:
			"sin_llave": estado.inventory.items = {}
			"llave_erronea": estado.inventory.items = {"Key2":1}
			"distancia": estado.position = [0, 800, 0]
			"posicion_invalida": estado.position = [NAN, 0, 0]
			"tipo_invalido": estado.position = [{}, 0, 0]
			"id_inexistente": id = "gruta_inexistente"
			"revision_vieja": revision = revision_vieja
		gestor.rpc_id(1, "_pedir_apertura", id, revision, estado)
		await create_timer(0.35).timeout
		if not await _consultar("estado"): return false
		if puerta.opened or respuesta.puertas[puerta.gate_id].abierta: _fallar("Se acepta la petición inválida " + defecto); return false
		print("GATE INVALID REJECTED ", defecto)
	# Las aperturas del invitado deben funcionar también si se pierde el canal
	# de instantáneas: la confirmación fiable conserva su puerta y colisión.
	sesion.world_state_received.disconnect(Callable(mundo, "_on_network_world_state_received"))
	for nodo in get_nodes_in_group("rpg_cave_gate"):
		puerta = nodo
		jugador.global_position = puerta.to_global(Vector3(0, 0.6, 2.8))
		inventario.add_item(puerta.key_item_id, 1)
		await create_timer(0.35).timeout
		await _capturar(puerta.gate_id + "_cerrada")
		var antes := int(aperturas[puerta.gate_id])
		if not jugador._interact_with_adventure_object(): _fallar("La interacción normal no alcanza la puerta."); return false
		if not await _esperar(func(): return puerta.opened): _fallar("El invitado con llave no abre " + puerta.gate_id); return false
		await create_timer(0.15).timeout
		var inicial: float = puerta.get_node("SealedDoor").position.y
		await create_timer(0.4).timeout
		var medio: float = puerta.get_node("SealedDoor").position.y
		await create_timer(0.8).timeout
		if not (inicial > 2 and medio > inicial and is_equal_approx(puerta.get_node("SealedDoor").position.y, 4.8)) or int(aperturas[puerta.gate_id]) != antes + 1:
			_fallar("Las instantáneas reinician la animación o repiten la apertura."); return false
		if not await _consultar("estado"): return false
		var remoto: Dictionary = respuesta.puertas[puerta.gate_id]
		if not remoto.abierta or remoto.solida or _bloquea(puerta) or bool(respuesta.llave_host):
			_fallar("La puerta abierta por el invitado no coincide con la puerta física del anfitrión."); return false
		if int(respuesta.objetos_invitado.get(puerta.key_item_id, 0)) < 1:
			_fallar("El guardado del anfitrión pierde la llave del invitado que abre la puerta."); return false
		print("GATE SHARED PASS ", puerta.gate_id)
		await _capturar(puerta.gate_id + "_abierta")
		if puerta.gate_id == "roots":
			# Una puerta ya abierta no emite otra apertura. Su respuesta individual
			# debe rescatar a quien hubiera perdido la confirmación anterior.
			puerta.apply_save_state({"id":puerta.gate_id, "opened":false})
			await physics_frame
			if not jugador._interact_with_adventure_object(): _fallar("No se puede reenviar la interacción de Raíces."); return false
			if not await _esperar(func(): return puerta.opened): _fallar("El invitado con llave no abre roots al reenviar su petición."); return false
			for i in 2: await physics_frame
			if not await _consultar("estado"): return false
			if _bloquea(puerta) or int(respuesta.puertas[puerta.gate_id].aperturas) != int(remoto.aperturas):
				_fallar("Reenviar una apertura repite el evento del anfitrión o deja colisión en el cliente."); return false
			print("GATE CONFIRMATION REPLAY PASS")
	if not await _consultar("pulso_normal"): return false
	return true

func _capturar(nombre: String) -> void:
	if camara == null: return
	camara.global_position = puerta.to_global(Vector3(1.4, 3.2, 8))
	camara.look_at(puerta.to_global(Vector3(0, 2, 0)))
	mundo.sincronizar_camara_terreno()
	for i in 30: await process_frame
	RenderingServer.force_draw(false, 0.0)
	var carpeta := "res://generated/reviews/2026-11-10/puertas-cooperativas/imagenes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var imagen := root.get_texture().get_image()
	assert(not imagen.is_empty() and imagen.save_png(carpeta.path_join(nombre + ".png")) == OK)

func _esperar(condicion: Callable) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 8000:
		if condicion.call(): return true
		await process_frame
	return false

func _fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
