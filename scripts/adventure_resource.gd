class_name AdventureResource
extends StaticBody3D

## Árboles, vetas, cofres, reliquias y animales ligados a un reto concreto.

@export var kind := "tree"
@export var zone_id := ""
@export var required_category := "axe"
@export var health := 3
@export var reward_item_id := "Coin"

var broken := false
var activated := false
var adventure_system: Node
var label: Label3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	add_to_group("adventure_interactable")
	if kind in ["tree", "rock"]:
		add_to_group("melee_target")


func get_interaction_prompt() -> String:
	if activated or broken:
		return ""
	match kind:
		"chest":
			return "E · Abrir cofre"
		"animal":
			return "E · Registrar animal en el bestiario"
		"relic":
			return "E · Recoger reliquia"
		"tree":
			return "2 · Hacha  ·  Clic · Talar"
		"rock":
			return "2 · Hacha  ·  Clic · Romper veta"
	return ""


func interact(player: Player) -> bool:
	if activated or broken:
		return false
	match kind:
		"chest":
			activated = true
			if adventure_system != null:
				adventure_system.call("open_chest", self, player)
			return true
		"animal":
			activated = true
			var exploration := get_node_or_null("/root/ExplorationManager")
			if exploration != null:
				exploration.call("register_world_action", zone_id, "discover_animal")
			player.action_feedback.emit("Animal añadido al bestiario")
			_play_animal_reaction()
			return true
		"relic":
			activated = true
			var inventory := get_node_or_null("/root/InventoryManager")
			var exploration := get_node_or_null("/root/ExplorationManager")
			if inventory != null:
				inventory.call("add_item", reward_item_id, 1)
			if exploration != null:
				exploration.call("register_world_action", zone_id, "recover_relic")
			player.action_feedback.emit("Reliquia conseguida: %s" % _reward_name())
			var tween := create_tween().set_parallel(true)
			tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.24).set_trans(Tween.TRANS_BACK)
			tween.tween_property(self, "position:y", position.y + 1.4, 0.24)
			tween.chain().tween_callback(queue_free)
			return true
	return false


func receive_tool_hit(category: String, _item_id: String, _hit_position: Vector3, player: Player) -> void:
	if broken or kind not in ["tree", "rock"]:
		return
	if category != required_category:
		player.action_feedback.emit("Necesitas equipar el hacha con 2")
		_wrong_tool_shake()
		return
	health -= 1
	_hit_feedback()
	if health <= 0:
		broken = true
		if adventure_system != null:
			adventure_system.call("break_resource", self, player)


func receive_projectile_hit(_hit_position: Vector3, _shooter: Node) -> void:
	# Una flecha puede clavarse visualmente, pero no sustituye la herramienta de
	# tala/minería ni abre cofres a distancia.
	_hit_feedback()


func disable_collisions() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)


func _hit_feedback() -> void:
	var original := scale
	var tween := create_tween()
	tween.tween_property(self, "scale", original * Vector3(1.06, 0.95, 1.06), 0.07)
	tween.tween_property(self, "scale", original, 0.10)


func _wrong_tool_shake() -> void:
	var original := rotation.z
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", original + 0.04, 0.05)
	tween.tween_property(self, "rotation:z", original - 0.03, 0.06)
	tween.tween_property(self, "rotation:z", original, 0.06)


func _play_animal_reaction() -> void:
	var animator := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null:
		for animation_name in ["Gallop", "Walk", "Idle"]:
			if animator.has_animation(animation_name):
				animator.play(animation_name, 0.12, 1.05)
				break


func _reward_name() -> String:
	var inventory := get_node_or_null("/root/InventoryManager")
	var definition := inventory.call("get_item_definition", reward_item_id) as Dictionary if inventory != null else {}
	return String(definition.get("display_name", reward_item_id.replace("_", " ")))
