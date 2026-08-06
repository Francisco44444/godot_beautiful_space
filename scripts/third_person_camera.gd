class_name ThirdPersonCamera
extends Node3D

## Cámara orbital independiente del giro del personaje.
## SpringArm3D acerca automáticamente la cámara cuando hay una pared detrás.

@export var target_path: NodePath
@export var target_height: float = 1.85
@export var mouse_sensitivity: float = 0.003
@export var follow_speed: float = 12.0
@export var min_pitch_degrees: float = -55.0
@export var max_pitch_degrees: float = 30.0
@export_category("Vista montada")
@export var mounted_target_height: float = 3.15
@export var mounted_distance: float = 16.0
@export var mounted_fov: float = 78.0
@export var riding_transition_speed: float = 4.5

@onready var target: Node3D = get_node(target_path) as Node3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = deg_to_rad(-14.0)
var _current_height: float
var _foot_distance: float
var _foot_fov: float


func _ready() -> void:
	_current_height = target_height
	_foot_distance = spring_arm.spring_length
	_foot_fov = camera.fov
	global_position = target.global_position + Vector3.UP * target_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var player := target as Player
	var riding := player != null and player.is_mounted()
	var active_target := player.get_camera_target() if player != null else target
	var desired_height := mounted_target_height if riding else target_height
	var desired_distance := mounted_distance if riding else _foot_distance
	var desired_fov := mounted_fov if riding else _foot_fov
	var riding_weight := 1.0 - exp(-riding_transition_speed * delta)

	_current_height = lerpf(_current_height, desired_height, riding_weight)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, desired_distance, riding_weight)
	camera.fov = lerpf(camera.fov, desired_fov, riding_weight)

	var desired_position := active_target.global_position + Vector3.UP * _current_height
	# Esta forma exponencial mantiene la misma sensación a cualquier tasa de fotogramas.
	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, follow_weight)
	rotation = Vector3(pitch, yaw, 0.0)
