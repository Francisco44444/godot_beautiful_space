extends SceneTree

## Capturas reproducibles del mundo real de Villa Robledal, con guardado del
## mundo desconectado e inventario/exploración redirigidos a /private/tmp.
## Godot --path . --audio-driver Dummy --script tools/diagnostics/review_village.gd -- --label=after

const CENTER := Vector2(-1450.0, 650.0)
const YAW := 0.42
const OUTPUT_ROOT := "/private/tmp/robledal_review"

var _output := OUTPUT_ROOT
var _world: Node3D
var _camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			_output += "_" + argument.trim_prefix("--label=").validate_filename()
	DirAccess.make_dir_recursive_absolute(_output)
	for singleton_name in ["ExplorationManager", "InventoryManager"]:
		var singleton := root.get_node(singleton_name)
		singleton.set("autosave_enabled", false)
		singleton.set("save_path", _output.path_join(singleton_name + ".json"))
	var saves := root.get_node("SaveGameManager")
	saves.set_process(false)
	root.get_node("GameSettings").call("set_resolution", Vector2i(1600, 900), false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	# bind_world() sucede durante _ready; se desliga antes del primer frame.
	saves.call("bind_world", null)
	_world.set("sun_cycle_radians", 1.08)
	_world.call("_update_sun_cycle", 0.0)
	_world.set("sun_cycle_enabled", false)
	_world.set_physics_process(false)
	var player := _world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.visible = false
	player.global_position = _village_point(Vector3(0.0, 2.0, 0.0))
	_world.get_node("HUD").visible = false
	_world.get_node("CameraRig").set_process(false)
	_world.get_node("CameraRig").set_physics_process(false)
	(_world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D).current = false
	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.far = 4000.0
	_world.add_child(_camera)
	_camera.current = true
	_camera.global_position = _village_point(Vector3(0.0, 4.5, 135.0))
	_camera.look_at(_village_point(Vector3(0.0, 9.0, -110.0)))
	# Calentar iluminación, LOD y animaciones sin dejar correr el autoguardado.
	for _frame in 90:
		await process_frame
	await _capture("street", _village_point(Vector3(0.0, 4.5, 135.0)), _village_point(Vector3(0.0, 9.0, -110.0)))
	await _capture("overview", _village_point(Vector3(220.0, 360.0, 530.0)), _village_point(Vector3(0.0, 10.0, 0.0)))
	var houses: Array[Node3D] = []
	for child in _world.get_node("MedievalSetDressing").get_children():
		if child is Node3D and String(child.name).begins_with("Villa Robledal") and child.has_meta("floor_count"):
			houses.append(child)
	houses.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
	var captured_floors: Dictionary = {}
	for house in houses:
		var floors := int(house.get_meta("floor_count", 0))
		if captured_floors.has(floors):
			continue
		captured_floors[floors] = true
		var doorway := house.get_node("Doorway") as Node3D
		var interior := house.get_node("InteriorPoint") as Node3D
		var outward := (doorway.global_position - interior.global_position).normalized()
		var tangent := outward.cross(Vector3.UP).normalized()
		var extent := house.get_meta("footprint", Vector2(22.0, 22.0)) as Vector2
		var distance := maxf(extent.length() * 0.82, 34.0)
		var aim := house.global_position + Vector3.UP * floors * 2.4
		await _capture("facade_%df" % floors, doorway.global_position + outward * distance + tangent * 11.0 + Vector3.UP * floors * 2.7, aim)
		print("VILLAGE REVIEW HOUSE: %s · %s · %d floors · position %s" % [house.name, house.get_meta("recipe", ""), floors, house.global_position])
		if captured_floors.size() == 1:
			await _capture("door_from_inside", interior.global_position + Vector3.UP * 0.3, doorway.global_position + outward * 4.0 + Vector3.UP * 0.3)
			await _capture("interior", interior.global_position + Vector3.UP * 0.35, house.global_position + Vector3.UP * 3.6)
		await _capture("interior_%df" % floors, interior.global_position + Vector3.UP * 0.35, house.global_position + Vector3.UP * 3.6)
		var furnishing := house.get_node_or_null("InteriorDecorations")
		if furnishing != null:
			for item in furnishing.get_children():
				if String(item.name).begins_with("Table_Large"):
					var furniture_aim: Vector3 = item.global_position + Vector3.UP * 1.0
					await _capture("furnished_room_%df" % floors, item.global_position + house.global_basis.orthonormalized() * Vector3(-2.9, 2.0, 3.0), furniture_aim)
					break
		var ramps: Array[CollisionShape3D] = []
		for child in house.get_children():
			if child is CollisionShape3D and String(child.name).begins_with("Escalera") and child.shape is ConvexPolygonShape3D:
				ramps.append(child)
		ramps.sort_custom(func(a: CollisionShape3D, b: CollisionShape3D) -> bool: return a.position.y < b.position.y)
		if not ramps.is_empty():
			await _capture_stair("stairs_%df_ground" % floors, ramps.front())
			await _capture_stair("stairs_%df_last" % floors, ramps.back())
	if houses.is_empty():
		push_error("Villa Robledal no produjo ninguna casa para la revisión visual.")
		quit(1)
		return
	await _capture_folk()
	print("VILLAGE REVIEW COMPLETE: %s · renderer %s · %d houses" % [_output, RenderingServer.get_current_rendering_method(), houses.size()])
	quit()


func _capture_stair(label: String, ramp: CollisionShape3D) -> void:
	# El prisma de BuildingAssembler publica cada lateral como cuatro vértices:
	# pie, pie inferior, cabeza, cabeza inferior. El centro pisa exactamente la
	# misma cuña que el héroe, y da una perspectiva repetible a altura de ojos.
	var points := (ramp.shape as ConvexPolygonShape3D).points
	if points.size() != 8:
		return
	var foot := ramp.to_global((points[0] + points[4]) * 0.5)
	var head := ramp.to_global((points[2] + points[6]) * 0.5)
	var forward := Vector3(head.x - foot.x, 0.0, head.z - foot.z).normalized()
	await _capture(label, foot - forward * 0.7 + Vector3.UP * 1.6, head + Vector3.UP * 0.5)


func _capture_folk() -> void:
	var folk := _world.get_node_or_null("MedievalSetDressing/Villa RobledalVecinos")
	if folk == null:
		return
	folk.set_physics_process(false)
	for walker in folk.get_children():
		if not walker is Node3D:
			continue
		if bool(walker.get_meta("mounted_patrol", false)):
			var aim: Vector3 = walker.global_position + Vector3.UP * 2.4
			await _capture("mounted_patrol", walker.global_position + walker.global_basis * Vector3(6.5, 3.7, 6.5), aim)
			await _capture("mounted_patrol_side", walker.global_position + walker.global_basis * Vector3(7.5, 3.8, 0.0), aim)
		elif walker is CharacterBody3D and walker.get("work_station") != null:
			var label := String(walker.call("trade_label")).validate_filename()
			await _capture("work_" + label, walker.global_position + walker.global_basis * Vector3(4.5, 2.9, 5.0), walker.global_position + Vector3.UP * 1.25)


func _village_point(local: Vector3) -> Vector3:
	var flat := CENTER + Vector2(local.x, local.z).rotated(YAW)
	var height: float = _world.get_node("Terrain3D").data.get_height(Vector3(CENTER.x, 0.0, CENTER.y))
	return Vector3(flat.x, height + local.y, flat.y)


func _capture(label: String, eye: Vector3, target: Vector3) -> void:
	_camera.global_position = eye
	_camera.look_at(target)
	_world.get_node("VegetationScatter").call("_update_explicit_lod_visibility", true)
	for _frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _output.path_join(label + ".png")
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("No se pudo escribir %s: %s" % [path, error_string(error)])
		quit(1)
	print("VILLAGE REVIEW CAPTURE: %s" % path)
