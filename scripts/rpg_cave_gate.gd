class_name RPGCaveGate
extends StaticBody3D

## Acceso de aventura cerrado por una llave física del Ultimate RPG Items Pack.

signal gate_opened(gate_id: String, key_item_id: String)

@export var gate_id := "root_cave"
@export var display_name := "Gruta de las Raíces"
@export var key_item_id := "Key1"
@export var destination_hint := "Cámara olvidada"

var story_runtime: Node
var opened := false
var _door_visual: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	add_to_group("adventure_interactable")
	add_to_group("rpg_cave_gate")
	_build_arch()


func get_interaction_prompt() -> String:
	if opened:
		return ""
	return "E · Abrir %s · requiere %s" % [display_name, _key_display_name()]


func interact(player: Node) -> bool:
	if opened:
		return false
	var inventory := get_node_or_null("/root/InventoryManager")
	if inventory == null or not bool(inventory.call("has_item", key_item_id, 1)):
		_feedback(player, "La entrada está sellada. Necesitas %s." % _key_display_name())
		_locked_feedback()
		return true
	open_gate(player)
	return true


func open_gate(player: Node = null, animated: bool = true) -> void:
	if opened:
		return
	opened = true
	if _collision != null:
		_collision.set_deferred("disabled", true)
	_feedback(player, "%s abierta · %s" % [display_name, destination_hint])
	gate_opened.emit(gate_id, key_item_id)
	if story_runtime != null:
		story_runtime.call("on_gate_opened", self)
	if _door_visual == null:
		return
	if animated:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_door_visual, "position:y", 4.8, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_door_visual, "rotation:y", deg_to_rad(12.0), 1.15)
	else:
		_door_visual.position.y = 4.8


func get_save_state() -> Dictionary:
	return {"id": gate_id, "opened": opened}


func apply_save_state(state: Dictionary) -> void:
	if String(state.get("id", gate_id)) == gate_id and bool(state.get("opened", false)):
		open_gate(null, false)


func _build_arch() -> void:
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.30, 0.34, 0.39)
	stone_material.roughness = 0.95
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.72
		pillar_mesh.bottom_radius = 0.95
		pillar_mesh.height = 4.8
		pillar_mesh.radial_segments = 7
		pillar_mesh.material = stone_material
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(side * 2.15, 2.4, 0.2)
		pillar.rotation.z = side * 0.075
		add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(5.3, 1.0, 1.2)
	lintel_mesh.material = stone_material
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0.0, 4.55, 0.2)
	add_child(lintel)

	_door_visual = MeshInstance3D.new()
	_door_visual.name = "SealedDoor"
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(3.45, 4.05, 0.48)
	var door_material := StandardMaterial3D.new()
	door_material.albedo_color = Color(0.16, 0.075, 0.035)
	door_material.roughness = 0.86
	metallic_runes(door_material)
	door_mesh.material = door_material
	_door_visual.mesh = door_mesh
	_door_visual.position.y = 2.0
	add_child(_door_visual)

	_collision = CollisionShape3D.new()
	_collision.name = "GateCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.6, 4.2, 0.72)
	_collision.shape = shape
	_collision.position.y = 2.05
	add_child(_collision)

	var label := Label3D.new()
	label.name = "GateName"
	label.text = "%s\n◆ %s" % [display_name, _key_display_name()]
	label.position = Vector3(0.0, 5.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(0.72, 0.88, 1.0)
	label.visibility_range_end = 42.0
	add_child(label)


func metallic_runes(material: StandardMaterial3D) -> void:
	material.metallic = 0.18
	material.emission_enabled = true
	material.emission = Color(0.03, 0.16, 0.24)
	material.emission_energy_multiplier = 1.25


func _locked_feedback() -> void:
	if _door_visual == null:
		return
	var original := _door_visual.position.x
	var tween := create_tween()
	tween.tween_property(_door_visual, "position:x", original + 0.09, 0.055)
	tween.tween_property(_door_visual, "position:x", original - 0.07, 0.065)
	tween.tween_property(_door_visual, "position:x", original, 0.07)


func _feedback(player: Node, message: String) -> void:
	if player != null and player.has_signal("action_feedback"):
		player.emit_signal("action_feedback", message)


func _key_display_name() -> String:
	var inventory := get_node_or_null("/root/InventoryManager")
	var definition := inventory.call("get_item_definition", key_item_id) as Dictionary if inventory != null else {}
	return String(definition.get("display_name", key_item_id.replace("_", " ")))
