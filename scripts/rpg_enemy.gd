class_name RPGEnemy
extends CharacterBody3D

## Enemigo ligero y autoritativo. Se integra con los golpes y proyectiles del
## jugador mediante las mismas funciones que ya usan árboles y rocas.
##
## NO USA GRAVEDAD. Terrain3D sólo genera colisión de suelo en un radio alrededor
## del jugador, y los enemigos viven repartidos por una isla de 144 km²: con
## gravedad se desploman al vacío antes de que nadie llegue a verlos. Medido
## sobre los 48 originales: los 48 caídos a los diez segundos, el peor 513,6 m.
## Por eso la cota se pega a la altura del terreno y el movimiento horizontal
## sigue pasando por move_and_slide(), que es lo que los frena contra los muros.
##
## Y duerme cuando el héroe está lejos: sin eso, cada enemigo de la isla persigue
## un objetivo que no existe en todos los fotogramas.
##
## CADA BIOMA PELEA A SU MANERA. Antes los diez modelos compartían una única
## conducta —caminar en línea recta y tocarte cada 1,25 s—, así que la nieve, el
## desierto y el bosque se jugaban exactamente igual. Ahora el estilo de combate
## sale del sitio:
##   - VALLE: embestida corta y telegrafiada. Si falla, se queda vendido.
##   - NIEVE: pisotón con onda expansiva. No hace falta que te toque; hace falta
##     que estés dentro. Lento, ancho y anunciado: se responde retrocediendo.
##   - DESIERTO: espinas a distancia. Este no se te acerca, te mantiene lejos y
##     te obliga a cerrar la distancia o a sacar el arco.
##   - BOSQUE TENEBROSO: parpadeo. Se desvanece, aparece a tu espalda y golpea.
##     Mientras está desvanecido el acero apenas le entra.
##   - CASTILLO: guardia. Entre golpe y golpe se cubre, y de frente casi no le
##     haces daño: hay que rodearlo o abrirlo con el ataque cargado.

enum Style { LUNGE, SLAM, SPINES, BLINK, GUARD }

const COMPANION_AGGRO_RANGE := 17.0
const COMPANION_AGGRO_EDGE := 3.2

signal defeated(enemy_id: String, reward_id: String)
signal health_changed(current: int, maximum: int)

@export var enemy_id := "shadow_orc"
@export var display_name := "Merodeador del Silencio"
@export var monster_path := "res://assets/quaternius/Ultimate Monsters/Blob/glTF/Orc.gltf"
@export var max_health := 6
@export var attack_damage := 8
@export var move_speed := 3.2
@export var detection_radius := 21.0
## Más allá de esto el enemigo no piensa. Tiene que ser bastante mayor que el
## radio de detección o se vería aparecer de golpe al acercarse.
@export var sleep_radius := 140.0
## A qué altura sobre el terreno queda la base de la cápsula.
@export var foot_offset := 0.08
## Cómo pelea. Lo fija el bestiario a partir del bioma donde nace.
@export var style := Style.LUNGE
## Radio de la onda del pisotón y alcance de las espinas.
@export var burst_radius := 3.6
@export var range_reach := 15.0
@export var attack_radius := 1.65
@export var reward_item_id := "Coin_Skull"
@export var reward_amount := 1

var story_runtime: Node
var health := 6
var dead := false
var _target: Node3D
var _retarget := 0.0
var _visual: Node3D
var _animator: AnimationPlayer
var _attack_cooldown := 0.0
var _spawn_position := Vector3.ZERO
var _terrain: Node = null
var _windup := 0.0
var _winding := false
var _lunge := 0.0
var _lunge_dir := Vector3.ZERO
var _faded := 0.0
var _guard_up := false


func _ready() -> void:
	collision_layer = 5
	collision_mask = 1
	health = max_health
	_spawn_position = global_position
	add_to_group("melee_target")
	add_to_group("rpg_enemy")
	_build_collision()
	_build_visual()
	_build_nameplate()
	if story_runtime!=null and story_runtime.has_method("registrar_enemigo_red"):
		story_runtime.registrar_enemigo_red(self)


func _physics_process(delta: float) -> void:
	if dead or not _is_authority():
		return
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(_target):
		_retarget = 1.4
		_pick_target()
	if not is_instance_valid(_target):
		return
	var flat := Vector3(
		_posicion_objetivo().x - global_position.x,
		0.0,
		_posicion_objetivo().z - global_position.z
	)
	var distance := flat.length()
	if distance > sleep_radius:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_windup = maxf(0.0, _windup - delta)
	_faded = maxf(0.0, _faded - delta)
	if distance <= detection_radius:
		_fight(delta, flat, distance)
	else:
		_idle(delta)
	velocity.y = 0.0
	move_and_slide()
	_stand_on_terrain()


func _idle(delta: float) -> void:
	_winding = false
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 2.0 * delta)
	_set_guard(false)
	_play_animation(["Idle", "Flying"])


func _fight(delta: float, flat: Vector3, distance: float) -> void:
	## El golpe se resuelve al final de la anticipación, no al empezarla: ese
	## hueco es lo que le da al jugador la oportunidad de responder.
	if _lunge > 0.0:
		_advance_lunge(delta)
		return
	if _winding:
		# La anticipación necesita su propia bandera. Con `if _windup > 0.0` por
		# fuera y `if _windup <= 0.0` por dentro, las dos condiciones eran
		# incompatibles y _release() no se llamaba NUNCA: el enemigo se quedaba
		# preparando el golpe para siempre y no hacía daño jamás.
		_brake(delta)
		_face(flat)
		if _windup <= 0.0:
			_winding = false
			_release(flat, distance)
		return
	match style:
		Style.SPINES:
			_keep_distance(delta, flat, distance)
		Style.BLINK:
			_stalk_blinking(delta, flat, distance)
		_:
			_close_in(delta, flat, distance)
	if _attack_cooldown <= 0.0 and _in_reach(distance):
		_begin_windup()


func _in_reach(distance: float) -> bool:
	match style:
		Style.SPINES:
			return distance <= range_reach
		Style.SLAM:
			return distance <= burst_radius * 1.15
		_:
			return distance <= attack_radius * 2.2


func _begin_windup() -> void:
	_winding = true
	_windup = 0.75 if style == Style.SLAM else 0.45
	_set_guard(false)
	_play_animation(["Attack", "Bite", "Idle"])


func _release(flat: Vector3, distance: float) -> void:
	_attack_cooldown = 1.9 if style == Style.SLAM else 1.35
	match style:
		Style.LUNGE, Style.GUARD:
			_lunge = 0.32
			_lunge_dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
		Style.SLAM:
			# La onda no necesita tocarte: necesita que estés dentro.
			if distance <= burst_radius:
				_hit_player()
			_shake_grass()
			# El pisotón se nota aunque falle: es lo que enseña a apartarse.
			if story_runtime != null:
				story_runtime.call("shake_camera", global_position, 0.34, burst_radius * 2.4)
		Style.SPINES:
			# Las espinas van en línea: si te has apartado del eje, fallan.
			var towards := flat.normalized()
			var forward := -global_basis.z
			if distance <= range_reach and towards.dot(forward) > 0.82:
				_hit_player()
		Style.BLINK:
			_blink_behind()
			_hit_player()
	if style == Style.GUARD:
		_set_guard(true)


func _advance_lunge(delta: float) -> void:
	_lunge = maxf(0.0, _lunge - delta)
	velocity.x = _lunge_dir.x * move_speed * 3.6
	velocity.z = _lunge_dir.z * move_speed * 3.6
	if not is_instance_valid(_target):
		return
	var reach := Vector3(
		_posicion_objetivo().x - global_position.x, 0.0,
		_posicion_objetivo().z - global_position.z
	).length()
	if reach <= attack_radius * 1.25:
		_hit_player()
		_lunge = 0.0


func _keep_distance(delta: float, flat: Vector3, distance: float) -> void:
	## El de las dunas no cierra: te mantiene lejos, que es lo que obliga a sacar
	## el arco o a comerse el camino hasta él.
	var direction := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var wanted := range_reach * 0.55
	var push := 0.0
	if distance < wanted * 0.7:
		push = -1.0
	elif distance > wanted:
		push = 1.0
	velocity.x = direction.x * move_speed * push
	velocity.z = direction.z * move_speed * push
	_face(flat)
	_play_animation(["Walk", "Run", "Flying", "Idle"] if absf(push) > 0.01 else ["Idle", "Flying"])


func _stalk_blinking(delta: float, flat: Vector3, distance: float) -> void:
	if _faded <= 0.0:
		_faded = 1.6
		_set_fade(true)
	_close_in(delta, flat, distance)


func _blink_behind() -> void:
	## Aparece a la espalda del héroe. Es lo que hace que en el Bosque Tenebroso
	## no baste con mirar al frente.
	if not is_instance_valid(_target):
		return
	var behind := _posicion_objetivo() - (-_target.global_basis.z) * 2.1
	global_position = Vector3(behind.x, global_position.y, behind.z)
	_stand_on_terrain()
	_set_fade(false)
	_faded = 0.0


func _close_in(delta: float, flat: Vector3, distance: float) -> void:
	if distance > attack_radius:
		var direction := flat.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		_face(flat)
		_play_animation(["Walk", "Run", "Flying", "Idle"])
	else:
		_brake(delta)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)


func _face(flat: Vector3) -> void:
	if flat.length() > 0.05:
		look_at(global_position + flat.normalized(), Vector3.UP, true)


## El héroe es el objetivo natural. Un aliado sólo le roba la atención si está
## claramente más cerca: si cualquiera valiera igual, llamar a los tuyos
## convertiría la pelea en un espectáculo que miras desde atrás.
func _pick_target() -> void:
	var chosen: Node3D
	var best := INF
	for node in get_tree().get_nodes_in_group("local_player")+get_tree().get_nodes_in_group("network_player"):
		var hero := node as Node3D
		if hero==null: continue
		if hero.has_meta("network_peer_id") and not bool(hero.get("_network_state_ready")): continue
		var point: Vector3 = hero.get_network_authoritative_position() if hero.has_method("get_network_authoritative_position") else hero.global_position
		var distance := global_position.distance_squared_to(point)
		if distance<best:
			best = distance
			chosen = hero
	best = sqrt(best)
	if not is_in_group("rpg_boss"):
		for node in get_tree().get_nodes_in_group("rpg_companion"):
			var mate := node as Node3D
			if mate==null or not mate.visible or bool(mate.get("downed")): continue
			var span := global_position.distance_to(mate.global_position)
			if span<best-COMPANION_AGGRO_EDGE and span<COMPANION_AGGRO_RANGE:
				best = span
				chosen = mate
	_target = chosen


func _posicion_objetivo() -> Vector3:
	if _target!=null and _target.has_method("get_network_authoritative_position"):
		return _target.get_network_authoritative_position()
	return _target.global_position if _target!=null else global_position


func _danar_objetivo(cantidad: int) -> void:
	if _target!=null and _target.is_in_group("rpg_companion"):
		if _target.has_method("take_hit"): _target.take_hit(cantidad)
		return
	if _target!=null and _target.has_meta("network_peer_id"):
		get_node("/root/NetworkSession").enviar_dano_combate(int(_target.get_meta("network_peer_id")),cantidad,global_position,display_name)
	elif story_runtime!=null:
		story_runtime.damage_player(cantidad,global_position,display_name)


func _hit_player() -> void:
	_danar_objetivo(attack_damage)


func _set_guard(up: bool) -> void:
	_guard_up = up and style == Style.GUARD


func _set_fade(on: bool) -> void:
	if _visual == null:
		return
	_visual.visible = not on or (Engine.get_physics_frames() % 12 < 6)


func _shake_grass() -> void:
	var world := get_parent()
	if world == null:
		return
	var scatter := world.get_node_or_null("../VegetationScatter")
	if scatter != null and scatter.has_method("flatten_grass_burst"):
		scatter.call("flatten_grass_burst", global_position, burst_radius * 1.4, 1.1)


func _stand_on_terrain() -> void:
	## La cota se lee del terreno en vez de caer por gravedad. Ver la nota de
	## cabecera: sin esto el enemigo se desploma en cuanto se aleja del héroe.
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain")
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
	if is_nan(height):
		return
	global_position.y = height + foot_offset


func receive_tool_hit(category: String, item_id: String, hit_position: Vector3, attacker: Node) -> void:
	if dead or not _is_authority():
		return
	# El grado del arma manda. Con la regla vieja —un `+2` si el nombre contenía
	# "Golden" o "big"— la espada dorada grande pegaba lo mismo que la dorada, y
	# la última mejora de la forja no se notaba.
	var fallback := 1
	match category:
		"sword": fallback = 3
		"axe": fallback = 2
		"bow": fallback = 2
	var damage := RPGForge.weapon_damage(item_id, fallback)
	var spinning := attacker != null and attacker.has_method("is_spin_attacking") \
		and bool(attacker.call("is_spin_attacking"))
	# La guardia del castillo sólo cubre por delante: se rodea o se abre con el
	# giro cargado. Y a un espectro desvanecido el acero apenas le entra.
	if _guard_up and not spinning and _hit_from_front(hit_position):
		damage = 1
	if _faded > 0.0 and not spinning:
		damage = maxi(1, damage / 2)
	_take_damage(damage, hit_position, attacker)


func _hit_from_front(hit_position: Vector3) -> bool:
	var towards := hit_position - global_position
	towards.y = 0.0
	if towards.length() < 0.05:
		return true
	return towards.normalized().dot(-global_basis.z) > 0.25


func receive_projectile_hit(hit_position: Vector3, shooter: Node) -> void:
	if not _is_authority(): return
	_take_damage(3, hit_position, shooter)


func get_network_state() -> Dictionary:
	return {
		"id": enemy_id, "position": global_position, "yaw": rotation.y,
		"health": health, "dead": dead,
		"anim": String(_animator.current_animation) if _animator!=null else "",
	}


func apply_network_state(state: Dictionary) -> void:
	if _is_authority():
		return
	var posicion: Vector3 = state.get("position",global_position)
	var giro := float(state.get("yaw",rotation.y))
	# La mayoría están quietos. Reescribir su transformación enviaba trabajo a
	# física y render aunque el paquete no hubiese cambiado ni un vértice.
	if posicion!=global_position: global_position = posicion
	if giro!=rotation.y: rotation.y = giro
	health = int(state.get("health", health))
	var animation := String(state.get("anim",""))
	if not dead and not animation.is_empty(): _play_animation([animation])
	if bool(state.get("dead", false)) and not dead:
		_die()


func _take_damage(amount: int, hit_position: Vector3, attacker: Node) -> void:
	if dead or not _is_authority():
		return
	health = maxi(0, health - maxi(1, amount))
	health_changed.emit(health, max_health)
	_play_animation(["Hit", "Damage", "Idle"])
	var away := global_position - hit_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		velocity += away.normalized() * 2.6
	if attacker != null and attacker.has_signal("action_feedback"):
		attacker.emit_signal("action_feedback", "%s · %d/%d" % [display_name, health, max_health])
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector3.ZERO
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	_play_animation(["Death", "Die", "Hit"])
	defeated.emit(enemy_id, reward_item_id)
	if story_runtime != null:
		story_runtime.call("on_enemy_defeated", self)
		# Que caer se vea. Sin esto el bicho se encoge en silencio y no parece
		# que hayas hecho nada.
		story_runtime.call("burst_sparks", global_position + Vector3.UP * 1.1,
			Color(0.96, 0.62, 0.34), 26, 6.2, 0.55)
		story_runtime.call("shake_camera", global_position, 0.11, 34.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "rotation:z", rotation.z + deg_to_rad(82.0), 0.48)
	tween.tween_property(self, "scale", Vector3.ONE * 0.18, 1.8).set_delay(0.65)
	tween.chain().tween_interval(2.0)
	tween.chain().tween_callback(queue_free)


func _try_attack() -> void:
	if _attack_cooldown > 0.0 or story_runtime == null:
		return
	_attack_cooldown = 1.25
	_play_animation(["Attack", "Bite", "Idle"])
	_danar_objetivo(attack_damage)


func _is_authority() -> bool:
	if story_runtime != null and story_runtime.has_method("is_world_authority"):
		return bool(story_runtime.call("is_world_authority"))
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "EnemyCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)


func _build_visual() -> void:
	var packed := load(monster_path) as PackedScene
	if packed != null:
		_visual = packed.instantiate() as Node3D
	if _visual == null:
		_visual = Node3D.new()
		var mesh_instance := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.52
		mesh.height = 1.5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.31, 0.08, 0.38)
		mesh.material = material
		mesh_instance.mesh = mesh
		mesh_instance.position.y = 0.85
		_visual.add_child(mesh_instance)
	_visual.name = "MonsterVisual"
	_visual.scale = Vector3.ONE * 1.12
	add_child(_visual)
	_animator = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_animation(["Idle", "Flying"])


func _build_nameplate() -> void:
	var label := Label3D.new()
	label.name = "EnemyName"
	label.text = "%s  ◆  %d" % [display_name, max_health]
	label.position.y = 2.25
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 7
	label.modulate = Color(1.0, 0.35, 0.3)
	label.visibility_range_end = 28.0
	add_child(label)


func _play_animation(candidates: Array[String]) -> void:
	if _animator == null:
		return
	for candidate in candidates:
		if _animator.has_animation(candidate):
			if _animator.current_animation != candidate:
				_animator.play(candidate, 0.16)
			return
