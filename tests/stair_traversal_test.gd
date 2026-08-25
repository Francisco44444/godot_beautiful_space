extends SceneTree

## Recorre físicamente una escalera doméstica y otra de la ciudadela con una
## cápsula idéntica a la del héroe. Nunca aplica velocidad de salto: alcanzar
## la planta superior demuestra que el primer peldaño y el desembarco son
## continuos y no exigen saltar.

const GRAVITY := 22.0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_world := load("res://scenes/world.tscn") as PackedScene
	var world := packed_world.instantiate()
	root.add_child(world)
	for _frame in 5:
		await physics_frame

	var medieval := world.get_node("MedievalSetDressing") as MedievalSetDressing
	var house: StaticBody3D
	var castle: StaticBody3D
	for child in medieval.get_children():
		if not child is StaticBody3D:
			continue
		if house == null and ("House" in child.name or "Hall" in child.name):
			house = child as StaticBody3D
		if castle == null and bool(child.get_meta("complete_fortress", false)):
			castle = child as StaticBody3D
	if house == null or castle == null:
		_fail("No se encontraron una vivienda y una ciudadela para probar las escaleras.")
		return

	var house_end: Vector3 = await _walk_without_jump(
		world,
		house,
		Vector3(3.0, 0.48, 3.95),
		Vector3(0.0, 0.0, -1.0),
		3.54,
		280
	)
	if house_end.y < 3.52 or house_end.z > -3.20:
		_fail("La escalera de la vivienda aún exige saltar o no alcanza su descansillo.")
		return

	var citadel_origin: Vector3 = castle.get_meta("citadel_origin", Vector3.ZERO)
	var castle_end: Vector3 = await _walk_without_jump(
		world,
		castle,
		Vector3(15.75, citadel_origin.y + 0.16, citadel_origin.z + 6.35),
		Vector3(0.0, 0.0, -1.0),
		citadel_origin.y + float(castle.get_meta("citadel_storey_height", 0.0)) + 0.12,
		380
	)
	if (
		castle_end.y < citadel_origin.y + float(castle.get_meta("citadel_storey_height", 0.0)) + 0.10
		or castle_end.z > citadel_origin.z - 5.45
	):
		_fail("La escalera de la ciudadela aún exige saltar o no alcanza su descansillo.")
		return

	var gate_end: Vector3 = await _walk_without_jump(
		world,
		castle,
		Vector3(0.0, 0.05, 59.0),
		Vector3(0.0, 0.0, -1.0),
		CASTLE_COURTYARD_Y_FOR_TEST - 0.20,
		360
	)
	if gate_end.y < CASTLE_COURTYARD_Y_FOR_TEST - 0.20 or gate_end.z > 42.0:
		_fail("La rampa principal del castillo no permite entrar caminando hasta el patio.")
		return

	print("STAIR TRAVERSAL TEST OK: vivienda, ciudadela y acceso al castillo recorridos sin saltar.")
	quit(0)


const CASTLE_COURTYARD_Y_FOR_TEST := 1.85


func _walk_without_jump(
	world: Node3D,
	support: Node3D,
	local_start: Vector3,
	local_direction: Vector3,
	target_local_y: float,
	physics_steps: int
) -> Vector3:
	var walker := CharacterBody3D.new()
	walker.name = "NoJumpStairWalker"
	walker.collision_layer = 2
	walker.collision_mask = 1
	walker.floor_snap_length = 0.35
	walker.floor_max_angle = deg_to_rad(48.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.position = Vector3(0.0, 0.9, 0.0)
	collision.shape = capsule
	walker.add_child(collision)
	world.add_child(walker)
	walker.global_position = support.to_global(local_start)
	var travel_direction := support.global_transform.basis * local_direction
	travel_direction.y = 0.0
	travel_direction = travel_direction.normalized()

	for _step in physics_steps:
		walker.velocity.x = travel_direction.x * 3.8
		walker.velocity.z = travel_direction.z * 3.8
		walker.velocity.y = -0.35 if walker.is_on_floor() else walker.velocity.y - GRAVITY / 60.0
		walker.move_and_slide()
		await physics_frame

	var final_local := support.to_local(walker.global_position)
	print("STAIR WALK %s: inicio=%s final=%s objetivo_y=%.2f" % [support.name, local_start, final_local, target_local_y])
	walker.queue_free()
	return final_local


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
