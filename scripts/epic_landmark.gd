class_name EpicLandmark
extends Node3D

## Hito visual del valle: una pared rocosa y una fortaleza construidas sólo
## con piezas CC0 de Quaternius, acompañadas por cascada, poza y río.
## Las posiciones se adaptan a la altura real de Terrain3D al arrancar.

const QUATERNIUS_ROOT := "res://assets/quaternius/store_bundle/glTF/"
const WATERFALL_SHADER: Shader = preload("res://shaders/waterfall.gdshader")
const LAKE_SHADER: Shader = preload("res://shaders/lake_water.gdshader")
const WATERFALL_AUDIO: AudioStream = preload("res://assets/audio/original/waterfall.ogg")

const LANDMARK_CENTER := Vector2(64.0, -155.0)
const WATERFALL_HEIGHT := 38.0

@export var terrain_path: NodePath = NodePath("../Terrain3D")

@onready var epic_cliffs: Node3D = $EpicCliffs
@onready var waterfall: Node3D = $Waterfall
@onready var pool: Node3D = $Pool
@onready var fortress: Node3D = $Fortress

var cliff_piece_count := 0
var fortress_piece_count := 0
var landmark_ground_height := 0.0

var _terrain: Terrain3D
var _mountainside_mesh: Mesh
var _rock_face_mesh: Mesh
var _dead_tree_mesh: Mesh
var _stump_mesh: Mesh
var _fort_meshes: Dictionary = {}


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain3D
	landmark_ground_height = _height_at(LANDMARK_CENTER)
	_cache_source_meshes()
	_build_cliff_wall()
	_build_waterfall()
	_build_pool_and_river()
	_build_fortress()
	_build_fallen_timber()
	print(
		"EPIC LANDMARK READY: %d rocas, %d módulos de fortaleza, cascada %.0f m."
		% [cliff_piece_count, fortress_piece_count, WATERFALL_HEIGHT]
	)


func _cache_source_meshes() -> void:
	_mountainside_mesh = _load_quaternius_mesh("Rock_Medium_1.gltf")
	_rock_face_mesh = _load_quaternius_mesh("Rock_Medium_2.gltf")
	_dead_tree_mesh = _load_quaternius_mesh("DeadTree_2.gltf")
	_stump_mesh = _load_quaternius_mesh("DeadTree_5.gltf")
	_fort_meshes["tower_round"] = _load_quaternius_mesh("Roof_Tower_RoundTiles.gltf")
	_fort_meshes["wall_thick_straight_01"] = _load_quaternius_mesh("Wall_UnevenBrick_Straight.gltf")
	_fort_meshes["wall_thin_gate_01"] = _load_quaternius_mesh("Wall_Arch.gltf")
	_fort_meshes["wall_thick_corner_01"] = _load_quaternius_mesh("Wall_Plaster_WoodGrid.gltf")


func _build_cliff_wall() -> void:
	# Tres estratos de rocas estilizadas forman una pared amplia y luminosa.
	var cliff_layout: Array[Array] = [
		[Vector2(8.0, -167.0), 0.18, Vector3(4.8, 4.2, 4.1), 0.0],
		[Vector2(25.0, -163.0), -0.22, Vector3(5.1, 4.6, 4.2), 0.0],
		[Vector2(43.0, -161.0), 0.12, Vector3(5.2, 4.8, 4.4), 0.0],
		[Vector2(64.0, -160.0), -0.08, Vector3(5.8, 5.0, 4.7), 0.0],
		[Vector2(85.0, -161.0), 0.19, Vector3(5.3, 4.7, 4.4), 0.0],
		[Vector2(104.0, -164.0), -0.27, Vector3(5.0, 4.4, 4.1), 0.0],
		[Vector2(122.0, -168.0), 0.24, Vector3(4.6, 4.0, 3.9), 0.0],
		[Vector2(19.0, -169.0), -0.16, Vector3(4.7, 4.1, 4.0), 7.0],
		[Vector2(38.0, -166.0), 0.23, Vector3(5.0, 4.5, 4.2), 7.5],
		[Vector2(58.0, -165.0), -0.12, Vector3(5.4, 4.8, 4.4), 8.0],
		[Vector2(78.0, -165.0), 0.18, Vector3(5.2, 4.6, 4.3), 7.6],
		[Vector2(98.0, -168.0), -0.20, Vector3(4.8, 4.3, 4.1), 7.0],
		[Vector2(32.0, -171.0), 0.16, Vector3(4.5, 3.8, 3.8), 14.0],
		[Vector2(52.0, -169.0), -0.21, Vector3(4.8, 4.1, 4.0), 14.5],
		[Vector2(73.0, -169.0), 0.10, Vector3(4.9, 4.2, 4.0), 14.8],
		[Vector2(93.0, -171.0), -0.14, Vector3(4.4, 3.8, 3.7), 14.0],
	]
	for index in cliff_layout.size():
		var entry := cliff_layout[index]
		var point: Vector2 = entry[0]
		var height := _height_at(point)
		_spawn_visual(
			epic_cliffs,
			"QuaterniusCliff%02d" % index,
			_mountainside_mesh if index % 2 == 0 else _rock_face_mesh,
			Vector3(point.x, height - 0.35 + float(entry[3]), point.y),
			Vector3(0.0, entry[1], 0.0),
			entry[2]
		)
		cliff_piece_count += 1

	_add_box_collider(
		epic_cliffs,
		"CliffCollisionCenter",
		Vector3(64.0, landmark_ground_height + 16.0, -160.0),
		Vector3(70.0, 33.0, 17.0),
		0.0
	)
	_add_box_collider(
		epic_cliffs,
		"CliffCollisionWest",
		Vector3(17.0, _height_at(Vector2(17.0, -165.0)) + 13.0, -165.0),
		Vector3(42.0, 27.0, 16.0),
		0.08
	)
	_add_box_collider(
		epic_cliffs,
		"CliffCollisionEast",
		Vector3(111.0, _height_at(Vector2(111.0, -165.0)) + 13.0, -165.0),
		Vector3(42.0, 27.0, 16.0),
		-0.08
	)


func _build_waterfall() -> void:
	var water_material := ShaderMaterial.new()
	water_material.shader = WATERFALL_SHADER
	water_material.set_shader_parameter("flow_speed", 0.72)
	water_material.set_shader_parameter("foam_strength", 1.08)

	var main_curtain := PlaneMesh.new()
	main_curtain.orientation = PlaneMesh.FACE_Z
	main_curtain.size = Vector2(15.5, WATERFALL_HEIGHT)
	main_curtain.subdivide_width = 22
	main_curtain.subdivide_depth = 72
	main_curtain.material = water_material
	var main_fall := _spawn_visual(
		waterfall,
		"WaterfallMain",
		main_curtain,
		Vector3(64.0, landmark_ground_height + WATERFALL_HEIGHT * 0.5 + 0.8, -151.2),
		Vector3.ZERO,
		Vector3.ONE,
		false
	)
	main_fall.extra_cull_margin = 4.0

	# Una segunda lámina descentrada da volumen sin duplicar todo el macizo.
	var veil_material := ShaderMaterial.new()
	veil_material.shader = WATERFALL_SHADER
	veil_material.set_shader_parameter("water_tint", Color(0.46, 0.69, 0.73, 0.54))
	veil_material.set_shader_parameter("flow_speed", 0.94)
	veil_material.set_shader_parameter("foam_strength", 1.24)
	veil_material.set_shader_parameter("curtain_motion", 0.18)
	var veil_mesh := PlaneMesh.new()
	veil_mesh.orientation = PlaneMesh.FACE_Z
	veil_mesh.size = Vector2(9.2, WATERFALL_HEIGHT - 3.0)
	veil_mesh.subdivide_width = 16
	veil_mesh.subdivide_depth = 64
	veil_mesh.material = veil_material
	_spawn_visual(
		waterfall,
		"WaterfallVeil",
		veil_mesh,
		Vector3(63.1, landmark_ground_height + WATERFALL_HEIGHT * 0.5, -150.88),
		Vector3(0.0, -0.025, 0.0),
		Vector3.ONE,
		false
	)

	_add_mist_volume()
	_add_spray_particles("BaseSpray", Vector3(64.0, landmark_ground_height + 1.7, -149.0), 150, 3.8, Vector3(5.2, 0.7, 2.5), true)
	_add_spray_particles("CrestSpray", Vector3(64.0, landmark_ground_height + WATERFALL_HEIGHT + 0.2, -152.0), 72, 2.8, Vector3(4.2, 0.35, 1.6), false)
	_add_waterfall_audio()


func _add_waterfall_audio() -> void:
	WATERFALL_AUDIO.set("loop", true)
	var audio := AudioStreamPlayer3D.new()
	audio.name = "WaterfallAudio"
	audio.position = Vector3(64.0, landmark_ground_height + 7.0, -149.0)
	audio.stream = WATERFALL_AUDIO
	audio.volume_db = -3.5
	audio.unit_size = 12.0
	audio.max_distance = 260.0
	audio.attenuation_filter_cutoff_hz = 6800.0
	audio.bus = &"Ambience"
	waterfall.add_child(audio)
	audio.play()


func _build_pool_and_river() -> void:
	var pool_material := _create_water_material(0.085, 0.82)
	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2(34.0, 24.0)
	pool_mesh.subdivide_width = 42
	pool_mesh.subdivide_depth = 30
	pool_mesh.material = pool_material
	_spawn_visual(
		pool,
		"WaterfallPool",
		pool_mesh,
		Vector3(64.0, landmark_ground_height + 0.34, -142.5),
		Vector3.ZERO,
		Vector3.ONE,
		false
	)

	var river_mesh := _create_river_mesh([
		Vector2(63.0, -133.0),
		Vector2(60.0, -124.0),
		Vector2(62.0, -115.0),
		Vector2(67.0, -105.0),
		Vector2(72.0, -95.0),
	], [6.4, 5.8, 5.0, 4.4, 3.8])
	if river_mesh != null:
		river_mesh.surface_set_material(0, _create_water_material(0.055, 0.79))
		_spawn_visual(pool, "River", river_mesh, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)

	# Rocas de ribera del mismo kit Quaternius que el bosque.
	for index in 8:
		var angle := TAU * float(index) / 8.0 + 0.22
		var radius := Vector2(18.2, 13.0)
		var point := Vector2(64.0, -142.5) + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		_spawn_visual(
			pool,
			"PoolBankRock%02d" % index,
			_rock_face_mesh,
			Vector3(point.x, _height_at(point) - 0.3, point.y),
			Vector3(0.0, -angle + PI * 0.5, 0.0),
			Vector3(0.75 + index % 3 * 0.12, 0.62 + index % 2 * 0.13, 0.72)
		)


func _build_fortress() -> void:
	var fort_base := landmark_ground_height + 38.0
	var tower_mesh: Mesh = _fort_meshes.get("tower_round") as Mesh
	var wall_mesh: Mesh = _fort_meshes.get("wall_thick_straight_01") as Mesh
	var gate_mesh: Mesh = _fort_meshes.get("wall_thin_gate_01") as Mesh
	var corner_mesh: Mesh = _fort_meshes.get("wall_thick_corner_01") as Mesh

	# Solo se extraen y colocan estos módulos: no se instancia la lámina completa
	# del pack, que incluye todas las piezas separadas sobre una cuadrícula.
	_spawn_fort_piece("WestTower", corner_mesh, Vector3(46.0, fort_base, -163.0), 0.0, Vector3.ONE * 2.8)
	_spawn_fort_piece("WestTowerRoof", tower_mesh, Vector3(46.0, fort_base + 8.0, -163.0), 0.0, Vector3.ONE * 2.6)
	_spawn_fort_piece("EastTower", corner_mesh, Vector3(80.0, fort_base, -163.0), 0.0, Vector3.ONE * 2.8)
	_spawn_fort_piece("EastTowerRoof", tower_mesh, Vector3(80.0, fort_base + 8.0, -163.0), 0.0, Vector3.ONE * 2.6)
	_spawn_fort_piece("WallWest", wall_mesh, Vector3(51.0, fort_base, -158.0), PI * 0.5, Vector3.ONE * 2.8)
	_spawn_fort_piece("WallEast", wall_mesh, Vector3(72.0, fort_base, -158.0), PI * 0.5, Vector3.ONE * 2.8)
	_spawn_fort_piece("CentralGate", gate_mesh, Vector3(63.0, fort_base, -153.0), PI * 0.5, Vector3.ONE * 3.2)
	_spawn_fort_piece("RearCorner", wall_mesh, Vector3(63.0, fort_base, -171.0), 0.0, Vector3.ONE * 2.8)

	_add_box_collider(
		fortress,
		"FortressCollision",
		Vector3(64.0, fort_base + 5.2, -162.0),
		Vector3(48.0, 11.0, 20.0),
		0.0
	)
	_add_fortress_beacon(Vector3(47.0, fort_base + 11.2, -158.0))
	_add_fortress_beacon(Vector3(79.0, fort_base + 11.2, -158.0))


func _build_fallen_timber() -> void:
	var timber_layout: Array[Array] = [
		[Vector2(47.0, -137.0), -0.18, 1.8],
		[Vector2(79.0, -134.0), 0.32, 1.55],
		[Vector2(84.0, -150.0), -0.52, 1.35],
	]
	for index in timber_layout.size():
		var entry := timber_layout[index]
		var point: Vector2 = entry[0]
		_spawn_visual(
			pool,
			"FallenTrunk%02d" % index,
			_dead_tree_mesh,
			Vector3(point.x, _height_at(point) + 0.18, point.y),
			Vector3(0.0, entry[1], 0.06),
			Vector3.ONE * float(entry[2])
		)
	for index in 4:
		var point := Vector2(51.0 + index * 9.0, -130.0 - (index % 2) * 4.0)
		_spawn_visual(
			pool,
			"TreeStump%02d" % index,
			_stump_mesh,
			Vector3(point.x, _height_at(point), point.y),
			Vector3(0.0, index * 1.41, 0.0),
			Vector3.ONE * (1.1 + index * 0.12)
		)


func _spawn_fort_piece(piece_name: String, mesh: Mesh, piece_position: Vector3, yaw: float, piece_scale: Vector3) -> void:
	if mesh == null:
		push_warning("No se encontró el módulo de fortaleza: %s" % piece_name)
		return
	_spawn_visual(fortress, piece_name, mesh, piece_position, Vector3(0.0, yaw, 0.0), piece_scale)
	fortress_piece_count += 1


func _spawn_visual(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	visual_position: Vector3,
	visual_rotation: Vector3,
	visual_scale: Vector3,
	shadows := true
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = visual_position
	instance.rotation = visual_rotation
	instance.scale = visual_scale
	instance.visibility_range_end = 900.0
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(instance)
	return instance


func _add_box_collider(parent: Node3D, node_name: String, body_position: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = body_position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _add_mist_volume() -> void:
	var fog_material := FogMaterial.new()
	fog_material.density = 0.20
	fog_material.albedo = Color(0.72, 0.84, 0.88, 1.0)
	fog_material.emission = Color(0.035, 0.055, 0.07, 1.0)
	fog_material.edge_fade = 0.52
	fog_material.height_falloff = 0.36
	var fog := FogVolume.new()
	fog.name = "WaterfallMist"
	fog.position = Vector3(64.0, landmark_ground_height + 2.2, -146.5)
	fog.size = Vector3(28.0, 7.0, 22.0)
	fog.material = fog_material
	waterfall.add_child(fog)


func _add_spray_particles(
	node_name: String,
	particle_position: Vector3,
	amount: int,
	lifetime: float,
	extents: Vector3,
	upward: bool
) -> void:
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = extents
	process_material.direction = Vector3(0.0, 1.0 if upward else -0.35, 0.18)
	process_material.spread = 62.0 if upward else 38.0
	process_material.initial_velocity_min = 0.55 if upward else 0.25
	process_material.initial_velocity_max = 2.4 if upward else 1.1
	process_material.gravity = Vector3(0.0, -0.32 if upward else -0.72, 0.0)
	process_material.scale_min = 0.65
	process_material.scale_max = 2.25
	process_material.color = Color(0.82, 0.93, 0.97, 0.42)

	var particle_material := StandardMaterial3D.new()
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_material.albedo_color = Color(0.84, 0.94, 1.0, 0.32)
	particle_material.vertex_color_use_as_albedo = true
	var card := QuadMesh.new()
	card.size = Vector2(1.7, 1.15)
	card.material = particle_material

	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.position = particle_position
	particles.amount = amount
	particles.lifetime = lifetime
	particles.randomness = 0.72
	particles.process_material = process_material
	particles.draw_pass_1 = card
	particles.visibility_aabb = AABB(Vector3(-12.0, -5.0, -9.0), Vector3(24.0, 18.0, 18.0))
	waterfall.add_child(particles)


func _create_water_material(wave_height: float, opacity: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LAKE_SHADER
	material.set_shader_parameter("wave_height", wave_height)
	material.set_shader_parameter("opacity", opacity)
	return material


func _create_river_mesh(points: Array[Vector2], widths: Array[float]) -> ArrayMesh:
	if points.size() < 2 or points.size() != widths.size():
		return null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left_edges: Array[Vector3] = []
	var right_edges: Array[Vector3] = []
	for index in points.size():
		var direction := (
			points[1] - points[0]
			if index == 0
			else points[index] - points[index - 1]
		)
		if index > 0 and index < points.size() - 1:
			direction = points[index + 1] - points[index - 1]
		direction = direction.normalized()
		var side := Vector2(-direction.y, direction.x) * widths[index] * 0.5
		var water_height := _height_at(points[index]) + 0.23
		left_edges.append(Vector3(points[index].x + side.x, water_height, points[index].y + side.y))
		right_edges.append(Vector3(points[index].x - side.x, water_height, points[index].y - side.y))

	for index in points.size() - 1:
		var v0 := float(index) / float(points.size() - 1)
		var v1 := float(index + 1) / float(points.size() - 1)
		_add_surface_vertex(surface, left_edges[index], Vector2(0.0, v0 * 5.0))
		_add_surface_vertex(surface, left_edges[index + 1], Vector2(0.0, v1 * 5.0))
		_add_surface_vertex(surface, right_edges[index], Vector2(1.0, v0 * 5.0))
		_add_surface_vertex(surface, right_edges[index], Vector2(1.0, v0 * 5.0))
		_add_surface_vertex(surface, left_edges[index + 1], Vector2(0.0, v1 * 5.0))
		_add_surface_vertex(surface, right_edges[index + 1], Vector2(1.0, v1 * 5.0))
	return surface.commit()


func _add_surface_vertex(surface: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _add_fortress_beacon(beacon_position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "Beacon"
	light.position = beacon_position
	light.light_color = Color(1.0, 0.42, 0.12, 1.0)
	light.light_energy = 3.4
	light.omni_range = 18.0
	light.shadow_enabled = false
	fortress.add_child(light)

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = Color(1.0, 0.25, 0.035, 1.0)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.15, 0.02, 1.0)
	glow_material.emission_energy_multiplier = 4.5
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.32
	glow_mesh.height = 0.64
	glow_mesh.material = glow_material
	var glow := MeshInstance3D.new()
	glow.name = "BeaconGlow"
	glow.position = beacon_position
	glow.mesh = glow_mesh
	fortress.add_child(glow)


func _load_quaternius_mesh(file_name: String) -> Mesh:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := QUATERNIUS_ROOT + file_name
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el módulo Quaternius: %s (%s)" % [path, error_string(error)])
		return null
	var instance := document.generate_scene(state)
	var result := _find_mesh(instance, "")
	instance.free()
	return result


func _find_mesh(node: Node, name_fragment: String) -> Mesh:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if name_fragment.is_empty() or name_fragment.to_lower() in String(mesh_instance.name).to_lower():
			return mesh_instance.mesh
	for child in node.get_children():
		var result := _find_mesh(child, name_fragment)
		if result != null:
			return result
	return null


func _height_at(point: Vector2) -> float:
	if _terrain == null or _terrain.data == null:
		return landmark_ground_height
	# La composición completa puede desplazarse desde world.tscn sin perder el
	# apoyo correcto sobre Terrain3D. `point` está en espacio local del hito.
	var world_point := to_global(Vector3(point.x, 0.0, point.y))
	var height := _terrain.data.get_height(world_point)
	return landmark_ground_height if is_nan(height) else height
