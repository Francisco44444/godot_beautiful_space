extends Node3D
var director: Node
var identificador := ""
var titulo := ""
func _ready() -> void:
	add_to_group("adventure_interactable")
func get_interaction_prompt() -> String:
	return "E · " + titulo
func interact(actor: Node) -> bool:
	return director.interactuar(identificador, actor)
