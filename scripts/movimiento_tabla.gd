extends RefCounted
## El canto tarda en entrar: virar conserva inercia. Agacharse reduce el arrastre
## real y sacrifica giro, en vez de limitarse a cambiar el número del velocímetro.
var rumbo := 0.0
var rapidez := 5.0
var en_salto := false
var agachado := 0.0
var inclinacion := 0.0
var pendiente := 0.0
var compresion := 0.0
var _giro := 0.0
var _caida := 0.0
var _angulo_tabla := 0.0

func avanzar(jugador: CharacterBody3D, terreno: Node, delta: float, entrada: Vector2, saltar: bool, agacharse: bool = false) -> void:
	agachado = lerpf(agachado,1.0 if agacharse else 0.0,1.0-exp(-9.0*delta))
	_giro = lerpf(_giro,-entrada.x,1.0-exp(-7.0*delta))
	var en_suelo := jugador.is_on_floor()
	rumbo += _giro*lerpf(1.8,1.2,agachado)*(1.0 if en_suelo else 0.62)*delta
	var direccion := Vector3(-sin(rumbo),0,-cos(rumbo))
	var a: float = terreno.data.get_height(jugador.global_position+direccion*1.2)
	var b: float = terreno.data.get_height(jugador.global_position-direccion*1.2)
	pendiente = clampf((a-b)/2.4,-0.8,0.8) if is_finite(a) and is_finite(b) else 0.0
	var impulso := (8.0 if rapidez<5.0 else 4.6) if entrada.y< -0.1 else 0.0
	var freno := 17.0 if entrada.y>0.1 else 0.8+rapidez*rapidez*lerpf(0.009,0.0028,agachado)
	var perdida_canto := absf(_giro)*rapidez*0.045 if en_suelo else 0.0
	if en_suelo:rapidez = clampf(rapidez+(impulso-pendiente*24.0-freno-perdida_canto)*delta,0,lerpf(30.0,38.0,agachado))
	compresion = move_toward(compresion,0.0,delta*2.8)
	if en_suelo:
		if en_salto:compresion = clampf(_caida/12.0,0.0,1.0)
		en_salto = false;_caida = 0.0
	else:
		en_salto = true;_caida = maxf(_caida,-jugador.velocity.y)
	jugador.floor_snap_length = 1.1 if not en_salto else 0.0
	var horizontal := Vector2(jugador.velocity.x,jugador.velocity.z)
	horizontal = horizontal.lerp(Vector2(direccion.x,direccion.z)*rapidez,1.0-exp(-(9.0 if en_suelo else 3.6)*delta))
	jugador.velocity.x = horizontal.x;jugador.velocity.z = horizontal.y
	var inclinacion_suelo := pendiente
	if saltar and en_suelo:
		jugador.velocity.y = 6.2+agachado*2.4;en_salto = true;jugador.floor_snap_length = 0
	elif en_suelo:
		var normal := jugador.get_floor_normal()
		inclinacion_suelo = clampf(-(normal.x*direccion.x+normal.z*direccion.z)/maxf(normal.y,0.15),-0.85,0.85)
		jugador.velocity.y = inclinacion_suelo*rapidez-1.0
	else:jugador.velocity.y -= 17.0*delta
	jugador.move_and_slide()
	if jugador.is_on_wall():rapidez = minf(rapidez,Vector2(jugador.velocity.x,jugador.velocity.z).length())
	inclinacion = lerpf(inclinacion,_giro*clampf(rapidez/24.0,0,1)*0.62,1.0-exp(-8.0*delta))
	var angulo_objetivo := atan(inclinacion_suelo) if en_suelo else atan2(jugador.velocity.y,maxf(rapidez,1.0))
	_angulo_tabla = lerpf(_angulo_tabla,clampf(angulo_objetivo,-0.7,0.7),1.0-exp(-12.0*delta))
	jugador.postura_nieve = Vector3(clampf(agachado+compresion*0.65,0,1),inclinacion,_angulo_tabla)
	jugador.visual.rotation = Vector3(jugador.postura_nieve.z,rumbo,inclinacion*0.25)
