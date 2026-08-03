shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.34, 0.34, 0.76);
uniform vec4 deep_color : source_color = vec4(0.025, 0.13, 0.20, 0.88);
uniform vec4 reflected_color : source_color = vec4(0.55, 0.69, 0.76, 1.0);
uniform float wave_height : hint_range(0.0, 0.5) = 0.095;
uniform float wave_scale : hint_range(0.05, 3.0) = 0.42;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.58;
uniform float opacity : hint_range(0.1, 1.0) = 0.82;

varying vec3 world_position;
varying float wave_value;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float first_wave = sin(world_position.x * wave_scale + TIME * wave_speed);
	float second_wave = sin(world_position.z * wave_scale * 1.37 - TIME * wave_speed * 0.74);
	float detail_wave = sin((world_position.x + world_position.z) * wave_scale * 2.4 + TIME * wave_speed * 1.6);
	wave_value = first_wave * 0.46 + second_wave * 0.38 + detail_wave * 0.16;
	VERTEX.y += wave_value * wave_height;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2);
	float ripples = 0.5 + 0.5 * sin((world_position.x * 1.7 - world_position.z * 1.2) + TIME * 1.35);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, 0.46 + wave_value * 0.22);
	ALBEDO = mix(base, reflected_color.rgb, fresnel * 0.64 + ripples * 0.035);
	ROUGHNESS = mix(0.09, 0.28, ripples * 0.24);
	METALLIC = 0.06;
	SPECULAR = 0.92;
	EMISSION = shallow_color.rgb * (0.025 + fresnel * 0.045);
	ALPHA = clamp(opacity + fresnel * 0.12, 0.0, 0.96);
}
