extends SceneTree

## La física debe atender al invitado aunque la vista del anfitrión esté lejos.
var mundo: Node3D
var camara: Camera3D
var jugador: Player
var invitado: Player
var lejos := Vector3(0, 800, 0)

class DatosCota:
	extends RefCounted
	var altura := 0.0
	func get_height(_punto: Vector3) -> float: return altura
	func get_control_hole(_punto: Vector3) -> bool: return false

class TerrenoCota:
	extends Node3D
	var data := DatosCota.new()

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]:
		root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	jugador = mundo.get_node("Player")
	jugador.set_physics_process(false)
	mundo.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	camara = Camera3D.new()
	mundo.add_child(camara)
	camara.current = true
	var grutas := get_nodes_in_group("explorable_cave")
	if grutas.size() != 4: _fallar("La prueba necesita las cuatro grutas reales."); return
	for gruta in grutas:
		gruta.set_process(false)
		jugador.global_position = lejos
		camara.global_position = lejos
		if not await _estado(gruta, false, false, "vacía"): return
		invitado = load("res://scenes/player.tscn").instantiate()
		invitado.configure_network_replica("Invitado de gruta", 0)
		invitado.set_meta("network_peer_id", 9001)
		mundo.get_node("NetworkPlayers").add_child(invitado)
		invitado.set_physics_process(false)
		invitado.set_process(false)
		var dentro: Vector3 = gruta.to_global(Vector3(0, -17, -95))
		invitado.global_position = dentro
		if not await _estado(gruta, false, false, "réplica sin primera muestra"): return
		_muestra(dentro)
		# El búfer visual puede ir detrás de la posición que usa el combate.
		invitado.global_position = lejos
		if not await _estado(gruta, true, false, "invitado autoritativo dentro, vista fuera"): return
		if not await _pisar_suelo(gruta): return
		if not _probar_flechas(gruta): return
		_muestra(lejos)
		invitado.global_position = dentro
		if not await _estado(gruta, true, false, "invitado visible dentro, muestra fuera"): return
		invitado.global_position = lejos
		if not await _estado(gruta, false, false, "invitado fuera"): return
		camara.global_position = dentro
		if not await _estado(gruta, false, true, "sólo cámara dentro"): return
		jugador.global_position = dentro
		camara.global_position = lejos
		if not await _estado(gruta, true, true, "héroe local dentro"): return
		jugador.global_position = lejos
		_muestra(dentro)
		if not await _estado(gruta, true, false, "último invitado dentro"): return
		invitado.get_parent().remove_child(invitado)
		invitado.queue_free()
		if not await _estado(gruta, false, false, "último invitado desconectado"): return
		print("CAVE ACTIVITY CHECK ", gruta.name, ": física nativa, cápsula, dos posiciones de red, luces y desconexión.")
	print("CAVE ACTIVITY TEST OK: cuatro grutas; cápsulas, flechas locales/remotas equivalentes, roca exterior y seis luces sólo por vista local.")
	quit(0)

func _muestra(posicion: Vector3) -> void:
	invitado.apply_network_state(posicion, 0.0, Vector3.ZERO, 0, float(Time.get_ticks_usec()) / 1000000.0, true)

func _estado(gruta: StaticBody3D, solida: bool, iluminada: bool, etapa: String) -> bool:
	gruta._process(1.0)
	for i in 2: await physics_frame
	var rayo := PhysicsRayQueryParameters3D.create(gruta.to_global(Vector3(0, -13, -95)), gruta.to_global(Vector3(0, -24, -95)), 1)
	var hit := mundo.get_world_3d().direct_space_state.intersect_ray(rayo)
	if (hit.get("collider") == gruta) != solida:
		_fallar("%s / %s: el suelo nativo no coincide con los participantes." % [gruta.name, etapa]); return false
	var luces: Array = gruta.get("lights")
	if luces.size() != 6: _fallar("Deben existir dos antorchas y cuatro luces interiores."); return false
	for luz in luces:
		if luz.visible != iluminada:
			_fallar("%s / %s: las luces no siguen la vista local." % [gruta.name, etapa]); return false
	return true

func _pisar_suelo(gruta: StaticBody3D) -> bool:
	var cuerpo := CharacterBody3D.new()
	cuerpo.collision_layer = 2
	cuerpo.collision_mask = 1
	var colision := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.height = 1.8
	forma.radius = 0.4
	colision.shape = forma
	colision.position.y = 0.9
	cuerpo.add_child(colision)
	mundo.add_child(cuerpo)
	cuerpo.global_position = gruta.to_global(Vector3(0, -17, -95))
	for i in 45:
		await physics_frame
		cuerpo.velocity = Vector3.DOWN * 6
		cuerpo.move_and_slide()
	var bien := cuerpo.is_on_floor() and absf(gruta.to_local(cuerpo.global_position).y + 18) < 0.6
	cuerpo.queue_free()
	if not bien: _fallar("La cápsula cae por el suelo del invitado en " + gruta.name)
	return bien

func _probar_flechas(gruta: StaticBody3D) -> bool:
	var origen := gruta.to_global(Vector3(0, -16, -95))
	var direccion := gruta.global_basis * Vector3.RIGHT
	var local := _flecha(origen, direccion, jugador)
	var remota := _flecha(origen, direccion, invitado)
	for paso in 15:
		local._physics_process(0.1)
		remota._physics_process(0.1)
		if local.is_stuck() != remota.is_stuck() or local.global_position.distance_to(remota.global_position) > 0.015:
			_fallar("La flecha remota se clava en el terreno de encima o atraviesa roca en " + gruta.name); return false
		if paso == 0 and (local.is_stuck() or local.global_position.distance_to(origen) < 2.9):
			_fallar("El control local no recorre el aire de la cámara."); return false
		if local.is_stuck(): break
	if not local.is_stuck(): _fallar("Las flechas no chocan contra la gruta real."); return false
	local.queue_free()
	remota.queue_free()
	var rayo := PhysicsRayQueryParameters3D.create(origen, origen + Vector3.UP * 30, 1)
	var techo := mundo.get_world_3d().direct_space_state.intersect_ray(rayo)
	if techo.get("collider") != gruta: _fallar("Falta la bóveda nativa para el control exterior."); return false
	var sobre_techo: Vector3 = techo.position + Vector3.UP * 0.6
	# La altura controlada exige roca sobre cada bóveda, incluso donde la ladera
	# real cae por debajo: así el control no desaparece por la topografía del bioma.
	var terreno_cota := TerrenoCota.new()
	terreno_cota.data.altura = sobre_techo.y + 6
	mundo.add_child(terreno_cota)
	var sobre_boveda := _flecha(sobre_techo, direccion, invitado)
	sobre_boveda.set("_terreno_red", terreno_cota)
	sobre_boveda._physics_process(0.1)
	if not sobre_boveda.is_stuck() or sobre_boveda.global_position.distance_to(sobre_techo) > 0.2:
		_fallar("El disparo ignora la roca situada sobre la bóveda en " + gruta.name); return false
	sobre_boveda.queue_free()
	terreno_cota.queue_free()
	var limites: AABB = gruta.get_node("Hollow").get_aabb()
	var exterior := gruta.to_global(Vector3(limites.end.x + 10, 0, -95))
	exterior.y = mundo.get_node("Terrain3D").data.get_height(exterior) - 2
	var enterrada := _flecha(exterior, Vector3(0.01, -1, 0).normalized(), invitado)
	enterrada._physics_process(0.1)
	if not enterrada.is_stuck() or enterrada.global_position.distance_to(exterior) > 0.2:
		_fallar("El disparo atraviesa terreno macizo fuera del hueco en " + gruta.name); return false
	enterrada.queue_free()
	return true

func _flecha(origen: Vector3, direccion: Vector3, tirador: Player) -> AdventureArrow:
	var flecha := AdventureArrow.new()
	mundo.add_child(flecha)
	flecha.global_position = origen
	flecha.launch(direccion, 30, tirador)
	flecha.set_physics_process(false)
	return flecha

func _fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
