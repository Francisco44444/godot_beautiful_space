extends SceneTree

## La rejilla debe devolver el mismo empuje que comparar con todos los vecinos,
## también si uno que ya se movió este tick ha cruzado una celda.
func _init() -> void: call_deferred("_run_test")

func _run_test() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for singleton in ["InventoryManager","ExplorationManager"]: root.get_node(singleton).set("autosave_enabled",false)
	var folk := VillageFolk.new()
	root.add_child(folk)
	var random := RandomNumberGenerator.new()
	random.seed = 481516
	var fixtures := [Vector3(0.02,0,0.02),Vector3(-0.02,3,0.02),Vector3(2,7,0.02),Vector3(1.99,-3,0.01),Vector3(0,0,-0.02)]
	for i in 192:
		var walker := VillageNeighbour.new()
		walker.position = fixtures[i] if i<fixtures.size() else Vector3(random.randf_range(-12,12),random.randf_range(-5,5),random.randf_range(-12,12))
		if i>130: walker.position += Vector3(-1450,0,650)
		folk.add_child(walker)
		folk._walkers.append(walker)
	folk._reconstruir_rejilla_evitacion()
	if "--break-avoidance-grid" in OS.get_cmdline_user_args(): folk._rejilla_evitacion.erase(Vector2i(-1,0))
	var comparisons := 0
	for walker in folk._walkers:
		if folk._avoidance(walker).distance_to(_reference(folk,walker))>0.000001:
			_fail("La rejilla cambia el empuje junto a un borde, en negativo o con distinta altura."); return
		comparisons += 1
	for index in folk._walkers.size():
		var walker := folk._walkers[index]
		var previous := folk._celda_evitacion(walker.global_position)
		walker.position += Vector3(2.3 if index%2==0 else -2.3,0,1.9)
		folk._actualizar_celda_evitacion(index,previous)
		var next := folk._walkers[(index+1)%folk._walkers.size()]
		if folk._avoidance(next).distance_to(_reference(folk,next))>0.000001:
			_fail("Un vecino ya movido desaparece de la evitación del siguiente."); return
		comparisons += 1
	if "--bench-avoidance" in OS.get_cmdline_user_args():
		for fast in [false,true,true,false]:
			var start := Time.get_ticks_usec()
			for iteration in 30:
				for walker in folk._walkers:
					if fast: folk._avoidance(walker)
					else: _reference(folk,walker)
			print("AVOIDANCE BENCH ",JSON.stringify({"grid":fast,"ms":(Time.get_ticks_usec()-start)/1000.0,"queries":30*folk._walkers.size()}))
	print("VILLAGE AVOIDANCE PASS: %d fuerzas idénticas, bordes negativos, alturas y traslado secuencial."%comparisons)
	quit(0)

func _reference(folk: VillageFolk,walker: VillageNeighbour) -> Vector3:
	var push := Vector3.ZERO
	for other in folk._walkers:
		if other==walker: continue
		var away := walker.global_position-other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance>folk.AVOID_RADIUS or distance<0.001: continue
		push += away.normalized()*(1.0-distance/folk.AVOID_RADIUS)*folk.AVOID_STRENGTH
	return push.limit_length(0.55)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
