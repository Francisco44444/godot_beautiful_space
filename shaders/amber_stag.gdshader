shader_type spatial;
render_mode cull_disabled;
uniform sampler2D coat_texture : source_color, filter_linear_mipmap;
uniform bool textured = false;
uniform float departure = 0.0;
void vertex() {
	VERTEX += NORMAL*departure*0.08 + vec3(0.0,departure*0.45,0.0);
}
void fragment() {
	vec3 original = textured ? texture(coat_texture,UV).rgb : vec3(0.6);
	float luminance = dot(original,vec3(0.299,0.587,0.114));
	float dark = smoothstep(0.035,0.18,luminance);
	float gold = smoothstep(0.16,0.72,luminance);
	vec3 bronze = vec3(0.48,0.24,0.045);
	vec3 champagne = vec3(0.98,0.78,0.36);
	vec3 coat = mix(bronze,champagne,gold);
	ALBEDO = mix(vec3(0.018,0.012,0.008),coat,dark);
	float rim = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	EMISSION = vec3(1.0,0.72,0.24)*(0.10+rim*0.8+departure*3.0)*dark;
	METALLIC = 0.28*dark;
	ROUGHNESS = 0.43;
	SPECULAR = 0.5;
}
