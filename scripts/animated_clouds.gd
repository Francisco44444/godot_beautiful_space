extends Node3D
class_name AnimatedClouds

## Nubes altas y ligeras sobre planos sin costuras. El sistema evita una
## SphereMesh porque su unión UV producía la cuña vertical visible en el cielo.

@export_range(1, 3, 1) var layer_count := 2
@export var cloud_altitude := 220.0
@export var wind_direction := Vector2(1.0, 0.28)
@export var wind_speed := 0.008

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 cloud_color : source_color = vec4(0.98, 0.99, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.68, 0.74, 0.82, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.57;
uniform float softness : hint_range(0.01, 0.5) = 0.13;
uniform float speed = 0.008;
uniform vec2 wind = vec2(1.0, 0.28);
uniform float scale = 4.0;
uniform float layer_seed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.34;

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
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	VERTEX.y += sin((VERTEX.x + TIME * 9.0 + layer_seed) * 0.007) * 1.2;
	VERTEX.y += cos((VERTEX.z - TIME * 7.0 + layer_seed) * 0.008) * 0.9;
}

void fragment() {
	vec2 drift_a = normalize(wind) * TIME * speed;
	vec2 drift_b = vec2(-wind.y, wind.x) * TIME * speed * 0.19;
	vec2 uv = UV * scale + drift_a + vec2(layer_seed, layer_seed * 0.37);
	float warp_a = fbm(uv * 0.71 + drift_b);
	float warp_b = fbm(uv * 1.22 - drift_b * 0.7);
	vec2 warped_uv = uv + vec2(warp_a, warp_b) * 0.48;
	float broad = fbm(warped_uv);
	float detail = fbm(warped_uv * 2.4 - drift_a * 0.31);
	float cloud = smoothstep(coverage, coverage + softness, broad * 0.84 + detail * 0.16);

	float fade_x = smoothstep(0.0, 0.16, UV.x) * (1.0 - smoothstep(0.84, 1.0, UV.x));
	float fade_y = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.78, 1.0, UV.y));
	float alpha = cloud * fade_x * fade_y * opacity;
	ALBEDO = mix(shadow_color.rgb, cloud_color.rgb, clamp(broad + 0.28, 0.0, 1.0));
	ALPHA = alpha;
}
"""


func _ready() -> void:
	_rebuild_cloud_layers()


func _process(delta: float) -> void:
	# El conjunto sigue a la cámara: las capas pueden ser enormes y transparentes
	# en sus bordes sin revelar nunca un borde geométrico al recorrer el mapa.
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return
	var follow_weight := 1.0 - exp(-2.5 * delta)
	global_position.x = lerpf(global_position.x, active_camera.global_position.x, follow_weight)
	global_position.z = lerpf(global_position.z, active_camera.global_position.z, follow_weight)
	var daylight := float(get_parent().get("daylight_factor"))
	var day_color := Color(0.98, 0.99, 1.0, 1.0)
	var night_color := Color(0.11, 0.15, 0.27, 1.0)
	var day_shadow := Color(0.68, 0.74, 0.82, 1.0)
	var night_shadow := Color(0.035, 0.05, 0.12, 1.0)
	for child in get_children():
		var layer := child as MeshInstance3D
		if layer == null:
			continue
		var material := layer.material_override as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("cloud_color", night_color.lerp(day_color, daylight))
		material.set_shader_parameter("shadow_color", night_shadow.lerp(day_shadow, daylight))


func _rebuild_cloud_layers() -> void:
	for child in get_children():
		child.queue_free()

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
		plane.set_meta("seam_free_plane", true)

		var mesh := PlaneMesh.new()
		mesh.size = Vector2(1420.0 + index * 180.0, 980.0 + index * 120.0)
		mesh.subdivide_width = 32
		mesh.subdivide_depth = 24
		plane.mesh = mesh

		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("wind", normalized_wind)
		material.set_shader_parameter("speed", wind_speed * (0.86 + index * 0.13))
		material.set_shader_parameter("scale", 3.7 + index * 0.55)
		material.set_shader_parameter("coverage", 0.56 + index * 0.035)
		material.set_shader_parameter("softness", 0.13 + index * 0.015)
		material.set_shader_parameter("opacity", 0.36 - index * 0.10)
		material.set_shader_parameter("layer_seed", float(index) * 17.3)
		plane.material_override = material

		plane.position = Vector3(0.0, cloud_altitude + index * 34.0, -90.0 - index * 85.0)
		plane.rotation_degrees.y = -8.0 + index * 16.0
		add_child(plane)
