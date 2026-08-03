class_name Horse
extends CharacterBody3D

## Montura controlable de la Fase 4.
## El caballo conserva su propia física: Player solo activa o desactiva el control
## y coloca su representación visual sobre RiderAnchor.

@export_category("Movimiento")
@export var walk_speed: float = 6.0
@export var canter_speed: float = 10.5
@export var gallop_speed: float = 15.5
@export var acceleration: float = 11.0
@export var braking: float = 16.0
@export var turn_speed: float = 5.0

@export_category("Identidad")
@export var horse_name: String = "Brisa"
@export var respawn_height: float = -12.0

@onready var visual: Node3D = $Visual
@onready var body_pivot: Node3D = $Visual/BodyPivot
@onready var rider_anchor: Marker3D = $Visual/BodyPivot/RiderAnchor
@onready var name_label: Label3D = $NameLabel
@onready var leg_pivots: Array[Node3D] = [
	$Visual/FrontLeftLeg,
	$Visual/FrontRightLeg,
	$Visual/BackLeftLeg,
	$Visual/BackRightLeg,
]

var spawn_position: Vector3
var mounted := false
var _stride_time := 0.0
var _body_base_height := 0.0


func _ready() -> void:
	spawn_position = global_position
	_body_base_height = body_pivot.position.y
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48.0)
	# La acción contextual vive en el HUD y solo aparece cuando está al alcance.
	name_label.text = horse_name.to_upper()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if mounted:
		_apply_riding_input(delta)
	else:
		_slow_to_stop(delta)

	move_and_slide()
	_animate_placeholder(delta)

	if global_position.y < respawn_height:
		global_position = spawn_position
		velocity = Vector3.ZERO


func set_mounted(value: bool) -> void:
	mounted = value
	name_label.visible = not mounted
	if not mounted:
		# El caballo no se detiene en seco al desmontar; pierde inercia suavemente.
		velocity.x *= 0.45
		velocity.z *= 0.45


func get_facing_yaw() -> float:
	return visual.rotation.y


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _apply_riding_input(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_strength := clampf(input_vector.length(), 0.0, 1.0)
	var direction := _camera_relative_direction(input_vector)

	var cruising_speed := lerpf(walk_speed, canter_speed, input_strength)
	var target_speed := gallop_speed if Input.is_action_pressed("sprint") else cruising_speed
	var target_velocity := direction * target_speed * input_strength
	var change_rate := acceleration if input_strength > 0.0 else braking

	velocity.x = move_toward(velocity.x, target_velocity.x, change_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, change_rate * delta)

	if direction.length_squared() > 0.0:
		var desired_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, turn_speed * delta)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.length_squared() <= 0.0:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	var camera_forward := -camera.global_basis.z
	var camera_right := camera.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	return (camera_right.normalized() * input_vector.x - camera_forward.normalized() * input_vector.y).normalized()


func _slow_to_stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	velocity.z = move_toward(velocity.z, 0.0, braking * delta)


func _animate_placeholder(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var motion_amount := clampf(horizontal_speed / gallop_speed, 0.0, 1.0)
	_stride_time += delta * lerpf(2.5, 10.0, motion_amount)

	# Dos pares diagonales alternos sugieren paso y galope sin usar assets externos.
	for index in leg_pivots.size():
		var phase := 0.0 if index in [0, 3] else PI
		var swing := sin(_stride_time + phase) * 0.48 * motion_amount
		leg_pivots[index].rotation.x = lerpf(leg_pivots[index].rotation.x, swing, 0.35)

	var bob := absf(sin(_stride_time * 2.0)) * 0.075 * motion_amount
	body_pivot.position.y = lerpf(body_pivot.position.y, _body_base_height + bob, 0.3)
