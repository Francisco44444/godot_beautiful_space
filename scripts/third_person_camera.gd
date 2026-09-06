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
@export_category("Apuntado con arco")
@export var aiming_distance: float = 2.9
@export var aiming_fov: float = 60.0
@export var aiming_target_height: float = 1.56
## Vista claramente diagonal sobre el hombro. Con el desplazamiento corto de
## antes el héroe tapaba el arco y la flecha salía justo por detrás de su
## cabeza, así que el disparo no se veía nunca.
@export var aiming_side_offset: float = -1.35

@onready var target: Node3D = get_node(target_path) as Node3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = deg_to_rad(-14.0)
var _current_height: float
var _foot_distance: float
var _foot_fov: float
var _aiming := false
var _current_side_offset := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var shake_count := 0


func _ready() -> void:
	add_to_group("camera_rig")
	_current_height = target_height
	_foot_distance = spring_arm.spring_length
	_foot_fov = camera.fov
	global_position = target.global_position + Vector3.UP * target_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func snap_to_target() -> void:
	## Evita que la cámara atraviese kilómetros de escenario después de un viaje rápido.
	var player := target as Player
	var riding := player != null and player.is_mounted()
	var active_target := player.get_camera_target() if player != null else target
	_current_height = mounted_target_height if riding else target_height
	spring_arm.spring_length = mounted_distance if riding else _foot_distance
	camera.fov = mounted_fov if riding else _foot_fov
	global_position = active_target.global_position + Vector3.UP * _current_height


func set_aiming(active: bool) -> void:
	_aiming = active


func is_aiming() -> bool:
	return _aiming


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## El golpe se siente en la cámara o no se siente. El desplazamiento va con el
## CUADRADO del trauma: así un roce apenas mueve nada y un pisotón sacude de
## verdad, en vez de que todo tiemble igual.
const MAX_SHAKE_PITCH := 0.055
const MAX_SHAKE_YAW := 0.075
const MAX_SHAKE_ROLL := 0.09
const TRAUMA_FADE := 1.35


func add_shake(amount: float) -> void:
	if amount <= 0.0:
		return
	_trauma = minf(1.0, _trauma + amount)
	shake_count += 1


## Sacudida a distancia: un pisotón a 40 m no puede moverte la cámara igual que
## uno en la cara.
func add_shake_from(point: Vector3, amount: float, reach: float) -> void:
	var span := global_position.distance_to(point)
	if span >= reach:
		return
	add_shake(amount * (1.0 - span / reach))


func _shake_offset(delta: float) -> Vector3:
	if _trauma <= 0.0:
		return Vector3.ZERO
	# En segundos REALES: durante la cámara lenta del golpe final la escala de
	# tiempo baja a 0,16 y con delta a secas la sacudida duraría seis veces más.
	var real := delta / maxf(Engine.time_scale, 0.01)
	_trauma = maxf(0.0, _trauma - TRAUMA_FADE * real)
	_shake_time += real * 34.0
	var force := _trauma * _trauma
	return Vector3(
		sin(_shake_time * 1.7) * MAX_SHAKE_PITCH,
		sin(_shake_time * 2.3 + 1.1) * MAX_SHAKE_YAW,
		sin(_shake_time * 2.9 + 2.4) * MAX_SHAKE_ROLL) * force


func _physics_process(delta: float) -> void:
	var player := target as Player
	var riding := player != null and player.is_mounted()
	var active_target := player.get_camera_target() if player != null else target
	var aiming_active := _aiming and not riding
	var desired_height := mounted_target_height if riding else (aiming_target_height if aiming_active else target_height)
	var desired_distance := mounted_distance if riding else (aiming_distance if aiming_active else _foot_distance)
	var desired_fov := mounted_fov if riding else (aiming_fov if aiming_active else _foot_fov)
	var desired_side_offset := aiming_side_offset if aiming_active else 0.0
	var riding_weight := 1.0 - exp(-riding_transition_speed * delta)

	_current_height = lerpf(_current_height, desired_height, riding_weight)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, desired_distance, riding_weight)
	camera.fov = lerpf(camera.fov, desired_fov, riding_weight)
	_current_side_offset = lerpf(_current_side_offset, desired_side_offset, riding_weight)
	spring_arm.position.x = _current_side_offset

	var desired_position := active_target.global_position + Vector3.UP * _current_height
	# Esta forma exponencial mantiene la misma sensación a cualquier tasa de fotogramas.
	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, follow_weight)
	rotation = Vector3(pitch, yaw, 0.0) + _shake_offset(delta)
