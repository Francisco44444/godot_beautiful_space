shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_prepass_alpha;

uniform sampler2D foliage_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 ambient_tint : source_color = vec3(0.74, 0.82, 0.72);

varying float instance_tint;


void vertex() {
	instance_tint = INSTANCE_CUSTOM.r;
	VERTEX.x += sin(TIME * 0.65 + MODEL_MATRIX[3].x * 0.09 + MODEL_MATRIX[3].z * 0.07) * UV.y * 0.035;
}


void fragment() {
	vec4 foliage = texture(foliage_texture, UV);
	ALBEDO = foliage.rgb * ambient_tint * instance_tint;
	ALPHA = foliage.a;
	ALPHA_SCISSOR_THRESHOLD = 0.16;
	ROUGHNESS = 0.92;
}
