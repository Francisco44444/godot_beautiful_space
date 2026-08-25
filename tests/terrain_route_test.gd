extends SceneTree

## Verifica la forma del paisaje y que la antigua plataforma del mirador siga
## siendo físicamente usable aunque ya no sea un objetivo obligatorio.

const ROUTE: Array[Vector2] = [Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)]
const VILLAGE_POINTS: Array[Vector2] = [
	Vector2(0, 190), Vector2(-1450, 650), Vector2(-2200, -900),
	Vector2(2260, -980), Vector2(2180, 1880), Vector2(-420, -2150),
]
const GROTTO_ROUTE: Array[Vector2] = [
	Vector2(2780, 1480), Vector2(3070, 1540), Vector2(3340, 1640),
	Vector2(3600, 1770), Vector2(3890, 1900),
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
		# Cuatro muestras a 250 m deben continuar al nivel de la villa: el núcleo
		# habitable ya no puede ser un pequeño disco hundido entre edificios.
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var plateau_height := _height_at(terrain, village_point + direction * 250.0)
			if absf(plateau_height - village_height) > 2.5:
				_fail("La villa %s no dispone de una gran meseta continua: %.2f frente a %.2f" % [village_point, village_height, plateau_height])
				return
	if VILLAGE_POINTS[2].distance_to(VILLAGE_POINTS[3]) < 4000.0:
		_fail("Las villas no aprovechan la anchura del mundo insular.")
	if _height_at(terrain, Vector2(5900, 0)) >= 1.0:
		_fail("El nuevo borde oriental debería hundirse bajo el mar.")
	if _height_at(terrain, Vector2(4800, -1300)) < 120.0:
		_fail("La península del Bosque Tenebroso no prolonga realmente la isla hacia el este.")
		return
	if _height_at(terrain, Vector2(520, -3000)) < 150.0:
		_fail("La cordillera nevada no alcanza una altura reconocible.")
		return

	# La nieve asciende como un macizo completo: piedemonte, media montaña y
	# cumbre. Se valida una sección continua para evitar volver a una elevación
	# circular y aislada.
	var snow_profile := [
		_height_at(terrain, Vector2(180, -2100)),
		_height_at(terrain, Vector2(180, -2700)),
		_height_at(terrain, Vector2(180, -3200)),
		_height_at(terrain, Vector2(180, -3350)),
	]
	if snow_profile[0] >= snow_profile[1] or snow_profile[1] >= snow_profile[2] or snow_profile[2] > snow_profile[3] + 2.0:
		_fail("La subida a Cumbres Blancas no es progresiva: %s" % [snow_profile])
		return
	if snow_profile[3] < 485.0 or snow_profile[3] > 500.1:
		_fail("La gran cumbre no alcanza el entorno de 500 m: %.2f" % snow_profile[3])
		return

	# Hay sistemas montañosos anchos en varios cuadrantes, no una sola aguja.
	var relief_samples := {
		"oeste": [_height_at(terrain, Vector2(-3150, -850)), _height_at(terrain, Vector2(-3650, -850)), 105.0],
		"este": [_height_at(terrain, Vector2(3120, -1280)), _height_at(terrain, Vector2(3650, -1280)), 90.0],
		"sur": [_height_at(terrain, Vector2(-2650, 2150)), _height_at(terrain, Vector2(-1950, 2150)), 65.0],
	}
	for relief_name in relief_samples:
		var relief: Array = relief_samples[relief_name]
		if relief[0] < relief[2] or relief[1] < relief[2] * 0.60:
			_fail("El macizo %s quedó demasiado pequeño o estrecho: %s" % [relief_name, relief])
			return
	var great_massifs := {
		"noroeste": _height_at(terrain, Vector2(-2850, -2200)),
		"cordillera oriental": _height_at(terrain, Vector2(2700, -2350)),
		"sierra sur": _height_at(terrain, Vector2(-980, 2940)),
	}
	for massif_name in great_massifs:
		if great_massifs[massif_name] < 300.0:
			_fail("El gran macizo %s no alcanza 300 m: %.2f" % [massif_name, great_massifs[massif_name]])
			return

	# La meseta desértica cae más de 60 m, pero la garganta tallada mantiene una
	# pendiente transitable de principio a fin.
	var grotto_grade := _maximum_route_grade(terrain, GROTTO_ROUTE, 12.0)
	var upper_cliff := _height_at(terrain, Vector2(3070, 1540))
	var lower_cliff := _height_at(terrain, Vector2(3890, 1900))
	if upper_cliff - lower_cliff < 60.0:
		_fail("El acantilado desértico no tiene suficiente desnivel: %.2f -> %.2f" % [upper_cliff, lower_cliff])
		return
	if grotto_grade > 0.18:
		_fail("La bajada de la gruta es demasiado abrupta: %.3f m/m" % grotto_grade)
		return
	var cliff_texture := terrain.data.get_texture_id(Vector3(3500.0, 0.0, 2200.0))
	if int(cliff_texture.x) != 3:
		_fail("El fondo de la fosa desértica no conserva su arena low-poly: %s" % cliff_texture)
		return
	var coastal_cliff_texture := terrain.data.get_texture_id(Vector3(-260.0, 0.0, -3836.0))
	if int(coastal_cliff_texture.x) != 6:
		_fail("La cornisa costera abrupta no usa la nueva caliza low-poly: %s" % coastal_cliff_texture)
		return
	# Esta pared queda tierra adentro, junto al marcador rojo del mapa. Debe usar
	# la misma caliza por superar 55 grados aunque no coincida con la costa radial.
	var interior_cliff_texture := terrain.data.get_texture_id(Vector3(-3676.0, 0.0, 1502.0))
	if int(interior_cliff_texture.x) != 6:
		_fail("La pared abrupta del Bosque Umbrío sigue apareciendo verde: %s" % interior_cliff_texture)
		return
	for abyss_point in [Vector2(3060, 850), Vector2(3920, 810), Vector2(3130, 2450), Vector2(4050, 1510)]:
		var abyss_height := _height_at(terrain, abyss_point)
		if abyss_height > -465.0:
			_fail("Una rama de la fosa no alcanza casi -500 m en %s: %.2f" % [abyss_point, abyss_height])
			return

	# Arena continua en los cuatro cuadrantes costeros y una ría inundada que
	# penetra entre los macizos occidentales.
	for beach_point in [Vector2(-4100, 0), Vector2(4700, 0), Vector2(0, -4100), Vector2(0, 4100)]:
		var beach_texture := terrain.data.get_texture_id(Vector3(beach_point.x, 0.0, beach_point.y))
		var beach_height := _height_at(terrain, beach_point)
		if int(beach_texture.x) != 3 or beach_height < -8.0 or beach_height > 24.0:
			_fail("El perímetro no forma playa en %s: altura %.2f, material %s" % [beach_point, beach_height, beach_texture])
			return
	if _height_at(terrain, Vector2(-3990, 2200)) > 4.0:
		_fail("La ría occidental no penetra en el valle entre montañas.")
		return
	var mystery_height := _height_at(terrain, Vector2(4380, -1320))
	var mystery_texture := terrain.data.get_texture_id(Vector3(4380.0, 0.0, -1320.0))
	if mystery_height < 120.0 or int(mystery_texture.x) != 2:
		_fail("El Bosque Tenebroso no es una región elevada de roca musgosa: %.2f, %s" % [mystery_height, mystery_texture])
		return

	# Teletransportamos al personaje sobre la tarima y dejamos actuar la física.
	player.global_position = Vector3(98.0, lookout_height + 3.0, -110.0)
	player.velocity = Vector3.ZERO
	for _frame in range(90):
		await physics_frame

	if not player.is_on_floor():
		_fail("El personaje no aterrizó sobre el mirador.")
		return
	if world.get_node("HUD/Objective").visible or not world.get_node("HUD/Objective").text.is_empty():
		_fail("El antiguo objetivo del mirador continúa visible en el HUD.")
		return

	print(
		"ISLAND ROUTE TEST OK: villa %.2f m, cumbre %.2f m, gruta %.3f m/m, ruta %.2f m/m."
		% [valley_height, snow_profile[3], grotto_grade, maximum_grade]
	)
	quit(0)


func _height_at(terrain: Terrain3D, point: Vector2) -> float:
	return terrain.data.get_height(Vector3(point.x, 0.0, point.y))


func _maximum_route_grade(terrain: Terrain3D, route: Array[Vector2], sample_spacing: float) -> float:
	var maximum_grade := 0.0
	for segment_index in range(route.size() - 1):
		var start := route[segment_index]
		var finish := route[segment_index + 1]
		var length := start.distance_to(finish)
		var steps := ceili(length / sample_spacing)
		var previous_height := _height_at(terrain, start)
		for step in range(1, steps + 1):
			var progress := float(step) / float(steps)
			var height := _height_at(terrain, start.lerp(finish, progress))
			maximum_grade = maxf(maximum_grade, absf(height - previous_height) / (length / steps))
			previous_height = height
	return maximum_grade


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
