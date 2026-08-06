extends SceneTree

## Construye una isla low-poly de 10 x 10 km. Terrain3D conserva una malla
## manejable de 1024² vértices y la extiende mediante vertex_spacing.

const MAP_SIZE := 1024
const WORLD_SIZE_METERS := 10000.0
const VERTEX_SPACING := WORLD_SIZE_METERS / float(MAP_SIZE)
const MAP_ORIGIN := Vector2(-WORLD_SIZE_METERS * 0.5, -WORLD_SIZE_METERS * 0.5)
const DATA_DIRECTORY := "res://terrain/data"
const LOOKOUT := Vector2(98.0, -110.0)

const ROAD_NETWORK: Array = [
	[Vector2(0, 190), Vector2(-120, 520), Vector2(-420, 760), Vector2(-980, 780), Vector2(-1450, 650)],
	[Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)],
	[Vector2(-1450, 650), Vector2(-1780, 230), Vector2(-2050, -420), Vector2(-2200, -900)],
	[Vector2(0, 190), Vector2(620, 320), Vector2(1260, 120), Vector2(1840, -420), Vector2(2260, -980)],
	[Vector2(620, 320), Vector2(1120, 820), Vector2(1660, 1320), Vector2(2180, 1880)],
	[Vector2(-1450, 650), Vector2(-1850, 1120), Vector2(-2180, 1650)],
	[Vector2(-420, -2150), Vector2(260, -2500), Vector2(720, -3080)],
	[Vector2(98, -110), Vector2(420, -420), Vector2(920, -560), Vector2(1840, -420)],
]

const SETTLEMENTS: Array[Vector3] = [
	Vector3(0.0, 12.0, 190.0),
	Vector3(-1450.0, 22.0, 650.0),
	Vector3(-2200.0, 20.0, -900.0),
	Vector3(2260.0, 34.0, -980.0),
	Vector3(2180.0, 16.0, 1880.0),
	Vector3(-420.0, 76.0, -2150.0),
]


func _init() -> void:
	call_deferred("_generate")


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIRECTORY))
	var height_map := Image.create_empty(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var control_map := Image.create_empty(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var min_height := INF
	var max_height := -INF

	for image_z in MAP_SIZE:
		for image_x in MAP_SIZE:
			var point := MAP_ORIGIN + Vector2(image_x, image_z) * VERTEX_SPACING
			var height := _terrain_height(point)
			height_map.set_pixel(image_x, image_z, Color(height, 0.0, 0.0, 1.0))
			control_map.set_pixel(image_x, image_z, _control_pixel(point, height))
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)

	var terrain := Terrain3D.new()
	terrain.name = "IslandTerrainGenerator"
	terrain.region_size = Terrain3D.SIZE_256
	terrain.vertex_spacing = VERTEX_SPACING
	root.add_child(terrain)
	terrain.data.import_images([height_map, control_map, null], Vector3(MAP_ORIGIN.x, 0.0, MAP_ORIGIN.y), 0.0, 1.0)
	terrain.data.save_directory(DATA_DIRECTORY)

	if not FileAccess.file_exists(DATA_DIRECTORY + "/assets.tres"):
		_fail("Falta terrain/data/assets.tres con los cinco tiles estilizados.")
		return
	if not FileAccess.file_exists(DATA_DIRECTORY + "/material.tres"):
		_fail("Falta terrain/data/material.tres.")
		return

	Terrain3DUtil.get_thumbnail(height_map, Vector2i(1024, 1024)).save_png("res://terrain/heightmap_preview.png")
	print("ISLAND TERRAIN GENERATED: %.2f..%.2f m, %.2f km² y %d rutas." % [min_height, max_height, WORLD_SIZE_METERS * WORLD_SIZE_METERS / 1000000.0, ROAD_NETWORK.size()])
	terrain.queue_free()
	quit(0)


func _terrain_height(point: Vector2) -> float:
	var rolling := sin(point.x * 0.0042 + point.y * 0.0017) * 5.5
	rolling += sin(point.y * 0.0061 - point.x * 0.0023) * 3.4
	rolling += sin((point.x + point.y) * 0.011) * 1.2
	var interior := 15.0 + rolling

	# Cordillera nevada septentrional, montañas occidentales y riscos orientales.
	interior += 245.0 * _gaussian(point, Vector2(250.0, -3020.0), Vector2(1050.0, 720.0))
	interior += 138.0 * _gaussian(point, Vector2(-3150.0, -850.0), Vector2(760.0, 1250.0))
	interior += 108.0 * _gaussian(point, Vector2(3120.0, -1280.0), Vector2(720.0, 1050.0))
	interior += 74.0 * _gaussian(point, Vector2(-400.0, -1800.0), Vector2(560.0, 720.0))

	# Dunas amplias: ondulación geométrica grande, nunca ruido PBR.
	var desert := _desert_strength(point)
	interior += desert * (sin(point.x * 0.009 + point.y * 0.004) * 7.0 + 4.0)

	# Mesetas estables para villas y castillos.
	for settlement in SETTLEMENTS:
		var center := Vector2(settlement.x, settlement.z)
		var flatten := 1.0 - smoothstep(105.0, 210.0, point.distance_to(center))
		interior = lerpf(interior, settlement.y, flatten * 0.92)

	var lookout_flatten := 1.0 - smoothstep(18.0, 38.0, point.distance_to(LOOKOUT))
	interior = lerpf(interior, 24.0, lookout_flatten)

	# Costa irregular: el terreno cruza el nivel del mar antes del límite físico.
	var normalized := Vector2(point.x / 4740.0, point.y / 4540.0)
	var coast_wobble := sin(atan2(normalized.y, normalized.x) * 7.0) * 0.018
	coast_wobble += sin(atan2(normalized.y, normalized.x) * 13.0 + 0.7) * 0.009
	var radial := normalized.length() + coast_wobble
	var land := 1.0 - smoothstep(0.865, 1.0, radial)
	return lerpf(-34.0, interior, land)


func _control_pixel(point: Vector2, height: float) -> Color:
	var base_texture := 0
	if _desert_strength(point) > 0.34:
		base_texture = 3
	elif _snow_strength(point, height) > 0.38:
		base_texture = 4
	elif _rock_strength(point, height) > 0.58:
		base_texture = 2

	var road_distance := distance_to_roads(point)
	var bits := Terrain3DUtil.enc_base(base_texture)
	# Sendero de 9-19 m en vez de una franja de 64 m: a la resolución low-poly
	# del terreno conserva un centro legible y permite que el bosque lo abrace.
	if road_distance < 19.0 and height > 0.5:
		var road_strength := 1.0 - smoothstep(4.5, 19.0, road_distance)
		bits |= Terrain3DUtil.enc_overlay(1)
		bits |= Terrain3DUtil.enc_blend(roundi(road_strength * 255.0))
	else:
		bits |= Terrain3DUtil.enc_overlay(base_texture)
		bits |= Terrain3DUtil.enc_blend(0)
	bits |= Terrain3DUtil.enc_auto(false)
	return Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)


func distance_to_roads(point: Vector2) -> float:
	var best := INF
	for road in ROAD_NETWORK:
		for index in range(road.size() - 1):
			best = minf(best, _distance_to_segment(point, road[index], road[index + 1]))
	return best


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)


func _desert_strength(point: Vector2) -> float:
	return _gaussian(point, Vector2(2350.0, 2050.0), Vector2(1250.0, 1050.0))


func _snow_strength(point: Vector2, height: float) -> float:
	var northern := _gaussian(point, Vector2(150.0, -3050.0), Vector2(1450.0, 1050.0))
	return northern * smoothstep(78.0, 175.0, height)


func _rock_strength(point: Vector2, height: float) -> float:
	var western := _gaussian(point, Vector2(-3150.0, -850.0), Vector2(900.0, 1450.0))
	var eastern := _gaussian(point, Vector2(3120.0, -1280.0), Vector2(860.0, 1300.0))
	return maxf(western, eastern) * smoothstep(48.0, 125.0, height)


func _gaussian(point: Vector2, center: Vector2, spread: Vector2) -> float:
	var offset := point - center
	return exp(-((offset.x * offset.x) / (2.0 * spread.x * spread.x) + (offset.y * offset.y) / (2.0 * spread.y * spread.y)))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
