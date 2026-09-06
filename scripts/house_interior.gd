class_name HouseInterior
extends RefCounted

const PACK := "res://assets/quaternius/Fantasy Props MegaKit/Exports/glTF/"
static var _scenes: Dictionary = {}


static func decorate(body: StaticBody3D, plan: BuildingSolver, variation: int) -> void:
	var root := Node3D.new()
	root.name = "InteriorDecorations"
	body.add_child(root)
	var shift := plan.centre_offset()
	var count := 0
	for floor_spec in plan.floors_plan:
		var volume := int(floor_spec.volume)
		# El cuerpo principal queda libre para las escaleras, sus descansillos y
		# la entrada. Las alas son estancias amuebladas, no obstáculos de paso.
		if volume == 0:
			continue
		var origin: Vector2i = floor_spec.origin
		var size: Vector2i = floor_spec.size
		var y := float(floor_spec.y)
		var middle := Vector3((origin.x + size.x * 0.5) * 2.0, y, (origin.y + size.y * 0.5) * 2.0) + shift
		var far_x := (origin.x + size.x - 0.6) * 2.0 if origin.x >= 0 else (origin.x + 0.6) * 2.0
		var back := Vector3(far_x, y, (origin.y + 0.7) * 2.0) + shift
		var front := Vector3(far_x, y, (origin.y + size.y - 0.7) * 2.0) + shift
		var theme := posmod(variation + int(floor_spec.level) + volume, 4)
		var large: Array[String] = ["Bed_Twin1", "Bookcase_2", "Cabinet", "Workbench"]
		var small: Array[String] = ["Nightstand_Shelf", "Chest_Wood", "Barrel", "BookStand"]
		_spawn(root, large[theme], back, 0.0, 3.1, true, body.scale.x)
		_spawn(root, small[theme], front, PI, 1.7, true, body.scale.x)
		var table := _spawn(root, "Table_Large", middle, 0.0, 3.0, true, body.scale.x)
		if table != null:
			var top := float(table.get_meta("top_y", 0.55))
			var item_names: Array[String] = ["CandleStick_Triple", "Book_Stack_2", "Pot_1", "Potion_2"]
			_spawn(root, item_names[theme], middle + Vector3(-0.25, top, 0.0), 0.4, 0.5, false, body.scale.x)
			_spawn(root, "Bottle_1", middle + Vector3(0.25, top, 0.1), 0.0, 0.4, false, body.scale.x)
		for side in [-1.0, 1.0]:
			_spawn(root, "Stool", middle + Vector3(0.0, 0.0, side * 1.8 / body.scale.x), 0.0, 0.75, true, body.scale.x)
		count += 7
	body.set_meta("interior_prop_count", count)
	body.set_meta("interior_pack", "Fantasy Props MegaKit")


static func _spawn(parent: Node3D, item: String, at: Vector3, yaw: float, extent: float, solid: bool, house_scale: float) -> Node3D:
	if not _scenes.has(item):
		_scenes[item] = load(PACK + item + ".gltf")
	var scene := _scenes[item] as PackedScene
	if scene == null:
		return null
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.name = item
	holder.position = at
	holder.rotation.y = yaw
	parent.add_child(holder)
	var visual := scene.instantiate() as Node3D
	holder.add_child(visual)
	var bounds := AABB()
	var first := true
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		mesh.visibility_range_end = 180.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if first:
		return holder
	var factor := extent / house_scale / maxf(bounds.size[bounds.size.max_axis_index()], 0.01)
	visual.scale = Vector3.ONE * factor
	visual.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	var size := bounds.size * factor
	holder.set_meta("top_y", size.y)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size.max(Vector3.ONE * 0.04)
		collision.shape = shape
		collision.position.y = size.y * 0.5
		holder.add_child(collision)
	return holder
