shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_tint : source_color = vec4(0.30, 0.58, 0.67, 0.72);
uniform vec4 foam_tint : source_color = vec4(0.90, 0.97, 1.0, 1.0);
uniform float flow_speed : hint_range(0.05, 2.0) = 0.72;
uniform float foam_strength : hint_range(0.0, 2.0) = 1.05;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.10;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.34;
uniform float curtain_motion : hint_range(0.0, 0.5) = 0.12;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void vertex() {
	float edge_motion = sin(UV.y * 22.0 - TIME * 2.1 + UV.x * 5.0);
	float secondary = sin(UV.y * 47.0 - TIME * 3.4 - UV.x * 9.0);
	VERTEX.z += (edge_motion * 0.65 + secondary * 0.35) * curtain_motion;
}

void fragment() {
	vec2 flowing_uv = vec2(UV.x * 7.0, UV.y * 12.0 - TIME * flow_speed);
	float broad_streams = value_noise(flowing_uv * vec2(0.42, 0.84));
	float fine_streams = value_noise(flowing_uv * vec2(1.35, 2.1) + vec2(4.7, 1.3));
	float broken_foam = smoothstep(0.48, 0.82, broad_streams * 0.68 + fine_streams * 0.52);
	float vertical_threads = pow(0.5 + 0.5 * sin(UV.x * 79.0 + fine_streams * 8.0), 7.0);
	float lower_foam = smoothstep(0.56, 1.0, UV.y) * (0.45 + fine_streams * 0.55);
	float foam = clamp((broken_foam + vertical_threads * 0.34 + lower_foam * 0.72) * foam_strength, 0.0, 1.0);
	float edge_mask = smoothstep(0.0, edge_softness, UV.x) * smoothstep(0.0, edge_softness, 1.0 - UV.x);
	float torn_edge = smoothstep(0.08, 0.34, edge_mask + broad_streams * 0.18);

	ALBEDO = mix(water_tint.rgb, foam_tint.rgb, foam);
	ROUGHNESS = mix(0.16, 0.42, foam);
	METALLIC = 0.02;
	SPECULAR = 0.86;
	EMISSION = foam_tint.rgb * foam * emission_strength;
	ALPHA = torn_edge * mix(water_tint.a, 0.94, foam);
}
