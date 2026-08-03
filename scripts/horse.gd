class_name Horse
extends CharacterBody3D

## Montura controlable de la Fase 4.
## El caballo conserva su propia física: Player solo activa o desactiva el control
## y coloca su representación visual sobre RiderAnchor.

const COAT_ALBEDO: Texture2D = preload("res://assets/textures/realistic/horse_coat_albedo.png")
const COAT_NORMAL: Texture2D = preload("res://assets/textures/realistic/horse_coat_normal_roughness.png")
const HOOFBEATS: Array[AudioStream] = [
	preload("res://assets/audio/original/hoof_1.wav"),
	preload("res://assets/audio/original/hoof_2.wav"),
	preload("res://assets/audio/original/hoof_3.wav"),
	preload("res://assets/audio/original/hoof_4.wav"),
]

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
@onready var rider_anchor: Marker3D = $Visual/RiderAnchor
@onready var name_label: Label3D = $NameLabel
@onready var model_mesh: MeshInstance3D = $Visual/ModelRoot/Armature/Skeleton3D/Horse
@onready var animation_player: AnimationPlayer = $Visual/ModelRoot/AnimationPlayer
@onready var hoof_audio: AudioStreamPlayer3D = $HoofAudio

var spawn_position: Vector3
var mounted := false
var _stride_time := 0.0
var _rider_base_height := 0.0
var _hoof_timer := 0.0
var _hoof_index := 0
var hoofbeat_count := 0


func _ready() -> void:
	spawn_position = global_position
	_rider_base_height = rider_anchor.position.y
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48.0)
	# La acción contextual vive en el HUD y solo aparece cuando está al alcance.
	name_label.text = horse_name.to_upper()
	_apply_realistic_materials()
	_prepare_animation_library()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if mounted:
		_apply_riding_input(delta)
	else:
		_slow_to_stop(delta)

	move_and_slide()
	_update_animation(delta)
	_update_hoof_audio(delta)

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


func _apply_realistic_materials() -> void:
	# El modelo CC0 no trae UVs. El triplanar proyecta el pelaje en tres ejes
	# y evita estiramientos incluso al animarse el esqueleto.
	var coat := StandardMaterial3D.new()
	coat.albedo_texture = COAT_ALBEDO
	coat.albedo_color = Color(0.88, 0.82, 0.76, 1.0)
	coat.roughness = 0.72
	coat.normal_enabled = true
	coat.normal_texture = COAT_NORMAL
	coat.normal_scale = 0.32
	coat.uv1_triplanar = true
	coat.uv1_scale = Vector3(18.0, 18.0, 18.0)

	var dark_coat := coat.duplicate() as StandardMaterial3D
	dark_coat.albedo_color = Color(0.12, 0.105, 0.095, 1.0)
	dark_coat.roughness = 0.82
	model_mesh.set_surface_override_material(0, coat)
	model_mesh.set_surface_override_material(1, dark_coat)


func _prepare_animation_library() -> void:
	for animation_name in animation_player.get_animation_list():
		if animation_name not in ["Armature|Death", "Armature|Jump"]:
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.play("Armature|Idle")


func _update_animation(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var motion_amount := clampf(horizontal_speed / gallop_speed, 0.0, 1.0)
	_stride_time += delta * lerpf(2.5, 10.0, motion_amount)

	var requested_animation := "Armature|Idle"
	var playback_speed := 1.0
	if horizontal_speed > 12.0:
		requested_animation = "Armature|Run"
		playback_speed = clampf(horizontal_speed / gallop_speed, 0.75, 1.15)
	elif horizontal_speed > 7.0:
		requested_animation = "Armature|Walk"
		playback_speed = clampf(horizontal_speed / canter_speed, 0.8, 1.25)
	elif horizontal_speed > 0.25:
		requested_animation = "Armature|WalkSlow"
		playback_speed = clampf(horizontal_speed / walk_speed, 0.55, 1.15)

	if animation_player.current_animation != requested_animation:
		animation_player.play(requested_animation, 0.22)
	animation_player.speed_scale = playback_speed

	# El ancla acompaña suavemente el lomo aunque el jinete sea un placeholder.
	var bob := absf(sin(_stride_time * 2.0)) * 0.075 * motion_amount
	rider_anchor.position.y = lerpf(rider_anchor.position.y, _rider_base_height + bob, 0.3)


func _update_hoof_audio(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not mounted or horizontal_speed < 0.8 or not is_on_floor():
		_hoof_timer = 0.0
		return

	var motion_amount := clampf(horizontal_speed / gallop_speed, 0.0, 1.0)
	var interval := lerpf(0.54, 0.22, motion_amount)
	_hoof_timer += delta
	if _hoof_timer < interval:
		return

	_hoof_timer -= interval
	hoof_audio.stream = HOOFBEATS[_hoof_index]
	hoof_audio.pitch_scale = 0.92 + motion_amount * 0.13 + (0.025 if _hoof_index % 2 == 0 else -0.02)
	hoof_audio.volume_db = lerpf(-10.5, -4.0, motion_amount)
	hoof_audio.play()
	_hoof_index = (_hoof_index + 1) % HOOFBEATS.size()
	hoofbeat_count += 1
