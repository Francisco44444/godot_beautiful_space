extends SceneTree

func _init() -> void: call_deferred("_comprobar")
func _comprobar() -> void:
	root.get_node("SaveGameManager").set_process(false)
	var mundo := Node3D.new()
	root.add_child(mundo)
	var acceso := RPGCaveGate.new()
	acceso.gate_id = "prueba_puerta"
	mundo.add_child(acceso)
	var cuenta := [0]
	acceso.gate_opened.connect(func(_id, _llave): cuenta[0] += 1)
	for i in 2: await physics_frame
	if not _bloquea(acceso): _fallar("El control cerrado no tiene colisión."); return
	acceso.apply_network_state({"id":"otra", "opened":true})
	acceso.apply_network_state({"id":acceso.gate_id, "opened":"true"})
	if acceso.opened: _fallar("Una identidad o tipo incorrectos abren la puerta."); return
	acceso.apply_network_state({"id":acceso.gate_id, "opened":true})
	var tween: Tween = acceso.get("_apertura")
	await create_timer(0.15).timeout
	for i in 20: acceso.apply_network_state({"id":acceso.gate_id, "opened":true})
	if cuenta[0] != 1 or acceso.get("_apertura") != tween: _fallar("Un estado repetido reinicia la apertura."); return
	acceso.apply_network_state({"id":acceso.gate_id, "opened":false})
	await create_timer(1.25).timeout
	if acceso.opened or not _bloquea(acceso) or not is_equal_approx(acceso.get_node("SealedDoor").position.y, 2) or not is_zero_approx(acceso.get_node("SealedDoor").rotation.y):
		_fallar("La restauración deja una colisión fantasma o un tween antiguo."); return
	acceso.open_gate(null, true)
	await create_timer(0.1).timeout
	acceso.apply_save_state({"id":acceso.gate_id, "opened":true})
	await physics_frame
	if _bloquea(acceso) or not is_equal_approx(acceso.get_node("SealedDoor").position.y, 4.8): _fallar("La carga de una puerta abierta conserva una animación incompleta."); return
	var gestor = preload("res://scripts/puertas_cooperativas.gd").new()
	gestor.configurar(mundo, null, null)
	mundo.add_child(gestor)
	var valido := {"position":[0.0, 1.0, 0.0], "yaw":0.0, "inventory":{"items":{"Key1":1}}}
	if not gestor.paquete_valido(acceso.gate_id, valido): _fallar("Se rechaza una intención de apertura bien formada."); return
	for defecto in ["id", "posicion", "nan", "yaw", "inventario", "objetos", "tamano"]:
		var estado := valido.duplicate(true)
		var id := acceso.gate_id
		match defecto:
			"id": id = "\npuerta"
			"posicion": estado.position = [{}, 0, 0]
			"nan": estado.position = [NAN, 0, 0]
			"yaw": estado.yaw = []
			"inventario": estado.inventory = []
			"objetos": estado.inventory.items = []
			"tamano": estado.extra = "x".repeat(70000)
		if gestor.paquete_valido(id, estado): _fallar("Se acepta el paquete inválido " + defecto); return
	var revision: int = gestor.get_state().revision
	gestor.partida_cargada()
	if gestor.get_state().revision == revision: _fallar("La carga no invalida las intenciones antiguas."); return
	var sesion := root.get_node("NetworkSession")
	sesion.session_mode = sesion.SessionMode.CLIENT
	gestor.aplicar_estado_red({"revision":100, "doors":[{"id":acceso.gate_id, "opened":true}]})
	gestor.aplicar_estado_red({"revision":100, "doors":[{"id":acceso.gate_id, "opened":false}]})
	if not acceso.opened: _fallar("Una instantánea retrasada contradice la confirmación fiable."); return
	gestor.aplicar_estado_red({"revision":99, "doors":[{"id":acceso.gate_id, "opened":false}]})
	if int(gestor.get("_revision_host")) != 100 or not acceso.opened: _fallar("Se acepta el estado de una partida anterior."); return
	gestor.aplicar_estado_red({"revision":101, "doors":[{"id":acceso.gate_id, "opened":false}]})
	await physics_frame
	if acceso.opened or not _bloquea(acceso): _fallar("La nueva revisión no permite restaurar una puerta cerrada."); return
	sesion.session_mode = sesion.SessionMode.OFFLINE
	print("GATE STATE TEST OK: identidad, tipos, colisión real, animación idempotente, restauración, orden entre canales y paquetes acotados.")
	quit(0)

func _bloquea(puerta: RPGCaveGate) -> bool:
	var espacio := puerta.get_world_3d().direct_space_state
	return espacio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 2), Vector3(0, 1.5, -2), 1)).get("collider") == puerta

func _fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
