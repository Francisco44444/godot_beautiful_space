class_name IslandEnvironment
extends Node3D

## Mar facetado, bancos de niebla y astros low-poly sin discos procedimentales.

const WORLD_SIZE := 10000.0
const MOON_DIRECTION := Vector3(-0.58, 0.69, -0.43)
const MOON_TEXTURE: Texture2D = preload("res://assets/textures/moon/moon_craters_lowpoly.png")
const OCEAN_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.58, 0.72, 0.84);
uniform vec4 deep_color : source_color = vec4(0.025, 0.20, 0.43, 0.94);
uniform vec4 foam_color : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform float wave_speed = 0.34;

varying float wave_height;

void vertex() {
	float large_wave = sin(VERTEX.x * 0.012 + TIME * wave_speed) * 0.75;
	large_wave += cos(VERTEX.z * 0.016 - TIME * wave_speed * 0.83) * 0.52;
	float cross_wave = sin((VERTEX.x + VERTEX.z) * 0.021 + TIME * 0.41) * 0.22;
	wave_height = large_wave + cross_wave;
	VERTEX.y += wave_height;
}

void fragment() {
	float facet = floor(clamp(wave_height * 0.22 + 0.5, 0.0, 0.999) * 5.0) / 4.0;
	float crest = smoothstep(0.78, 1.28, wave_height);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, facet);
	ALBEDO = mix(ALBEDO, foam_color.rgb, crest * 0.38);
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
	{"name": "BosqueUmbrio", "center": Vector3(-2180, 26, 1650), "size": Vector3(1050, 64, 920), "color": Color(0.25, 0.34, 0.31, 1), "density": 0.032},
	{"name": "AldeaBruma", "center": Vector3(-2200, 24, -900), "size": Vector3(980, 58, 860), "color": Color(0.42, 0.48, 0.56, 1), "density": 0.026},
	{"name": "PinarNorte", "center": Vector3(520, 92, -2650), "size": Vector3(1180, 92, 820), "color": Color(0.52, 0.59, 0.68, 1), "density": 0.019},
]

var fog_zone_count := 0
var ocean: MeshInstance3D
var stars: MultiMeshInstance3D
var star_count := 260
var moon_visual: MeshInstance3D
var moon_light: DirectionalLight3D
var moon_radius := 88.0
var sun_visual: MeshInstance3D
var sun_radius := 46.0
var _star_material: StandardMaterial3D
var _moon_material: ShaderMaterial
var _sun_material: ShaderMaterial


func _ready() -> void:
	_build_ocean()
	_build_fog_zones()
	_build_stars()
	_build_sun()
	_build_moon()


func _process(_delta: float) -> void:
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
			sun_visual.global_position = camera.global_position + sun_source_direction * 760.0
	if sun_visual != null:
		# Es una geometría opaca que desaparece completamente de noche: no deja
		# el punto negro que provocaba el disco procedural dentro de la niebla.
		sun_visual.visible = camera != null and daylight > 0.12 and sun_source_direction.y > -0.02
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
	sun_visual.visibility_range_end = 2400.0
	sun_visual.visible = false
	sun_visual.set_meta("low_poly_sun", true)
	sun_visual.set_meta("opaque_sun", true)
	sun_visual.set_meta("radius_metres", sun_radius)
	add_child(sun_visual)


func _build_ocean() -> void:
	ocean = MeshInstance3D.new()
	ocean.name = "LowPolyOcean"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WORLD_SIZE * 1.34, WORLD_SIZE * 1.34)
	mesh.subdivide_width = 144
	mesh.subdivide_depth = 144
	ocean.mesh = mesh
	ocean.position.y = -0.55
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.visibility_range_end = 16000.0
	ocean.set_meta("low_poly_waves", true)
	var shader := Shader.new()
	shader.code = OCEAN_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	ocean.material_override = material
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
		add_child(volume)
		fog_zone_count += 1


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
