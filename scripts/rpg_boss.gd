class_name RPGBoss
extends RPGEnemy

## Un jefe de acto. Vertebra un objetivo principal y exige una mecánica concreta
## del repertorio del héroe.
##
## Lo que había antes no eran jefes: eran limos con otra malla. Medido sobre el
## sistema anterior, el Rey Fúngico tenía 4 puntos de vida —exactamente los
## mismos que el limo espinoso más básico— y moría de un solo tajo; el dragón
## tenía 8 y el demonio 12. Los diez modelos compartían clase, vida derivada del
## ORDEN de generación (`4 + índice % 5 * 2`) y una única conducta: caminar en
## línea recta y tocarte cada 1,25 s.
##
## Un jefe de este juego, en cambio, hace tres cosas que un enemigo de camino no:
##   1. TELEGRAFÍA. Antes de cada golpe se planta y anuncia, y ese aviso es el
##      que da al jugador la oportunidad de responder.
##   2. EXIGE UNA RESPUESTA CONCRETA. Cubrirse, disparar, cargar o esquivar. Si
##      no la das, el golpe entra entero; si la das, el jefe queda ABIERTO.
##   3. TIENE FASES. A dos tercios y a un tercio de vida cambia de ritmo, así que
##      el combate no es la misma pelea repetida hasta que la barra baja.
##
## La ventana de vulnerabilidad es la única forma real de hacerle daño: mientras
## se recupera, cada impacto vale el triple. Un jefe no se gana a base de aguante,
## se gana leyendo lo que hace.

enum Demand { GUARD, BOW, CHARGE, DODGE, TRIAL }
enum Stance { STALK, WINDUP, STRIKE, OPEN }

## Cuánto se multiplica el daño recibido mientras el jefe está abierto.
const OPEN_DAMAGE_FACTOR := 3
## Lo que dura el aviso antes del golpe. Menos que esto no da tiempo a responder.
const WINDUP_TIME := 1.15
## Lo que el jefe se queda abierto tras fallar o ser respondido.
const OPEN_TIME := 2.4
## Daño mínimo que atraviesa una coraza o una bruma sin romper.
const WARDED_DAMAGE := 1

@export var demand := Demand.GUARD
@export var strike_radius := 4.6
@export var strike_damage := 16
@export var stalk_cooldown := 2.6
## Cuántos flechazos rompen la bruma, o cuántos giros rompen la coraza.
@export var ward_hits := 3
@export var act_title := "Acto"

var stance := Stance.STALK
var phase := 1
var _stance_left := 0.0
var _cooldown := 1.5
var _ward := 0
var _dive_origin := Vector3.ZERO
var _health_label: Label3D = null
var _announced := false
## Sellado hasta que su acto esté en curso. Sin este cerrojo se podía ir derecho
## al último jefe con la espada de partida y la historia no significaba nada.
var sealed := true
var spark_bursts := 0
var hazard: Node = null
## El estandarte del HUD ya lo nombra y ya lleva su barra. Repetirlo flotando
## encima sólo tapa la arena, así que uno de los dos se calla.
var banner_shown := false


func set_banner_shown(shown: bool) -> void:
	banner_shown = shown
	if _health_label != null:
		_health_label.visible = not shown
	# Y la chapa que hereda de enemigo normal, que es la que de verdad tapaba:
	# esconder sólo la de vida dejaba «La corona de invierno · Coloso» encima.
	var plate := get_node_or_null("EnemyName") as Label3D
	if plate != null:
		plate.visible = not shown


func _ready() -> void:
	super()
	add_to_group("rpg_boss")
	remove_from_group("rpg_enemy")
	_ward = ward_hits if demand in [Demand.BOW, Demand.CHARGE, Demand.TRIAL] else 0
	_build_health_label()


func _physics_process(delta: float) -> void:
	if dead or not _is_authority():
		return
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("local_player") as Node3D
	if not is_instance_valid(_target):
		return
	var flat := Vector3(
		_target.global_position.x - global_position.x,
		0.0,
		_target.global_position.z - global_position.z
	)
	var distance := flat.length()
	if distance > sleep_radius:
		return
	if sealed:
		_brake(delta)
		move_and_slide()
		_stand_on_terrain()
		_refresh_health_label()
		if not _announced and distance < detection_radius:
			_announced = true
			_say("%s duerme sellado. Aún no es su hora." % display_name)
		return
	if not _announced and distance < detection_radius:
		_announced = true
		_say("%s · %s" % [act_title, display_name])
	_update_phase()
	_advance_stance(delta, flat, distance)
	velocity.y = 0.0
	move_and_slide()
	_stand_on_terrain()
	_refresh_health_label()


func _advance_stance(delta: float, flat: Vector3, distance: float) -> void:
	_stance_left = maxf(0.0, _stance_left - delta)
	match stance:
		Stance.STALK:
			_cooldown = maxf(0.0, _cooldown - delta)
			_walk_towards(flat, distance, delta)
			if distance <= strike_radius * 1.6 and _cooldown <= 0.0:
				_begin_windup()
		Stance.WINDUP:
			_brake(delta)
			_face(flat)
			if _stance_left <= 0.0:
				_resolve_strike()
		Stance.STRIKE:
			if demand == Demand.DODGE:
				_dive(delta)
			else:
				_brake(delta)
			if _stance_left <= 0.0:
				_open("")
		Stance.OPEN:
			_brake(delta)
			if _stance_left <= 0.0:
				stance = Stance.STALK
				_cooldown = stalk_cooldown / float(phase)
				_play_animation(["Idle", "Flying"])


func _begin_windup() -> void:
	stance = Stance.WINDUP
	_stance_left = WINDUP_TIME / (1.0 + 0.18 * float(phase - 1))
	_play_animation(["Attack", "Bite", "Idle"])
	_say(_telegraph())


func _telegraph() -> String:
	match demand:
		Demand.GUARD:
			return "%s alza los brazos: CÚBRETE" % display_name
		Demand.BOW:
			return "%s se envuelve en bruma: usa el ARCO" % display_name
		Demand.CHARGE:
			return "%s cierra su coraza: sólo el ataque CARGADO la abre" % display_name
		Demand.DODGE:
			return "%s se lanza en picado: ESQUIVA" % display_name
		_:
			return "%s cambia de forma" % display_name


func _resolve_strike() -> void:
	## Aquí se decide el combate. Si el héroe ha dado la respuesta que el jefe
	## exige, el golpe se pierde y el jefe queda abierto; si no, entra entero.
	stance = Stance.STRIKE
	_stance_left = 0.85 if demand == Demand.DODGE else 0.35
	if demand == Demand.DODGE:
		var towards := _target.global_position - global_position
		towards.y = 0.0
		_dive_origin = towards.normalized() if towards.length() > 0.01 else Vector3.FORWARD
		return
	var answered := _player_answered()
	if answered:
		_open(_reward_line())
		return
	var reach := strike_radius
	if global_position.distance_to(_target.global_position) <= reach and story_runtime != null:
		story_runtime.call("damage_player", strike_damage, global_position, display_name)


func _player_answered() -> bool:
	match demand:
		Demand.GUARD:
			return bool(_target.get("is_guarding"))
		Demand.BOW, Demand.CHARGE, Demand.TRIAL:
			# La bruma y la coraza no se responden en el instante del golpe: se
			# rompen antes, a flechazos o a giros. Si ya está rota, el jefe llega
			# al golpe descubierto y falla solo.
			return _ward <= 0
		_:
			return false


func _reward_line() -> String:
	match demand:
		Demand.GUARD:
			return "Tu escudo aguanta: %s queda expuesto" % display_name
		Demand.BOW:
			return "La bruma se deshace: %s queda expuesto" % display_name
		Demand.CHARGE:
			return "La coraza cede: %s queda expuesto" % display_name
		_:
			return "%s queda expuesto" % display_name


func _dive(delta: float) -> void:
	## El picado recorre una línea recta. Quien no se aparta, lo recibe; quien se
	## aparta, ve al jefe pasarse de largo y clavarse.
	velocity.x = _dive_origin.x * move_speed * 3.4
	velocity.z = _dive_origin.z * move_speed * 3.4
	var flat := Vector3(
		_target.global_position.x - global_position.x, 0.0,
		_target.global_position.z - global_position.z
	)
	if flat.length() <= strike_radius * 0.62 and not bool(_target.get("is_rolling")):
		if story_runtime != null:
			story_runtime.call("damage_player", strike_damage, global_position, display_name)
			# Sacude aunque falle: el mazazo se oye en el suelo.
			story_runtime.call("shake_camera", global_position, 0.30, 95.0)
		_stance_left = 0.0
		stance = Stance.STALK
		_cooldown = stalk_cooldown
		return
	if _stance_left <= 0.0:
		_open("%s se estrella: queda expuesto" % display_name)


func _open(line: String) -> void:
	stance = Stance.OPEN
	_stance_left = OPEN_TIME
	velocity = Vector3.ZERO
	# Romper la guardia es EL momento del combate: estallido blanco y sacudida.
	if story_runtime != null:
		story_runtime.call("burst_sparks", global_position + Vector3.UP * 2.4 * scale.y,
			Color(1.0, 0.97, 0.86), 64, 11.5, 0.85)
		story_runtime.call("shake_camera", global_position, 0.52, 110.0)
		spark_bursts += 1
	_play_animation(["Defeat", "RecieveHit", "Idle"])
	if not line.is_empty():
		_say(line)


func _update_phase() -> void:
	var ratio := float(health) / float(maxi(max_health, 1))
	var next := 1
	if ratio <= 0.34:
		next = 3
	elif ratio <= 0.67:
		next = 2
	if next == phase:
		return
	phase = next
	# Cada fase devuelve la guardia: la coraza y la bruma se rehacen, así que el
	# jugador tiene que volver a resolverlas en vez de romperlas una vez y ya.
	_ward = ward_hits if demand in [Demand.BOW, Demand.CHARGE, Demand.TRIAL] else 0
	move_speed *= 1.14
	_say("%s entra en su fase %d" % [display_name, phase])
	# Y se lleva por delante una salida. El escenario deja de ser fondo.
	if hazard != null and is_instance_valid(hazard):
		var closed := String(hazard.call("tighten"))
		if not closed.is_empty():
			_say(closed)


func receive_tool_hit(category: String, item_id: String, hit_position: Vector3, attacker: Node) -> void:
	if dead or sealed:
		return
	var spinning := attacker != null and attacker.has_method("is_spin_attacking") \
		and bool(attacker.call("is_spin_attacking"))
	# La coraza sólo cede al giro cargado; la bruma, sólo a las flechas.
	if _ward > 0:
		if demand == Demand.CHARGE and spinning:
			_ward -= 1
			_break_ward()
			return
		_warded_clang(hit_position)
		_take_damage(WARDED_DAMAGE, hit_position, attacker)
		return
	var fallback := 3
	match category:
		"sword": fallback = 4
		"axe": fallback = 3
		"bow": fallback = 2
	var damage := RPGForge.weapon_damage(item_id, fallback)
	if spinning:
		damage += 2
	if stance == Stance.OPEN:
		damage *= OPEN_DAMAGE_FACTOR
	_take_damage(damage, hit_position, attacker)


func receive_projectile_hit(hit_position: Vector3, shooter: Node) -> void:
	if dead or sealed:
		return
	if _ward > 0:
		if demand in [Demand.BOW, Demand.TRIAL]:
			_ward -= 1
			_break_ward()
			return
		_warded_clang(hit_position)
		_take_damage(WARDED_DAMAGE, hit_position, shooter)
		return
	var damage := 4
	if stance == Stance.OPEN:
		damage *= OPEN_DAMAGE_FACTOR
	_take_damage(damage, hit_position, shooter)


func _warded_clang(point: Vector3) -> void:
	if story_runtime == null:
		return
	story_runtime.call("burst_sparks", point, Color(1.0, 0.86, 0.42), 22, 5.4, 0.42)
	story_runtime.call("shake_camera", point, 0.13, 40.0)
	spark_bursts += 1


func _break_ward() -> void:
	if _ward > 0:
		_say("%s · quedan %d" % [display_name, _ward])
		return
	_open(_reward_line())


func _walk_towards(flat: Vector3, distance: float, delta: float) -> void:
	if distance > strike_radius * 1.2:
		var direction := flat.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_face(flat)
		_play_animation(["Walk", "Run", "Flying", "Idle"])
	else:
		_brake(delta)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)


func _face(flat: Vector3) -> void:
	if flat.length() > 0.05:
		look_at(global_position + flat.normalized(), Vector3.UP, true)


func _say(message: String) -> void:
	if _target != null and _target.has_signal("action_feedback"):
		_target.emit_signal("action_feedback", message)


func _build_health_label() -> void:
	_health_label = Label3D.new()
	_health_label.name = "BossHealth"
	_health_label.position = Vector3(0.0, 3.4, 0.0)
	_health_label.no_depth_test = true
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 40
	_health_label.outline_size = 10
	_health_label.modulate = Color(1.0, 0.72, 0.36)
	_health_label.visibility_range_end = 90.0
	add_child(_health_label)


func _refresh_health_label() -> void:
	if _health_label == null:
		return
	if sealed:
		_health_label.text = "%s\n· sellado ·" % display_name
		return
	var filled := int(round(12.0 * float(health) / float(maxi(max_health, 1))))
	var ward := "" if _ward <= 0 else " [%s]" % "◆".repeat(_ward)
	_health_label.text = "%s\n%s%s%s" % [
		display_name, "█".repeat(maxi(filled, 0)), "·".repeat(maxi(12 - filled, 0)), ward]


func set_sealed(value: bool) -> void:
	## Al romperse el sello el jefe despierta y se vuelve a anunciar, porque el
	## aviso anterior decía justo lo contrario.
	if sealed == value:
		return
	sealed = value
	_announced = false
	_refresh_health_label()
