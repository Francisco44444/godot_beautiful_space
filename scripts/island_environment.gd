class_name IslandEnvironment
extends Node3D

## Mar facetado animado y bancos de niebla locales para los bosques aislados.

const WORLD_SIZE := 10000.0
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

const FOG_ZONES: Array = [
	{"name": "BosqueUmbrio", "center": Vector3(-2180, 26, 1650), "size": Vector3(1050, 64, 920), "color": Color(0.25, 0.34, 0.31, 1), "density": 0.032},
	{"name": "AldeaBruma", "center": Vector3(-2200, 24, -900), "size": Vector3(980, 58, 860), "color": Color(0.42, 0.48, 0.56, 1), "density": 0.026},
	{"name": "PinarNorte", "center": Vector3(520, 92, -2650), "size": Vector3(1180, 92, 820), "color": Color(0.52, 0.59, 0.68, 1), "density": 0.019},
]

var fog_zone_count := 0
var ocean: MeshInstance3D
var stars: MultiMeshInstance3D
var star_count := 260
var _star_material: StandardMaterial3D


func _ready() -> void:
	_build_ocean()
	_build_fog_zones()
	_build_stars()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and stars != null:
		stars.global_position = Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	var daylight := float(get_parent().get("daylight_factor"))
	var night := 1.0 - smoothstep(0.08, 0.34, daylight)
	if _star_material != null:
		_star_material.albedo_color = Color(0.88, 0.94, 1.0, night)
		_star_material.emission_energy_multiplier = 1.2 + night * 2.6


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
