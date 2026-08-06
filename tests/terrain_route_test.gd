extends SceneTree

## Verifica la forma del paisaje y que el destino final sea físicamente usable.

const ROUTE: Array[Vector2] = [Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)]
const VILLAGE_POINTS: Array[Vector2] = [
	Vector2(0, 190), Vector2(-1450, 650), Vector2(-2200, -900),
	Vector2(2260, -980), Vector2(2180, 1880), Vector2(-420, -2150),
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
		var steps := ceili(length / 20.0)
		var previous_height := _height_at(terrain, start)
		for step in range(1, steps + 1):
			var progress := float(step) / float(steps)
			var point := start.lerp(finish, progress)
			var height := _height_at(terrain, point)
			maximum_grade = maxf(maximum_grade, absf(height - previous_height) / 20.0)
			previous_height = height

	if maximum_grade > 1.25:
		_fail("La ruta a la cordillera tiene un desnivel imposible: %.2f m/m" % maximum_grade)
		return

	var valley_height := _height_at(terrain, ROUTE[0])
	var lookout_height := _height_at(terrain, Vector2(98, -110))
	if valley_height < 8.0 or lookout_height < 22.0:
		_fail("Alturas inesperadas: villa inicial %.2f, mirador %.2f" % [valley_height, lookout_height])
		return
	for village_point in VILLAGE_POINTS:
		var village_height := _height_at(terrain, village_point)
		if is_nan(village_height):
			_fail("Un pueblo quedó fuera del Terrain3D ampliado: %s" % village_point)
			return
	if VILLAGE_POINTS[2].distance_to(VILLAGE_POINTS[3]) < 4000.0:
		_fail("Las villas no aprovechan la anchura de 10 km de la isla.")
	if _height_at(terrain, Vector2(4700, 0)) >= 1.0:
		_fail("El borde oriental debería hundirse bajo el mar.")
	if _height_at(terrain, Vector2(520, -3000)) < 150.0:
		_fail("La cordillera nevada no alcanza una altura reconocible.")
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
		"ISLAND ROUTE TEST OK: villa %.2f m, mirador %.2f m, pendiente máxima %.2f m/m."
		% [valley_height, lookout_height, maximum_grade]
	)
	quit(0)


func _height_at(terrain: Terrain3D, point: Vector2) -> float:
	return terrain.data.get_height(Vector3(point.x, 0.0, point.y))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
