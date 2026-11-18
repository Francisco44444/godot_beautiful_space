extends RefCounted
## Un macizo ancho y continuo, sin levantar plataformas bajo la pista. El
## fundido por cota mantiene intactos el mar, las villas y los valles bajos.
static func altura_adicional(punto: Vector2, base: float) -> float:
	if punto.x< -2850 or punto.x>2650 or punto.y< -4670 or punto.y> -2030:return 0.0
	var radio := Vector2((punto.x+100.0)/1250.0,(punto.y+3350.0)/600.0).length()
	return 500.0*exp(-radio*radio*1.2)*smoothstep(150.0,350.0,base)*(1.0-smoothstep(1.6,2.2,radio))


static func adaptar_guardado(posicion: Variant, terreno: Terrain3D) -> Variant:
	if not posicion is Array or posicion.size() != 3:
		return posicion
	var punto := Vector3(float(posicion[0]), float(posicion[1]), float(posicion[2]))
	if not punto.is_finite() or altura_adicional(Vector2(punto.x, punto.z), punto.y) < 1.0:
		return posicion
	var suelo := terreno.data.get_height(punto)
	if not is_finite(suelo):
		# La antigua coordenada puede coincidir con un hueco de la portada.
		# El rellano de salida ofrece suelo sólido en la misma cordillera.
		var salida: Vector2 = preload("res://scripts/ruta_nieve.gd").PUNTOS[0]
		punto = Vector3(salida.x, punto.y, salida.y)
		suelo = terreno.data.get_height(punto)
	if is_finite(suelo) and suelo > punto.y + 1.0:
		return [punto.x, suelo + 0.18, punto.z]
	return posicion
