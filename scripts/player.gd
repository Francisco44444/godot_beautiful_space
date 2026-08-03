class_name Player
extends CharacterBody3D

## Controlador sencillo en tercera persona.
## La dirección de movimiento se calcula desde la cámara, no desde el mundo:
## por eso W siempre hace avanzar al personaje hacia donde está mirando el jugador.

signal mount_state_changed(mounted: bool, horse: Horse)

enum ControlState {
	ON_FOOT,
	MOUNTED,
}

@export_category("Movimiento")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 22.0
@export var air_acceleration: float = 7.0
@export var jump_velocity: float = 5.3
@export var turn_speed: float = 12.0

@export_category("Seguridad")
@export var respawn_height: float = -12.0

@export_category("Montura")
@export var mount_distance: float = 3.6
@export var dismount_offset: float = 1.65

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $Collision

var spawn_position: Vector3
var control_state := ControlState.ON_FOOT
var current_mount: Horse


func _ready() -> void:
	spawn_position = global_position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)


func _physics_process(delta: float) -> void:
	if control_state == ControlState.MOUNTED:
		_sync_with_mount()
		if Input.is_action_just_pressed("interact"):
			dismount()
		return

	if Input.is_action_just_pressed("interact"):
		var nearby_horse := get_nearby_mount()
		if nearby_horse != null:
			mount_horse(nearby_horse)
			return

	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	move_and_slide()

	if global_position.y < respawn_height:
		_respawn()


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
	if control_state != ControlState.ON_FOOT or horse == null or horse.mounted:
		return false

	current_mount = horse
	control_state = ControlState.MOUNTED
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	horse.set_mounted(true)

	# El placeholder del jugador se convierte en jinete al pasar al ancla de la silla.
	visual.reparent(horse.rider_anchor, false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	global_position = horse.global_position
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
	mount_state_changed.emit(false, horse)
	return true


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
		# Godot expone la gravedad configurada del proyecto como un vector.
		velocity += get_gravity() * delta


func _apply_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
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
		camera_forward = camera_forward.normalized()
		camera_right = camera_right.normalized()
		direction = (camera_right * input_vector.x - camera_forward * input_vector.y).normalized()

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * target_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)

	if direction.length_squared() > 0.0:
		# El modelo tiene su frente hacia -Z. Interpolamos el giro para evitar tirones.
		var desired_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, turn_speed * delta)


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
