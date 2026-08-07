class_name Player
extends CharacterBody3D

## Aventurero Quaternius en tercera persona. Mantiene la máquina de estados
## a pie/montado y añade combate cuerpo a cuerpo con cuchillo.

signal mount_state_changed(mounted: bool, horse: Horse)
signal attack_started(combo_index: int)
signal melee_hit(target: Node)

enum ControlState {
	ON_FOOT,
	MOUNTED,
}

const KNIFE_OBJ_PATH := "res://assets/quaternius/Survival Pack - Sept 2020/OBJ/Knife.obj"
const OBJ_LOADER: Script = preload("res://scripts/quaternius_obj_loader.gd")

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walk"
const ANIM_RUN := "Run"
const ANIM_JUMP := "Jump"
const ANIM_ATTACK := "SwordSlash"
const ANIM_SIT := "SitDown"
const REALISTIC_IDLE := ANIM_IDLE

@export_category("Movimiento")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 10.0
@export var acceleration: float = 26.0
@export var air_acceleration: float = 7.0
@export var jump_velocity: float = 5.3
@export var turn_speed: float = 12.0
@export var walk_animation_rate: float = 1.42
@export var run_animation_rate: float = 1.18

@export_category("Combate")
@export var attack_duration: float = 0.78
@export var attack_hit_start: float = 0.16
@export var attack_hit_end: float = 0.54
@export var attack_recovery: float = 0.18

@export_category("Seguridad")
@export var respawn_height: float = -12.0

@export_category("Quaternius")
@export_file("*.gltf") var quaternius_hero_path := "res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Male.gltf"
@export var hero_skin_color := Color("d87842")

@export_category("Montura")
@export var mount_distance: float = 3.6
@export var dismount_offset: float = 1.65

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $Collision
@onready var model_root: Node3D = $Visual/ModelRoot
@onready var attack_area: Area3D = $Visual/AttackArea
@onready var attack_shape: CollisionShape3D = $Visual/AttackArea/CollisionShape3D

var skeleton: Skeleton3D
var character_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var realistic_pose: Node3D
var realistic_model: Node3D
var realistic_skeleton: Skeleton3D
var realistic_animation: AnimationPlayer
var spawn_position: Vector3
var control_state := ControlState.ON_FOOT
var current_mount: Horse
var is_attacking := false
var attacks_performed := 0
var _attack_time := 0.0
var _attack_cooldown := 0.0
var _attack_hits: Dictionary = {}
var _realistic_stride := 0.0
var _weapon_grip: Node3D
var _weapon_base_rotation := Vector3.ZERO
var skin_surface_count := 0


func _ready() -> void:
	spawn_position = global_position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	attack_shape.disabled = true
	_load_quaternius_hero()
	model_root.visible = true
	_configure_realistic_hero()
	_attach_knife_to_hand()
	_configure_animation_loops()
	_play_animation(ANIM_IDLE, 0.0)


func _process(delta: float) -> void:
	_update_realistic_visual(delta)


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if control_state == ControlState.MOUNTED:
		_sync_with_mount()
		if Input.is_action_just_pressed("interact"):
			dismount()
		return

	if Input.is_action_just_pressed("attack"):
		start_attack()
	if Input.is_action_just_pressed("interact") and not is_attacking:
		var nearby_horse := get_nearby_mount()
		if nearby_horse != null:
			mount_horse(nearby_horse)
			return

	_update_attack(delta)
	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	move_and_slide()
	_update_locomotion_animation()

	if global_position.y < respawn_height:
		_respawn()


func start_attack() -> bool:
	if is_mounted() or is_attacking or _attack_cooldown > 0.0:
		return false
	is_attacking = true
	_attack_time = 0.0
	_attack_hits.clear()
	attacks_performed += 1
	_play_animation(ANIM_ATTACK, 0.06, 1.45)
	attack_started.emit(attacks_performed)
	return true


func is_mounted() -> bool:
	return control_state == ControlState.MOUNTED and is_instance_valid(current_mount)


func get_camera_target() -> Node3D:
	return current_mount if is_mounted() else self


func get_nearby_mount() -> Horse:
	var nearest: Horse
	var nearest_distance := mount_distance
	for node in get_tree().get_nodes_in_group("mountable"):
		var horse := node as Horse
		if horse == null or horse.mounted:
			continue
		var distance := global_position.distance_to(horse.global_position)
		if distance <= nearest_distance:
			nearest = horse
			nearest_distance = distance
	return nearest


func mount_horse(horse: Horse) -> bool:
	if control_state != ControlState.ON_FOOT or horse == null or horse.mounted or is_attacking:
		return false

	current_mount = horse
	control_state = ControlState.MOUNTED
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	attack_shape.set_deferred("disabled", true)
	horse.set_mounted(true)
	visual.reparent(horse.rider_anchor, false)
	# El rig conserva la colisión a pie, pero hundimos las piernas en la montura
	# para que el torso quede sentado sobre la silla real del caballo.
	visual.position = Vector3(0.0, -0.15, 0.08)
	visual.rotation = Vector3.ZERO
	global_position = horse.global_position
	_play_animation(ANIM_SIT, 0.12, 1.25)
	mount_state_changed.emit(true, horse)
	return true


func dismount() -> bool:
	if not is_mounted():
		return false

	var horse := current_mount
	var exit_direction := horse.visual.global_basis.x.normalized()
	visual.reparent(self, false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3(0.0, horse.get_facing_yaw(), 0.0)
	global_position = horse.global_position + exit_direction * dismount_offset + Vector3.UP * 0.35
	velocity = Vector3.ZERO
	control_state = ControlState.ON_FOOT
	current_mount = null
	collision.set_deferred("disabled", false)
	horse.set_mounted(false)
	_play_animation(ANIM_IDLE, 0.12)
	mount_state_changed.emit(false, horse)
	return true


func _update_attack(delta: float) -> void:
	if not is_attacking:
		attack_shape.disabled = true
		return
	_attack_time += delta
	var active := _attack_time >= attack_hit_start and _attack_time <= attack_hit_end
	attack_shape.disabled = not active
	if active:
		_apply_melee_hits()
	if _attack_time >= attack_duration:
		is_attacking = false
		attack_shape.disabled = true
		_attack_cooldown = attack_recovery


func _apply_melee_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body == self or _attack_hits.has(body.get_instance_id()):
			continue
		_attack_hits[body.get_instance_id()] = true
		if body.has_method("receive_melee_hit"):
			body.call("receive_melee_hit", attack_area.global_position)
		melee_hit.emit(body)


func _sync_with_mount() -> void:
	if not is_instance_valid(current_mount):
		control_state = ControlState.ON_FOOT
		current_mount = null
		collision.set_deferred("disabled", false)
		return
	global_position = current_mount.global_position
	velocity = current_mount.velocity


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _apply_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity


func _apply_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	if camera != null and input_vector.length_squared() > 0.0:
		var camera_forward := -camera.global_basis.z
		var camera_right := camera.global_basis.x
		camera_forward.y = 0.0
		camera_right.y = 0.0
		direction = (camera_right.normalized() * input_vector.x - camera_forward.normalized() * input_vector.y).normalized()

	var target_speed := sprint_speed if _is_sprint_pressed() else walk_speed
	if is_attacking:
		target_speed *= 0.28
	var target_velocity := direction * target_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)
	if direction.length_squared() > 0.0:
		var desired_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, turn_speed * delta)


func _update_locomotion_animation() -> void:
	if is_attacking:
		return
	if not is_on_floor():
		_play_animation(ANIM_JUMP, 0.1)
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > walk_speed + 0.8:
		_play_animation(ANIM_RUN, 0.10, clampf(horizontal_speed / sprint_speed * run_animation_rate, 0.95, 1.48))
	elif horizontal_speed > 0.25:
		_play_animation(ANIM_WALK, 0.10, clampf(horizontal_speed / walk_speed * walk_animation_rate, 0.82, 1.68))
	else:
		_play_animation(ANIM_IDLE, 0.18)


func _play_animation(animation_name: String, blend: float, speed: float = 1.0) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, blend, speed)
	else:
		animation_player.speed_scale = speed


func _configure_animation_loops() -> void:
	if animation_player == null:
		return
	for animation_name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func _configure_realistic_hero() -> void:
	if realistic_animation == null:
		return
	if realistic_animation.has_animation(REALISTIC_IDLE):
		var idle := realistic_animation.get_animation(REALISTIC_IDLE)
		idle.loop_mode = Animation.LOOP_LINEAR
		realistic_animation.play(REALISTIC_IDLE)


func _update_realistic_visual(delta: float) -> void:
	if realistic_pose == null:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var motion_amount := clampf(horizontal_speed / sprint_speed, 0.0, 1.0)
	_realistic_stride += delta * lerpf(2.2, 8.5, motion_amount)
	var desired_position := Vector3.ZERO
	var desired_rotation := Vector3.ZERO
	var desired_weapon_rotation := _weapon_base_rotation

	if is_mounted():
		desired_position.y = sin(_realistic_stride * 2.0) * 0.018
		desired_rotation.x = deg_to_rad(-4.0)
	elif is_attacking:
		var phase := clampf(_attack_time / attack_duration, 0.0, 1.0)
		var strike := sin(phase * PI)
		var follow_through := sin(phase * PI * 0.72)
		var slash_progress := smoothstep(0.04, 0.78, phase)
		desired_position.z = -0.18 * strike
		desired_rotation.y = deg_to_rad(32.0 * strike - 12.0 * follow_through)
		desired_rotation.z = deg_to_rad(-8.0 * strike)
		# La hoja parte armada junto al hombro y recorre casi 180 grados hasta
		# terminar al otro lado del cuerpo durante la ventana de impacto.
		desired_weapon_rotation.y += deg_to_rad(22.0 * strike)
		desired_weapon_rotation.z += deg_to_rad(lerpf(64.0, -118.0, slash_progress))
	else:
		desired_position.y = absf(sin(_realistic_stride)) * 0.035 * motion_amount
		desired_rotation.x = deg_to_rad(-5.5 * motion_amount)
		desired_rotation.z = deg_to_rad(sin(_realistic_stride * 0.5) * 1.8 * motion_amount)

	var blend := 1.0 - exp(-14.0 * delta)
	realistic_pose.position = realistic_pose.position.lerp(desired_position, blend)
	realistic_pose.rotation = realistic_pose.rotation.lerp(desired_rotation, blend)
	if _weapon_grip != null:
		_weapon_grip.rotation = _weapon_grip.rotation.lerp(desired_weapon_rotation, blend)
	if realistic_animation != null:
		realistic_animation.speed_scale = lerpf(0.72, 1.25, motion_amount)


func _attach_knife_to_hand() -> void:
	# El cuchillo del Survival Pack vive sobre un pivote independiente para que
	# el tajo sea legible sin alterar el rig importado del caballero.
	var grip := Node3D.new()
	grip.name = "KnifeGrip"
	grip.position = Vector3(-0.34, 1.30, -0.13)
	grip.rotation_degrees = Vector3(72.0, 0.0, -12.0)
	realistic_pose.add_child(grip)
	var knife := MeshInstance3D.new()
	knife.name = "EquippedKnife"
	knife.mesh = OBJ_LOADER.load_mesh(KNIFE_OBJ_PATH)
	if knife.mesh == null:
		knife.queue_free()
		return
	knife.scale = Vector3.ONE * 0.58
	grip.add_child(knife)
	_configure_knife_materials(knife)
	_weapon_grip = grip
	_weapon_base_rotation = grip.rotation


func _load_quaternius_hero() -> void:
	var loaded_scene := _load_gltf_scene(quaternius_hero_path)
	if loaded_scene != null:
		model_root.add_child(loaded_scene)
		loaded_scene.rotation_degrees.y = 180.0
		_recolor_hero_skin(loaded_scene)
		loaded_scene.set_meta("character_source", quaternius_hero_path)
	realistic_pose = model_root
	realistic_model = model_root
	skeleton = _find_skeleton(model_root)
	character_mesh = _find_visible_mesh(model_root)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	realistic_skeleton = skeleton
	realistic_animation = animation_player


func _recolor_hero_skin(loaded_scene: Node3D) -> void:
	# Cowboy_Male trae la cabeza casi negra en el material Skin. Ojos, cejas y
	# bigote usan Face/Hair, por lo que se conservan al aplicar un tono humano.
	skin_surface_count = 0
	var mesh_nodes: Array[Node] = loaded_scene.find_children("*", "MeshInstance3D", true, false)
	if loaded_scene is MeshInstance3D:
		mesh_nodes.push_front(loaded_scene)
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != "Skin":
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.albedo_color = hero_skin_color
			material.metallic = 0.0
			material.roughness = 0.86
			material.set_meta("human_skin_recolor", true)
			mesh_instance.set_surface_override_material(surface, material)
			mesh_instance.set_meta("human_skin_recolored", true)
			skin_surface_count += 1


func _load_gltf_scene(path: String) -> Node3D:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el modelo Quaternius: %s" % path)
		return null
	var node := document.generate_scene(state)
	return node as Node3D


func _configure_knife_materials(knife_mesh: MeshInstance3D) -> void:
	for surface in knife_mesh.mesh.get_surface_count():
		var source := knife_mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		material.roughness = 0.22 if surface in [1, 2] else 0.74
		material.metallic = 0.92 if surface in [1, 2] else 0.04
		knife_mesh.set_surface_override_material(surface, material)


func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)


func _find_skeleton(parent: Node) -> Skeleton3D:
	for node in parent.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _find_visible_mesh(parent: Node) -> MeshInstance3D:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			return mesh_instance
	return null


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
