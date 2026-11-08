shader_type spatial;
// En espacio de VISTA (`skip_vertex_transform`): el cuadro siempre mira a la cámara.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

// UNA LUCIÉRNAGA (`VidaMenuda`): un punto de luz verde amarillenta que se enciende y se
// apaga a su ritmo y deriva despacio. Todo aquí: la CPU sólo recoloca el enjambre
// alrededor del jugador cada pocos segundos.
//
// INSTANCE_CUSTOM: x fase, y periodo del parpadeo (s), z cuánto deriva (m), w tamaño.
// Sin niebla: de noche en el bosque la niebla se las comía a veinte metros.

uniform vec3 color : source_color = vec3(0.78, 1.0, 0.36);
uniform float brillo = 3.0;
uniform float rise = 0.0;

varying float v_pulso;

void vertex() {
	float fase = INSTANCE_CUSTOM.x;
	float deriva = INSTANCE_CUSTOM.z;
	vec3 centro = MODEL_MATRIX[3].xyz + vec3(
		sin(TIME * 0.31 + fase * 1.7) + 0.4 * sin(TIME * 0.83 + fase * 3.1),
		0.45 * sin(TIME * 0.47 + fase * 2.3),
		cos(TIME * 0.27 + fase * 2.9) + 0.4 * cos(TIME * 0.71 + fase * 1.3)) * deriva;
	// Encendida un rato corto de cada periodo, con subida y bajada suaves: el destello
	// de una luciérnaga, no un intermitente.
	float t = fract(TIME / INSTANCE_CUSTOM.y + fase * 0.159);
	v_pulso = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.18, 0.42, t));
	float lado = INSTANCE_CUSTOM.w;
	centro.y += fract(TIME*0.08+fase*0.159)*rise;
	vec3 vista = (VIEW_MATRIX * vec4(centro, 1.0)).xyz;
	VERTEX = vista + vec3(VERTEX.x, VERTEX.y, 0.0) * lado;
	// Apagada del todo (escala cero en `VidaMenuda._apagar`): colapsa a un punto.
	if (length(MODEL_MATRIX[0].xyz) < 0.001) {
		VERTEX = vista;
	}
}

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r2 = dot(d, d);
	float nucleo = exp(-r2 * 26.0);
	float halo = exp(-r2 * 4.0) * 0.35;
	ALBEDO = (color * (nucleo * 1.4 + halo) + vec3(1.0, 1.0, 0.85) * nucleo * 0.6) * brillo * v_pulso;
}
