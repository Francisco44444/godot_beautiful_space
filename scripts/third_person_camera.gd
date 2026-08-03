class_name ThirdPersonCamera
extends Node3D

## Cámara orbital independiente del giro del personaje.
## SpringArm3D acerca automáticamente la cámara cuando hay una pared detrás.

@export var target_path: NodePath
@export var target_height: float = 1.35
@export var mouse_sensitivity: float = 0.003
@export var follow_speed: float = 12.0
@export var min_pitch_degrees: float = -55.0
@export var max_pitch_degrees: float = 30.0

@onready var target: Node3D = get_node(target_path) as Node3D

var yaw: float = 0.0
var pitch: float = deg_to_rad(-18.0)


func _ready() -> void:
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
	var desired_position := target.global_position + Vector3.UP * target_height
	# Esta forma exponencial mantiene la misma sensación a cualquier tasa de fotogramas.
	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, follow_weight)
	rotation = Vector3(pitch, yaw, 0.0)

