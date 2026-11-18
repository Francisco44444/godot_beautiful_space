shader_type canvas_item;
// La misma óptica periférica de la moto de Sables. El centro no se desplaza;
// cinco muestras radiales estiran los laterales, sin desenfocar la interfaz.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensidad = 0.0;
uniform vec2 centro = vec2(0.5, 0.46);
void fragment() {
	vec2 d = SCREEN_UV - centro;
	vec2 proporcion = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float radio = length(d * proporcion);
	float borde = smoothstep(0.32, 0.88, radio) * intensidad;
	vec3 color = texture(pantalla, SCREEN_UV).rgb * 0.40;
	for (int i = 1; i <= 4; i++) {
		color += texture(pantalla, SCREEN_UV - d * float(i) * borde * 0.021).rgb * 0.15;
	}
	float angulo = atan(d.y, d.x * proporcion.x + 0.00001);
	float sector = floor((angulo + 3.141593) * 37.0);
	float semilla = fract(sin(sector * 91.17) * 43758.54);
	float linea = pow(max(0.0, cos(angulo * 104.0)), 28.0);
	float viaje = fract(radio * 1.5 - TIME * (3.0 + semilla) + semilla * 8.0);
	float raya = smoothstep(0.64, 0.80, viaje) * (1.0 - smoothstep(0.86, 1.0, viaje));
	color += vec3(0.64, 0.82, 0.89) * linea * raya * borde * 0.32;
	COLOR = vec4(color, 1.0);
}
