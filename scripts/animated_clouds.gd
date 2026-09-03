extends Node3D
class_name AnimatedClouds

## Cielo procedural continuo. Las tarjetas ilustradas quedan disponibles como
## opción, pero desactivadas por defecto porque delataban su orientación al
## girar la cámara cuando una nube pasaba cerca del jugador.

const DEFAULT_CLOUD_ATLAS: Texture2D = preload(
	"res://assets/textures/sky/illustrated_cloud_atlas_v3.png"
)
const FIELD_AABB := AABB(
	Vector3(-15000.0, -200.0, -15000.0),
	Vector3(30000.0, 2200.0, 30000.0)
)

@export var illustrated_cloud_atlas: Texture2D = DEFAULT_CLOUD_ATLAS
@export var illustrated_clouds_enabled := false
@export var cloud_altitude := 220.0
@export var low_cloud_altitude := 108.0
@export var wind_direction := Vector2(1.0, 0.28)
@export var wind_speed := 0.1
@export_range(4, 16, 1) var near_cloud_count := 6
@export_range(8, 28, 1) var mid_cloud_count := 10
@export_range(12, 40, 1) var horizon_cloud_count := 16
@export_range(4, 12, 1) var shadow_mask_count := 6
@export_range(1, 8, 1) var atlas_columns := 4
@export_range(1, 8, 1) var atlas_rows := 4
@export_range(0.05, 0.95, 0.01) var procedural_veil_opacity := 0.75
@export_range(0.15, 0.85, 0.01) var procedural_cloud_coverage := 0.66
@export_range(1.8, 5.0, 0.1) var procedural_cloud_region_scale := 3.8

var _cloud_rng := RandomNumberGenerator.new()
var _visual_material: ShaderMaterial
var _shadow_material: ShaderMaterial
var _veil_material: ShaderMaterial
var _near_clouds: MultiMeshInstance3D
var _mid_clouds: MultiMeshInstance3D
var _horizon_clouds: MultiMeshInstance3D
var _shadow_masks: MultiMeshInstance3D
var _procedural_veil: MeshInstance3D
var _near_records: Array[Dictionary] = []
var _mid_records: Array[Dictionary] = []
var _horizon_records: Array[Dictionary] = []

const ILLUSTRATED_CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform sampler2D cloud_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform float atlas_cell_count = 16.0;
uniform vec4 day_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 night_tint : source_color = vec4(0.09, 0.14, 0.25, 1.0);
uniform vec4 sunset_tint : source_color = vec4(1.0, 0.64, 0.37, 1.0);
uniform vec4 horizon_tint : source_color = vec4(0.80, 0.91, 1.0, 1.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float warm_light : hint_range(0.0, 1.0) = 0.0;

varying float instance_opacity;
varying float instance_haze;
varying float instance_brightness;

void vertex() {
	float cell_index = floor(INSTANCE_CUSTOM.r * atlas_cell_count);
	vec2 atlas_cell = vec2(
		mod(cell_index, atlas_grid.x),
		floor(cell_index / atlas_grid.x)
	);
	UV = (UV + atlas_cell) / atlas_grid;
	instance_haze = INSTANCE_CUSTOM.g;
	instance_opacity = INSTANCE_CUSTOM.b;
	instance_brightness = INSTANCE_CUSTOM.a;
}

void fragment() {
	vec4 painted_cloud = texture(cloud_atlas, UV);
	float painted_alpha = smoothstep(0.025, 0.16, painted_cloud.a);
	vec3 time_tint = mix(night_tint.rgb, day_tint.rgb, daylight);
	time_tint = mix(time_tint, sunset_tint.rgb, warm_light);
	vec3 illustrated_color = painted_cloud.rgb * time_tint;
	illustrated_color *= mix(0.88, 1.09, instance_brightness);
	// La banda lejana pierde contraste y adopta el color del horizonte. Esto
	// crea profundidad dibujada sin añadir niebla volumétrica ni más geometría.
	illustrated_color = mix(illustrated_color, horizon_tint.rgb, instance_haze);
	ALBEDO = illustrated_color;
	EMISSION = illustrated_color * mix(0.035, 0.11, daylight);
	ROUGHNESS = 1.0;
	ALPHA = painted_alpha * instance_opacity * mix(0.72, 1.0, daylight);
	ALPHA_SCISSOR_THRESHOLD = 0.045;
}
"""

const CLOUD_SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D cloud_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform float atlas_cell_count = 16.0;

varying float instance_opacity;

void vertex() {
	float cell_index = floor(INSTANCE_CUSTOM.r * atlas_cell_count);
	vec2 atlas_cell = vec2(
		mod(cell_index, atlas_grid.x),
		floor(cell_index / atlas_grid.x)
	);
	UV = (UV + atlas_cell) / atlas_grid;
	instance_opacity = INSTANCE_CUSTOM.b;
}

void fragment() {
	float cloud_alpha = texture(cloud_atlas, UV).a * instance_opacity;
	ALBEDO = vec3(0.0);
	ALPHA = cloud_alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
}
"""

const PROCEDURAL_VEIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_prepass_alpha;

uniform vec2 wind = vec2(1.0, 0.28);
uniform vec2 world_anchor = vec2(0.0);
uniform float speed = 0.012;
uniform float opacity : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.66;
uniform float cloud_region_scale : hint_range(1.0, 8.0) = 3.8;
uniform vec4 day_cloud : source_color = vec4(0.98, 0.99, 1.0, 1.0);
//uniform vec4 day_shadow : source_color = vec4(0.89, 0.93, 0.98, 1.0);
uniform vec4 day_shadow : source_color = vec4(0.74, 0.81, 0.90, 1.0);
uniform vec4 night_cloud : source_color = vec4(0.08, 0.13, 0.23, 1.0);
uniform vec4 sunset_cloud : source_color = vec4(1.0, 0.67, 0.40, 1.0);
uniform vec4 horizon_tint : source_color = vec4(0.80, 0.92, 1.0, 1.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float warm_light : hint_range(0.0, 1.0) = 0.0;

varying vec3 sky_direction;

float hash31(vec3 point) {
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

float value_noise3(vec3 point) {
	vec3 cell = floor(point);
	vec3 local = fract(point);
	vec3 blend = local * local * (3.0 - 2.0 * local);
	float n000 = hash31(cell);
	float n100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(cell + vec3(1.0, 1.0, 1.0));
	float low = mix(
		mix(n000, n100, blend.x),
		mix(n010, n110, blend.x),
		blend.y
	);
	float high = mix(
		mix(n001, n101, blend.x),
		mix(n011, n111, blend.x),
		blend.y
	);
	return mix(low, high, blend.z);
}

// Ruido tridimensional sobre la dirección de la bóveda. Además de evitar una
// costura, permite masas grandes y cirros sin proyectar un plano sobre el cielo.
float fbm3d(vec3 point) {
	float result = 0.0;
	float amplitude = 0.56;
	for (int octave = 0; octave < 3; octave++) {
		result += value_noise3(point) * amplitude;
		point = vec3(
			point.y * 1.67 + point.z * 0.54,
			point.z * 1.31 - point.x * 0.91,
			point.x * 1.43 + point.y * 0.72
		) + vec3(11.7, 7.3, 5.9);
		amplitude *= 0.46;
	}
	return result;
}

void vertex() {
	// El dominio nace de la dirección local de la bóveda, no de coordenadas de textura.
	// Por ello no existe costura polar ni un rectángulo que pueda revelarse.
	sky_direction = normalize(VERTEX);
}

void fragment() {
	vec3 direction = normalize(sky_direction);
	float elevation = clamp(direction.y, 0.0, 1.0);
	float above_horizon = smoothstep(0.008, 0.10, elevation);
	float horizon_blend = 1.0 - smoothstep(0.04, 0.48, direction.y);
	vec2 normalized_wind = normalize(wind);
	vec3 drift = vec3(normalized_wind.x, 0.0, normalized_wind.y) * TIME * speed;
	vec3 anchor = vec3(world_anchor.x, 0.0, world_anchor.y);
	// Distribución meteorológica de gran escala. Los bancos pueden aparecer
	// delante, detrás o a los lados, y se desplazan lentamente con el viento.
	// El umbral deja huecos realmente transparentes para conservar cielo azul.
	float region_noise = fbm3d(
		direction * cloud_region_scale
		+ anchor * 0.38
		+ drift * 0.13
		+ vec3(17.2, 4.7, 9.3)
	);
	float region_breakup = value_noise3(
		direction * cloud_region_scale * 2.35
		- drift * 0.08
		+ vec3(3.1, 12.6, 6.8)
	);
	float region_field = region_noise + (region_breakup - 0.5) * 0.18;
	float region_threshold = mix(0.58, 0.40, cloud_coverage);
	float cloud_region = smoothstep(
		region_threshold,
		region_threshold + 0.065,
		region_field
	);
	// Primera escala: bancos atmosféricos realmente grandes. Una corona suave
	// cerca del horizonte garantiza la neblina blanca lejana de la referencia.
	vec3 broad_domain = direction * 4.10 + anchor + drift;
	float broad_warp = fbm3d(broad_domain * 0.62 + vec3(2.7, 5.1, 1.4));
	float broad = fbm3d(
		broad_domain + vec3(broad_warp * 0.54, broad_warp * 0.16, -broad_warp * 0.43)
	);
	float soft_detail = value_noise3(direction * 10.2 + anchor * 1.7 - drift * 0.34);
	float edge_erosion = value_noise3(
		direction * 22.4 + anchor * 2.1 + drift * 0.21 + vec3(3.8, 9.4, 1.7)
	);
	float horizon_crown = smoothstep(0.02, 0.24, elevation)
		* (1.0 - smoothstep(0.48, 0.79, elevation));
	float zenith_boost = smoothstep(0.30, 0.82, elevation) * 0.10;
	float bank_field = broad
		+ (soft_detail - 0.5) * 0.22
		+ (edge_erosion - 0.5) * 0.10
		+ zenith_boost;
	// Una segunda distribución, algo más pequeña, abre claros dentro de cada
	// banco grande. Sin ella una única zona alta del ruido podía convertirse
	// en una mitad del cielo uniformemente blanca.
	float cluster_noise = fbm3d(
		direction * 7.4 + anchor * 1.18 - drift * 0.20 + vec3(8.6, 2.4, 13.1)
	);
	float cluster_shape = smoothstep(0.40, 0.60, cluster_noise);
	// Separamos el halo del cuerpo para que la franja sea una sucesión de
	// nubes blancas densas, no una pared de niebla que lave medio cielo.
	float bank_haze = smoothstep(0.48, 0.55, bank_field);
	float bank_body = smoothstep(0.52, 0.60, bank_field);
	// Segunda escala: velos altos estirados en horizontal. Son blancos,
	// semitransparentes y se funden en lugar de formar óvalos sólidos.
	vec3 cirrus_domain = vec3(
		direction.x * 3.10,
		direction.y * 17.0 + direction.x * 3.6 - direction.z * 2.2,
		direction.z * 3.10
	) + anchor * 0.72 - drift * 0.46;
	cirrus_domain.y += (broad - 0.5) * 3.2;
	float cirrus = fbm3d(cirrus_domain + vec3(7.4, 2.1, 11.8));
	float cirrus_detail = value_noise3(cirrus_domain * 2.15 + vec3(3.0, 9.0, 4.0));
	float cirrus_breakup = value_noise3(
		direction * 7.2 + anchor * 0.63 + drift * 0.18 + vec3(4.3, 1.7, 8.9)
	);
	float cirrus_contour = 1.0 - abs(cirrus * 2.06 - 1.0);
	float streak_mask = smoothstep(
		0.68,
		0.91,
		cirrus_contour + (cirrus_detail - 0.5) * 0.12
	);
	streak_mask *= smoothstep(0.18, 0.48, elevation);
	streak_mask *= smoothstep(0.40, 0.63, broad);
	streak_mask *= smoothstep(0.25, 0.60, cirrus_breakup);
	// Composición por cobertura: el halo exterior permanece ligero y el cuerpo
	// nunca alcanza la opacidad de una pegatina.
	float bank_vertical_fade = mix(
		0.30,
		0.95,
		smoothstep(0.30, 0.85, elevation)
	);
	//float bank_alpha = (bank_haze * 0.38 + bank_body * 0.14) * bank_vertical_fade;
	//float bank_alpha = (bank_haze * 0.50 + bank_body * 0.30) * bank_vertical_fade;
	float bank_core = smoothstep(0.58, 0.66, bank_field);
	float bank_alpha = (
		bank_haze * 0.12
		+ bank_body * 0.68
		+ bank_core * 0.62
	) * bank_vertical_fade * cloud_region * mix(0.30, 1.0, cluster_shape);
	float cirrus_alpha = streak_mask * 0.15 * cloud_region;
	float cloud_mask = 1.0 - (1.0 - bank_alpha) * (1.0 - cirrus_alpha);
	vec3 cloud_color = mix(night_cloud.rgb, day_cloud.rgb, daylight);
	cloud_color = mix(cloud_color, sunset_cloud.rgb, warm_light);
	vec3 shadow_color = mix(night_cloud.rgb * 0.62, day_shadow.rgb, daylight);
	//vec3 painted_color = mix(shadow_color, cloud_color, 0.48 + bank_body * 0.42);
	vec3 painted_color = mix(shadow_color, cloud_color, 0.70 + bank_body * 0.26);
	painted_color = mix(painted_color, cloud_color, streak_mask * 0.58);
	painted_color = mix(painted_color, horizon_tint.rgb, horizon_blend * 0.22);
	float final_alpha = clamp(
		cloud_mask * above_horizon * opacity,
		0.0,
		0.94
	);
	ALBEDO = painted_color;
	EMISSION = painted_color * mix(0.025, 0.115, daylight);
	ROUGHNESS = 1.0;
	ALPHA = final_alpha;
}
"""


func _ready() -> void:
	_build_illustrated_sky()


func _process(delta: float) -> void:
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return
	var normalized_wind := wind_direction.normalized()
	if normalized_wind.length_squared() < 0.001:
		normalized_wind = Vector2.RIGHT
	var drift_speed := maxf(wind_speed, 0.001) * 430.0
	_update_visual_field(
		_near_clouds, _near_records, active_camera, 2200.0,
		drift_speed, 1.0, delta, false, normalized_wind
	)
	_update_visual_field(
		_mid_clouds, _mid_records, active_camera, 4800.0,
		drift_speed, 0.54, delta, false, normalized_wind
	)
	_update_visual_field(
		_horizon_clouds, _horizon_records, active_camera, 7600.0,
		drift_speed, 0.22, delta, true, normalized_wind
	)
	_update_shadow_masks(active_camera)
	_update_procedural_veil(active_camera)
	_update_cloud_palette()


func _build_illustrated_sky() -> void:
	for child in get_children():
		child.queue_free()
	_cloud_rng.seed = 447731
	_visual_material = null
	_shadow_material = null
	_near_clouds = null
	_mid_clouds = null
	_horizon_clouds = null
	_shadow_masks = null
	_near_records.clear()
	_mid_records.clear()
	_horizon_records.clear()
	if illustrated_clouds_enabled:
		var atlas := illustrated_cloud_atlas if illustrated_cloud_atlas != null else DEFAULT_CLOUD_ATLAS
		_visual_material = _make_material(ILLUSTRATED_CLOUD_SHADER, atlas)
		_shadow_material = _make_material(CLOUD_SHADOW_SHADER, atlas)
		var visual_mesh := _make_card_mesh(_visual_material)
		var shadow_mesh := _make_card_mesh(_shadow_material)
		_near_clouds = _make_visual_field(
			"IllustratedCloudNear", visual_mesh, near_cloud_count,
			Vector2(1300.0, 3500.0),
			Vector2(low_cloud_altitude + 180.0, low_cloud_altitude + 660.0),
			Vector2(650.0, 1400.0), Vector2(220.0, 500.0),
			Vector2(0.78, 0.96), Vector2(0.02, 0.16), _near_records,
			PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
		)
		_mid_clouds = _make_visual_field(
			"IllustratedCloudMid", visual_mesh, mid_cloud_count,
			Vector2(2500.0, 6200.0),
			Vector2(cloud_altitude + 100.0, cloud_altitude + 720.0),
			Vector2(850.0, 1900.0), Vector2(240.0, 570.0),
			Vector2(0.56, 0.84), Vector2(0.16, 0.45), _mid_records,
			PackedInt32Array([
				0, 1, 2, 3, 4,
				5, 6, 7, 8, 9,
				10, 11, 12, 13, 14, 15,
			])
		)
		_horizon_clouds = _make_visual_field(
			"IllustratedCloudHorizon", visual_mesh, horizon_cloud_count,
			Vector2(4800.0, 9400.0),
			Vector2(low_cloud_altitude + 45.0, low_cloud_altitude + 520.0),
			Vector2(1200.0, 2900.0), Vector2(210.0, 550.0),
			Vector2(0.38, 0.68), Vector2(0.48, 0.84), _horizon_records,
			PackedInt32Array([0, 1, 2, 3, 4, 10, 11, 12, 13, 14, 15])
		)
		_shadow_masks = _make_shadow_field(shadow_mesh)
	_procedural_veil = _make_procedural_veil()

	set_meta("illustrated_billboards", illustrated_clouds_enabled)
	set_meta("drawn_clouds_disabled", not illustrated_clouds_enabled)
	set_meta("procedural_clouds_only", not illustrated_clouds_enabled)
	set_meta("procedural_diffuse_veil", true)
	set_meta("distributed_cloud_banks", true)
	set_meta("clear_sky_gaps", true)
	set_meta("hybrid_cloud_system", illustrated_clouds_enabled)
	set_meta("depth_band_count", 3 if illustrated_clouds_enabled else 1)
	set_meta("sun_occlusion", illustrated_clouds_enabled)
	set_meta("separate_shadow_masks", illustrated_clouds_enabled)
	set_meta("atlas_grid", Vector2i(atlas_columns, atlas_rows))
	set_meta("atlas_cloud_variety", atlas_columns * atlas_rows)
	set_meta("cloud_shape_families", 3)
	set_meta(
		"visual_triangle_budget",
		(near_cloud_count + mid_cloud_count + horizon_cloud_count) * 2
		if illustrated_clouds_enabled
		else 0
	)


func _make_material(shader_code: String, atlas: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = shader_code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cloud_atlas", atlas)
	material.set_shader_parameter(
		"atlas_grid", Vector2(maxi(atlas_columns, 1), maxi(atlas_rows, 1))
	)
	material.set_shader_parameter(
		"atlas_cell_count", float(maxi(atlas_columns * atlas_rows, 1))
	)
	return material


func _make_procedural_veil() -> MeshInstance3D:
	var shader := Shader.new()
	shader.code = PROCEDURAL_VEIL_SHADER
	_veil_material = ShaderMaterial.new()
	_veil_material.shader = shader
	_veil_material.set_shader_parameter("wind", wind_direction.normalized())
	_veil_material.set_shader_parameter("speed", maxf(wind_speed, 0.001) * 0.78)
	_veil_material.set_shader_parameter("opacity", procedural_veil_opacity)
	_veil_material.set_shader_parameter(
		"cloud_coverage", procedural_cloud_coverage
	)
	_veil_material.set_shader_parameter(
		"cloud_region_scale", procedural_cloud_region_scale
	)
	var mesh := SphereMesh.new()
	mesh.radius = 8200.0
	mesh.height = 16400.0
	mesh.radial_segments = 32
	mesh.rings = 16
	mesh.material = _veil_material
	var veil := MeshInstance3D.new()
	veil.name = "ProceduralCloudVeil"
	veil.mesh = mesh
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	veil.extra_cull_margin = 12000.0
	veil.set_meta("procedural_diffuse_veil", true)
	veil.set_meta("large_diffuse_clouds", true)
	veil.set_meta("world_anchored_noise", true)
	veil.set_meta("direction_mapped_canopy", true)
	veil.set_meta("noise_octaves", 3)
	veil.set_meta("distributed_cloud_banks", true)
	veil.set_meta("clear_sky_gaps", true)
	add_child(veil)
	return veil


func _make_card_mesh(material: Material) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = material
	return mesh


func _make_visual_field(
	field_name: String,
	cloud_mesh: Mesh,
	cloud_count: int,
	radius_range: Vector2,
	elevation_range: Vector2,
	width_range: Vector2,
	height_range: Vector2,
	opacity_range: Vector2,
	haze_range: Vector2,
	records: Array[Dictionary],
	atlas_choices: PackedInt32Array
) -> MultiMeshInstance3D:
	records.clear()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = cloud_mesh
	multimesh.instance_count = cloud_count
	var atlas_start := _cloud_rng.randi_range(0, atlas_choices.size() - 1)
	var atlas_stride := 7
	for cloud_index in cloud_count:
		var normalized := (
			float(cloud_index) + _cloud_rng.randf_range(0.12, 0.88)
		) / float(cloud_count)
		var radius := sqrt(lerpf(
			radius_range.x * radius_range.x,
			radius_range.y * radius_range.y,
			clampf(normalized, 0.0, 1.0)
		))
		var angle := TAU * fmod(
			float(cloud_index) * 0.61803398875 + _cloud_rng.randf_range(0.0, 0.21),
			1.0
		)
		var atlas_choice_index := (
			atlas_start + cloud_index * atlas_stride
		) % atlas_choices.size()
		var atlas_index := atlas_choices[atlas_choice_index]
		var family_scale := _atlas_family_scale(atlas_index)
		var family_speed := _atlas_family_speed(atlas_index)
		var family_elevation := _atlas_family_elevation(atlas_index)
		var record := {
			"offset": Vector2(cos(angle), sin(angle)) * radius,
			"elevation": (
				_cloud_rng.randf_range(elevation_range.x, elevation_range.y)
				+ family_elevation
			),
			"width": (
				_cloud_rng.randf_range(width_range.x, width_range.y)
				* family_scale.x
			),
			"height": (
				_cloud_rng.randf_range(height_range.x, height_range.y)
				* family_scale.y
			),
			"speed": _cloud_rng.randf_range(0.76, 1.28) * family_speed,
			"atlas_index": atlas_index,
			"opacity": _cloud_rng.randf_range(opacity_range.x, opacity_range.y),
			"haze": _cloud_rng.randf_range(haze_range.x, haze_range.y),
			"brightness": _cloud_rng.randf_range(0.58, 0.98),
		}
		records.append(record)
		multimesh.set_instance_transform(cloud_index, _initial_card_transform(record))
		multimesh.set_instance_custom_data(cloud_index, _record_custom_data(record))
	multimesh.custom_aabb = FIELD_AABB
	var instance := MultiMeshInstance3D.new()
	instance.name = field_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.set_meta("illustrated_billboard", true)
	instance.set_meta("occludes_sun", true)
	instance.set_meta("casts_world_shadows", false)
	instance.set_meta("recycled_field_radius", radius_range.y)
	add_child(instance)
	return instance


func _atlas_family_scale(atlas_index: int) -> Vector2:
	if atlas_index < 5:
		# Bancos horizontales: enormes y bajos.
		return Vector2(1.42, 0.66)
	if atlas_index < 10:
		# Cúmulos asimétricos: masa y altura visibles desde el suelo.
		return Vector2(1.04, 1.18)
	# Cirros: recorridos muy largos con poco espesor.
	return Vector2(1.62, 0.48)


func _atlas_family_speed(atlas_index: int) -> float:
	if atlas_index < 5:
		return 0.72
	if atlas_index < 10:
		return 0.90
	return 1.34


func _atlas_family_elevation(atlas_index: int) -> float:
	if atlas_index < 5:
		return -55.0
	if atlas_index < 10:
		return 35.0
	return 360.0


func _make_shadow_field(shadow_mesh: Mesh) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = shadow_mesh
	multimesh.instance_count = shadow_mask_count
	for shadow_index in shadow_mask_count:
		var source_record := _near_records[shadow_index % _near_records.size()]
		multimesh.set_instance_transform(
			shadow_index, _initial_shadow_transform(source_record)
		)
		var shadow_data := _record_custom_data(source_record)
		shadow_data.b = 0.72
		multimesh.set_instance_custom_data(shadow_index, shadow_data)
	multimesh.custom_aabb = FIELD_AABB
	var instance := MultiMeshInstance3D.new()
	instance.name = "CloudShadowMasks"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.set_meta("illustrated_billboard", false)
	instance.set_meta("shadow_masks_only", true)
	instance.set_meta("occludes_sun", false)
	instance.set_meta("casts_world_shadows", true)
	add_child(instance)
	return instance


func _update_visual_field(
	instance: MultiMeshInstance3D,
	records: Array[Dictionary],
	camera: Camera3D,
	field_radius: float,
	base_drift_speed: float,
	drift_ratio: float,
	delta: float,
	cylindrical_billboard: bool,
	normalized_wind: Vector2
) -> void:
	if instance == null or instance.multimesh == null:
		return
	for cloud_index in records.size():
		var record := records[cloud_index]
		var offset := record["offset"] as Vector2
		offset += (
			normalized_wind * base_drift_speed * drift_ratio
			* float(record["speed"]) * delta
		)
		offset.x = fposmod(offset.x + field_radius, field_radius * 2.0) - field_radius
		offset.y = fposmod(offset.y + field_radius, field_radius * 2.0) - field_radius
		record["offset"] = offset
		records[cloud_index] = record
		var position := Vector3(
			camera.global_position.x + offset.x,
			camera.global_position.y + float(record["elevation"]),
			camera.global_position.z + offset.y
		)
		instance.multimesh.set_instance_transform(
			cloud_index,
			_billboard_transform(position, record, camera, cylindrical_billboard)
		)


func _update_shadow_masks(camera: Camera3D) -> void:
	if _shadow_masks == null or _shadow_masks.multimesh == null or _near_records.is_empty():
		return
	for shadow_index in shadow_mask_count:
		var record := _near_records[shadow_index % _near_records.size()]
		var offset := record["offset"] as Vector2
		var position := Vector3(
			camera.global_position.x + offset.x,
			camera.global_position.y + float(record["elevation"]),
			camera.global_position.z + offset.y
		)
		var width := float(record["width"]) * 0.84
		var depth := float(record["height"]) * 1.48
		var basis := Basis(
			Vector3.RIGHT * width,
			Vector3.FORWARD * depth,
			Vector3.UP
		)
		_shadow_masks.multimesh.set_instance_transform(
			shadow_index, Transform3D(basis, position)
		)


func _update_procedural_veil(camera: Camera3D) -> void:
	if _procedural_veil == null:
		return
	_procedural_veil.global_position = Vector3(
		camera.global_position.x,
		camera.global_position.y,
		camera.global_position.z
	)
	if _veil_material != null:
		_veil_material.set_shader_parameter(
			"world_anchor",
			Vector2(camera.global_position.x, camera.global_position.z) * 0.00010
		)


func _billboard_transform(
	position: Vector3,
	record: Dictionary,
	_camera: Camera3D,
	_cylindrical: bool
) -> Transform3D:
	# La tarjeta mira hacia el centro del campo en coordenadas del mundo. No usa
	# los ejes de la cámara: girar la vista ya no hace que la nube gire con ella.
	var offset := record["offset"] as Vector2
	var basis := _world_facing_cloud_basis(offset, record)
	return Transform3D(basis, position)


func _initial_card_transform(record: Dictionary) -> Transform3D:
	var offset := record["offset"] as Vector2
	return Transform3D(
		_world_facing_cloud_basis(offset, record),
		Vector3(offset.x, float(record["elevation"]), offset.y)
	)


func _world_facing_cloud_basis(offset: Vector2, record: Dictionary) -> Basis:
	# El vector depende únicamente de la posición relativa de la nube, incluida
	# su altura. Por eso la tarjeta conserva la forma frontal al mirar arriba,
	# pero no recibe el yaw ni el pitch de la cámara.
	var forward := Vector3(
		-offset.x,
		-float(record["elevation"]),
		-offset.y
	).normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var right := Vector3.UP.cross(forward).normalized()
	var corrected_up := forward.cross(right).normalized()
	return Basis(
		right * float(record["width"]),
		corrected_up * float(record["height"]),
		forward
	)


func _initial_shadow_transform(record: Dictionary) -> Transform3D:
	var offset := record["offset"] as Vector2
	var width := float(record["width"]) * 0.84
	var depth := float(record["height"]) * 1.48
	return Transform3D(
		Basis(Vector3.RIGHT * width, Vector3.FORWARD * depth, Vector3.UP),
		Vector3(offset.x, float(record["elevation"]), offset.y)
	)


func _record_custom_data(record: Dictionary) -> Color:
	var atlas_cell_count := maxi(atlas_columns * atlas_rows, 1)
	var encoded_index := (
		float(record["atlas_index"]) + 0.5
	) / float(atlas_cell_count)
	return Color(
		encoded_index,
		float(record["haze"]),
		float(record["opacity"]),
		float(record["brightness"])
	)


func _update_cloud_palette() -> void:
	var daylight := clampf(float(get_parent().get("daylight_factor")), 0.0, 1.0)
	var time_name := String(get_parent().get("time_of_day"))
	var warm_light := 0.72 if time_name in ["Amanecer", "Atardecer"] else 0.0
	var day_horizon := Color(0.79, 0.91, 1.0, 1.0)
	var sunset_horizon := Color(1.0, 0.72, 0.48, 1.0)
	var night_horizon := Color(0.035, 0.075, 0.16, 1.0)
	var horizon_tint := night_horizon.lerp(day_horizon, daylight).lerp(
		sunset_horizon, warm_light * daylight
	)
	if _visual_material != null:
		_visual_material.set_shader_parameter("daylight", daylight)
		_visual_material.set_shader_parameter("warm_light", warm_light * daylight)
		_visual_material.set_shader_parameter("horizon_tint", horizon_tint)
	if _veil_material != null:
		_veil_material.set_shader_parameter("daylight", daylight)
		_veil_material.set_shader_parameter("warm_light", warm_light * daylight)
		_veil_material.set_shader_parameter("horizon_tint", horizon_tint)
