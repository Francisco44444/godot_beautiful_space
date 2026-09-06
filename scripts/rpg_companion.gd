class_name RPGCompanion
extends StaticBody3D

## Alguien que se viene contigo.
##
## Hasta ahora la isla estaba llena de gente que hablaba y ninguna que peleara a
## tu lado. Un compañero cambia el combate de sitio: deja de ser tú contra una
## guarida entera y pasa a ser dos frentes, y eso importa sobre todo en los
## jefes, donde tener a alguien que le quite la vista de encima un segundo es la
## diferencia entre entrar y no entrar.
##
## NO usa gravedad, por lo mismo que los enemigos y los vecinos: Terrain3D sólo
## genera colisión de suelo cerca del héroe y un compañero con física se cae al
## vacío en cuanto te alejas del punto de partida.
##
## Cada uno pelea como es: Brenn dispara de lejos, Calen aguanta delante, Tavia
## cura, Orin pega fuerte y despacio. No es un modificador de daño con nombre:
## es una manera distinta de resolver una pelea.

signal companion_downed(companion_id: String)
signal companion_spoke(line: String)

enum Craft { ARCHER, SHIELD, HEALER, HAMMER }

## Un compañero no camina contigo: está en lo suyo hasta que lo llamas. Y sólo
## acude si hay pelea, igual que el caballo sólo viene si estás a pie. Llega
## cruzando el horizonte, no aparece de la nada a tu lado.
enum Duty { AWAY, ARRIVING, MUSTERED }

## A cuánto se mantiene del héroe cuando no hay nada que hacer.
const FOLLOW_NEAR := 4.2
const FOLLOW_FAR := 8.0
## Más allá de esto se teletransporta detrás de ti: perder al compañero en un
## bosque porque se quedó atascado en una piedra no es una mecánica, es un fallo.
const LEASH := 46.0
const SPEAK_GAP := 26.0
## Medido contra el caballo (summon_horizon_distance 58 m): a esa distancia se
## ve la silueta llegar sin que parezca un teletransporte.
const HORIZON := 58.0
const ARRIVE_SPEED := 13.5
const MUSTER_TIME := 80.0
const MUSTER_FLOOR := 14.0
const CALL_COOLDOWN := 35.0

@export var companion_id := "brenn"
@export var display_name := "Brenn"
@export var craft := Craft.ARCHER
@export var character_file := "Cowboy_Male.gltf"
@export var max_health := 60
@export var move_speed := 4.6
@export var attack_damage := 7
@export var attack_reach := 2.6
@export var shoot_reach := 26.0
@export var engage_radius := 22.0

var health := 60
var downed := false
var duty := Duty.AWAY
var muster_count := 0
## Los actos que ha peleado a tu lado. Es lo que convierte a un aliado en
## alguien: si no recuerda dónde estuvo, es una torreta con nombre.
var witnessed: PackedStringArray = PackedStringArray()
var story_runtime: Node = null

var _hero: Node3D = null
var _terrain: Node = null
var _visual: Node3D = null
var _animator: AnimationPlayer = null
var _target: Node3D = null
var _cooldown := 0.0
var _heal_cooldown := 0.0
var _speak_left := 8.0
var _recover := 0.0
var _rng := RandomNumberGenerator.new()
var _muster_left := 0.0
var _call_cooldown := 0.0


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	health = max_health
	_rng.seed = hash(companion_id)
	add_to_group("rpg_companion")
	add_to_group("adventure_interactable")
	_build_collision()
	_build_visual()
	_build_plate()
	## La altura la sirve `Terrain3D.data`, no el nodo: preguntársela al nodo
	## devuelve siempre lo mismo y el aliado aparece flotando o enterrado.
	if story_runtime != null and "_terrain" in story_runtime:
		_terrain = story_runtime.get("_terrain")
	visible = false
	duty = Duty.AWAY


func is_available() -> bool:
	return duty == Duty.AWAY and not downed and _call_cooldown <= 0.0


func is_here() -> bool:
	return duty != Duty.AWAY


func cooldown_left() -> float:
	return maxf(_call_cooldown, 0.0)


func recovery_left() -> float:
	return maxf(_recover, 0.0) if downed else 0.0


## Una línea para el HUD: en qué anda y cuánto falta. Sin esto no había forma de
## saber si un aliado estaba vivo, tumbado o todavía volviendo a lo suyo.
func status_line() -> String:
	if downed:
		return "tumbado · %d s" % int(ceil(recovery_left()))
	if is_here():
		return "contigo" if duty == Duty.MUSTERED else "llegando"
	if _call_cooldown > 0.0:
		return "vuelve en %d s" % int(ceil(_call_cooldown))
	return "listo · C"


## Aparece a `HORIZON` metros y viene corriendo. Devuelve false si no toca.
func summon(hero: Node3D) -> bool:
	if not is_available() or hero == null:
		return false
	_hero = hero
	var forward := -hero.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var origin := Vector2(hero.global_position.x, hero.global_position.z)
	var spot := _horizon_spot(origin, Vector2(forward.x, forward.z))
	global_position = spot
	visible = true
	duty = Duty.ARRIVING
	muster_count += 1
	_muster_left = MUSTER_TIME
	_target = null
	_face(hero.global_position - global_position)
	var veteran := veteran_line()
	_say(veteran if not veteran.is_empty() and muster_count % 2 == 0 else _arrival_line())
	return true


## Busca un punto del horizonte con suelo: sobre el mar la silueta se hundiría.
func _horizon_spot(origin: Vector2, forward: Vector2) -> Vector3:
	var best := origin + forward * HORIZON
	var best_height := -1000.0
	for turn in [0.0, 0.9, -0.9, 1.9, -1.9, 2.8]:
		var direction := forward.rotated(float(turn))
		var probe := origin + direction * HORIZON
		var height := _height_at(probe)
		if height > 1.2:
			return Vector3(probe.x, height + 0.05, probe.y)
		if height > best_height:
			best_height = height
			best = probe
	return Vector3(best.x, maxf(best_height, 1.0) + 0.05, best.y)


func _height_at(point: Vector2) -> float:
	if _terrain == null:
		return -1000.0
	var height: float = _terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	return -1000.0 if is_nan(height) else height


## Se marcha por donde vino cuando ya no hace falta.
func _depart() -> void:
	_say(_farewell_line())
	duty = Duty.AWAY
	visible = false
	_target = null
	_call_cooldown = CALL_COOLDOWN


func get_interaction_prompt() -> String:
	if downed:
		return "E · %s se recupera · aguanta tú" % display_name
	return "E · Hablar con %s" % display_name


func interact(_player: Node) -> bool:
	## Mientras está contigo puedes cambiar dos palabras. Es lo que sostiene
	## que sea alguien y no una torreta que te sigue.
	if not downed:
		_muster_left = maxf(_muster_left, MUSTER_FLOOR + 20.0)
	_say(_down_line() if downed else _banter_lines()[_rng.randi() % 2])
	return true


## Su frase para la cinemática de cierre. Devuelve cadena vacía si no estuvo
## allí: nadie puede reclamar una gesta que no peleó.
func witness(act_id: String, relic: String) -> String:
	if not is_here() or downed:
		return ""
	if not witnessed.has(act_id):
		witnessed.append(act_id)
	match companion_id:
		"calen":
			return "Calen se quita el yelmo. «%s.» Lo dice entero, despacio, como quien devuelve algo prestado." % relic
		"tavia":
			return "Tavia te mira las manos antes que la cara. «Estás sangrando otra vez.» No te suelta hasta que para."
		"orin":
			return "Orin apoya el martillo en el suelo. «Yo no fundí esa campana. Pero he oído a mi padre nombrarla.»"
		_:
			return "Brenn baja el arco y no dice nada durante un rato largo. Luego: «Se oye desde aquí arriba.»"


## Lo que suelta cuando ya habéis cerrado algo juntos: distinto de la primera vez.
func veteran_line() -> String:
	if witnessed.is_empty():
		return ""
	match companion_id:
		"calen": return "«Contigo he estado en %d. Vamos a por la siguiente.»" % witnessed.size()
		"tavia": return "«Van %d. Y sigues sin cuidarte.»" % witnessed.size()
		"orin": return "«%d campanas. Me estoy quedando sin excusas para no ir.»" % witnessed.size()
		_: return "«%d veces te he cubierto la espalda. Llevo la cuenta.»" % witnessed.size()


func _arrival_line() -> String:
	match companion_id:
		"calen": return "«¡Aguanta! ¡Que ya voy!»"
		"tavia": return "«¡Te oí! ¡No te caigas antes de que llegue!»"
		"orin": return "«¡Ya corro! ¡No empieces sin mí!»"
		_: return "«¡Te tengo a tiro! ¡Voy!»"


func _ready_line() -> String:
	match companion_id:
		"calen": return "«A tu lado. Dime cuál cae primero.»"
		"tavia": return "«Estoy detrás. Tú pega, yo te cierro.»"
		"orin": return "«Aquí. Señala y lo abro.»"
		_: return "«En posición. No te cruces en mi línea.»"


func _farewell_line() -> String:
	match companion_id:
		"calen": return "«Se acabó. Vuelvo al muro, llámame otra vez.»"
		"tavia": return "«Ya no sangras. Me vuelvo, silba si hace falta.»"
		"orin": return "«Buen trabajo. La fragua no se atiende sola.»"
		_: return "«Despejado. Estaré cerca, grita y vengo.»"


func _physics_process(delta: float) -> void:
	_call_cooldown = maxf(0.0, _call_cooldown - delta)
	if duty == Duty.AWAY:
		return
	if duty == Duty.ARRIVING:
		_run_in(delta)
		return
	_muster_left -= delta
	if _muster_left <= 0.0 and _closest_foe() == null:
		# Irse en mitad del cierre de acto sería marcharse justo cuando toca
		# mirar lo que acabáis de hacer.
		if story_runtime != null:
			var film = story_runtime.get("cinematic")
			if film != null and bool(film.get("running")):
				_muster_left = MUSTER_FLOOR
				_serve(delta)
				return
		_depart()
		return
	_serve(delta)


## Corriendo desde el horizonte. No pelea por el camino: viene a por ti.
func _run_in(delta: float) -> void:
	if not is_instance_valid(_hero):
		_depart()
		return
	var to_hero := _hero.global_position - global_position
	to_hero.y = 0.0
	if to_hero.length() <= FOLLOW_FAR:
		duty = Duty.MUSTERED
		_muster_left = MUSTER_TIME
		_say(_ready_line())
		return
	_walk(to_hero.normalized(), ARRIVE_SPEED)
	_stand_on_terrain()
	_speak_left = maxf(_speak_left - delta, 0.0)


func _serve(delta: float) -> void:
	if downed:
		_recover = maxf(0.0, _recover - delta)
		if _recover <= 0.0:
			_revive()
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("local_player") as Node3D
		if _hero == null:
			return
	_cooldown = maxf(0.0, _cooldown - delta)
	_heal_cooldown = maxf(0.0, _heal_cooldown - delta)
	_speak_left = maxf(0.0, _speak_left - delta)

	var to_hero := _flat(_hero.global_position - global_position)
	if to_hero.length() > LEASH:
		_catch_up()
		return
	_target = _closest_foe()
	if _target != null:
		_fight(delta)
	else:
		_follow(delta, to_hero)
	if _speak_left <= 0.0:
		_speak_left = SPEAK_GAP + _rng.randf_range(0.0, 18.0)
		_banter()
	_stand_on_terrain()


func _fight(delta: float) -> void:
	## Mientras haya pelea no se marchan a media faena, aunque venza el plazo.
	_muster_left = maxf(_muster_left, MUSTER_FLOOR)
	var to_foe := _flat(_target.global_position - global_position)
	var reach := shoot_reach if craft == Craft.ARCHER else attack_reach
	if to_foe.length() > reach:
		_walk(to_foe.normalized(), move_speed)
		_play(["Run", "Walk", "Idle"])
	else:
		_brake(delta)
		_face(to_foe)
		_strike()


func _strike() -> void:
	if _cooldown > 0.0:
		return
	match craft:
		Craft.HEALER:
			_cooldown = 3.4
			_mend()
		Craft.SHIELD:
			_cooldown = 1.4
			_hit(attack_damage)
			_play(["SwordSlash", "Punch", "Idle"])
		Craft.HAMMER:
			_cooldown = 2.6
			_hit(attack_damage * 2)
			_play(["SwordSlash", "Punch", "Idle"])
		_:
			_cooldown = 1.8
			_hit(attack_damage)
			_play(["Shoot_OneHanded", "Punch", "Idle"])


func _hit(amount: int) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if _target.has_method("receive_projectile_hit") and craft == Craft.ARCHER:
		_target.call("receive_projectile_hit", global_position, self)
		return
	if _target.has_method("receive_tool_hit"):
		# Se declara como espada para que la coraza y la bruma de los jefes
		# reaccionen igual que con el héroe: un compañero no salta las reglas.
		_target.call("receive_tool_hit", "sword", "CompanionBlade", global_position, self)


func _mend() -> void:
	## Tavia no pega: cierra heridas. Es el compañero que cambia una pelea larga.
	if story_runtime == null or _heal_cooldown > 0.0:
		return
	_heal_cooldown = 7.5
	if story_runtime.has_method("heal_player"):
		story_runtime.call("heal_player", 14, display_name)
	_play(["PickUp", "Idle"])


func _follow(delta: float, to_hero: Vector3) -> void:
	var distance := to_hero.length()
	if distance > FOLLOW_FAR:
		_walk(to_hero.normalized(), move_speed)
		_play(["Run", "Walk", "Idle"])
	elif distance < FOLLOW_NEAR:
		_walk(-to_hero.normalized(), move_speed * 0.45)
		_play(["Walk", "Idle"])
	else:
		_brake(delta)
		_face(to_hero)
		_play(["Idle"])


func _catch_up() -> void:
	## Aparece detrás del héroe. Es preferible a que se quede clavado en una roca
	## a cuarenta metros mientras te matan.
	var behind := _hero.global_position - _hero.global_basis.z * -3.4
	global_position = Vector3(behind.x, global_position.y, behind.z)
	_stand_on_terrain()


func receive_tool_hit(_category: String, _item_id: String, _hit_position: Vector3, _attacker: Node) -> void:
	pass


func take_hit(amount: int) -> void:
	## Lo llaman los enemigos que le apuntan a él en vez de al héroe.
	if downed:
		return
	health = maxi(0, health - maxi(1, amount))
	if health <= 0:
		_go_down()


func _go_down() -> void:
	downed = true
	_recover = 45.0
	_play(["Defeat", "Death", "Idle"])
	_say(_down_line())
	companion_downed.emit(companion_id)


func _revive() -> void:
	downed = false
	health = max_health
	_say("«Ya estoy. No ha sido nada.»")


func _closest_foe() -> Node3D:
	var best := INF
	var found: Node3D = null
	for group in ["rpg_enemy", "rpg_boss"]:
		for node in get_tree().get_nodes_in_group(group):
			var foe := node as Node3D
			if foe == null or bool(foe.get("dead")):
				continue
			if group == "rpg_boss" and bool(foe.get("sealed")):
				continue
			var distance := _flat(foe.global_position - global_position).length()
			if distance < best and distance <= engage_radius:
				best = distance
				found = foe
	return found


func _banter() -> void:
	## Comentarios sueltos mientras camináis. Es lo que separa a un compañero de
	## una torreta que te sigue.
	var lines: PackedStringArray = _banter_lines()
	if lines.is_empty():
		return
	_say(lines[_rng.randi_range(0, lines.size() - 1)])


func _banter_lines() -> PackedStringArray:
	if _target != null:
		match companion_id:
			"brenn":
				return PackedStringArray(["«Le tengo.»", "«No te cruces.»"])
			"calen":
				return PackedStringArray(["«Detrás de mí.»", "«Aguanto yo.»"])
			"tavia":
				return PackedStringArray(["«Quieto un segundo, que te cierro eso.»"])
			_:
				return PackedStringArray(["«Aparta.»", "«Este es mío.»"])
	match companion_id:
		"brenn":
			return PackedStringArray([
				"«Hace años que no salía tan lejos de la aldea.»",
				"«Se oye distinto por aquí. Más limpio.»",
				"«Mi padre pasó por este camino. Eso me contaron.»",
			])
		"calen":
			return PackedStringArray([
				"«Nunca había patrullado sin uniforme. Se anda mejor.»",
				"«Si mis hombres me vieran a tus órdenes.»",
				"«Cinco nombres. Todavía me despierto contándolos.»",
			])
		"tavia":
			return PackedStringArray([
				"«Esa raíz de ahí está sana. Buena señal.»",
				"«Se me van a echar a perder las semillas.»",
				"«Mi hermana habría venido antes que yo.»",
			])
		_:
			return PackedStringArray([
				"«Andando se piensa mejor que en la fragua.»",
				"«Cuando volvamos te afilo eso, que va romo.»",
			])


func _down_line() -> String:
	match companion_id:
		"brenn":
			return "«Me quedo... ve tú.»"
		"calen":
			return "«¡Sigue! Es una orden.»"
		"tavia":
			return "«Estoy bien. Estoy bien. No lo estoy.»"
		_:
			return "«Dame un momento.»"


func _say(line: String) -> void:
	companion_spoke.emit(line)
	if _hero != null and _hero.has_signal("action_feedback"):
		_hero.emit_signal("action_feedback", "%s: %s" % [display_name, line])


func _walk(direction: Vector3, speed: float) -> void:
	var step := Vector3(direction.x, 0.0, direction.z).normalized() * speed * get_physics_process_delta_time()
	global_position += step
	_face(direction)


func _brake(_delta: float) -> void:
	pass


func _face(direction: Vector3) -> void:
	var flat := _flat(direction)
	if flat.length() > 0.05:
		rotation.y = atan2(flat.x, flat.z)


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func _stand_on_terrain() -> void:
	if _terrain == null:
		var world := get_tree().current_scene
		if world != null:
			_terrain = world.get_node_or_null("Terrain3D")
		if _terrain == null:
			return
	var data = _terrain.get("data")
	if data == null:
		return
	var height: float = data.get_height(Vector3(global_position.x, 0.0, global_position.z))
	if not is_nan(height):
		global_position.y = height + 0.08


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CompanionBody"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)


func _build_visual() -> void:
	var scene := load(
		"res://assets/quaternius/ultimate_animated_characters/glTF/%s" % character_file
	) as PackedScene
	if scene == null:
		return
	_visual = scene.instantiate() as Node3D
	if _visual == null:
		return
	_visual.name = "CompanionVisual"
	_visual.scale = Vector3.ONE * 0.97
	add_child(_visual)
	_animator = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play(["Idle"])


func _build_plate() -> void:
	var label := Label3D.new()
	label.name = "CompanionName"
	label.text = display_name
	label.position = Vector3(0.0, 2.15, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.modulate = Color(0.70, 0.92, 1.0)
	label.visibility_range_end = 44.0
	add_child(label)


func _play(candidates: Array) -> void:
	if _animator == null:
		return
	for name in candidates:
		if _animator.has_animation(String(name)):
			if _animator.current_animation != String(name):
				_animator.play(String(name))
			return
