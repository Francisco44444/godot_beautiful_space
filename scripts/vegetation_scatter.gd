class_name VegetationScatter
extends Node3D

## Valle estilizado construido exclusivamente con el Stylized Nature Mega Kit
## de Quaternius. Los modelos se cargan desde glTF y se agrupan por celdas en
## MultiMesh para mantener senderos frondosos y masas de bosque muy densas sin
## convertir cada planta en un draw call independiente.

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
const GRASS_WIND_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float breeze_strength = 0.035;
uniform float gust_strength = 0.16;
uniform float snow_amount = 0.0;

void vertex() {
	vec3 instance_origin = MODEL_MATRIX[3].xyz;
	float phase = instance_origin.x * 0.041 + instance_origin.z * 0.057;
	float slow_cycle = sin(TIME * 0.20 + phase * 0.27) * 0.5 + 0.5;
	float gust = smoothstep(0.72, 0.98, slow_cycle);
	float wave = sin(TIME * 1.35 + phase + VERTEX.y * 0.42);
	float height_mask = smoothstep(0.05, 1.65, VERTEX.y);
	float bend = (breeze_strength + gust * gust_strength) * wave * height_mask;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.58 + sin(TIME * 0.83 + phase * 1.7) * 0.018 * height_mask;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float green_mask = smoothstep(0.025, 0.20, tex.g - max(tex.r, tex.b));
	vec3 snow_color = vec3(0.88, 0.93, 0.98);
	ALBEDO = mix(tex.rgb, snow_color, green_mask * snow_amount * 0.94);
	ROUGHNESS = 0.92;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.32;
}
"""
const SNOW_TINT_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float green_mask = smoothstep(0.02, 0.18, tex.g - max(tex.r, tex.b));
	float pale_mask = smoothstep(0.58, 0.92, dot(tex.rgb, vec3(0.299, 0.587, 0.114))) * 0.18;
	float snow_mask = clamp(green_mask * 0.96 + pale_mask, 0.0, 0.98);
	ALBEDO = mix(tex.rgb, vec3(0.86, 0.92, 0.98), snow_mask);
	ROUGHNESS = 0.94;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.32;
}
"""
const MYSTERY_TINT_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float leaf = smoothstep(0.015, 0.16, tex.g - max(tex.r, tex.b));
	vec3 shadowed_wood = tex.rgb * vec3(0.42, 0.48, 0.58);
	vec3 blue_leaf = mix(vec3(0.025, 0.10, 0.17), vec3(0.10, 0.34, 0.46), tex.g);
	ALBEDO = mix(shadowed_wood, blue_leaf, leaf * 0.94);
	ROUGHNESS = 0.96;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.32;
}
"""
const GRASS_LOD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wind_strength = 0.055;

void vertex() {
	vec3 instance_origin = MODEL_MATRIX[3].xyz;
	float phase = instance_origin.x * 0.029 + instance_origin.z * 0.043;
	float height_mask = smoothstep(0.02, 0.78, VERTEX.y);
	float wave = sin(TIME * 0.82 + phase) + sin(TIME * 0.31 + phase * 1.71) * 0.38;
	VERTEX.x += wave * wind_strength * height_mask;
	VERTEX.z += wave * wind_strength * 0.54 * height_mask;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.96;
}
"""

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
const ALL_ROAD_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const STONE_VILLAGES: Array[Vector3] = [
	Vector3(0.0, 190.0, 0.08), Vector3(-1450.0, 650.0, 0.42),
	Vector3(-2200.0, -900.0, -0.36), Vector3(2260.0, -980.0, 0.72),
	Vector3(2180.0, 1880.0, -0.25), Vector3(-420.0, -2150.0, 0.0),
]
const ROUTE: Array[Vector2] = [Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)]
const LOOKOUT := Vector2(98.0, -110.0)
const PLAYER_START := Vector2(0.0, 190.0)
const HORSE_START := Vector2(4.0, 180.0)
const VILLAGE_CLEARINGS: Array[Vector3] = [
	Vector3(0.0, 190.0, 95.0), Vector3(-1450.0, 650.0, 190.0),
	Vector3(-2200.0, -900.0, 105.0), Vector3(2260.0, -980.0, 190.0),
	Vector3(2180.0, 1880.0, 105.0), Vector3(-420.0, -2150.0, 190.0),
]
const RURAL_CLEARINGS: Array[Vector3] = [
	Vector3(-720.0, 740.0, 58.0), Vector3(-1680.0, 310.0, 58.0),
	Vector3(-940.0, -1110.0, 58.0), Vector3(970.0, -170.0, 58.0),
	Vector3(1510.0, 830.0, 58.0), Vector3(1720.0, -1030.0, 58.0),
	Vector3(-1040.0, -1900.0, 58.0), Vector3(910.0, -2360.0, 58.0),
]
const FOREST_ZONES: Array[Vector4] = [
	Vector4(-2180.0, 1650.0, 760.0, 660.0),
	Vector4(-2200.0, -900.0, 820.0, 720.0),
	Vector4(760.0, -1550.0, 760.0, 920.0),
	Vector4(2450.0, -1750.0, 620.0, 760.0),
	Vector4(-3380.0, 1120.0, 780.0, 1320.0),
	Vector4(-3420.0, -620.0, 720.0, 1180.0),
	Vector4(4300.0, -1380.0, 1450.0, 1120.0),
	Vector4(5050.0, -650.0, 720.0, 900.0),
]
const TREE_CELL_SIZE := 340.0
const TREE_LOD_CELL_SIZE := TREE_CELL_SIZE
const TREE_COVERAGE_CELL_SIZE := 54.0
const TREE_COVERAGE_TARGET_RATIO := 0.36
const TREE_LOD_SWITCH_DISTANCE := 340.0
const TREE_LOD_VISIBILITY_END := 5200.0
const TREE_LOD_HYSTERESIS := 18.0
const GRASS_CELL_SIZE := 96.0
const GRASS_LOD_SWITCH_RATIO := 0.52
const GRASS_LOD_MIN_SWITCH := 120.0
const GRASS_LOD_MAX_SWITCH := 300.0
const GRASS_LOD_VISIBILITY_END := 920.0
const GRASS_LOD_HYSTERESIS := 8.0
const EXPLICIT_LOD_REFRESH_SECONDS := 0.12
const DETAIL_CELL_SIZE := 440.0
const GROUND_CELL_SIZE := 380.0

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export_category("Claro y bosque Quaternius")
@export var tree_count := 52000
@export_range(0.0, 0.15, 0.001) var autumn_tree_ratio := 0.004
@export var rock_count := 3000
@export var grass_count := 110000
@export var fern_count := 10000
@export var shrub_count := 10000
@export var flower_count := 8000
@export var mushroom_count := 2200
@export var path_pebble_count := 12000
@export var forest_detail_count := 1200
@export var random_seed := 731947
@export_category("LOD global")
@export_range(180.0, 900.0, 10.0) var lod_switch_distance := TREE_LOD_SWITCH_DISTANCE

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
var generated_snow_tree_count := 0
var generated_mystery_tree_count := 0
var generated_snow_grass_count := 0
var generated_snow_fern_count := 0
var generated_snow_shrub_count := 0
var generated_tree_collision_count := 0
var generated_rock_collision_count := 0
var generated_tree_lod_instances := 0
var generated_tree_lod_cells := 0
var generated_coverage_tree_count := 0
var generated_coverage_primary_tree_count := 0
var generated_grass_lod_instances := 0
var generated_grass_lod_cells := 0
var explicit_lod_visible_full_cells := 0
var explicit_lod_visible_proxy_cells := 0
var tree_positions: Array[Vector3] = []

var _random := RandomNumberGenerator.new()
var _tree_meshes: Array[Mesh] = []
var _tree_lod_meshes: Array[Mesh] = []
var _grass_lod_meshes: Array[Mesh] = []
var _rock_meshes: Array[Mesh] = []
var _grass_meshes: Array[Mesh] = []
var _fern_meshes: Array[Mesh] = []
var _shrub_meshes: Array[Mesh] = []
var _flower_meshes: Array[Mesh] = []
var _mushroom_meshes: Array[Mesh] = []
var _dead_tree_meshes: Array[Mesh] = []
var _pebble_meshes: Array[Mesh] = []
var _snow_tree_offset := -1
var _mystery_tree_offset := -1
var _snow_grass_offset := -1
var _snow_fern_offset := -1
var _snow_shrub_offset := -1
var _snow_shader: Shader
var _tree_full_cells: Dictionary = {}
var _tree_proxy_cells: Dictionary = {}
var _grass_full_cells: Dictionary = {}
var _grass_proxy_cells: Dictionary = {}
var _tree_cell_states: Dictionary = {}
var _grass_cell_states: Dictionary = {}
var _explicit_lod_refresh_elapsed := 0.0


func _ready() -> void:
	_random.seed = random_seed
	set_meta("project_assets_loaded_via_importer", true)
	set_meta("explicit_tree_lod", true)
	set_meta("sparse_static_grass_lod", true)
	set_meta("exclusive_lod_pairs", true)
	var green_tree_meshes := _load_mesh_library(GREEN_TREE_FILES)
	var autumn_tree_meshes := _load_mesh_library(AUTUMN_TREE_FILES)
	_tree_meshes = green_tree_meshes.duplicate()
	_tree_meshes.append_array(autumn_tree_meshes)
	_snow_tree_offset = _tree_meshes.size()
	_tree_meshes.append_array(_make_snow_mesh_library(green_tree_meshes))
	_mystery_tree_offset = _tree_meshes.size()
	_tree_meshes.append_array(_make_mystery_mesh_library(green_tree_meshes))
	_tree_lod_meshes = _make_tree_lod_mesh_library()
	_rock_meshes = _load_mesh_library(ROCK_FILES)
	_grass_meshes = _load_mesh_library(GRASS_FILES)
	_snow_grass_offset = _grass_meshes.size()
	for grass_mesh in _grass_meshes.duplicate():
		_grass_meshes.append((grass_mesh as Mesh).duplicate(true) as Mesh)
	_grass_lod_meshes = [
		_make_grass_lod_mesh(2, 0.72, 0.34, Color(0.12, 0.40, 0.09), Color(0.42, 0.76, 0.20)),
		_make_grass_lod_mesh(2, 0.72, 0.34, Color(0.55, 0.66, 0.64), Color(0.90, 0.95, 0.98)),
	]
	_fern_meshes = _load_mesh_library(FERN_FILES)
	_snow_fern_offset = _fern_meshes.size()
	_fern_meshes.append_array(_make_snow_mesh_library(_fern_meshes.duplicate()))
	_shrub_meshes = _load_mesh_library(SHRUB_FILES)
	_snow_shrub_offset = _shrub_meshes.size()
	_shrub_meshes.append_array(_make_snow_mesh_library(_shrub_meshes.duplicate()))
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
	_apply_grass_wind_materials()

	_scatter_forest()
	_scatter_rocks()
	_scatter_ground_cover()
	_scatter_color_details()
	_scatter_path_pebbles()
	_scatter_forest_details()
	call_deferred("_update_explicit_lod_visibility", true)
	print(
		"QUATERNIUS VALLEY READY: %d árboles verdes, %d nevados, %d azules tenebrosos, %d otoñales (%d de cobertura anti-calvas; %d celdas primarias), %d rocas, %d hierbas animadas (%d nevadas), %d helechos, %d arbustos, %d flores, %d setas y %d guijarros en %d celdas; las calles de piedra viven en Terrain3D."
		% [generated_green_tree_count, generated_snow_tree_count, generated_mystery_tree_count, generated_autumn_tree_count, generated_coverage_tree_count, generated_coverage_primary_tree_count, generated_rock_count, generated_grass_count, generated_snow_grass_count, generated_fern_count, generated_shrub_count, generated_flower_count, generated_mushroom_count, generated_path_pebble_count, generated_cell_count]
	)


func _process(delta: float) -> void:
	_explicit_lod_refresh_elapsed += delta
	if _explicit_lod_refresh_elapsed < EXPLICIT_LOD_REFRESH_SECONDS:
		return
	_explicit_lod_refresh_elapsed = 0.0
	_update_explicit_lod_visibility(false)


func _scatter_forest() -> void:
	var buckets: Dictionary = {}
	var lod_buckets: Dictionary = {}
	# Una retícula irregular cubre primero toda pradera válida. El reparto
	# aleatorio anterior podía colocar 52.000 árboles y aun dejar calvas enormes.
	# El resto del presupuesto conserva las masas densas y senderos arbolados.
	var coverage_points := _build_tree_coverage_points(roundi(tree_count * TREE_COVERAGE_TARGET_RATIO))
	var coverage_index := 0
	var attempts := 0
	while generated_tree_count < tree_count and attempts < tree_count * 34:
		attempts += 1
		var uses_coverage_point := coverage_index < coverage_points.size()
		var point: Vector2
		if uses_coverage_point:
			point = coverage_points[coverage_index]
			coverage_index += 1
		else:
			point = _tree_distribution_point()
		if not _tree_point_allowed(point):
			continue
		var height := _height_at(point)
		var snow_probability := _snow_probability(point, height)
		var snowy := _random.randf() < snow_probability
		var mystery_strength := _mystery_forest_strength(point)
		var mystery := not snowy and mystery_strength > 0.24 and _random.randf() < smoothstep(0.18, 0.62, mystery_strength)
		var autumn := not snowy and not mystery and _random.randf() < autumn_tree_ratio
		var variant := 0
		var local_tree_variant := _random.randi_range(0, GREEN_TREE_FILES.size() - 1)
		if snowy:
			# En la cumbre predominan los pinos nevados. En la franja intermedia
			# conviven con ejemplares verdes gracias a la probabilidad gradual.
			local_tree_variant = _random.randi_range(5, GREEN_TREE_FILES.size() - 1)
			variant = _snow_tree_offset + local_tree_variant
			generated_snow_tree_count += 1
		elif mystery:
			variant = _mystery_tree_offset + local_tree_variant
			generated_mystery_tree_count += 1
		elif autumn:
			variant = GREEN_TREE_FILES.size() + _random.randi_range(0, AUTUMN_TREE_FILES.size() - 1)
			generated_autumn_tree_count += 1
		else:
			variant = local_tree_variant
			generated_green_tree_count += 1
		# Siluetas más monumentales sin aumentar instancias ni draw calls: el mismo
		# MultiMesh/LOD conserva el rendimiento, pero el bosque gana dosel y escala.
		var scale_value := _random.randf_range(1.48, 2.68)
		if local_tree_variant >= 5:
			scale_value *= _random.randf_range(1.05, 1.30)
		var position := Vector3(point.x, height + 0.10, point.y)
		var transform := _make_transform(position, _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		_bucket_transform(
			buckets,
			variant,
			point,
			TREE_CELL_SIZE,
			transform
		)
		var lod_variant := _tree_lod_variant(snowy, mystery, autumn, local_tree_variant)
		_bucket_transform(lod_buckets, lod_variant, point, TREE_LOD_CELL_SIZE, transform)
		tree_positions.append(position)
		if uses_coverage_point:
			generated_coverage_tree_count += 1
		# Colisión completa alrededor de las rutas jugables y una muestra densa en
		# el bosque profundo. La geometría distante sigue siendo MultiMesh barata.
		if distance_to_route(point) < 34.0 or generated_tree_count % 16 == 0:
			_add_tree_collision(position, _tree_meshes[variant].get_aabb(), scale_value)
			generated_tree_collision_count += 1
		generated_tree_count += 1
	_install_cell_buckets("TreeCells", buckets, _tree_meshes, 0.0, true)
	var full_tree_root := get_node("TreeCells") as Node3D
	full_tree_root.set_meta("lod_tier", "full")
	full_tree_root.set_meta("switch_distance", lod_switch_distance)
	full_tree_root.set_meta("coverage_cell_size", TREE_COVERAGE_CELL_SIZE)
	full_tree_root.set_meta("coverage_tree_count", generated_coverage_tree_count)
	full_tree_root.set_meta("coverage_primary_tree_count", generated_coverage_primary_tree_count)
	_install_tree_lod_buckets(lod_buckets)


func _scatter_rocks() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_rock_count < rock_count and attempts < rock_count * 24:
		attempts += 1
		var point := _corridor_point(5.2, 142.0, 0.62)
		if distance_to_route(point) < 8.0 or _inside_clearing(point, 9.0, 16.0) or _inside_village_clearing(point, -5.0) or _inside_desert(point):
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
		if distance_to_route(point) < 28.0 or generated_rock_count % 4 == 0:
			_add_rock_collision(position, _rock_meshes[variant].get_aabb().size * scale_vector)
			generated_rock_collision_count += 1
		generated_rock_count += 1
	_install_cell_buckets("RockCells", buckets, _rock_meshes, 420.0, true)


func _scatter_ground_cover() -> void:
	var grass_buckets: Dictionary = {}
	var grass_lod_buckets: Dictionary = {}
	var attempts := 0
	while generated_grass_count < grass_count and attempts < grass_count * 14:
		attempts += 1
		var point := _corridor_point(2.35, 126.0, 0.76)
		if distance_to_route(point) < 8.2 or _inside_clearing(point, 4.3, 8.0) or _inside_stone_village_street(point, 1.8) or _inside_desert(point) or _slope_at(point) > 0.88:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _grass_meshes.size() - 1)
		var snowy := _random.randf() < _snow_probability(point, height)
		if snowy:
			variant = _snow_grass_offset + _random.randi_range(0, GRASS_FILES.size() - 1)
			generated_snow_grass_count += 1
		else:
			variant = _random.randi_range(0, GRASS_FILES.size() - 1)
		var scale_value := _random.randf_range(0.64, 1.28)
		var scale_vector := Vector3(
			scale_value * _random.randf_range(1.30, 2.10),
			scale_value,
			scale_value * _random.randf_range(1.30, 2.10)
		)
		var transform := _make_transform(Vector3(point.x, height + 0.02, point.y), _random.randf_range(0.0, TAU), scale_vector)
		_bucket_transform(grass_buckets, variant, point, GRASS_CELL_SIZE, transform)
		_bucket_transform(grass_lod_buckets, 1 if snowy else 0, point, GRASS_CELL_SIZE, transform)
		generated_grass_count += 1
	_install_cell_buckets("GrassCells", grass_buckets, _grass_meshes, 0.0, false)
	_install_grass_lod_buckets(grass_lod_buckets)

	var fern_buckets: Dictionary = {}
	attempts = 0
	while generated_fern_count < fern_count and attempts < fern_count * 16:
		attempts += 1
		var point := _corridor_point(2.8, 132.0, 0.70)
		if distance_to_route(point) < 8.5 or _inside_clearing(point, 5.4, 10.0) or _inside_stone_village_street(point, 2.1) or _inside_desert(point) or _slope_at(point) > 0.82:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, FERN_FILES.size() - 1)
		if _random.randf() < _snow_probability(point, height):
			variant += _snow_fern_offset
			generated_snow_fern_count += 1
		var scale_value := _random.randf_range(0.30, 0.62) if variant == 0 else _random.randf_range(0.52, 1.10)
		_bucket_transform(fern_buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.03, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_fern_count += 1
	_install_cell_buckets("FernCells", fern_buckets, _fern_meshes, 245.0, true)

	var shrub_buckets: Dictionary = {}
	attempts = 0
	while generated_shrub_count < shrub_count and attempts < shrub_count * 16:
		attempts += 1
		var point := _corridor_point(3.4, 136.0, 0.68)
		if distance_to_route(point) < 9.0 or _inside_clearing(point, 6.2, 11.5) or _inside_stone_village_street(point, 2.5) or _inside_desert(point) or _slope_at(point) > 0.82:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, SHRUB_FILES.size() - 1)
		if _random.randf() < _snow_probability(point, height):
			variant += _snow_shrub_offset
			generated_snow_shrub_count += 1
		var scale_value := _random.randf_range(0.82, 1.62)
		_bucket_transform(shrub_buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.04, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_shrub_count += 1
	_install_cell_buckets("ShrubCells", shrub_buckets, _shrub_meshes, 270.0, true)


func _scatter_color_details() -> void:
	var flower_buckets: Dictionary = {}
	var attempts := 0
	while generated_flower_count < flower_count and attempts < flower_count * 15:
		attempts += 1
		var point := _corridor_point(1.9, 108.0, 0.78)
		if distance_to_route(point) < 8.0 or _inside_clearing(point, 3.8, 7.0) or _inside_stone_village_street(point, 1.5) or _inside_desert(point) or _slope_at(point) > 0.84:
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		if _snow_probability(point, height) > 0.62:
			continue
		var variant := _random.randi_range(0, _flower_meshes.size() - 1)
		var scale_value := _random.randf_range(0.40, 0.82)
		_bucket_transform(flower_buckets, variant, point, GROUND_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.025, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_flower_count += 1
	_install_cell_buckets("FlowerCells", flower_buckets, _flower_meshes, 185.0, false)

	var mushroom_buckets: Dictionary = {}
	attempts = 0
	while generated_mushroom_count < mushroom_count and attempts < mushroom_count * 18:
		attempts += 1
		var point := _corridor_point(2.0, 112.0, 0.72)
		if distance_to_route(point) < 8.0 or _inside_clearing(point, 3.8, 7.5) or _inside_stone_village_street(point, 1.5) or _inside_desert(point):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		if _snow_probability(point, height) > 0.72:
			continue
		var variant := _random.randi_range(0, _mushroom_meshes.size() - 1)
		var scale_value := _random.randf_range(0.72, 1.42)
		_bucket_transform(mushroom_buckets, variant, point, GROUND_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.02, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_mushroom_count += 1
	_install_cell_buckets("MushroomCells", mushroom_buckets, _mushroom_meshes, 150.0, false)


func _scatter_path_pebbles() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_path_pebble_count < path_pebble_count and attempts < path_pebble_count * 4:
		attempts += 1
		# Los guijarros solo acompañan los caminos rurales de tierra. Las calles
		# internas de las villas no reciben ninguna piedra 3D superpuesta.
		var route_sample := _route_sample()
		var point: Vector2 = route_sample[0]
		var normal: Vector2 = route_sample[1]
		point += normal * _random.randf_range(-3.2, 3.2)
		if _inside_stone_village_street(point, 2.0):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _pebble_meshes.size() - 1)
		var scale_value := _random.randf_range(0.58, 1.32)
		_bucket_transform(buckets, variant, point, DETAIL_CELL_SIZE, _make_transform(Vector3(point.x, height + 0.035, point.y), _random.randf_range(0.0, TAU), Vector3.ONE * scale_value))
		generated_path_pebble_count += 1
	_install_cell_buckets("PathDetailCells", buckets, _pebble_meshes, 190.0, true)
	var dirt_detail_cells := get_node("PathDetailCells") as Node3D
	dirt_detail_cells.set_meta("road_indices", ALL_ROAD_INDICES)
	dirt_detail_cells.set_meta("ground_texture_id", 1)


func _scatter_forest_details() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	var created := 0
	while created < forest_detail_count and attempts < forest_detail_count * 24:
		attempts += 1
		var point := _corridor_point(8.0, 142.0, 0.64)
		# Los troncos secos son parte del bosque, nunca del interior de una casa,
		# patio o ciudadela. El resto del arbolado ya respetaba estas reservas,
		# pero este pase de detalle podía atravesar edificios completos.
		if distance_to_route(point) < 5.2 or _inside_clearing(point, 9.5, 15.5) or _inside_village_clearing(point, 8.0) or _inside_desert(point):
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


func _make_snow_mesh_library(source_meshes: Array[Mesh]) -> Array[Mesh]:
	if _snow_shader == null:
		_snow_shader = Shader.new()
		_snow_shader.code = SNOW_TINT_SHADER
	var result: Array[Mesh] = []
	for source_mesh in source_meshes:
		var snow_mesh := source_mesh.duplicate(true) as Mesh
		for surface_index in snow_mesh.get_surface_count():
			var source_material := source_mesh.surface_get_material(surface_index) as BaseMaterial3D
			if source_material == null or source_material.albedo_texture == null:
				continue
			var snow_material := ShaderMaterial.new()
			snow_material.shader = _snow_shader
			snow_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
			snow_mesh.surface_set_material(surface_index, snow_material)
		result.append(snow_mesh)
	return result


func _make_mystery_mesh_library(source_meshes: Array[Mesh]) -> Array[Mesh]:
	var shader := Shader.new()
	shader.code = MYSTERY_TINT_SHADER
	var result: Array[Mesh] = []
	for source_mesh in source_meshes:
		var mystery_mesh := source_mesh.duplicate(true) as Mesh
		for surface_index in mystery_mesh.get_surface_count():
			var source_material := source_mesh.surface_get_material(surface_index) as BaseMaterial3D
			if source_material == null or source_material.albedo_texture == null:
				continue
			var mystery_material := ShaderMaterial.new()
			mystery_material.shader = shader
			mystery_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
			mystery_mesh.surface_set_material(surface_index, mystery_material)
		result.append(mystery_mesh)
	return result


func _make_tree_lod_mesh_library() -> Array[Mesh]:
	# Los árboles Quaternius completos rondan varios miles de vértices. A partir
	# de unos cientos de metros se sustituyen por siluetas facetadas de menos de
	# 140 vértices, iluminadas normalmente y sin sombras lejanas.
	return [
		_make_tree_lod_mesh(Color("3f9145"), Color("694329"), false),
		_make_tree_lod_mesh(Color("2f7644"), Color("62402a"), true),
		_make_tree_lod_mesh(Color("b45232"), Color("75503a"), false),
		_make_tree_lod_mesh(Color("dce9e7"), Color("7b6758"), true),
		_make_tree_lod_mesh(Color("21556b"), Color("394b57"), false),
		_make_tree_lod_mesh(Color("173f59"), Color("344957"), true),
	]


func _make_tree_lod_mesh(leaf_color: Color, bark_color: Color, pine: bool) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_lod_prism(surface, 0.0, 3.45, 0.34, 0.22, 5, bark_color.darkened(0.18), bark_color)
	if pine:
		_add_lod_cone(surface, 2.15, 4.65, 2.15, 7, leaf_color.darkened(0.16), leaf_color)
		_add_lod_cone(surface, 3.25, 5.85, 1.72, 7, leaf_color.darkened(0.10), leaf_color.lightened(0.04))
		_add_lod_cone(surface, 4.40, 7.15, 1.24, 7, leaf_color, leaf_color.lightened(0.10))
	else:
		_add_lod_crown(surface, Vector3(0.0, 4.55, 0.0), Vector3(2.20, 2.05, 2.05), leaf_color)
		_add_lod_crown(surface, Vector3(-1.18, 4.35, 0.18), Vector3(1.35, 1.48, 1.30), leaf_color.darkened(0.08))
		_add_lod_crown(surface, Vector3(1.12, 4.70, -0.12), Vector3(1.30, 1.52, 1.32), leaf_color.lightened(0.06))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	surface.set_material(material)
	surface.generate_normals()
	return surface.commit()


func _add_lod_prism(
	surface: SurfaceTool,
	bottom_y: float,
	top_y: float,
	bottom_radius: float,
	top_radius: float,
	sides: int,
	bottom_color: Color,
	top_color: Color
) -> void:
	for side_index in sides:
		var angle_a := TAU * float(side_index) / float(sides)
		var angle_b := TAU * float(side_index + 1) / float(sides)
		var bottom_a := Vector3(cos(angle_a) * bottom_radius, bottom_y, sin(angle_a) * bottom_radius)
		var bottom_b := Vector3(cos(angle_b) * bottom_radius, bottom_y, sin(angle_b) * bottom_radius)
		var top_a := Vector3(cos(angle_a) * top_radius, top_y, sin(angle_a) * top_radius)
		var top_b := Vector3(cos(angle_b) * top_radius, top_y, sin(angle_b) * top_radius)
		_add_lod_triangle(surface, bottom_a, bottom_b, top_b, bottom_color, bottom_color, top_color)
		_add_lod_triangle(surface, bottom_a, top_b, top_a, bottom_color, top_color, top_color)


func _add_lod_cone(
	surface: SurfaceTool,
	bottom_y: float,
	top_y: float,
	radius: float,
	sides: int,
	bottom_color: Color,
	top_color: Color
) -> void:
	var tip := Vector3(0.0, top_y, 0.0)
	for side_index in sides:
		var angle_a := TAU * float(side_index) / float(sides)
		var angle_b := TAU * float(side_index + 1) / float(sides)
		var a := Vector3(cos(angle_a) * radius, bottom_y, sin(angle_a) * radius)
		var b := Vector3(cos(angle_b) * radius, bottom_y, sin(angle_b) * radius)
		_add_lod_triangle(surface, a, b, tip, bottom_color, bottom_color, top_color)


func _add_lod_crown(surface: SurfaceTool, center: Vector3, radius: Vector3, color: Color) -> void:
	var top := center + Vector3.UP * radius.y
	var bottom := center - Vector3.UP * radius.y
	const RING_SIDES := 7
	for side_index in RING_SIDES:
		var angle_a := TAU * float(side_index) / float(RING_SIDES)
		var angle_b := TAU * float(side_index + 1) / float(RING_SIDES)
		var a := center + Vector3(cos(angle_a) * radius.x, 0.0, sin(angle_a) * radius.z)
		var b := center + Vector3(cos(angle_b) * radius.x, 0.0, sin(angle_b) * radius.z)
		_add_lod_triangle(surface, a, b, top, color.darkened(0.06), color.darkened(0.06), color.lightened(0.10))
		_add_lod_triangle(surface, b, a, bottom, color.darkened(0.04), color.darkened(0.04), color.darkened(0.18))


func _add_lod_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color_a: Color,
	color_b: Color,
	color_c: Color
) -> void:
	surface.set_color(color_a)
	surface.add_vertex(a)
	surface.set_color(color_b)
	surface.add_vertex(b)
	surface.set_color(color_c)
	surface.add_vertex(c)


func _tree_lod_variant(snowy: bool, mystery: bool, autumn: bool, local_tree_variant: int) -> int:
	if snowy:
		return 3
	if mystery:
		return 5 if local_tree_variant >= 5 else 4
	if autumn:
		return 2
	return 1 if local_tree_variant >= 5 else 0


func _apply_grass_wind_materials() -> void:
	var shader := Shader.new()
	shader.code = GRASS_WIND_SHADER
	for mesh_index in _grass_meshes.size():
		var mesh := _grass_meshes[mesh_index]
		for surface_index in mesh.get_surface_count():
			var source_material := mesh.surface_get_material(surface_index) as BaseMaterial3D
			if source_material == null or source_material.albedo_texture == null:
				continue
			var wind_material := ShaderMaterial.new()
			wind_material.shader = shader
			wind_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
			wind_material.set_shader_parameter("snow_amount", 1.0 if mesh_index >= _snow_grass_offset else 0.0)
			mesh.surface_set_material(surface_index, wind_material)


func _load_gltf_scene(path: String) -> Node3D:
	# Cargar primero el PackedScene importado permite que Godot aplique el
	# postproceso del importador (`generate_lods`) a rocas, plantas y decorado.
	# GLTFDocument queda solo como respaldo para un asset recién copiado que aún
	# no tenga su caché `.import`.
	var imported := ResourceLoader.load(path)
	if imported is PackedScene:
		return (imported as PackedScene).instantiate() as Node3D
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
		buckets[key] = {"variant": variant, "cell": cell, "cell_size": cell_size, "transforms": []}
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
		var cell_size := float(bucket["cell_size"])
		var anchor := _cell_anchor(cell, cell_size)
		var local_transforms := _localize_transforms(transforms, anchor)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[variant]
		multimesh.instance_count = local_transforms.size()
		for index in local_transforms.size():
			multimesh.set_instance_transform(index, local_transforms[index])
		multimesh.custom_aabb = _transforms_aabb(local_transforms, meshes[variant])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Cell_%d_%d_v%d" % [cell.x, cell.y, variant]
		instance.multimesh = multimesh
		instance.position = anchor
		instance.visibility_range_end = visibility_distance
		instance.visibility_range_end_margin = 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		instance.lod_bias = 0.75
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.set_meta("imported_mesh_lod_bias", 0.75)
		instance.set_meta("cell", cell)
		instance.set_meta("cell_size", cell_size)
		instance.set_meta("base_visibility_end", visibility_distance)
		category.add_child(instance)
		if root_name == "TreeCells":
			instance.set_meta("explicit_lod_role", "full")
			_register_lod_instance(_tree_full_cells, cell, instance)
		elif root_name == "GrassCells":
			instance.set_meta("explicit_lod_role", "full")
			_register_lod_instance(_grass_full_cells, cell, instance)
		generated_cell_count += 1


func _install_tree_lod_buckets(buckets: Dictionary) -> void:
	var category := Node3D.new()
	category.name = "TreeLODCells"
	category.set_meta("lod_tier", "faceted_far")
	category.set_meta("source_tree_count", tree_count)
	category.set_meta("visibility_begin", lod_switch_distance)
	category.set_meta("visibility_end", TREE_LOD_VISIBILITY_END)
	category.set_meta("shadows_disabled", true)
	category.set_meta("exclusive_with", "TreeCells")
	add_child(category)
	var keys := buckets.keys()
	keys.sort()
	for key in keys:
		var bucket: Dictionary = buckets[key]
		var transforms: Array = bucket["transforms"]
		var variant: int = bucket["variant"]
		var cell: Vector2i = bucket["cell"]
		var cell_size := float(bucket["cell_size"])
		var anchor := _cell_anchor(cell, cell_size)
		var local_transforms := _localize_transforms(transforms, anchor)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _tree_lod_meshes[variant]
		multimesh.instance_count = local_transforms.size()
		for index in local_transforms.size():
			multimesh.set_instance_transform(index, local_transforms[index])
		multimesh.custom_aabb = _transforms_aabb(local_transforms, _tree_lod_meshes[variant])
		var instance := MultiMeshInstance3D.new()
		instance.name = "LOD_%d_%d_v%d" % [cell.x, cell.y, variant]
		instance.multimesh = multimesh
		instance.position = anchor
		# El gestor de celda decide la representación de forma atómica. No se usan
		# rangos superpuestos del motor: proxy y malla completa nunca coexisten.
		instance.visibility_range_begin = 0.0
		instance.visibility_range_begin_margin = 0.0
		instance.visibility_range_end = 0.0
		instance.visibility_range_end_margin = 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.set_meta("lod_geometry", "faceted_tree")
		instance.set_meta("full_mesh_replacement", true)
		instance.set_meta("explicit_lod_role", "proxy")
		instance.set_meta("cell", cell)
		instance.set_meta("cell_size", cell_size)
		instance.visible = false
		category.add_child(instance)
		_register_lod_instance(_tree_proxy_cells, cell, instance)
		generated_tree_lod_cells += 1
		generated_tree_lod_instances += local_transforms.size()


func _install_grass_lod_buckets(buckets: Dictionary) -> void:
	var category := Node3D.new()
	category.name = "GrassLODCells"
	category.set_meta("lod_tier", "sparse_proxy")
	category.set_meta("source_grass_count", grass_count)
	category.set_meta("switch_distance_ratio", GRASS_LOD_SWITCH_RATIO)
	category.set_meta("visibility_end", GRASS_LOD_VISIBILITY_END)
	category.set_meta("shadows_disabled", true)
	category.set_meta("exclusive_with", "GrassCells")
	add_child(category)
	var keys := buckets.keys()
	keys.sort()
	for key in keys:
		var bucket: Dictionary = buckets[key]
		var transforms: Array = bucket["transforms"]
		var variant: int = bucket["variant"]
		var cell: Vector2i = bucket["cell"]
		var cell_size := float(bucket["cell_size"])
		var anchor := _cell_anchor(cell, cell_size)
		var local_transforms := _localize_transforms(transforms, anchor)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _grass_lod_meshes[variant]
		multimesh.instance_count = local_transforms.size()
		for index in local_transforms.size():
			multimesh.set_instance_transform(index, local_transforms[index])
		multimesh.custom_aabb = _transforms_aabb(local_transforms, _grass_lod_meshes[variant])
		var instance := MultiMeshInstance3D.new()
		instance.name = "LOD_%d_%d_v%d" % [cell.x, cell.y, variant]
		instance.multimesh = multimesh
		instance.position = anchor
		instance.visibility_range_begin = 0.0
		instance.visibility_range_begin_margin = 0.0
		instance.visibility_range_end = 0.0
		instance.visibility_range_end_margin = 0.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.set_meta("lod_geometry", "two_triangle_grass")
		instance.set_meta("full_mesh_replacement", true)
		instance.set_meta("explicit_lod_role", "proxy")
		instance.set_meta("cell", cell)
		instance.set_meta("cell_size", cell_size)
		instance.visible = false
		category.add_child(instance)
		_register_lod_instance(_grass_proxy_cells, cell, instance)
		generated_grass_lod_cells += 1
		generated_grass_lod_instances += local_transforms.size()


func set_lod_switch_distance(distance_metres: float) -> void:
	lod_switch_distance = clampf(distance_metres, 180.0, 900.0)
	_tree_cell_states.clear()
	_grass_cell_states.clear()
	var tree_lod_root := get_node_or_null("TreeLODCells") as Node3D
	if tree_lod_root != null:
		tree_lod_root.set_meta("visibility_begin", lod_switch_distance)
	var tree_root := get_node_or_null("TreeCells") as Node3D
	if tree_root != null:
		tree_root.set_meta("switch_distance", lod_switch_distance)
	_update_explicit_lod_visibility(true)


func _update_explicit_lod_visibility(force: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var focus := Vector2(camera.global_position.x, camera.global_position.z)
	explicit_lod_visible_full_cells = 0
	explicit_lod_visible_proxy_cells = 0
	_update_lod_pair_set(
		_tree_full_cells,
		_tree_proxy_cells,
		_tree_cell_states,
		focus,
		TREE_CELL_SIZE,
		lod_switch_distance,
		TREE_LOD_HYSTERESIS,
		TREE_LOD_VISIBILITY_END,
		force
	)
	var grass_switch := clampf(
		lod_switch_distance * GRASS_LOD_SWITCH_RATIO,
		GRASS_LOD_MIN_SWITCH,
		GRASS_LOD_MAX_SWITCH
	)
	_update_lod_pair_set(
		_grass_full_cells,
		_grass_proxy_cells,
		_grass_cell_states,
		focus,
		GRASS_CELL_SIZE,
		grass_switch,
		GRASS_LOD_HYSTERESIS,
		GRASS_LOD_VISIBILITY_END,
		force
	)
	set_meta("active_lod_distance", lod_switch_distance)
	set_meta("visible_full_lod_cells", explicit_lod_visible_full_cells)
	set_meta("visible_proxy_lod_cells", explicit_lod_visible_proxy_cells)


func _update_lod_pair_set(
	full_cells: Dictionary,
	proxy_cells: Dictionary,
	states: Dictionary,
	focus: Vector2,
	cell_size: float,
	switch_distance: float,
	hysteresis: float,
	far_distance: float,
	force: bool
) -> void:
	var keys := full_cells.keys()
	for proxy_key in proxy_cells.keys():
		if not full_cells.has(proxy_key):
			keys.append(proxy_key)
	for key_value in keys:
		var cell := key_value as Vector2i
		var distance := _distance_to_cell(focus, cell, cell_size)
		var use_full := distance <= switch_distance
		if not force and states.has(cell):
			use_full = bool(states[cell])
			if use_full and distance > switch_distance + hysteresis:
				use_full = false
			elif not use_full and distance < switch_distance - hysteresis:
				use_full = true
		states[cell] = use_full
		_set_lod_instances_visible(full_cells.get(cell, []), use_full)
		var show_proxy := not use_full and distance <= far_distance
		_set_lod_instances_visible(proxy_cells.get(cell, []), show_proxy)
		if use_full:
			explicit_lod_visible_full_cells += 1
		elif show_proxy:
			explicit_lod_visible_proxy_cells += 1


func _set_lod_instances_visible(instances: Array, should_be_visible: bool) -> void:
	for instance_value in instances:
		var instance := instance_value as MultiMeshInstance3D
		if instance != null:
			instance.visible = should_be_visible


func _register_lod_instance(store: Dictionary, cell: Vector2i, instance: MultiMeshInstance3D) -> void:
	if not store.has(cell):
		store[cell] = []
	var instances: Array = store[cell]
	instances.append(instance)


func _distance_to_cell(point: Vector2, cell: Vector2i, cell_size: float) -> float:
	var minimum := Vector2(cell.x * cell_size, cell.y * cell_size)
	var maximum := minimum + Vector2.ONE * cell_size
	var closest := Vector2(clampf(point.x, minimum.x, maximum.x), clampf(point.y, minimum.y, maximum.y))
	return point.distance_to(closest)


func _cell_anchor(cell: Vector2i, cell_size: float) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * cell_size, 0.0, (float(cell.y) + 0.5) * cell_size)


func _localize_transforms(transforms: Array, anchor: Vector3) -> Array[Transform3D]:
	var localized: Array[Transform3D] = []
	localized.resize(transforms.size())
	for index in transforms.size():
		var transform := transforms[index] as Transform3D
		transform.origin -= anchor
		localized[index] = transform
	return localized


func _make_grass_lod_mesh(
	blade_count: int,
	height: float,
	half_width: float,
	bottom_color: Color,
	top_color: Color
) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade_index in blade_count:
		var angle := TAU * float(blade_index) / float(blade_count)
		var right := Vector3(cos(angle), 0.0, sin(angle))
		var forward := Vector3(-right.z, 0.0, right.x)
		var a := -right * half_width
		var b := right * half_width
		var c := forward * half_width * 0.52 + Vector3.UP * height
		_add_lod_triangle(surface, a, b, c, bottom_color.darkened(0.10), bottom_color, top_color)
	var shader := Shader.new()
	shader.code = GRASS_LOD_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.set_material(material)
	surface.generate_normals()
	return surface.commit()


func _make_transform(position: Vector3, yaw: float, scale_value: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale_value), position)


func _transforms_aabb(transforms: Array, mesh: Mesh) -> AABB:
	var result := AABB()
	var initialized := false
	var mesh_aabb := mesh.get_aabb()
	for transform_value in transforms:
		var transformed := (transform_value as Transform3D) * mesh_aabb
		if not initialized:
			result = transformed
			initialized = true
		else:
			result = result.merge(transformed)
	return result.grow(0.20) if initialized else AABB(Vector3.ZERO, Vector3.ONE * 0.01)


func _corridor_point(minimum_offset: float, maximum_offset: float, corridor_chance: float) -> Vector2:
	if _random.randf() > corridor_chance:
		return _forest_point()
	var sample := _route_sample()
	var point: Vector2 = sample[0]
	var normal: Vector2 = sample[1]
	var side := -1.0 if _random.randf() < 0.5 else 1.0
	var edge_bias := pow(_random.randf(), 2.15)
	return point + normal * lerpf(minimum_offset, maximum_offset, edge_bias) * side


func _route_sample() -> Array[Vector2]:
	return _indexed_route_sample(ALL_ROAD_INDICES)


func _indexed_route_sample(road_indices: Array[int]) -> Array[Vector2]:
	var selected_index := road_indices[_random.randi_range(0, road_indices.size() - 1)]
	var road: Array = ROAD_NETWORK[selected_index]
	var segment_index := _random.randi_range(0, road.size() - 2)
	var start: Vector2 = road[segment_index]
	var finish: Vector2 = road[segment_index + 1]
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
	for road in ROAD_NETWORK:
		for index in road.size() - 1:
			var start: Vector2 = road[index]
			var finish: Vector2 = road[index + 1]
			var segment := finish - start
			var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
			best_distance = minf(best_distance, point.distance_to(start + segment * progress))
	return best_distance


func _forest_point() -> Vector2:
	# Siete de cada diez muestras forman un cinturón de vegetación de hasta
	# 132 m a cada lado de todos los senderos. El resto rellena las reservas
	# forestales aisladas para que desde dentro parezcan realmente interminables.
	if _random.randf() < 0.70:
		var sample := _route_sample()
		var point: Vector2 = sample[0]
		var normal: Vector2 = sample[1]
		var side := -1.0 if _random.randf() < 0.5 else 1.0
		var edge_bias := pow(_random.randf(), 1.65)
		return point + normal * lerpf(13.0, 132.0, edge_bias) * side
	return _forest_zone_point()


func _tree_distribution_point() -> Vector2:
	# El reparto anterior dedicaba el 70 % al borde del sendero y dejaba vacías
	# las praderas intermedias. Ahora rutas, reservas y superficie insular verde
	# participan de forma equilibrada; el filtro de material posterior descarta
	# agua, arena, caminos y paredes.
	var distribution := _random.randf()
	if distribution < 0.35:
		var sample := _route_sample()
		var point: Vector2 = sample[0]
		var normal: Vector2 = sample[1]
		var side := -1.0 if _random.randf() < 0.5 else 1.0
		return point + normal * lerpf(13.0, 178.0, sqrt(_random.randf())) * side
	if distribution < 0.70:
		return _forest_zone_point()
	return Vector2(_random.randf_range(-4850.0, 5450.0), _random.randf_range(-4380.0, 4380.0))


func _build_tree_coverage_points(target_count: int) -> Array[Vector2]:
	var primary_points: Array[Vector2] = []
	var companion_points: Array[Vector2] = []
	var minimum := Vector2(-4850.0, -4380.0)
	var maximum := Vector2(5450.0, 4380.0)
	var columns := ceili((maximum.x - minimum.x) / TREE_COVERAGE_CELL_SIZE)
	var rows := ceili((maximum.y - minimum.y) / TREE_COVERAGE_CELL_SIZE)
	for row in rows:
		for column in columns:
			var center := minimum + Vector2(
				(float(column) + 0.5) * TREE_COVERAGE_CELL_SIZE,
				(float(row) + 0.5) * TREE_COVERAGE_CELL_SIZE
			)
			var point := center + Vector2(
				_random.randf_range(-0.34, 0.34),
				_random.randf_range(-0.34, 0.34)
			) * TREE_COVERAGE_CELL_SIZE
			# Un único intento aleatorio podía caer sobre un sendero o un borde de
			# material y descartar una celda cuya mayor parte era pradera. Conservamos
			# el jitter orgánico, pero buscamos después centro y cuadrantes para que
			# una exclusión local no vuelva a producir una calva de cientos de metros.
			var primary := Vector2(INF, INF)
			var candidates: Array[Vector2] = [
				point,
				center,
				center + Vector2(-0.27, -0.27) * TREE_COVERAGE_CELL_SIZE,
				center + Vector2(0.27, -0.27) * TREE_COVERAGE_CELL_SIZE,
				center + Vector2(-0.27, 0.27) * TREE_COVERAGE_CELL_SIZE,
				center + Vector2(0.27, 0.27) * TREE_COVERAGE_CELL_SIZE,
			]
			for candidate in candidates:
				if _tree_coverage_point_allowed(candidate):
					primary = candidate
					primary_points.append(candidate)
					break
			# Algunos compañeros rompen la lectura geométrica sin crear nodos nuevos:
			# todas las instancias siguen agrupadas en los mismos MultiMesh por celda.
			if _random.randf() < 0.42:
				var companion := center + Vector2(
					_random.randf_range(-0.43, 0.43),
					_random.randf_range(-0.43, 0.43)
				) * TREE_COVERAGE_CELL_SIZE
				if primary.x != INF and companion.distance_to(primary) > 17.0 and _tree_coverage_point_allowed(companion):
					companion_points.append(companion)
	# Nunca se recorta un punto primario: hacerlo podría reabrir justo la celda que
	# este pase pretende garantizar. Sólo se barajan y limitan los acompañantes.
	for index in range(companion_points.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := companion_points[index]
		companion_points[index] = companion_points[swap_index]
		companion_points[swap_index] = temporary
	generated_coverage_primary_tree_count = primary_points.size()
	var result := primary_points
	var companion_budget := maxi(target_count - result.size(), 0)
	for index in mini(companion_budget, companion_points.size()):
		result.append(companion_points[index])
	return result


func _tree_coverage_point_allowed(point: Vector2) -> bool:
	if not _tree_point_allowed(point):
		return false
	# La cobertura anti-calvas sólo consume presupuesto sobre pradera. Nieve,
	# roca y Bosque Tenebroso mantienen sus agrupaciones propias por bioma.
	var terrain_material := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
	var base_is_grass := int(terrain_material.x) == 0
	var overlay_is_grass := int(terrain_material.y) == 0
	var blend := terrain_material.z
	return (base_is_grass and (overlay_is_grass or blend < 0.70)) or (overlay_is_grass and blend > 0.30)


func _tree_point_allowed(point: Vector2) -> bool:
	if (
		distance_to_route(point) < 11.5
		or _inside_clearing(point, 13.5, 23.0)
		or _inside_village_clearing(point, 5.0)
		or _inside_desert(point)
		or _slope_at(point) > 0.80
	):
		return false
	var height := _height_at(point)
	if is_nan(height) or height < 3.0:
		return false
	var terrain_material := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
	return int(terrain_material.x) in [0, 2, 4]


func _forest_zone_point() -> Vector2:
	var zone_index := _random.randi_range(0, FOREST_ZONES.size() - 1)
	var zone := FOREST_ZONES[zone_index]
	var angle := _random.randf_range(0.0, TAU)
	var radius := sqrt(_random.randf())
	# Bordes ondulados y solapados: las reservas dejan de leerse como óvalos.
	var distortion := 0.90 + sin(angle * 3.0 + zone_index * 1.73) * 0.16
	distortion += sin(angle * 7.0 - zone_index * 0.81) * 0.08
	return Vector2(zone.x + cos(angle) * zone.z * radius * distortion, zone.y + sin(angle) * zone.w * radius * distortion)


func _inside_desert(point: Vector2) -> bool:
	var core := _gaussian_strength(point, Vector2(2400.0, 2050.0), Vector2(1450.0, 1120.0))
	var coast := _gaussian_strength(point, Vector2(4380.0, 2500.0), Vector2(1550.0, 1180.0))
	var southern := _gaussian_strength(point, Vector2(2450.0, 3550.0), Vector2(1750.0, 760.0))
	var dunes := maxf(core, maxf(coast * 0.96, southern * 0.78)) > 0.34
	var cliff_local := point - Vector2(3500.0, 1800.0)
	var cliffs := pow(cliff_local.x / 1550.0, 2.0) + pow(cliff_local.y / 1750.0, 2.0) < 1.0
	var coastal_beach := _coast_ratio(point) > 0.815
	return dunes or cliffs or coastal_beach


func _snow_probability(point: Vector2, height: float) -> float:
	# La nieve solo aparece en la cordillera septentrional. La altura produce
	# tres franjas continuas: verde abajo, mezcla en media montaña y blanco arriba.
	var northern := _gaussian_strength(point, Vector2(150.0, -3400.0), Vector2(1650.0, 1250.0))
	var west := _gaussian_strength(point, Vector2(-1050.0, -4070.0), Vector2(1250.0, 660.0)) * 0.70
	var east := _gaussian_strength(point, Vector2(1320.0, -4210.0), Vector2(1420.0, 620.0)) * 0.66
	var irregularity := 0.86 + sin(point.x * 0.0027 + point.y * 0.0018) * 0.12
	var snow_strength := maxf(northern, maxf(west, east)) * irregularity * smoothstep(90.0, 260.0, height)
	return smoothstep(0.15, 0.60, snow_strength)


func _mystery_forest_strength(point: Vector2) -> float:
	var core := _gaussian_strength(point, Vector2(4380.0, -1320.0), Vector2(1420.0, 1080.0))
	var north := _gaussian_strength(point, Vector2(3950.0, -2550.0), Vector2(1180.0, 780.0)) * 0.82
	var coast := _gaussian_strength(point, Vector2(5200.0, -620.0), Vector2(820.0, 980.0)) * 0.88
	var veins := 0.86 + sin(point.x * 0.0034 + point.y * 0.0021) * 0.11
	return clampf(maxf(core, maxf(north, coast)) * veins, 0.0, 1.0)


func _gaussian_strength(point: Vector2, center: Vector2, spread: Vector2) -> float:
	var offset := point - center
	return exp(-((offset.x * offset.x) / (2.0 * spread.x * spread.x) + (offset.y * offset.y) / (2.0 * spread.y * spread.y)))


func _coast_ratio(point: Vector2) -> float:
	var angle := atan2(point.y, point.x)
	var cosine := cos(angle)
	var sine := sin(angle)
	var ellipse_radius := 1.0 / sqrt((cosine * cosine) / (4740.0 * 4740.0) + (sine * sine) / (4540.0 * 4540.0))
	var mystery_angle := atan2(sin(angle + 0.27), cos(angle + 0.27))
	var extension := 1200.0 * exp(-(mystery_angle * mystery_angle) / (2.0 * 0.27 * 0.27))
	var desert_angle := atan2(sin(angle - 0.50), cos(angle - 0.50))
	var desert_shoulder := 420.0 * exp(-(desert_angle * desert_angle) / (2.0 * 0.32 * 0.32))
	var north_neck_angle := atan2(sin(angle + 0.82), cos(angle + 0.82))
	var north_inlet := 350.0 * exp(-(north_neck_angle * north_neck_angle) / (2.0 * 0.20 * 0.20))
	var south_neck_angle := atan2(sin(angle - 0.04), cos(angle - 0.04))
	var south_inlet := 430.0 * exp(-(south_neck_angle * south_neck_angle) / (2.0 * 0.18 * 0.18))
	var wobble := sin(angle * 7.0) * 0.018 + sin(angle * 13.0 + 0.7) * 0.009
	return point.length() / (ellipse_radius + extension + desert_shoulder - north_inlet - south_inlet) + wobble


func _inside_clearing(point: Vector2, start_radius: float, lookout_radius: float) -> bool:
	return point.distance_to(PLAYER_START) < start_radius or point.distance_to(HORSE_START) < start_radius or point.distance_to(LOOKOUT) < lookout_radius


func _inside_village_clearing(point: Vector2, padding: float = 0.0) -> bool:
	for index in VILLAGE_CLEARINGS.size():
		var clearing := VILLAGE_CLEARINGS[index]
		var center := Vector2(clearing.x, clearing.y)
		# Las villas con fortaleza usaban un círculo vacío de 380 m de diámetro.
		# Ajustamos por separado el caserío y la fortaleza desplazada para recuperar
		# pradera arbolada sin atravesar casas, murallas ni patios.
		if clearing.z >= 180.0:
			if point.distance_to(center) < 88.0 + padding:
				return true
			var yaw := STONE_VILLAGES[index].z
			var castle_center := center + Vector2(125.0, 3.0).rotated(yaw)
			var castle_local := (point - castle_center).rotated(-yaw)
			if absf(castle_local.x) < 76.0 + padding and absf(castle_local.y) < 64.0 + padding:
				return true
		elif point.distance_to(center) < clearing.z + padding:
			return true
	for clearing in RURAL_CLEARINGS:
		if point.distance_to(Vector2(clearing.x, clearing.y)) < clearing.z + padding:
			return true
	return false


func _inside_stone_village_street(point: Vector2, padding: float = 0.0) -> bool:
	# Dos ejes cortos por villa: cruzan únicamente el hueco entre las casas. Esta
	# misma huella se pinta directamente en Terrain3D y aquí se mantiene libre de
	# hierba, flores, arbustos y guijarros para que nunca reaparezca vegetación.
	for village in STONE_VILLAGES:
		var center := Vector2(village.x, village.y)
		var local := (point - center).rotated(-village.z)
		var main_distance := _distance_to_segment_2d(local, Vector2(0.0, -58.0), Vector2(0.0, 64.0))
		var cross_distance := _distance_to_segment_2d(local, Vector2(-58.0, 0.0), Vector2(58.0, 0.0))
		if minf(main_distance, cross_distance) < 9.0 + padding:
			return true
	return false


func _distance_to_segment_2d(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)


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
