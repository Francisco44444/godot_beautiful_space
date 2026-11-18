extends RefCounted
## Corredor compartido por el trazado, la vegetación horneada y las pruebas.
const METROS := 4455.0
const PUNTOS := [
	Vector2(-100.00,-3350.00),Vector2(-157.04,-3364.96),Vector2(-212.50,-3378.42),Vector2(-272.46,-3393.96),
	Vector2(-328.82,-3410.97),Vector2(-384.38,-3434.90),Vector2(-392.23,-3481.47),Vector2(-346.33,-3523.02),
	Vector2(-295.46,-3553.05),Vector2(-238.24,-3578.01),Vector2(-181.17,-3594.79),Vector2(-124.46,-3606.50),
	Vector2(-68.86,-3614.40),Vector2(-9.89,-3619.52),Vector2(50.26,-3621.30),Vector2(109.29,-3619.27),
	Vector2(164.80,-3613.22),Vector2(220.95,-3603.56),Vector2(278.62,-3588.39),Vector2(335.00,-3568.96),
	Vector2(388.79,-3546.65),Vector2(438.63,-3522.35),Vector2(488.91,-3493.11),Vector2(536.68,-3458.46),
	Vector2(582.01,-3416.00),Vector2(618.01,-3370.63),Vector2(644.19,-3318.32),Vector2(649.62,-3263.53),
	Vector2(632.12,-3209.12),Vector2(600.05,-3156.56),Vector2(561.26,-3112.10),Vector2(513.27,-3076.98),
	Vector2(455.57,-3054.58),Vector2(399.75,-3041.04),Vector2(342.99,-3029.63),Vector2(286.18,-3021.02),
	Vector2(226.74,-3015.86),Vector2(170.72,-3013.05),Vector2(109.32,-3010.85),Vector2(50.49,-3008.70),
	Vector2(-9.99,-3006.62),Vector2(-65.62,-3005.34),Vector2(-123.14,-3005.06),Vector2(-181.97,-3004.72),
	Vector2(-241.49,-3004.27),Vector2(-303.26,-3004.55),Vector2(-359.24,-3006.09),Vector2(-416.78,-3009.67),
	Vector2(-474.66,-3015.99),Vector2(-531.48,-3025.65),Vector2(-585.86,-3038.54),Vector2(-644.03,-3054.61),
	Vector2(-701.24,-3075.46),Vector2(-757.68,-3103.05),Vector2(-811.27,-3132.87),Vector2(-861.56,-3160.78),
	Vector2(-914.40,-3184.99),Vector2(-969.71,-3195.25),Vector2(-1023.67,-3185.44),Vector2(-1076.17,-3157.88),
	Vector2(-1116.91,-3120.63),Vector2(-1137.00,-3067.98),Vector2(-1114.99,-3013.30),Vector2(-1071.97,-2974.57),
	Vector2(-1021.45,-2938.79),Vector2(-968.14,-2909.04),Vector2(-911.99,-2883.41),Vector2(-858.78,-2863.41),
	Vector2(-804.65,-2850.48),Vector2(-749.76,-2845.25),Vector2(-687.06,-2843.68),Vector2(-624.39,-2840.74),
	Vector2(-567.87,-2832.76),Vector2(-505.09,-2821.12),Vector2(-442.70,-2808.37),Vector2(-388.54,-2796.86),
	Vector2(-350.47,-2788.95),
]
static func dentro_corredor(punto: Vector2) -> bool:
	if punto.x< -1250 or punto.x>750 or punto.y< -3680 or punto.y> -2740:return false
	for i in PUNTOS.size()-1:
		if Geometry2D.get_closest_point_to_segment(punto,PUNTOS[i],PUNTOS[i+1]).distance_to(punto)<14.0:return true
	return false
