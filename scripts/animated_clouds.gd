extends Node3D
class_name AnimatedClouds

@export var layer_count := 4
@export var cloud_altitude := 145.0
@export var wind_direction := Vector2(1.0, 0.28)
@export var wind_speed := 0.014

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 cloud_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.44, 0.51, 0.60, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.46;
uniform float softness : hint_range(0.01, 0.5) = 0.16;
uniform float speed = 0.014;
uniform vec2 wind = vec2(1.0, 0.28);
uniform float scale = 3.8;
uniform float layer_seed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.72;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amp * noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amp *= 0.5;
	}
	return value;
}

void vertex() {
	VERTEX.y += sin((VERTEX.x + TIME * 16.0 + layer_seed) * 0.010) * 2.4;
	VERTEX.y += cos((VERTEX.z - TIME * 11.0 + layer_seed) * 0.012) * 1.8;
}

void fragment() {
	vec2 uv = UV * scale + normalize(wind) * TIME * speed + vec2(layer_seed, layer_seed * 0.37);
	float body = fbm(uv);
	float detail = fbm(uv * 2.6 + vec2(TIME * speed * 0.35, -TIME * speed * 0.22));
	float cloud = smoothstep(coverage, coverage + softness, body * 0.78 + detail * 0.22);

	float edge_fade = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);
	edge_fade *= smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.72, UV.y);
	float alpha = cloud * edge_fade * opacity;

	vec3 lit_cloud = mix(shadow_color.rgb, cloud_color.rgb, clamp(body + 0.2, 0.0, 1.0));
	ALBEDO = lit_cloud;
	ALPHA = alpha;
}
"""

const SKY_DOME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 cloud_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.55, 0.62, 0.70, 1.0);
uniform float speed = 0.018;
uniform vec2 wind = vec2(1.0, 0.33);
uniform float opacity : hint_range(0.0, 1.0) = 0.78;

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 37.7);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 6; i++) {
		value += amp * noise(p);
		p = p * 2.01 + vec2(4.6, 8.3);
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 drift = normalize(wind) * TIME * speed;
	vec2 uv = vec2(UV.x * 4.0, UV.y * 2.1) + drift;
	float broad = fbm(uv);
	float torn = fbm(uv * 3.2 + vec2(TIME * speed * 0.6, -TIME * speed * 0.25));
	float cloud = smoothstep(0.50, 0.66, broad * 0.74 + torn * 0.26);
	float upper_sky = smoothstep(0.08, 0.36, UV.y) * smoothstep(0.94, 0.62, UV.y);
	float broken_horizon = smoothstep(0.18, 0.36, UV.y);
	float alpha = cloud * upper_sky * broken_horizon * opacity;
	ALBEDO = mix(shadow_color.rgb, cloud_color.rgb, clamp(broad + 0.22, 0.0, 1.0));
	ALPHA = alpha;
}
"""


func _ready() -> void:
	_rebuild_cloud_layers()


func _process(delta: float) -> void:
	for child in get_children():
		if not child.name.begins_with("HorizonCloud"):
			continue
		var speed: float = child.get_meta("drift_speed", 0.0)
		child.position.x += speed * delta
		if child.position.x > 310.0:
			child.position.x = -310.0


func _rebuild_cloud_layers() -> void:
	for child in get_children():
		child.queue_free()

	_add_sky_dome()
	_add_horizon_clouds()

	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	var normalized_wind := wind_direction.normalized()
	if normalized_wind.length() < 0.01:
		normalized_wind = Vector2.RIGHT

	for index in layer_count:
		var plane := MeshInstance3D.new()
		plane.name = "CloudLayer%02d" % (index + 1)
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plane.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

		var mesh := PlaneMesh.new()
		mesh.size = Vector2(760.0 + index * 70.0, 520.0 + index * 52.0)
		mesh.subdivide_width = 24
		mesh.subdivide_depth = 16
		plane.mesh = mesh

		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("wind", normalized_wind)
		material.set_shader_parameter("speed", wind_speed * (0.72 + index * 0.18))
		material.set_shader_parameter("scale", 3.0 + index * 0.45)
		material.set_shader_parameter("coverage", 0.42 + index * 0.035)
		material.set_shader_parameter("softness", 0.17)
		material.set_shader_parameter("opacity", 0.62 - index * 0.07)
		material.set_shader_parameter("layer_seed", float(index) * 11.7)
		plane.material_override = material

		plane.position = Vector3(-70.0 + index * 48.0, cloud_altitude + index * 13.0, -70.0 - index * 35.0)
		plane.rotation_degrees = Vector3(0.0, -18.0 + index * 9.0, 0.0)
		add_child(plane)


func _add_horizon_clouds() -> void:
	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	var normalized_wind := wind_direction.normalized()
	if normalized_wind.length() < 0.01:
		normalized_wind = Vector2.RIGHT

	for index in 9:
		var cloud := MeshInstance3D.new()
		cloud.name = "HorizonCloud%02d" % (index + 1)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

		var mesh := QuadMesh.new()
		mesh.size = Vector2(84.0 + (index % 3) * 22.0, 24.0 + (index % 4) * 5.0)
		cloud.mesh = mesh

		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("wind", normalized_wind)
		material.set_shader_parameter("speed", wind_speed * (0.9 + index * 0.08))
		material.set_shader_parameter("scale", 2.4 + (index % 3) * 0.35)
		material.set_shader_parameter("coverage", 0.34 + (index % 2) * 0.04)
		material.set_shader_parameter("softness", 0.20)
		material.set_shader_parameter("opacity", 0.82)
		material.set_shader_parameter("layer_seed", float(index) * 19.3)
		cloud.material_override = material

		cloud.position = Vector3(-280.0 + index * 70.0, 88.0 + (index % 4) * 9.0, -245.0 - (index % 3) * 28.0)
		cloud.rotation_degrees = Vector3(0.0, 0.0, -2.0 + (index % 5))
		cloud.set_meta("drift_speed", 1.2 + index * 0.17)
		add_child(cloud)


func _add_sky_dome() -> void:
	var dome := MeshInstance3D.new()
	dome.name = "MovingCloudDome"
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	var sphere := SphereMesh.new()
	sphere.radius = 560.0
	sphere.height = 1120.0
	sphere.radial_segments = 96
	sphere.rings = 48
	dome.mesh = sphere

	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SKY_DOME_SHADER
	material.shader = shader
	material.set_shader_parameter("wind", wind_direction.normalized())
	material.set_shader_parameter("speed", wind_speed * 0.85)
	dome.material_override = material
	add_child(dome)
