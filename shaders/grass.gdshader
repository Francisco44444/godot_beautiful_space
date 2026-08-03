shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 dry_color : source_color = vec3(0.28, 0.29, 0.12);
uniform vec3 fresh_color : source_color = vec3(0.16, 0.27, 0.09);
uniform float wind_strength = 0.11;

varying float instance_tint;


void vertex() {
	instance_tint = INSTANCE_CUSTOM.r;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.35 + world_position.x * 0.07 + world_position.z * 0.05);
	// UV.y vale 0 en la base y 1 en la punta, por lo que la raíz queda fija.
	VERTEX.x += gust * wind_strength * UV.y;
	VERTEX.z += cos(TIME * 0.82 + world_position.z * 0.06) * wind_strength * 0.45 * UV.y;
}


void fragment() {
	float blade_gradient = smoothstep(0.0, 1.0, UV.y);
	ALBEDO = mix(dry_color, fresh_color, blade_gradient) * instance_tint;
	ROUGHNESS = 0.96;
}
