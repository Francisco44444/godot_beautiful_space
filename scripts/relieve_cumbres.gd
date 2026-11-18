extends RefCounted
## Un macizo ancho y continuo, sin levantar plataformas bajo la pista. El
## fundido por cota mantiene intactos el mar, las villas y los valles bajos.
static func altura_adicional(punto: Vector2, base: float) -> float:
	if punto.x< -2850 or punto.x>2650 or punto.y< -4670 or punto.y> -2030:return 0.0
	var radio := Vector2((punto.x+100.0)/1250.0,(punto.y+3350.0)/600.0).length()
	return 500.0*exp(-radio*radio*1.2)*smoothstep(150.0,350.0,base)*(1.0-smoothstep(1.6,2.2,radio))
