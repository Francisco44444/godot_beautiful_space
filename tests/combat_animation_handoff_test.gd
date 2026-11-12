extends SceneTree

## Una orden confirmada sustituye la recuperación visual retrasada de la réplica.
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
	var replica := load("res://scenes/player.tscn").instantiate() as Player
	replica.name = "Peer_2"
	replica.configure_network_replica("Compañero", 2)
	mundo.get_node("NetworkPlayers").add_child(replica)
	replica.set_physics_process(false)
	replica.equip_item(1, "Sword")
	await create_timer(0.8).timeout
	var combate := mundo.get_node("CombateCooperativo")
	var orden := {"tipo":"carga", "ranura":1, "objeto":"Sword", "posicion":Vector3(0, 800, 0),
		"yaw":0.0, "velocidad":Vector3.ZERO, "hora":float(Time.get_ticks_usec())/1000000.0, "suelo":true}
	for tajo_activo in [true, false]:
		replica._cancel_melee_charge()
		if tajo_activo: replica._start_slash()
		replica.set("_attack_cooldown", 0.07)
		combate._representar(2, orden)
		if not replica.is_charging_attack() or replica.is_attacking:
			push_error("La réplica rechaza una carga confirmada por conservar el tajo o su recuperación visual.")
			quit(1)
			return
	print("COMBAT ANIMATION HANDOFF TEST OK: carga confirmada tras tajo activo y recuperación visual retrasada.")
	quit(0)
