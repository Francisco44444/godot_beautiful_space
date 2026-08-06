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

var generated_animal_count := 0


func _ready() -> void:
	var terrain := get_node_or_null(terrain_path) as Terrain3D
	for spec in ANIMAL_SPECS:
		var animal := _load_gltf_scene(spec["path"])
		if animal == null:
			continue
		animal.name = "%s_%02d" % [spec["path"].get_file().get_basename(), generated_animal_count + 1]
		animal.scale = Vector3.ONE * float(spec["scale"])
		animal.rotation_degrees.y = float(spec["yaw"])
		animal.position = spec["position"]
		if terrain != null:
			var height := terrain.data.get_height(animal.position)
			if not is_nan(height):
				animal.position.y = height + 0.04
		add_child(animal)
		_play_idle(animal)
		generated_animal_count += 1


func _load_gltf_scene(path: String) -> Node3D:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar fauna Quaternius: %s" % path)
		return null
	return document.generate_scene(state) as Node3D


func _play_idle(root: Node3D) -> void:
	var animator := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null:
		return
	for animation_name in animator.get_animation_list():
		if animation_name.begins_with("Idle"):
			animator.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
			animator.play(animation_name)
			return
