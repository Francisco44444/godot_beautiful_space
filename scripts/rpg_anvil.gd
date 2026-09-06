class_name RPGAnvil
extends StaticBody3D

## El yunque del herrero: donde los cristales que sueltan las criaturas se
## convierten en acero mejor.
##
## Es el nudo que ata el combate con la progresión. Cada bioma suelta un cristal
## distinto, y cada grado del equipo pide uno concreto, así que subir de espada
## obliga a ir a buscarlo donde vive. Sin este nodo la forja sería una tabla que
## nadie usa; con él, un diamante del desierto se convierte en un arco dorado.

const PROP_PATH := "res://assets/quaternius/Fantasy Props MegaKit/Exports/glTF/Anvil_Log.gltf"
## En qué orden se ofrece la mejora cuando hay varias posibles.
const ORDER: PackedStringArray = ["sword", "shield", "bow", "axe"]

@export var smith_name := "Herrería"

var _inventory: Node = null


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	add_to_group("adventure_interactable")
	add_to_group("rpg_anvil")
	_build_visual()
	_build_collision()
	_build_sign()


func get_interaction_prompt() -> String:
	var offer := _next_offer()
	if offer.is_empty():
		return "E · %s · nada que forjar" % smith_name
	var recipe: Dictionary = offer["recipe"]
	var ready := bool(offer["affordable"])
	return "E · Forjar %s · %s%s" % [
		String(recipe["name"]),
		RPGForge.cost_line(recipe["cost"]),
		"" if ready else " (te falta material)",
	]


func interact(player: Node) -> bool:
	var offer := _next_offer()
	if offer.is_empty():
		_say(player, "%s: no hay nada que mejorar todavía." % smith_name)
		return true
	var recipe: Dictionary = offer["recipe"]
	if not bool(offer["affordable"]):
		_say(player, "%s: para %s hacen falta %s." % [
			smith_name, String(recipe["name"]), RPGForge.cost_line(recipe["cost"])])
		return true
	var inventory := _inventory_manager()
	if inventory == null:
		return false
	# Se cobra primero y se entrega después: si algo fallara a mitad, es
	# preferible que el jugador conserve el material a que se quede sin él.
	for item in (recipe["cost"] as Dictionary):
		if not bool(inventory.call("remove_item", item, int(recipe["cost"][item]), false)):
			_say(player, "%s: falta %s." % [smith_name, String(item)])
			return true
	var from_id := String(offer["from"])
	var to_id := String(recipe["to"])
	inventory.call("remove_item", from_id, 1, false)
	inventory.call("add_item", to_id, 1, false)
	inventory.call("equip_item", to_id, true)
	_say(player, "%s forjada. %s ya cuelga de tu cinto." % [String(recipe["name"]), to_id])
	# Cargar acero mejor también endurece a quien lo lleva: cada grado sube un
	# poco la vida y el vigor máximos.
	var runtime := get_tree().root.find_child("RPGStoryRuntime", true, false)
	if runtime != null and runtime.has_method("grow_hero"):
		runtime.call("grow_hero", 6, 5, String(recipe["name"]))
	if player != null and player.has_method("play_gesture"):
		player.call("play_gesture", "Victory")
	return true


func _next_offer() -> Dictionary:
	var inventory := _inventory_manager()
	if inventory == null:
		return {}
	for category in ORDER:
		var equipped := String(inventory.call("get_equipped_item", category))
		if equipped.is_empty():
			continue
		var recipe := RPGForge.recipe_for(equipped)
		if recipe.is_empty():
			continue
		var affordable := true
		for item in (recipe["cost"] as Dictionary):
			if not bool(inventory.call("has_item", item, int(recipe["cost"][item]))):
				affordable = false
				break
		return {"from": equipped, "recipe": recipe, "affordable": affordable, "category": category}
	return {}


func _inventory_manager() -> Node:
	if _inventory == null or not is_instance_valid(_inventory):
		_inventory = get_tree().root.get_node_or_null("InventoryManager")
	return _inventory


func _say(player: Node, message: String) -> void:
	if player != null and player.has_signal("action_feedback"):
		player.emit_signal("action_feedback", message)


func _build_visual() -> void:
	var scene := load(PROP_PATH) as PackedScene
	if scene == null:
		return
	var visual := scene.instantiate() as Node3D
	if visual == null:
		return
	visual.name = "AnvilVisual"
	visual.scale = Vector3.ONE * 1.6
	add_child(visual)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "AnvilCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.1, 0.9)
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)


func _build_sign() -> void:
	var label := Label3D.new()
	label.name = "AnvilSign"
	label.text = smith_name
	label.position = Vector3(0.0, 1.9, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(1.0, 0.78, 0.42)
	label.visibility_range_end = 40.0
	add_child(label)
