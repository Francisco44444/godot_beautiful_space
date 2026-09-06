class_name DesertBreeze
extends Node3D

## Rachas de polvo del desierto. De vez en cuando pasa una brisa que arrastra
## arena a ras de suelo alrededor del héroe, y entre racha y racha no hay nada:
## una nube permanente se leería como niebla, no como viento.
##
## No escribe el viento de la vegetación (`set_storm_strength`): ese canal lo
## gobierna la tormenta de la fuerza especial y compartirlo acabaría en el mismo
## enredo que tuvo el sol con el ciclo día/noche, donde cada uno pisaba al otro.
## Aquí solo hay polvo.

## Cada cuánto pasa una racha, con su margen de variación.
@export var gust_interval: float = 11.0
@export var gust_interval_jitter: float = 5.0
## Cuánto dura, contando la entrada y la salida.
@export var gust_duration: float = 4.2
## Velocidad del arrastre y ancho de la cortina de polvo.
@export var gust_speed: float = 6.4
@export var gust_span: float = 34.0
@export var dust_amount: int = 340

var _dust: GPUParticles3D
var _dust_process: ParticleProcessMaterial
var _player: Node3D
var _vegetation: Node
var _wait := 3.0
var _gust_time := 0.0
var _strength := 0.0
var _wind := Vector3(0.84, 0.0, 0.54)
var _biome := ""
var _gusts_started := 0


func bind(world: Node) -> void:
	_player = world.get_node_or_null("Player") as Node3D
	_vegetation = world.get_node_or_null("VegetationScatter")
	_build_dust()
	_wait = randf_range(1.5, gust_interval)


func is_gusting() -> bool:
	return _gust_time > 0.0


func get_strength() -> float:
	return _strength


func get_biome() -> String:
	return _biome


func get_gust_count() -> int:
	return _gusts_started


func get_wind_direction() -> Vector3:
	return _wind


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or _dust == null:
		return
	_biome = _resolve_biome()
	if _biome != "desert":
		# Fuera del desierto no hay polvo que levantar: se corta la racha en
		# curso y el contador espera a la siguiente entrada.
		_gust_time = 0.0
		_strength = 0.0
		_dust.emitting = false
		return
	if _gust_time > 0.0:
		_gust_time = maxf(_gust_time - delta, 0.0)
		# Campana: la racha entra, arrecia y se va, sin cortes.
		var progress := 1.0 - _gust_time / maxf(gust_duration, 0.1)
		_strength = sin(clampf(progress, 0.0, 1.0) * PI)
		if _gust_time <= 0.0:
			_wait = maxf(gust_interval + randf_range(-gust_interval_jitter, gust_interval_jitter), 2.0)
	else:
		_strength = 0.0
		_wait = maxf(_wait - delta, 0.0)
		if _wait <= 0.0:
			_start_gust()
	_dust.global_position = _player.global_position
	_dust.emitting = _strength > 0.02
	_dust.amount_ratio = clampf(_strength, 0.05, 1.0)
	if _dust_process != null:
		_dust_process.direction = _wind
		_dust_process.initial_velocity_min = gust_speed * 0.55 * _strength
		_dust_process.initial_velocity_max = gust_speed * _strength


func _start_gust() -> void:
	_gust_time = gust_duration
	_gusts_started += 1
	# Cada racha llega de un lado distinto, pero siempre horizontal: el polvo se
	# arrastra, no cae ni sube.
	var angle := randf_range(0.0, TAU)
	_wind = Vector3(cos(angle), 0.0, sin(angle))


func _resolve_biome() -> String:
	if _vegetation != null and _vegetation.has_method("biome_at"):
		return String(_vegetation.call("biome_at", _player.global_position))
	return ""


func _soft_mote_texture() -> Texture2D:
	## Mota redonda y difusa: blanca en el centro y transparente en el borde.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.62))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "DesertDust"
	_dust.top_level = true
	_dust.amount = dust_amount
	_dust.lifetime = 3.4
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(
		Vector3(-gust_span, -4.0, -gust_span),
		Vector3(gust_span * 2.0, 14.0, gust_span * 2.0)
	)
	_dust_process = ParticleProcessMaterial.new()
	# Caja ancha y baja centrada en el héroe: el polvo cruza por delante y por
	# los lados, que es como se ve pasar una brisa.
	_dust_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Algo de altura: parte del polvo cruza recortado contra el cielo, que es
	# donde más se nota que pasa una racha.
	_dust_process.emission_box_extents = Vector3(gust_span * 0.5, 2.1, gust_span * 0.5)
	_dust_process.direction = _wind
	_dust_process.spread = 16.0
	_dust_process.flatness = 0.85
	_dust_process.gravity = Vector3(0.0, 0.28, 0.0)
	_dust_process.initial_velocity_min = 3.4
	_dust_process.initial_velocity_max = 6.4
	_dust_process.damping_min = 0.4
	_dust_process.damping_max = 1.1
	_dust_process.angular_velocity_min = -40.0
	_dust_process.angular_velocity_max = 40.0
	_dust_process.scale_min = 1.6
	_dust_process.scale_max = 4.8
	# Polvo CLARO, no del color de la arena: del tono del suelo no se distinguía
	# nada sobre las dunas. Un velo pálido se lee tanto contra la arena como
	# contra el cielo.
	_dust_process.color = Color(0.98, 0.94, 0.86, 0.52)
	# Se desvanece al final de su vida en vez de desaparecer de golpe.
	var fade := Gradient.new()
	fade.set_color(0, Color(0.98, 0.94, 0.86, 0.0))
	fade.set_color(1, Color(1.0, 0.97, 0.90, 0.0))
	fade.add_point(0.20, Color(0.99, 0.95, 0.88, 0.60))
	fade.add_point(0.68, Color(0.99, 0.95, 0.88, 0.44))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_dust_process.color_ramp = ramp
	_dust.process_material = _dust_process
	var mote := QuadMesh.new()
	# Motas grandes: el polvo se lee como vedijas que cruzan, no como chispas.
	mote.size = Vector2(1.15, 0.72)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.99, 0.95, 0.88, 0.42)
	material.vertex_color_use_as_albedo = true
	# Sin textura, cada partícula es un rectángulo de bordes duros y el polvo se
	# leía como un puñado de cartas volando. Este degradado radial la convierte
	# en una mota difusa.
	material.albedo_texture = _soft_mote_texture()
	mote.material = material
	_dust.draw_pass_1 = mote
	_dust.emitting = false
	add_child(_dust)
