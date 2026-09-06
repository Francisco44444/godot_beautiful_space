extends SceneTree

## Un jefe tiene que costar llegar y, a la vez, poder alcanzarse. Las dos cosas
## se rompen por separado: acercar una arena a un camino la vuelve un tropiezo,
## y moverla a una cima cerrada la vuelve inalcanzable. Antes de esto, tres de
## las cinco estaban a menos de 200 m de un camino y el Centinela a 91 m de una
## casa: te lo encontrabas sin buscarlo.


const MIN_ROAD := 350.0
const MIN_HOUSE := 300.0
## El suelo de la arena tiene que ser llano o el jefe pelea en una ladera.
const MAX_RELIEF := 4.0
## El héroe sube hasta unos 45°. Por encima de 0,85 de desnivel por metro no
## hay paso.
const WALKABLE := 0.85
const MIN_WALKABLE_BEARINGS := 3
const GUARDS_PER_ARENA := 4

var _terrain: Node = null


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 7:
		await process_frame

	var runtime := world.get_node_or_null("RPGStoryRuntime")
	if runtime == null:
		_fail("Falta RPGStoryRuntime.")
		return
	_terrain = runtime.get("_terrain")
	if _terrain == null:
		_fail("Sin terreno no se puede medir el acceso.")
		return

	var roads: Array[Vector2] = []
	for road in VegetationScatter.ROAD_NETWORK:
		for raw in road:
			roads.append(Vector2(raw))
	var houses: Array[Vector2] = []
	for node in root.get_tree().get_nodes_in_group("adventure_interactable"):
		var n := node as Node3D
		if n != null:
			houses.append(Vector2(n.global_position.x, n.global_position.z))

	var closest_road := 1e9
	for arena in RPGBestiary.ARENAS:
		var id := String(arena["id"])
		var centre: Vector2 = arena["centre"]
		var radius: float = arena["radius"]

		var road_span := _nearest(centre, roads)
		closest_road = minf(closest_road, road_span)
		if road_span < MIN_ROAD:
			_fail("%s está a %.0f m de un camino: te lo encuentras sin buscarlo." % [id, road_span])
			return
		var house_span := _nearest(centre, houses)
		if house_span < MIN_HOUSE:
			_fail("%s está a %.0f m de una casa." % [id, house_span])
			return

		var low := 1e9
		var high := -1e9
		for k in 24:
			var probe := _height(centre + Vector2.RIGHT.rotated(TAU * k / 24.0) * radius)
			low = minf(low, probe)
			high = maxf(high, probe)
		if high - low > MAX_RELIEF:
			_fail("%s tiene %.1f m de desnivel en su suelo: el jefe pelearía en una ladera." % [
				id, high - low])
			return

		var walkable := 0
		for k in 32:
			if _climb(centre, TAU * k / 32.0, radius) <= WALKABLE:
				walkable += 1
		if walkable < MIN_WALKABLE_BEARINGS:
			_fail("%s sólo tiene %d rumbos subibles de 32: el jefe es inalcanzable." % [id, walkable])
			return

		# Los hitos marcan UNA cuesta. Si marcan un risco, el jugador los sigue
		# hasta un muro y se queda sin saber por dónde se entra.
		var built := runtime.get_node_or_null("Arena_%s" % id)
		if built == null:
			_fail("No se levantó la arena de %s." % id)
			return
		var bearing := float(built.get_meta("approach_bearing", -1.0))
		if bearing < 0.0:
			_fail("%s no marcó ninguna cuesta." % id)
			return
		var marked := _climb(centre, bearing, radius)
		if marked > WALKABLE:
			_fail("%s marca una cuesta de %.2f: los hitos llevan a un muro." % [id, marked])
			return

	# Ningún árbol dentro del suelo de piedra. Antes de darles claro propio había
	# 5 atravesando losas y monolitos, y 14 más en el borde.
	var scatter := world.get_node_or_null("VegetationScatter")
	if scatter == null:
		_fail("Sin VegetationScatter no se puede comprobar que las arenas estén despejadas.")
		return
	var trunks: Array = scatter.get("tree_positions")
	if trunks.size() < 10000:
		_fail("Sólo %d troncos: el contador no está mirando la vegetación real." % trunks.size())
		return
	for arena in RPGBestiary.ARENAS:
		var centre: Vector2 = arena["centre"]
		var hull: float = float(arena["radius"]) + 6.0
		var intruders := 0
		for origin in trunks:
			if centre.distance_squared_to(Vector2(origin.x, origin.z)) < hull * hull:
				intruders += 1
		if intruders > 0:
			_fail("%s tiene %d árboles dentro de la arena." % [String(arena["id"]), intruders])
			return

	var guards := int(runtime.get("generated_approach_guards"))
	if guards != RPGBestiary.ARENAS.size() * GUARDS_PER_ARENA:
		_fail("Se esperaban %d centinelas en las cuestas y hay %d." % [
			RPGBestiary.ARENAS.size() * GUARDS_PER_ARENA, guards])
		return

	print("OK · %d arenas despejadas, la más accesible a %.0f m de un camino, cuestas marcadas y %d centinelas" % [
		RPGBestiary.ARENAS.size(), closest_road, guards])
	quit(0)


func _climb(centre: Vector2, bearing: float, radius: float) -> float:
	var direction := Vector2.RIGHT.rotated(bearing)
	var worst := 0.0
	var last := _height(centre + direction * 220.0)
	var steps := int((220.0 - radius) / 5.0)
	for step in range(1, steps + 1):
		var probe := _height(centre + direction * (220.0 - step * 5.0))
		if is_nan(probe) or is_nan(last):
			return 99.0
		worst = maxf(worst, absf(probe - last) / 5.0)
		last = probe
	return worst


func _height(point: Vector2) -> float:
	return _terrain.data.get_height(Vector3(point.x, 0.0, point.y))


func _nearest(point: Vector2, cloud: Array[Vector2]) -> float:
	var span := 1e9
	for other in cloud:
		span = minf(span, point.distance_squared_to(other))
	return sqrt(span)


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
