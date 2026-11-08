extends SceneTree
var world: Node3D
var wonders: Node
var terrain: Terrain3D
var failed := false

func _init() -> void: call_deferred("run")
func run() -> void:
	Engine.time_scale = 4.0
	for singleton in ["InventoryManager","ExplorationManager"]: root.get_node(singleton).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await process_frame
	paused = false
	wonders = world.get_node("RPGStoryRuntime/ForestWonders")
	terrain = world.get_node("Terrain3D")
	world.get_node("Player").set_physics_process(false)
	wonders.set_process(false)
	var inv := root.get_node("InventoryManager")
	var before := int(inv.call("get_item_count","Gold_Ingots")) if inv.has_method("get_item_count") else 0
	for cave in get_nodes_in_group("explorable_cave"):
		if "--break-cave-floor" in OS.get_cmdline_user_args():
			cave.get_node("HollowCollision").disabled = true
			cave.get_node("ApproachCollision").disabled = true
		if int(cave.get_meta("sculpted_terrain_vertices",0))<=0 or cave.has_node("GrassBanksAndStonePath"):
			fail("Los laterales no pertenecen al terreno real"); return
		if terrain.data.get_control_hole(cave.to_global(Vector3(0,0,0))):
			fail("La ladera verde sigue siendo un agujero cubierto con una malla"); return
		cave.gate.open_gate(null,false)
		cave._process(1.0)
		cave.collision_layer = 1
		var probe := CharacterBody3D.new()
		probe.collision_layer = 2
		probe.collision_mask = 1
		probe.floor_snap_length = 0.4
		probe.floor_max_angle = deg_to_rad(48)
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.42
		shape.height = 1.8
		collision.shape = shape
		collision.position.y = 0.9
		probe.add_child(collision)
		world.add_child(probe)
		probe.global_position = cave.to_global(Vector3(0,0.25,34))
		world.get_node("Player").global_position = probe.global_position
		for i in 5: await physics_frame
		var targets: Array[Vector3] = []
		for point in cave.ROUTE: targets.append(point)
		targets.append(cave.SECRET)
		targets.append(Vector3(0,-18,-95))
		for i in range(cave.ROUTE.size()-1,-1,-1): targets.append(cave.ROUTE[i])
		for target in targets:
			var at: Vector3 = cave.to_global(target)
			var arrived := false
			for step in 650:
				await physics_frame
				var delta := at-probe.global_position
				var flat := Vector3(delta.x,0,delta.z)
				if flat.length()<0.65:
					arrived = true
					break
				probe.velocity.x = flat.normalized().x*12
				probe.velocity.z = flat.normalized().z*12
				probe.velocity.y -= 20.0/60.0
				probe.move_and_slide()
				world.get_node("Player").global_position = probe.global_position
				# No se admiten saltos, teletransporte ni pérdida del suelo.
				if probe.global_position.y < cave.global_position.y-25: break
			if not arrived:
				for hit_index in probe.get_slide_collision_count():
					var hit := probe.get_slide_collision(hit_index)
					print("WALK BLOCK ",hit.get_collider()," normal=",hit.get_normal()," at=",cave.to_local(hit.get_position()))
				fail("No se puede caminar por %s hasta %s: se queda en %s" % [cave.name,target,cave.to_local(probe.global_position)])
				return
		print("CAVE WALK OK ",cave.name," recorrido, secreto y regreso sin saltar")
		probe.queue_free()
		await physics_frame
	var actor := world.get_node("Player")
	for memory in get_nodes_in_group("cave_memory"):
		if memory.kind == "rune":
			actor.global_position = memory.global_position
			memory.interact(actor)
			paused = false
	var heart: Node3D
	for memory in get_nodes_in_group("cave_memory"):
		if memory.kind == "heart": heart = memory; break
	actor.global_position = heart.global_position
	heart.interact(actor)
	paused = false
	var count_before: int = wonders.trace_rewards
	heart.interact(actor)
	paused = false
	if wonders.trace_rewards != count_before: fail("El recuerdo paga dos veces"); return
	var secret: Node3D
	for memory in get_nodes_in_group("cave_memory"):
		if memory.kind == "secret": secret = memory; break
	actor.global_position = secret.global_position
	secret.interact(actor)
	paused = false
	var secret_rewards: int = wonders.trace_rewards
	secret.interact(actor)
	paused = false
	if wonders.trace_rewards != secret_rewards: fail("El secreto paga dos veces"); return
	var state: Dictionary = wonders.save_state()
	wonders.load_state({})
	if wonders.rune_count("roots") != 0: fail("Cambiar de ranura arrastra voces viejas"); return
	wonders.load_state(state)
	if wonders.rune_count("roots") != 3: fail("Las voces no sobreviven al guardado"); return
	wonders.guide_stage = 1
	wonders.guide_index = 0
	wonders._build_route()
	if wonders.route.size()<30: fail("El guía no encuentra un recorrido entre los troncos"); return
	world.sun_cycle_radians = PI*1.5
	world._update_sun_cycle(0.0)
	actor.global_position = wonders.grounded(wonders.START)
	wonders._guide.global_position = wonders.route[0]
	var waiting: Vector3 = wonders._guide.global_position
	actor.global_position = waiting+Vector3(0,0,80)
	wonders._process(0.1)
	if wonders._guide.global_position != waiting: fail("El ciervo no espera al jugador rezagado"); return
	actor.global_position = waiting+Vector3(0,0,3)
	actor.velocity = Vector3(10,0,0)
	wonders._process(0.1)
	if wonders._guide.global_position != waiting: fail("El ciervo avanza aunque lo persigan corriendo"); return
	for i in 2200:
		actor.global_position = wonders._guide.global_position + Vector3(0,0,3)
		actor.velocity = Vector3.ZERO
		wonders._process(0.1)
		if wonders.guide_stage == 2: break
	if wonders.guide_stage != 2: fail("El ciervo no llega al claro"); return
	var flower: Node3D = get_nodes_in_group("cave_memory").filter(func(n):return n.kind=="flower")[0]
	actor.global_position = flower.global_position
	flower.interact(actor)
	paused = false
	if wonders.guide_stage != 3: fail("La flor no cierra la misión"); return
	world.sun_cycle_radians = PI/2
	world._update_sun_cycle(0)
	wonders._update_ambient()
	if wonders._fireflies.visible: fail("Hay luciérnagas de día"); return
	print("WONDERS TEST OK: cuatro grutas, 12 voces, recompensas únicas, guardado, guía y ciclo nocturno")
	quit(0)
func fail(message: String) -> void:
	push_error(message)
	quit(1)
