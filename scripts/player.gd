class_name Player
extends CharacterBody3D

## Controlador sencillo en tercera persona.
## La dirección de movimiento se calcula desde la cámara, no desde el mundo:
## por eso W siempre hace avanzar al personaje hacia donde está mirando el jugador.

@export_category("Movimiento")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var acceleration: float = 22.0
@export var air_acceleration: float = 7.0
@export var jump_velocity: float = 5.3
@export var turn_speed: float = 12.0

@export_category("Seguridad")
@export var respawn_height: float = -12.0

@onready var visual: Node3D = $Visual

var spawn_position: Vector3


func _ready() -> void:
	spawn_position = global_position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	move_and_slide()

	if global_position.y < respawn_height:
		_respawn()


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

