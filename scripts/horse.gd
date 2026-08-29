class_name Horse
extends CharacterBody3D

## Montura controlable de la Fase 4.
## El caballo conserva su propia física: Player solo activa o desactiva el control
## y coloca su representación visual sobre RiderAnchor.

const HOOFBEATS: Array[AudioStream] = [
	preload("res://assets/audio/original/hoof_1.wav"),
	preload("res://assets/audio/original/hoof_2.wav"),
	preload("res://assets/audio/original/hoof_3.wav"),
	preload("res://assets/audio/original/hoof_4.wav"),
]

@export_category("Movimiento")
@export var walk_speed: float = 6.0
@export var canter_speed: float = 10.5
@export var gallop_speed: float = 17.5
@export var acceleration: float = 18.0
@export var braking: float = 16.0
@export var turn_speed: float = 5.0

@export_category("Identidad")
@export var horse_name: String = "Brisa"
@export var respawn_height: float = -12.0

@export_category("Llamada desde el horizonte")
@export var summon_horizon_distance: float = 58.0
@export var summon_teleport_threshold: float = 30.0
@export var summon_materialize_delay: float = 0.42

@export_category("Quaternius")
@export_file("*.gltf") var quaternius_horse_path := "res://assets/quaternius/ultimate_animated_animals/glTF/Horse.gltf"

@onready var visual: Node3D = $Visual
@onready var rider_anchor: Marker3D = $Visual/RiderAnchor
@onready var name_label: Label3D = $NameLabel
@onready var model_root: Node3D = $Visual/ModelRoot
@onready var hoof_audio: AudioStreamPlayer3D = $HoofAudio

var animation_player: AnimationPlayer
var spawn_position: Vector3
var mounted := false
var _stride_time := 0.0
var _rider_base_height := 0.0
var _hoof_timer := 0.0
var _hoof_index := 0
var hoofbeat_count := 0
var sprint_requested := false
var _summon_target: Node3D
var _is_being_called := false
var _summon_pending := false
var _summon_timer := 0.0
var _summon_destination := Vector3.ZERO
var summon_teleport_count := 0
var _saved_collision_layer := 1


func _ready() -> void:
	spawn_position = global_position
	_rider_base_height = rider_anchor.position.y
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48.0)
	# La acción contextual vive en el HUD y solo aparece cuando está al alcance.
	name_label.text = horse_name.to_upper()
	name_label.visible = false
	_load_quaternius_horse()
	_prepare_animation_library()


func _physics_process(delta: float) -> void:
	if _summon_pending:
		_summon_timer -= delta
		velocity = Vector3.ZERO
		if _summon_timer <= 0.0:
			_materialize_at_horizon()
		return
	_apply_gravity(delta)
	if mounted:
		_is_being_called = false
		_apply_riding_input(delta)
	elif _is_being_called and is_instance_valid(_summon_target):
		_follow_summon_target(delta)
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
	name_label.visible = false
	if not mounted:
		# El caballo no se detiene en seco al desmontar; pierde inercia suavemente.
		velocity.x *= 0.45
		velocity.z *= 0.45


func get_facing_yaw() -> float:
	return visual.rotation.y


func call_to(target: Node3D) -> void:
	if mounted or target == null:
		return
	_summon_target = target
	var distance := global_position.distance_to(target.global_position)
	if distance > summon_teleport_threshold:
		_schedule_horizon_arrival(target)
	else:
		_is_being_called = true
	name_label.text = "%s · CRUZA EL HORIZONTE" % horse_name.to_upper()
	name_label.visible = true


func is_coming_when_called() -> bool:
	return _is_being_called or _summon_pending


func _schedule_horizon_arrival(target: Node3D) -> void:
	var forward := -target.global_basis.z
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		forward = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD
	var right := Vector3.UP.cross(forward).normalized()
	var preferred := target.global_position + forward * summon_horizon_distance + right * 8.0
	_summon_destination = _find_safe_summon_point(preferred, target.global_position, forward)
	_summon_pending = true
	_is_being_called = false
	_summon_timer = summon_materialize_delay
	_saved_collision_layer = collision_layer
	collision_layer = 0
	visual.visible = false
	velocity = Vector3.ZERO


func _find_safe_summon_point(preferred: Vector3, target_position: Vector3, forward: Vector3) -> Vector3:
	var terrain := get_node_or_null("../Terrain3D")
	if terrain == null or terrain.get("data") == null:
		return Vector3(preferred.x, target_position.y + 1.0, preferred.z)
	var directions: Array[Vector3] = [
		forward,
		forward.rotated(Vector3.UP, deg_to_rad(24.0)),
		forward.rotated(Vector3.UP, deg_to_rad(-24.0)),
		forward.rotated(Vector3.UP, deg_to_rad(48.0)),
		forward.rotated(Vector3.UP, deg_to_rad(-48.0)),
	]
	for direction in directions:
		var point := target_position + direction * summon_horizon_distance
		var height: float = terrain.data.get_height(point)
		var nearby_height: float = terrain.data.get_height(point + Vector3(direction.z, 0.0, -direction.x) * 2.5)
		if not is_nan(height) and not is_nan(nearby_height) and height > 1.4 and absf(nearby_height - height) < 2.0:
			return Vector3(point.x, height + 0.24, point.z)
	var fallback_height: float = terrain.data.get_height(preferred)
	return Vector3(preferred.x, fallback_height + 0.24 if not is_nan(fallback_height) else target_position.y + 1.0, preferred.z)


func _materialize_at_horizon() -> void:
	_summon_pending = false
	global_position = _summon_destination
	velocity = Vector3.ZERO
	collision_layer = _saved_collision_layer
	visual.visible = true
	_is_being_called = is_instance_valid(_summon_target)
	summon_teleport_count += 1
	_spawn_arrival_mist()
	if _is_being_called:
		var direction := _summon_target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.01:
			visual.rotation.y = atan2(-direction.x, -direction.z)
			velocity = direction.normalized() * gallop_speed * 0.72
	name_label.text = "%s · GALOPA HACIA TI" % horse_name.to_upper()


func _spawn_arrival_mist() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "HorizonArrivalMist"
	particles.amount = 26
	particles.lifetime = 0.82
	particles.one_shot = true
	particles.explosiveness = 0.78
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.4
	particles.direction = Vector3.UP
	particles.spread = 58.0
	particles.initial_velocity_min = 1.1
	particles.initial_velocity_max = 2.8
	particles.gravity = Vector3(0.0, -1.2, 0.0)
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.85
	particles.color = Color(0.72, 0.83, 0.90, 0.56)
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 5
	puff.rings = 3
	particles.mesh = puff
	get_parent().add_child(particles)
	particles.global_position = global_position + Vector3.UP * 0.4
	particles.emitting = true
	var cleanup := get_tree().create_timer(1.1)
	cleanup.timeout.connect(particles.queue_free)


func _follow_summon_target(delta: float) -> void:
	var offset := _summon_target.global_position - global_position
	offset.y = 0.0
	if offset.length() <= 3.0:
		_is_being_called = false
		name_label.visible = false
		_slow_to_stop(delta)
		return
	var direction := offset.normalized()
	var target_speed := canter_speed if offset.length() < 42.0 else gallop_speed * 0.82
	velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	var desired_yaw := atan2(-direction.x, -direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, turn_speed * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _apply_riding_input(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_strength := clampf(input_vector.length(), 0.0, 1.0)
	var direction := _camera_relative_direction(input_vector)

	var cruising_speed := lerpf(walk_speed, canter_speed, input_strength)
	sprint_requested = _is_sprint_pressed()
	var target_speed := gallop_speed if sprint_requested else cruising_speed
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


func _prepare_animation_library() -> void:
	if animation_player == null:
		return
	for animation_name in ["Idle", "Idle_2", "Idle_Headlow", "Walk", "Gallop", "Gallop_Jump", "Jump_toIdle"]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	if animation_player.has_animation("Idle"):
		animation_player.play("Idle")


func _update_animation(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var motion_amount := clampf(horizontal_speed / gallop_speed, 0.0, 1.0)
	_stride_time += delta * lerpf(2.5, 10.0, motion_amount)

	var requested_animation := "Idle"
	var playback_speed := 1.0
	if horizontal_speed > 7.0:
		requested_animation = "Gallop"
		playback_speed = clampf(horizontal_speed / gallop_speed, 0.75, 1.15)
	elif horizontal_speed > 0.25:
		requested_animation = "Walk"
		playback_speed = clampf(horizontal_speed / walk_speed, 0.55, 1.15)

	if animation_player == null or not animation_player.has_animation(requested_animation):
		return
	if animation_player.current_animation != requested_animation:
		animation_player.play(requested_animation, 0.22)
	animation_player.speed_scale = playback_speed

	# El ancla acompaña suavemente el lomo para que el jinete siga la zancada.
	var bob := absf(sin(_stride_time * 2.0)) * 0.075 * motion_amount
	rider_anchor.position.y = lerpf(rider_anchor.position.y, _rider_base_height + bob, 0.3)


func _load_quaternius_horse() -> void:
	var loaded_scene := _load_gltf_scene(quaternius_horse_path)
	if loaded_scene == null:
		return
	model_root.add_child(loaded_scene)
	loaded_scene.rotation_degrees.y = 180.0
	loaded_scene.scale = Vector3.ONE * 1.05
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _load_gltf_scene(path: String) -> Node3D:
	var imported := ResourceLoader.load(path)
	if imported is PackedScene:
		var imported_node := (imported as PackedScene).instantiate() as Node3D
		if imported_node != null:
			imported_node.set_meta("loaded_via_project_importer", true)
		return imported_node
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el modelo Quaternius: %s" % path)
		return null
	var node := document.generate_scene(state)
	if node != null:
		node.set_meta("loaded_via_project_importer", false)
	return node as Node3D


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


func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
