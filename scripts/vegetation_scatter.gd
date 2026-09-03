class_name VegetationScatter
extends Node3D

## Valle estilizado construido exclusivamente con el Stylized Nature Mega Kit
## de Quaternius. Los modelos se cargan desde glTF y se agrupan por celdas en
## MultiMesh para mantener senderos frondosos y masas de bosque muy densas sin
## convertir cada planta en un draw call independiente.

const ASSET_ROOT := "res://assets/quaternius/store_bundle/glTF/"
const NATURE_OBJ_ROOT := "res://assets/quaternius/Nature Pack - Jun 2019/OBJ/"
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
const MOSS_ROCK_FILES: PackedStringArray = [
	"Rock_Moss_1.obj", "Rock_Moss_3.obj", "Rock_Moss_6.obj",
]
const CACTUS_FILES: PackedStringArray = [
	"Cactus_1.obj", "Cactus_3.obj", "CactusFlowers_3.obj",
]
const DENSE_GRASS_SOURCE_INDEX := 0
const UPRIGHT_GRASS_TRIAL := true
const GRASS_WIND_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 grass_tint : source_color = vec4(0.55, 0.82, 0.20, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float breeze_strength = 0.055;
uniform float gust_strength = 0.19;
uniform vec3 player_position = vec3(0.0, -10000.0, 0.0);
uniform float interaction_radius = 1.35;
uniform float lod_role = 0.0;
uniform float full_fade_start = 32.0;
uniform float full_fade_end = 55.0;
uniform float proxy_fade_start = 32.0;
uniform float proxy_fade_end = 55.0;
uniform float mid_fade_out_start = 95.0;
uniform float mid_fade_out_end = 125.0;
uniform float proxy_far_fade_start = 155.0;
uniform float proxy_far_fade_end = 195.0;
uniform float terrain_follow = 0.0;
uniform float ground_sink = -0.045;
uniform float procedural_blade = 0.0;

uniform float _vertex_density = 1.0;
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625;
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform highp sampler2DArray _height_maps : repeat_disable, filter_linear;

varying vec3 grass_world_position;
varying vec3 grass_anchor_position;
varying float grass_lod_visibility;

ivec3 terrain_index_coord(vec2 terrain_grid_position) {
	vec2 texel_position = floor(terrain_grid_position);
	ivec2 region_position = ivec2(floor(texel_position * _region_texel_size))
		+ ivec2(_region_map_size / 2);
	int in_bounds = int(uint(region_position.x | region_position.y) < uint(_region_map_size));
	ivec2 safe_position = clamp(
		region_position,
		ivec2(0),
		ivec2(_region_map_size - 1)
	);
	int layer_index = _region_map[safe_position.y * _region_map_size + safe_position.x]
		* in_bounds - 1;
	return ivec3(ivec2(mod(texel_position, _region_size)), layer_index);
}

float terrain_height_at(vec2 world_xz, float fallback_height) {
	vec2 terrain_grid_position = world_xz * _vertex_density;
	ivec3 terrain_index = terrain_index_coord(terrain_grid_position);
	if (terrain_index.z < 0) {
		return fallback_height;
	}
	vec2 height_uv = (mod(terrain_grid_position, _region_size) + vec2(0.5)) / _region_size;
	return textureLod(_height_maps, vec3(height_uv, float(terrain_index.z)), 0.0).r;
}

void vertex() {
	mat3 inverse_model_basis = inverse(mat3(MODEL_MATRIX));
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind_direction = normalize(vec2(0.84, 0.54));
	float wave_position = dot(world_position.xz, wind_direction);
	float height_mask = smoothstep(0.03, 0.88, VERTEX.y);
	if (terrain_follow > 0.5) {
		vec3 local_root = vec3(VERTEX.x, -0.10, VERTEX.z);
		vec3 world_root = (MODEL_MATRIX * vec4(local_root, 1.0)).xyz;
		float terrain_height = terrain_height_at(world_root.xz, world_root.y);
		vec3 local_ground_correction = inverse_model_basis
			* vec3(0.0, terrain_height - world_root.y + ground_sink, 0.0);
		VERTEX += local_ground_correction;
		world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	grass_anchor_position = world_position;
	float spatial_phase = world_position.x * 0.006 + world_position.z * 0.004;
	float soft_cycle = sin(TIME * 0.36 - spatial_phase) * 0.5 + 0.5;
	float strong_cycle = sin(TIME * 0.095 - spatial_phase * 0.43 + 1.7) * 0.5 + 0.5;
	float soft_gust = smoothstep(0.56, 0.91, soft_cycle);
	float strong_gust = smoothstep(0.84, 0.985, strong_cycle);
	float travelling_wave = sin(wave_position * 0.052 - TIME * (0.92 + strong_gust * 0.34));
	float fine_wave = sin(wave_position * 0.137 - TIME * 1.64 + soft_gust * 1.2);
	float gust_amplitude = breeze_strength
		+ gust_strength * (soft_gust * 0.38 + strong_gust * 1.08);
	float bend = gust_amplitude * (travelling_wave * 0.78 + fine_wave * 0.22) * height_mask;
	vec3 local_wind_direction = normalize(
		inverse_model_basis * vec3(wind_direction.x, 0.0, wind_direction.y)
	);
	VERTEX += local_wind_direction * bend;
	vec2 player_delta = world_position.xz - player_position.xz;
	float player_distance = length(player_delta);
	float interaction = 1.0 - smoothstep(interaction_radius * 0.28, interaction_radius, player_distance);
	vec2 outward = player_delta / max(player_distance, 0.001);
	vec3 local_outward = normalize(
		inverse_model_basis * vec3(outward.x, 0.0, outward.y)
	);
	VERTEX += local_outward * interaction * 0.52 * height_mask;
	VERTEX.y -= interaction * 0.13 * height_mask;
	grass_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float camera_distance = distance(CAMERA_POSITION_WORLD.xz, grass_world_position.xz);
	if (lod_role < 0.5) {
		grass_lod_visibility = 1.0 - smoothstep(full_fade_start, full_fade_end, camera_distance);
	} else if (lod_role > 1.5) {
		float near_visibility = smoothstep(proxy_fade_start, proxy_fade_end, camera_distance);
		float far_visibility = 1.0 - smoothstep(
			mid_fade_out_start,
			mid_fade_out_end,
			camera_distance
		);
		grass_lod_visibility = near_visibility * far_visibility;
	} else {
		float near_visibility = smoothstep(mid_fade_out_start, mid_fade_out_end, camera_distance);
		float far_visibility = 1.0 - smoothstep(
			proxy_far_fade_start,
			proxy_far_fade_end,
			camera_distance
		);
		grass_lod_visibility = near_visibility * far_visibility;
	}
}

void fragment() {
	vec2 dither_cell = floor(grass_anchor_position.xz * 3.75 + grass_anchor_position.y * 0.37);
	float stable_dither = fract(sin(dot(dither_cell, vec2(12.9898, 78.233))) * 43758.5453);
	if (grass_lod_visibility <= stable_dither) {
		discard;
	}
	vec4 tex = texture(albedo_texture, UV);
	if (procedural_blade > 0.5) {
		float normalized_height = clamp(UV.y, 0.0, 1.0);
		float blade_count = lod_role < 0.5 ? 2.0 : (lod_role > 1.5 ? 4.0 : 6.0);
		float blade_slot = UV.x * blade_count;
		float blade_index = floor(blade_slot);
		float blade_seed = fract(
			sin((blade_index + 1.0) * 27.619 + lod_role * 13.417) * 43758.5453
		);
		float blade_height = mix(0.64, 1.0, blade_seed);
		float blade_y = normalized_height / blade_height;
		float curved_center = sin(blade_y * 2.15 + blade_seed * 4.0)
			* 0.045 * blade_y;
		float local_x = abs(fract(blade_slot) - 0.5 - curved_center);
		float body_progress = min(blade_y / 0.88, 1.0);
		float body_half_width = mix(0.49, 0.22, pow(body_progress, 0.68));
		float cap_progress = clamp((blade_y - 0.88) / 0.12, 0.0, 1.0);
		float rounded_cap_width = 0.22 * sqrt(max(1.0 - cap_progress * cap_progress, 0.0));
		float half_width = blade_y < 0.88 ? body_half_width : rounded_cap_width;
		float blade_edge = 1.0 - smoothstep(
			max(half_width - 0.055, 0.0),
			half_width,
			local_x
		);
		float rounded_base = smoothstep(0.0, 0.035, blade_y);
		float blade_mask = blade_edge * rounded_base * step(blade_y, 1.0);
		if (blade_mask < 0.42) {
			discard;
		}
		float palette_selector = fract(
			sin(dot(floor(grass_anchor_position.xz * 5.0), vec2(39.346, 11.135)))
			* 18431.271
		);
		float palette_u = palette_selector < 0.54 ? 0.083 : 0.198;
		tex = texture(albedo_texture, vec2(palette_u, 1.0 - normalized_height));
	} else if (tex.a < 0.32) {
		discard;
	}

/*
	float broad_tint = sin(grass_world_position.x * 0.018)
		* sin(grass_world_position.z * 0.014) * 0.065;
	NORMAL = normalize(FRONT_FACING ? NORMAL : -NORMAL);
	ALBEDO = tex.rgb * (0.84 + broad_tint);
	EMISSION = tex.rgb * 0.025;
*/
	// Unifica toda la hierba al mismo tono que la pradera.
	tex.rgb = grass_tint.rgb;

	// Variación MUY ligera, para que no parezca completamente plana.
	float broad_tint = sin(grass_world_position.x * 0.018)
		* sin(grass_world_position.z * 0.014) * 0.012;

	//NORMAL = normalize(FRONT_FACING ? NORMAL : -NORMAL);
	//NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.45));
	vec3 face_normal = normalize(FRONT_FACING ? NORMAL : -NORMAL);
	NORMAL = normalize(mix(face_normal, vec3(0.0, 1.0, 0.0), 0.25));
	ALBEDO = grass_tint.rgb;
	EMISSION = tex.rgb * 0.01;
	//EMISSION = grass_tint.rgb * 0.03;

	ROUGHNESS = 0.98;
	SPECULAR = 0.08;


}
"""
const TREE_WIND_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float tint_mode = 0.0;
uniform float leaf_factor = 0.0;

varying vec3 tree_world_position;

void vertex() {
	vec3 instance_origin = MODEL_MATRIX[3].xyz;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float spatial_phase = world_position.x * 0.006 + world_position.z * 0.004;
	float soft_cycle = sin(TIME * 0.36 - spatial_phase) * 0.5 + 0.5;
	float strong_cycle = sin(TIME * 0.095 - spatial_phase * 0.43 + 1.7) * 0.5 + 0.5;
	float soft_gust = smoothstep(0.56, 0.91, soft_cycle);
	float strong_gust = smoothstep(0.84, 0.985, strong_cycle);
	float tree_phase = instance_origin.x * 0.021 + instance_origin.z * 0.017;
	float broad_wave = sin(TIME * (0.58 + strong_gust * 0.18) + tree_phase);
	float secondary_wave = sin(TIME * 1.31 + tree_phase * 1.73 + VERTEX.y * 0.31);
	float height_mask = smoothstep(1.15, 6.65, VERTEX.y);
	float gust_amplitude = 0.012 + soft_gust * 0.030 + strong_gust * 0.085;
	float branch_bend = gust_amplitude
		* (broad_wave * 0.82 + secondary_wave * 0.18)
		* height_mask;
	float surface_strength = mix(0.72, 1.0, leaf_factor);
	VERTEX.x += branch_bend * surface_strength;
	VERTEX.z += branch_bend * 0.58 * surface_strength;
	if (leaf_factor > 0.5) {
		float leaf_flutter = sin(TIME * 2.35 + tree_phase * 2.1 + VERTEX.x * 1.7)
			* (0.006 + soft_gust * 0.010 + strong_gust * 0.017) * height_mask;
		VERTEX.x += leaf_flutter;
		VERTEX.z -= leaf_flutter * 0.46;
	}
	tree_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	if (tex.a < 0.32) {
		discard;
	}
	vec3 color = tex.rgb;
	if (tint_mode > 1.5) {
		float leaf = smoothstep(0.015, 0.16, tex.g - max(tex.r, tex.b));
		vec3 shadowed_wood = tex.rgb * vec3(0.40, 0.30, 0.26);
		vec3 crimson_leaf = mix(
			vec3(0.16, 0.012, 0.018),
			vec3(0.58, 0.035, 0.025),
			tex.r + tex.g * 0.25
		);
		color = mix(shadowed_wood, crimson_leaf, leaf * 0.96);
	} else if (tint_mode > 0.5) {
		float green_mask = smoothstep(0.02, 0.18, tex.g - max(tex.r, tex.b));
		float pale_mask = smoothstep(
			0.58,
			0.92,
			dot(tex.rgb, vec3(0.299, 0.587, 0.114))
		) * 0.18;
		float snow_mask = clamp(green_mask * 0.96 + pale_mask, 0.0, 0.98);
		color = mix(tex.rgb, vec3(0.86, 0.92, 0.98), snow_mask);
	}
	float broad_light = sin(tree_world_position.x * 0.009)
		* sin(tree_world_position.z * 0.011) * 0.025;
	NORMAL = normalize(FRONT_FACING ? NORMAL : -NORMAL);
	ALBEDO = color * (1.0 + broad_light);
	ROUGHNESS = 0.94;
	SPECULAR = 0.08;
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
	vec3 shadowed_wood = tex.rgb * vec3(0.40, 0.30, 0.26);
	vec3 crimson_leaf = mix(vec3(0.16, 0.012, 0.018), vec3(0.58, 0.035, 0.025), tex.r + tex.g * 0.25);
	ALBEDO = mix(shadowed_wood, crimson_leaf, leaf * 0.96);
	ROUGHNESS = 0.96;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.32;
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
const TREE_COVERAGE_CELL_SIZE := 34.0
const TREE_COVERAGE_TARGET_RATIO := 0.55
const TREE_HARVEST_CELL_SIZE := 18.0
const TREE_HARVEST_HEALTH := 3
const TREE_LOD_SWITCH_DISTANCE := 340.0
const TREE_LOD_VISIBILITY_END := 5200.0
const TREE_LOD_HYSTERESIS := 18.0
const GRASS_CELL_SIZE := 96.0
const GRASS_FULL_FADE_START := 50.0
const GRASS_FULL_FADE_END := 80.0
const GRASS_NEAR_INDEX_CELL_SIZE := 24.0
const GRASS_NEAR_PRELOAD_RADIUS := 94.0
const GRASS_NEAR_REFRESH_DISTANCE := 2.25
const GRASS_PROXY_FADE_START := 42.0
const GRASS_PROXY_FADE_END := 72.0
const GRASS_MID_FADE_OUT_START := 120.0
const GRASS_MID_FADE_OUT_END := 160.0
const GRASS_MID_PRELOAD_RADIUS := 174.0
const GRASS_PROXY_FAR_FADE_START := 210.0
const GRASS_LOD_VISIBILITY_END := 260.0
const EXPLICIT_LOD_REFRESH_SECONDS := 0.12
const DETAIL_CELL_SIZE := 440.0
const GROUND_CELL_SIZE := 380.0
const GRASS_COVERAGE_SPACING := 13.0
const DENSE_GRASS_CLUSTER_COPIES := 1550
const DENSE_GRASS_PATCH_RADIUS := 11.0
const GRASS_MID_CLUSTER_COPIES := 220
const GRASS_LOD_CLUSTER_COPIES := 96
const MYSTERY_DEAD_TREE_COUNT := 4200
const LAYOUT_CACHE_PATH := "res://generated/vegetation_layout_cache.res"
const LAYOUT_CACHE_SCHEMA := 4
const FOREST_CACHE_STRIDE := 9
const GRASS_CACHE_STRIDE := 9

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export_category("Claro y bosque Quaternius")
@export var tree_count := 80000
@export_range(0.0, 0.15, 0.001) var autumn_tree_ratio := 0.004
@export var rock_count := 504
@export var moss_rock_count := 0
@export var cactus_count := 173
@export var grass_count := 220000
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
var generated_moss_rock_count := 0
var generated_cactus_count := 0
var generated_grass_count := 0
var generated_mystery_dead_tree_count := 0
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
var generated_breakable_resource_count := 0
var generated_harvestable_tree_count := 0
var generated_tree_lod_instances := 0
var generated_tree_lod_cells := 0
var generated_coverage_tree_count := 0
var generated_coverage_primary_tree_count := 0
var generated_grass_lod_instances := 0
var generated_grass_lod_cells := 0
var explicit_lod_visible_full_cells := 0
var explicit_lod_visible_proxy_cells := 0
var tree_positions: Array[Vector3] = []
var rock_positions: Array[Vector3] = []
var moss_rock_positions: Array[Vector3] = []

var _random := RandomNumberGenerator.new()
var _tree_meshes: Array[Mesh] = []
var _tree_lod_meshes: Array[Mesh] = []
var _grass_mid_lod_meshes: Array[Mesh] = []
var _grass_lod_meshes: Array[Mesh] = []
var _rock_meshes: Array[Mesh] = []
var _grass_meshes: Array[Mesh] = []
var _moss_rock_meshes: Array[Mesh] = []
var _cactus_meshes: Array[Mesh] = []
var _fern_meshes: Array[Mesh] = []
var _shrub_meshes: Array[Mesh] = []
var _flower_meshes: Array[Mesh] = []
var _mushroom_meshes: Array[Mesh] = []
var _dead_tree_meshes: Array[Mesh] = []
var _pebble_meshes: Array[Mesh] = []
var _snow_tree_offset := -1
var _mystery_tree_offset := -1
var _dense_grass_offset := -1
var _snow_fern_offset := -1
var _snow_shrub_offset := -1
var _snow_shader: Shader
var _tree_full_cells: Dictionary = {}
var _tree_proxy_cells: Dictionary = {}
var _grass_full_cells: Dictionary = {}
var _grass_proxy_cells: Dictionary = {}
var _grass_near_transform_cells: Dictionary = {}
var _grass_near_instance: MultiMeshInstance3D
var _grass_mid_instance: MultiMeshInstance3D
var _grass_near_last_focus := Vector2(INF, INF)
var _grass_near_active_instances := 0
var _grass_mid_active_instances := 0
var _tree_cell_states: Dictionary = {}
var _grass_cell_states: Dictionary = {}
var _explicit_lod_refresh_elapsed := 0.0
var _installed_multimeshes: Dictionary = {}
var _breakable_resources: Dictionary = {}
var _destroyed_resource_ids: Dictionary = {}
var _harvest_tree_positions: Array[Vector3] = []
var _harvest_tree_ids := PackedStringArray()
var _harvest_tree_full_keys := PackedStringArray()
var _harvest_tree_full_indices := PackedInt32Array()
var _harvest_tree_proxy_keys := PackedStringArray()
var _harvest_tree_proxy_indices := PackedInt32Array()
var _harvest_tree_full_originals: Array[Transform3D] = []
var _harvest_tree_proxy_originals: Array[Transform3D] = []
var _harvest_tree_cells: Dictionary = {}
var _harvest_tree_index_by_id: Dictionary = {}
var _harvest_tree_health: Dictionary = {}
var _tree_last_attack_serial: Dictionary = {}
var _tree_hit_tweens: Dictionary = {}
var _resource_hit_tweens: Dictionary = {}
var _harvest_stumps: Dictionary = {}
var _stump_mesh: CylinderMesh
var _active_layout_cache: VegetationLayoutCache
var _bake_layout_cache := false
var _profile_vegetation_startup := false
var _forest_cache_records := PackedFloat32Array()
var _grass_cache_records := PackedFloat32Array()
var _forest_cache_rng_state := 0
var _grass_cache_rng_state := 0
var _forest_cache_counts: Dictionary = {}
var _tree_collision_records := PackedFloat32Array()
var _tree_collision_resource_ids := PackedStringArray()
var _forest_collision_shape: ConcavePolygonShape3D
var _forest_collision_node: CollisionShape3D
var _grass_wind_materials: Array[ShaderMaterial] = []
var _tree_wind_material_count := 0
var _grass_interaction_target: Node3D


func _ready() -> void:
	var startup_stage := Time.get_ticks_msec()
	_bake_layout_cache = "--bake-vegetation" in OS.get_cmdline_user_args()
	_profile_vegetation_startup = _bake_layout_cache or "--profile-vegetation" in OS.get_cmdline_user_args()
	_active_layout_cache = _load_layout_cache()
	_random.seed = random_seed
	set_meta("project_assets_loaded_via_importer", true)
	set_meta("explicit_tree_lod", true)
	set_meta("dense_static_grass_lod", true)
	set_meta("grass_patch_clumps", DENSE_GRASS_CLUSTER_COPIES)
	set_meta("exclusive_tree_lod_pairs", true)
	set_meta("grass_lod_crossfade", true)
	var green_tree_meshes := _load_mesh_library(GREEN_TREE_FILES)
	var autumn_tree_meshes := _load_mesh_library(AUTUMN_TREE_FILES)
	_tree_meshes = green_tree_meshes.duplicate()
	_tree_meshes.append_array(autumn_tree_meshes)
	_snow_tree_offset = _tree_meshes.size()
	_tree_meshes.append_array(_make_snow_mesh_library(green_tree_meshes))
	_mystery_tree_offset = _tree_meshes.size()
	# El Bosque Tenebroso abandona las copas azules: sólo usa los árboles
	# retorcidos rojos del pack, oscurecidos hacia carmesí.
	_tree_meshes.append_array(_make_mystery_mesh_library(autumn_tree_meshes))
	_tree_lod_meshes = _make_tree_lod_mesh_library()
	_rock_meshes = _load_mesh_library(ROCK_FILES)
	_cactus_meshes = _make_cactus_mesh_library()
	_grass_meshes = _load_mesh_library(GRASS_FILES)
	var dense_grass_source := _grass_meshes[DENSE_GRASS_SOURCE_INDEX] if _grass_meshes.size() > DENSE_GRASS_SOURCE_INDEX else null
	if dense_grass_source != null:
		dense_grass_source = _make_grass_card_source(dense_grass_source)
		_dense_grass_offset = _grass_meshes.size()
		_grass_meshes.append(_make_dense_grass_patch_mesh(dense_grass_source))
	_grass_mid_lod_meshes = [
		_make_grass_mid_lod_mesh(
			dense_grass_source,
			GRASS_MID_CLUSTER_COPIES,
			DENSE_GRASS_PATCH_RADIUS
		),
	]
	_grass_lod_meshes = [
		_make_grass_lod_mesh(
			dense_grass_source,
			GRASS_LOD_CLUSTER_COPIES,
			DENSE_GRASS_PATCH_RADIUS
		),
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
		_tree_meshes.is_empty() or _rock_meshes.is_empty()
		or _cactus_meshes.is_empty() or _grass_meshes.is_empty() or _dense_grass_offset < 0
		or _fern_meshes.is_empty() or _shrub_meshes.is_empty() or _flower_meshes.is_empty()
		or _mushroom_meshes.is_empty() or _dead_tree_meshes.is_empty() or _pebble_meshes.is_empty()
	):
		push_error("No se pudo cargar la biblioteca visual Quaternius completa.")
		return
	_apply_tree_wind_materials()
	_apply_grass_wind_materials()
	_grass_interaction_target = get_node_or_null("../Player") as Node3D
	startup_stage = _startup_checkpoint("carga de mallas", startup_stage)

	_scatter_forest()
	startup_stage = _startup_checkpoint("bosque", startup_stage)
	_scatter_rocks()
	startup_stage = _startup_checkpoint("rocas", startup_stage)
	_scatter_moss_rocks()
	_scatter_desert_cacti()
	startup_stage = _startup_checkpoint("cactus", startup_stage)
	_scatter_ground_cover()
	startup_stage = _startup_checkpoint("hierba", startup_stage)
	if _bake_layout_cache:
		_save_layout_cache()
	_scatter_color_details()
	startup_stage = _startup_checkpoint("detalle de color", startup_stage)
	_scatter_path_pebbles()
	startup_stage = _startup_checkpoint("guijarros", startup_stage)
	_scatter_forest_details()
	startup_stage = _startup_checkpoint("detalle de bosque", startup_stage)
	_scatter_mystery_dead_trees()
	_finalize_harvest_tree_registry()
	_startup_checkpoint("árboles secos", startup_stage)
	_finalize_tree_collision_mesh()
	call_deferred("_update_explicit_lod_visibility", true)
	print(
		"QUATERNIUS VALLEY READY: %d árboles verdes, %d nevados, %d rojos tenebrosos, %d otoñales y %d secos tenebrosos; %d rocas desérticas, %d rocas hundidas desérticas, %d cactus grandes y %d parches densos de hierba exclusivamente verde en %d celdas."
		% [generated_green_tree_count, generated_snow_tree_count, generated_mystery_tree_count, generated_autumn_tree_count, generated_mystery_dead_tree_count, generated_rock_count, generated_moss_rock_count, generated_cactus_count, generated_grass_count, generated_cell_count]
	)


func _startup_checkpoint(label: String, started_msec: int) -> int:
	var now := Time.get_ticks_msec()
	if _profile_vegetation_startup:
		print("VEGETATION STARTUP · %s: %.3f s" % [label, float(now - started_msec) / 1000.0])
	return now


func _layout_cache_signature() -> String:
	# Incrementar LAYOUT_CACHE_SCHEMA cuando cambien filtros, alturas, escalas o
	# materiales que afecten al reparto de árbol/hierba.
	return "v%d|seed=%d|trees=%d|grass=%d|tc=%.2f|gc=%.2f|scale=2.20-4.00" % [
		LAYOUT_CACHE_SCHEMA,
		random_seed,
		tree_count,
		grass_count,
		TREE_COVERAGE_CELL_SIZE,
		GRASS_COVERAGE_SPACING,
	]


func _load_layout_cache() -> VegetationLayoutCache:
	if _bake_layout_cache or not ResourceLoader.exists(LAYOUT_CACHE_PATH):
		return null
	var cache := ResourceLoader.load(LAYOUT_CACHE_PATH) as VegetationLayoutCache
	if (
		cache == null
		or cache.schema_version != LAYOUT_CACHE_SCHEMA
		or cache.signature != _layout_cache_signature()
		or cache.forest_records.size() != tree_count * FOREST_CACHE_STRIDE
		or cache.grass_records.size() != grass_count * GRASS_CACHE_STRIDE
	):
		push_warning("El layout de vegetación está desactualizado; se regenerará en ejecución.")
		return null
	set_meta("vegetation_layout_cache", LAYOUT_CACHE_PATH)
	set_meta("vegetation_layout_cached", true)
	return cache


func _save_layout_cache() -> void:
	if (
		_forest_cache_records.size() != tree_count * FOREST_CACHE_STRIDE
		or _grass_cache_records.size() != grass_count * GRASS_CACHE_STRIDE
	):
		push_error("No se puede hornear vegetación: los registros no están completos.")
		return
	var cache := VegetationLayoutCache.new()
	cache.schema_version = LAYOUT_CACHE_SCHEMA
	cache.signature = _layout_cache_signature()
	cache.forest_records = _forest_cache_records
	cache.grass_records = _grass_cache_records
	cache.forest_rng_state = _forest_cache_rng_state
	cache.grass_rng_state = _grass_cache_rng_state
	cache.forest_counts = _forest_cache_counts.duplicate(true)
	var absolute_directory := ProjectSettings.globalize_path(LAYOUT_CACHE_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	var error := ResourceSaver.save(cache, LAYOUT_CACHE_PATH, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("No se pudo guardar el layout horneado: %s" % error_string(error))
		return
	print("VEGETATION CACHE BAKED: %s" % LAYOUT_CACHE_PATH)


func _process(delta: float) -> void:
	_update_grass_interaction()
	_explicit_lod_refresh_elapsed += delta
	if _explicit_lod_refresh_elapsed < EXPLICIT_LOD_REFRESH_SECONDS:
		return
	_explicit_lod_refresh_elapsed = 0.0
	_update_explicit_lod_visibility(false)


func _update_grass_interaction() -> void:
	if _grass_interaction_target == null:
		_grass_interaction_target = get_node_or_null("../Player") as Node3D
	var target_position := Vector3(0.0, -10000.0, 0.0)
	if _grass_interaction_target != null:
		target_position = _grass_interaction_target.global_position
	for material in _grass_wind_materials:
		material.set_shader_parameter("player_position", target_position)


func _scatter_forest() -> void:
	if _active_layout_cache != null:
		_scatter_forest_from_cache(_active_layout_cache)
		return
	var profile_stage := Time.get_ticks_msec()
	var buckets: Dictionary = {}
	var lod_buckets: Dictionary = {}
	# Una retícula irregular cubre primero toda pradera válida. El reparto
	# aleatorio anterior podía colocar 52.000 árboles y aun dejar calvas enormes.
	# El resto del presupuesto conserva las masas densas y senderos arbolados.
	var coverage_points := _build_tree_coverage_points(roundi(tree_count * TREE_COVERAGE_TARGET_RATIO))
	profile_stage = _startup_checkpoint("bosque/retícula", profile_stage)
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
		var mystery_strength := _mystery_forest_strength(point)
		# Dentro del bioma tenebroso no se permite que el azar vuelva a introducir
		# árboles verdes o nevados: el límite irregular decide el bioma completo.
		var mystery := mystery_strength > 0.26
		var snow_probability := _snow_probability(point, height)
		# La retícula anti-calvas también alcanza la nieve, pero allí se aclara de
		# forma gradual hasta conservar aproximadamente el 80 % en las cumbres. Los
		# ejemplares descartados se recuperan en otros biomas al continuar el bucle.
		var snow_thinning := smoothstep(0.18, 0.72, snow_probability)
		if snow_thinning > 0.0 and _random.randf() > lerpf(1.0, 0.80, snow_thinning):
			continue
		var snowy := not mystery and _random.randf() < snow_probability
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
			local_tree_variant = _random.randi_range(0, AUTUMN_TREE_FILES.size() - 1)
			variant = _mystery_tree_offset + local_tree_variant
			generated_mystery_tree_count += 1
		elif autumn:
			variant = GREEN_TREE_FILES.size() + _random.randi_range(0, AUTUMN_TREE_FILES.size() - 1)
			generated_autumn_tree_count += 1
		else:
			variant = local_tree_variant
			generated_green_tree_count += 1
		# Escala amplia pero equilibrada: conserva un bosque tupido sin que los
		# ejemplares oculten demasiado el paisaje y los caminos.
		var scale_value := _random.randf_range(2.20, 4.00)
		if local_tree_variant >= 5:
			scale_value *= _random.randf_range(1.05, 1.30)
		var position := Vector3(point.x, height + 0.10, point.y)
		var yaw := _random.randf_range(0.0, TAU)
		var transform := _make_transform(position, yaw, Vector3.ONE * scale_value)
		var full_reference := _bucket_transform_reference(
			buckets,
			variant,
			point,
			TREE_CELL_SIZE,
			transform
		)
		var lod_variant := _tree_lod_variant(snowy, mystery, autumn, local_tree_variant)
		var proxy_reference := _bucket_transform_reference(
			lod_buckets, lod_variant, point, TREE_LOD_CELL_SIZE, transform
		)
		tree_positions.append(position)
		var tree_resource_id := _stable_scatter_resource_id("forest_tree", point)
		_register_harvest_tree_reference(
			position,
			tree_resource_id,
			"TreeCells|%s" % String(full_reference.bucket_key),
			int(full_reference.instance_index),
			"TreeLODCells|%s" % String(proxy_reference.bucket_key),
			int(proxy_reference.instance_index)
		)
		if uses_coverage_point:
			generated_coverage_tree_count += 1
		# Colisión completa alrededor de las rutas jugables y una muestra densa en
		# el bosque profundo. La geometría distante sigue siendo MultiMesh barata.
		var has_collision := distance_to_route(point) < 34.0 or generated_tree_count % 16 == 0
		if has_collision:
			_add_tree_collision(
				position, _tree_meshes[variant].get_aabb(), scale_value, tree_resource_id
			)
			generated_tree_collision_count += 1
		if _bake_layout_cache:
			for value in [
				position.x, position.y, position.z, yaw, scale_value,
				float(variant), float(lod_variant), 1.0 if has_collision else 0.0,
				1.0 if uses_coverage_point else 0.0,
			]:
				_forest_cache_records.append(float(value))
		generated_tree_count += 1
	_forest_cache_rng_state = _random.state
	_forest_cache_counts = {
		"green": generated_green_tree_count,
		"snow": generated_snow_tree_count,
		"mystery": generated_mystery_tree_count,
		"autumn": generated_autumn_tree_count,
		"coverage": generated_coverage_tree_count,
		"coverage_primary": generated_coverage_primary_tree_count,
	}
	profile_stage = _startup_checkpoint("bosque/distribución", profile_stage)
	_install_cell_buckets("TreeCells", buckets, _tree_meshes, 0.0, true)
	profile_stage = _startup_checkpoint("bosque/multimesh cercano", profile_stage)
	var full_tree_root := get_node("TreeCells") as Node3D
	full_tree_root.set_meta("lod_tier", "full")
	full_tree_root.set_meta("switch_distance", lod_switch_distance)
	full_tree_root.set_meta("coverage_cell_size", TREE_COVERAGE_CELL_SIZE)
	full_tree_root.set_meta("coverage_tree_count", generated_coverage_tree_count)
	full_tree_root.set_meta("coverage_primary_tree_count", generated_coverage_primary_tree_count)
	_install_tree_lod_buckets(lod_buckets)
	_startup_checkpoint("bosque/multimesh LOD", profile_stage)


func _scatter_forest_from_cache(cache: VegetationLayoutCache) -> void:
	var started := Time.get_ticks_msec()
	var profile_stage := started
	var buckets: Dictionary = {}
	var lod_buckets: Dictionary = {}
	var records := cache.forest_records
	for offset in range(0, records.size(), FOREST_CACHE_STRIDE):
		var position := Vector3(records[offset], records[offset + 1], records[offset + 2])
		var point := Vector2(position.x, position.z)
		var yaw := records[offset + 3]
		var scale_value := records[offset + 4]
		var variant := roundi(records[offset + 5])
		var lod_variant := roundi(records[offset + 6])
		var transform := _make_transform(position, yaw, Vector3.ONE * scale_value)
		var full_reference := _bucket_transform_reference(
			buckets, variant, point, TREE_CELL_SIZE, transform
		)
		var proxy_reference := _bucket_transform_reference(
			lod_buckets, lod_variant, point, TREE_LOD_CELL_SIZE, transform
		)
		tree_positions.append(position)
		var tree_resource_id := _stable_scatter_resource_id("forest_tree", point)
		_register_harvest_tree_reference(
			position,
			tree_resource_id,
			"TreeCells|%s" % String(full_reference.bucket_key),
			int(full_reference.instance_index),
			"TreeLODCells|%s" % String(proxy_reference.bucket_key),
			int(proxy_reference.instance_index)
		)
		if records[offset + 7] > 0.5:
			_add_tree_collision(
				position, _tree_meshes[variant].get_aabb(), scale_value, tree_resource_id
			)
			generated_tree_collision_count += 1
		generated_tree_count += 1
	profile_stage = _startup_checkpoint("bosque horneado/instancias y colisiones (%d)" % generated_tree_collision_count, profile_stage)
	generated_green_tree_count = int(cache.forest_counts.get("green", 0))
	generated_snow_tree_count = int(cache.forest_counts.get("snow", 0))
	generated_mystery_tree_count = int(cache.forest_counts.get("mystery", 0))
	generated_autumn_tree_count = int(cache.forest_counts.get("autumn", 0))
	generated_coverage_tree_count = int(cache.forest_counts.get("coverage", 0))
	generated_coverage_primary_tree_count = int(cache.forest_counts.get("coverage_primary", 0))
	_install_cell_buckets("TreeCells", buckets, _tree_meshes, 0.0, true)
	profile_stage = _startup_checkpoint("bosque horneado/multimesh cercano", profile_stage)
	var full_tree_root := get_node("TreeCells") as Node3D
	full_tree_root.set_meta("lod_tier", "full")
	full_tree_root.set_meta("switch_distance", lod_switch_distance)
	full_tree_root.set_meta("coverage_cell_size", TREE_COVERAGE_CELL_SIZE)
	full_tree_root.set_meta("coverage_tree_count", generated_coverage_tree_count)
	full_tree_root.set_meta("coverage_primary_tree_count", generated_coverage_primary_tree_count)
	_install_tree_lod_buckets(lod_buckets)
	_startup_checkpoint("bosque horneado/multimesh LOD", profile_stage)
	_random.state = cache.forest_rng_state
	_startup_checkpoint("bosque horneado", started)


func _scatter_rocks() -> void:
	var buckets: Dictionary = {}
	var breakable_specs: Array[Dictionary] = []
	var attempts := 0
	while generated_rock_count < rock_count and attempts < rock_count * 72:
		attempts += 1
		var point := Vector2(
			_random.randfn(2600.0, 1120.0),
			_random.randfn(2100.0, 820.0)
		)
		if (
			not _desert_decoration_point_allowed(point)
			or distance_to_route(point) < 10.0
			or _inside_clearing(point, 9.0, 16.0)
			or _inside_village_clearing(point, 1.0)
		):
			continue
		var height := _height_at(point)
		if is_nan(height) or height < 2.0:
			continue
		var variant := _random.randi_range(0, _rock_meshes.size() - 1)
		var scale_value := _random.randf_range(0.50, 1.44)
		var scale_vector := Vector3(
			scale_value * _random.randf_range(0.78, 1.30),
			scale_value * _random.randf_range(0.72, 1.08),
			scale_value * _random.randf_range(0.82, 1.26)
		)
		var position := Vector3(point.x, height - scale_value * _random.randf_range(0.03, 0.10), point.y)
		var reference := _bucket_transform_reference(
			buckets, variant, point, DETAIL_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), scale_vector)
		)
		breakable_specs.append({
			"resource_id": _stable_scatter_resource_id("desert_rock", point),
			"kind": "rock",
			"position": position,
			"size": _rock_meshes[variant].get_aabb().size * scale_vector,
			"bucket_key": String(reference.bucket_key),
			"instance_index": int(reference.instance_index),
		})
		rock_positions.append(position)
		generated_rock_count += 1
	_install_cell_buckets("RockCells", buckets, _rock_meshes, 420.0, true)
	for spec in breakable_specs:
		_add_scatter_breakable(spec)
	var root := get_node("RockCells") as Node3D
	root.set_meta("desert_only", true)
	root.set_meta("sunk_into_ground", true)
	root.set_meta("excluded_from_cliffs", true)


func _scatter_moss_rocks() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_moss_rock_count < moss_rock_count and attempts < moss_rock_count * 72:
		attempts += 1
		var point := Vector2(
			_random.randfn(2600.0, 1120.0),
			_random.randfn(2100.0, 820.0)
		)
		# Estas rocas ligeramente hundidas pertenecen sólo a la arena del desierto.
		# Se descartan expresamente playas, paredes y taludes abruptos.
		if (
			not _desert_decoration_point_allowed(point)
			or distance_to_route(point) < 9.0
			or _inside_clearing(point, 8.0, 14.0)
			or _inside_village_clearing(point, 2.0)
		):
			continue
		var height := _height_at(point)
		if is_nan(height) or height < 2.0:
			continue
		var variant := _random.randi_range(0, _moss_rock_meshes.size() - 1)
		var scale_value := _random.randf_range(2.15, 4.55)
		var scale_vector := Vector3(
			scale_value * _random.randf_range(0.82, 1.22),
			scale_value * _random.randf_range(0.72, 1.02),
			scale_value * _random.randf_range(0.84, 1.20)
		)
		# La ligera penetración elimina el aspecto de roca apoyada sobre una mesa.
		var position := Vector3(point.x, height - scale_value * _random.randf_range(0.06, 0.14), point.y)
		_bucket_transform(
			buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), scale_vector)
		)
		if distance_to_route(point) < 31.0 or generated_moss_rock_count % 9 == 0:
			_add_rock_collision(position, _moss_rock_meshes[variant].get_aabb().size * scale_vector)
			generated_rock_collision_count += 1
		moss_rock_positions.append(position)
		generated_moss_rock_count += 1
	_install_cell_buckets("MossRockCells", buckets, _moss_rock_meshes, 680.0, true)
	var root := get_node("MossRockCells") as Node3D
	root.set_meta("sunk_into_ground", true)
	root.set_meta("desert_only", true)
	root.set_meta("excluded_from_cliffs", true)


func _scatter_desert_cacti() -> void:
	var buckets: Dictionary = {}
	var breakable_specs: Array[Dictionary] = []
	var attempts := 0
	while generated_cactus_count < cactus_count and attempts < cactus_count * 60:
		attempts += 1
		var point := Vector2(
			_random.randfn(2600.0, 1120.0),
			_random.randfn(2100.0, 820.0)
		)
		if (
			not _inside_desert_core(point)
			or _coast_ratio(point) > 0.77
			or _slope_at(point) > 0.30
			or distance_to_route(point) < 13.0
			or _inside_village_clearing(point, 5.0)
		):
			continue
		var height := _height_at(point)
		if is_nan(height) or height < 2.0:
			continue
		var variant := _random.randi_range(0, _cactus_meshes.size() - 1)
		var scale_value := _random.randf_range(3.6, 6.9)
		var scale_vector := Vector3(
			scale_value * _random.randf_range(0.86, 1.14),
			scale_value,
			scale_value * _random.randf_range(0.86, 1.14)
		)
		var position := Vector3(point.x, height + 0.02, point.y)
		var reference := _bucket_transform_reference(
			buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), scale_vector)
		)
		breakable_specs.append({
			"resource_id": _stable_scatter_resource_id("desert_cactus", point),
			"kind": "cactus",
			"position": position,
			"size": _cactus_meshes[variant].get_aabb().size * scale_vector,
			"bucket_key": String(reference.bucket_key),
			"instance_index": int(reference.instance_index),
		})
		generated_cactus_count += 1
	_install_cell_buckets("CactusCells", buckets, _cactus_meshes, 1250.0, true)
	for spec in breakable_specs:
		_add_scatter_breakable(spec)
	var root := get_node("CactusCells") as Node3D
	root.set_meta("nature_pack_source", "Nature Pack - Jun 2019")
	root.set_meta("desert_core_only", true)


func _scatter_ground_cover() -> void:
	var profile_stage := Time.get_ticks_msec()
	_grass_near_transform_cells.clear()
	var grass_lod_buckets: Dictionary = {}
	if _active_layout_cache != null:
		var records := _active_layout_cache.grass_records
		for offset in range(0, records.size(), GRASS_CACHE_STRIDE):
			var position := Vector3(records[offset], records[offset + 1], records[offset + 2])
			var point := Vector2(position.x, position.z)
			var transform := _make_ground_aligned_transform(
				position,
				records[offset + 3],
				Vector3(records[offset + 4], records[offset + 5], records[offset + 6]),
				Vector2(records[offset + 7], records[offset + 8])
			)
			_index_near_grass_transform(point, transform)
			_bucket_transform(grass_lod_buckets, 0, point, GRASS_CELL_SIZE, transform)
			generated_grass_count += 1
		_random.state = _active_layout_cache.grass_rng_state
	else:
		var coverage_points := _build_grass_coverage_points(grass_count)
		profile_stage = _startup_checkpoint("hierba/retícula", profile_stage)
		for point in coverage_points:
			var height := _height_at(point)
			var variant := _dense_grass_offset
			var scale_value := _random.randf_range(0.88, 1.16)
			var scale_vector := Vector3(
				scale_value * _random.randf_range(0.92, 1.08),
				scale_value,
				scale_value * _random.randf_range(0.92, 1.08)
			)
			var position := Vector3(point.x, height + 0.02, point.y)
			var yaw := _random.randf_range(0.0, TAU)
			var terrain_gradient := _terrain_gradient_at(point, height)
			var transform := _make_ground_aligned_transform(position, yaw, scale_vector, terrain_gradient)
			_index_near_grass_transform(point, transform)
			_bucket_transform(grass_lod_buckets, 0, point, GRASS_CELL_SIZE, transform)
			if _bake_layout_cache:
				for value in [
					position.x, position.y, position.z, yaw,
					scale_vector.x, scale_vector.y, scale_vector.z,
					terrain_gradient.x, terrain_gradient.y,
				]:
					_grass_cache_records.append(float(value))
			generated_grass_count += 1
		_grass_cache_rng_state = _random.state
	profile_stage = _startup_checkpoint("hierba/distribución", profile_stage)
	_install_grass_near_field()
	profile_stage = _startup_checkpoint("hierba/campo cercano", profile_stage)
	_install_grass_lod_buckets(grass_lod_buckets)
	_startup_checkpoint("hierba/multimesh LOD", profile_stage)
	var grass_root := get_node("GrassCells") as Node3D
	grass_root.set_meta("coverage", "all_green_terrain")
	grass_root.set_meta("excluded_biomes", PackedStringArray(["snow", "desert", "mystery_forest"]))
	grass_root.set_meta("source_model", GRASS_FILES[DENSE_GRASS_SOURCE_INDEX])
	grass_root.set_meta("clumps_per_instance", DENSE_GRASS_CLUSTER_COPIES)
	grass_root.set_meta("effective_clump_count", generated_grass_count * DENSE_GRASS_CLUSTER_COPIES)

	var fern_buckets: Dictionary = {}
	var attempts := 0
	while generated_fern_count < fern_count and attempts < fern_count * 16:
		attempts += 1
		var point := _corridor_point(2.8, 132.0, 0.70)
		if distance_to_route(point) < 8.5 or _inside_clearing(point, 5.4, 10.0) or _inside_stone_village_street(point, 2.1) or _inside_desert(point) or _inside_mystery_forest(point) or _slope_at(point) > 0.82:
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
		if distance_to_route(point) < 9.0 or _inside_clearing(point, 6.2, 11.5) or _inside_stone_village_street(point, 2.5) or _inside_desert(point) or _inside_mystery_forest(point) or _slope_at(point) > 0.82:
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
		if distance_to_route(point) < 8.0 or _inside_clearing(point, 3.8, 7.0) or _inside_stone_village_street(point, 1.5) or _inside_desert(point) or _inside_mystery_forest(point) or _slope_at(point) > 0.84:
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
		if distance_to_route(point) < 8.0 or _inside_clearing(point, 3.8, 7.5) or _inside_stone_village_street(point, 1.5) or _inside_desert(point) or _inside_mystery_forest(point):
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
		if distance_to_route(point) < 5.2 or _inside_clearing(point, 9.5, 15.5) or _inside_village_clearing(point, 8.0) or _inside_desert(point) or _inside_mystery_forest(point):
			continue
		var height := _height_at(point)
		if is_nan(height):
			continue
		var variant := _random.randi_range(0, _dead_tree_meshes.size() - 1)
		var scale_value := _random.randf_range(1.30, 2.42)
		var position := Vector3(point.x, height + 0.08, point.y)
		var reference := _bucket_transform_reference(
			buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		)
		_register_harvest_tree_reference(
			position,
			_stable_scatter_resource_id("forest_dead_tree", point),
			"ForestDetailCells|%s" % String(reference.bucket_key),
			int(reference.instance_index),
			"",
			-1
		)
		created += 1
	_install_cell_buckets("ForestDetailCells", buckets, _dead_tree_meshes, 245.0, true)


func _scatter_mystery_dead_trees() -> void:
	var buckets: Dictionary = {}
	var attempts := 0
	while generated_mystery_dead_tree_count < MYSTERY_DEAD_TREE_COUNT and attempts < MYSTERY_DEAD_TREE_COUNT * 44:
		attempts += 1
		var point := Vector2(
			_random.randfn(4400.0, 980.0),
			_random.randfn(-1380.0, 780.0)
		)
		if (
			not _inside_mystery_forest(point)
			or _coast_ratio(point) > 0.83
			or distance_to_route(point) < 10.5
			or _inside_village_clearing(point, 5.0)
			or _slope_at(point) > 0.78
		):
			continue
		var height := _height_at(point)
		if is_nan(height) or height < 2.5:
			continue
		var variant := _random.randi_range(0, _dead_tree_meshes.size() - 1)
		var scale_value := _random.randf_range(1.85, 3.65)
		var position := Vector3(point.x, height + 0.06, point.y)
		var reference := _bucket_transform_reference(
			buckets,
			variant,
			point,
			DETAIL_CELL_SIZE,
			_make_transform(position, _random.randf_range(0.0, TAU), Vector3.ONE * scale_value)
		)
		var tree_resource_id := _stable_scatter_resource_id("mystery_dead_tree", point)
		_register_harvest_tree_reference(
			position,
			tree_resource_id,
			"MysteryDeadTreeCells|%s" % String(reference.bucket_key),
			int(reference.instance_index),
			"",
			-1
		)
		if distance_to_route(point) < 30.0 or generated_mystery_dead_tree_count % 18 == 0:
			_add_tree_collision(
				position, _dead_tree_meshes[variant].get_aabb(), scale_value, tree_resource_id
			)
			generated_tree_collision_count += 1
		generated_mystery_dead_tree_count += 1
	_install_cell_buckets("MysteryDeadTreeCells", buckets, _dead_tree_meshes, 760.0, true)
	var root := get_node("MysteryDeadTreeCells") as Node3D
	root.set_meta("biome", "Bosque Tenebroso")
	root.set_meta("palette", "red_and_dead_only")


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


func _load_obj_mesh_library(file_names: PackedStringArray) -> Array[Mesh]:
	var result: Array[Mesh] = []
	for file_name in file_names:
		var mesh := _load_obj_mesh(NATURE_OBJ_ROOT + file_name)
		if mesh != null:
			result.append(mesh)
	return result


func _make_cactus_mesh_library() -> Array[Mesh]:
	var result: Array[Mesh] = []
	for source_mesh in _load_obj_mesh_library(CACTUS_FILES):
		var cactus_mesh := source_mesh.duplicate(true) as Mesh
		for surface_index in cactus_mesh.get_surface_count():
			var source_material := cactus_mesh.surface_get_material(surface_index)
			var material_name := source_material.resource_name.to_lower() if source_material != null else "green"
			var color := Color(0.15, 0.46, 0.095)
			if "pink" in material_name:
				color = Color(0.92, 0.25, 0.58)
			elif "orange" in material_name:
				color = Color(0.94, 0.55, 0.16)
			var material := StandardMaterial3D.new()
			material.resource_name = source_material.resource_name if source_material != null else "CactusGreen"
			material.albedo_color = color
			material.metallic = 0.0
			material.roughness = 0.88
			# Una emisión muy suave conserva el verde incluso cuando el sol queda a
			# contraluz, sin hacer que el cactus parezca luminoso durante la noche.
			material.emission_enabled = true
			material.emission = color.darkened(0.34)
			material.emission_energy_multiplier = 0.22
			cactus_mesh.surface_set_material(surface_index, material)
		result.append(cactus_mesh)
	return result


func _load_obj_mesh(path: String) -> Mesh:
	# Los OBJ del Nature Pack se importan como ArrayMesh. Mantener esta carga por
	# ResourceLoader hace que sus materiales MTL, caché y LOD pasen por Godot.
	var resource := ResourceLoader.load(path)
	if resource is Mesh:
		return resource as Mesh
	if resource is PackedScene:
		var scene := (resource as PackedScene).instantiate()
		var mesh := _find_first_mesh(scene)
		scene.free()
		return mesh
	push_error("No se pudo cargar la malla OBJ Quaternius: %s" % path)
	return null


func _make_dense_grass_patch_mesh(source: Mesh) -> Mesh:
	# Mil quinientas cincuenta matas en X: dos tarjetas cruzadas impiden que la vegetación se
	# convierta en líneas de un píxel al mirarla de canto. Cada plano contiene dos
	# siluetas curvas y conserva volumen desde cualquier ángulo.
	return _make_grass_model_patch(
		source,
		DENSE_GRASS_CLUSTER_COPIES,
		DENSE_GRASS_PATCH_RADIUS,
		Vector2(2.70, 4.05),
		Vector2(0.74, 1.16)
	)


func _make_grass_card_source(source: Mesh) -> Mesh:
	# La malla es deliberadamente un quad barato; la forma visible se obtiene en
	# GRASS_WIND_SHADER mediante alpha-test y termina en una punta estrecha curva.
	# Se conserva la textura/paleta original de Grass_Common_Short.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad_positions := [
		PackedVector3Array([
			Vector3(-0.055, 0.0, 0.0),
			Vector3(0.055, 0.0, 0.0),
			Vector3(0.055, 1.0, 0.0),
			Vector3(-0.055, 1.0, 0.0),
		]),
		PackedVector3Array([
			Vector3(0.0, 0.0, -0.055),
			Vector3(0.0, 0.0, 0.055),
			Vector3(0.0, 1.0, 0.055),
			Vector3(0.0, 1.0, -0.055),
		]),
	]
	var quad_normals := [Vector3.FORWARD, Vector3.RIGHT]
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	for quad_index in 2:
		var positions: PackedVector3Array = quad_positions[quad_index]
		for vertex_index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(quad_normals[quad_index])
			surface.set_uv(uvs[vertex_index])
			surface.add_vertex(positions[vertex_index])
	surface.index()
	var source_material := source.surface_get_material(0) if source.get_surface_count() > 0 else null
	if source_material != null:
		surface.set_material(source_material)
	return surface.commit()


func _make_upright_grass_source(source: Mesh) -> Mesh:
	# Cada hoja del modelo Quaternius es una isla de triángulos independiente.
	# Conservamos su base y centramos progresivamente el tallo sobre ella; así se
	# elimina la inclinación estática sin sustituir el modelo ni añadir geometría.
	var result := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if vertices.is_empty():
			continue
		var parents := PackedInt32Array()
		parents.resize(vertices.size())
		for vertex_index in vertices.size():
			parents[vertex_index] = vertex_index
		for triangle_start in range(0, indices.size(), 3):
			_grass_union_vertices(parents, indices[triangle_start], indices[triangle_start + 1])
			_grass_union_vertices(parents, indices[triangle_start + 1], indices[triangle_start + 2])
		var components: Dictionary = {}
		for vertex_index in vertices.size():
			var root := _grass_vertex_root(parents, vertex_index)
			var component: PackedInt32Array = components.get(root, PackedInt32Array())
			component.append(vertex_index)
			components[root] = component
		for component_value in components.values():
			var component: PackedInt32Array = component_value
			var minimum_y := INF
			var maximum_y := -INF
			for vertex_index in component:
				minimum_y = minf(minimum_y, vertices[vertex_index].y)
				maximum_y = maxf(maximum_y, vertices[vertex_index].y)
			var height := maxf(maximum_y - minimum_y, 0.001)
			var base_limit := minimum_y + height * 0.12
			var base_center := Vector2.ZERO
			var base_count := 0
			for vertex_index in component:
				var vertex := vertices[vertex_index]
				if vertex.y <= base_limit:
					base_center += Vector2(vertex.x, vertex.z)
					base_count += 1
			if base_count == 0:
				continue
			base_center /= float(base_count)
			for vertex_index in component:
				var vertex := vertices[vertex_index]
				var normalized_height := clampf((vertex.y - minimum_y) / height, 0.0, 1.0)
				var straightening := smoothstep(0.08, 0.92, normalized_height)
				vertex.x = lerpf(vertex.x, base_center.x, straightening)
				vertex.z = lerpf(vertex.z, base_center.y, straightening)
				vertices[vertex_index] = vertex
		arrays[Mesh.ARRAY_VERTEX] = vertices
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
		result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface_index))
	return result


func _grass_vertex_root(parents: PackedInt32Array, vertex_index: int) -> int:
	var root := vertex_index
	while parents[root] != root:
		root = parents[root]
	var current := vertex_index
	while parents[current] != current:
		var next := parents[current]
		parents[current] = root
		current = next
	return root


func _grass_union_vertices(parents: PackedInt32Array, first: int, second: int) -> void:
	var first_root := _grass_vertex_root(parents, first)
	var second_root := _grass_vertex_root(parents, second)
	if first_root != second_root:
		parents[second_root] = first_root


func _make_lightweight_grass_blade_source(source: Mesh) -> Mesh:
	# Grass_Common_Short contiene nueve hojas y 155 triángulos. Para una pradera
	# masiva se conserva una hoja auténtica del mismo asset (UV, textura, color y
	# curvatura), escogiendo la isla ligera más alta de siete triángulos.
	var result := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if vertices.is_empty() or indices.is_empty():
			continue
		var parents := PackedInt32Array()
		parents.resize(vertices.size())
		for vertex_index in vertices.size():
			parents[vertex_index] = vertex_index
		for triangle_start in range(0, indices.size(), 3):
			_grass_union_vertices(parents, indices[triangle_start], indices[triangle_start + 1])
			_grass_union_vertices(parents, indices[triangle_start + 1], indices[triangle_start + 2])
		var components: Dictionary = {}
		for vertex_index in vertices.size():
			var root := _grass_vertex_root(parents, vertex_index)
			var component: PackedInt32Array = components.get(root, PackedInt32Array())
			component.append(vertex_index)
			components[root] = component
		var selected_root := -1
		var selected_height := -INF
		for root_value in components:
			var root := int(root_value)
			var component: PackedInt32Array = components[root]
			if component.size() > 12:
				continue
			var minimum_y := INF
			var maximum_y := -INF
			for vertex_index in component:
				minimum_y = minf(minimum_y, vertices[vertex_index].y)
				maximum_y = maxf(maximum_y, vertices[vertex_index].y)
			var component_height := maximum_y - minimum_y
			if component_height > selected_height:
				selected_height = component_height
				selected_root = root
		if selected_root < 0:
			return source
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle_start in range(0, indices.size(), 3):
			if _grass_vertex_root(parents, indices[triangle_start]) != selected_root:
				continue
			for corner in 3:
				var vertex_index := indices[triangle_start + corner]
				if normals.size() == vertices.size():
					surface.set_normal(normals[vertex_index])
				if colors.size() == vertices.size():
					surface.set_color(colors[vertex_index])
				if uvs.size() == vertices.size():
					surface.set_uv(uvs[vertex_index])
				surface.add_vertex(vertices[vertex_index])
		surface.index()
		surface.set_material(source.surface_get_material(surface_index))
		surface.commit(result)
	return result if result.get_surface_count() > 0 else source


func _make_grass_model_patch(
	source: Mesh,
	cluster_count: int,
	patch_radius: float,
	horizontal_scale_range: Vector2,
	vertical_scale_range: Vector2
) -> Mesh:
	var result := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		var surface := SurfaceTool.new()
		surface.begin(source.surface_get_primitive_type(surface_index))
		var tuft_size := 5
		var tuft_count := ceili(float(cluster_count) / float(tuft_size))
		for cluster_index in cluster_count:
			var tuft_index := cluster_index / tuft_size
			var tuft_slot := cluster_index % tuft_size
			var normalized := (float(tuft_index) + 0.43) / float(tuft_count)
			var radial_angle := TAU * fmod(float(tuft_index) * 0.61803398875 + 0.137, 1.0)
			var tuft_radius := sqrt(normalized) * maxf(patch_radius - 0.68, 0.1)
			var local_angle := TAU * (
				float(tuft_slot) / float(tuft_size)
				+ fmod(float(tuft_index) * 0.38196601125, 1.0)
			)
			var local_radius := sqrt((float(tuft_slot) + 0.35) / float(tuft_size)) * 0.68
			var local_offset := Vector2(cos(local_angle), sin(local_angle)) * local_radius
			var facing := TAU * fmod(float(cluster_index) * 0.38196601125 + 0.29, 1.0)
			var variation := sin(float(cluster_index) * 12.9898 + 1.73) * 0.5 + 0.5
			var horizontal_scale := lerpf(horizontal_scale_range.x, horizontal_scale_range.y, variation)
			var vertical_scale := lerpf(vertical_scale_range.x, vertical_scale_range.y, 1.0 - variation)
			var lean := lerpf(-0.085, 0.085, fmod(variation * 1.61803398875, 1.0))
			var lean_axis := Vector3(cos(local_angle), 0.0, sin(local_angle))
			var basis := (Basis(lean_axis, lean) * Basis(Vector3.UP, facing)).scaled(
				Vector3(horizontal_scale, vertical_scale, horizontal_scale)
			)
			var transform := Transform3D(
				basis,
				Vector3(
					cos(radial_angle) * tuft_radius + local_offset.x,
					-0.08,
					sin(radial_angle) * tuft_radius + local_offset.y
				)
			)
			surface.append_from(source, surface_index, transform)
		surface.set_material(source.surface_get_material(surface_index))
		surface.commit(result)
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
			snow_material.resource_name = source_material.resource_name
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
			mystery_material.resource_name = source_material.resource_name
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
		_make_tree_lod_mesh(Color("65151b"), Color("3d2725"), false),
		_make_tree_lod_mesh(Color("3f0d12"), Color("302321"), true),
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


func _apply_tree_wind_materials() -> void:
	var shader := Shader.new()
	shader.code = TREE_WIND_SHADER
	_tree_wind_material_count = 0
	for mesh_index in _tree_meshes.size():
		var tree_mesh := _tree_meshes[mesh_index]
		var tint_mode := 0.0
		if mesh_index >= _mystery_tree_offset:
			tint_mode = 2.0
		elif mesh_index >= _snow_tree_offset:
			tint_mode = 1.0
		for surface_index in tree_mesh.get_surface_count():
			var source_material := tree_mesh.surface_get_material(surface_index)
			if source_material == null:
				continue
			var albedo_texture: Texture2D
			if source_material is BaseMaterial3D:
				albedo_texture = (source_material as BaseMaterial3D).albedo_texture
			elif source_material is ShaderMaterial:
				albedo_texture = (source_material as ShaderMaterial).get_shader_parameter(
					"albedo_texture"
				) as Texture2D
			if albedo_texture == null:
				continue
			var material_name := source_material.resource_name.to_lower()
			# Los glTF Quaternius separan corteza y hojas en las superficies 0 y 1.
			# El nombre se conserva en las copias nevadas/tenebrosas, pero se mantiene
			# el índice como respaldo para imports antiguos.
			var is_leaf := "leave" in material_name or "leaf" in material_name
			if material_name.is_empty():
				is_leaf = surface_index > 0
			var wind_material := ShaderMaterial.new()
			wind_material.resource_name = source_material.resource_name
			wind_material.shader = shader
			wind_material.set_shader_parameter("albedo_texture", albedo_texture)
			wind_material.set_shader_parameter("tint_mode", tint_mode)
			wind_material.set_shader_parameter("leaf_factor", 1.0 if is_leaf else 0.0)
			tree_mesh.surface_set_material(surface_index, wind_material)
			_tree_wind_material_count += 1
	set_meta("tree_wind_materials", _tree_wind_material_count)
	set_meta("tree_wind_gust_levels", PackedStringArray(["breeze", "soft", "strong"]))


func _apply_grass_wind_materials() -> void:
	_grass_wind_materials.clear()
	var shader := Shader.new()
	shader.code = GRASS_WIND_SHADER
	for mesh_index in _grass_meshes.size():
		_apply_grass_material_to_mesh(
			_grass_meshes[mesh_index],
			shader,
			0.0,
			true,
			mesh_index == _dense_grass_offset
		)
	for mesh in _grass_mid_lod_meshes:
		_apply_grass_material_to_mesh(mesh, shader, 2.0, true, true)
	for mesh in _grass_lod_meshes:
		_apply_grass_material_to_mesh(mesh, shader, 1.0, false, true)


func _apply_grass_material_to_mesh(
	mesh: Mesh,
	shader: Shader,
	lod_role: float,
	follow_terrain: bool,
	procedural_blade: bool = false
) -> void:
	for surface_index in mesh.get_surface_count():
		var source_material := mesh.surface_get_material(surface_index) as BaseMaterial3D
		if source_material == null or source_material.albedo_texture == null:
			continue
		var wind_material := ShaderMaterial.new()
		wind_material.shader = shader
		wind_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
		wind_material.set_shader_parameter("interaction_radius", 1.35)
		wind_material.set_shader_parameter("lod_role", lod_role)
		wind_material.set_shader_parameter("terrain_follow", 1.0 if follow_terrain else 0.0)
		wind_material.set_shader_parameter("procedural_blade", 1.0 if procedural_blade else 0.0)
		wind_material.set_shader_parameter("full_fade_start", GRASS_FULL_FADE_START)
		wind_material.set_shader_parameter("full_fade_end", GRASS_FULL_FADE_END)
		wind_material.set_shader_parameter("proxy_fade_start", GRASS_PROXY_FADE_START)
		wind_material.set_shader_parameter("proxy_fade_end", GRASS_PROXY_FADE_END)
		wind_material.set_shader_parameter("mid_fade_out_start", GRASS_MID_FADE_OUT_START)
		wind_material.set_shader_parameter("mid_fade_out_end", GRASS_MID_FADE_OUT_END)
		wind_material.set_shader_parameter("proxy_far_fade_start", GRASS_PROXY_FAR_FADE_START)
		wind_material.set_shader_parameter("proxy_far_fade_end", GRASS_LOD_VISIBILITY_END)
		mesh.surface_set_material(surface_index, wind_material)
		_set_grass_terrain_shader_parameters(wind_material)
		_grass_wind_materials.append(wind_material)


func _set_grass_terrain_shader_parameters(material: ShaderMaterial) -> void:
	if terrain == null or terrain.data == null:
		return
	var material_rid := material.get_rid()
	RenderingServer.material_set_param(material_rid, "_vertex_density", 1.0 / terrain.vertex_spacing)
	RenderingServer.material_set_param(material_rid, "_region_size", terrain.region_size)
	RenderingServer.material_set_param(material_rid, "_region_texel_size", 1.0 / terrain.region_size)
	RenderingServer.material_set_param(material_rid, "_region_map_size", 32)
	RenderingServer.material_set_param(material_rid, "_region_map", terrain.data.get_region_map())
	RenderingServer.material_set_param(material_rid, "_height_maps", terrain.data.get_height_maps_rid())


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
	_bucket_transform_reference(buckets, variant, point, cell_size, transform)


func _index_near_grass_transform(point: Vector2, transform: Transform3D) -> void:
	var cell := Vector2i(
		floori(point.x / GRASS_NEAR_INDEX_CELL_SIZE),
		floori(point.y / GRASS_NEAR_INDEX_CELL_SIZE)
	)
	var transforms: Array = _grass_near_transform_cells.get(cell, [])
	transforms.append(transform)
	_grass_near_transform_cells[cell] = transforms


func _install_grass_near_field() -> void:
	var category := Node3D.new()
	category.name = "GrassCells"
	category.set_meta("fixed_world_layout", true)
	category.set_meta("gpu_window_faded", true)
	add_child(category)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _grass_meshes[_dense_grass_offset]
	multimesh.instance_count = 0
	multimesh.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE * 0.01)
	_grass_near_instance = MultiMeshInstance3D.new()
	_grass_near_instance.name = "FixedNearField"
	_grass_near_instance.multimesh = multimesh
	_grass_near_instance.lod_bias = 0.75
	_grass_near_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass_near_instance.set_meta("imported_mesh_lod_bias", 0.75)
	_grass_near_instance.set_meta("source_layout_count", grass_count)
	_grass_near_instance.set_meta("preload_radius", GRASS_NEAR_PRELOAD_RADIUS)
	category.add_child(_grass_near_instance)
	var mid_category := Node3D.new()
	mid_category.name = "GrassMidLODCells"
	mid_category.set_meta("fixed_world_layout", true)
	mid_category.set_meta("lod_tier", "terrain_following_mid")
	add_child(mid_category)
	var mid_multimesh := MultiMesh.new()
	mid_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mid_multimesh.mesh = _grass_mid_lod_meshes[0]
	mid_multimesh.instance_count = 0
	mid_multimesh.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE * 0.01)
	_grass_mid_instance = MultiMeshInstance3D.new()
	_grass_mid_instance.name = "FixedMidField"
	_grass_mid_instance.multimesh = mid_multimesh
	_grass_mid_instance.lod_bias = 0.75
	_grass_mid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grass_mid_instance.set_meta("imported_mesh_lod_bias", 0.75)
	_grass_mid_instance.set_meta("source_layout_count", grass_count)
	_grass_mid_instance.set_meta("preload_radius", GRASS_MID_PRELOAD_RADIUS)
	mid_category.add_child(_grass_mid_instance)
	generated_cell_count += 2


func _update_grass_near_field(focus: Vector2, force: bool) -> void:
	if (
		_grass_near_instance == null
		or _grass_near_instance.multimesh == null
		or _grass_mid_instance == null
		or _grass_mid_instance.multimesh == null
	):
		return
	if (
		not force
		and is_finite(_grass_near_last_focus.x)
		and focus.distance_squared_to(_grass_near_last_focus)
			< GRASS_NEAR_REFRESH_DISTANCE * GRASS_NEAR_REFRESH_DISTANCE
	):
		return
	_grass_near_last_focus = focus
	var center_cell := Vector2i(
		floori(focus.x / GRASS_NEAR_INDEX_CELL_SIZE),
		floori(focus.y / GRASS_NEAR_INDEX_CELL_SIZE)
	)
	var cell_radius := ceili(GRASS_MID_PRELOAD_RADIUS / GRASS_NEAR_INDEX_CELL_SIZE)
	var near_radius_squared := GRASS_NEAR_PRELOAD_RADIUS * GRASS_NEAR_PRELOAD_RADIUS
	var mid_radius_squared := GRASS_MID_PRELOAD_RADIUS * GRASS_MID_PRELOAD_RADIUS
	var active_transforms: Array[Transform3D] = []
	var mid_transforms: Array[Transform3D] = []
	for cell_y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
		for cell_x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
			for transform_value in _grass_near_transform_cells.get(Vector2i(cell_x, cell_y), []):
				var transform := transform_value as Transform3D
				var point := Vector2(transform.origin.x, transform.origin.z)
				var distance_squared := point.distance_squared_to(focus)
				if distance_squared <= near_radius_squared:
					active_transforms.append(transform)
				if distance_squared <= mid_radius_squared:
					mid_transforms.append(transform)
	var multimesh := _grass_near_instance.multimesh
	multimesh.instance_count = active_transforms.size()
	for index in active_transforms.size():
		multimesh.set_instance_transform(index, active_transforms[index])
	multimesh.custom_aabb = _transforms_aabb(active_transforms, multimesh.mesh)
	_grass_near_active_instances = active_transforms.size()
	var mid_multimesh := _grass_mid_instance.multimesh
	mid_multimesh.instance_count = mid_transforms.size()
	for index in mid_transforms.size():
		mid_multimesh.set_instance_transform(index, mid_transforms[index])
	mid_multimesh.custom_aabb = _transforms_aabb(mid_transforms, mid_multimesh.mesh)
	_grass_mid_active_instances = mid_transforms.size()


func _bucket_transform_reference(buckets: Dictionary, variant: int, point: Vector2, cell_size: float, transform: Transform3D) -> Dictionary:
	var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
	var key := "%d:%d:%d" % [variant, cell.x, cell.y]
	if not buckets.has(key):
		buckets[key] = {"variant": variant, "cell": cell, "cell_size": cell_size, "transforms": []}
	var transforms: Array = buckets[key]["transforms"]
	var instance_index := transforms.size()
	transforms.append(transform)
	return {"bucket_key": key, "instance_index": instance_index}


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
		_installed_multimeshes["%s|%s" % [root_name, String(key)]] = instance
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
		_installed_multimeshes["TreeLODCells|%s" % String(key)] = instance
		_register_lod_instance(_tree_proxy_cells, cell, instance)
		generated_tree_lod_cells += 1
		generated_tree_lod_instances += local_transforms.size()


func _install_grass_lod_buckets(buckets: Dictionary) -> void:
	var category := Node3D.new()
	category.name = "GrassLODCells"
	category.set_meta("lod_tier", "dense_patch_proxy")
	category.set_meta("source_grass_count", grass_count)
	category.set_meta("effective_clump_count", grass_count * DENSE_GRASS_CLUSTER_COPIES)
	category.set_meta("crossfade_start", GRASS_PROXY_FADE_START)
	category.set_meta("crossfade_end", GRASS_PROXY_FADE_END)
	category.set_meta("visibility_end", GRASS_LOD_VISIBILITY_END)
	category.set_meta("shadows_disabled", true)
	category.set_meta("crossfades_with", "GrassCells")
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
		instance.set_meta("lod_geometry", "distributed_grass_carpet")
		instance.set_meta("full_mesh_replacement", false)
		instance.set_meta("distance_crossfade", true)
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
	var focus := Vector2.ZERO
	if camera != null:
		focus = Vector2(camera.global_position.x, camera.global_position.z)
	elif _grass_interaction_target != null:
		focus = Vector2(
			_grass_interaction_target.global_position.x,
			_grass_interaction_target.global_position.z
		)
	else:
		return
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
	_update_grass_near_field(focus, force)
	if _grass_near_active_instances > 0:
		explicit_lod_visible_full_cells += 1
	_update_grass_crossfade_cells(
		_grass_full_cells,
		_grass_proxy_cells,
		focus,
		GRASS_CELL_SIZE,
		0.0,
		GRASS_LOD_VISIBILITY_END
	)
	set_meta("active_lod_distance", lod_switch_distance)
	set_meta("visible_full_lod_cells", explicit_lod_visible_full_cells)
	set_meta("visible_proxy_lod_cells", explicit_lod_visible_proxy_cells)


func _update_grass_crossfade_cells(
	full_cells: Dictionary,
	proxy_cells: Dictionary,
	focus: Vector2,
	cell_size: float,
	full_cull_distance: float,
	far_distance: float
) -> void:
	# La geometría completa y el proxy se solapan. El shader hace la transición
	# por distancia mundial de cada hoja, por lo que activar una celda nueva no
	# puede producir un salto visible aunque el jugador vaya rápido a caballo.
	var keys := full_cells.keys()
	for proxy_key in proxy_cells.keys():
		if not full_cells.has(proxy_key):
			keys.append(proxy_key)
	for key_value in keys:
		var cell := key_value as Vector2i
		var distance := _distance_to_cell(focus, cell, cell_size)
		var show_full := distance <= full_cull_distance
		var show_proxy := distance <= far_distance
		_set_lod_instances_visible(full_cells.get(cell, []), show_full)
		_set_lod_instances_visible(proxy_cells.get(cell, []), show_proxy)
		if show_full:
			explicit_lod_visible_full_cells += 1
		if show_proxy:
			explicit_lod_visible_proxy_cells += 1


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


func _make_grass_mid_lod_mesh(
	source: Mesh,
	cluster_count: int,
	patch_radius: float
) -> Mesh:
	# Segunda corona: misma silueta y terreno, con menos briznas algo más anchas.
	return _make_grass_model_patch(
		source,
		cluster_count,
		patch_radius,
		Vector2(4.90, 7.15),
		Vector2(0.65, 1.01)
	)


func _make_grass_lod_mesh(
	source: Mesh,
	cluster_count: int,
	patch_radius: float
) -> Mesh:
	# El LOD lejano mantiene una alfombra continua; sólo baja la densidad geométrica.
	return _make_grass_model_patch(
		source,
		cluster_count,
		patch_radius,
		Vector2(7.80, 12.30),
		Vector2(0.48, 0.78)
	)


func _make_transform(position: Vector3, yaw: float, scale_value: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale_value), position)


func _terrain_gradient_at(point: Vector2, center_height: float) -> Vector2:
	var sample_distance := 1.5
	var east := _height_at(point + Vector2(sample_distance, 0.0))
	var north := _height_at(point + Vector2(0.0, sample_distance))
	if is_nan(center_height) or is_nan(east) or is_nan(north):
		return Vector2.ZERO
	return Vector2(
		(east - center_height) / sample_distance,
		(north - center_height) / sample_distance
	)


func _make_ground_aligned_transform(
	position: Vector3,
	yaw: float,
	scale_value: Vector3,
	terrain_gradient: Vector2
) -> Transform3D:
	var up := Vector3(-terrain_gradient.x, 1.0, -terrain_gradient.y).normalized()
	var tangent_x := Vector3(1.0, terrain_gradient.x, 0.0).normalized()
	var tangent_z := tangent_x.cross(up).normalized()
	tangent_x = up.cross(tangent_z).normalized()
	var ground_basis := Basis(tangent_x, up, tangent_z)
	var rotated_basis := ground_basis * Basis(Vector3.UP, yaw)
	return Transform3D(rotated_basis.scaled(scale_value), position)


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
	# El 33 % sólo se aplica al presupuesto sobrante después de la retícula. Al
	# ampliar ésta a pradera y nieve, la cantidad junto a caminos se conserva y
	# los nuevos ejemplares se concentran en las superficies interiores vacías.
	if distribution < 0.33:
		var sample := _route_sample()
		var point: Vector2 = sample[0]
		var normal: Vector2 = sample[1]
		var side := -1.0 if _random.randf() < 0.5 else 1.0
		return point + normal * lerpf(13.0, 178.0, sqrt(_random.randf())) * side
	if distribution < 0.72:
		return _forest_zone_point()
	return Vector2(_random.randf_range(-4850.0, 5450.0), _random.randf_range(-4380.0, 4380.0))


func _build_grass_coverage_points(target_count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var minimum := Vector2(-4850.0, -4380.0)
	var maximum := Vector2(5450.0, 4380.0)
	var columns := ceili((maximum.x - minimum.x) / GRASS_COVERAGE_SPACING)
	var rows := ceili((maximum.y - minimum.y) / GRASS_COVERAGE_SPACING)
	for row in rows:
		for column in columns:
			var point := minimum + Vector2(
				(float(column) + 0.5) * GRASS_COVERAGE_SPACING,
				(float(row) + 0.5) * GRASS_COVERAGE_SPACING
			)
			point += Vector2(
				_random.randf_range(-0.34, 0.34),
				_random.randf_range(-0.34, 0.34)
			) * GRASS_COVERAGE_SPACING
			if _grass_coverage_point_allowed(point):
				result.append(point)
	# El recorte se hace tras barajar, de modo que no privilegie una esquina del
	# mapa. Si las exclusiones crecen en el futuro, el relleno aleatorio garantiza
	# que el contrato de instancias siga siendo exacto.
	for index in range(result.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	if result.size() > target_count:
		result.resize(target_count)
	var attempts := 0
	while result.size() < target_count and attempts < target_count * 30:
		attempts += 1
		var point := Vector2(
			_random.randf_range(minimum.x, maximum.x),
			_random.randf_range(minimum.y, maximum.y)
		)
		if _grass_coverage_point_allowed(point):
			result.append(point)
	return result


func _grass_coverage_point_allowed(point: Vector2) -> bool:
	if (
		distance_to_route(point) < 8.2
		or _inside_clearing(point, 5.0, 9.0)
		or _inside_stone_village_street(point, 2.0)
		or _inside_village_clearing(point, -4.0)
		or _inside_desert(point)
		or _inside_mystery_forest(point)
		or _coast_ratio(point) > 0.80
		or _slope_at(point) > 0.72
	):
		return false
	var height := _height_at(point)
	if is_nan(height) or height < 2.5:
		return false
	# La hierba se corta antes de la primera franja de nieve; no se recolorea de
	# blanco ni se permite bajo los árboles del bioma tenebroso.
	if _snow_probability(point, height) > 0.06:
		return false
	var terrain_material := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
	var base_id := int(terrain_material.x)
	var overlay_id := int(terrain_material.y)
	var blend := terrain_material.z
	var base_is_meadow := base_id == 0
	var overlay_is_meadow := overlay_id == 0
	return (base_is_meadow and (overlay_is_meadow or blend < 0.12)) or (overlay_is_meadow and blend > 0.88)


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
			if _random.randf() < 0.75:
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
	# La cobertura anti-calvas incluye tanto pradera como nieve. Antes sólo
	# aceptaba el id 0 y las grandes llanuras nevadas quedaban dependiendo del
	# reparto aleatorio, aunque el arbolado general pareciera denso desde lejos.
	var terrain_material := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
	var base_is_forest_floor := int(terrain_material.x) in [0, 4]
	var overlay_is_forest_floor := int(terrain_material.y) in [0, 4]
	var blend := terrain_material.z
	return (base_is_forest_floor and (overlay_is_forest_floor or blend < 0.70)) or (overlay_is_forest_floor and blend > 0.30)


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


func _desert_decoration_point_allowed(point: Vector2) -> bool:
	if not _inside_desert_core(point) or _coast_ratio(point) > 0.77 or _slope_at(point) > 0.32:
		return false
	var terrain_material := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
	var dominant_id := int(terrain_material.y) if terrain_material.z >= 0.50 else int(terrain_material.x)
	return dominant_id == 3


func _inside_desert(point: Vector2) -> bool:
	var core := _gaussian_strength(point, Vector2(2400.0, 2050.0), Vector2(1450.0, 1120.0))
	var coast := _gaussian_strength(point, Vector2(4380.0, 2500.0), Vector2(1550.0, 1180.0))
	var southern := _gaussian_strength(point, Vector2(2450.0, 3550.0), Vector2(1750.0, 760.0))
	var dunes := maxf(core, maxf(coast * 0.96, southern * 0.78)) > 0.34
	var cliff_local := point - Vector2(3500.0, 1800.0)
	var cliffs := pow(cliff_local.x / 1550.0, 2.0) + pow(cliff_local.y / 1750.0, 2.0) < 1.0
	var coastal_beach := _coast_ratio(point) > 0.815
	return dunes or cliffs or coastal_beach


func _inside_desert_core(point: Vector2) -> bool:
	var core := _gaussian_strength(point, Vector2(2400.0, 2050.0), Vector2(1450.0, 1120.0))
	var coast := _gaussian_strength(point, Vector2(4380.0, 2500.0), Vector2(1550.0, 1180.0))
	var southern := _gaussian_strength(point, Vector2(2450.0, 3550.0), Vector2(1750.0, 760.0))
	return maxf(core, maxf(coast * 0.96, southern * 0.78)) > 0.38


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


func _inside_mystery_forest(point: Vector2) -> bool:
	return _mystery_forest_strength(point) > 0.26


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


func _add_tree_collision(
	base: Vector3,
	bounds: AABB,
	tree_scale: float,
	resource_id: String = ""
) -> void:
	var radius := clampf(tree_scale * 0.34, 0.38, 1.42)
	var height := maxf(bounds.size.y * tree_scale * 0.76, 4.0)
	for value in [base.x, base.y, base.z, radius, height]:
		_tree_collision_records.append(float(value))
	_tree_collision_resource_ids.append(resource_id)


func _finalize_tree_collision_mesh() -> void:
	if _tree_collision_records.is_empty():
		return
	var started := Time.get_ticks_msec()
	_forest_collision_shape = ConcavePolygonShape3D.new()
	_forest_collision_shape.backface_collision = true
	_forest_collision_node = CollisionShape3D.new()
	_forest_collision_node.name = "ForestTreeCollisionMesh"
	_forest_collision_node.shape = _forest_collision_shape
	_forest_collision_node.set_meta("source_tree_count", generated_tree_collision_count)
	_get_collision_body().add_child(_forest_collision_node)
	_refresh_tree_collision_mesh()
	_startup_checkpoint("colisión forestal unificada", started)


func _refresh_tree_collision_mesh() -> void:
	if _forest_collision_shape == null:
		return
	var faces := PackedVector3Array()
	# Prismas hexagonales: suficientes para troncos low-poly y mucho más baratos
	# que miles de CollisionShape3D independientes. Jolt construye un único BVH.
	const SIDE_COUNT := 6
	for offset in range(0, _tree_collision_records.size(), 5):
		var collision_index := offset / 5
		var resource_id := (
			_tree_collision_resource_ids[collision_index]
			if collision_index < _tree_collision_resource_ids.size()
			else ""
		)
		if not resource_id.is_empty() and _destroyed_resource_ids.has(resource_id):
			continue
		var base := Vector3(
			_tree_collision_records[offset],
			_tree_collision_records[offset + 1],
			_tree_collision_records[offset + 2]
		)
		var radius := _tree_collision_records[offset + 3]
		var height := _tree_collision_records[offset + 4]
		for side in SIDE_COUNT:
			var angle_a := TAU * float(side) / float(SIDE_COUNT)
			var angle_b := TAU * float(side + 1) / float(SIDE_COUNT)
			var bottom_a := base + Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius)
			var bottom_b := base + Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius)
			var top_a := bottom_a + Vector3.UP * height
			var top_b := bottom_b + Vector3.UP * height
			faces.append(bottom_a)
			faces.append(bottom_b)
			faces.append(top_b)
			faces.append(bottom_a)
			faces.append(top_b)
			faces.append(top_a)
	_forest_collision_shape.set_faces(faces)
	if _forest_collision_node != null:
		_forest_collision_node.set_meta("active_tree_count", faces.size() / (SIDE_COUNT * 6))
	set_meta("tree_collision_face_count", faces.size() / 3)


func _add_rock_collision(base: Vector3, mesh_size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(mesh_size.x * 0.72, 0.55), maxf(mesh_size.y * 0.70, 0.45), maxf(mesh_size.z * 0.72, 0.55))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3.UP * shape.size.y * 0.42
	_get_collision_body().add_child(collision)


func _stable_scatter_resource_id(prefix: String, point: Vector2) -> String:
	# La posición procede de una semilla determinista. Identificar por decímetros
	# mantiene la partida compatible aunque cambie el orden interno de las celdas.
	return "%s_%d_%d" % [prefix, roundi(point.x * 10.0), roundi(point.y * 10.0)]


func _register_harvest_tree_reference(
	position: Vector3,
	resource_id: String,
	full_key: String,
	full_index: int,
	proxy_key: String,
	proxy_index: int
) -> void:
	var tree_index := _harvest_tree_positions.size()
	_harvest_tree_positions.append(position)
	_harvest_tree_ids.append(resource_id)
	_harvest_tree_full_keys.append(full_key)
	_harvest_tree_full_indices.append(full_index)
	_harvest_tree_proxy_keys.append(proxy_key)
	_harvest_tree_proxy_indices.append(proxy_index)
	_harvest_tree_full_originals.append(Transform3D.IDENTITY)
	_harvest_tree_proxy_originals.append(Transform3D.IDENTITY)
	_harvest_tree_index_by_id[resource_id] = tree_index


func _finalize_harvest_tree_registry() -> void:
	_harvest_tree_cells.clear()
	for tree_index in _harvest_tree_positions.size():
		var full_instance := _installed_multimeshes.get(
			_harvest_tree_full_keys[tree_index]
		) as MultiMeshInstance3D
		var full_index := _harvest_tree_full_indices[tree_index]
		if (
			full_instance != null
			and full_instance.multimesh != null
			and full_index >= 0
			and full_index < full_instance.multimesh.instance_count
		):
			_harvest_tree_full_originals[tree_index] = (
				full_instance.multimesh.get_instance_transform(full_index)
			)
		var proxy_key := _harvest_tree_proxy_keys[tree_index]
		var proxy_instance := _installed_multimeshes.get(proxy_key) as MultiMeshInstance3D
		var proxy_index := _harvest_tree_proxy_indices[tree_index]
		if (
			not proxy_key.is_empty()
			and proxy_instance != null
			and proxy_instance.multimesh != null
			and proxy_index >= 0
			and proxy_index < proxy_instance.multimesh.instance_count
		):
			_harvest_tree_proxy_originals[tree_index] = (
				proxy_instance.multimesh.get_instance_transform(proxy_index)
			)
		var position := _harvest_tree_positions[tree_index]
		var cell := Vector2i(
			floori(position.x / TREE_HARVEST_CELL_SIZE),
			floori(position.z / TREE_HARVEST_CELL_SIZE)
		)
		var indices: Array = _harvest_tree_cells.get(cell, [])
		indices.append(tree_index)
		_harvest_tree_cells[cell] = indices
	generated_harvestable_tree_count = _harvest_tree_positions.size()
	set_meta("all_trees_harvestable", true)
	set_meta("harvestable_tree_count", generated_harvestable_tree_count)
	set_meta("harvest_tree_spatial_cell_size", TREE_HARVEST_CELL_SIZE)


func try_hit_nearest_tree(
	category: String,
	_item_id: String,
	player_position: Vector3,
	forward: Vector3,
	attack_reach: float,
	player: Player
) -> bool:
	if _harvest_tree_cells.is_empty() or player == null:
		return false
	var player_key := player.get_instance_id()
	var attack_serial := int(player.attacks_performed)
	if int(_tree_last_attack_serial.get(player_key, -1)) == attack_serial:
		return true
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	if flat_forward.length_squared() < 0.01:
		return false
	var player_point := Vector2(player_position.x, player_position.z)
	var search_radius := maxf(attack_reach + 2.1, 3.2)
	var center_cell := Vector2i(
		floori(player_point.x / TREE_HARVEST_CELL_SIZE),
		floori(player_point.y / TREE_HARVEST_CELL_SIZE)
	)
	var cell_radius := ceili(search_radius / TREE_HARVEST_CELL_SIZE)
	var selected_index := -1
	var selected_score := INF
	for cell_y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
		for cell_x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
			for index_value in _harvest_tree_cells.get(Vector2i(cell_x, cell_y), []):
				var tree_index := int(index_value)
				var resource_id := _harvest_tree_ids[tree_index]
				if _destroyed_resource_ids.has(resource_id):
					continue
				var tree_position := _harvest_tree_positions[tree_index]
				if absf(tree_position.y - player_position.y) > 5.0:
					continue
				var delta := Vector2(tree_position.x, tree_position.z) - player_point
				var distance := delta.length()
				if distance > search_radius:
					continue
				var alignment := 1.0 if distance < 0.05 else flat_forward.dot(delta / distance)
				var lateral := absf(flat_forward.x * delta.y - flat_forward.y * delta.x)
				if alignment < 0.08 or lateral > 2.25:
					continue
				var score := distance - alignment * 0.72 + lateral * 0.24
				if score < selected_score:
					selected_score = score
					selected_index = tree_index
	if selected_index < 0:
		return false
	_tree_last_attack_serial[player_key] = attack_serial
	if category != "axe":
		player.action_feedback.emit("Necesitas equipar el hacha con 2")
		_animate_harvest_tree_hit(selected_index, true)
		return true
	var remaining_health := int(
		_harvest_tree_health.get(selected_index, TREE_HARVEST_HEALTH)
	) - 1
	_harvest_tree_health[selected_index] = remaining_health
	_animate_harvest_tree_hit(selected_index, false)
	if remaining_health <= 0:
		_break_harvest_tree(selected_index, flat_forward, player)
	else:
		player.action_feedback.emit("Golpe al árbol · faltan %d" % remaining_health)
	return true


func _animate_harvest_tree_hit(tree_index: int, wrong_tool: bool) -> void:
	_kill_tree_tween(tree_index)
	var amplitude := 0.075 if wrong_tool else 0.055
	var tween := create_tween()
	_tree_hit_tweens[tree_index] = tween
	var apply_angle := func(angle: float) -> void:
		_set_harvest_tree_pose(tree_index, Vector3.FORWARD, angle, Vector3.ONE)
	tween.tween_method(apply_angle, 0.0, amplitude, 0.055)
	tween.tween_method(apply_angle, amplitude, -amplitude * 0.72, 0.070)
	tween.tween_method(apply_angle, -amplitude * 0.72, amplitude * 0.32, 0.060)
	tween.tween_method(apply_angle, amplitude * 0.32, 0.0, 0.075)


func _break_harvest_tree(tree_index: int, player_forward: Vector2, player: Player) -> void:
	var resource_id := _harvest_tree_ids[tree_index]
	if _destroyed_resource_ids.has(resource_id):
		return
	var network := get_node_or_null("/root/NetworkSession")
	if _is_network_client(network):
		network.call("request_world_resource_break", "vegetation", resource_id)
	_destroyed_resource_ids[resource_id] = true
	_harvest_tree_health.erase(tree_index)
	_kill_tree_tween(tree_index)
	var fall_axis := Vector3(player_forward.y, 0.0, -player_forward.x).normalized()
	if fall_axis.length_squared() < 0.01:
		fall_axis = Vector3.RIGHT
	var tween := create_tween()
	_tree_hit_tweens[tree_index] = tween
	var apply_fall := func(progress: float) -> void:
		var eased := progress * progress
		_set_harvest_tree_pose(
			tree_index,
			fall_axis,
			lerpf(0.0, deg_to_rad(88.0), eased),
			Vector3(1.0 + progress * 0.03, 1.0 - progress * 0.05, 1.0 + progress * 0.03)
		)
	tween.tween_method(apply_fall, 0.0, 1.0, 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_set_harvest_tree_hidden(tree_index, true)
		_refresh_tree_collision_mesh()
		_ensure_tree_stump(tree_index)
		_spawn_tree_loot(tree_index, player)
		_tree_hit_tweens.erase(tree_index)
		var save_manager := get_node_or_null("/root/SaveGameManager")
		if save_manager != null:
			save_manager.call("save_current_game", "árbol talado")
	)
	player.action_feedback.emit("Árbol talado: recoge los troncos")


func _kill_tree_tween(tree_index: int) -> void:
	var previous = _tree_hit_tweens.get(tree_index, null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	_tree_hit_tweens.erase(tree_index)


func _set_harvest_tree_pose(
	tree_index: int,
	axis: Vector3,
	angle: float,
	local_scale: Vector3
) -> void:
	_set_harvest_tree_instance_pose(
		_harvest_tree_full_keys[tree_index],
		_harvest_tree_full_indices[tree_index],
		_harvest_tree_full_originals[tree_index],
		axis,
		angle,
		local_scale
	)
	if not _harvest_tree_proxy_keys[tree_index].is_empty():
		_set_harvest_tree_instance_pose(
			_harvest_tree_proxy_keys[tree_index],
			_harvest_tree_proxy_indices[tree_index],
			_harvest_tree_proxy_originals[tree_index],
			axis,
			angle,
			local_scale
		)


func _set_harvest_tree_instance_pose(
	key: String,
	instance_index: int,
	original: Transform3D,
	axis: Vector3,
	angle: float,
	local_scale: Vector3
) -> void:
	var multimesh_instance := _installed_multimeshes.get(key) as MultiMeshInstance3D
	if (
		multimesh_instance == null
		or multimesh_instance.multimesh == null
		or instance_index < 0
		or instance_index >= multimesh_instance.multimesh.instance_count
	):
		return
	var pose := Transform3D(
		Basis(axis, angle) * original.basis.scaled(local_scale),
		original.origin
	)
	multimesh_instance.multimesh.set_instance_transform(instance_index, pose)


func _set_harvest_tree_hidden(tree_index: int, hidden: bool) -> void:
	_set_harvest_tree_instance_hidden(
		_harvest_tree_full_keys[tree_index],
		_harvest_tree_full_indices[tree_index],
		_harvest_tree_full_originals[tree_index],
		hidden
	)
	if not _harvest_tree_proxy_keys[tree_index].is_empty():
		_set_harvest_tree_instance_hidden(
			_harvest_tree_proxy_keys[tree_index],
			_harvest_tree_proxy_indices[tree_index],
			_harvest_tree_proxy_originals[tree_index],
			hidden
		)


func _set_harvest_tree_instance_hidden(
	key: String,
	instance_index: int,
	original: Transform3D,
	hidden: bool
) -> void:
	var multimesh_instance := _installed_multimeshes.get(key) as MultiMeshInstance3D
	if (
		multimesh_instance == null
		or multimesh_instance.multimesh == null
		or instance_index < 0
		or instance_index >= multimesh_instance.multimesh.instance_count
	):
		return
	var pose := Transform3D(original.basis, original.origin)
	if hidden:
		pose.basis = Basis.from_scale(Vector3.ONE * 0.001)
		pose.origin.y -= 10000.0
	multimesh_instance.multimesh.set_instance_transform(instance_index, pose)


func _ensure_tree_stump(tree_index: int) -> void:
	var resource_id := _harvest_tree_ids[tree_index]
	if _harvest_stumps.has(resource_id):
		return
	if _stump_mesh == null:
		_stump_mesh = CylinderMesh.new()
		# Misma silueta low-poly y mismas proporciones que el tocón de los árboles
		# de misión. La escala individual de abajo lo adapta al tronco talado.
		_stump_mesh.top_radius = 0.72
		_stump_mesh.bottom_radius = 0.88
		_stump_mesh.height = 0.75
		_stump_mesh.radial_segments = 8
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("6e3d22")
		material.roughness = 0.94
		_stump_mesh.material = material
	var stump_root := get_node_or_null("HarvestedTreeStumps") as Node3D
	if stump_root == null:
		stump_root = Node3D.new()
		stump_root.name = "HarvestedTreeStumps"
		add_child(stump_root)
	var stump := MeshInstance3D.new()
	stump.name = "Stump_%s" % resource_id
	stump.mesh = _stump_mesh
	var original := _harvest_tree_full_originals[tree_index]
	var tree_scale := maxf(original.basis.x.length(), original.basis.z.length())
	var stump_scale := clampf(tree_scale * 0.45, 0.90, 1.80)
	stump.scale = Vector3(stump_scale, 1.0, stump_scale)
	stump.position = _harvest_tree_positions[tree_index] + Vector3.UP * 0.36
	stump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	stump_root.add_child(stump)
	_harvest_stumps[resource_id] = stump


func _remove_tree_stump(resource_id: String) -> void:
	var stump := _harvest_stumps.get(resource_id) as Node
	if stump != null:
		stump.queue_free()
	_harvest_stumps.erase(resource_id)


func _spawn_tree_loot(tree_index: int, player: Player) -> void:
	var resource_id := _harvest_tree_ids[tree_index]
	var arrow_bonus := _tree_bonus_arrow_amount(resource_id)
	var adventure := get_node_or_null("../AdventureSystem")
	if adventure == null or not adventure.has_method("spawn_pickup"):
		var inventory := get_node_or_null("/root/InventoryManager")
		if inventory != null:
			inventory.call("add_item", "WoodLog", 2)
			if arrow_bonus > 0:
				inventory.call("add_item", "Arrow", arrow_bonus)
		return
	var position := _harvest_tree_positions[tree_index]
	var seed_value := absi(resource_id.hash())
	var direction := Vector2(cos(float(seed_value % 628) * 0.01), sin(float(seed_value % 628) * 0.01))
	adventure.call("spawn_pickup", "WoodLog", 1, position + Vector3(direction.x * 0.72, 0.52, direction.y * 0.72))
	adventure.call("spawn_pickup", "WoodLog", 1, position + Vector3(-direction.y * 0.78, 0.52, direction.x * 0.78))
	if arrow_bonus > 0:
		adventure.call(
			"spawn_pickup",
			"Arrow",
			arrow_bonus,
			position + Vector3(-direction.x * 0.94, 0.64, -direction.y * 0.94)
		)
	if is_instance_valid(player):
		if arrow_bonus > 0:
			player.action_feedback.emit(
				"Han caído dos troncos y %d flechas junto al tocón" % arrow_bonus
			)
		else:
			player.action_feedback.emit("Dos troncos han caído junto al tocón")


func _tree_bonus_arrow_amount(resource_id: String) -> int:
	# Aproximadamente tres de cada diez árboles esconden flechas entre sus ramas.
	# El identificador estable hace que la recompensa sea la misma en cada carga y
	# para todos los jugadores de una partida cooperativa.
	var seed_value := absi(resource_id.hash())
	if seed_value % 100 >= 30:
		return 0
	return 2 + (seed_value / 100) % 5


func _add_scatter_breakable(spec: Dictionary) -> void:
	var resource := AdventureResource.new()
	var resource_id := String(spec.resource_id)
	resource.name = resource_id
	resource.kind = String(spec.kind)
	resource.zone_id = resource_id
	resource.required_category = "axe"
	resource.health = 3
	resource.adventure_system = self
	resource.position = spec.position
	resource.set_meta("ambient_breakable", true)
	resource.set_meta("multimesh_key", "%s|%s" % ["RockCells" if resource.kind == "rock" else "CactusCells", String(spec.bucket_key)])
	resource.set_meta("multimesh_instance_index", int(spec.instance_index))
	var multimesh_instance := _installed_multimeshes.get(String(resource.get_meta("multimesh_key"))) as MultiMeshInstance3D
	if multimesh_instance != null and multimesh_instance.multimesh != null:
		resource.set_meta("multimesh_original_transform", multimesh_instance.multimesh.get_instance_transform(int(spec.instance_index)))
	var size: Vector3 = spec.size
	var collision := CollisionShape3D.new()
	if resource.kind == "rock":
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(size.x * 0.72, 0.55), maxf(size.y * 0.70, 0.45), maxf(size.z * 0.72, 0.55))
		collision.shape = box
		collision.position.y = box.size.y * 0.42
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = clampf(maxf(size.x, size.z) * 0.22, 0.55, 2.2)
		cylinder.height = clampf(size.y * 0.86, 2.8, 13.0)
		collision.shape = cylinder
		collision.position.y = cylinder.height * 0.5
	resource.add_child(collision)
	var breakable_root := get_node_or_null("BreakableResources") as Node3D
	if breakable_root == null:
		breakable_root = Node3D.new()
		breakable_root.name = "BreakableResources"
		add_child(breakable_root)
	breakable_root.add_child(resource)
	_breakable_resources[resource_id] = resource
	generated_breakable_resource_count += 1
	if _destroyed_resource_ids.has(resource_id):
		_apply_destroyed_scatter_resource(resource)


func resource_hit_feedback(resource: AdventureResource, wrong_tool: bool = false) -> void:
	if resource == null or resource.broken:
		return
	_kill_resource_tween(resource.zone_id)
	var amplitude := 0.105 if wrong_tool else 0.072
	var tween := create_tween()
	_resource_hit_tweens[resource.zone_id] = tween
	var apply_wobble := func(angle: float) -> void:
		_set_scatter_resource_pose(
			resource,
			angle,
			Vector3(1.0 + absf(angle) * 0.55, 1.0 - absf(angle) * 0.34, 1.0 + absf(angle) * 0.55)
		)
	tween.tween_method(apply_wobble, 0.0, amplitude, 0.050)
	tween.tween_method(apply_wobble, amplitude, -amplitude * 0.78, 0.065)
	tween.tween_method(apply_wobble, -amplitude * 0.78, amplitude * 0.34, 0.055)
	tween.tween_method(apply_wobble, amplitude * 0.34, 0.0, 0.070)
	tween.tween_callback(func() -> void: _resource_hit_tweens.erase(resource.zone_id))


func break_resource(resource: AdventureResource, player: Player) -> void:
	if resource == null or not resource.broken:
		return
	var resource_id := resource.zone_id
	if _destroyed_resource_ids.has(resource_id):
		return
	var network := get_node_or_null("/root/NetworkSession")
	if _is_network_client(network):
		network.call("request_world_resource_break", "vegetation", resource_id)
	_destroyed_resource_ids[resource_id] = true
	resource.disable_collisions()
	_kill_resource_tween(resource_id)
	var tween := create_tween()
	_resource_hit_tweens[resource_id] = tween
	var apply_final_wobble := func(angle: float) -> void:
		_set_scatter_resource_pose(
			resource,
			angle,
			Vector3(1.0 + absf(angle) * 0.45, 1.0 - absf(angle) * 0.28, 1.0 + absf(angle) * 0.45)
		)
	tween.tween_method(apply_final_wobble, 0.0, 0.12, 0.055)
	tween.tween_method(apply_final_wobble, 0.12, -0.10, 0.070)
	tween.tween_method(apply_final_wobble, -0.10, 0.0, 0.060)
	var apply_break := func(progress: float) -> void:
		_set_scatter_resource_break_pose(resource, progress)
	tween.tween_method(apply_break, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_apply_destroyed_scatter_resource(resource)
		_spawn_scatter_resource_loot(resource, player)
		_resource_hit_tweens.erase(resource_id)
		var save_manager := get_node_or_null("/root/SaveGameManager")
		if save_manager != null:
			save_manager.call("save_current_game", "recurso roto")
	)
	if resource.kind == "rock":
		player.action_feedback.emit("Roca rota: recoge lo que ha soltado")
	else:
		player.action_feedback.emit("Cactus cortado: recoge lo que ha soltado")


func network_break_resource(resource_id: String, remote_player: Player) -> bool:
	## Entrada exclusiva del anfitrión para el golpe final de un invitado. No se
	## acepta el id si el jugador no tiene el hacha, está lejos o el objeto ya fue
	## destruido; así tampoco pueden duplicarse troncos, flechas, pociones o rubíes.
	if (
		not _is_network_host(get_node_or_null("/root/NetworkSession"))
		or remote_player == null
		or remote_player.equipped_slot != 2
		or _destroyed_resource_ids.has(resource_id)
	):
		return false
	if _harvest_tree_index_by_id.has(resource_id):
		var tree_index := int(_harvest_tree_index_by_id[resource_id])
		var tree_position := _harvest_tree_positions[tree_index]
		if not _network_break_reachable(remote_player.global_position, tree_position):
			return false
		var fall_direction := Vector2(
			tree_position.x - remote_player.global_position.x,
			tree_position.z - remote_player.global_position.z
		).normalized()
		_break_harvest_tree(tree_index, fall_direction, remote_player)
		return true
	var resource := _breakable_resources.get(resource_id) as AdventureResource
	if (
		resource == null
		or resource.broken
		or not _network_break_reachable(remote_player.global_position, resource.global_position)
	):
		return false
	resource.health = 0
	resource.broken = true
	break_resource(resource, remote_player)
	return true


func _network_break_reachable(player_position: Vector3, target_position: Vector3) -> bool:
	var horizontal := Vector2(
		player_position.x - target_position.x,
		player_position.z - target_position.z
	).length()
	# Margen de red sobre el alcance del hacha: admite interpolación/latencia, pero
	# rechaza cualquier petición remota o procedente de otra zona del mapa.
	return horizontal <= 7.0 and absf(player_position.y - target_position.y) <= 8.0


func _is_network_client(network: Node) -> bool:
	return (
		network != null
		and bool(network.call("is_networked"))
		and not bool(network.call("is_world_authority"))
	)


func _is_network_host(network: Node) -> bool:
	return network != null and bool(network.call("is_host"))


func _kill_resource_tween(resource_id: String) -> void:
	var previous = _resource_hit_tweens.get(resource_id, null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	_resource_hit_tweens.erase(resource_id)


func _set_scatter_resource_pose(
	resource: AdventureResource,
	angle: float,
	local_scale: Vector3
) -> void:
	var multimesh_instance := _installed_multimeshes.get(
		String(resource.get_meta("multimesh_key", ""))
	) as MultiMeshInstance3D
	var index := int(resource.get_meta("multimesh_instance_index", -1))
	var original = resource.get_meta("multimesh_original_transform", null)
	if (
		multimesh_instance == null
		or multimesh_instance.multimesh == null
		or index < 0
		or index >= multimesh_instance.multimesh.instance_count
		or not original is Transform3D
	):
		return
	var original_transform := original as Transform3D
	var axis := Vector3.FORWARD if resource.kind == "cactus" else Vector3(0.72, 0.0, 0.69).normalized()
	var pose := Transform3D(
		Basis(axis, angle) * original_transform.basis.scaled(local_scale),
		original_transform.origin
	)
	resource.set_meta("computed_visible_wobble_delta", pose.basis.y.distance_to(original_transform.basis.y))
	multimesh_instance.multimesh.set_instance_transform(index, pose)
	resource.set_meta("last_visible_wobble_angle", angle)


func _set_scatter_resource_break_pose(resource: AdventureResource, progress: float) -> void:
	if resource.kind == "cactus":
		_set_scatter_resource_pose(
			resource,
			deg_to_rad(82.0) * progress * progress,
			Vector3(1.0, 1.0 - progress * 0.10, 1.0)
		)
	else:
		_set_scatter_resource_pose(
			resource,
			progress * 0.08,
			Vector3(1.0 + progress * 0.20, 1.0 - progress * 0.78, 1.0 + progress * 0.20)
		)


func _spawn_scatter_resource_loot(resource: AdventureResource, player: Player) -> void:
	var seed_value := absi(resource.zone_id.hash())
	var rewards: Array[Dictionary] = []
	if resource.kind == "rock":
		# Todas las rocas dejan munición; una de cada tres conserva además el
		# premio de rubíes que ya podían contener.
		rewards.append({"item_id": "Arrow", "amount": 3 + seed_value % 5})
		if seed_value % 3 == 0:
			rewards.append({"item_id": "Crystal4", "amount": 1 + seed_value % 3})
	else:
		if seed_value % 2 == 0:
			rewards.append({
				"item_id": "Potion%d_Filled" % (1 + seed_value % 11),
				"amount": 1,
			})
		else:
			rewards.append({"item_id": "Crystal4", "amount": 1 + seed_value % 2})
	var drop_position := resource.global_position + Vector3.UP * (0.72 if resource.kind == "rock" else 1.05)
	var adventure := get_node_or_null("../AdventureSystem")
	var inventory := get_node_or_null("/root/InventoryManager")
	var feedback_parts := PackedStringArray()
	for reward_index in rewards.size():
		var reward := rewards[reward_index]
		var reward_id := String(reward.item_id)
		var amount := int(reward.amount)
		var angle := float(reward_index) * 2.35 + float(seed_value % 628) * 0.01
		var reward_position := drop_position + Vector3(cos(angle), 0.0, sin(angle)) * (0.56 * float(reward_index))
		if adventure != null and adventure.has_method("spawn_pickup"):
			adventure.call("spawn_pickup", reward_id, amount, reward_position)
		elif inventory != null:
			inventory.call("add_item", reward_id, amount)
		var definition := inventory.call("get_item_definition", reward_id) as Dictionary if inventory != null else {}
		feedback_parts.append(
			"%d × %s" % [amount, String(definition.get("display_name", reward_id))]
		)
	if is_instance_valid(player):
		player.action_feedback.emit("Ha caído: %s" % ", ".join(feedback_parts))


func _apply_destroyed_scatter_resource(resource: AdventureResource) -> void:
	resource.broken = true
	resource.disable_collisions()
	var multimesh_instance := _installed_multimeshes.get(String(resource.get_meta("multimesh_key", ""))) as MultiMeshInstance3D
	if multimesh_instance == null or multimesh_instance.multimesh == null:
		return
	var index := int(resource.get_meta("multimesh_instance_index", -1))
	if index < 0 or index >= multimesh_instance.multimesh.instance_count:
		return
	var hidden_transform := multimesh_instance.multimesh.get_instance_transform(index)
	hidden_transform.basis = Basis.from_scale(Vector3.ONE * 0.001)
	hidden_transform.origin.y -= 10000.0
	multimesh_instance.multimesh.set_instance_transform(index, hidden_transform)


func get_save_state() -> Dictionary:
	var ids := PackedStringArray(_destroyed_resource_ids.keys())
	ids.sort()
	return {"destroyed_resource_ids": Array(ids)}


func apply_save_state(state: Dictionary) -> void:
	var previous_destroyed := _destroyed_resource_ids.duplicate()
	for tween_value in _tree_hit_tweens.values():
		if tween_value is Tween and (tween_value as Tween).is_valid():
			(tween_value as Tween).kill()
	for tween_value in _resource_hit_tweens.values():
		if tween_value is Tween and (tween_value as Tween).is_valid():
			(tween_value as Tween).kill()
	_tree_hit_tweens.clear()
	_resource_hit_tweens.clear()
	_harvest_tree_health.clear()
	_destroyed_resource_ids.clear()
	for id_value in state.get("destroyed_resource_ids", []):
		_destroyed_resource_ids[String(id_value)] = true
	for resource_id in _breakable_resources:
		var resource := _breakable_resources[resource_id] as AdventureResource
		if _destroyed_resource_ids.has(resource_id):
			_apply_destroyed_scatter_resource(resource)
		else:
			_restore_scatter_resource(resource)
	for old_id_value in previous_destroyed.keys():
		var old_id := String(old_id_value)
		if _destroyed_resource_ids.has(old_id) or not _harvest_tree_index_by_id.has(old_id):
			continue
		var restored_index := int(_harvest_tree_index_by_id[old_id])
		_set_harvest_tree_hidden(restored_index, false)
		_remove_tree_stump(old_id)
	for resource_id_value in _destroyed_resource_ids.keys():
		var tree_resource_id := String(resource_id_value)
		if not _harvest_tree_index_by_id.has(tree_resource_id):
			continue
		var tree_index := int(_harvest_tree_index_by_id[tree_resource_id])
		_set_harvest_tree_hidden(tree_index, true)
		_ensure_tree_stump(tree_index)
	_refresh_tree_collision_mesh()


func _restore_scatter_resource(resource: AdventureResource) -> void:
	resource.broken = false
	resource.health = 3
	resource.set_collisions_enabled(true)
	var multimesh_instance := _installed_multimeshes.get(String(resource.get_meta("multimesh_key", ""))) as MultiMeshInstance3D
	if multimesh_instance == null or multimesh_instance.multimesh == null:
		return
	var index := int(resource.get_meta("multimesh_instance_index", -1))
	var original = resource.get_meta("multimesh_original_transform", null)
	if index >= 0 and index < multimesh_instance.multimesh.instance_count and original is Transform3D:
		multimesh_instance.multimesh.set_instance_transform(index, original as Transform3D)


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
