extends SceneTree

## Entrada real: respuesta al pulsar, tres tajos anticipados y carga deliberada.
var jugador: Player
var tajos: Array[String] = []
var cargas := 0

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("InventoryManager").reset_inventory_for_tests(false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	jugador = mundo.get_node("Player")
	mundo.get_node("RPGStoryRuntime").set("_damage_cooldown", 1000000000.0)
	jugador.attack_started.connect(func(_numero: int): tajos.append(jugador.get_library_animation()))
	jugador.charge_changed.connect(func(_fuerza: float, _lista: bool):
		if jugador.is_charging_attack(): cargas += 1)
	if not _exigir(jugador.equip_item(1), "No se pudo preparar la espada."): return
	await create_timer(0.8).timeout
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	if not _exigir(jugador.attack_phase == Player.AttackPhase.SLASH and jugador.attacks_performed == 1,
		"Una pulsación breve no inicia el tajo inmediato: entra en carga."): return
	Input.action_release("attack")
	await physics_frame
	await physics_frame
	await _clic()
	await _clic()
	await _clic()
	await _clic()
	if not await _esperar(func(): return tajos.size() == 3 and not jugador.is_attacking, 8.0):
		_fallar("Se pierden clics anticipados durante el combo: " + str(tajos)); return
	if not _exigir(tajos == ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"],
		"Tres pulsaciones no producen los tres tajos distintos: " + str(tajos)): return
	await create_timer(0.9).timeout
	if not _exigir(cargas == 0 and jugador.attacks_performed == 3,
		"Los clics breves generan una carga o golpes adicionales."): return
	await _clic()
	if not _exigir(tajos.back() == "Sword_Regular_A", "El combo no vuelve al primer tajo tras una pausa."): return
	if not await _reposo(): return
	# Abrir una ventana descarta los clics pendientes; cerrarla no los dispara.
	await _clic()
	await _clic()
	jugador.bloquear_entrada_interfaz(true)
	var golpes := jugador.attacks_performed
	if not await _esperar(func(): return not jugador.is_attacking, 4.0): _fallar("No termina el tajo al abrir la interfaz."); return
	jugador.bloquear_entrada_interfaz(false)
	await create_timer(1.0).timeout
	if not _exigir(jugador.attacks_performed == golpes, "La interfaz deja golpes pendientes al cerrar."): return
	# El clic con el arma guardada desenvaina y da un tajo, sin entrar en carga.
	if not _exigir(jugador.stow_weapon(), "No se pudo guardar la espada."): return
	await create_timer(0.6).timeout
	await _clic()
	if not await _esperar(func(): return jugador.attacks_performed == golpes + 1, 3.0): _fallar("Desenvainar con un clic no inicia el tajo."); return
	if not _exigir(not jugador.is_charging_attack(), "Desenvainar con un clic entra en carga."): return
	if not await _reposo(): return
	# El clic durante el viaje a la espalda tampoco puede perderse.
	golpes = jugador.attacks_performed
	if not _exigir(jugador.stow_weapon(), "No se pudo iniciar el envainado."): return
	await _clic()
	if not await _esperar(func(): return jugador.attacks_performed == golpes + 1, 3.0): _fallar("Un clic durante el envainado se pierde sin desenvainar y atacar."); return
	if not await _reposo(): return
	# Mantener conserva la fuerza especial exigida por los jefes.
	Input.action_press("attack")
	if not await _esperar(func(): return jugador.is_charging_attack(), 4.0): _fallar("Mantener el botón no prepara la carga después del tajo."); return
	if not await _esperar(func(): return jugador.is_spin_ready(), 2.0): _fallar("La carga sostenida no completa la fuerza especial."); return
	Input.action_release("attack")
	if not await _esperar(func(): return jugador.is_spin_attacking(), 0.5): _fallar("Soltar una carga completa no inicia el giro."); return
	if not await _reposo(): return
	# Una herramienta que no ataca y la guardia no deben guardar clics ocultos.
	jugador.equip_item(4)
	await create_timer(0.7).timeout
	golpes = jugador.attacks_performed
	await _clic()
	await create_timer(0.3).timeout
	if not _exigir(jugador.attacks_performed == golpes, "La antorcha inicia un ataque cuerpo a cuerpo."): return
	jugador.equip_item(1)
	await create_timer(0.8).timeout
	if not _exigir(jugador.attacks_performed == golpes, "Cambiar de herramienta conserva un clic antiguo."): return
	print("MELEE INPUT TEST OK: clic inmediato, combo A/B/C, cola acotada, pausa, interfaz, desenvainado y carga deliberada.")
	quit(0)

func _clic() -> void:
	Input.action_press("attack")
	for i in 2: await physics_frame
	Input.action_release("attack")
	for i in 2: await physics_frame

func _reposo() -> bool:
	if not await _esperar(func(): return not jugador.is_attacking and jugador.attack_phase == Player.AttackPhase.NONE, 5.0):
		_fallar("El ataque no vuelve al reposo."); return false
	await create_timer(0.9).timeout
	return true

func _esperar(condicion: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicion.call(): return true
		await physics_frame
	return false

func _exigir(condicion: bool, texto: String) -> bool:
	if not condicion: _fallar(texto)
	return condicion

func _fallar(texto: String) -> void:
	Input.action_release("attack")
	push_error(texto)
	quit(1)
