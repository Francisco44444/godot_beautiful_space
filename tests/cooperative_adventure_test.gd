extends SceneTree

class ControlAventura:
	extends Node
	signal respuesta(nombre: String, datos: Dictionary)
	var consultar: Callable
	@rpc("any_peer","call_remote","reliable",4)
	func pedir(nombre: String) -> void:
		if multiplayer.is_server(): recibir.rpc_id(multiplayer.get_remote_sender_id(),nombre,consultar.call(nombre))
	@rpc("authority","call_remote","reliable",4)
	func recibir(nombre: String, datos: Dictionary) -> void: respuesta.emit(nombre,datos)

var mundo: Node3D
var historia: Node
var d: Node
var sesion: Node
var control: ControlAventura
var respuestas := {}
var fin := false
func _init() -> void: call_deferred("_probar")
func _probar() -> void:
	var host := "--host" in OS.get_cmdline_user_args()
	var tarde := "--late" in OS.get_cmdline_user_args()
	var url := ""; var sala := ""; var archivo := ""
	var puerto := 24851
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): puerto = int(arg.trim_prefix("--port="))
		if arg.begins_with("--web-url="): url = arg.trim_prefix("--web-url=")
		if arg.begins_with("--sala="): sala = arg.trim_prefix("--sala=")
		if arg.begins_with("--archivo="): archivo = arg.trim_prefix("--archivo=")
	root.get_node("GameSettings").set_player_identity("AventuraHost" if host else ("AventuraTardia" if tarde else "AventuraInvitado"),0,false)
	for n in ["InventoryManager","ExplorationManager"]: root.get_node(n).set("autosave_enabled",false)
	root.get_node("InventoryManager").reset_inventory_for_tests(false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate(); root.add_child(mundo); current_scene = mundo
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false; mundo.player.set_physics_process(false)
	historia = mundo.get_node("RPGStoryRuntime"); d = historia.aventura_pacifica
	control = ControlAventura.new(); control.name = "ControlAventura"; control.consultar = Callable(self,"_estado")
	control.respuesta.connect(func(n: String,datos: Dictionary): respuestas[n] = datos)
	mundo.add_child(control); sesion = root.get_node("NetworkSession")
	var error: Error
	if url.is_empty(): error = sesion.host_game(puerto) if host else sesion.join_game("127.0.0.1",puerto)
	else: error = sesion.host_web(url) if host else sesion.join_web(sala,url)
	if not exigir(error==OK,"No se abre la sesión"): return
	if host:
		mundo.player.global_position = Vector3(0,800,0)
		if not url.is_empty():
			if not await esperar(func(): return not sesion.get_web_room_code().is_empty()): exigir(false,"No se crea la sala web"); return
			FileAccess.open(archivo,FileAccess.WRITE).store_string(sesion.get_web_room_code())
		print("ADVENTURE HOST READY")
		if not await esperar(func(): return fin,120000): exigir(false,"No termina la prueba cooperativa"); return
		await create_timer(0.4).timeout
		print("ADVENTURE HOST PASS")
	elif tarde:
		if not await esperar(func(): return sesion.get_player_count()==2 and historia.campaign.progress().finished): exigir(false,"La incorporación tardía pierde la campaña"); return
		d = historia.aventura_pacifica
		if not exigir(d.refugios.size()==2 and d.retorno.is_empty(),"El invitado tardío pierde refugios o hereda el descanso del anfitrión"): return
		if not exigir(get_nodes_in_group("rpg_enemy").is_empty(),"Aparecen enemigos al entrar tarde"): return
		await consultar("fin")
		print("ADVENTURE LATE CLIENT PASS")
	else:
		if not await esperar(func(): return sesion.get_player_count()==2): exigir(false,"No conecta el invitado"); return
		await create_timer(0.8).timeout
		mundo.cambiar_modo_aventura(false)
		if not exigir(mundo.modo_aventura,"El invitado cambia las reglas del anfitrión"): return
		sesion.set("_save_snapshot_accumulator",-1000000.0)
		# Un mensaje real desde lejos no puede resolver el mecanismo.
		mundo.player.global_position = Vector3(0,800,0)
		await create_timer(0.4).timeout
		d.interactuar("acto:0:0",mundo.player)
		await create_timer(0.3).timeout
		var datos := await consultar("estado")
		if not exigir(datos.pasos.is_empty(),"Se acepta una interacción a distancia"): return
		for i in 5:
			for j in [[0,1,2],[0,2],[0,0,1,2,2,2],[0,2],[2,0,1]][i]:
				var id := "acto:%d:%d" % [i,j]
				mundo.player.global_position = d.objetos[id].global_position
				await create_timer(0.4).timeout
				d.interactuar(id,mundo.player)
				await create_timer(0.25).timeout
		if not await esperar(func(): return historia.campaign.progress().finished): exigir(false,"No se comparte la resolución de los cinco actos"); return
		if not exigir(historia.player_max_health==225,"El invitado no recibe el crecimiento de los actos compartidos"): return
		var inventario := root.get_node("InventoryManager")
		var objeto: String = historia.sidequests.encargos()[0].target
		var antes: int = inventario.get_count(objeto)
		mundo.player.global_position = d.objetos["encargo:0"].global_position
		await create_timer(0.4).timeout
		d.interactuar("encargo:0",mundo.player)
		var premio: int = int(historia.sidequests.encargos()[0].needed)+3
		if not await esperar(func(): return inventario.get_count(objeto)==antes+premio): exigir(false,"El invitado no recibe su entrega"); return
		datos = await consultar("estado")
		if not exigir(int(datos.items_invitado.get(objeto,0))==antes+premio,"El anfitrión pierde la entrega antes del guardado periódico"): return
		d.interactuar("encargo:0",mundo.player); await create_timer(0.3).timeout
		if not exigir(inventario.get_count(objeto)==antes+premio,"Se duplica la entrega al repetir la interacción"): return
		var madera: int = inventario.get_count("WoodLog")
		if madera>0: inventario.remove_item("WoodLog",madera,false)
		inventario.add_item("WoodLog",6,false)
		mundo.player.global_position = Vector3(-247,mundo.terrain.data.get_height(Vector3(-247,0,40)),40)
		await create_timer(0.5).timeout
		d.construir_refugio()
		if not await esperar(func(): return d.refugios.size()==1 and not d._refugio_pendiente): exigir(false,"El invitado no construye un refugio compartido"); return
		if not exigir(inventario.get_count("WoodLog")==0,"El refugio no consume la madera del constructor"): return
		mundo.player.global_position = d.objetos["refugio:0"].global_position
		await create_timer(0.4).timeout
		d.interactuar("refugio:0",mundo.player)
		if not await esperar(func(): return d.retorno.size()==3): exigir(false,"El invitado no descansa"); return
		var regreso: Array = d.retorno.duplicate()
		datos = await consultar("otro_refugio")
		if not exigir(datos.refugios==2,"No se levanta el segundo refugio"): return
		await create_timer(0.8).timeout
		if not exigir(d.retorno==regreso and d.objetos.has("refugio:0") and d.objetos.has("refugio:1"),"La réplica del mundo pisa el descanso personal o repite identificadores"): return
		var estado: Dictionary = sesion._local_save_snapshot(mundo.player)
		if not exigir(estado.return_position==regreso,"El guardado pierde el refugio personal"): return
		await consultar("cambiar")
		if not await esperar(func(): return not mundo.modo_aventura): exigir(false,"El modo Combate no se replica"); return
		await consultar("volver")
		if not await esperar(func(): return mundo.modo_aventura and historia.campaign.progress().finished): exigir(false,"Volver a Aventura pierde el progreso compartido"); return
		d = historia.aventura_pacifica
		if not exigir(d.refugios.size()==2 and get_nodes_in_group("rpg_enemy").is_empty(),"Volver deja enemigos o pierde refugios"): return
		print("ADVENTURE CLIENT PASS")
	sesion.leave_session(); quit(0)

func _estado(nombre: String) -> Dictionary:
	if nombre=="otro_refugio":
		var inventario := root.get_node("InventoryManager")
		for i in 24:
			var punto := Vector3(-247+cos(i*0.7)*25,0,40+sin(i*0.7)*25)
			punto.y = mundo.terrain.data.get_height(punto)
			if d._ubicacion_refugio(mundo.player,punto).is_finite():
				mundo.player.global_position = punto; inventario.add_item("WoodLog",6,false); d.construir_refugio(); break
		if d.objetos.has("refugio:1"): d._descanso(d.objetos["refugio:1"].global_position)
	elif nombre=="cambiar": mundo.cambiar_modo_aventura(false)
	elif nombre=="volver": mundo.cambiar_modo_aventura(true); d = historia.aventura_pacifica
	elif nombre=="fin": fin = true
	var guardado: Dictionary = sesion.get_party_save_states().get("AventuraInvitado",{})
	return {"items_invitado":guardado.get("inventory",{}).get("items",{}),"pasos":d.pasos if is_instance_valid(d) else {},"refugios":d.refugios.size() if is_instance_valid(d) else 0}
func consultar(nombre: String) -> Dictionary:
	respuestas.erase(nombre); control.pedir.rpc_id(1,nombre)
	if not await esperar(func(): return respuestas.has(nombre)): exigir(false,"No responde el anfitrión: "+nombre); return {}
	return respuestas[nombre]
func esperar(condicion: Callable, limite: int = 8000) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio<limite:
		if condicion.call(): return true
		await process_frame
	return false
func exigir(valor: bool, texto: String) -> bool:
	if valor: return true
	push_error(texto); quit(1); return false
