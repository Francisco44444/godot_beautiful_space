shader_type spatial;
render_mode cull_disabled;
uniform vec4 tela : source_color = vec4(0.15,0.37,0.40,1.0);
void vertex() {
	// Un extremo cosido al asta y el resto moviéndose con el aire del macizo.
	float libre = pow(UV.x,1.4);
	float fase = (MODEL_MATRIX[3].x+MODEL_MATRIX[3].z)*0.03;
	VERTEX.z += sin(TIME*2.4+UV.x*5.0+fase)*0.12*libre;
}
void fragment() {
	vec2 p = UV-vec2(0.5);
	float diamante = abs(p.x)*1.1+abs(p.y);
	float sello = (1.0-smoothstep(0.018,0.032,abs(diamante-0.18)));
	float cruz = (1.0-smoothstep(0.014,0.025,min(abs(p.x),abs(p.y))))*(1.0-smoothstep(0.08,0.14,length(p)));
	float ribete = 1.0-smoothstep(0.018,0.035,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
	ALBEDO = mix(tela.rgb,vec3(0.76,0.61,0.32),max(ribete,max(sello,cruz)));
	ROUGHNESS = 0.95;
}
