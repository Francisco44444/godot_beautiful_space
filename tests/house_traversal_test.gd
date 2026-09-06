extends SceneTree

## La prueba que responde a "bonito por fuera, fatal por dentro": una cápsula
## idéntica al héroe entra por la puerta y sube por CADA UNO de los dos tramos
## de CADA planta, sin aplicar nunca velocidad de salto.
##
## Cada fallo que caza corresponde a un defecto real que apareció al construirla:
##   - el forjado superior era una losa maciza sin hueco de escalera, así que el
##     tramo subía contra el techo y la planta alta era inalcanzable;
##   - y el tramo de vuelta arrancaba justo en el borde del hueco que había
##     abierto el tramo de ida, de modo que quien subía se despeñaba por él.
## Las dos veces la casa parecía perfecta por fuera y tenía las escaleras
## puestas: sólo caminándola se ve.

const MIN_HOUSES_TO_WALK := 20
const GRAVITY := 22.0
const WALK_SPEED := 5.0
const MAX_STEPS := 800
## Cuánto del desnivel hay que salvar para dar el tramo por subido.
const CLIMB_FRACTION := 0.8


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	# Save data belongs to the player; this geometry test never writes a slot.
	for singleton_name in ["ExplorationManager", "InventoryManager"]:
		root.get_node(singleton_name).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	Engine.physics_ticks_per_second = 360
	Engine.time_scale = 6.0
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	root.get_node("SaveGameManager").call("bind_world", null)
	world.set_process(false)
	world.set_physics_process(false)
	world.get_node("Player").set_physics_process(false)
	for _frame in 8:
		await physics_frame

	var medieval := world.get_node("MedievalSetDressing") as MedievalSetDressing
	var walked := 0
	var flights := 0
	var floors_walked: Dictionary = {}
	for child in medieval.get_children():
		if not child is StaticBody3D:
			continue
		if not String(child.name).begins_with("Villa Robledal") or not child.has_meta("floor_count"):
			continue
		walked += 1
		var body := child as StaticBody3D
		var doorway := body.get_node_or_null("Doorway") as Node3D
		var interior := body.get_node_or_null("InteriorPoint") as Node3D
		var approach := body.get_node_or_null("ApproachPoint") as Node3D
		if doorway == null or interior == null or approach == null:
			_fail("%s no declara umbral y punto interior." % body.name)
			return

		var walker := _make_walker(world)
		walker.global_position = approach.global_position + Vector3.UP * 0.2
		if body.position.y <= float(body.get_meta("terrain_max_height", INF)):
			_fail("%s tiene terreno atravesando el suelo interior." % body.name)
			return
		if not await _walk_to(walker, interior.global_position):
			_fail("No se puede entrar en %s: la cápsula no llega del umbral al interior." % body.name)
			return
		if not await _walk_to(walker, approach.global_position):
			_fail("No se puede SALIR de %s por la misma puerta y rampa." % body.name)
			return
		var floor_count := int(body.get_meta("floor_count"))
		if floors_walked.has(floor_count):
			walker.queue_free()
			await physics_frame
			continue
		floors_walked[floor_count] = true

		var ramps := _ramps(body)
		var expected := int(body.get_meta("stair_count", 0))
		if ramps.size() != expected:
			_fail("%s declara %d escaleras y tiene %d cuñas." % [body.name, expected, ramps.size()])
			return
		if ramps.is_empty():
			_fail("%s no tiene ninguna escalera." % body.name)
			return
		# Recorrido humano continuo desde el exterior hasta la última planta y
		# vuelta. La prueba tramo-a-tramo no detectaba que el siguiente cerraba
		# el desembarco sobre la cabeza del jugador.
		if not await _walk_whole_house(walker, body, ramps, approach.global_position, interior.global_position):
			return
		for ramp in ramps:
			var foot: Vector3 = ramp[0]
			var head: Vector3 = ramp[1]
			walker.global_position = foot + Vector3.UP * 0.16
			walker.velocity = Vector3.ZERO
			for _frame in 6:
				await physics_frame
			var start_y := walker.global_position.y
			if not await _walk_to(walker, head + (head - foot).normalized() * 0.65):
				_fail("En %s no se puede salir completamente del tramo." % body.name)
				return
			var climbed := walker.global_position.y - start_y
			if climbed < (head.y - foot.y) * CLIMB_FRACTION:
				_fail(
					"En %s un tramo sólo sube %.2f m de %.2f: no se llega arriba andando."
					% [body.name, climbed, head.y - foot.y]
				)
				return
			if not await _walk_to(walker, foot):
				_fail("En %s no se puede bajar del descansillo al pie de la escalera." % body.name)
				return
			flights += 1
		walker.queue_free()
		await process_frame

	if walked < MIN_HOUSES_TO_WALK or floors_walked.size() != 3:
		_fail("Sólo se han recorrido %d casas; plantas representadas: %s." % [walked, floors_walked])
		return
	print("HOUSE TRAVERSAL OK: %d puertas recorridas entrando y saliendo, %d tramos subidos y bajados sin saltar; casas de 3, 4 y 5 plantas." % [walked, flights])
	quit()


func _walk_whole_house(walker: CharacterBody3D, body: StaticBody3D, ramps: Array, outside: Vector3, interior: Vector3) -> bool:
	var interior_floor := interior - Vector3.UP * 1.1 * body.scale.y
	var waypoints: Array[Vector3] = [outside, interior_floor]
	var centre_x := (body.to_local(ramps[0][0]).x + body.to_local(ramps[1][0]).x) * 0.5
	var local_here := body.to_local(interior)
	# Primero salir del umbral al pasillo central, no atravesar la escalera.
	waypoints.append(body.to_global(Vector3(centre_x, 0.0, local_here.z)))
	var floor_count := int(body.get_meta("floor_count"))
	for level in range(floor_count - 1):
		var foot := body.to_local(ramps[level * 2][0])
		var head := body.to_local(ramps[level * 2][1])
		var direction := signf(head.z - foot.z)
		var entry_z := foot.z - direction * 0.85
		waypoints.append(body.to_global(Vector3(centre_x, foot.y, entry_z)))
		waypoints.append(body.to_global(Vector3(foot.x, foot.y, entry_z)))
		waypoints.append(body.to_global(foot))
		waypoints.append(body.to_global(head))
		var exit_z := head.z + direction * 0.85
		if level < floor_count - 2:
			var next_foot := body.to_local(ramps[(level + 1) * 2][0])
			exit_z = next_foot.z + direction * 0.85
		waypoints.append(body.to_global(Vector3(head.x, head.y, exit_z)))
		waypoints.append(body.to_global(Vector3(centre_x, head.y, exit_z)))
	# No teletransportes: la cápsula sigue donde quedó tras salir de la casa.
	for index in range(1, waypoints.size()):
		if not await _walk_to(walker, waypoints[index]) or absf(walker.global_position.y - waypoints[index].y) > 0.45:
			_fail("Recorrido continuo bloqueado en %s, paso %d, posición %s, destino %s." % [body.name, index, body.to_local(walker.global_position), body.to_local(waypoints[index])])
			return false
	for index in range(waypoints.size() - 2, -1, -1):
		if not await _walk_to(walker, waypoints[index]) or absf(walker.global_position.y - waypoints[index].y) > 0.45:
			_fail("No se puede regresar andando en %s, paso %d, posición %s, destino %s." % [body.name, index, body.to_local(walker.global_position), body.to_local(waypoints[index])])
			return false
	print("RECORRIDO CONTINUO OK: %s, %d plantas, subida y bajada sin recolocar al personaje." % [body.name, floor_count])
	return true


func _make_walker(world: Node) -> CharacterBody3D:
	var walker := CharacterBody3D.new()
	walker.collision_layer = 2
	walker.collision_mask = 1
	walker.floor_max_angle = deg_to_rad(48.0)
	walker.floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	walker.add_child(shape)
	world.add_child(walker)
	return walker


func _ramps(body: StaticBody3D) -> Array:
	## Pie y meseta de cada tramo, tomados en el CENTRO de la cuña. En un canto
	## lateral la cápsula nace pegada al muro y se queda encajada sin pisarla.
	var out: Array = []
	for part in body.get_children():
		if not (part is CollisionShape3D):
			continue
		var collision := part as CollisionShape3D
		if not collision.name.begins_with("Escalera") and not collision.name.begins_with("Caracol"):
			continue
		var points: PackedVector3Array = (collision.shape as ConvexPolygonShape3D).points
		var lowest := INF
		var highest := -INF
		# First point of each wedge is exactly on its bottom walking surface;
		# the under-side vertices must not lower the test's spawn beneath steps.
		var bottom_y := points[0].y
		for point in points:
			var world_point: Vector3 = collision.global_transform * point
			lowest = minf(lowest, world_point.y)
			highest = maxf(highest, world_point.y)
		var low_sum := Vector3.ZERO
		var low_count := 0
		var high_sum := Vector3.ZERO
		var high_count := 0
		for point in points:
			var world_point: Vector3 = collision.global_transform * point
			if is_equal_approx(point.y, bottom_y):
				low_sum += world_point
				low_count += 1
			if absf(highest - world_point.y) < 0.02:
				high_sum += world_point
				high_count += 1
		if low_count == 0 or high_count == 0:
			continue
		out.append([low_sum / float(low_count), high_sum / float(high_count)])
	return out


func _walk_to(walker: CharacterBody3D, target: Vector3) -> bool:
	for _step in MAX_STEPS:
		var delta := target - walker.global_position
		var flat := Vector3(delta.x, 0.0, delta.z)
		if flat.length() < 0.22:
			return true
		var direction := flat.normalized()
		walker.velocity.x = direction.x * WALK_SPEED
		walker.velocity.z = direction.z * WALK_SPEED
		if walker.is_on_floor():
			walker.velocity.y = 0.0
		else:
			walker.velocity.y -= GRAVITY * (1.0 / 60.0)
		walker.move_and_slide()
		await physics_frame
	return false


func _fail(message: String) -> void:
	push_error(message)
	printerr(message)
	quit(1)
