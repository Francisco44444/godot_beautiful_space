class_name VegetationScatter
extends Node3D

## Scattering determinista y barato: miles de elementos se dibujan mediante
## MultiMesh, pero las zonas de paso, inicio y mirador permanecen despejadas.

const BARK_ALBEDO: Texture2D = preload("res://assets/textures/realistic/pine_bark_albedo.png")
const BARK_NORMAL: Texture2D = preload("res://assets/textures/realistic/pine_bark_normal_roughness.png")
const PINE_BRANCH: Texture2D = preload("res://assets/textures/realistic/pine_branch_albedo.png")
const ROCK_ALBEDO: Texture2D = preload("res://assets/textures/cc0/polyhaven/mossy_rock/albedo.jpg")
const ROCK_NORMAL: Texture2D = preload("res://assets/textures/cc0/polyhaven/mossy_rock/normal_roughness.png")
const FOLIAGE_SHADER: Shader = preload("res://shaders/foliage.gdshader")
const GRASS_SHADER: Shader = preload("res://shaders/grass.gdshader")

const ROUTE: Array[Vector2] = [
	Vector2(0.0, 190.0),
	Vector2(-4.0, 95.0),
	Vector2(7.0, 25.0),
	Vector2(22.0, -25.0),
	Vector2(43.0, -58.0),
	Vector2(69.0, -86.0),
	Vector2(98.0, -110.0),
]
const LOOKOUT := Vector2(98.0, -110.0)
const PLAYER_START := Vector2(0.0, 190.0)
const HORSE_START := Vector2(4.0, 180.0)

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export_category("Densidad")
@export var tree_count := 420
@export var rock_count := 190
@export var grass_count := 6200
@export var random_seed := 731947

@onready var terrain: Terrain3D = get_node(terrain_path) as Terrain3D

var generated_tree_count := 0
var generated_rock_count := 0
var generated_grass_count := 0

var _random := RandomNumberGenerator.new()
var _tree_colliders := 0
var _rock_colliders := 0


func _ready() -> void:
	_random.seed = random_seed
	_scatter_forest()
	_scatter_rocks()
	_scatter_grass()
	print(
		"SCATTER READY: %d árboles, %d rocas, %d matas de hierba."
		% [generated_tree_count, generated_rock_count, generated_grass_count]
	)


func _scatter_forest() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.19
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 8
	trunk_mesh.material = _create_bark_material()

	var crown_mesh := QuadMesh.new()
	crown_mesh.size = Vector2(2.0, 2.0)
	crown_mesh.material = _create_foliage_material()

	var trunks: Array[Transform3D] = []
	var trunk_tints: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_tints: Array[Color] = []
	var attempts := 0
	while trunks.size() < tree_count and attempts < tree_count * 16:
		attempts += 1
		var point := _random_point()
		var route_distance := distance_to_route(point)
		if route_distance < 13.0 or _inside_clearing(point, 18.0, 24.0):
			continue
		if _slope_at(point) > 0.78:
			continue

		var height := _height_at(point)
		if is_nan(height):
			continue
		var tree_height := _random.randf_range(6.8, 11.8)
		var width := _random.randf_range(0.82, 1.28)
		var yaw := _random.randf_range(0.0, TAU)
		var base := Vector3(point.x, height, point.y)
		var tint := _random.randf_range(0.82, 1.08)

		trunks.append(_make_transform(base + Vector3.UP * tree_height * 0.5, yaw, Vector3(width, tree_height * 0.5, width)))
		trunk_tints.append(Color(tint, 0.0, 0.0, 1.0))

		# Tres alturas y dos láminas cruzadas por altura forman ramas irregulares.
		# La silueta fotográfica evita el aspecto de cono geométrico sin perder el
		# batching: todo el bosque continúa dentro de un único MultiMesh.
		var crown_layers := [
			Vector3(width * 1.75, tree_height * 0.18, width * 1.75),
			Vector3(width * 1.42, tree_height * 0.16, width * 1.42),
			Vector3(width * 1.02, tree_height * 0.14, width * 1.02),
		]
		var layer_heights := [0.60, 0.77, 0.91]
		for layer in crown_layers.size():
			for card_yaw in [yaw, yaw + PI * 0.5]:
				crowns.append(_make_transform(base + Vector3.UP * tree_height * layer_heights[layer], card_yaw, crown_layers[layer]))
				crown_tints.append(Color(tint, 0.0, 0.0, 1.0))

		# Todo tronco visible es sólido, no solo los cercanos al sendero.
		_add_tree_collision(base, tree_height, width)

	_install_multimesh("TreeTrunks", trunk_mesh, trunks, trunk_tints, 430.0, true)
	_install_multimesh("TreeCrowns", crown_mesh, crowns, crown_tints, 430.0, true)
	generated_tree_count = trunks.size()


func _scatter_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 9
	rock_mesh.rings = 5
	rock_mesh.material = _create_rock_material()

	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var attempts := 0
	while transforms.size() < rock_count and attempts < rock_count * 14:
		attempts += 1
		var point := _random_point()
		var route_distance := distance_to_route(point)
		if route_distance < 6.5 or _inside_clearing(point, 12.0, 18.0):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue

		var scale := Vector3(
			_random.randf_range(0.55, 1.9),
			_random.randf_range(0.42, 1.3),
			_random.randf_range(0.65, 2.15)
		)
		var yaw := _random.randf_range(0.0, TAU)
		var base := Vector3(point.x, height + scale.y * 0.55, point.y)
		transforms.append(_make_transform(base, yaw, scale))
		tints.append(Color(_random.randf_range(0.82, 1.08), 0.0, 0.0, 1.0))
		# Toda roca visible bloquea al jugador y a la montura.
		_add_rock_collision(base, scale)

	_install_multimesh("Rocks", rock_mesh, transforms, tints, 320.0, true)
	generated_rock_count = transforms.size()


func _scatter_grass() -> void:
	var grass_mesh := _create_grass_mesh()
	grass_mesh.surface_set_material(0, _create_grass_material())
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var attempts := 0
	while transforms.size() < grass_count and attempts < grass_count * 9:
		attempts += 1
		var point := _random_point()
		if distance_to_route(point) < 3.2 or _inside_clearing(point, 7.0, 13.0):
			continue
		if _slope_at(point) > 0.92:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var scale := _random.randf_range(0.58, 1.38)
		var transform := _make_transform(
			Vector3(point.x, height + 0.035, point.y),
			_random.randf_range(0.0, TAU),
			Vector3(scale, scale, scale)
		)
		transforms.append(transform)
		tints.append(Color(_random.randf_range(0.78, 1.12), 0.0, 0.0, 1.0))

	_install_multimesh("Grass", grass_mesh, transforms, tints, 115.0, false)
	generated_grass_count = transforms.size()


func _install_multimesh(
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	custom_data: Array[Color],
	visibility_distance: float,
	shadows: bool
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_custom_data(index, custom_data[index])

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.visibility_range_end = visibility_distance
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	add_child(instance)


func _create_bark_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = BARK_ALBEDO
	material.roughness = 0.92
	material.normal_enabled = true
	material.normal_texture = BARK_NORMAL
	material.normal_scale = 0.58
	return material


func _create_rock_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ROCK_ALBEDO
	material.albedo_color = Color(0.78, 0.8, 0.82, 1.0)
	material.roughness = 0.86
	material.normal_enabled = true
	material.normal_texture = ROCK_NORMAL
	material.normal_scale = 0.72
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(0.72, 0.72, 0.72)
	return material


func _create_foliage_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter("foliage_texture", PINE_BRANCH)
	return material


func _create_grass_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	return material


func _create_grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		var right := Vector3(cos(angle), 0.0, sin(angle)) * 0.16
		var vertices := [-right, right, -right + Vector3.UP * 0.85, right + Vector3.UP * 0.85]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
		for index in [0, 2, 1, 1, 2, 3]:
			surface.set_uv(uvs[index])
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertices[index])
	return surface.commit()


func _make_transform(position: Vector3, yaw: float, scale: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale), position)


func _random_point() -> Vector2:
	return Vector2(_random.randf_range(-238.0, 238.0), _random.randf_range(-238.0, 238.0))


func _height_at(point: Vector2) -> float:
	return terrain.data.get_height(Vector3(point.x, 0.0, point.y))


func _slope_at(point: Vector2) -> float:
	var center := _height_at(point)
	var east := _height_at(point + Vector2(1.5, 0.0))
	var north := _height_at(point + Vector2(0.0, 1.5))
	if is_nan(center) or is_nan(east) or is_nan(north):
		return INF
	return maxf(absf(east - center), absf(north - center)) / 1.5


func distance_to_route(point: Vector2) -> float:
	var best_distance := INF
	for index in ROUTE.size() - 1:
		var start := ROUTE[index]
		var finish := ROUTE[index + 1]
		var segment := finish - start
		var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		best_distance = minf(best_distance, point.distance_to(start + segment * progress))
	return best_distance


func _inside_clearing(point: Vector2, start_radius: float, lookout_radius: float) -> bool:
	return (
		point.distance_to(PLAYER_START) < start_radius
		or point.distance_to(HORSE_START) < start_radius
		or point.distance_to(LOOKOUT) < lookout_radius
	)


func _add_tree_collision(base: Vector3, tree_height: float, width: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 0.32 * width
	shape.height = tree_height * 0.5
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * shape.height * 0.5
	_get_collision_body().add_child(collision)
	_tree_colliders += 1


func _add_rock_collision(center: Vector3, scale: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = scale * 1.35
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	_get_collision_body().add_child(collision)
	_rock_colliders += 1


func _get_collision_body() -> StaticBody3D:
	var existing := get_node_or_null("DecorCollisions") as StaticBody3D
	if existing != null:
		return existing
	var body := StaticBody3D.new()
	body.name = "DecorCollisions"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	return body
