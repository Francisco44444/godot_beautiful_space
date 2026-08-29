class_name RPGEnemy
extends CharacterBody3D

## Enemigo ligero y autoritativo. Se integra con los golpes y proyectiles del
## jugador mediante las mismas funciones que ya usan árboles y rocas.

signal defeated(enemy_id: String, reward_id: String)
signal health_changed(current: int, maximum: int)

@export var enemy_id := "shadow_orc"
@export var display_name := "Merodeador del Silencio"
@export var monster_path := "res://assets/quaternius/Ultimate Monsters/Blob/glTF/Orc.gltf"
@export var max_health := 6
@export var attack_damage := 8
@export var move_speed := 3.2
@export var detection_radius := 21.0
@export var attack_radius := 1.65
@export var reward_item_id := "Coin_Skull"
@export var reward_amount := 1

var story_runtime: Node
var health := 6
var dead := false
var _target: Node3D
var _visual: Node3D
var _animator: AnimationPlayer
var _attack_cooldown := 0.0
var _spawn_position := Vector3.ZERO
var _gravity := 9.8


func _ready() -> void:
	collision_layer = 5
	collision_mask = 1
	health = max_health
	_spawn_position = global_position
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	add_to_group("melee_target")
	add_to_group("rpg_enemy")
	_build_collision()
	_build_visual()
	_build_nameplate()


func _physics_process(delta: float) -> void:
	if dead or not _is_authority():
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("local_player") as Node3D
	if not is_instance_valid(_target):
		return
	var flat_delta := Vector3(_target.global_position.x - global_position.x, 0.0, _target.global_position.z - global_position.z)
	var distance := flat_delta.length()
	if distance <= detection_radius:
		if distance > attack_radius:
			var direction := flat_delta.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			look_at(global_position + direction, Vector3.UP, true)
			_play_animation(["Walk", "Run", "Flying", "Idle"])
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)
			_try_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 2.0 * delta)
		_play_animation(["Idle", "Flying"])
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	move_and_slide()


func receive_tool_hit(category: String, item_id: String, hit_position: Vector3, attacker: Node) -> void:
	if dead:
		return
	var damage := 1
	match category:
		"sword": damage = 3
		"axe": damage = 2
		"bow": damage = 2
	if "Golden" in item_id or "big" in item_id.to_lower():
		damage += 2
	_take_damage(damage, hit_position, attacker)


func receive_projectile_hit(hit_position: Vector3, shooter: Node) -> void:
	_take_damage(3, hit_position, shooter)


func get_network_state() -> Dictionary:
	return {
		"id": enemy_id, "position": global_position, "yaw": rotation.y,
		"health": health, "dead": dead,
	}


func apply_network_state(state: Dictionary) -> void:
	if _is_authority():
		return
	global_position = state.get("position", global_position)
	rotation.y = float(state.get("yaw", rotation.y))
	health = int(state.get("health", health))
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
	story_runtime.call("damage_player", attack_damage, global_position, display_name)


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
