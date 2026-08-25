class_name AdventurePickup
extends Area3D

## Objeto físico ligero que se recoge al pasar por encima. Se usa para troncos,
## rubíes, flechas y recompensas expulsadas por los cofres.

@export var item_id := "Coin"
@export var amount := 1
@export var zone_id := ""
@export var completion_action := ""

var collected := false
var base_height := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	base_height = position.y
	add_to_group("adventure_pickup")


func _process(delta: float) -> void:
	if collected:
		return
	rotation.y += delta * 1.35
	position.y = base_height + sin(Time.get_ticks_msec() * 0.0028 + float(get_instance_id() % 31)) * 0.10


func _on_body_entered(body: Node3D) -> void:
	if collected or not body is Player or bool(body.get("network_remote")):
		return
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory == null or not bool(inventory.call("add_item", item_id, amount)):
		return
	collected = true
	if not zone_id.is_empty() and not completion_action.is_empty():
		var exploration := get_node_or_null("/root/ExplorationManager")
		if exploration != null:
			exploration.call("register_world_action", zone_id, completion_action)
	if body.has_signal("action_feedback"):
		body.emit_signal("action_feedback", "+%d %s" % [amount, _display_name(item_id)])
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 0.08, 0.18).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y + 1.1, 0.18)
	tween.chain().tween_callback(queue_free)


func _display_name(value: String) -> String:
	var inventory := get_node_or_null("/root/InventoryManager")
	var definition := inventory.call("get_item_definition", value) as Dictionary if inventory != null else {}
	return String(definition.get("display_name", value.replace("_", " ")))
