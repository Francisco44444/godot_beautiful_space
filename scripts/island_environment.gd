class_name IslandEnvironment
extends Node3D

## Mar facetado, bancos de niebla y astros low-poly sin discos procedimentales.

const WORLD_SIZE := 12000.0
const MOON_DIRECTION := Vector3(-0.42, 0.88, -0.31)
const MOON_DISTANCE := 760.0
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

// Ondas analíticas rotadas y con frecuencias no armónicas. A diferencia de
// una textura repetida, el patrón no vuelve a encajar en una cuadrícula visible
// cuando se mira el mar desde una montaña o desde el borde de la isla.
float multiscale_wave_noise(vec2 point, float time_value) {
	vec2 warped = point + vec2(
		sin(dot(point, vec2(0.0017, -0.0023)) + time_value * 0.071),
		cos(dot(point, vec2(-0.0011, 0.0019)) - time_value * 0.053)
	) * 94.0;
	float macro = sin(dot(warped, vec2(0.00371, 0.00213)) + time_value * 0.19);
	float medium = sin(dot(warped, vec2(-0.00817, 0.00529)) - time_value * 0.31);
	float detail = cos(dot(warped, vec2(0.01873, -0.01391)) + time_value * 0.47);
	return macro * 0.50 + medium * 0.32 + detail * 0.18;
}

void vertex() {
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world_vertex.xz;
	camera_distance = distance(world_vertex.xz, CAMERA_POSITION_WORLD.xz);
	float large_wave = sin(dot(world_vertex.xz, vec2(0.0117, 0.0031)) + TIME * wave_speed) * 0.66;
	large_wave += cos(dot(world_vertex.xz, vec2(-0.0049, 0.0143)) - TIME * wave_speed * 0.83) * 0.46;
	float cross_wave = multiscale_wave_noise(world_vertex.xz, TIME) * 0.48;
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
	float color_noise = multiscale_wave_noise(world_xz * 0.73 + vec2(713.0, -419.0), TIME * 0.37);
	float facet = floor(clamp(wave_height * 0.20 + color_noise * 0.10 + 0.5, 0.0, 0.999) * 6.0) / 5.0;
	float crest = smoothstep(0.78, 1.28, wave_height);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, facet);
	// La variación cromática de gran escala rompe las franjas uniformes del
	// horizonte sin perder el aspecto facetado low-poly cerca de la orilla.
	// La capa de color distante reutiliza el ruido ya calculado y solo suma una
	// onda continental: evita pagar otro bloque de trigonometría por cada píxel.
	float continent_tint = sin(dot(world_xz, vec2(0.00041, -0.00063)) + TIME * 0.025) * 0.5 + 0.5;
	float distant_variation = mix(continent_tint, color_noise * 0.5 + 0.5, 0.28);
	ALBEDO *= mix(vec3(0.88, 0.94, 1.04), vec3(1.06, 1.02, 0.92), distant_variation * 0.34);
	ALBEDO = mix(ALBEDO, foam_color.rgb, crest * 0.38);
	ALBEDO = mix(ALBEDO, horizon_color.rgb, smoothstep(7200.0, 21000.0, camera_distance));
	ROUGHNESS = 0.28;
	SPECULAR = 0.58;
	ALPHA = mix(deep_color.a, shallow_color.a, facet);
}
"""

const CASCADE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.42, 0.84, 1.0, 0.82);
uniform vec4 foam_color : source_color = vec4(0.90, 0.98, 1.0, 0.96);

void fragment() {
	float stream_a = sin(UV.y * 47.0 - TIME * 5.2 + UV.x * 7.0) * 0.5 + 0.5;
	float stream_b = sin(UV.y * 19.0 - TIME * 2.7 - UV.x * 11.0) * 0.5 + 0.5;
	float facets = floor((stream_a * 0.62 + stream_b * 0.38) * 5.0) / 4.0;
	ALBEDO = mix(water_color.rgb, foam_color.rgb, facets * 0.48);
	EMISSION = ALBEDO * 0.22;
	ALPHA = water_color.a * (0.72 + facets * 0.28);
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

const CASCADE_SEARCH_ZONES: Array[Dictionary] = [
	{"name": "Cascada de la Bruma", "center": Vector2(-2960.0, -1120.0), "radius": 760.0},
	{"name": "Cascada del Bosque Umbrio", "center": Vector2(-2700.0, 1720.0), "radius": 720.0},
]

var fog_zone_count := 0
var ocean: MeshInstance3D
var stars: MultiMeshInstance3D
var star_count := 260
var moon_visual: MeshInstance3D
var moon_light: DirectionalLight3D
var sun_source_direction := Vector3.UP
var moon_source_direction := MOON_DIRECTION.normalized()
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
var scenic_cascade_count := 0
var scenic_cascade_mist_count := 0


func _ready() -> void:
	_build_ocean()
	_build_scenic_cascades()
	_build_fog_zones()
	_build_stars()
	_build_sun()
	_build_moon()


func _process(delta: float) -> void:
	if NetworkSession.is_world_authority():
		_update_tide(delta)
	var camera := get_viewport().get_camera_3d()
	var daylight := float(get_parent().get("daylight_factor"))
	sync_celestial_sources(camera)
	if camera != null:
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


func sync_celestial_sources(camera: Camera3D = null) -> void:
	# Esta función también se llama inmediatamente desde World tras rotar el sol.
	# Así disco y luz se actualizan en la misma operación, sin depender del orden
	# de _process entre padre e hijo ni mostrar un fotograma de sombras desplazadas.
	if camera == null:
		camera = get_viewport().get_camera_3d()
	var directional_sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	sun_source_direction = Vector3.UP
	if directional_sun != null:
		# DirectionalLight emite por -Z; la fuente visible está en +Z.
		sun_source_direction = directional_sun.global_basis.z.normalized()
	# La luna ocupa una dirección angular fija durante toda la noche. No deriva
	# del ciclo solar: el disco sólo se recentra alrededor de la cámara para que
	# parezca astronómicamente lejano al recorrer la isla. Esta misma dirección
	# gobierna MoonLight y mantiene las sombras alineadas con la luna visible.
	moon_source_direction = MOON_DIRECTION.normalized()
	_update_moon_light_direction()
	if camera != null:
		if stars != null:
			stars.global_position = Vector3(camera.global_position.x, 0.0, camera.global_position.z)
		if moon_visual != null:
			moon_visual.global_position = camera.global_position + moon_source_direction * MOON_DISTANCE
		if sun_visual != null:
			# El astro queda detrás de toda la isla, no a 760 m entre montañas y
			# edificios. El radio mantiene el mismo tamaño angular que antes.
			sun_visual.global_position = camera.global_position + sun_source_direction * SUN_DISTANCE


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


func apply_network_tide_state(authoritative_phase: float) -> void:
	var previous_height := tide_height
	tide_phase = fposmod(authoritative_phase, TAU)
	tide_normalized = sin(tide_phase) * 0.5 + 0.5
	tide_height = lerpf(-2.30, 2.45, smoothstep(0.06, 0.94, tide_normalized))
	tide_rising = cos(tide_phase) > 0.0001
	tide_velocity = tide_height - previous_height
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
	ocean.set_meta("multiscale_nonrepeating_waves", true)
	ocean.set_meta("ocean_pattern", "domain-warped analytic waves at non-harmonic scales")
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


func _build_scenic_cascades() -> void:
	var terrain := get_parent().get_node_or_null("Terrain3D") as Terrain3D
	if terrain == null or terrain.data == null:
		return
	var container := Node3D.new()
	container.name = "CascadasEscenicas"
	container.set_meta("low_poly_cascades", true)
	container.set_meta("procedural_terrain_anchoring", true)
	add_child(container)
	for search_zone in CASCADE_SEARCH_ZONES:
		var descent := _find_scenic_descent(terrain, search_zone)
		if descent.is_empty():
			continue
		_add_scenic_cascade(container, String(search_zone["name"]), descent["top"], descent["bottom"])
	container.set_meta("cascade_count", scenic_cascade_count)
	container.set_meta("mist_emitter_count", scenic_cascade_mist_count)


func _find_scenic_descent(terrain: Terrain3D, search_zone: Dictionary) -> Dictionary:
	var center := search_zone["center"] as Vector2
	var radius := float(search_zone["radius"])
	var best_drop := 0.0
	var best_top := Vector3.ZERO
	var best_bottom := Vector3.ZERO
	var grid_step := 110.0
	var descent_length := 82.0
	var grid_radius := int(floor(radius / grid_step))
	for grid_x in range(-grid_radius, grid_radius + 1):
		for grid_z in range(-grid_radius, grid_radius + 1):
			var top_flat := center + Vector2(float(grid_x), float(grid_z)) * grid_step
			if top_flat.distance_to(center) > radius:
				continue
			var top_height := terrain.data.get_height(Vector3(top_flat.x, 0.0, top_flat.y))
			if is_nan(top_height) or top_height < 16.0:
				continue
			for direction_index in 12:
				var angle := TAU * float(direction_index) / 12.0
				var bottom_flat := top_flat + Vector2(cos(angle), sin(angle)) * descent_length
				var bottom_height := terrain.data.get_height(Vector3(bottom_flat.x, 0.0, bottom_flat.y))
				if is_nan(bottom_height) or bottom_height < 4.0:
					continue
				var drop := top_height - bottom_height
				if drop > best_drop:
					best_drop = drop
					best_top = Vector3(top_flat.x, top_height - 0.28, top_flat.y)
					best_bottom = Vector3(bottom_flat.x, bottom_height + 0.42, bottom_flat.y)
	# Una pendiente suave no se disfraza de cascada: solo se crea el hito donde
	# existe una pared natural suficientemente marcada en el Terrain3D.
	if best_drop < 9.0:
		return {}
	return {"top": best_top, "bottom": best_bottom, "drop": best_drop}


func _add_scenic_cascade(container: Node3D, cascade_name: String, top: Vector3, bottom: Vector3) -> void:
	var flat_direction := Vector2(bottom.x - top.x, bottom.z - top.z).normalized()
	var side := Vector2(-flat_direction.y, flat_direction.x)
	var width := clampf((top.y - bottom.y) * 0.18, 5.8, 11.0)
	var half_side := side * width * 0.5
	var vertices := PackedVector3Array([
		Vector3(top.x + half_side.x, top.y, top.z + half_side.y),
		Vector3(top.x - half_side.x, top.y, top.z - half_side.y),
		Vector3(bottom.x - half_side.x * 0.82, bottom.y, bottom.z - half_side.y * 0.82),
		Vector3(top.x + half_side.x, top.y, top.z + half_side.y),
		Vector3(bottom.x - half_side.x * 0.82, bottom.y, bottom.z - half_side.y * 0.82),
		Vector3(bottom.x + half_side.x * 0.82, bottom.y, bottom.z + half_side.y * 0.82),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
		Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var cascade_mesh := ArrayMesh.new()
	cascade_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = CASCADE_SHADER
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	cascade_mesh.surface_set_material(0, water_material)
	var sheet := MeshInstance3D.new()
	sheet.name = cascade_name.validate_node_name()
	sheet.mesh = cascade_mesh
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.visibility_range_end = 3100.0
	sheet.set_meta("low_poly_water_ribbon", true)
	sheet.set_meta("terrain_drop_metres", top.y - bottom.y)
	container.add_child(sheet)

	var foam_material := StandardMaterial3D.new()
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.albedo_color = Color(0.72, 0.93, 1.0, 0.76)
	foam_material.emission_enabled = true
	foam_material.emission = Color(0.34, 0.72, 0.92)
	foam_material.emission_energy_multiplier = 0.38
	var foam_mesh := SphereMesh.new()
	foam_mesh.radius = width * 0.56
	foam_mesh.height = width * 0.34
	foam_mesh.radial_segments = 10
	foam_mesh.rings = 4
	foam_mesh.material = foam_material
	var foam := MeshInstance3D.new()
	foam.name = "Espuma"
	foam.mesh = foam_mesh
	foam.position = bottom + Vector3(0.0, 0.18, 0.0)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.visibility_range_end = 2500.0
	foam.set_meta("impact_foam", true)
	container.add_child(foam)

	var mist := GPUParticles3D.new()
	mist.name = "BrumaDeAgua"
	mist.position = bottom + Vector3(0.0, 1.2, 0.0)
	mist.amount = 22
	mist.lifetime = 2.6
	mist.randomness = 0.72
	mist.visibility_range_end = 1800.0
	mist.visibility_aabb = AABB(Vector3(-12.0, -3.0, -12.0), Vector3(24.0, 18.0, 24.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(width * 0.42, 0.35, width * 0.24)
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 48.0
	process_material.initial_velocity_min = 1.1
	process_material.initial_velocity_max = 3.4
	process_material.gravity = Vector3(0.0, 0.24, 0.0)
	process_material.scale_min = 1.4
	process_material.scale_max = 3.6
	mist.process_material = process_material
	var mist_material := StandardMaterial3D.new()
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist_material.albedo_color = Color(0.72, 0.91, 1.0, 0.28)
	var mist_quad := QuadMesh.new()
	mist_quad.size = Vector2(1.4, 1.4)
	mist_quad.material = mist_material
	mist.draw_pass_1 = mist_quad
	mist.set_meta("waterfall_mist", true)
	container.add_child(mist)
	scenic_cascade_count += 1
	scenic_cascade_mist_count += 1


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
	moon_visual.set_meta("fixed_sky_direction", true)
	add_child(moon_visual)

	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.52, 0.66, 1.0)
	moon_light.light_energy = 0.0
	moon_light.shadow_enabled = false
	moon_light.directional_shadow_max_distance = 720.0
	moon_light.light_volumetric_fog_energy = 0.72
	moon_light.set_meta("night_only", true)
	moon_light.set_meta("aligned_with_visible_moon", true)
	add_child(moon_light)
	_update_moon_light_direction()


func _update_moon_light_direction() -> void:
	if moon_light == null:
		return
	var source := moon_source_direction.normalized()
	var up := Vector3.UP
	if absf(source.dot(up)) > 0.965:
		up = Vector3.FORWARD
	# Basis.looking_at orienta -Z hacia el objetivo; mirar a -source hace que +Z,
	# la dirección aparente de la fuente de DirectionalLight, coincida con la luna.
	moon_light.basis = Basis.looking_at(-source, up)
	moon_light.set_meta("source_direction", source)


func get_moon_alignment_error_degrees() -> float:
	if moon_light == null:
		return 180.0
	return rad_to_deg(acos(clampf(moon_light.global_basis.z.normalized().dot(moon_source_direction.normalized()), -1.0, 1.0)))
