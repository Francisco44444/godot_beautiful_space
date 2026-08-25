class_name IslandEnvironment
extends Node3D

## Mar facetado, bancos de niebla y astros low-poly sin discos procedimentales.

const WORLD_SIZE := 12000.0
const MOON_DIRECTION := Vector3(-0.58, 0.69, -0.43)
const SUN_DISTANCE := 20000.0
const FOG_STREAM_REFRESH_SECONDS := 0.40
const FOG_VOLUME_BUDGET := 2
const MOON_TEXTURE: Texture2D = preload("res://assets/textures/moon/moon_craters_lowpoly.png")
const OCEAN_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.58, 0.72, 0.84);
uniform vec4 deep_color : source_color = vec4(0.025, 0.20, 0.43, 0.94);
uniform vec4 foam_color : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.34, 0.64, 0.76, 1.0);
uniform float wave_speed = 0.34;
uniform float horizon_radius = 1200000.0;

varying float wave_height;
varying float camera_distance;
varying vec2 world_xz;

float segment_distance(vec2 point, vec2 start, vec2 finish) {
	vec2 segment = finish - start;
	float progress = clamp(dot(point - start, segment) / dot(segment, segment), 0.0, 1.0);
	return distance(point, start + segment * progress);
}

float ria_distance(vec2 point) {
	float distance_value = 100000.0;
	distance_value = min(distance_value, segment_distance(point, vec2(-4780.0, -2100.0), vec2(-4420.0, -1950.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-4420.0, -1950.0), vec2(-4090.0, -1640.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-4090.0, -1640.0), vec2(-3720.0, -1510.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-3720.0, -1510.0), vec2(-3360.0, -1740.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-4780.0, 2250.0), vec2(-4380.0, 2040.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-4380.0, 2040.0), vec2(-3990.0, 2200.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-3990.0, 2200.0), vec2(-3610.0, 1880.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-3610.0, 1880.0), vec2(-3220.0, 1960.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-2550.0, -4480.0), vec2(-2390.0, -4100.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-2390.0, -4100.0), vec2(-2070.0, -3820.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-2070.0, -3820.0), vec2(-1760.0, -3520.0)));
	distance_value = min(distance_value, segment_distance(point, vec2(-1760.0, -3520.0), vec2(-1600.0, -3180.0)));
	return distance_value;
}

float coast_ratio(vec2 point) {
	float angle = atan(point.y, point.x);
	float cosine = cos(angle);
	float sine = sin(angle);
	float ellipse_radius = 1.0 / sqrt(
		(cosine * cosine) / (4740.0 * 4740.0)
		+ (sine * sine) / (4540.0 * 4540.0)
	);
	float mystery_angle = atan(sin(angle + 0.27), cos(angle + 0.27));
	float mystery_peninsula = 1200.0 * exp(-(mystery_angle * mystery_angle) / (2.0 * 0.27 * 0.27));
	float desert_angle = atan(sin(angle - 0.50), cos(angle - 0.50));
	float desert_shoulder = 420.0 * exp(-(desert_angle * desert_angle) / (2.0 * 0.32 * 0.32));
	float north_neck_angle = atan(sin(angle + 0.82), cos(angle + 0.82));
	float north_inlet = 350.0 * exp(-(north_neck_angle * north_neck_angle) / (2.0 * 0.20 * 0.20));
	float south_neck_angle = atan(sin(angle - 0.04), cos(angle - 0.04));
	float south_inlet = 430.0 * exp(-(south_neck_angle * south_neck_angle) / (2.0 * 0.18 * 0.18));
	float wobble = sin(angle * 7.0) * 0.018 + sin(angle * 13.0 + 0.7) * 0.009;
	return length(point) / (ellipse_radius + mystery_peninsula + desert_shoulder - north_inlet - south_inlet) + wobble;
}

void vertex() {
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world_vertex.xz;
	camera_distance = distance(world_vertex.xz, CAMERA_POSITION_WORLD.xz);
	float large_wave = sin(VERTEX.x * 0.012 + TIME * wave_speed) * 0.75;
	large_wave += cos(VERTEX.z * 0.016 - TIME * wave_speed * 0.83) * 0.52;
	float cross_wave = sin((VERTEX.x + VERTEX.z) * 0.021 + TIME * 0.41) * 0.22;
	wave_height = large_wave + cross_wave;
	VERTEX.y += wave_height;
	// Curvatura deliberadamente exagerada: oculta el borde geométrico y crea
	// una caída oceánica continua similar a un horizonte esférico.
	VERTEX.y -= camera_distance * camera_distance / (2.0 * horizon_radius);
}

void fragment() {
	float island_radius = coast_ratio(world_xz);
	bool ria_water = ria_distance(world_xz) < 128.0;
	bool dry_fossa = world_xz.x > 2500.0 && world_xz.y > 280.0 && world_xz.y < 3360.0 && island_radius < 0.90;
	// Bajo el interior el océano se descarta: las rías conservan agua, mientras
	// que la fosa desértica puede verse hasta el fondo en vez de quedar inundada.
	if ((island_radius < 0.835 && !ria_water) || dry_fossa) {
		discard;
	}
	float facet = floor(clamp(wave_height * 0.22 + 0.5, 0.0, 0.999) * 5.0) / 4.0;
	float crest = smoothstep(0.78, 1.28, wave_height);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, facet);
	ALBEDO = mix(ALBEDO, foam_color.rgb, crest * 0.38);
	ALBEDO = mix(ALBEDO, horizon_color.rgb, smoothstep(7200.0, 21000.0, camera_distance));
	ROUGHNESS = 0.28;
	SPECULAR = 0.58;
	ALPHA = mix(deep_color.a, shallow_color.a, facet);
}
"""

const MOON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D moon_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 moon_tint : source_color = vec3(0.78, 0.86, 1.0);

void fragment() {
	vec3 lunar_surface = texture(moon_texture, UV).rgb;
	float facets = floor(clamp(NORMAL.x * 0.20 + NORMAL.y * 0.32 + NORMAL.z * 0.12 + 0.62, 0.0, 1.0) * 7.0) / 7.0;
	vec3 color = lunar_surface * moon_tint * (0.82 + facets * 0.28);
	ALBEDO = color;
	EMISSION = color * 1.38;
	ROUGHNESS = 1.0;
}
"""

const SUN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 warm_color : source_color = vec3(1.0, 0.53, 0.12);
uniform vec3 core_color : source_color = vec3(1.0, 0.91, 0.42);

void fragment() {
	float light_facing = clamp(NORMAL.z * 0.18 + NORMAL.y * 0.22 + 0.62, 0.0, 1.0);
	float facet = floor(light_facing * 6.0) / 5.0;
	vec3 color = mix(warm_color, core_color, facet);
	ALBEDO = color;
	EMISSION = color * 2.8;
	ROUGHNESS = 1.0;
}
"""

const FOG_ZONES: Array = [
	{"name": "BosqueUmbrio", "center": Vector3(-2180, 26, 1650), "size": Vector3(1050, 64, 920), "color": Color(0.25, 0.34, 0.31, 1), "density": 0.024},
	{"name": "AldeaBruma", "center": Vector3(-2200, 24, -900), "size": Vector3(980, 58, 860), "color": Color(0.42, 0.48, 0.56, 1), "density": 0.020},
	{"name": "PinarNorte", "center": Vector3(520, 92, -2650), "size": Vector3(1180, 92, 820), "color": Color(0.52, 0.59, 0.68, 1), "density": 0.015},
	{"name": "BosqueTenebroso", "center": Vector3(4380, 92, -1320), "size": Vector3(2200, 150, 1800), "color": Color(0.08, 0.18, 0.29, 1), "density": 0.033},
	{"name": "NubeBajaTenebrosa", "center": Vector3(4250, 215, -1720), "size": Vector3(2250, 86, 1420), "color": Color(0.23, 0.34, 0.48, 1), "density": 0.014},
	{"name": "BrumaCosteraOccidental", "center": Vector3(-3550, 38, 250), "size": Vector3(1250, 54, 2200), "color": Color(0.48, 0.58, 0.62, 1), "density": 0.013},
]

var fog_zone_count := 0
var ocean: MeshInstance3D
var stars: MultiMeshInstance3D
var star_count := 260
var moon_visual: MeshInstance3D
var moon_light: DirectionalLight3D
var moon_radius := 88.0
var sun_visual: MeshInstance3D
var sun_radius := 1210.0
var tide_period_seconds := 210.0
var tide_phase := 0.18
var tide_height := -0.55
var tide_normalized := 0.5
var tide_rising := true
var tide_velocity := 0.0
var _star_material: StandardMaterial3D
var _moon_material: ShaderMaterial
var _sun_material: ShaderMaterial
var _ocean_material: ShaderMaterial
var _fog_volumes: Array[FogVolume] = []
var _fog_stream_elapsed := FOG_STREAM_REFRESH_SECONDS
var active_fog_volume_count := 0


func _ready() -> void:
	_build_ocean()
	_build_fog_zones()
	_build_stars()
	_build_sun()
	_build_moon()


func _process(delta: float) -> void:
	_update_tide(delta)
	var camera := get_viewport().get_camera_3d()
	var daylight := float(get_parent().get("daylight_factor"))
	var directional_sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	var sun_source_direction := Vector3.UP
	if directional_sun != null:
		# DirectionalLight emite por -Z; la fuente visible está en +Z.
		sun_source_direction = directional_sun.global_basis.z.normalized()
	if camera != null:
		if stars != null:
			stars.global_position = Vector3(camera.global_position.x, 0.0, camera.global_position.z)
		if moon_visual != null:
			moon_visual.global_position = camera.global_position + MOON_DIRECTION.normalized() * 760.0
		if sun_visual != null:
			# El astro queda detrás de toda la isla, no a 760 m entre montañas y
			# edificios. El radio mantiene el mismo tamaño angular que antes.
			sun_visual.global_position = camera.global_position + sun_source_direction * SUN_DISTANCE
		_update_fog_streaming(camera, delta)
	if sun_visual != null:
		# El radio aparente del astro exige mantener su centro visible unos grados
		# bajo el horizonte; así no desaparece antes de completar la puesta.
		var horizon_margin := sun_radius / SUN_DISTANCE * 1.05
		sun_visual.visible = camera != null and daylight > 0.004 and sun_source_direction.y > -horizon_margin
	var night := 1.0 - smoothstep(0.08, 0.34, daylight)
	if _star_material != null:
		_star_material.albedo_color = Color(0.88, 0.94, 1.0, night)
		_star_material.emission_energy_multiplier = 1.2 + night * 2.6
	if moon_visual != null:
		# No se deja una esfera transparente en el pase diurno: se retira del
		# render por completo para impedir el punto negro que producía la niebla.
		moon_visual.visible = night > 0.06
	if moon_light != null:
		moon_light.light_energy = night * 0.72
		moon_light.shadow_enabled = night > 0.08
	if _ocean_material != null:
		var ocean_night := Color(0.035, 0.075, 0.16, 1.0)
		var ocean_day := Color(0.34, 0.64, 0.76, 1.0)
		_ocean_material.set_shader_parameter("horizon_color", ocean_night.lerp(ocean_day, daylight))


func _update_tide(delta: float) -> void:
	if tide_period_seconds <= 0.0:
		return
	var previous_height := tide_height
	tide_phase = fmod(tide_phase + delta * TAU / tide_period_seconds, TAU)
	tide_normalized = sin(tide_phase) * 0.5 + 0.5
	# Bajamar deja visibles los últimos brazos; pleamar entra hasta las cabeceras.
	tide_height = lerpf(-2.30, 2.45, smoothstep(0.06, 0.94, tide_normalized))
	tide_rising = cos(tide_phase) > 0.0001
	tide_velocity = (tide_height - previous_height) / delta if delta > 0.0001 else 0.0
	if ocean != null:
		ocean.position.y = tide_height


func _build_sun() -> void:
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = sun_radius
	sun_mesh.height = sun_radius * 2.0
	sun_mesh.radial_segments = 12
	sun_mesh.rings = 6
	var shader := Shader.new()
	shader.code = SUN_SHADER
	_sun_material = ShaderMaterial.new()
	_sun_material.shader = shader
	sun_mesh.material = _sun_material
	sun_visual = MeshInstance3D.new()
	sun_visual.name = "LowPolySun"
	sun_visual.mesh = sun_mesh
	sun_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun_visual.visibility_range_end = 0.0
	sun_visual.visible = false
	sun_visual.set_meta("low_poly_sun", true)
	sun_visual.set_meta("opaque_sun", true)
	sun_visual.set_meta("radius_metres", sun_radius)
	sun_visual.set_meta("celestial_distance", SUN_DISTANCE)
	sun_visual.set_meta("behind_world_geometry", true)
	add_child(sun_visual)


func _build_ocean() -> void:
	ocean = MeshInstance3D.new()
	ocean.name = "LowPolyOcean"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WORLD_SIZE * 6.0, WORLD_SIZE * 6.0)
	mesh.subdivide_width = 320
	mesh.subdivide_depth = 320
	ocean.mesh = mesh
	ocean.position.y = tide_height
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.visibility_range_end = 28000.0
	ocean.set_meta("low_poly_waves", true)
	ocean.set_meta("spherical_horizon", true)
	ocean.set_meta("horizon_radius", 1200000.0)
	ocean.set_meta("animated_tides", true)
	ocean.set_meta("rising_tide_pushes_actors", true)
	ocean.set_meta("tide_range", Vector2(-2.30, 2.45))
	var shader := Shader.new()
	shader.code = OCEAN_SHADER
	_ocean_material = ShaderMaterial.new()
	_ocean_material.shader = shader
	ocean.material_override = _ocean_material
	add_child(ocean)


func _build_fog_zones() -> void:
	for zone in FOG_ZONES:
		var volume := FogVolume.new()
		volume.name = zone.name
		volume.position = zone.center
		volume.size = zone.size
		var fog := FogMaterial.new()
		fog.density = zone.density
		fog.albedo = zone.color
		fog.emission = Color(zone.color.r, zone.color.g, zone.color.b, 1.0) * 0.035
		fog.edge_fade = 0.72
		fog.height_falloff = 0.34
		volume.material = fog
		volume.set_meta("activation_radius", maxf(zone.size.x, zone.size.z) * 0.62 + 520.0)
		volume.set_meta("high_altitude_only", String(zone.name) == "NubeBajaTenebrosa")
		volume.set_meta("distance_streamed", true)
		volume.visible = false
		add_child(volume)
		_fog_volumes.append(volume)
		fog_zone_count += 1


func _update_fog_streaming(camera: Camera3D, delta: float) -> void:
	_fog_stream_elapsed += delta
	if _fog_stream_elapsed < FOG_STREAM_REFRESH_SECONDS:
		return
	_fog_stream_elapsed = 0.0
	active_fog_volume_count = 0
	var camera_flat := Vector2(camera.global_position.x, camera.global_position.z)
	var candidates: Array[Dictionary] = []
	for volume in _fog_volumes:
		var center_flat := Vector2(volume.global_position.x, volume.global_position.z)
		var distance := camera_flat.distance_to(center_flat)
		var active := distance <= float(volume.get_meta("activation_radius", 1200.0))
		if bool(volume.get_meta("high_altitude_only", false)) and camera.global_position.y < 118.0:
			active = false
		volume.visible = false
		if active:
			candidates.append({"distance": distance, "volume": volume})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	for index in mini(candidates.size(), FOG_VOLUME_BUDGET):
		var active_volume := candidates[index]["volume"] as FogVolume
		active_volume.visible = true
		active_fog_volume_count += 1
	set_meta("active_fog_volume_count", active_fog_volume_count)
	set_meta("fog_volume_budget", FOG_VOLUME_BUDGET)


func _build_stars() -> void:
	_star_material = StandardMaterial3D.new()
	_star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_material.albedo_color = Color(0.88, 0.94, 1.0, 0.0)
	_star_material.emission_enabled = true
	_star_material.emission = Color(0.72, 0.84, 1.0)
	_star_material.emission_energy_multiplier = 1.2
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.48
	star_mesh.height = 0.96
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	star_mesh.material = _star_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = star_mesh
	multimesh.instance_count = star_count
	var random := RandomNumberGenerator.new()
	random.seed = 88421
	for index in star_count:
		var angle := random.randf_range(0.0, TAU)
		var elevation := random.randf_range(0.18, 0.96)
		var horizontal := sqrt(1.0 - elevation * elevation)
		var direction := Vector3(cos(angle) * horizontal, elevation, sin(angle) * horizontal)
		var scale_value := random.randf_range(0.55, 1.55)
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), direction * 920.0))
	stars = MultiMeshInstance3D.new()
	stars.name = "NightStars"
	stars.multimesh = multimesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.set_meta("night_only", true)
	add_child(stars)


func _build_moon() -> void:
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = moon_radius
	moon_mesh.height = moon_radius * 2.0
	moon_mesh.radial_segments = 12
	moon_mesh.rings = 6
	var shader := Shader.new()
	shader.code = MOON_SHADER
	_moon_material = ShaderMaterial.new()
	_moon_material.shader = shader
	_moon_material.set_shader_parameter("moon_texture", MOON_TEXTURE)
	moon_mesh.material = _moon_material
	moon_visual = MeshInstance3D.new()
	moon_visual.name = "LowPolyMoon"
	moon_visual.mesh = moon_mesh
	moon_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_visual.visibility_range_end = 2400.0
	moon_visual.visible = false
	moon_visual.set_meta("low_poly_moon", true)
	moon_visual.set_meta("crater_texture", MOON_TEXTURE.resource_path)
	moon_visual.set_meta("radius_metres", moon_radius)
	add_child(moon_visual)

	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	moon_light.light_color = Color(0.52, 0.66, 1.0)
	moon_light.light_energy = 0.0
	moon_light.shadow_enabled = false
	moon_light.directional_shadow_max_distance = 720.0
	moon_light.light_volumetric_fog_energy = 0.72
	moon_light.set_meta("night_only", true)
	add_child(moon_light)
