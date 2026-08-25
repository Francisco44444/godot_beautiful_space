extends SceneTree

## Construye una isla low-poly asimétrica dentro de un mundo de 12 x 12 km. Los 2560² puntos del mapa de
## control permiten caminos continuos de pocos metros sin perder el LOD.

const MAP_SIZE := 2560
const WORLD_SIZE_METERS := 12000.0
const VERTEX_SPACING := WORLD_SIZE_METERS / float(MAP_SIZE)
const MAP_ORIGIN := Vector2(-WORLD_SIZE_METERS * 0.5, -WORLD_SIZE_METERS * 0.5)
const DATA_DIRECTORY := "res://terrain/data"
const LOOKOUT := Vector2(98.0, -110.0)
const COASTAL_CLIFF_TEXTURE_ID := 6
const COASTAL_CLIFF_SLOPE_DEGREES := 48.0
const EXTREME_CLIFF_SLOPE_DEGREES := 55.0

const ROAD_NETWORK: Array = [
	[Vector2(0, 190), Vector2(-120, 520), Vector2(-420, 760), Vector2(-980, 780), Vector2(-1450, 650)],
	[Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)],
	[Vector2(-1450, 650), Vector2(-1780, 230), Vector2(-2050, -420), Vector2(-2200, -900)],
	[Vector2(0, 190), Vector2(620, 320), Vector2(1260, 120), Vector2(1840, -420), Vector2(2260, -980)],
	[Vector2(620, 320), Vector2(1120, 820), Vector2(1660, 1320), Vector2(2180, 1880)],
	[Vector2(-1450, 650), Vector2(-1850, 1120), Vector2(-2180, 1650)],
	[Vector2(-420, -2150), Vector2(260, -2500), Vector2(720, -3080)],
	[Vector2(98, -110), Vector2(420, -420), Vector2(920, -560), Vector2(1840, -420)],
	# Bajada tallada en la meseta desértica: conecta el altiplano con la gruta
	# abierta del acantilado sin exigir saltos ni atravesar una pared vertical.
	[Vector2(2780, 1480), Vector2(3070, 1540), Vector2(3340, 1640), Vector2(3600, 1770), Vector2(3890, 1900)],
	# El sendero oriental atraviesa el cuello de la nueva península y se pierde
	# dentro del Bosque Tenebroso, futura región del enemigo final.
	[Vector2(2260, -980), Vector2(2860, -1120), Vector2(3480, -1320), Vector2(4140, -1260), Vector2(4920, -1080)],
]
const GROTTO_DESCENT: Array[Vector3] = [
	Vector3(2780.0, 116.0, 1480.0),
	Vector3(3070.0, 94.0, 1540.0),
	Vector3(3340.0, 68.0, 1640.0),
	Vector3(3600.0, 40.0, 1770.0),
	Vector3(3890.0, 15.0, 1900.0),
]
const RIA_CHANNELS: Array = [
	[Vector2(-4780, -2100), Vector2(-4420, -1950), Vector2(-4090, -1640), Vector2(-3720, -1510), Vector2(-3360, -1740)],
	[Vector2(-4780, 2250), Vector2(-4380, 2040), Vector2(-3990, 2200), Vector2(-3610, 1880), Vector2(-3220, 1960)],
	[Vector2(-2550, -4480), Vector2(-2390, -4100), Vector2(-2070, -3820), Vector2(-1760, -3520), Vector2(-1600, -3180)],
]
const CANYON_NETWORK: Array = [
	[Vector2(2760, 620), Vector2(3060, 850), Vector2(3240, 1160), Vector2(3470, 1430), Vector2(3760, 1690), Vector2(4140, 1980), Vector2(4320, 2420), Vector2(4230, 2860)],
	[Vector2(3240, 1160), Vector2(3560, 980), Vector2(3920, 810), Vector2(4250, 920)],
	[Vector2(3470, 1430), Vector2(3310, 1770), Vector2(3420, 2160), Vector2(3710, 2380), Vector2(3990, 2710)],
	[Vector2(3760, 1690), Vector2(4050, 1510), Vector2(4350, 1580)],
	[Vector2(3420, 2160), Vector2(3130, 2450), Vector2(3060, 2820), Vector2(3280, 3090)],
]
const SETTLEMENTS: Array[Vector3] = [
	Vector3(0.0, 12.0, 190.0),
	Vector3(-1450.0, 22.0, 650.0),
	Vector3(-2200.0, 20.0, -900.0),
	Vector3(2260.0, 34.0, -980.0),
	Vector3(2180.0, 16.0, 1880.0),
	Vector3(-420.0, 76.0, -2150.0),
]
const STONE_VILLAGES: Array[Vector3] = [
	Vector3(0.0, 190.0, 0.08), Vector3(-1450.0, 650.0, 0.42),
	Vector3(-2200.0, -900.0, -0.36), Vector3(2260.0, -980.0, 0.72),
	Vector3(2180.0, 1880.0, -0.25), Vector3(-420.0, -2150.0, 0.0),
]
const CASTLE_PLATEAUS: Array[Vector3] = [
	Vector3(-1336.0, 22.0, 703.0),
	Vector3(2352.0, 34.0, -895.0),
	Vector3(-295.0, 76.0, -2147.0),
]


func _init() -> void:
	call_deferred("_generate")


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIRECTORY))
	# Terrain3D reserializa también assets.tres al guardar alturas y puede añadir
	# normales/meshes internos por defecto. Conservamos los catálogos artísticos
	# byte a byte: esta herramienta solo debe sustituir altura y control.
	var preserved_catalogs: Dictionary[String, String] = {}
	for catalog_path in [DATA_DIRECTORY + "/assets.tres", DATA_DIRECTORY + "/material.tres"]:
		if FileAccess.file_exists(catalog_path):
			preserved_catalogs[catalog_path] = FileAccess.get_file_as_string(catalog_path)
	var height_map := Image.create_empty(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var control_map := Image.create_empty(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RF)
	var min_height := INF
	var max_height := -INF

	for image_z in MAP_SIZE:
		for image_x in MAP_SIZE:
			var point := MAP_ORIGIN + Vector2(image_x, image_z) * VERTEX_SPACING
			var height := _terrain_height(point)
			height_map.set_pixel(image_x, image_z, Color(height, 0.0, 0.0, 1.0))
			min_height = minf(min_height, height)
			max_height = maxf(max_height, height)

	# El material de un cantil depende de su pendiente real, no del bioma. Una
	# segunda pasada permite medir la derivada del heightmap ya completo y evita
	# pintar como roca las playas o las rampas que sí son transitables.
	for image_z in MAP_SIZE:
		for image_x in MAP_SIZE:
			var point := MAP_ORIGIN + Vector2(image_x, image_z) * VERTEX_SPACING
			var height := height_map.get_pixel(image_x, image_z).r
			var slope_degrees := _heightmap_slope_degrees(height_map, image_x, image_z)
			control_map.set_pixel(image_x, image_z, _control_pixel(point, height, slope_degrees))

	var terrain := Terrain3D.new()
	terrain.name = "IslandTerrainGenerator"
	terrain.region_size = Terrain3D.SIZE_256
	terrain.vertex_spacing = VERTEX_SPACING
	root.add_child(terrain)
	terrain.data.import_images([height_map, control_map, null], Vector3(MAP_ORIGIN.x, 0.0, MAP_ORIGIN.y), 0.0, 1.0)
	terrain.data.save_directory(DATA_DIRECTORY)
	for catalog_path in preserved_catalogs:
		var catalog := FileAccess.open(catalog_path, FileAccess.WRITE)
		if catalog != null:
			catalog.store_string(preserved_catalogs[catalog_path])

	if not FileAccess.file_exists(DATA_DIRECTORY + "/assets.tres"):
		_fail("Falta terrain/data/assets.tres con el catálogo de tiles estilizados.")
		return
	if not FileAccess.file_exists(DATA_DIRECTORY + "/material.tres"):
		_fail("Falta terrain/data/material.tres.")
		return

	Terrain3DUtil.get_thumbnail(height_map, Vector2i(1024, 1024)).save_png("res://terrain/heightmap_preview.png")
	print("ISLAND TERRAIN GENERATED: %.2f..%.2f m, %.2f km² y %d rutas." % [min_height, max_height, WORLD_SIZE_METERS * WORLD_SIZE_METERS / 1000000.0, ROAD_NETWORK.size()])
	terrain.queue_free()
	quit(0)


func _terrain_height(point: Vector2) -> float:
	# Ondulación continental a gran escala. Las frecuencias bajas dan lomas y
	# valles continuos, no pequeños círculos levantados como tubos sobre el suelo.
	var rolling := sin(point.x * 0.00155 + point.y * 0.00072) * 9.0
	rolling += sin(point.y * 0.00210 - point.x * 0.00083) * 6.0
	rolling += sin((point.x + point.y) * 0.00335) * 3.2
	rolling += sin(point.x * 0.0061 - point.y * 0.0044) * 1.4
	var interior := 18.0 + rolling

	# Cada región es una agrupación de volúmenes anchos y solapados. La suma
	# forma cordilleras, estribaciones, valles y rías con carácter atlántico.
	interior += _snow_massif_height(point)
	interior += _western_mountain_height(point)
	interior += _eastern_mountain_height(point)
	interior += _southern_highlands_height(point)
	interior += _central_ribera_height(point)
	interior += _galician_massifs_height(point)
	interior += _mystery_highlands_height(point)

	# Dunas amplias: ondulación geométrica grande, nunca ruido PBR.
	var desert := _desert_strength(point)
	interior += desert * (sin(point.x * 0.009 + point.y * 0.004) * 7.0 + 4.0)
	interior += _desert_escarpment_height(point)

	# Valles habitables de gran radio. Más de 400 m centrales son prácticamente
	# planos y la transición ocupa más de 600 m: las villas dejan de parecer
	# socavones circulares tallados dentro de una montaña.
	for settlement in SETTLEMENTS:
		var center := Vector2(settlement.x, settlement.z)
		var flatten := _settlement_valley_strength(point, center)
		interior = lerpf(interior, settlement.y, flatten)
	# Los castillos se desplazan fuera de la plaza de cada villa. Cada uno recibe
	# su propia meseta para que murallas, torres y accesos nazcan sobre terreno
	# estable en vez de quedar suspendidos sobre la ladera.
	for castle in CASTLE_PLATEAUS:
		var castle_center := Vector2(castle.x, castle.z)
		var castle_flatten := 1.0 - smoothstep(145.0, 250.0, point.distance_to(castle_center))
		interior = lerpf(interior, castle.y, castle_flatten)

	var lookout_flatten := 1.0 - smoothstep(18.0, 38.0, point.distance_to(LOOKOUT))
	interior = lerpf(interior, 24.0, lookout_flatten)

	# Costa irregular con una franja de playa continua antes de tocar el agua.
	var radial := _coast_radial(point)
	var land := 1.0 - smoothstep(0.865, 1.0, radial)
	# El techo de 500 m solo afecta a unos pocos metros alrededor de la cumbre;
	# el resto del macizo conserva perfiles redondeados y varias cimas visibles.
	var coastal_height := lerpf(-34.0, minf(interior, 500.0), land)
	var beach_band := smoothstep(0.825, 0.862, radial) * (1.0 - smoothstep(0.955, 0.985, radial))
	var beach_height := lerpf(13.0, -5.0, smoothstep(0.850, 0.965, radial))
	coastal_height = lerpf(coastal_height, beach_height, beach_band)
	# Las rías abren valles inundados entre macizos y conservan orillas suaves.
	coastal_height = _carve_rias(point, coastal_height)
	# El acantilado sureste es una fosa ramificada, no una única zanja. Sus
	# canales alcanzan casi -500 m y forman cruces y callejones de roca dorada.
	coastal_height = _carve_desert_fossa(point, coastal_height)
	# La garganta se talla después de formar la costa: sus cotas son las alturas
	# finales del sendero y el fundido litoral no puede volver a deformarlas.
	return clampf(_carve_grotto_descent(point, coastal_height), -500.0, 500.0)


func _control_pixel(point: Vector2, height: float, slope_degrees: float) -> Color:
	var base_texture := 0
	# Los desplomes costeros que superan la pendiente caminable y cualquier pared
	# interior casi vertical reciben la caliza clara. Tiene prioridad sobre arena
	# y bioma para que ninguna pared imposible vuelva a aparecer como hierba.
	if _is_extreme_cliff(point, height, slope_degrees):
		base_texture = COASTAL_CLIFF_TEXTURE_ID
	# Todas las costas emergidas y las orillas de las rías reciben arena antes
	# del agua, también en los biomas de nieve y bosque.
	elif _beach_strength(point, height) > 0.34:
		base_texture = 3
	# La fosa/acantilado mantiene la misma roca dorada low-poly del desierto.
	elif maxf(_desert_strength(point), _desert_cliff_strength(point)) > 0.34:
		base_texture = 3
	elif _mystery_forest_strength(point) > 0.36:
		base_texture = 2
	elif _snow_strength(point, height) > 0.38:
		base_texture = 4
	elif _rock_strength(point, height) > 0.58:
		base_texture = 2

	var road_info := nearest_road(point)
	var road_distance := road_info.x
	var stone_street_strength := _stone_village_street_strength(point)
	var dirt_road_strength := 0.0
	if road_distance < 9.0 and height > 0.5:
		dirt_road_strength = 1.0 - smoothstep(3.6, 9.0, road_distance)
	var bits := Terrain3DUtil.enc_base(base_texture)
	# La roca compactada sustituye el material base, nunca se coloca como una
	# malla por encima. Solo aparece en dos calles cortas entre las casas de cada
	# villa grande; toda la red insular exterior continúa siendo de tierra.
	# Dentro de la huella urbana manda la piedra, pero hereda la cobertura sólida
	# del camino entrante. La tierra termina limpia en el borde del adoquín sin
	# lenguas naranjas ni un hueco de hierba entre ambos materiales.
	if stone_street_strength > 0.0 and height > 0.5:
		var street_coverage := maxf(stone_street_strength, dirt_road_strength)
		bits |= Terrain3DUtil.enc_overlay(5)
		bits |= Terrain3DUtil.enc_blend(roundi(street_coverage * 255.0))
	elif dirt_road_strength > 0.0:
		bits |= Terrain3DUtil.enc_overlay(1)
		bits |= Terrain3DUtil.enc_blend(roundi(dirt_road_strength * 255.0))
	else:
		bits |= Terrain3DUtil.enc_overlay(base_texture)
		bits |= Terrain3DUtil.enc_blend(0)
	bits |= Terrain3DUtil.enc_auto(false)
	return Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)


func _heightmap_slope_degrees(height_map: Image, image_x: int, image_z: int) -> float:
	var left := maxi(image_x - 1, 0)
	var right := mini(image_x + 1, MAP_SIZE - 1)
	var back := maxi(image_z - 1, 0)
	var forward := mini(image_z + 1, MAP_SIZE - 1)
	var span_x := maxf(float(right - left) * VERTEX_SPACING, VERTEX_SPACING)
	var span_z := maxf(float(forward - back) * VERTEX_SPACING, VERTEX_SPACING)
	var grade_x := (height_map.get_pixel(right, image_z).r - height_map.get_pixel(left, image_z).r) / span_x
	var grade_z := (height_map.get_pixel(image_x, forward).r - height_map.get_pixel(image_x, back).r) / span_z
	return rad_to_deg(atan(sqrt(grade_x * grade_x + grade_z * grade_z)))


func _is_extreme_cliff(point: Vector2, height: float, slope_degrees: float) -> bool:
	if height < 7.0 or slope_degrees < COASTAL_CLIFF_SLOPE_DEGREES:
		return false
	# Una pared casi vertical nunca puede seguir siendo verde aunque aparezca en
	# el interior de la isla. El umbral más alto conserva las laderas normales.
	if slope_degrees >= EXTREME_CLIFF_SLOPE_DEGREES:
		return true
	var radial := _coast_radial(point)
	var outer_coast := radial >= 0.79 and radial <= 0.985
	var ria_wall := false
	if point.x < -3000.0 or (point.x < -1250.0 and point.y < -2950.0):
		ria_wall = _nearest_network_point(point, RIA_CHANNELS).x < 300.0
	return outer_coast or ria_wall


func _stone_village_street_strength(point: Vector2) -> float:
	var best_strength := 0.0
	for village in STONE_VILLAGES:
		var center := Vector2(village.x, village.y)
		var local := (point - center).rotated(-village.z)
		var main_distance := _distance_to_segment(local, Vector2(0.0, -58.0), Vector2(0.0, 64.0))
		var cross_distance := _distance_to_segment(local, Vector2(-58.0, 0.0), Vector2(58.0, 0.0))
		var distance := minf(main_distance, cross_distance)
		best_strength = maxf(best_strength, 1.0 - smoothstep(3.4, 9.0, distance))
	return best_strength


func _settlement_valley_strength(point: Vector2, center: Vector2) -> float:
	var local := point - center
	# Cada valle adopta una orientación distinta y una silueta suavemente
	# irregular. El radio útil equivale a varias plazas de pueblo, no a un pincel.
	var orientation := center.angle() * 0.37 + center.x * 0.00021
	local = local.rotated(-orientation)
	var ellipse_distance := Vector2(local.x / 1.24, local.y / 0.86).length()
	var angle := atan2(local.y, local.x)
	var organic_edge := sin(angle * 3.0 + center.y * 0.0013) * 46.0
	organic_edge += sin(angle * 5.0 - center.x * 0.0009) * 24.0
	return 1.0 - smoothstep(410.0, 1080.0, ellipse_distance + organic_edge)


func distance_to_roads(point: Vector2) -> float:
	return nearest_road(point).x


func nearest_road(point: Vector2) -> Vector2:
	var best := INF
	var best_index := -1
	for road_index in ROAD_NETWORK.size():
		var road: Array = ROAD_NETWORK[road_index]
		for index in range(road.size() - 1):
			var distance := _distance_to_segment(point, road[index], road[index + 1])
			if distance < best:
				best = distance
				best_index = road_index
	return Vector2(best, best_index)


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)


func _desert_strength(point: Vector2) -> float:
	# El desierto es una franja irregular que nace en las dunas, rodea la fosa y
	# termina contra la costa sureste. La superposición evita cualquier círculo.
	var core := _gaussian(point, Vector2(2400.0, 2050.0), Vector2(1450.0, 1120.0))
	var coast := _gaussian(point, Vector2(4380.0, 2500.0), Vector2(1550.0, 1180.0))
	var southern_tongue := _gaussian(point, Vector2(2450.0, 3550.0), Vector2(1750.0, 760.0))
	var irregularity := 0.88 + sin(point.x * 0.0019 + point.y * 0.0031) * 0.10
	irregularity += sin(point.x * 0.0042 - point.y * 0.0013) * 0.06
	return clampf(maxf(core, maxf(coast * 0.96, southern_tongue * 0.78)) * irregularity, 0.0, 1.0)


func _snow_massif_height(point: Vector2) -> float:
	# El piedemonte comienza suavemente al norte de la villa boreal y desemboca
	# en un macizo de casi 500 m. Las cimas laterales evitan la silueta de cono.
	var foothills := 165.0 * _gaussian(point, Vector2(100.0, -2700.0), Vector2(1500.0, 1150.0))
	# 258 m sitúan la cima natural prácticamente en 500 m; el límite superior
	# deja de producir una meseta blanca plana alrededor del punto más alto.
	var central_peak := 258.0 * _gaussian(point, Vector2(180.0, -3350.0), Vector2(760.0, 600.0))
	var western_peak := 70.0 * _gaussian(point, Vector2(-520.0, -3380.0), Vector2(620.0, 540.0))
	var eastern_peak := 72.0 * _gaussian(point, Vector2(760.0, -3500.0), Vector2(660.0, 500.0))
	var northern_ridge := 48.0 * _gaussian(point, Vector2(-80.0, -3820.0), Vector2(1050.0, 420.0))
	var massif_mask := _gaussian(point, Vector2(120.0, -3300.0), Vector2(1650.0, 1200.0))
	var rock_fold := massif_mask * (
		sin(point.x * 0.0047 + point.y * 0.0018) * 8.0
		+ sin(point.x * 0.0022 - point.y * 0.0041) * 5.0
	)
	return foothills + central_peak + western_peak + eastern_peak + northern_ridge + rock_fold


func _western_mountain_height(point: Vector2) -> float:
	var range_height := 142.0 * _gaussian(point, Vector2(-3160.0, -780.0), Vector2(900.0, 1370.0))
	range_height += 82.0 * _gaussian(point, Vector2(-3570.0, -1750.0), Vector2(720.0, 850.0))
	range_height += 68.0 * _gaussian(point, Vector2(-2720.0, 300.0), Vector2(930.0, 700.0))
	var mask := _gaussian(point, Vector2(-3150.0, -800.0), Vector2(1450.0, 1900.0))
	return range_height + mask * (sin(point.x * 0.0038 - point.y * 0.0017) * 7.0)


func _eastern_mountain_height(point: Vector2) -> float:
	var range_height := 126.0 * _gaussian(point, Vector2(3140.0, -1320.0), Vector2(910.0, 1220.0))
	range_height += 74.0 * _gaussian(point, Vector2(3650.0, -300.0), Vector2(720.0, 760.0))
	range_height += 62.0 * _gaussian(point, Vector2(2700.0, -2350.0), Vector2(790.0, 740.0))
	var mask := _gaussian(point, Vector2(3150.0, -1250.0), Vector2(1500.0, 1800.0))
	return range_height + mask * (sin(point.x * 0.0031 + point.y * 0.0024) * 6.5)


func _southern_highlands_height(point: Vector2) -> float:
	# Páramos amplios al suroeste, con cimas suaves y laderas cultivables.
	var highlands := 82.0 * _gaussian(point, Vector2(-2650.0, 2150.0), Vector2(1450.0, 900.0))
	highlands += 52.0 * _gaussian(point, Vector2(-3650.0, 2500.0), Vector2(850.0, 650.0))
	highlands += 45.0 * _gaussian(point, Vector2(-1750.0, 2850.0), Vector2(950.0, 620.0))
	return highlands


func _central_ribera_height(point: Vector2) -> float:
	# Dos lomos largos crean el valle central y rompen la planicie sin encerrar
	# los pueblos en paredes abruptas.
	var north_bank := 55.0 * _gaussian(point, Vector2(-650.0, -900.0), Vector2(1750.0, 620.0))
	var south_bank := 48.0 * _gaussian(point, Vector2(450.0, 1350.0), Vector2(1850.0, 690.0))
	var eastern_bank := 36.0 * _gaussian(point, Vector2(1750.0, 650.0), Vector2(1050.0, 620.0))
	return north_bank + south_bank + eastern_bank


func _galician_massifs_height(point: Vector2) -> float:
	# Macizos de escala regional: cada núcleo ocupa alrededor de una aldea y se
	# solapa con cimas vecinas para formar cordilleras, collados y valles largos.
	var northwest := 228.0 * _gaussian(point, Vector2(-2850.0, -2200.0), Vector2(980.0, 820.0))
	northwest += 158.0 * _gaussian(point, Vector2(-3450.0, -1600.0), Vector2(760.0, 680.0))
	northwest += 132.0 * _gaussian(point, Vector2(-2300.0, -3380.0), Vector2(800.0, 620.0))
	var east_chain := 218.0 * _gaussian(point, Vector2(2700.0, -2350.0), Vector2(980.0, 820.0))
	east_chain += 164.0 * _gaussian(point, Vector2(3400.0, -1600.0), Vector2(760.0, 700.0))
	var southern_range := 252.0 * _gaussian(point, Vector2(-980.0, 2940.0), Vector2(1120.0, 790.0))
	southern_range += 162.0 * _gaussian(point, Vector2(80.0, 3420.0), Vector2(880.0, 600.0))
	southern_range += 128.0 * _gaussian(point, Vector2(-2050.0, 3290.0), Vector2(850.0, 620.0))
	var inner_range := 176.0 * _gaussian(point, Vector2(980.0, -1650.0), Vector2(1000.0, 720.0))
	var fold_mask := maxf(
		_gaussian(point, Vector2(-2800.0, -2200.0), Vector2(1700.0, 1300.0)),
		_gaussian(point, Vector2(-700.0, 3000.0), Vector2(1900.0, 1100.0))
	)
	var folds := fold_mask * (
		sin(point.x * 0.0035 + point.y * 0.0019) * 10.0
		+ sin(point.x * 0.0018 - point.y * 0.0042) * 6.0
	)
	return northwest + east_chain + southern_range + inner_range + folds


func _mystery_highlands_height(point: Vector2) -> float:
	# La prolongación oriental asciende en lomos amplios cubiertos de bosque. Las
	# cimas rozan la capa baja de nubes sin convertirse en conos independientes.
	var highlands := 142.0 * _gaussian(point, Vector2(4220.0, -1320.0), Vector2(1320.0, 980.0))
	highlands += 92.0 * _gaussian(point, Vector2(5030.0, -1780.0), Vector2(880.0, 760.0))
	highlands += 68.0 * _gaussian(point, Vector2(3920.0, -2450.0), Vector2(980.0, 720.0))
	var mask := _mystery_forest_strength(point)
	return highlands + mask * (sin(point.x * 0.0041 - point.y * 0.0022) * 7.0)


func _desert_escarpment_height(point: Vector2) -> float:
	var desert_mask := _gaussian(point, Vector2(3150.0, 1800.0), Vector2(1450.0, 1250.0))
	var cliff_line := 3470.0 + sin((point.y - 1700.0) * 0.0018) * 170.0
	var inland_plateau := 1.0 - smoothstep(cliff_line - 190.0, cliff_line + 150.0, point.x)
	var plateau := 98.0 * desert_mask * inland_plateau
	var mesas := 38.0 * _gaussian(point, Vector2(2880.0, 2600.0), Vector2(760.0, 520.0))
	mesas += 26.0 * _gaussian(point, Vector2(2450.0, 3150.0), Vector2(920.0, 520.0))
	return plateau + mesas


func _desert_cliff_strength(point: Vector2) -> float:
	var cliff_mask := _gaussian(point, Vector2(3350.0, 1800.0), Vector2(1350.0, 1250.0))
	var cliff_line := 3470.0 + sin((point.y - 1700.0) * 0.0018) * 170.0
	var edge := 1.0 - smoothstep(260.0, 760.0, absf(point.x - cliff_line))
	var canyon := 0.0
	var canyon_distance := _canyon_distance(point)
	if canyon_distance < INF:
		canyon = 1.0 - smoothstep(230.0, 390.0, canyon_distance)
	# Incluye la garganta, las cinco ramas y ambas caras visibles del cantil.
	return maxf(cliff_mask * lerpf(0.42, 1.0, edge), canyon)


func _coast_radial(point: Vector2) -> float:
	var angle := atan2(point.y, point.x)
	var cosine := cos(angle)
	var sine := sin(angle)
	var ellipse_radius := 1.0 / sqrt((cosine * cosine) / (4740.0 * 4740.0) + (sine * sine) / (4540.0 * 4540.0))
	var mystery_angle := atan2(sin(angle + 0.27), cos(angle + 0.27))
	var mystery_peninsula := 1200.0 * exp(-(mystery_angle * mystery_angle) / (2.0 * 0.27 * 0.27))
	var desert_angle := atan2(sin(angle - 0.50), cos(angle - 0.50))
	var desert_shoulder := 420.0 * exp(-(desert_angle * desert_angle) / (2.0 * 0.32 * 0.32))
	var north_neck_angle := atan2(sin(angle + 0.82), cos(angle + 0.82))
	var north_inlet := 350.0 * exp(-(north_neck_angle * north_neck_angle) / (2.0 * 0.20 * 0.20))
	var south_neck_angle := atan2(sin(angle - 0.04), cos(angle - 0.04))
	var south_inlet := 430.0 * exp(-(south_neck_angle * south_neck_angle) / (2.0 * 0.18 * 0.18))
	var coast_wobble := sin(angle * 7.0) * 0.018
	coast_wobble += sin(angle * 13.0 + 0.7) * 0.009
	return point.length() / (ellipse_radius + mystery_peninsula + desert_shoulder - north_inlet - south_inlet) + coast_wobble


func _beach_strength(point: Vector2, height: float) -> float:
	var radial := _coast_radial(point)
	var perimeter := 0.0
	if height < 42.0:
		perimeter = smoothstep(0.815, 0.850, radial) * (1.0 - smoothstep(0.965, 0.995, radial))
	var ria_bank := 0.0
	if point.x < -3000.0 or (point.x < -1250.0 and point.y < -2950.0):
		var ria_info := _nearest_network_point(point, RIA_CHANNELS)
		if ria_info.x < 250.0 and height < 42.0:
			ria_bank = 1.0 - smoothstep(75.0, 250.0, ria_info.x)
	return maxf(perimeter, ria_bank)


func _carve_rias(point: Vector2, original_height: float) -> float:
	if point.x > -3000.0 and not (point.x < -1250.0 and point.y < -2950.0):
		return original_height
	var nearest := _nearest_network_point(point, RIA_CHANNELS)
	if nearest.x > 340.0:
		return original_height
	# El fondo queda entre bajamar y pleamar: las cabeceras se vacían y vuelven
	# a llenarse, mientras la desembocadura conserva siempre un canal de agua.
	var target_height := lerpf(-2.65, 1.20, nearest.y)
	var shoulder := 1.0 - smoothstep(88.0, 340.0, nearest.x)
	var shoulder_target := target_height + 18.0 + nearest.x * 0.075
	var carved := lerpf(original_height, minf(original_height, shoulder_target), shoulder * 0.88)
	var water_channel := 1.0 - smoothstep(34.0, 92.0, nearest.x)
	return lerpf(carved, target_height, water_channel)


func _carve_desert_fossa(point: Vector2, original_height: float) -> float:
	var distance := _canyon_distance(point)
	if distance == INF or distance > 350.0:
		return original_height
	var outer_wall := 1.0 - smoothstep(140.0, 350.0, distance)
	var inner_wall := 1.0 - smoothstep(62.0, 150.0, distance)
	var abyss := 1.0 - smoothstep(22.0, 60.0, distance)
	var carved := lerpf(original_height, minf(original_height, -78.0), outer_wall * 0.72)
	carved = lerpf(carved, minf(carved, -310.0), inner_wall * 0.92)
	var bottom := -484.0 + sin(point.x * 0.012 + point.y * 0.008) * 12.0
	return lerpf(carved, bottom, abyss)


func _canyon_distance(point: Vector2) -> float:
	if point.x < 2520.0 or point.y < 300.0 or point.y > 3340.0:
		return INF
	return _nearest_network_point(point, CANYON_NETWORK).x


func _nearest_network_point(point: Vector2, network: Array) -> Vector2:
	var best_distance := INF
	var best_progress := 0.0
	for channel in network:
		var segment_count: int = channel.size() - 1
		for index in range(segment_count):
			var start: Vector2 = channel[index]
			var finish: Vector2 = channel[index + 1]
			var segment := finish - start
			var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
			var distance := point.distance_to(start + segment * progress)
			if distance < best_distance:
				best_distance = distance
				best_progress = (float(index) + progress) / float(segment_count)
	return Vector2(best_distance, best_progress)


func _carve_grotto_descent(point: Vector2, original_height: float) -> float:
	var best_distance := INF
	var target_height := original_height
	for index in range(GROTTO_DESCENT.size() - 1):
		var start3 := GROTTO_DESCENT[index]
		var finish3 := GROTTO_DESCENT[index + 1]
		var start := Vector2(start3.x, start3.z)
		var finish := Vector2(finish3.x, finish3.z)
		var segment := finish - start
		var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var distance := point.distance_to(start + segment * progress)
		if distance < best_distance:
			best_distance = distance
			target_height = lerpf(start3.y, finish3.y, progress)
	# Primero abre una vaguada de 300 m con hombros suaves; dentro queda una
	# senda firme de unos 50 m. Así la bajada se lee como valle erosionado y no
	# como una pincelada estrecha hundida en el terreno.
	var shoulder := 1.0 - smoothstep(82.0, 330.0, best_distance)
	var shoulder_target := target_height + 42.0 + best_distance * 0.14
	var carved_height := lerpf(original_height, minf(original_height, shoulder_target), shoulder * 0.72)
	var corridor := 1.0 - smoothstep(26.0, 92.0, best_distance)
	return lerpf(carved_height, target_height, corridor)


func _snow_strength(point: Vector2, height: float) -> float:
	var northern := _gaussian(point, Vector2(150.0, -3400.0), Vector2(1650.0, 1250.0))
	var western_ridge := _gaussian(point, Vector2(-1050.0, -4070.0), Vector2(1250.0, 660.0))
	var eastern_ridge := _gaussian(point, Vector2(1320.0, -4210.0), Vector2(1420.0, 620.0))
	var irregularity := 0.86 + sin(point.x * 0.0027 + point.y * 0.0018) * 0.12
	return clampf(maxf(northern, maxf(western_ridge * 0.70, eastern_ridge * 0.66)) * irregularity, 0.0, 1.0) * smoothstep(90.0, 260.0, height)


func _mystery_forest_strength(point: Vector2) -> float:
	var core := _gaussian(point, Vector2(4380.0, -1320.0), Vector2(1420.0, 1080.0))
	var north_reach := _gaussian(point, Vector2(3950.0, -2550.0), Vector2(1180.0, 780.0))
	var coastal_reach := _gaussian(point, Vector2(5200.0, -620.0), Vector2(820.0, 980.0))
	var veins := 0.86 + sin(point.x * 0.0034 + point.y * 0.0021) * 0.11
	veins += sin(point.x * 0.0017 - point.y * 0.0043) * 0.07
	return clampf(maxf(core, maxf(north_reach * 0.82, coastal_reach * 0.88)) * veins, 0.0, 1.0)


func _rock_strength(point: Vector2, height: float) -> float:
	var western := _gaussian(point, Vector2(-3150.0, -850.0), Vector2(900.0, 1450.0))
	var eastern := _gaussian(point, Vector2(3120.0, -1280.0), Vector2(860.0, 1300.0))
	var northwest := _gaussian(point, Vector2(-3000.0, -2750.0), Vector2(1250.0, 1000.0))
	var southern := _gaussian(point, Vector2(-850.0, 3000.0), Vector2(1500.0, 900.0))
	var mystery := _mystery_forest_strength(point) * 0.82
	return maxf(maxf(maxf(western, eastern), maxf(northwest, southern)), mystery) * smoothstep(70.0, 210.0, height)


func _gaussian(point: Vector2, center: Vector2, spread: Vector2) -> float:
	var offset := point - center
	return exp(-((offset.x * offset.x) / (2.0 * spread.x * spread.x) + (offset.y * offset.y) / (2.0 * spread.y * spread.y)))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
