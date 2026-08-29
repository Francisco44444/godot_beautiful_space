class_name RPGNPC
extends StaticBody3D

## Personaje narrativo compatible con el sistema de interacción ya usado por el
## jugador. La conversación real y las recompensas viven en RPGStoryRuntime.

@export var npc_id := "maela"
@export var display_name := "Habitante de Aeloria"
@export var role := "Testigo"
@export var character_file := "Casual_Female.gltf"
@export var interaction_radius := 4.5

var story_runtime: Node
var visual: Node3D
var animator: AnimationPlayer
var conversation_count := 0


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	add_to_group("adventure_interactable")
	add_to_group("rpg_npc")
	_build_collision()
	_build_nameplate()
	_load_character()


func get_interaction_prompt() -> String:
	return "E · Hablar con %s · %s" % [display_name, role]


func interact(player: Node) -> bool:
	if story_runtime == null:
		return false
	conversation_count += 1
	_face_position((player as Node3D).global_position if player is Node3D else global_position - global_basis.z)
	story_runtime.call("begin_npc_dialogue", self, player)
	_play_best_animation(["Talk", "Talking", "Interact", "Idle"])
	return true


func get_story_identity() -> Dictionary:
	return {
		"id": npc_id,
		"name": display_name,
		"role": role,
		"conversations": conversation_count,
	}


func _load_character() -> void:
	var path := "res://assets/quaternius/ultimate_animated_characters/glTF/%s" % character_file
	var packed := load(path) as PackedScene
	if packed == null:
		_build_fallback_character()
		return
	visual = packed.instantiate() as Node3D
	if visual == null:
		_build_fallback_character()
		return
	visual.name = "CharacterVisual"
	visual.scale = Vector3.ONE * 0.95
	add_child(visual)
	animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_best_animation(["Idle", "idle", "Standing"])


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "NPCBodyCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)


func _build_nameplate() -> void:
	var label := Label3D.new()
	label.name = "NPCName"
	label.text = "%s\n%s" % [display_name, role]
	label.position = Vector3(0.0, 2.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color(1.0, 0.89, 0.58)
	label.visibility_range_end = 35.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(label)


func _build_fallback_character() -> void:
	visual = Node3D.new()
	visual.name = "FallbackCharacter"
	add_child(visual)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.48, 0.62)
	capsule.material = material
	body.mesh = capsule
	body.position.y = 0.9
	visual.add_child(body)


func _play_best_animation(candidates: Array[String]) -> void:
	if animator == null:
		return
	for candidate in candidates:
		if animator.has_animation(candidate):
			var animation := animator.get_animation(candidate)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			animator.play(candidate, 0.18)
			return


func _face_position(target: Vector3) -> void:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_squared_to(flat_target) > 0.01:
		look_at(flat_target, Vector3.UP, true)
