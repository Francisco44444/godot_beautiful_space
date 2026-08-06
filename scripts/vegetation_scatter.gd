class_name VegetationScatter
extends Node3D

## Valle estilizado construido exclusivamente con el Stylized Nature Mega Kit
## de Quaternius. Los modelos se cargan desde glTF y se agrupan por celdas en
## MultiMesh para mantener claros amplios y masas de bosque legibles sin
## disparar los draw calls.

const ASSET_ROOT := "res://assets/quaternius/store_bundle/glTF/"
const GREEN_TREE_FILES: PackedStringArray = [
	"CommonTree_1.gltf", "CommonTree_2.gltf", "CommonTree_3.gltf",
	"CommonTree_4.gltf", "CommonTree_5.gltf", "Pine_1.gltf", "Pine_2.gltf", "Pine_3.gltf",
	"Pine_4.gltf", "Pine_5.gltf",
]
const AUTUMN_TREE_FILES: PackedStringArray = [
	"TwistedTree_1.gltf", "TwistedTree_2.gltf", "TwistedTree_3.gltf",
	"TwistedTree_4.gltf", "TwistedTree_5.gltf",
]
const ROCK_FILES: PackedStringArray = [
	"Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf",
]
const GRASS_FILES: PackedStringArray = [
	"Grass_Common_Short.gltf", "Grass_Common_Tall.gltf",
	"Grass_Wispy_Short.gltf", "Grass_Wispy_Tall.gltf",
]
const FERN_FILES: PackedStringArray = [
	"Fern_1.gltf", "Plant_1.gltf", "Plant_1_Big.gltf",
	"Plant_7.gltf", "Plant_7_Big.gltf", "Clover_1.gltf", "Clover_2.gltf",
]
const SHRUB_FILES: PackedStringArray = ["Bush_Common.gltf", "Bush_Common_Flowers.gltf"]
const FLOWER_FILES: PackedStringArray = [
	"Flower_3_Group.gltf", "Flower_3_Single.gltf",
	"Flower_4_Group.gltf", "Flower_4_Single.gltf",
]
const MUSHROOM_FILES: PackedStringArray = ["Mushroom_Common.gltf", "Mushroom_Laetiporus.gltf"]
const DEAD_TREE_FILES: PackedStringArray = [
	"DeadTree_1.gltf", "DeadTree_2.gltf", "DeadTree_3.gltf",
	"DeadTree_4.gltf", "DeadTree_5.gltf",
]
const PEBBLE_FILES: PackedStringArray = [
	"Pebble_Round_1.gltf", "Pebble_Round_2.gltf", "Pebble_Round_3.gltf",
	"Pebble_Round_4.gltf", "Pebble_Round_5.gltf", "Pebble_Square_1.gltf",
	"Pebble_Square_2.gltf", "Pebble_Square_3.gltf", "Pebble_Square_4.gltf",
	"Pebble_Square_5.gltf", "Pebble_Square_6.gltf",
]

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
const VILLAGE_CLEARINGS: Array[Vector3] = [
	Vector3(-18.0, 168.0, 27.0),
	Vector3(-94.0, 52.0, 31.0),
	Vector3(126.0, -32.0, 30.0),
]
const TREE_CELL_SIZE := 92.0
const DETAIL_CELL_SIZE := 68.0
const GROUND_CELL_SIZE := 56.0

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export_category("Claro y bosque Quaternius")
@export var tree_count := 760
@export_range(0.0, 0.15, 0.001) var autumn_tree_ratio := 0.004
@export var rock_count := 220
@export var grass_count := 14000
@export var fern_count := 520
@export var shrub_count := 620
@export var flower_count := 1500
@export var mushroom_count := 190
@export var path_pebble_count := 720
@export var forest_detail_count := 32
@export var random_seed := 731947

@onready var terrain: Terrain3D = get_node(terrain_path) as Terrain3D

var generated_tree_count := 0
var generated_rock_count := 0
var generated_grass_count := 0
var generated_fern_count := 0
var generated_shrub_count := 0
var generated_flower_count := 0
var generated_mushroom_count := 0
var generated_path_pebble_count := 0
var generated_cell_count := 0
var generated_green_tree_count := 0
var generated_autumn_tree_count := 0
var tree_positions: Array[Vector3] = []

var _random := RandomNumberGenerator.new()
var _tree_meshes: Array[Mesh] = []
var _rock_meshes: Array[Mesh] = []
var _grass_meshes: Array[Mesh] = []
var _fern_meshes: Array[Mesh] = []
var _shrub_meshes: Array[Mesh] = []
var _flower_meshes: Array[Mesh] = []
var _mushroom_meshes: Array[Mesh] = []
var _dead_tree_meshes: Array[Mesh] = []
var _pebble_meshes: Array[Mesh] = []


func _ready() -> void:
	_random.seed = random_seed
	var green_tree_meshes := _load_mesh_library(GREEN_TREE_FILES)
	var autumn_tree_meshes := _load_mesh_library(AUTUMN_TREE_FILES)
	_tree_meshes = green_tree_meshes.duplicate()
	_tree_meshes.append_array(autumn_tree_meshes)
	_rock_meshes = _load_mesh_library(ROCK_FILES)
	_grass_meshes = _load_mesh_library(GRASS_FILES)
	_fern_meshes = _load_mesh_library(FERN_FILES)
	_shrub_meshes = _load_mesh_library(SHRUB_FILES)
	_flower_meshes = _load_mesh_library(FLOWER_FILES)
	_mushroom_meshes = _load_mesh_library(MUSHROOM_FILES)
	_dead_tree_meshes = _load_mesh_library(DEAD_TREE_FILES)
	_pebble_meshes = _load_mesh_library(PEBBLE_FILES)
	if (
		_tree_meshes.is_empty() or _rock_meshes.is_empty() or _grass_meshes.is_empty()
		or _fern_meshes.is_empty() or _shrub_meshes.is_empty() or _flower_meshes.is_empty()
		or _mushroom_meshes.is_empty() or _dead_tree_meshes.is_empty() or _pebble_meshes.is_empty()
	):
		push_error("No se pudo cargar la biblioteca visual Quaternius completa.")
		return

	_scatter_forest()
	_scatter_rocks()
	_scatter_ground_cover()
	_scatter_color_details()
	_scatter_path_pebbles()
	_scatter_forest_details()
	print(
		"QUATERNIUS VALLEY READY: %d árboles verdes, %d otoñales, %d rocas, %d hierbas, %d helechos, %d arbustos, %d flores, %d setas y %d guijarros en %d celdas."
		% [generated_green_tree_count, generated_autumn_tree_count, generated_rock_count, generated_grass_count, generated_fern_count, generated_shrub_count, generated_flower_count, generated_mushroom_count, generated_path_pebble_count, generated_cell_count]
	)


func _scatter_forest() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_tree_count < tree_count and attempts < tree_count * 34:
		attempts += 1
		var point := _corridor_point(17.0, 138.0, 0.68)
		if (
			distance_to_route(point) < 11.5
			or _inside_clearing(point, 13.5, 23.0)
			or _inside_village_clearing(point, 5.0)
			or point.distance_to(EPIC_LANDMARK) < 37.0
			or _slope_at(point) > 0.80
		):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var autumn := _random.randf() < autumn_tree_ratio
		var variant := 0
		if autumn:
			variant = GREEN_TREE_FILES.size() + _random.randi_range(0, AUTUMN_TREE_FILES.size() - 1)
			generated_autumn_tree_count += 1
		else:
			variant = _random.randi_range(0, GREEN_TREE_FILES.size() - 1)
			generated_green_tree_count += 1
		var scale_value := _random.randf_range(1.12, 2.04)
		if variant >= 5 and variant < GREEN_TREE_FILES.size():
			scale_value *= _random.randf_range(1.05, 1.30)
		var position := Vector3(point.x, height + 0.10, point.y)
		_bucket_transform(
			buckets,
			variant,
			point,
			TREE_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		)
		tree_positions.append(position)
		_add_tree_collision(position, _tree_meshes[variant].get_aabb(), scale_value)
		generated_tree_count += 1
	_install_cell_buckets("TreeCells", buckets, _tree_meshes, 520.0, true)


func _scatter_rocks() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_rock_count < rock_count and attempts < rock_count * 24:
		attempts += 1
		var point := _corridor_point(5.2, 142.0, 0.62)
		if distance_to_route(point) < 4.8 or _inside_clearing(point, 9.0, 16.0) or _inside_village_clearing(point, -5.0):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _rock_meshes.size() - 1)
		var scale_value := _random.randf_range(0.42, 1.20)
		var scale_vector := Vector3(
			scale_value * _random.randf_range(0.78, 1.30),
			scale_value * _random.randf_range(0.72, 1.08),
			scale_value * _random.randf_range(0.82, 1.26)
		)
		var position := Vector3(point.x, height + 0.03, point.y)
		_bucket_transform(buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(position, _random.randf_range(0.0, TAU), scale_vector))
		_add_rock_collision(position, _rock_meshes[variant].get_aabb().size * scale_vector)
		generated_rock_count += 1
	_install_cell_buckets("RockCells", buckets, _rock_meshes, 310.0, true)


func _scatter_ground_cover() -> void:
	var grass_buckets: Dictionary = {}
	var attempts := 0
	while generated_grass_count < grass_count and attempts < grass_count * 14:
		attempts += 1
		var point := _corridor_point(2.35, 126.0, 0.76)
		if distance_to_route(point) < 1.8 or _inside_clearing(point, 4.3, 8.0) or _slope_at(point) > 0.88:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _grass_meshes.size() - 1)
		var scale_value := _random.randf_range(0.42, 0.88)
		var scale_vector := Vector3(scale_value * _random.randf_range(0.72, 1.28), scale_value, scale_value * _random.randf_range(0.72, 1.28))
		_bucket_transform(grass_buckets, variant, point, GROUND_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.02, point.y), _random.randf_range(0.0, TAU), scale_vector))
		generated_grass_count += 1
	_install_cell_buckets("GrassCells", grass_buckets, _grass_meshes, 145.0, false)

	var fern_buckets: Dictionary = {}
	attempts = 0
	while generated_fern_count < fern_count and attempts < fern_count * 16:
		attempts += 1
		var point := _corridor_point(2.8, 132.0, 0.70)
		if distance_to_route(point) < 2.15 or _inside_clearing(point, 5.4, 10.0) or _slope_at(point) > 0.82:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _fern_meshes.size() - 1)
		var scale_value := _random.randf_range(0.30, 0.62) if variant == 0 else _random.randf_range(0.52, 1.10)
		_bucket_transform(fern_buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.03, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_fern_count += 1
	_install_cell_buckets("FernCells", fern_buckets, _fern_meshes, 180.0, true)

	var shrub_buckets: Dictionary = {}
	attempts = 0
	while generated_shrub_count < shrub_count and attempts < shrub_count * 16:
		attempts += 1
		var point := _corridor_point(3.4, 136.0, 0.68)
		if distance_to_route(point) < 2.8 or _inside_clearing(point, 6.2, 11.5) or _slope_at(point) > 0.82:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _shrub_meshes.size() - 1)
		var scale_value := _random.randf_range(0.82, 1.62)
		_bucket_transform(shrub_buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.04, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_shrub_count += 1
	_install_cell_buckets("ShrubCells", shrub_buckets, _shrub_meshes, 200.0, true)


func _scatter_color_details() -> void:
	var flower_buckets: Dictionary = {}
	var attempts := 0
	while generated_flower_count < flower_count and attempts < flower_count * 15:
		attempts += 1
		var point := _corridor_point(1.9, 108.0, 0.78)
		if distance_to_route(point) < 1.45 or _inside_clearing(point, 3.8, 7.0) or _slope_at(point) > 0.84:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _flower_meshes.size() - 1)
		var scale_value := _random.randf_range(0.28, 0.58)
		_bucket_transform(flower_buckets, variant, point, GROUND_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.025, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_flower_count += 1
	_install_cell_buckets("FlowerCells", flower_buckets, _flower_meshes, 125.0, false)

	var mushroom_buckets: Dictionary = {}
	attempts = 0
	while generated_mushroom_count < mushroom_count and attempts < mushroom_count * 18:
		attempts += 1
		var point := _corridor_point(2.0, 112.0, 0.72)
		if distance_to_route(point) < 1.6 or _inside_clearing(point, 3.8, 7.5):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _mushroom_meshes.size() - 1)
		var scale_value := _random.randf_range(0.72, 1.42)
		_bucket_transform(mushroom_buckets, variant, point, GROUND_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.02, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_mushroom_count += 1
	_install_cell_buckets("MushroomCells", mushroom_buckets, _mushroom_meshes, 105.0, false)


func _scatter_path_pebbles() -> void:
	var buckets: Dictionary = {}
	for _index in path_pebble_count:
		var route_sample := _route_sample()
		var point: Vector2 = route_sample[0]
		var normal: Vector2 = route_sample[1]
		point += normal * _random.randf_range(-3.8, 3.8)
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _pebble_meshes.size() - 1)
		var scale_value := _random.randf_range(0.58, 1.32)
		_bucket_transform(buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.035, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_path_pebble_count += 1
	_install_cell_buckets("PathDetailCells", buckets, _pebble_meshes, 190.0, true)


func _scatter_forest_details() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	var created := 0
	while created < forest_detail_count and attempts < forest_detail_count * 24:
		attempts += 1
		var point := _corridor_point(8.0, 142.0, 0.64)
		if distance_to_route(point) < 5.2 or _inside_clearing(point, 9.5, 15.5):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _dead_tree_meshes.size() - 1)
		var scale_value := _random.randf_range(0.88, 1.62)
		_bucket_transform(buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.08, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		created += 1
	_install_cell_buckets("ForestDetailCells", buckets, _dead_tree_meshes, 245.0, true)


func _load_mesh_library(file_names: PackedStringArray) -> Array[Mesh]:
	var result: Array[Mesh] = []
	for file_name in file_names:
		var source := _load_gltf_scene(ASSET_ROOT + file_name)
		if source == null:
			continue
		var mesh := _find_first_mesh(source)
		if mesh != null:
			result.append(mesh)
		source.free()
	return result


func _load_gltf_scene(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el asset Quaternius: %s (%s)" % [path, error_string(error)])
		return null
	return document.generate_scene(state)


func _find_first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var result := _find_first_mesh(child)
		if result != null:
			return result
	return null


func _bucket_transform(buckets: Dictionary, variant: int, point: Vector2, cell_size: float, transform: Transform3D) -> void:
	var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
	var key := "%d:%d:%d" % [variant, cell.x, cell.y]
	if not buckets.has(key):
		buckets[key] = {"variant": variant, "cell": cell, "transforms": []}
	var transforms: Array = buckets[key]["transforms"]
	transforms.append(transform)


func _install_cell_buckets(root_name: String, buckets: Dictionary, meshes: Array[Mesh], visibility_distance: float, shadows: bool) -> void:
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
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		category.add_child(instance)
		generated_cell_count += 1


func _make_transform(position: Vector3, yaw: float, scale_value: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale_value), position)


func _corridor_point(minimum_offset: float, maximum_offset: float, corridor_chance: float) -> Vector2:
	if _random.randf() > corridor_chance:
		return Vector2(_random.randf_range(-245.0, 245.0), _random.randf_range(-245.0, 245.0))
	var sample := _route_sample()
	var point: Vector2 = sample[0]
	var normal: Vector2 = sample[1]
	var side := -1.0 if _random.randf() < 0.5 else 1.0
	return point + normal * _random.randf_range(minimum_offset, maximum_offset) * side


func _route_sample() -> Array[Vector2]:
	var segment_index := _random.randi_range(0, ROUTE.size() - 2)
	var start := ROUTE[segment_index]
	var finish := ROUTE[segment_index + 1]
	var direction := (finish - start).normalized()
	return [start.lerp(finish, _random.randf()), Vector2(-direction.y, direction.x)]


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
	return point.distance_to(PLAYER_START) < start_radius or point.distance_to(HORSE_START) < start_radius or point.distance_to(LOOKOUT) < lookout_radius


func _inside_village_clearing(point: Vector2, padding: float = 0.0) -> bool:
	for clearing in VILLAGE_CLEARINGS:
		if point.distance_to(Vector2(clearing.x, clearing.y)) < clearing.z + padding:
			return true
	return false


func _add_tree_collision(base: Vector3, bounds: AABB, tree_scale: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = clampf(tree_scale * 0.34, 0.38, 0.82)
	shape.height = maxf(bounds.size.y * tree_scale * 0.76, 4.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * shape.height * 0.5
	_get_collision_body().add_child(collision)


func _add_rock_collision(base: Vector3, mesh_size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(mesh_size.x * 0.72, 0.55), maxf(mesh_size.y * 0.70, 0.45), maxf(mesh_size.z * 0.72, 0.55))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * shape.size.y * 0.42
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
