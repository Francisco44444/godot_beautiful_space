class_name RPGArenaHazard
extends Node3D

## El sitio pelea contigo. Cada arena tenía carácter sólo en el decorado: las
## raíces se cerraban sobre ti, la bruma hablaba, el observatorio estaba helado
## —y nada de eso te tocaba. Aquí cada una castiga una postura distinta y ofrece
## un refugio distinto, así que aprender el sitio es parte de ganar al jefe.
##
##   RAICES        las esporas suben fuera de la losa · refugio: la piedra
##   PIEDRAS       la bruma muerde en campo abierto · refugio: junto a un menhir
##   OBSERVATORIO  el frío agarra a quien se para · refugio: moverse
##   SOLAR         el sol quema fuera de la sombra · refugio: junto a una columna
##   ECO           el eco te vacía sin piedra detrás · refugio: junto a un muro

const TICK := 1.15
const SHELTER_REACH := 5.0
## Bajo esta velocidad se considera que estás quieto (m/s).
const STILL := 2.0

@export var style := "raices"
@export var centre := Vector2.ZERO
@export var radius := 18.0
@export var floor_radius := 13.0
## Arrancan en los valores de arriba y el jefe los va apretando por fases.
var shelter_reach := SHELTER_REACH
var still_speed := STILL

var shelters: PackedVector2Array = PackedVector2Array()
var boss: Node = null
var story_runtime: Node = null
var bites := 0
var _left := TICK
var _player: Node3D = null
var arena: Node = null
var tightenings := 0


func _physics_process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	# Sólo mientras el jefe esté despierto: el sitio no castiga a quien pasa.
	if bool(boss.get("dead")) or bool(boss.get("sealed")):
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("local_player") as Node3D
		if _player == null:
			return
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	if here.distance_to(centre) > radius:
		_left = TICK
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = TICK
	if sheltered(here):
		return
	bite()


## El jefe cierra el sitio. Cada fase quita una salida, así que la última parte
## del combate se pelea en el espacio que él te ha dejado y no en el que había.
## Sin esto, jefe y escenario peleaban por separado.
func tighten() -> String:
	tightenings += 1
	match style:
		"raices":
			# La losa se agrieta: el suelo limpio mengua.
			floor_radius = maxf(4.5, floor_radius - 2.8)
			_flash(centre)
			return "La losa se agrieta · queda menos piedra limpia"
		"observatorio":
			# El hielo se extiende: hay que moverse más deprisa para no cuajarse.
			still_speed += 1.1
			_flash(centre)
			return "El hielo gana terreno · muévete más deprisa"
		"eco":
			shelter_reach = maxf(2.2, shelter_reach - 0.9)
			_flash(centre)
			return "El eco se ensancha · los muros cobijan menos"
		_:
			var lost := _topple_nearest()
			if lost == Vector2.ZERO:
				shelter_reach = maxf(2.2, shelter_reach - 0.9)
				return "El sitio se cierra"
			_flash(lost)
			return "Cae un refugio · queda uno menos"


## Derriba el refugio más cercano al jefe: se lleva por delante lo que tiene al
## lado, que es lo que hace que la fase se vea y no sólo se sufra.
func _topple_nearest() -> Vector2:
	if arena == null or shelters.is_empty():
		return Vector2.ZERO
	var anchor := centre
	if boss != null and boss is Node3D:
		anchor = Vector2((boss as Node3D).global_position.x, (boss as Node3D).global_position.z)
	var best := 0
	var span := 1e9
	for index in shelters.size():
		var distance := anchor.distance_to(shelters[index])
		if distance < span:
			span = distance
			best = index
	var gone: Vector2 = arena.call("topple_shelter", best)
	shelters = arena.get("shelter_points")
	return gone


func _flash(point: Vector2) -> void:
	if story_runtime == null:
		return
	story_runtime.call("burst_sparks", Vector3(point.x, global_position.y + 1.6, point.y),
		_tint(), 40, 8.4, 0.7)
	story_runtime.call("shake_camera", Vector3(point.x, global_position.y, point.y), 0.34, 70.0)


## Si esto devuelve true el sitio te deja en paz. Es la regla que hay que
## aprender en cada arena.
func sheltered(here: Vector2) -> bool:
	match style:
		"raices":
			return here.distance_to(centre) <= floor_radius
		"observatorio":
			var speed := 0.0
			if _player != null and "velocity" in _player:
				var motion: Vector3 = _player.get("velocity")
				speed = Vector2(motion.x, motion.z).length()
			return speed >= still_speed
		_:
			for stone in shelters:
				if here.distance_to(stone) <= shelter_reach:
					return true
			return false


func bite() -> void:
	bites += 1
	if story_runtime == null:
		return
	var hurt := int(_hurt())
	var drain := float(_drain())
	if _player != null and bites == 1:
		# La regla, una vez, la primera. Un sitio que te castiga sin decir por
		# qué no enseña nada: parece una avería del juego.
		_player.action_feedback.emit(_rule())
	if hurt > 0:
		# El nombre corto, porque quien lo recibe compone «X te hiere · vida...»
		story_runtime.call("damage_player", hurt, global_position, _source())
	elif _player != null and bites > 1:
		_player.action_feedback.emit(_rule())
	if drain > 0.0 and _player != null and _player.has_method("_spend_stamina"):
		_player.call("_spend_stamina", drain)
	story_runtime.call("burst_sparks", global_position, _tint(), 18, 4.6, 0.5)


func _hurt() -> int:
	match style:
		"piedras": return 4
		"solar": return 5
		"eco": return 5
		_: return 0


func _drain() -> float:
	match style:
		"raices": return 13.0
		"observatorio": return 15.0
		"eco": return 9.0
		_: return 0.0


func _rule() -> String:
	match style:
		"piedras": return "La bruma muerde donde no hay piedra · pégate a un menhir"
		"observatorio": return "El frío se agarra a quien se para · no dejes de moverte"
		"solar": return "El sol quema fuera de la sombra · busca una columna"
		"eco": return "El eco te vacía sin piedra detrás · pégate a un muro"
		_: return "Las esporas pesan fuera de la losa · vuelve a la piedra"


func _source() -> String:
	match style:
		"piedras": return "La bruma"
		"observatorio": return "El frío"
		"solar": return "El sol de la arena"
		"eco": return "El eco de la nave"
		_: return "Las esporas"


func _tint() -> Color:
	match style:
		"piedras": return Color(0.72, 0.80, 0.92)
		"observatorio": return Color(0.80, 0.92, 1.0)
		"solar": return Color(1.0, 0.83, 0.42)
		"eco": return Color(0.62, 0.55, 0.74)
		_: return Color(0.68, 0.86, 0.48)
