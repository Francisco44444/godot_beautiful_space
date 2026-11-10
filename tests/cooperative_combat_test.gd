extends SceneTree

## Dos procesos ENet con el mundo real. La plataforma a 800 m aísla el combate
## de enemigos ambientales sin sustituir ventanas de golpe, flechas ni réplicas.
class MotorPrueba:
	extends Node
	var jugador: Player
	func _physics_process(delta: float) -> void:
		jugador.set("_attack_cooldown",maxf(float(jugador.get("_attack_cooldown"))-delta,0.0))
		if jugador.attack_phase==Player.AttackPhase.CHARGING:
			jugador.set("_charge_time",float(jugador.get("_charge_time"))+delta)
			jugador.set("_charge_strength",clampf(float(jugador.get("_charge_time"))/jugador.charge_full_time,0,1))
		if jugador.is_rolling: jugador._update_dodge(delta)
		jugador._update_attack(delta)
		jugador.velocity = Vector3.DOWN*0.2
		jugador.move_and_slide()

class DatosTerrenoPrueba:
	extends RefCounted
	var hueco := false
	func get_height(at: Vector3) -> float: return 805.0 if at.x>11.0 else 799.0
	func get_control_hole(_at: Vector3) -> bool: return hueco

class TerrenoPrueba:
	extends Node3D
	var data: RefCounted

class ControlPrueba:
	extends Node
	signal respuesta(nombre: String, datos: Dictionary)
	var evaluar := Callable()
	@rpc("any_peer","call_remote","reliable",4)
	func pedir(nombre: String) -> void:
		if not multiplayer.is_server() or not evaluar.is_valid(): return
		var datos: Dictionary = evaluar.call(nombre)
		confirmar.rpc_id(multiplayer.get_remote_sender_id(),nombre,datos)
	@rpc("authority","call_remote","reliable",4)
	func confirmar(nombre: String, datos: Dictionary) -> void:
		respuesta.emit(nombre,datos)

var mundo: Node3D
var heroe: Player
var historia: Node
var sesion: Node
var control: ControlPrueba
var enemigos: Dictionary = {}
var respuestas: Dictionary = {}
var pared: StaticBody3D
var es_host := false
var terminar_host := false
var puerto := 24685
var monedas_antes := 0
var estados_mundo := 0
var arbol_red := ""

func _init() -> void: call_deferred("_run_test")

func _run_test() -> void:
	var argumentos := OS.get_cmdline_user_args()
	es_host = "--host" in argumentos
	for argumento in argumentos:
		if argumento.begins_with("--port="): puerto = int(argumento.trim_prefix("--port="))
	root.get_node("GameSettings").set_player_identity("CoopHostCodex" if es_host else "CoopGuestCodex",2,false)
	root.get_node("SaveGameManager").set_process(false)
	for singleton in ["InventoryManager","ExplorationManager"]: root.get_node(singleton).set("autosave_enabled",false)
	root.get_node("InventoryManager").reset_inventory_for_tests(false)
	sesion = root.get_node("NetworkSession")
	sesion.world_state_received.connect(func(_estado: Dictionary): estados_mundo+=1)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	current_scene = mundo
	root.get_node("SaveGameManager").bind_world(null)
	for i in 6: await process_frame
	paused = false
	heroe = mundo.get_node("Player")
	heroe.set_physics_process(false)
	mundo.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	historia = mundo.get_node("RPGStoryRuntime")
	for enemigo in get_nodes_in_group("rpg_enemy")+get_nodes_in_group("rpg_boss"): enemigo.set_physics_process(false)
	var suelo := StaticBody3D.new()
	suelo.position = Vector3(0,799.875,0)
	var forma := CollisionShape3D.new()
	forma.shape = BoxShape3D.new()
	forma.shape.size = Vector3(80,0.25,80)
	suelo.add_child(forma)
	mundo.add_child(suelo)
	heroe.global_position = Vector3(20 if es_host else 0,800.02,0)
	heroe.visual.rotation.y = 0
	var motor := MotorPrueba.new()
	motor.name = "MotorPrueba"
	motor.jugador = heroe
	mundo.add_child(motor)
	heroe.equip_item(1)
	crear_enemigo("frente",Vector3(0,800,-1.65))
	crear_enemigo("espalda",Vector3(0,800,1.8))
	crear_enemigo("arco",Vector3(-12,800,0))
	crear_enemigo("anfitrion",Vector3(20,800,-1.65))
	crear_enemigo("jefe",Vector3(3,800,0),true)
	control = ControlPrueba.new()
	control.name = "ControlPrueba"
	control.evaluar = Callable(self,"_evaluar")
	control.respuesta.connect(func(nombre: String,datos: Dictionary): respuestas[nombre]=datos)
	mundo.add_child(control)
	monedas_antes = root.get_node("InventoryManager").get_count("Coin_Skull")
	var error: Error = sesion.host_game(puerto) if es_host else sesion.join_game("127.0.0.1",puerto)
	if error!=OK: _fallar("No se pudo abrir ENet: "+error_string(error)); return
	if es_host:
		print("COOP COMBAT HOST READY")
		var inicio := Time.get_ticks_msec()
		while not terminar_host and Time.get_ticks_msec()-inicio<65000: await process_frame
		if not terminar_host: _fallar("El invitado no terminó el recorrido."); return
		await create_timer(0.7).timeout
		print("COOP COMBAT HOST PASS")
	else:
		if not await _esperar(func(): return sesion.get_player_count()==2): _fallar("No llegó el roster."); return
		await create_timer(0.4).timeout
		if not await _etapa("anfitrion"): return
		var replica_host := mundo.get_node("NetworkPlayers/Peer_1") as Player
		if not await _esperar(func(): return replica_host.is_attacking): _fallar("No se representa el tajo del anfitrión en el invitado."); return
		if not await _esperar(func(): return enemigos.anfitrion.health==27): _fallar("El golpe del anfitrión no se sincroniza."); return
		var hora_tajo := float(Time.get_ticks_usec())/1000000.0
		if not heroe.start_attack(): _fallar("No empieza el tajo local."); return
		await _reposo()
		if not await _etapa("tajo"): return
		var repetido := _paquete()
		repetido.secuencia = int(sesion.get("_secuencia_combate"))
		sesion.rpc_id(1,"_servidor_accion_combate",repetido)
		for defecto in ["cadencia","arma","giro","nan"]:
			var falso := _paquete()
			var siguiente := int(sesion.get("_secuencia_combate"))+1
			sesion.set("_secuencia_combate",siguiente)
			falso.secuencia = siguiente
			match defecto:
				"cadencia": falso.hora = hora_tajo+0.01
				"arma": falso.objeto = "Bow_Wooden"
				"giro": falso.tipo = "giro"
				"nan": falso.posicion = Vector3(NAN,800,0)
			sesion.rpc_id(1,"_servidor_accion_combate",falso)
		await create_timer(1.2).timeout
		if not await _etapa("invalidos"): return
		if float(replica_host.get("_slash_chain_window"))>0.0: _fallar("El combo remoto no vuelve al primer tajo después de esperar."); return
		if not heroe.start_charge(): _fallar("No empieza la carga."); return
		await create_timer(0.7).timeout
		if not heroe.start_spin_attack(): _fallar("No empieza el giro."); return
		await _reposo()
		if not await _etapa("giro"): return
		if not await _esperar(func(): return int(enemigos.jefe.get("_ward"))==1): _fallar("No se sincroniza la coraza del jefe."); return
		var defensa := int(enemigos.jefe.get("_ward"))
		heroe.attack_phase = Player.AttackPhase.SPIN
		enemigos.jefe.receive_tool_hit("sword","Sword",heroe.global_position,heroe)
		heroe.attack_phase = Player.AttackPhase.NONE
		if "--break-client-ward" in argumentos: enemigos.jefe.set("_ward",defensa-1)
		if int(enemigos.jefe.get("_ward"))!=defensa: _fallar("El invitado cambia una coraza sin autoridad."); return
		enemigos.jefe.set("demand",RPGBoss.Demand.BOW)
		enemigos.jefe.receive_projectile_hit(enemigos.jefe.global_position,heroe)
		enemigos.jefe.set("demand",RPGBoss.Demand.CHARGE)
		if int(enemigos.jefe.get("_ward"))!=defensa: _fallar("Una flecha cliente rompe una defensa sin autoridad."); return
		if not await _etapa("pared_on"): return
		_crear_pared()
		await create_timer(0.1).timeout
		heroe.start_attack()
		await _reposo()
		if not await _etapa("pared_golpe"): return
		pared.queue_free()
		if not await _etapa("pared_off"): return
		await create_timer(0.1).timeout
		heroe.equip_item(3)
		var camara := Camera3D.new()
		mundo.add_child(camara)
		camara.global_position = Vector3(-5,803.2,7)
		camara.look_at(Vector3(-12,800.9,0))
		camara.current = true
		await create_timer(0.3).timeout
		if not heroe._begin_bow_draw(): _fallar("No se puede tensar el arco."); return
		await create_timer(0.15).timeout
		if not await _etapa("tensar"): return
		heroe.set("_bow_draw_strength",1.0)
		if not heroe._release_bow_arrow(): _fallar("No sale la flecha local."); return
		await create_timer(0.8).timeout
		if not await _etapa("flecha"): return
		if not await _esperar(func(): return enemigos.arco.health==27): _fallar("El impacto de flecha no llega al invitado."); return
		heroe.equip_item(1)
		await create_timer(0.3).timeout
		var vida := int(historia.player_health)
		if not await _etapa("danar"): return
		if not await _esperar(func(): return int(historia.player_health)==vida-8): _fallar("El golpe no hiere al invitado correcto."); return
		await create_timer(0.8).timeout
		Input.action_press("block")
		heroe._raise_shield()
		await create_timer(0.2).timeout
		if not await _etapa("guardia"): return
		Input.action_release("block")
		heroe._lower_shield()
		await create_timer(0.1).timeout
		if not heroe.start_dodge_roll(1): _fallar("No empieza la esquiva."); return
		await create_timer(0.15).timeout
		if not await _etapa("esquiva"): return
		await create_timer(1.0).timeout
		root.get_node("InventoryManager").add_item("Sword_Golden",1)
		root.get_node("InventoryManager").equip_item("Sword_Golden",false)
		heroe.equip_item(1)
		await create_timer(0.3).timeout
		if not await _etapa("dorado"): return
		heroe.visual.rotation.y = 0
		heroe.start_attack()
		await _reposo()
		if not await _etapa("dano_dorado"): return
		if not await _etapa("preparar_muerte"): return
		heroe.visual.rotation.y = 0
		heroe.start_attack()
		await _reposo()
		if not await _etapa("muerte"): return
		if not await _esperar(func(): return root.get_node("InventoryManager").get_count("Coin_Skull")==monedas_antes+1): _fallar("El invitado no recibe la recompensa una vez."); return
		await create_timer(0.5).timeout
		if root.get_node("InventoryManager").get_count("Coin_Skull")!=monedas_antes+1 or not is_equal_approx(Engine.time_scale,1.0): _fallar("Se duplica botín o la cámara ralentiza la sesión."); return
		if not await _probar_recursos(): return
		if not await _probar_grutas(): return
		if not await _etapa("fin"): return
		print("COOP COMBAT CLIENT PASS: tajo, giro, coraza, pared, flecha, daño dirigido, guardia, esquiva, arma propia y recompensa.")
	sesion.leave_session()
	quit(0)

func crear_enemigo(id: String, punto: Vector3, jefe: bool = false) -> void:
	var enemigo: RPGEnemy = RPGBoss.new() if jefe else RPGEnemy.new()
	enemigo.enemy_id = "prueba_coop_"+id
	enemigo.display_name = id
	enemigo.max_health = 100 if jefe else 30
	enemigo.story_runtime = historia
	enemigo.position = punto
	if jefe: enemigo.set("demand",RPGBoss.Demand.CHARGE)
	historia.add_child(enemigo)
	enemigo.set_physics_process(false)
	if jefe: enemigo.set("sealed",false)
	enemigos[id] = enemigo

func _crear_pared() -> void:
	pared = StaticBody3D.new()
	pared.position = Vector3(0,800.9,-0.75)
	var forma := CollisionShape3D.new()
	forma.shape = BoxShape3D.new()
	forma.shape.size = Vector3(3,2.2,0.2)
	pared.add_child(forma)
	mundo.add_child(pared)

func _evaluar(nombre: String) -> Dictionary:
	var replica := mundo.get_node("NetworkPlayers").get_children()[0] as Player
	var correcto := true
	if nombre.begins_with("gruta_impacto/"):
		var id := nombre.trim_prefix("gruta_impacto/")
		for gruta in get_nodes_in_group("explorable_cave"):
			if String(gruta.spec.id) != id: continue
			var destino: Vector3 = gruta.to_global(Vector3(0, -17, -95))
			correcto = heroe.global_position.distance_to(destino) > 240 and replica.get_network_authoritative_position().distance_to(destino) < 0.2
			correcto = correcto and _suelo_de_gruta(gruta) and enemigos["gruta_" + id].health == 27
			for luz in gruta.lights: correcto = correcto and not luz.visible
			print("COOP CAVE SHOT ", id, " ", correcto, ": impacto de arco remoto, suelo presente y luces del anfitrión apagadas.")
			return {"ok": correcto}
		return {"ok": false}
	match nombre:
		"grutas_preparar":
			var destinos := []
			for gruta in get_nodes_in_group("explorable_cave"):
				var id := String(gruta.spec.id)
				var objetivo: Vector3 = gruta.to_global(Vector3(6, -18, -95))
				crear_enemigo("gruta_" + id, objetivo)
				destinos.append({"id": id, "jugador": gruta.to_global(Vector3(0, -17, -95)), "objetivo": objetivo, "camara": gruta.to_global(Vector3(0, -14.5, -89))})
			return {"ok": destinos.size() == 4, "destinos": destinos}
		"grutas_vacias":
			for gruta in get_nodes_in_group("explorable_cave"):
				correcto = correcto and not _suelo_de_gruta(gruta)
				for luz in gruta.lights: correcto = correcto and not luz.visible
			if correcto: print("COOP CAVE HOST PASS: cuatro disparos de invitado en grutas lejanas y desactivación al salir.")
		"recurso_elegir":
			var vegetacion := mundo.get_node("VegetationScatter")
			for indice in vegetacion.get("_harvest_tree_ids").size():
				var id: String = vegetacion.get("_harvest_tree_ids")[indice]
				var punto: Vector3 = vegetacion.get("_harvest_tree_positions")[indice]
				if Vector2(punto.x,punto.z).distance_squared_to(Vector2(0,190))>200*200: continue
				if not vegetacion.call("_resource_unavailable",id):
					arbol_red = id
					return {"ok":true,"id":id,"posicion":vegetacion.get("_harvest_tree_positions")[indice]}
			return {"ok":false}
		"recurso_talado":
			var vegetacion := mundo.get_node("VegetationScatter")
			correcto = vegetacion.get("_destroyed_resource_ids").has(arbol_red) and vegetacion.get("_harvest_stumps").has(arbol_red)
		"recurso_restaurar":
			var vegetacion := mundo.get_node("VegetationScatter")
			var estado: Dictionary = vegetacion.get_save_state()
			estado.destroyed_resource_ids.erase(arbol_red)
			vegetacion.apply_save_state(estado)
			sesion.broadcast_world_state_now()
			correcto = not vegetacion.get("_destroyed_resource_ids").has(arbol_red) and not vegetacion.get("_harvest_stumps").has(arbol_red)
			if correcto: print("COOP RESOURCE HOST PASS: tala validada y restauración autoritativa.")
		"anfitrion": correcto = heroe.start_attack()
		"tajo", "invalidos": correcto = enemigos.frente.health==27 and enemigos.espalda.health==30 and enemigos.arco.health==30
		"giro": correcto = enemigos.frente.health==21 and enemigos.espalda.health==24 and int(enemigos.jefe.get("_ward"))==1
		"pared_on": _crear_pared()
		"pared_golpe": correcto = enemigos.frente.health==21
		"pared_off": pared.queue_free()
		"tensar": correcto = replica.is_drawing_bow and replica.get("_nocked_arrow")!=null
		"flecha": correcto = enemigos.arco.health==27
		"danar":
			enemigos.frente._pick_target()
			correcto = enemigos.frente.get("_target")==replica
			enemigos.frente._hit_player()
			correcto = correcto and historia.player_health==100
		"guardia":
			enemigos.jefe.set("_target",replica)
			enemigos.jefe.set("demand",RPGBoss.Demand.GUARD)
			var escudo: Node3D = replica.get("_shield_mesh")
			correcto = replica.is_guarding and enemigos.jefe._player_answered() and escudo!=null and escudo.get_parent()==replica.get("_shield_grip")
		"esquiva": correcto = replica.is_rolling
		"dorado": correcto = replica.equipped_item_id=="Sword_Golden" and replica.equipped_category=="sword"
		"dano_dorado": correcto = enemigos.frente.health==11
		"preparar_muerte": enemigos.frente.health = 3
		"muerte": correcto = enemigos.frente.dead and root.get_node("InventoryManager").get_count("Coin_Skull")==monedas_antes+1 and is_equal_approx(Engine.time_scale,1.0)
		"fin":
			correcto = _probar_terreno_lejano(replica)
			terminar_host = correcto
	var salud_frente: int = enemigos.frente.health if is_instance_valid(enemigos.frente) else 0
	var datos := {"ok":correcto,"frente":salud_frente,"espalda":enemigos.espalda.health,"arco":enemigos.arco.health,"ward":enemigos.jefe.get("_ward"),"arma":replica.equipped_item_id}
	print("COOP STAGE ",nombre," ",JSON.stringify(datos))
	return datos


func _probar_recursos() -> bool:
	mundo.get_node("MotorPrueba").set_physics_process(false)
	if not await _etapa("recurso_elegir"): return false
	var datos: Dictionary = respuestas.recurso_elegir
	var vegetacion := mundo.get_node("VegetationScatter")
	var id := String(datos.id)
	var indice := int(vegetacion.get("_harvest_tree_index_by_id").get(id,-1))
	if indice<0: _fallar("El invitado no identifica el árbol del anfitrión."); return false
	heroe.global_position = (datos.posicion as Vector3)+Vector3(0,0,2.4)
	heroe.equip_item(2)
	if "--capture-resources" in OS.get_cmdline_user_args():
		root.get_node("GameSettings").set_resolution(Vector2i(1600,900),false)
		root.always_on_top = true
		mundo.get_node("HUD").visible = false
		var camara := Camera3D.new()
		mundo.add_child(camara)
		camara.fov = 62
		camara.current = true
		camara.global_position = (datos.posicion as Vector3)+Vector3(8,5,11)
		camara.look_at((datos.posicion as Vector3)+Vector3(0,5,0))
		mundo.sincronizar_camara_terreno()
		for fotograma in 50: await process_frame
		await _capturar_recurso("antes")
	await create_timer(0.5).timeout
	var salud := VegetationScatter.TREE_HARVEST_HEALTH
	for golpe in salud:
		heroe.attacks_performed += 1
		var recibidos := estados_mundo
		if not vegetacion.try_hit_nearest_tree("axe","Axe_small",heroe.global_position,Vector3.FORWARD,3.0,heroe): _fallar("El hacha no alcanza el árbol en la sesión real."); return false
		await create_timer(0.5).timeout
		if golpe==salud-1: await _capturar_recurso("caida")
		if not await _esperar(func(): return estados_mundo-recibidos>=2): _fallar("La prueba de tala no cruza dos instantáneas periódicas."); return false
		if golpe<salud-1 and int(vegetacion.get("_harvest_tree_health").get(indice,salud))!=salud-golpe-1: _fallar("Los estados periódicos borran el daño parcial de la tala."); return false
		print("COOP RESOURCE SAMPLE: golpe %d, %d estados recibidos."%[golpe+1,estados_mundo-recibidos])
	await create_timer(0.5).timeout
	if not vegetacion.get("_destroyed_resource_ids").has(id) or not vegetacion.get("_harvest_stumps").has(id): _fallar("La confirmación interrumpe la caída y no aparece el tocón."); return false
	if not await _etapa("recurso_talado"): return false
	await _capturar_recurso("tocon")
	if not await _etapa("recurso_restaurar"): return false
	if not await _esperar(func(): return not vegetacion.get("_destroyed_resource_ids").has(id) and not vegetacion.get("_harvest_stumps").has(id)): _fallar("El invitado no restaura el árbol y su tocón."); return false
	await _capturar_recurso("restaurado")
	print("COOP RESOURCE CLIENT PASS: %d golpes con estados intermedios a 5 Hz, caída completa, tocón y restauración compartida."%salud)
	return true


func _capturar_recurso(etapa: String) -> void:
	if "--capture-resources" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var carpeta := "res://generated/reviews/2026-11-09/recursos-red/imagenes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	root.get_texture().get_image().save_png(carpeta.path_join(etapa+".png"))

func _probar_grutas() -> bool:
	if not await _etapa("grutas_preparar"): return false
	var destinos: Array = respuestas.grutas_preparar.destinos
	for destino in destinos: crear_enemigo("gruta_" + String(destino.id), destino.objetivo)
	var camara := Camera3D.new()
	mundo.add_child(camara)
	camara.current = true
	heroe.equip_item(3)
	for destino in destinos:
		heroe.global_position = destino.jugador
		heroe.velocity = Vector3.ZERO
		camara.global_position = destino.camara
		camara.look_at((destino.objetivo as Vector3) + Vector3.UP * 0.9)
		mundo.sincronizar_camara_terreno()
		await create_timer(0.65).timeout
		if not heroe._begin_bow_draw(): _fallar("No se puede tensar dentro de la gruta."); return false
		await create_timer(0.2).timeout
		heroe.set("_bow_draw_strength", 1.0)
		if not heroe._release_bow_arrow(): _fallar("No se puede disparar dentro de la gruta."); return false
		var enemigo: Node = enemigos["gruta_" + String(destino.id)]
		if not await _esperar(func(): return enemigo.health == 27): _fallar("La flecha cooperativa no alcanza el objetivo dentro de " + String(destino.id)); return false
		if not await _etapa("gruta_impacto/" + String(destino.id)): return false
	for gruta in get_nodes_in_group("explorable_cave"):
		if _suelo_de_gruta(gruta) and heroe.global_position.distance_to(gruta.to_global(Vector3(0, -17, -95))) > 240:
			_fallar("Se mantiene encendida la física de una gruta desocupada."); return false
	heroe.global_position = Vector3(0, 800, 0)
	camara.global_position = Vector3(0, 805, 5)
	await create_timer(0.65).timeout
	if not await _etapa("grutas_vacias"): return false
	print("COOP CAVE CLIENT PASS: arco real por ENet, cuatro interiores y salida sin mantener grutas lejanas activas.")
	return true

func _suelo_de_gruta(gruta: StaticBody3D) -> bool:
	var rayo := PhysicsRayQueryParameters3D.create(gruta.to_global(Vector3(0, -13, -95)), gruta.to_global(Vector3(0, -24, -95)), 1)
	return mundo.get_world_3d().direct_space_state.intersect_ray(rayo).get("collider") == gruta

func _paquete() -> Dictionary:
	return {"tipo":"tajo","secuencia":1,"posicion":heroe.global_position,"velocidad":Vector3.ZERO,
		"yaw":0.0,"suelo":true,"hora":float(Time.get_ticks_usec())/1000000.0,"ranura":1,"objeto":"Sword"}

func _probar_terreno_lejano(replica: Player) -> bool:
	var terreno := TerrenoPrueba.new()
	terreno.data = DatosTerrenoPrueba.new()
	mundo.add_child(terreno)
	for hueco in [false,true]:
		terreno.data.set("hueco",hueco)
		var flecha := AdventureArrow.new()
		mundo.add_child(flecha)
		flecha.global_position = Vector3(10,801,10)
		flecha.set("_terreno_red",terreno)
		flecha.launch(Vector3.RIGHT,48,replica)
		flecha._physics_process(0.1)
		if flecha.is_stuck()==hueco: return false
		flecha.queue_free()
	terreno.queue_free()
	return true

func _etapa(nombre: String) -> bool:
	control.pedir.rpc_id(1,nombre)
	if not await _esperar(func(): return respuestas.has(nombre)): _fallar("No llega la etapa "+nombre); return false
	if not bool(respuestas[nombre].get("ok",false)): _fallar("Etapa "+nombre+": "+JSON.stringify(respuestas[nombre])); return false
	return true

func _reposo() -> void:
	await _esperar(func(): return not heroe.is_attacking and float(heroe.get("_attack_cooldown"))<=0.0)
	await create_timer(0.2).timeout

func _esperar(condicion: Callable) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio<8000:
		if condicion.call(): return true
		await process_frame
	return false

func _fallar(mensaje: String) -> void:
	Input.action_release("block")
	push_error(mensaje)
	if sesion!=null: sesion.leave_session()
	quit(1)
