extends SceneTree

## Verifica la forma del paisaje y que el destino final sea físicamente usable.

const ROUTE: Array[Vector2] = [
	Vector2(0.0, 190.0),
	Vector2(-4.0, 95.0),
	Vector2(7.0, 25.0),
	Vector2(22.0, -25.0),
	Vector2(43.0, -58.0),
	Vector2(69.0, -86.0),
	Vector2(98.0, -110.0),
]
const VILLAGE_POINTS: Array[Vector2] = [
	Vector2(-18.0, 168.0),
	Vector2(-94.0, 52.0),
	Vector2(126.0, -32.0),
]


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in range(3):
		await process_frame

	var terrain := world.get_node("Terrain3D") as Terrain3D
	var player := world.get_node("Player") as CharacterBody3D
	var maximum_grade := 0.0
	for segment_index in range(ROUTE.size() - 1):
		var start := ROUTE[segment_index]
		var finish := ROUTE[segment_index + 1]
		var length := start.distance_to(finish)
		var steps := ceili(length)
		var previous_height := _height_at(terrain, start)
		for step in range(1, steps + 1):
			var progress := float(step) / float(steps)
			var point := start.lerp(finish, progress)
			var height := _height_at(terrain, point)
			maximum_grade = maxf(maximum_grade, absf(height - previous_height))
			previous_height = height

	if maximum_grade > 0.75:
		_fail("El sendero tiene un escalón demasiado brusco: %.2f m/m" % maximum_grade)
		return

	var valley_height := _height_at(terrain, ROUTE[0])
	var lookout_height := _height_at(terrain, ROUTE[-1])
	if valley_height >= 8.0 or lookout_height < 22.0:
		_fail("Alturas inesperadas: valle %.2f, mirador %.2f" % [valley_height, lookout_height])
		return
	for village_point in VILLAGE_POINTS:
		var village_height := _height_at(terrain, village_point)
		if is_nan(village_height):
			_fail("Un pueblo quedó fuera del Terrain3D ampliado: %s" % village_point)
			return
	if VILLAGE_POINTS[1].distance_to(VILLAGE_POINTS[2]) < 210.0:
		_fail("Los pueblos no aprovechan la anchura del escenario ampliado.")
		return

	# Teletransportamos al personaje sobre la tarima y dejamos actuar la física.
	player.global_position = Vector3(98.0, lookout_height + 3.0, -110.0)
	player.velocity = Vector3.ZERO
	for _frame in range(90):
		await physics_frame

	if not player.is_on_floor():
		_fail("El personaje no aterrizó sobre el mirador.")
		return
	if "alcanzado" not in world.get_node("HUD/Objective").text:
		_fail("El objetivo no detectó la llegada al mirador.")
		return

	print(
		"TERRAIN ROUTE TEST OK: valle %.2f m, mirador %.2f m, pendiente máxima %.2f m/m."
		% [valley_height, lookout_height, maximum_grade]
	)
	quit(0)


func _height_at(terrain: Terrain3D, point: Vector2) -> float:
	return terrain.data.get_height(Vector3(point.x, 0.0, point.y))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
