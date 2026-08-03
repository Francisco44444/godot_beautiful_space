class_name Player
extends CharacterBody3D

## Aventurero medieval original en tercera persona. Mantiene la máquina de
## estados a pie/montado y añade combate cuerpo a cuerpo con espada.

signal mount_state_changed(mounted: bool, horse: Horse)
signal attack_started(combo_index: int)
signal sword_hit(target: Node)

enum ControlState {
	ON_FOOT,
	MOUNTED,
}

const SWORD_SCENE: PackedScene = preload("res://assets/models/medieval_hero/Sword.fbx")
const WOOL_ALBEDO: Texture2D = preload("res://assets/textures/medieval/forest_wool_albedo.png")
const WOOL_NORMAL_ROUGHNESS: Texture2D = preload("res://assets/textures/medieval/forest_wool_normal_roughness.png")
const LEATHER_ALBEDO: Texture2D = preload("res://assets/textures/medieval/aged_leather_albedo.png")
const LEATHER_NORMAL_ROUGHNESS: Texture2D = preload("res://assets/textures/medieval/aged_leather_normal_roughness.png")

const ANIM_IDLE := "HumanArmature|Idle_swordRight"
const ANIM_WALK := "HumanArmature|Walking"
const ANIM_RUN := "HumanArmature|Run_swordRight"
const ANIM_JUMP := "HumanArmature|Jump"
const ANIM_ATTACK := "HumanArmature|swordAttackJump"

@export_category("Movimiento")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 22.0
@export var air_acceleration: float = 7.0
@export var jump_velocity: float = 5.3
@export var turn_speed: float = 12.0

@export_category("Combate")
@export var attack_duration: float = 0.78
@export var attack_hit_start: float = 0.16
@export var attack_hit_end: float = 0.54
@export var attack_recovery: float = 0.18

@export_category("Seguridad")
@export var respawn_height: float = -12.0

@export_category("Montura")
@export var mount_distance: float = 3.6
@export var dismount_offset: float = 1.65

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $Collision
@onready var model_root: Node3D = $Visual/ModelRoot
@onready var skeleton: Skeleton3D = $Visual/ModelRoot/HumanArmature/Skeleton3D
@onready var character_mesh: MeshInstance3D = $Visual/ModelRoot/HumanArmature/Skeleton3D/Knight
@onready var animation_player: AnimationPlayer = $Visual/ModelRoot/AnimationPlayer
@onready var attack_area: Area3D = $Visual/AttackArea
@onready var attack_shape: CollisionShape3D = $Visual/AttackArea/CollisionShape3D

var spawn_position: Vector3
var control_state := ControlState.ON_FOOT
var current_mount: Horse
var is_attacking := false
var attacks_performed := 0
var _attack_time := 0.0
var _attack_cooldown := 0.0
var _attack_hits: Dictionary = {}


func _ready() -> void:
	spawn_position = global_position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	attack_shape.disabled = true
	_configure_character_materials()
	_attach_sword_to_hand()
	_configure_animation_loops()
	_play_animation(ANIM_IDLE, 0.0)


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
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	global_position = horse.global_position
	_play_animation(ANIM_IDLE, 0.12)
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
		_apply_sword_hits()
	if _attack_time >= attack_duration:
		is_attacking = false
		attack_shape.disabled = true
		_attack_cooldown = attack_recovery


func _apply_sword_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body == self or _attack_hits.has(body.get_instance_id()):
			continue
		_attack_hits[body.get_instance_id()] = true
		if body.has_method("receive_sword_hit"):
			body.call("receive_sword_hit", attack_area.global_position)
		sword_hit.emit(body)


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

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
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
		_play_animation(ANIM_RUN, 0.12, horizontal_speed / sprint_speed)
	elif horizontal_speed > 0.25:
		_play_animation(ANIM_WALK, 0.12, horizontal_speed / walk_speed)
	else:
		_play_animation(ANIM_IDLE, 0.18)


func _play_animation(animation_name: String, blend: float, speed: float = 1.0) -> void:
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, blend, speed)
	else:
		animation_player.speed_scale = speed


func _configure_animation_loops() -> void:
	for animation_name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func _configure_character_materials() -> void:
	character_mesh.set_surface_override_material(0, _make_pbr_material(WOOL_ALBEDO, WOOL_NORMAL_ROUGHNESS, 0.96, 0.0, Color(1.8, 2.05, 1.65, 1.0)))
	character_mesh.set_surface_override_material(2, _make_pbr_material(LEATHER_ALBEDO, LEATHER_NORMAL_ROUGHNESS, 0.82, 0.0, Color(1.3, 1.2, 1.1, 1.0)))


func _make_pbr_material(albedo: Texture2D, normal_roughness: Texture2D, roughness: float, metallic: float, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo
	material.albedo_color = tint
	material.roughness = roughness
	material.roughness_texture = normal_roughness
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	material.normal_enabled = true
	material.normal_texture = normal_roughness
	material.normal_scale = 0.72
	material.metallic = metallic
	return material


func _attach_sword_to_hand() -> void:
	var source_root := SWORD_SCENE.instantiate()
	var sword_mesh := source_root.get_node_or_null("Sword") as MeshInstance3D
	if sword_mesh == null:
		source_root.free()
		return
	source_root.remove_child(sword_mesh)
	source_root.free()
	var attachment := BoneAttachment3D.new()
	attachment.name = "SwordHandAttachment"
	attachment.bone_name = "Palm.R"
	skeleton.add_child(attachment)
	attachment.add_child(sword_mesh)
	sword_mesh.name = "EquippedSword"
	# El FBX de la espada y el esqueleto llevan conversión de centímetros. Al
	# anidarlos se compensa una de las dos escalas para conservar 1,30 m reales.
	sword_mesh.scale *= 0.01
	sword_mesh.position = Vector3(0.0, 0.0, 0.0)
	_configure_sword_materials(sword_mesh)


func _configure_sword_materials(sword_mesh: MeshInstance3D) -> void:
	for surface in sword_mesh.mesh.get_surface_count():
		var source := sword_mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		material.roughness = 0.24 if surface in [0, 2] else 0.78
		material.metallic = 0.95 if surface in [0, 2] else 0.05
		sword_mesh.set_surface_override_material(surface, material)


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
