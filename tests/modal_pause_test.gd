extends SceneTree

var mundo: Node3D
var hud: Node
var sesion: Node
var jugador: Player
var caballo: Horse

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	root.get_node("InventoryManager").reset_inventory_for_tests(false)
	if DisplayServer.get_name()!="headless":
		root.get_node("GameSettings").set_resolution(Vector2i(1600,900),false)
		root.always_on_top = true
		root.show()
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	hud = mundo.get_node("HUD")
	jugador = mundo.get_node("Player")
	caballo = mundo.get_node("Horse")
	mundo.get_node("RPGStoryRuntime").set("_damage_cooldown",1000000000.0)
	sesion = root.get_node("NetworkSession")
	# Aquí se prueban las reglas de interfaz; los procesos ENet se comprueban
	# aparte. El singleton no envía tráfico con estos modos simulados.
	sesion.set_physics_process(false)
	for modo in [sesion.SessionMode.OFFLINE,sesion.SessionMode.HOST,sesion.SessionMode.CLIENT]:
		sesion.session_mode = modo
		for ventana in ["dialogo","inventario","diario","ajustes","vestibulo","pausa"]:
			_abrir(ventana,true)
			if paused != (modo==sesion.SessionMode.OFFLINE):
				_fallar("La ventana %s detiene la expedición cooperativa o pierde la pausa individual." % ventana); return
			if not jugador.entrada_interfaz_bloqueada or not caballo.entrada_interfaz_bloqueada:
				_fallar("La ventana %s deja libres los controles locales." % ventana); return
			if hud.mini_map.visible: _fallar("El minimapa se superpone a una ventana abierta."); return
			if ventana=="pausa" and hud.pause_menu._subtitulo.text != ("MENÚ DE PAUSA" if modo==sesion.SessionMode.OFFLINE else "MENÚ DE EXPEDICIÓN"):
				_fallar("El menú no distingue pausa individual y expedición activa."); return
			_abrir(ventana,false)
			if paused: _fallar("Cerrar %s deja la partida pausada." % ventana); return
			if jugador.entrada_interfaz_bloqueada or caballo.entrada_interfaz_bloqueada:
				_fallar("Cerrar %s no devuelve los controles locales." % ventana); return
	for modo in [sesion.SessionMode.OFFLINE,sesion.SessionMode.HOST]:
		sesion.session_mode = modo
		_abrir("ajustes",true)
		_abrir("dialogo",true)
		_abrir("dialogo",false)
		if not jugador.entrada_interfaz_bloqueada or paused != (modo==sesion.SessionMode.OFFLINE):
			_fallar("Cerrar una ventana libera otra que sigue abierta."); return
		_abrir("ajustes",false)
	sesion.session_mode = sesion.SessionMode.OFFLINE
	_abrir("inventario",true)
	sesion.session_mode = sesion.SessionMode.HOST
	sesion.session_started.emit("host")
	if paused or not jugador.entrada_interfaz_bloqueada: _fallar("Crear sesión con una ventana abierta no reanuda la expedición."); return
	sesion.session_mode = sesion.SessionMode.OFFLINE
	sesion.session_ended.emit()
	if not paused or not jugador.entrada_interfaz_bloqueada: _fallar("Perder la conexión pierde la pausa de la ventana individual."); return
	_abrir("inventario",false)
	sesion.session_mode = sesion.SessionMode.HOST
	if not await _comprobar_entrada(): return
	sesion.session_mode = sesion.SessionMode.OFFLINE
	sesion.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("MODAL PAUSE TEST OK: seis ventanas, tres modos, superposición, cambios de sesión, controles, gravedad, montura, cargas y clic de cierre.")
	quit(0)

func _comprobar_entrada() -> bool:
	jugador.global_position.y += 8.0
	jugador.velocity = Vector3.ZERO
	_abrir("inventario",true)
	var inicial := jugador.global_position
	for accion in ["move_forward","attack","jump","block"]: Input.action_press(accion)
	await create_timer(0.35).timeout
	if Vector2(jugador.global_position.x-inicial.x,jugador.global_position.z-inicial.z).length()>0.08 or jugador.is_attacking or jugador.is_drawing_bow or jugador.is_guarding or jugador.is_rolling:
		_fallar("Las teclas o clics del menú mueven o arman al héroe."); return false
	if jugador.global_position.y>=inicial.y-0.2: _fallar("El bloqueo de interfaz también congela la gravedad."); return false
	_liberar_acciones()
	var equipo := jugador.equipped_slot
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_2
	tecla.pressed = true
	jugador._unhandled_input(tecla)
	if jugador.equipped_slot!=equipo: _fallar("Un atajo equipa armas detrás de la interfaz."); return false
	inicial = jugador.global_position
	tecla.physical_keycode = KEY_6
	mundo._unhandled_input(tecla)
	if jugador.global_position.distance_to(inicial)>0.01: _fallar("Un atajo de viaje atraviesa la interfaz."); return false
	if caballo.is_coming_when_called(): _fallar("El control ya había llamado a la montura."); return false
	tecla.physical_keycode = KEY_H
	hud._unhandled_input(tecla)
	if caballo.is_coming_when_called(): _fallar("El atajo H llama a la montura desde el inventario."); return false
	Input.action_press("move_forward")
	Input.action_press("sprint")
	caballo.velocity = Vector3.ZERO
	caballo._apply_riding_input(1.0)
	if Vector2(caballo.velocity.x,caballo.velocity.z).length()>0.01 or caballo.sprint_requested:
		_fallar("El menú sigue leyendo el movimiento de la montura."); return false
	_liberar_acciones()
	if DisplayServer.get_name()!="headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: _fallar("El control gráfico no capturó el ratón."); return false
		var camara := mundo.get_node("CameraRig") as ThirdPersonCamera
		var giro := camara.yaw
		var raton := InputEventMouseMotion.new()
		raton.relative = Vector2(400,100)
		camara._unhandled_input(raton)
		if camara.yaw!=giro: _fallar("La cámara gira detrás de la interfaz."); return false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_abrir("inventario",false)
	await create_timer(0.8).timeout
	# Preparar cada gesto sin red: la replicación de su cancelación se comprueba
	# con los dos procesos ENet, sin simular un peer que no existe aquí.
	sesion.session_mode = sesion.SessionMode.OFFLINE
	jugador.equip_item(1)
	jugador.draw_weapon()
	await create_timer(0.8).timeout
	if not jugador.start_charge(): _fallar("El control no puede cargar la espada."); return false
	_abrir("inventario",true)
	if jugador.is_charging_attack() or jugador._pending_draw_attack: _fallar("Abrir la interfaz conserva una carga o un tajo pendiente."); return false
	if jugador.start_charge(): _fallar("La interfaz permite iniciar una carga nueva."); return false
	_abrir("inventario",false)
	jugador.equip_item(3)
	await create_timer(0.8).timeout
	var flechas := jugador.get_arrow_count()
	if not jugador._begin_bow_draw(): _fallar("El control no puede tensar el arco."); return false
	_abrir("inventario",true)
	if jugador.is_drawing_bow or jugador.get_arrow_count()!=flechas: _fallar("Abrir la interfaz dispara o conserva el arco tensado."); return false
	if jugador._begin_bow_draw(): _fallar("La interfaz permite volver a tensar el arco."); return false
	_abrir("inventario",false)
	await create_timer(0.8).timeout
	sesion.session_mode = sesion.SessionMode.HOST
	_abrir("inventario",true)
	Input.action_press("attack")
	_abrir("inventario",false)
	await physics_frame
	await physics_frame
	_liberar_acciones()
	if jugador.is_drawing_bow or jugador.is_attacking or jugador.get_arrow_count()!=flechas:
		_fallar("El clic de cerrar la ventana se convierte en un ataque."); return false
	return true

func _liberar_acciones() -> void:
	for accion in ["move_forward","attack","jump","block","sprint"]: Input.action_release(accion)

func _abrir(ventana: String, abrir: bool) -> void:
	match ventana:
		"dialogo": hud._set_story_dialogue_open(abrir)
		"inventario": hud._set_inventory_open(abrir)
		"diario": hud._set_exploration_journal_open(abrir)
		"ajustes": hud._set_settings_open(abrir)
		"vestibulo": hud._set_lobby_open(abrir)
		"pausa": hud.pause_menu.set_open(abrir)

func _fallar(mensaje: String) -> void:
	_liberar_acciones()
	if sesion!=null: sesion.session_mode = sesion.SessionMode.OFFLINE
	paused = false
	push_error(mensaje)
	quit(1)
