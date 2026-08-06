extends SceneTree

## Genera de forma determinista el terreno de la Fase 2.
## Se ejecuta una sola vez en desarrollo; el juego carga después los `.res`
## guardados en `terrain/data`, no recalcula el mapa en cada arranque.

const MAP_SIZE := 512
const MAP_ORIGIN := Vector2(-256.0, -256.0)
const DATA_DIRECTORY := "res://terrain/data"
const LOOKOUT := Vector2(98.0, -110.0)

const TRAIL_POINTS: Array[Vector3] = [
	Vector3(0.0, 2.0, 190.0),
	Vector3(-4.0, 2.2, 95.0),
	Vector3(7.0, 2.8, 25.0),
	Vector3(22.0, 4.5, -25.0),
	Vector3(43.0, 9.0, -58.0),
	Vector3(69.0, 16.0, -86.0),
	Vector3(98.0, 24.0, -110.0),
]


func _init() -> void:
	call_deferred("_generate")


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIRECTORY))

	var height_map := Image.create_empty(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var control_map := Image.create_empty(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var min_height := INF
	var max_height := -INF

	for image_z in range(MAP_SIZE):
		for image_x in range(MAP_SIZE):
			var world_point := MAP_ORIGIN + Vector2(image_x, image_z)
			var trail_sample := _sample_trail(world_point)
			var height := _terrain_height(world_point, trail_sample)
			height_map.set_pixel(image_x, image_z, Color(height, 0.0, 0.0, 1.0))
			control_map.set_pixel(image_x, image_z, _control_pixel(trail_sample.y))
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)

	var terrain := Terrain3D.new()
	terrain.name = "TerrainGenerator"
	terrain.region_size = Terrain3D.SIZE_256
	root.add_child(terrain)
	terrain.data.import_images(
		[height_map, control_map, null],
		Vector3(MAP_ORIGIN.x, 0.0, MAP_ORIGIN.y),
		0.0,
		1.0
	)
	terrain.data.save_directory(DATA_DIRECTORY)

	# El generador solo sustituye relieve y mapa de control. Los tiles estilizados
	# mantenidos en assets.tres/material.tres no se pisan al regenerar el valle.
	if not FileAccess.file_exists(DATA_DIRECTORY + "/assets.tres"):
		_fail("Falta terrain/data/assets.tres con los tiles estilizados de Terrain3D.")
		return
	if not FileAccess.file_exists(DATA_DIRECTORY + "/material.tres"):
		_fail("Falta terrain/data/material.tres.")
		return

	var preview := Terrain3DUtil.get_thumbnail(height_map, Vector2i(512, 512))
	preview.save_png("res://terrain/heightmap_preview.png")

	print("TERRAIN GENERATED: %.2f m..%.2f m, valle, sendero y mirador." % [min_height, max_height])
	terrain.queue_free()
	quit(0)


func _terrain_height(point: Vector2, trail_sample: Vector2) -> float:
	var absolute_x := absf(point.x)
	# Dos laderas amplias dejan un valle norte-sur cómodo de recorrer.
	var side_ridges := 24.0 * pow(clampf((absolute_x - 24.0) / 190.0, 0.0, 1.0), 1.35)
	var western_hill := 12.0 * _gaussian(point, Vector2(-112.0, -72.0), Vector2(78.0, 96.0))
	var eastern_hill := 15.5 * _gaussian(point, LOOKOUT, Vector2(74.0, 82.0))
	var northern_hills := 9.0 * _gaussian(point, Vector2(18.0, -205.0), Vector2(155.0, 60.0))
	var southern_hills := 6.5 * _gaussian(point, Vector2(-70.0, 215.0), Vector2(140.0, 70.0))
	var rolling := sin(point.x * 0.032 + point.y * 0.011) * 0.75
	rolling += sin(point.y * 0.046 - point.x * 0.008) * 0.48
	var height := 2.25 + side_ridges + western_hill + eastern_hill + northern_hills + southern_hills + rolling

	# El sendero aplana y suaviza el ascenso. trail_sample.x es la altura
	# deseada y trail_sample.y la distancia al eje del sendero.
	var trail_strength := 1.0 - smoothstep(5.5, 16.0, trail_sample.y)
	height = lerpf(height, trail_sample.x, trail_strength * 0.9)

	# La cima se convierte en una pequeña meseta estable para el mirador.
	var lookout_distance := point.distance_to(LOOKOUT)
	var plateau_strength := 1.0 - smoothstep(14.0, 27.0, lookout_distance)
	height = lerpf(height, 24.0, plateau_strength)

	# Levantamos suavemente los límites para enmarcar la vista y hacer legible
	# dónde termina este prototipo de 512 metros.
	var edge := maxf(absf(point.x), absf(point.y))
	height += pow(smoothstep(218.0, 256.0, edge), 2.0) * 10.0
	return height


func _sample_trail(point: Vector2) -> Vector2:
	var best_distance := INF
	var best_height := TRAIL_POINTS[0].y
	for index in range(TRAIL_POINTS.size() - 1):
		var start := Vector2(TRAIL_POINTS[index].x, TRAIL_POINTS[index].z)
		var finish := Vector2(TRAIL_POINTS[index + 1].x, TRAIL_POINTS[index + 1].z)
		var segment := finish - start
		var segment_length_squared := segment.length_squared()
		var progress := 0.0
		if segment_length_squared > 0.0:
			progress = clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest := start + segment * progress
		var distance := point.distance_to(closest)
		if distance < best_distance:
			best_distance = distance
			best_height = lerpf(TRAIL_POINTS[index].y, TRAIL_POINTS[index + 1].y, progress)
	return Vector2(best_height, best_distance)


func _control_pixel(distance_to_trail: float) -> Color:
	var bits: int
	if distance_to_trail < 4.8:
		var dirt_strength := 1.0 - smoothstep(1.7, 4.8, distance_to_trail)
		bits = Terrain3DUtil.enc_base(0)
		bits |= Terrain3DUtil.enc_overlay(1)
		bits |= Terrain3DUtil.enc_blend(roundi(dirt_strength * 255.0))
		bits |= Terrain3DUtil.enc_auto(false)
	else:
		bits = Terrain3DUtil.enc_base(0)
		bits |= Terrain3DUtil.enc_overlay(2)
		# Las laderas cercanas conservan la pradera húmeda. El antiguo modo
		# automático interpretaba casi toda la cuenca como roca clara y borraba
		# visualmente el tapiz verde; los riscos del fondo ya usan mallas estilizadas.
		bits |= Terrain3DUtil.enc_blend(0)
		bits |= Terrain3DUtil.enc_auto(false)
	return Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)


func _gaussian(point: Vector2, center: Vector2, spread: Vector2) -> float:
	var offset := point - center
	return exp(-(
		(offset.x * offset.x) / (2.0 * spread.x * spread.x)
		+ (offset.y * offset.y) / (2.0 * spread.y * spread.y)
	))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
