class_name VegetationScatter
extends Node3D

## Bosque PBR determinista construido con pinos game-ready y sotobosque
## escaneado. Cada especie se divide en celdas para que Godot oculte sectores
## completos y evite un único MultiMesh gigante.

const PINE_SCENE: PackedScene = preload("res://assets/models/realistic_pines/pine_trees_lolipop_1k.glb")
const GRASS_SCENE: PackedScene = preload("res://assets/models/photorealistic/grass_medium_01/grass_medium_01_1k.gltf")
const BERMUDA_SCENE: PackedScene = preload("res://assets/models/photorealistic/grass_bermuda_01/grass_bermuda_01_1k.gltf")
const FERN_SCENE: PackedScene = preload("res://assets/models/photorealistic/fern_02/fern_02_1k.gltf")
const SHRUB_SCENE: PackedScene = preload("res://assets/models/photorealistic/shrub_03/shrub_03_1k.gltf")
const ROCK_SCENE: PackedScene = preload("res://assets/models/photorealistic/rock_moss_set_01/rock_moss_set_01_1k.gltf")
const DEAD_TRUNK_SCENE: PackedScene = preload("res://assets/models/photorealistic/dead_tree_trunk/dead_tree_trunk_1k.gltf")
const STUMP_SCENE: PackedScene = preload("res://assets/models/photorealistic/tree_stump_01/tree_stump_01_1k.gltf")

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
const EPIC_LANDMARK := Vector2(16.0, -155.0)
const PINE_VARIANTS: Array[String] = [
	"Pine_large_1",
	"Pine_large_2",
	"Pine_large_3",
	"Pine_big_1",
	"Pine_big_2",
	"Pine_big_3",
	"Pine_medium_1",
	"Pine_medium_2",
	"Pine_medium_3",
]
const TREE_CELL_SIZE := 96.0
const DETAIL_CELL_SIZE := 80.0
const GRASS_CELL_SIZE := 72.0

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export_category("Densidad PBR")
@export var tree_count := 340
@export var rock_count := 170
@export var grass_count := 7000
@export var bermuda_grass_count := 32000
@export var fern_count := 800
@export var shrub_count := 900
@export var forest_detail_count := 42
@export var random_seed := 731947

@onready var terrain: Terrain3D = get_node(terrain_path) as Terrain3D

var generated_tree_count := 0
var generated_rock_count := 0
var generated_grass_count := 0
var generated_bermuda_grass_count := 0
var generated_fern_count := 0
var generated_shrub_count := 0
var generated_cell_count := 0
var tree_positions: Array[Vector3] = []

var _random := RandomNumberGenerator.new()
var _tree_meshes: Array[Mesh] = []
var _grass_meshes: Array[Mesh] = []
var _bermuda_meshes: Array[Mesh] = []
var _fern_meshes: Array[Mesh] = []
var _shrub_meshes: Array[Mesh] = []
var _rock_meshes: Array[Mesh] = []
var _dead_trunk_meshes: Array[Mesh] = []
var _stump_meshes: Array[Mesh] = []


func _ready() -> void:
	_random.seed = random_seed
	_tree_meshes = _extract_pine_meshes(PINE_SCENE)
	_grass_meshes = _extract_meshes(GRASS_SCENE)
	_bermuda_meshes = _extract_meshes(BERMUDA_SCENE)
	_fern_meshes = _extract_meshes(FERN_SCENE)
	_shrub_meshes = _extract_meshes(SHRUB_SCENE)
	_rock_meshes = _extract_meshes(ROCK_SCENE)
	_dead_trunk_meshes = _extract_meshes(DEAD_TRUNK_SCENE)
	_stump_meshes = _extract_meshes(STUMP_SCENE)

	_scatter_forest()
	_scatter_rocks()
	_scatter_ground_cover()
	_scatter_forest_details()
	print(
		"PBR SCATTER READY: %d pinos, %d rocas, %d matas, %d briznas Bermuda, %d helechos, %d arbustos en %d celdas."
		% [generated_tree_count, generated_rock_count, generated_grass_count, generated_bermuda_grass_count, generated_fern_count, generated_shrub_count, generated_cell_count]
	)


func _scatter_forest() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_tree_count < tree_count and attempts < tree_count * 28:
		attempts += 1
		var point := _corridor_point(8.0, 56.0, 0.90)
		if (
			distance_to_route(point) < 7.4
			or _inside_clearing(point, 10.5, 21.0)
			or point.distance_to(EPIC_LANDMARK) < 35.0
		):
			continue
		if _slope_at(point) > 0.72:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue

		# Predominan árboles grandes y medianos; las tres variantes de 30 m se
		# reservan para una quinta parte del bosque y construyen la silueta épica.
		var size_roll := _random.randf()
		var variant := _random.randi_range(0, 2)
		if size_roll >= 0.20 and size_roll < 0.68:
			variant = _random.randi_range(3, 5)
		elif size_roll >= 0.68:
			variant = _random.randi_range(6, 8)
		var scale_value := _random.randf_range(0.72, 1.08)
		var position := Vector3(point.x, height + 0.02, point.y)
		var transform := _make_pine_transform(position, _random.randf_range(0.0, TAU), scale_value)
		_bucket_transform(buckets, variant, point, TREE_CELL_SIZE, transform)
		tree_positions.append(position)
		# El pack fuente es Z-up; la corrección de eje de `_make_pine_transform`
		# convierte esta dimensión en altura mundial.
		var tree_height := _tree_meshes[variant].get_aabb().size.z * scale_value
		_add_tree_collision(position, tree_height, scale_value)
		generated_tree_count += 1

	_install_cell_buckets("TreeCells", buckets, _tree_meshes, 360.0, true)


func _scatter_rocks() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_rock_count < rock_count and attempts < rock_count * 22:
		attempts += 1
		var point := _corridor_point(6.0, 92.0, 0.66)
		if distance_to_route(point) < 5.4 or _inside_clearing(point, 10.0, 17.0):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _rock_meshes.size() - 1)
		var scale_value := _random.randf_range(0.42, 1.08)
		var squash := Vector3(
			scale_value * _random.randf_range(0.8, 1.22),
			scale_value * _random.randf_range(0.72, 1.08),
			scale_value * _random.randf_range(0.78, 1.26)
		)
		var position := Vector3(point.x, height - 0.12 * scale_value, point.y)
		_bucket_transform(
			buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), squash)
		)
		_add_rock_collision(position, _rock_meshes[variant].get_aabb().size * squash)
		generated_rock_count += 1

	_install_cell_buckets("RockCells", buckets, _rock_meshes, 260.0, true)


func _scatter_ground_cover() -> void:
	var grass_buckets: Dictionary = {}
	var grass_variants: Array[Mesh] = []
	# Cinco siluetas bastan para variar el tapiz sin multiplicar draw calls.
	for index in [0, 2, 3, 8, 9]:
		grass_variants.append(_grass_meshes[index])

	var attempts := 0
	while generated_grass_count < grass_count and attempts < grass_count * 12:
		attempts += 1
		var point := _corridor_point(2.7, 44.0, 0.94)
		if distance_to_route(point) < 2.55 or _inside_clearing(point, 4.2, 8.5):
			continue
		if _slope_at(point) > 0.82:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, grass_variants.size() - 1)
		var scale_value := _random.randf_range(3.0, 5.4)
		_bucket_transform(
			grass_buckets,
			variant,
			point,
			GRASS_CELL_SIZE,
			_make_transform(
				Vector3(point.x, height + 0.015, point.y),
				_random.randf_range(0.0, TAU),
				Vector3(scale_value * _random.randf_range(0.8, 1.2), scale_value, scale_value * _random.randf_range(0.8, 1.2))
			)
		)
		generated_grass_count += 1
	_install_cell_buckets("GrassCells", grass_buckets, grass_variants, 105.0, false)

	# Una segunda especie extremadamente ligera (decenas de vértices por mata)
	# forma el tapiz continuo que faltaba entre los clumps grandes.
	var bermuda_variants: Array[Mesh] = [
		_bermuda_meshes[3],
		_bermuda_meshes[5],
		_bermuda_meshes[9],
		_bermuda_meshes[12],
	]
	var bermuda_buckets: Dictionary = {}
	attempts = 0
	while generated_bermuda_grass_count < bermuda_grass_count and attempts < bermuda_grass_count * 10:
		attempts += 1
		var point := _corridor_point(2.15, 47.0, 0.96)
		if distance_to_route(point) < 2.0 or _inside_clearing(point, 3.7, 7.5):
			continue
		if _slope_at(point) > 0.84:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, bermuda_variants.size() - 1)
		var scale_value := _random.randf_range(4.5, 8.5)
		_bucket_transform(
			bermuda_buckets,
			variant,
			point,
			GRASS_CELL_SIZE,
			_make_transform(
				Vector3(point.x, height + 0.012, point.y),
				_random.randf_range(0.0, TAU),
				Vector3(scale_value * _random.randf_range(0.78, 1.24), scale_value, scale_value * _random.randf_range(0.78, 1.24))
			)
		)
		generated_bermuda_grass_count += 1
	_install_cell_buckets("MeadowGrassCells", bermuda_buckets, bermuda_variants, 92.0, false)

	var fern_buckets: Dictionary = {}
	attempts = 0
	while generated_fern_count < fern_count and attempts < fern_count * 14:
		attempts += 1
		var point := _corridor_point(2.4, 62.0, 0.87)
		if distance_to_route(point) < 2.0 or _inside_clearing(point, 5.2, 9.5):
			continue
		if _slope_at(point) > 0.78:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _fern_meshes.size() - 1)
		var scale_value := _random.randf_range(1.45, 2.65)
		_bucket_transform(
			fern_buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(Vector3(point.x, height + 0.02, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		)
		generated_fern_count += 1
	_install_cell_buckets("FernCells", fern_buckets, _fern_meshes, 140.0, true)

	var shrub_buckets: Dictionary = {}
	attempts = 0
	while generated_shrub_count < shrub_count and attempts < shrub_count * 14:
		attempts += 1
		var point := _corridor_point(3.7, 70.0, 0.84)
		if distance_to_route(point) < 3.2 or _inside_clearing(point, 6.5, 11.0):
			continue
		if _slope_at(point) > 0.76:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _shrub_meshes.size() - 1)
		var scale_value := _random.randf_range(1.8, 3.45)
		_bucket_transform(
			shrub_buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(Vector3(point.x, height + 0.015, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		)
		generated_shrub_count += 1
	_install_cell_buckets("ShrubCells", shrub_buckets, _shrub_meshes, 155.0, true)


func _scatter_forest_details() -> void:
	var detail_meshes: Array[Mesh] = [_dead_trunk_meshes[0], _stump_meshes[0]]
	var buckets: Dictionary = {}
	var created := 0
	var attempts := 0
	while created < forest_detail_count and attempts < forest_detail_count * 20:
		attempts += 1
		var point := _corridor_point(5.5, 48.0, 0.9)
		if distance_to_route(point) < 4.8 or _inside_clearing(point, 9.0, 15.0):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := created % 2
		var scale_value := _random.randf_range(0.8, 1.55)
		_bucket_transform(
			buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(Vector3(point.x, height + 0.03, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		)
		created += 1
	_install_cell_buckets("ForestDetailCells", buckets, detail_meshes, 190.0, true)


func _extract_meshes(scene: PackedScene) -> Array[Mesh]:
	var result: Array[Mesh] = []
	var source := scene.instantiate()
	var pending: Array[Node] = [source]
	while not pending.is_empty():
		var node: Node = pending.pop_back() as Node
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				result.append(mesh)
		for child in node.get_children():
			pending.append(child)
	source.free()
	return result


func _extract_pine_meshes(scene: PackedScene) -> Array[Mesh]:
	# El pack trae Bark y Clusters separados para cada LOD. Se combinan las dos
	# superficies del LOD1 de cada variante, conservando sus materiales PBR.
	var result: Array[Mesh] = []
	var source := scene.instantiate()
	for variant_name in PINE_VARIANTS:
		var bark := _find_mesh_fragment(source, variant_name + "_LOD1_Bark")
		var clusters := _find_mesh_fragment(source, variant_name + "_LOD1_Clusters")
		if bark == null or clusters == null:
			push_error("Falta una superficie del pino game-ready: %s" % variant_name)
			continue
		result.append(_combine_mesh_surfaces([bark, clusters]))
	source.free()
	return result


func _find_mesh_fragment(node: Node, fragment: String) -> Mesh:
	if node is MeshInstance3D and fragment in String(node.name):
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var match := _find_mesh_fragment(child, fragment)
		if match != null:
			return match
	return null


func _combine_mesh_surfaces(source_meshes: Array[Mesh]) -> ArrayMesh:
	var combined := ArrayMesh.new()
	for source in source_meshes:
		for surface_index in source.get_surface_count():
			combined.add_surface_from_arrays(
				source.surface_get_primitive_type(surface_index),
				source.surface_get_arrays(surface_index)
			)
			var combined_surface := combined.get_surface_count() - 1
			combined.surface_set_material(combined_surface, source.surface_get_material(surface_index))
	return combined


func _bucket_transform(
	buckets: Dictionary,
	variant: int,
	point: Vector2,
	cell_size: float,
	transform: Transform3D
) -> void:
	var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
	var key := "%d:%d:%d" % [variant, cell.x, cell.y]
	if not buckets.has(key):
		buckets[key] = {"variant": variant, "cell": cell, "transforms": []}
	var transforms: Array = buckets[key]["transforms"]
	transforms.append(transform)


func _install_cell_buckets(
	root_name: String,
	buckets: Dictionary,
	meshes: Array[Mesh],
	visibility_distance: float,
	shadows: bool
) -> void:
	var category := Node3D.new()
	category.name = root_name
	add_child(category)
	var keys := buckets.keys()
	keys.sort()
	for key in keys:
		var bucket: Dictionary = buckets[key]
		var transforms: Array = bucket["transforms"]
		var variant: int = bucket["variant"]
		var cell: Vector2i = bucket["cell"]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[variant]
		multimesh.instance_count = transforms.size()
		for index in transforms.size():
			multimesh.set_instance_transform(index, transforms[index])

		var instance := MultiMeshInstance3D.new()
		instance.name = "Cell_%d_%d_v%d" % [cell.x, cell.y, variant]
		instance.multimesh = multimesh
		instance.visibility_range_end = visibility_distance
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		category.add_child(instance)
		generated_cell_count += 1


func _make_transform(position: Vector3, yaw: float, scale_value: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale_value), position)


func _make_pine_transform(position: Vector3, yaw: float, scale_value: float) -> Transform3D:
	var axis_correction := Basis(Vector3.RIGHT, -PI * 0.5)
	var basis := Basis(Vector3.UP, yaw) * axis_correction
	basis = basis.scaled(Vector3.ONE * scale_value)
	return Transform3D(basis, position)


func _corridor_point(minimum_offset: float, maximum_offset: float, corridor_chance: float) -> Vector2:
	if _random.randf() > corridor_chance:
		return Vector2(_random.randf_range(-235.0, 235.0), _random.randf_range(-235.0, 235.0))
	var segment_index := _random.randi_range(0, ROUTE.size() - 2)
	var start := ROUTE[segment_index]
	var finish := ROUTE[segment_index + 1]
	var direction := (finish - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var along := start.lerp(finish, _random.randf())
	var side := -1.0 if _random.randf() < 0.5 else 1.0
	var offset := _random.randf_range(minimum_offset, maximum_offset)
	return along + normal * offset * side


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


func _add_tree_collision(base: Vector3, tree_height: float, tree_scale: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = clampf(tree_scale * 0.045, 0.25, 0.52)
	shape.height = maxf(tree_height * 0.72, 3.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * shape.height * 0.5
	_get_collision_body().add_child(collision)


func _add_rock_collision(base: Vector3, mesh_size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(mesh_size.x * 0.7, 0.5), maxf(mesh_size.y * 0.75, 0.4), maxf(mesh_size.z * 0.7, 0.5))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * shape.size.y * 0.38
	_get_collision_body().add_child(collision)


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
