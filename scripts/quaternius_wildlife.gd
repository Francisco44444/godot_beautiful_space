extends Node3D
class_name QuaterniusWildlife

const ANIMAL_SPECS: Array[Dictionary] = [
	{"path": "res://assets/quaternius/ultimate_animated_animals/glTF/Deer.gltf", "position": Vector3(-18, 0, 138), "scale": 0.95, "yaw": 22.0},
	{"path": "res://assets/quaternius/ultimate_animated_animals/glTF/Stag.gltf", "position": Vector3(28, 0, 126), "scale": 1.05, "yaw": -35.0},
	{"path": "res://assets/quaternius/ultimate_animated_animals/glTF/Fox.gltf", "position": Vector3(-42, 0, 98), "scale": 0.82, "yaw": 70.0},
	{"path": "res://assets/quaternius/ultimate_animated_animals/glTF/Wolf.gltf", "position": Vector3(42, 0, 82), "scale": 0.9, "yaw": -110.0},
	{"path": "res://assets/quaternius/ultimate_animated_animals/glTF/Deer.gltf", "position": Vector3(74, 0, 34), "scale": 0.88, "yaw": 150.0},
	{"path": "res://assets/quaternius/ultimate_animated_animals/glTF/Fox.gltf", "position": Vector3(-78, 0, 18), "scale": 0.76, "yaw": -45.0},
]

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export_category("Reacción al jugador")
@export var awareness_distance := 28.0
@export var close_awareness_distance := 10.0
@export var flee_speed := 4.2
@export var reaction_seconds := 2.8
@export var roaming_radius := 22.0

var generated_animal_count := 0
var reactive_animal_count := 0
var reaction_count := 0
var _animals: Array[Dictionary] = []
var _terrain: Terrain3D
var _player: Player


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain3D
	_player = get_node_or_null("../Player") as Player
	for spec in ANIMAL_SPECS:
		var animal := _load_gltf_scene(spec["path"])
		if animal == null:
			continue
		animal.name = "%s_%02d" % [spec["path"].get_file().get_basename(), generated_animal_count + 1]
		animal.scale = Vector3.ONE * float(spec["scale"])
		animal.rotation_degrees.y = float(spec["yaw"])
		animal.position = spec["position"]
		if _terrain != null:
			var height := _terrain.data.get_height(animal.position)
			if not is_nan(height):
				animal.position.y = height + 0.04
		add_child(animal)
		var animator := animal.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_play_animation(animator, "Idle", 1.0)
		_animals.append({
			"node": animal,
			"animator": animator,
			"home": animal.position,
			"alert_time": 0.0,
			"flee_direction": Vector3.ZERO,
			"alerted": false,
		})
		generated_animal_count += 1
		reactive_animal_count += 1


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	for agent in _animals:
		_update_animal(agent, delta)


func _update_animal(agent: Dictionary, delta: float) -> void:
	var animal := agent["node"] as Node3D
	if animal == null:
		return
	var player_position := _player.global_position
	var flat_to_player := Vector3(player_position.x - animal.global_position.x, 0.0, player_position.z - animal.global_position.z)
	var player_distance := flat_to_player.length()
	var sees_player := _can_see_player(animal, flat_to_player, player_distance)

	if sees_player:
		var flee_direction := -flat_to_player.normalized()
		if flee_direction.length_squared() < 0.01:
			flee_direction = -animal.global_basis.z.normalized()
		agent["flee_direction"] = flee_direction
		agent["alert_time"] = reaction_seconds
		if not bool(agent["alerted"]):
			reaction_count += 1
		agent["alerted"] = true
	else:
		agent["alert_time"] = maxf(float(agent["alert_time"]) - delta, 0.0)

	var move_direction := Vector3.ZERO
	var move_speed := 0.0
	if float(agent["alert_time"]) > 0.0:
		move_direction = agent["flee_direction"] as Vector3
		move_speed = flee_speed
		_play_animation(agent["animator"] as AnimationPlayer, "Gallop", 1.12)
	else:
		agent["alerted"] = false
		var home := agent["home"] as Vector3
		var flat_home := Vector3(home.x - animal.position.x, 0.0, home.z - animal.position.z)
		if flat_home.length() > roaming_radius:
			move_direction = flat_home.normalized()
			move_speed = 1.15
			_play_animation(agent["animator"] as AnimationPlayer, "Walk", 0.88)
		else:
			_play_animation(agent["animator"] as AnimationPlayer, "Idle", 1.0)

	if move_speed <= 0.0 or move_direction.length_squared() <= 0.01:
		return
	var candidate := animal.position + move_direction * move_speed * delta
	candidate.x = clampf(candidate.x, -232.0, 232.0)
	candidate.z = clampf(candidate.z, -232.0, 232.0)
	if _terrain != null:
		var ground := _terrain.data.get_height(candidate)
		if is_nan(ground):
			return
		candidate.y = ground + 0.04
	animal.position = candidate
	var desired_yaw := atan2(-move_direction.x, -move_direction.z)
	animal.rotation.y = lerp_angle(animal.rotation.y, desired_yaw, 1.0 - exp(-8.0 * delta))


func _can_see_player(animal: Node3D, to_player: Vector3, distance: float) -> bool:
	if distance > awareness_distance:
		return false
	if distance <= close_awareness_distance:
		return true
	var look_direction := -animal.global_basis.z.normalized()
	return look_direction.dot(to_player.normalized()) > -0.15


func _load_gltf_scene(path: String) -> Node3D:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar fauna Quaternius: %s" % path)
		return null
	return document.generate_scene(state) as Node3D


func _play_animation(animator: AnimationPlayer, requested: String, speed: float) -> void:
	if animator == null:
		return
	if not animator.has_animation(requested):
		return
	animator.get_animation(requested).loop_mode = Animation.LOOP_LINEAR
	if animator.current_animation != requested:
		animator.play(requested, 0.18)
	animator.speed_scale = speed
