extends SceneTree

## Comprueba que el valle Quaternius sea determinista, esté dividido en celdas
## y no invada el sendero jugable. También valida personajes y caballo.

const EXPECTED_TREE_COUNT := 80000
const EXPECTED_ROCK_COUNT := 504
const EXPECTED_MOSS_ROCK_COUNT := 0
const EXPECTED_CACTUS_COUNT := 173
const EXPECTED_MYSTERY_DEAD_TREE_COUNT := 4200
const EXPECTED_GRASS_COUNT := 220000
const EXPECTED_GRASS_CLUMPS_PER_PATCH := 1550
const MAX_GRASS_FULL_TRIANGLES_PER_PATCH := 6300
const MAX_GRASS_MID_TRIANGLES_PER_PATCH := 910
const MAX_GRASS_LOD_TRIANGLES_PER_PATCH := 410
const EXPECTED_FERN_COUNT := 10000
const EXPECTED_SHRUB_COUNT := 10000
const EXPECTED_FLOWER_COUNT := 8000
const EXPECTED_MUSHROOM_COUNT := 2200
const EXPECTED_PATH_PEBBLE_COUNT := 12000
const EXPECTED_CHARACTER_COUNT := 50
const MIN_EXPECTED_CELL_COUNT := 2800
const ROAD_NETWORK: Array = [
	[Vector2(0, 190), Vector2(-120, 520), Vector2(-420, 760), Vector2(-980, 780), Vector2(-1450, 650)],
	[Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)],
	[Vector2(-1450, 650), Vector2(-1780, 230), Vector2(-2050, -420), Vector2(-2200, -900)],
	[Vector2(0, 190), Vector2(620, 320), Vector2(1260, 120), Vector2(1840, -420), Vector2(2260, -980)],
	[Vector2(620, 320), Vector2(1120, 820), Vector2(1660, 1320), Vector2(2180, 1880)],
	[Vector2(-1450, 650), Vector2(-1850, 1120), Vector2(-2180, 1650)],
	[Vector2(-420, -2150), Vector2(260, -2500), Vector2(720, -3080)],
	[Vector2(98, -110), Vector2(420, -420), Vector2(920, -560), Vector2(1840, -420)],
	[Vector2(2780, 1480), Vector2(3070, 1540), Vector2(3340, 1640), Vector2(3600, 1770), Vector2(3890, 1900)],
	[Vector2(2260, -980), Vector2(2860, -1120), Vector2(3480, -1320), Vector2(4140, -1260), Vector2(4920, -1080)],
]


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var game_settings := root.get_node_or_null("GameSettings")
	if game_settings != null:
		game_settings.call("reset_defaults", false)
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := scene.instantiate()
	root.add_child(world)
	var scatter := world.get_node("VegetationScatter") as VegetationScatter
	var terrain := world.get_node("Terrain3D") as Terrain3D
	var player := world.get_node("Player") as Player
	var horse := world.get_node("Horse") as Horse
	var clouds := world.get_node_or_null("AnimatedClouds") as Node3D
	var wildlife := world.get_node_or_null("QuaterniusWildlife") as Node3D
	var medieval_set := world.get_node_or_null("MedievalSetDressing") as MedievalSetDressing

	# La distribución es estática; sólo la ventana GPU cercana y el fundido LOD
	# se actualizan después de que exista una cámara activa.
	for _frame in range(4):
		await process_frame
	var vegetation_cache := load("res://generated/vegetation_layout_cache.res") as VegetationLayoutCache
	if vegetation_cache == null or vegetation_cache.schema_version != 4 or "scale=2.20-4.00" not in vegetation_cache.signature:
		_fail("La caché de vegetación no contiene la escala equilibrada de los árboles.")
		return
	if vegetation_cache != null and vegetation_cache.grass_records.size() >= 3:
		scatter.call(
			"_update_grass_near_field",
			Vector2(vegetation_cache.grass_records[0], vegetation_cache.grass_records[2]),
			true
		)

	if wildlife == null or int(wildlife.get("generated_animal_count")) < 6:
		_fail("El valle debe cargar fauna Quaternius desde el pack de animales.")
		return
	if int(wildlife.get("reactive_animal_count")) != int(wildlife.get("generated_animal_count")):
		_fail("Toda la fauna colocada debe reaccionar cuando detecta al jugador.")
		return
	if medieval_set == null or medieval_set.generated_village_count < 6 or medieval_set.generated_hamlet_count < 8 or medieval_set.generated_house_count < 54 or medieval_set.generated_castle_count < 3:
		_fail("La isla debe incluir seis villas, ocho caseríos, cincuenta y cuatro casas y tres castillos.")
		return
	var character_directory := DirAccess.open("res://assets/quaternius/ultimate_animated_characters/glTF")
	if character_directory == null:
		_fail("Falta la biblioteca completa de personajes Quaternius.")
		return
	var character_count := 0
	for file_name in character_directory.get_files():
		if file_name.get_extension().to_lower() == "gltf":
			character_count += 1
	if character_count != EXPECTED_CHARACTER_COUNT:
		_fail("La biblioteca debería contener %d personajes glTF; contiene %d." % [EXPECTED_CHARACTER_COUNT, character_count])
		return

	if clouds == null:
		_fail("Falta el sistema de nubes procedurales.")
		return
	if (
		bool(clouds.get_meta("illustrated_billboards", true))
		or not bool(clouds.get_meta("drawn_clouds_disabled", false))
		or not bool(clouds.get_meta("procedural_clouds_only", false))
		or not bool(clouds.get_meta("distributed_cloud_banks", false))
		or not bool(clouds.get_meta("clear_sky_gaps", false))
		or int(clouds.get_meta("depth_band_count", 0)) != 1
		or not bool(clouds.get_meta("procedural_diffuse_veil", false))
		or bool(clouds.get_meta("hybrid_cloud_system", true))
	):
		_fail("Las nubes no declaran bancos procedurales con huecos despejados.")
		return
	for legacy_name in [
		"MovingCloudDome",
		"CloudLayer01",
		"CloudLayer02",
		"CloudLayer03",
		"ShadowCumulus",
		"DistantCumulus",
	]:
		if clouds.get_node_or_null(legacy_name) != null:
			_fail("El cielo conserva el nodo de nubes antiguo %s." % legacy_name)
			return
	for removed_cloud_name in [
		"IllustratedCloudNear",
		"IllustratedCloudMid",
		"IllustratedCloudHorizon",
		"CloudShadowMasks",
	]:
		if clouds.get_node_or_null(removed_cloud_name) != null:
			_fail("Se reactivó una capa de nubes dibujadas: %s." % removed_cloud_name)
			return
	var procedural_veil := clouds.get_node_or_null("ProceduralCloudVeil") as MeshInstance3D
	var procedural_dome_count := 0
	for cloud_child in clouds.get_children():
		var cloud_mesh_instance := cloud_child as MeshInstance3D
		if cloud_mesh_instance != null and cloud_mesh_instance.mesh is SphereMesh:
			procedural_dome_count += 1
	if (
		procedural_veil == null
		or not procedural_veil.mesh is SphereMesh
		or procedural_dome_count != 1
		or _mesh_triangle_count(procedural_veil.mesh) <= 0
		or _mesh_triangle_count(procedural_veil.mesh) > 2048
	):
		_fail("El cielo procedural debe usar una única SphereMesh interior de hasta 2048 triángulos.")
		return
	var veil_material := procedural_veil.material_override as ShaderMaterial
	if veil_material == null and procedural_veil.mesh.get_surface_count() > 0:
		veil_material = procedural_veil.mesh.surface_get_material(0) as ShaderMaterial
	var veil_shader_code := "" if veil_material == null or veil_material.shader == null else veil_material.shader.code
	var veil_shader_lower := veil_shader_code.to_lower()
	if (
		veil_shader_code.is_empty()
		or not veil_shader_code.contains("TIME")
		or veil_shader_code.contains("UV")
		or (not veil_shader_lower.contains("fbm") and not veil_shader_lower.contains("noise"))
		or (not veil_shader_lower.contains("sky_direction") and not veil_shader_lower.contains("dome_direction"))
		or not veil_shader_lower.contains("horizon_blend")
		or not veil_shader_lower.contains("cloud_region")
		or not veil_shader_lower.contains("region_field")
	):
		_fail("El cielo debe usar ruido direccional animado y bancos separados por huecos azules.")
		return

	var terrain_assets := load("res://terrain/data/assets.tres") as Terrain3DAssets
	if terrain_assets == null or terrain_assets.get_texture_count() != 7:
		_fail("Terrain3D debe incluir los albedos estilizados, la calle compacta y la nueva caliza costera.")
		return
	for index in terrain_assets.get_texture_count():
		var texture_asset := terrain_assets.get_texture(index) as Terrain3DTextureAsset
		if texture_asset == null or texture_asset.albedo_texture == null:
			_fail("Falta el albedo estilizado del material %d." % index)
			return
		if "stylized_terrain" not in texture_asset.albedo_texture.resource_path:
			_fail("El terreno sigue usando una textura PBR ajena al estilo Quaternius.")
			return
		if texture_asset.normal_texture != null or texture_asset.normal_depth > 0.01:
			_fail("El terreno estilizado no debe recuperar microdetalle normal fotográfico.")
			return
		if texture_asset.albedo_texture.get_width() != 1024 or texture_asset.albedo_texture.get_height() != 1024:
			_fail("Los tiles estilizados deben estar normalizados a 1024 x 1024.")
			return
	var stone_street_asset := terrain_assets.get_texture(5) as Terrain3DTextureAsset
	if (
		stone_street_asset == null
		or not stone_street_asset.albedo_texture.resource_path.ends_with("quaternius_rock_albedo_seamless.png")
		or stone_street_asset.uv_scale < 0.17
	):
		_fail("La calle no usa una variante compactada de quaternius_rock.")
		return
	var coastal_cliff_asset := terrain_assets.get_texture(6) as Terrain3DTextureAsset
	if (
		coastal_cliff_asset == null
		or not coastal_cliff_asset.albedo_texture.resource_path.ends_with("coastal_cliff_albedo_seamless.png")
		or coastal_cliff_asset.normal_texture != null
		or coastal_cliff_asset.normal_depth > 0.01
	):
		_fail("El cantil no usa la caliza low-poly generada para las pendientes costeras.")
		return
	var dirt_road_texture: Vector3 = terrain.data.get_texture_id(Vector3(200.0, 0.0, -480.0))
	if int(dirt_road_texture.y) != 1 or dirt_road_texture.z < 0.70:
		_fail("Los senderos de tierra no conservan quaternius_path.")
		return
	# Muestreamos todo el eje de las diez rutas, incluidos cada vértice y cruce.
	# Ningún punto puede volver a hierba: debe ser tierra o la calle de una villa.
	var minimum_road_coverage := 1.0
	var minimum_road_point := Vector2.ZERO
	for road in ROAD_NETWORK:
		for segment_index in range(road.size() - 1):
			var start: Vector2 = road[segment_index]
			var finish: Vector2 = road[segment_index + 1]
			var steps := ceili(start.distance_to(finish) / 4.0)
			for step_index in range(steps + 1):
				var point := start.lerp(finish, float(step_index) / float(steps))
				var road_texture := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
				if int(road_texture.y) not in [1, 5]:
					_fail("El camino pierde continuidad en %s: material %s." % [point, road_texture])
					return
				if road_texture.z < minimum_road_coverage:
					minimum_road_coverage = road_texture.z
					minimum_road_point = point
	if minimum_road_coverage < 0.35:
		_fail("El camino se estrecha demasiado en %s: cobertura %.1f%%." % [minimum_road_point, minimum_road_coverage * 100.0])
		return
	print("ROAD CONTINUITY: cobertura mínima %.1f%% en %s." % [minimum_road_coverage * 100.0, minimum_road_point])
	for former_stone_route_point in [Vector2(-600.0, 772.0), Vector2(-1960.0, -205.0), Vector2(820.0, -530.0)]:
		var route_texture := terrain.data.get_texture_id(Vector3(former_stone_route_point.x, 0.0, former_stone_route_point.y))
		if int(route_texture.y) != 1:
			_fail("Una antigua calzada exterior continúa usando piedra en vez de tierra.")
			return
	for village_center in [Vector2(0.0, 190.0), Vector2(-1450.0, 650.0), Vector2(-2200.0, -900.0), Vector2(2260.0, -980.0), Vector2(2180.0, 1880.0), Vector2(-420.0, -2150.0)]:
		var street_texture := terrain.data.get_texture_id(Vector3(village_center.x, 0.0, village_center.y))
		if int(street_texture.y) != 5 or street_texture.z < 0.45:
			_fail("La villa %s no sustituye la hierba por quaternius_rock en su calle interior." % village_center)
			return

	if scatter.generated_green_tree_count + scatter.generated_snow_tree_count + scatter.generated_mystery_tree_count + scatter.generated_autumn_tree_count != scatter.generated_tree_count:
		_fail("El reparto de árboles verdes, nevados, tenebrosos y otoñales no coincide con el total.")
		return
	if scatter.generated_snow_tree_count < 1200 or scatter.generated_snow_grass_count != 0 or scatter.generated_snow_fern_count <= 0 or scatter.generated_snow_shrub_count <= 0:
		_fail("La cordillera debe conservar árboles y plantas nevadas, pero ninguna instancia de hierba.")
		return
	var high_snow_point := Vector2(520.0, -3000.0)
	var high_snow_height := terrain.data.get_height(Vector3(high_snow_point.x, 0.0, high_snow_point.y))
	var high_snow_probability := float(scatter.call("_snow_probability", high_snow_point, high_snow_height))
	var low_snow_point := Vector2(-420.0, -2150.0)
	var low_snow_height := terrain.data.get_height(Vector3(low_snow_point.x, 0.0, low_snow_point.y))
	var low_snow_probability := float(scatter.call("_snow_probability", low_snow_point, low_snow_height))
	var transition_found := false
	for sample_x in range(-900, 901, 150):
		for sample_z in range(-2850, -2199, 100):
			var sample := Vector2(sample_x, sample_z)
			var sample_height := terrain.data.get_height(Vector3(sample.x, 0.0, sample.y))
			var probability := float(scatter.call("_snow_probability", sample, sample_height))
			if probability > 0.28 and probability < 0.72:
				transition_found = true
				break
		if transition_found:
			break
	if high_snow_probability < 0.88 or low_snow_probability > 0.08 or not transition_found:
		_fail("La nieve vegetal no forma las franjas verde, mixta y blanca por altura.")
		return
	if not bool(scatter.call("_tree_coverage_point_allowed", high_snow_point)):
		_fail("La retícula anti-calvas todavía excluye las llanuras nevadas.")
		return
	var desert_grass_point := Vector2(2400.0, 2050.0)
	var mystery_grass_point := Vector2(4380.0, -1320.0)
	if (
		bool(scatter.call("_grass_coverage_point_allowed", high_snow_point))
		or bool(scatter.call("_grass_coverage_point_allowed", desert_grass_point))
		or bool(scatter.call("_grass_coverage_point_allowed", mystery_grass_point))
	):
		_fail("La hierba entra en nieve, desierto o Bosque Tenebroso.")
		return
	if scatter.generated_green_tree_count + scatter.generated_snow_tree_count + scatter.generated_mystery_tree_count < roundi(scatter.generated_tree_count * 0.99):
		_fail("Al menos el 99%% de los árboles debe pertenecer a los biomas verde, nevado o tenebroso.")
		return
	if scatter.generated_mystery_tree_count < 1800:
		_fail("El Bosque Tenebroso necesita una masa carmesí de al menos 1.800 árboles.")
		return
	if scatter.generated_autumn_tree_count > roundi(scatter.generated_tree_count * 0.01):
		_fail("Los árboles otoñales fuera del Bosque Tenebroso deben ser una excepción de como máximo el 1%.")
		return
	if scatter.generated_mystery_dead_tree_count != EXPECTED_MYSTERY_DEAD_TREE_COUNT:
		_fail("El Bosque Tenebroso no contiene sus %d árboles secos exclusivos." % EXPECTED_MYSTERY_DEAD_TREE_COUNT)
		return
	var minimum_tree_x := INF
	var maximum_tree_x := -INF
	var minimum_tree_z := INF
	var maximum_tree_z := -INF
	var far_from_route_count := 0
	var far_tree_cells: Dictionary = {}
	for tree_position in scatter.tree_positions:
		minimum_tree_x = minf(minimum_tree_x, tree_position.x)
		maximum_tree_x = maxf(maximum_tree_x, tree_position.x)
		minimum_tree_z = minf(minimum_tree_z, tree_position.z)
		maximum_tree_z = maxf(maximum_tree_z, tree_position.z)
		if scatter.distance_to_route(Vector2(tree_position.x, tree_position.z)) > 180.0:
			far_from_route_count += 1
			far_tree_cells[Vector2i(floori(tree_position.x / 320.0), floori(tree_position.z / 320.0))] = true
		if scatter.distance_to_route(Vector2(tree_position.x, tree_position.z)) < 11.2:
			_fail("Un árbol invadió el corredor despejado del sendero.")
			return
	if maximum_tree_x - minimum_tree_x < 4000.0 or maximum_tree_z - minimum_tree_z < 3500.0:
		_fail("Los bosques aislados no aprovechan todavía la extensión de la isla.")
		return
	if far_from_route_count < roundi(scatter.generated_tree_count * 0.25) or far_tree_cells.size() < 85:
		_fail("El arbolado continúa aglutinado junto a caminos: %d ejemplares lejanos en %d celdas." % [far_from_route_count, far_tree_cells.size()])
		return
	var tree_cells_root := scatter.get_node("TreeCells") as Node3D
	if (
		scatter.generated_coverage_tree_count < 7000
		or scatter.generated_coverage_primary_tree_count < 7000
		or float(tree_cells_root.get_meta("coverage_cell_size", INF)) > 70.0
		or int(tree_cells_root.get_meta("coverage_tree_count", 0)) != scatter.generated_coverage_tree_count
		or int(tree_cells_root.get_meta("coverage_primary_tree_count", 0)) != scatter.generated_coverage_primary_tree_count
	):
		_fail("La retícula anti-calvas no cubre de forma verificable las praderas verdes.")
		return
	if (
		not bool(scatter.get_meta("vegetation_layout_cached", false))
		or not ResourceLoader.exists("res://generated/vegetation_layout_cache.res")
	):
		_fail("El arranque ha vuelto a recalcular la vegetación en vez de usar el layout horneado.")
		return

	var count_specs: Array[Array] = [
		["árboles", scatter.tree_count, scatter.generated_tree_count, EXPECTED_TREE_COUNT],
		["rocas", scatter.rock_count, scatter.generated_rock_count, EXPECTED_ROCK_COUNT],
		["rocas musgosas", scatter.moss_rock_count, scatter.generated_moss_rock_count, EXPECTED_MOSS_ROCK_COUNT],
		["cactus", scatter.cactus_count, scatter.generated_cactus_count, EXPECTED_CACTUS_COUNT],
		["hierba", scatter.grass_count, scatter.generated_grass_count, EXPECTED_GRASS_COUNT],
		["helechos", scatter.fern_count, scatter.generated_fern_count, EXPECTED_FERN_COUNT],
		["arbustos", scatter.shrub_count, scatter.generated_shrub_count, EXPECTED_SHRUB_COUNT],
		["flores", scatter.flower_count, scatter.generated_flower_count, EXPECTED_FLOWER_COUNT],
		["setas", scatter.mushroom_count, scatter.generated_mushroom_count, EXPECTED_MUSHROOM_COUNT],
		["guijarros", scatter.path_pebble_count, scatter.generated_path_pebble_count, EXPECTED_PATH_PEBBLE_COUNT],
	]
	for spec in count_specs:
		var label: String = spec[0]
		var configured: int = spec[1]
		var generated: int = spec[2]
		var expected: int = spec[3]
		if configured != expected:
			_fail("El conteo exportado de %s debería ser %d, no %d." % [label, expected, configured])
			return
		if generated != configured:
			_fail("Se generaron %d elementos de %s; se esperaban %d." % [generated, label, configured])
			return
	if scatter.rock_positions.size() != EXPECTED_ROCK_COUNT or scatter.moss_rock_positions.size() != EXPECTED_MOSS_ROCK_COUNT:
		_fail("Las posiciones verificables de las rocas no coinciden con sus conteos.")
		return
	for rock_position in scatter.rock_positions + scatter.moss_rock_positions:
		var rock_point := Vector2(rock_position.x, rock_position.z)
		if not bool(scatter.call("_desert_decoration_point_allowed", rock_point)):
			_fail("Una roca decorativa quedó fuera de la arena transitable del desierto: %s." % rock_point)
			return

	var cell_specs: Array[Array] = [
		["TreeCells", scatter.generated_tree_count],
		["RockCells", scatter.generated_rock_count],
		["MossRockCells", scatter.generated_moss_rock_count],
		["CactusCells", scatter.generated_cactus_count],
		["GrassCells", scatter.generated_grass_count],
		["GrassMidLODCells", scatter.generated_grass_count],
		["FernCells", scatter.generated_fern_count],
		["ShrubCells", scatter.generated_shrub_count],
		["FlowerCells", scatter.generated_flower_count],
		["MushroomCells", scatter.generated_mushroom_count],
		["PathDetailCells", scatter.generated_path_pebble_count],
		["ForestDetailCells", scatter.forest_detail_count],
		["MysteryDeadTreeCells", scatter.generated_mystery_dead_tree_count],
	]
	var counted_cells := 0
	for spec in cell_specs:
		var root_name: String = spec[0]
		var expected_instances: int = spec[1]
		var category := scatter.get_node_or_null(root_name) as Node3D
		if category == null:
			_fail("Falta la raíz de celdas %s." % root_name)
			return
		if expected_instances > 0 and category.get_child_count() == 0:
			_fail("La raíz %s no contiene ninguna celda." % root_name)
			return
		var instance_total := 0
		for child in category.get_children():
			var cell := child as MultiMeshInstance3D
			if cell == null or cell.multimesh == null or cell.multimesh.mesh == null:
				_fail("%s contiene una celda MultiMesh inválida." % root_name)
				return
			if cell.multimesh.instance_count <= 0:
				_fail("%s contiene una celda vacía." % root_name)
				return
			if absf(cell.lod_bias - 0.75) > 0.01 or not cell.has_meta("imported_mesh_lod_bias"):
				_fail("%s no aplica el LOD importado al decorado completo." % root_name)
				return
			instance_total += cell.multimesh.instance_count
			counted_cells += 1
		if root_name.begins_with("Grass") and (instance_total <= 0 or instance_total >= expected_instances):
			_fail("%s no contiene una ventana acotada: %d instancias." % [root_name, instance_total])
			return
		if not root_name.begins_with("Grass") and instance_total != expected_instances:
			_fail("%s contiene %d instancias; se esperaban %d." % [root_name, instance_total, expected_instances])
			return
	if scatter.get_node_or_null("StoneRoadGround") != null:
		_fail("Todavía existe una cinta de piedra colocada por encima del terreno.")
		return
	if scatter.get_node_or_null("StonePathCells") != null:
		_fail("Las calles vuelven a contener piezas RockPath decorativas.")
		return
	var dirt_detail_cells := scatter.get_node("PathDetailCells") as Node3D
	if dirt_detail_cells.get_meta("road_indices", []) != [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]:
		_fail("Los diez caminos exteriores deben ser de tierra.")
		return
	# El renderer dummy de --headless no conserva el buffer de transforms de
	# MultiMesh y devuelve identidades. En un renderer real sí se comprueban los
	# puntos; en headless se valida su AABB, anclaje y generación determinista.
	if DisplayServer.get_name().to_lower() != "headless":
		for cover_name in ["GrassCells", "FernCells", "ShrubCells", "FlowerCells", "MushroomCells"]:
			var cover_root := scatter.get_node(cover_name) as Node3D
			for cell_node in cover_root.get_children():
				var cover_cell := cell_node as MultiMeshInstance3D
				for instance_index in cover_cell.multimesh.instance_count:
					var origin := cover_cell.to_global(cover_cell.multimesh.get_instance_transform(instance_index).origin)
					if bool(scatter.call("_inside_stone_village_street", Vector2(origin.x, origin.z), 0.0)):
						_fail("%s invade una calle de piedra integrada en Terrain3D." % cover_name)
						return
					if float(scatter.call("distance_to_route", Vector2(origin.x, origin.z))) < 7.8:
						_fail("%s invade el material de un camino de tierra." % cover_name)
						return
	if scatter.generated_cell_count < MIN_EXPECTED_CELL_COUNT:
		_fail(
			"El bosque generó solo %d celdas; se esperaban al menos %d."
			% [scatter.generated_cell_count, MIN_EXPECTED_CELL_COUNT]
		)
		return
	if scatter.generated_cell_count != counted_cells:
		_fail("El contador de celdas no coincide con las %d celdas Quaternius instaladas." % counted_cells)
		return
	if scatter.get_node_or_null("DenseGrassStream") != null:
		_fail("La alfombra móvil de hierba masiva sigue activa en vez del reparto disperso original.")
		return
	var grass_cells := scatter.get_node("GrassCells") as Node3D
	var grass_lod_cells := scatter.get_node_or_null("GrassLODCells") as Node3D
	if (
		grass_lod_cells == null
		or not bool(scatter.get_meta("dense_static_grass_lod", false))
		or not bool(scatter.get_meta("grass_lod_crossfade", false))
		or String(grass_lod_cells.get_meta("crossfades_with", "")) != "GrassCells"
		or scatter.generated_grass_lod_instances != EXPECTED_GRASS_COUNT
		or scatter.generated_grass_lod_cells <= 0
		or String(grass_cells.get_meta("source_model", "")) != "Grass_Common_Short.gltf"
		or grass_cells.get_meta("excluded_biomes", PackedStringArray()) != PackedStringArray(["snow", "desert", "mystery_forest"])
	):
		_fail("La hierba densa no conserva su modelo, exclusiones y fundido LOD estable.")
		return
	for rock_root_name in ["RockCells", "MossRockCells"]:
		var rock_root := scatter.get_node(rock_root_name) as Node3D
		if not bool(rock_root.get_meta("desert_only", false)) or not bool(rock_root.get_meta("excluded_from_cliffs", false)):
			_fail("%s no declara su confinamiento al desierto llano." % rock_root_name)
			return
	if (
		int(scatter.get_meta("grass_patch_clumps", 0)) != EXPECTED_GRASS_CLUMPS_PER_PATCH
		or int(grass_cells.get_meta("effective_clump_count", 0)) != EXPECTED_GRASS_COUNT * EXPECTED_GRASS_CLUMPS_PER_PATCH
		or int(grass_lod_cells.get_meta("effective_clump_count", 0)) != EXPECTED_GRASS_COUNT * EXPECTED_GRASS_CLUMPS_PER_PATCH
	):
		_fail("Los parches no representan la nueva alfombra densa mediante MultiMesh.")
		return
	var first_grass_patch := (grass_cells.get_child(0) as MultiMeshInstance3D).multimesh.mesh
	var grass_patch_aabb := first_grass_patch.get_aabb()
	if (
		_mesh_triangle_count(first_grass_patch) > MAX_GRASS_FULL_TRIANGLES_PER_PATCH
		or grass_patch_aabb.size.x < 17.0
		or grass_patch_aabb.size.z < 17.0
	):
		_fail("La hierba cercana no combina cobertura continua con una malla GPU barata.")
		return
	var counted_grass_lod_instances := 0
	for grass_lod_node in grass_lod_cells.get_children():
		var grass_lod_cell := grass_lod_node as MultiMeshInstance3D
		if (
			grass_lod_cell == null
			or grass_lod_cell.multimesh == null
			or grass_lod_cell.multimesh.instance_count <= 0
			or grass_lod_cell.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			or grass_lod_cell.visibility_range_begin != 0.0
			or grass_lod_cell.visibility_range_end != 0.0
			or grass_lod_cell.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			or grass_lod_cell.multimesh.custom_aabb.size.length_squared() <= 0.0
			or not _cell_is_spatially_anchored(grass_lod_cell)
			or _mesh_triangle_count(grass_lod_cell.multimesh.mesh) > MAX_GRASS_LOD_TRIANGLES_PER_PATCH
		):
			_fail("Una celda proxy de hierba no es barata, local o exclusivamente gobernada.")
			return
		counted_grass_lod_instances += grass_lod_cell.multimesh.instance_count
	if counted_grass_lod_instances != EXPECTED_GRASS_COUNT:
		_fail("El proxy de hierba no replica exactamente las %d matas dispersas." % EXPECTED_GRASS_COUNT)
		return
	if not bool(scatter.get_meta("project_assets_loaded_via_importer", false)):
		_fail("El decorado continúa saltándose el importador y sus LOD automáticos.")
		return
	scatter.call("_update_explicit_lod_visibility", true)
	if vegetation_cache != null and vegetation_cache.grass_records.size() >= 3:
		scatter.call(
			"_update_grass_near_field",
			Vector2(vegetation_cache.grass_records[0], vegetation_cache.grass_records[2]),
			true
		)
	var near_field := grass_cells.get_node_or_null("FixedNearField") as MultiMeshInstance3D
	var mid_cells := scatter.get_node_or_null("GrassMidLODCells") as Node3D
	var mid_field := mid_cells.get_node_or_null("FixedMidField") as MultiMeshInstance3D if mid_cells != null else null
	if (
		near_field == null
		or near_field.multimesh == null
		or near_field.multimesh.instance_count <= 0
		or not bool(grass_cells.get_meta("fixed_world_layout", false))
		or not bool(grass_cells.get_meta("gpu_window_faded", false))
	):
		_fail("El campo cercano no conserva posiciones fijas con precarga invisible.")
		return
	if (
		mid_field == null
		or mid_field.multimesh == null
		or mid_field.multimesh.instance_count <= near_field.multimesh.instance_count
		or _mesh_triangle_count(mid_field.multimesh.mesh) > MAX_GRASS_MID_TRIANGLES_PER_PATCH
		or not bool(mid_cells.get_meta("fixed_world_layout", false))
	):
		_fail("La corona intermedia no amplía la profundidad con una malla económica.")
		return

	var tree_cells := scatter.get_node("TreeCells") as Node3D
	var tree_lod_cells := scatter.get_node_or_null("TreeLODCells") as Node3D
	if (
		tree_lod_cells == null
		or scatter.generated_tree_lod_instances != EXPECTED_TREE_COUNT
		or scatter.generated_tree_lod_cells < 120
		or absf(float(tree_lod_cells.get_meta("visibility_begin", 0.0)) - scatter.lod_switch_distance) > 0.01
		or float(tree_lod_cells.get_meta("visibility_end", 0.0)) < 5000.0
		or not bool(tree_lod_cells.get_meta("shadows_disabled", false))
		or String(tree_lod_cells.get_meta("exclusive_with", "")) != "TreeCells"
		or absf(float(tree_cells.get_meta("switch_distance", 0.0)) - scatter.lod_switch_distance) > 0.01
	):
		_fail("Los árboles no alternan modelo completo cercano y proxy facetado lejano.")
		return
	var counted_tree_lod_instances := 0
	var maximum_tree_lod_triangles := 0
	for lod_node in tree_lod_cells.get_children():
		var lod_cell := lod_node as MultiMeshInstance3D
		if (
			lod_cell == null
			or lod_cell.multimesh == null
			or lod_cell.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			or lod_cell.visibility_range_begin != 0.0
			or lod_cell.visibility_range_end != 0.0
			or lod_cell.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			or lod_cell.multimesh.custom_aabb.size.length_squared() <= 0.0
			or not _cell_is_spatially_anchored(lod_cell)
		):
			_fail("Una celda LOD de árboles no tiene anclaje, culling o AABB válidos.")
			return
		counted_tree_lod_instances += lod_cell.multimesh.instance_count
		var lod_triangles := _mesh_triangle_count(lod_cell.multimesh.mesh)
		maximum_tree_lod_triangles = maxi(maximum_tree_lod_triangles, lod_triangles)
	if counted_tree_lod_instances != EXPECTED_TREE_COUNT or maximum_tree_lod_triangles > 110:
		_fail("El proxy arbóreo no replica los %d árboles o supera 110 triángulos: %d/%d." % [EXPECTED_TREE_COUNT, counted_tree_lod_instances, maximum_tree_lod_triangles])
		return
	if not _lod_pair_is_exclusive(tree_cells, tree_lod_cells):
		_fail("Los árboles completos y sus proxies aparecen simultáneamente en una misma celda.")
		return
	scatter.set_lod_switch_distance(600.0)
	if absf(scatter.lod_switch_distance - 600.0) > 0.01 or not _lod_pair_is_exclusive(tree_cells, tree_lod_cells):
		_fail("Cambiar la distancia LOD rompe la exclusividad de los árboles.")
		return
	scatter.set_lod_switch_distance(340.0)
	for child in tree_cells.get_children():
		var cell := child as MultiMeshInstance3D
		if cell.multimesh.mesh.get_aabb().size.y < 6.0:
			_fail("El bosque debe utilizar árboles adultos Quaternius de al menos seis metros.")
			return
	var forest_detail_cells := scatter.get_node("ForestDetailCells") as Node3D
	if DisplayServer.get_name().to_lower() != "headless":
		for child in forest_detail_cells.get_children():
			var cell := child as MultiMeshInstance3D
			for index in cell.multimesh.instance_count:
				var position := cell.to_global(cell.multimesh.get_instance_transform(index).origin)
				if bool(scatter.call("_inside_village_clearing", Vector2(position.x, position.z), 0.0)):
					_fail("Un árbol seco de detalle atraviesa una casa, patio o castillo.")
					return

	var collision_body := scatter.get_node_or_null("DecorCollisions") as StaticBody3D
	var expected_collisions := 1 + scatter.generated_rock_collision_count
	if collision_body == null or collision_body.get_child_count() != expected_collisions:
		_fail("La colisión forestal unificada y las colisiones de roca no coinciden.")
		return
	var forest_collision := collision_body.get_node_or_null("ForestTreeCollisionMesh") as CollisionShape3D
	if (
		forest_collision == null
		or not forest_collision.shape is ConcavePolygonShape3D
		or int(forest_collision.get_meta("source_tree_count", 0)) != scatter.generated_tree_collision_count
	):
		_fail("Los troncos seleccionados no están incluidos en la malla física forestal.")
		return
	if scatter.generated_tree_collision_count < 4000:
		_fail("El corredor jugable no conserva suficiente colisión entre árboles.")
		return
	var breakable_root := scatter.get_node_or_null("BreakableResources") as Node3D
	var expected_breakables := scatter.generated_rock_count + scatter.generated_cactus_count
	if (
		breakable_root == null
		or breakable_root.get_child_count() != expected_breakables
		or scatter.generated_breakable_resource_count != expected_breakables
	):
		_fail("Cada roca y cactus del desierto debe tener una colisión rompible individual.")
		return
	for child in breakable_root.get_children():
		var resource := child as AdventureResource
		if resource == null or resource.kind not in ["rock", "cactus"] or resource.get_child_count() != 1:
			_fail("Una roca o cactus no está conectado al sistema rompible.")
			return
	var persistence_probe := breakable_root.get_child(0) as AdventureResource
	var probe_id := persistence_probe.zone_id
	scatter.apply_save_state({"destroyed_resource_ids": [probe_id]})
	var saved_resources := scatter.get_save_state().get("destroyed_resource_ids", []) as Array
	if not persistence_probe.broken or probe_id not in saved_resources:
		_fail("El estado roto de una roca o cactus no entra en el guardado.")
		return
	scatter.apply_save_state({"destroyed_resource_ids": []})
	if persistence_probe.broken:
		_fail("Cargar otra ranura no restaura los recursos que siguen enteros en ella.")
		return
	var save_manager := root.get_node_or_null("SaveGameManager")
	if save_manager != null:
		save_manager.call("bind_world", null)
	var adventure_system := world.get_node("AdventureSystem")
	for wanted_kind in ["rock", "cactus"]:
		var breakable: AdventureResource = null
		for child in breakable_root.get_children():
			var candidate := child as AdventureResource
			if candidate != null and candidate.kind == wanted_kind:
				breakable = candidate
				break
		if breakable == null:
			_fail("No existe un %s de prueba en el desierto." % wanted_kind)
			return
		var multimesh_key := String(breakable.get_meta("multimesh_key", ""))
		var visual_multimesh := scatter.get("_installed_multimeshes").get(multimesh_key) as MultiMeshInstance3D
		var visual_index := int(breakable.get_meta("multimesh_instance_index", -1))
		var visible_before := visual_multimesh.multimesh.get_instance_transform(visual_index)
		var drops_before := int(adventure_system.get("generated_pickup_count"))
		breakable.receive_tool_hit("axe", "Axe_Small", breakable.global_position, player)
		await create_timer(0.10).timeout
		var visible_during_hit := visual_multimesh.multimesh.get_instance_transform(visual_index)
		# El renderer dummy de --headless no conserva el buffer MultiMesh tras
		# instalarlo en el árbol. En ejecución normal comprobamos la transformación
		# real; sin pantalla comprobamos que el tween produjo una pose visible.
		var visible_wobble_computed := float(
			breakable.get_meta("computed_visible_wobble_delta", 0.0)
		) > 0.0001
		var renderer_keeps_multimesh_buffer := DisplayServer.get_name().to_lower() != "headless"
		if (
			not visible_wobble_computed
			or (
				renderer_keeps_multimesh_buffer
				and visible_during_hit.basis.is_equal_approx(visible_before.basis)
			)
		):
			_fail("Golpear un %s no hace vibrar su malla visible." % wanted_kind)
			return
		breakable.receive_tool_hit("axe", "Axe_Small", breakable.global_position, player)
		breakable.receive_tool_hit("axe", "Axe_Small", breakable.global_position, player)
		await create_timer(0.62).timeout
		var broken_state := scatter.get_save_state().get("destroyed_resource_ids", []) as Array
		var spawned_arrow := false
		for pickup_node in adventure_system.get_children():
			var pickup := pickup_node as AdventurePickup
			if pickup != null and pickup.item_id == "Arrow" and pickup.get_instance_id() != 0:
				spawned_arrow = true
				break
		if (
			breakable.zone_id not in broken_state
			or int(adventure_system.get("generated_pickup_count")) <= drops_before
			or (wanted_kind == "rock" and not spawned_arrow)
		):
			_fail("Romper un %s no persiste o no deja el botín físico esperado." % wanted_kind)
			return
		scatter.apply_save_state({"destroyed_resource_ids": []})
		await process_frame
	var expected_harvestable_trees := (
		scatter.generated_tree_count
		+ scatter.forest_detail_count
		+ scatter.generated_mystery_dead_tree_count
	)
	if (
		not bool(scatter.get_meta("all_trees_harvestable", false))
		or scatter.generated_harvestable_tree_count != expected_harvestable_trees
		or int(scatter.get_meta("harvestable_tree_count", 0)) != expected_harvestable_trees
	):
		_fail("Todos los árboles normales y secos deben estar indexados para tala persistente.")
		return
	# Tres golpes independientes deben tumbar una instancia MultiMesh, crear su
	# tocón y expulsar dos troncos sin haber creado 80.000 nodos físicos.
	var harvest_position := scatter.tree_positions[0]
	var harvest_player_position := harvest_position + Vector3(0.0, 0.0, 2.4)
	var harvest_forward := (harvest_position - harvest_player_position).normalized()
	var pickup_count_before := int(world.get_node("AdventureSystem").get("generated_pickup_count"))
	for attack_serial in range(1, 4):
		player.attacks_performed = attack_serial
		if not bool(scatter.call(
			"try_hit_nearest_tree",
			"axe",
			"Axe_Small",
			harvest_player_position,
			harvest_forward,
			2.0,
			player
		)):
			_fail("El índice forestal no encontró un árbol cercano durante la tala.")
			return
		for _frame in 5:
			await process_frame
	await create_timer(0.95).timeout
	var harvest_id := String(scatter.call(
		"_stable_scatter_resource_id",
		"forest_tree",
		Vector2(harvest_position.x, harvest_position.z)
	))
	var expected_arrow_bonus := int(scatter.call("_tree_bonus_arrow_amount", harvest_id))
	var harvest_state := scatter.get_save_state().get("destroyed_resource_ids", []) as Array
	var stump_root := scatter.get_node_or_null("HarvestedTreeStumps") as Node3D
	if (
		harvest_id not in harvest_state
		or stump_root == null
		or stump_root.get_child_count() <= 0
		or int(world.get_node("AdventureSystem").get("generated_pickup_count"))
			< pickup_count_before + 2 + (1 if expected_arrow_bonus > 0 else 0)
	):
		_fail("Talar un árbol no persiste o no expulsa sus troncos y flechas visibles.")
		return
	var trees_with_arrows := 0
	var trees_without_arrows := 0
	var harvest_ids: PackedStringArray = scatter.get("_harvest_tree_ids")
	for sample_index in mini(harvest_ids.size(), 1000):
		if int(scatter.call("_tree_bonus_arrow_amount", harvest_ids[sample_index])) > 0:
			trees_with_arrows += 1
		else:
			trees_without_arrows += 1
	if trees_with_arrows <= 0 or trees_without_arrows <= 0:
		_fail("Las flechas de los árboles deben ser una recompensa aleatoria, no universal.")
		return
	scatter.apply_save_state({"destroyed_resource_ids": []})
	await process_frame
	if scatter.get_save_state().get("destroyed_resource_ids", []).has(harvest_id):
		_fail("Cambiar de ranura no restaura correctamente un árbol talado.")
		return
	var first_grass_cell := scatter.get_node("GrassCells").get_child(0) as MultiMeshInstance3D
	var grass_material := first_grass_cell.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	if (
		grass_material == null
		or grass_material.shader == null
		or not grass_material.shader.code.contains("TIME")
		or not grass_material.shader.code.contains("soft_gust")
		or not grass_material.shader.code.contains("strong_gust")
		or not grass_material.shader.code.contains("travelling_wave")
		or not grass_material.shader.code.contains("grass_world_position")
		or not grass_material.shader.code.contains("player_position")
		or not grass_material.shader.code.contains("local_outward")
	):
		_fail("La alfombra no combina viento coordinado y apertura alrededor del personaje.")
		return
	scatter.call("_update_grass_interaction")
	var shader_player_position: Vector3 = grass_material.get_shader_parameter("player_position")
	var interaction_player := world.get_node("Player") as Node3D
	if shader_player_position.distance_to(interaction_player.global_position) > 0.01:
		_fail("La deformación de la alfombra no sigue la posición real del personaje.")
		return

	var horse_model_root := horse.get_node_or_null("Visual/ModelRoot") as Node3D
	if horse_model_root == null or not horse_model_root.is_visible_in_tree():
		_fail("El GLB realista del caballo no está visible en el árbol.")
		return
	var horse_skeleton := _find_skeleton(horse_model_root)
	if horse_skeleton == null or horse_skeleton.get_bone_count() < 20:
		_fail("El caballo no conserva un esqueleto real válido.")
		return
	if not _has_visible_mesh(horse_model_root):
		_fail("El caballo no contiene ninguna malla visible y renderizable.")
		return
	var animator := horse_model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null:
		_fail("El caballo no contiene AnimationPlayer.")
		return
	for required_animation in ["Idle", "Walk", "Gallop"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación del caballo: %s" % required_animation)
			return
	if animator.current_animation != "Idle":
		_fail("El caballo no inicia con su animación Quaternius Idle.")
		return

	var player_model_root := world.get_node("Player/Visual/ModelRoot") as Node3D
	var player_animator := player_model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player_model_root.get_child_count() == 0:
		_fail("El protagonista debe cargar el personaje Quaternius.")
		return
	for required_animation in ["Idle", "Walk", "Run", "SwordSlash"]:
		if player_animator == null or not player_animator.has_animation(required_animation):
			_fail("Falta la animación del protagonista Quaternius: %s" % required_animation)
			return

	var first_animal := wildlife.get_child(0) as Node3D
	var animal_start := first_animal.global_position
	var initial_forward := first_animal.global_basis.z.normalized()
	world.get_node("Player").global_position = animal_start + initial_forward * 3.0
	for _frame in range(24):
		await physics_frame
	var flat_displacement := Vector3(first_animal.global_position.x - animal_start.x, 0.0, first_animal.global_position.z - animal_start.z)
	if flat_displacement.length() < 2.3 or float(wildlife.get("flee_speed")) < 8.0:
		_fail("La fauna sigue desplazándose demasiado despacio durante la huida.")
		return
	if int(wildlife.get("reaction_count")) <= 0:
		_fail("La fauna no registró ninguna reacción visual al jugador.")
		return
	var final_forward := first_animal.global_basis.z.normalized()
	if final_forward.dot(flat_displacement.normalized()) < 0.78 or str(first_animal.get_meta("visual_forward_axis", "")) != "+Z":
		_fail("La fauna todavía se desplaza hacia atrás respecto a sus patas.")
		return
	if float(first_animal.get_meta("animation_motion_ratio", 1.0)) > 0.14:
		_fail("Las patas de la fauna siguen animándose demasiado rápido para su desplazamiento.")
		return

	var generated_cell_total := scatter.generated_cell_count
	var tree_lod_instance_total := scatter.generated_tree_lod_instances
	var grass_lod_instance_total := scatter.generated_grass_lod_instances
	world.queue_free()
	for _frame in range(8):
		await process_frame
	print(
		"QUATERNIUS TEST OK: %d árboles + %d proxies (%.1f%% lejos de rutas), %d hierbas fijas con fundido LOD, %d celdas base, %d elementos y %d personajes."
		% [EXPECTED_TREE_COUNT, tree_lod_instance_total, float(far_from_route_count) * 100.0 / float(EXPECTED_TREE_COUNT), grass_lod_instance_total, generated_cell_total, EXPECTED_TREE_COUNT + EXPECTED_ROCK_COUNT + EXPECTED_MOSS_ROCK_COUNT + EXPECTED_CACTUS_COUNT + EXPECTED_MYSTERY_DEAD_TREE_COUNT + EXPECTED_GRASS_COUNT + EXPECTED_FERN_COUNT + EXPECTED_SHRUB_COUNT + EXPECTED_FLOWER_COUNT + EXPECTED_MUSHROOM_COUNT + EXPECTED_PATH_PEBBLE_COUNT, EXPECTED_CHARACTER_COUNT]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _find_skeleton(parent: Node) -> Skeleton3D:
	for node in parent.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _has_visible_mesh(parent: Node) -> bool:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if (
			mesh_instance != null
			and mesh_instance.mesh != null
			and mesh_instance.mesh.get_surface_count() > 0
			and mesh_instance.is_visible_in_tree()
		):
			return true
	return false


func _cell_is_spatially_anchored(cell: MultiMeshInstance3D) -> bool:
	if not cell.has_meta("cell") or not cell.has_meta("cell_size"):
		return false
	var cell_key: Vector2i = cell.get_meta("cell")
	var cell_size := float(cell.get_meta("cell_size"))
	var expected_anchor := Vector2((float(cell_key.x) + 0.5) * cell_size, (float(cell_key.y) + 0.5) * cell_size)
	if Vector2(cell.position.x, cell.position.z).distance_to(expected_anchor) > 0.01:
		return false
	for index in cell.multimesh.instance_count:
		var local_origin := cell.multimesh.get_instance_transform(index).origin
		if absf(local_origin.x) > cell_size * 0.501 or absf(local_origin.z) > cell_size * 0.501:
			return false
	return true


func _lod_pair_is_exclusive(full_root: Node3D, proxy_root: Node3D) -> bool:
	var full_state: Dictionary = {}
	var proxy_state: Dictionary = {}
	for node in full_root.get_children():
		var instance := node as MultiMeshInstance3D
		if instance == null:
			continue
		var cell: Vector2i = instance.get_meta("cell")
		if full_state.has(cell) and bool(full_state[cell]) != instance.visible:
			return false
		full_state[cell] = instance.visible
	for node in proxy_root.get_children():
		var instance := node as MultiMeshInstance3D
		if instance == null:
			continue
		var cell: Vector2i = instance.get_meta("cell")
		if proxy_state.has(cell) and bool(proxy_state[cell]) != instance.visible:
			return false
		proxy_state[cell] = instance.visible
		if instance.visible and bool(full_state.get(cell, false)):
			return false
	return true


func _mesh_triangle_count(mesh: Mesh) -> int:
	var triangle_count := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not indices.is_empty():
			triangle_count += indices.size() / 3
		else:
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices is PackedVector3Array:
				triangle_count += vertices.size() / 3
	return triangle_count


func _illustrated_cloud_field_is_valid(
	field: MultiMeshInstance3D,
	expected_count: int,
	shadows_only: bool
) -> bool:
	if (
		field == null
		or field.multimesh == null
		or field.multimesh.mesh == null
		or expected_count <= 0
		or field.multimesh.instance_count != expected_count
		or not field.multimesh.use_custom_data
		or field.multimesh.custom_aabb.size.length_squared() <= 0.0
		or _mesh_triangle_count(field.multimesh.mesh) != 2
	):
		return false
	var expected_shadow_mode := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if shadows_only
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	return field.cast_shadow == expected_shadow_mode
