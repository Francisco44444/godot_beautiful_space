extends SceneTree
func _init() -> void: call_deferred("_probar")
func exigir(valor: bool, texto: String) -> bool:
	if valor: return true
	push_error(texto); quit(1); return false
func _probar() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for n in ["InventoryManager","ExplorationManager"]: root.get_node(n).set("autosave_enabled",false)
	var mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo); current_scene = mundo
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	var historia = mundo.get_node("RPGStoryRuntime")
	if not exigir(mundo.modo_aventura and historia.aventura_pacifica != null,"Aventura no es el modo predeterminado"): return
	if not exigir(get_nodes_in_group("rpg_enemy").is_empty() and get_nodes_in_group("rpg_boss").is_empty(),"Quedan enemigos en Aventura"): return
	var d = historia.aventura_pacifica
	var heroe = mundo.player
	heroe.set_physics_process(false)
	for q in historia.sidequests.encargos():
		if not exigir(q.kind != 0,"Queda una cacería"): return
	var inicio = historia.campaign.progress()
	var piedra = d.objetos["acto:0:2"]
	heroe.global_position = piedra.global_position
	d.interactuar("acto:0:2",heroe)
	if not exigir(historia.campaign.progress() == inicio,"Un orden equivocado completa un acto"): return
	for i in 5:
		for j in [[0,1,2],[0,2],[0,0,1,2,2,2],[0,2],[2,0,1]][i]:
			var id := "acto:%d:%d" % [i,j]
			heroe.global_position = d.objetos[id].global_position
			d.interactuar(id,heroe)
			paused = false
	if not exigir(historia.campaign.progress().finished,"La campaña pacífica no se puede terminar"): return
	var inventario = root.get_node("InventoryManager")
	for i in historia.sidequests.encargos().size():
		var q = historia.sidequests.encargos()[i]
		historia.sidequests.take(q)
		var id := "encargo:%d" % i
		heroe.global_position = d.objetos[id].global_position
		d.interactuar(id,heroe)
		if not exigir(historia.sidequests.try_deliver(q),"No se puede entregar el encargo "+q.id): return
	for i in 4:
		var id := "llave:%d" % i
		heroe.global_position = d.objetos[id].global_position; d.interactuar(id,heroe)
		if not exigir(inventario.has_item(historia.GATE_SPECS[i].key),"Falta una llave sin combate"): return
	heroe.global_position = mundo.terrain.to_global(Vector3(-247,0,40))
	inventario.add_item("WoodLog",6,false)
	if not exigir(d.construir_refugio(),"No se construye el refugio con seis troncos"): return
	var retos = d.get_node("RetosSenderos")
	for i in 3:
		var diana = retos.dianas[str(i)]
		heroe.global_position = diana.global_position + Vector3(0,0,10)
		var flecha = load("res://scripts/adventure_arrow.gd").new()
		mundo.add_child(flecha)
		flecha.global_position = diana.global_position + Vector3(0,0.4,9)
		flecha.launch(Vector3.FORWARD,30,heroe,1.0)
		await create_timer(0.5).timeout
		if not exigir(d.hechos.has("diana:%d" % i),"La flecha real no activa la diana"): return
	heroe.global_position = retos.inicio_lava + Vector3(8,-1.3,0)
	for i in 6: await physics_frame
	if not exigir(heroe.global_position.distance_to(retos.inicio_lava)<2,"La lava no devuelve al inicio"): return
	# Recorrer los nueve saltos con la cápsula real y la gravedad del héroe.
	# Sólo se coloca en el inicio; cada aterrizaje depende de la colisión.
	heroe.global_position = retos.inicio_lava
	heroe.velocity = Vector3.ZERO
	for cuadro in 20:
		heroe.velocity.y -= 9.8/60.0
		heroe.move_and_slide()
		await physics_frame
	for salto in range(1,10):
		var destino: Vector3 = retos.inicio_lava + Vector3(salto*3,0,0.65 if salto%2 else -0.65)
		heroe.velocity.y = heroe.jump_velocity
		var aterrizado := false
		for cuadro in 90:
			var direccion: Vector3 = destino-heroe.global_position; direccion.y = 0
			var velocidad: float = minf(heroe.walk_speed,direccion.length()*60)
			heroe.velocity.x = direccion.normalized().x*velocidad
			heroe.velocity.z = direccion.normalized().z*velocidad
			heroe._apply_gravity(1.0/60.0)
			heroe.move_and_slide()
			await physics_frame
			if cuadro>8 and heroe.is_on_floor():
				aterrizado = Vector2(heroe.global_position.x-destino.x,heroe.global_position.z-destino.z).length()<0.9
				break
		if not exigir(aterrizado,"No es transitable el salto de lava %d" % salto): return
	var estado: Dictionary = historia.get_save_state()
	mundo.cambiar_modo_aventura(false)
	if not exigir(historia.generated_enemy_count > 0,"La opción Combate ha desaparecido"): return
	mundo.cambiar_modo_aventura(true)
	if not exigir(historia.campaign.progress().finished and historia.aventura_pacifica.refugios.size()==1,"Cambiar de modo pierde progreso"): return
	historia.apply_save_state(estado)
	if not exigir(mundo.modo_aventura and historia.campaign.progress().finished,"Cargar pierde el modo o campaña"): return
	var compartido: Dictionary = mundo.get_shared_world_save_state()
	var personal: Dictionary = mundo.get_local_player_save_state()
	personal.return_position = [-240,30,42]
	mundo.apply_shared_world_save_state(compartido)
	mundo.apply_local_player_save_state(personal)
	for cuadro in 4: await process_frame
	if not exigir(historia.aventura_pacifica.retorno==personal.return_position,"La carga compartida pisa el punto de descanso personal"): return
	var sesion := root.get_node("NetworkSession")
	var instantanea: Dictionary = sesion._local_save_snapshot(heroe)
	for invalido in [[NAN,0,0],[{},0,0],[0,0],[7000,0,0]]:
		instantanea.return_position = invalido
		if not exigir(not sesion._is_valid_save_snapshot(instantanea),"Se acepta un regreso inválido"): return
	historia.apply_save_state({})
	if not exigir(not mundo.modo_aventura and historia.generated_enemy_count>0,"Una partida antigua cambia involuntariamente de modo"): return
	print("PEACEFUL ADVENTURE OK: cinco actos, 18 encargos, cuatro llaves, refugio, flechas reales, lava y cambio de modo sin perder progreso.")
	quit(0)
