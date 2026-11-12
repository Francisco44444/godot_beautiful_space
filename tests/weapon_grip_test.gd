extends SceneTree

## Mide el mango y el filo en los ocho héroes, incluyendo cambios de escala.
const PIEZAS := {"Sword": [1, Vector3(0, 0.05, 0)], "Claymore": [1, Vector3(0, 0.85, 0)],
	"Sword_Big": [1, Vector3(0, 0.50, 0)], "Sword_2": [1, Vector3(0, -0.03, 0)],
	"Sword_big": [1, Vector3(0, 0.22, 0)], "Sword_big_Golden": [1, Vector3(0, 0.22, 0)],
	"Axe_small": [2, Vector3(0.05, -0.46, 0)], "Axe": [2, Vector3(0.05, -1.20, 0)],
	"Axe_Small": [2, Vector3(0.05, -0.86, 0)], "Torch": [4, Vector3(0, 0.02, 0)]}
var jugador: Player
var inventario: Node
var error_maximo := 0.0
var filo_minimo := 1.0

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	inventario = root.get_node("InventoryManager")
	inventario.reset_inventory_for_tests(false)
	root.get_node("SaveGameManager").set_process(false)
	for pieza in PIEZAS: inventario.add_item(pieza, 1, false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	jugador = mundo.get_node("Player")
	for i in 12: await physics_frame
	jugador.set_physics_process(false)
	for pieza in PIEZAS:
		if not await _equipar(pieza): return
		if not _comprobar_mano(pieza, false): return
		if int(PIEZAS[pieza][0]) == 4: continue
		var malla := jugador.get_equipped_mesh()
		var escala := malla.scale
		if not jugador.stow_weapon(): _fallar("No se puede envainar " + pieza); return
		await create_timer(0.5).timeout
		if not malla.scale.is_equal_approx(escala): _fallar("Envainar pierde la escala propia de " + pieza); return
		var punto: Vector3 = PIEZAS[pieza][1]
		var ancla: Vector3 = jugador.get("_back_weapon_grip").to_global(Player.BACK_WEAPON_POSITION)
		if malla.to_global(punto).distance_to(ancla) > 0.002: _fallar("Envainar desplaza el mango de " + pieza); return
		if not jugador.draw_weapon(): _fallar("No se puede desenvainar " + pieza); return
		await create_timer(0.5).timeout
		if not _comprobar_mano(pieza, false): return
	# Cada rig conserva el puño y la dirección del filo en reposo y al caminar.
	for indice in Player.CHARACTER_PATHS.size():
		jugador.apply_identity("Agarre", indice)
		for pieza in ["Sword", "Axe_small", "Torch"]:
			if not await _equipar(pieza): return
			for andando in [false, true]:
				jugador.velocity = jugador._hero_direction(Vector3(0, 0, 3)) if andando else Vector3.ZERO
				jugador.animation_player.play(Player.ANIM_WALK if andando else Player.ANIM_IDLE, 0.0)
				jugador.animation_player.seek(0.3, true)
				jugador.animation_player.speed_scale = 0.0
				await create_timer(0.25).timeout
				if not _comprobar_mano(pieza, andando): return
	print("WEAPON GRIP TEST OK: diez piezas, escalas al envainar/desenvainar y 48 poses en ocho héroes; error máximo %.9f m, filo mínimo %.3f." % [error_maximo, filo_minimo])
	quit(0)

func _equipar(pieza: String) -> bool:
	var anterior := jugador.equipped_slot
	var ranura: int = PIEZAS[pieza][0]
	inventario.equip_item(pieza, false)
	if anterior != ranura and not jugador.equip_item(ranura): _fallar("No se pudo equipar " + pieza); return false
	await create_timer(0.5).timeout
	if jugador.equipped_item_id != pieza: _fallar("La ranura no cambió a " + pieza); return false
	return true

func _comprobar_mano(pieza: String, andando: bool) -> bool:
	var malla := jugador.get_equipped_mesh()
	var punto: Vector3 = PIEZAS[pieza][1]
	if not (malla.get_meta("grip_point") as Vector3).is_equal_approx(punto): return _fallar("El mango calibrado está fuera de la empuñadura de " + pieza)
	var error := malla.to_global(punto).distance_to(jugador.get("_weapon_grip").global_position)
	error_maximo = maxf(error_maximo, error)
	if error > 0.002: return _fallar("Cambiar a una pieza de otra escala separa la empuñadura de la mano: " + pieza)
	var escala := float(Player.EQUIPMENT_SPECS[int(PIEZAS[pieza][0])].scale) * float(inventario.get_item_definition(pieza).get("mesh_scale", 1.0))
	if not malla.scale.is_equal_approx(Vector3.ONE * escala): return _fallar("La mano pierde la escala propia de " + pieza)
	if pieza == "Torch":
		if malla.global_basis.y.normalized().dot(Vector3.UP) < 0.97: return _fallar("La antorcha pierde la vertical al caminar o descansar.")
	else:
		var filo := malla.global_basis.x.normalized().dot(jugador._hero_direction(Vector3(0, 0, 1)).normalized())
		filo_minimo = minf(filo_minimo, filo)
		if filo < 0.70: return _fallar("El filo vuelve hacia el personaje: %s, andando=%s, %.3f." % [pieza, andando, filo])
	return true

func _fallar(texto: String) -> bool:
	push_error(texto)
	quit(1)
	return false
