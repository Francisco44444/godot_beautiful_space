extends Node3D

var director: Node
var memory_id := ""
var title := ""
var text := ""
var kind := "rune"
var cave_id := ""

func _ready() -> void:
	add_to_group("adventure_interactable")
	add_to_group("cave_memory")

func get_interaction_prompt() -> String:
	if director == null:
		return ""
	return "E · %s" % title

func interact(player: Node) -> bool:
	return bool(director.call("interact_memory", self, player))
