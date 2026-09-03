extends SceneTree

## Captura visual determinista de la pradera para revisar densidad, LOD y viento.
## Uso: Godot --path . --script tests/grass_visual_capture.gd

const OUTPUT_PATH := "/private/tmp/grass_visual_capture.png"
const INTERACTION_OUTPUT_PATH := "/private/tmp/grass_interaction_capture.png"


func _initialize() -> void:
	call_deferred("_capture_meadow")


func _capture_meadow() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var packed := load("res://scenes/world.tscn") as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var terrain := world.get_node("Terrain3D") as Terrain3D
	var player := world.get_node("Player") as CharacterBody3D
	var meadow_point := _find_open_meadow()
	var height := terrain.data.get_height(Vector3(meadow_point.x, 0.0, meadow_point.y))
	player.global_position = Vector3(meadow_point.x, height + 0.35, meadow_point.y)
	player.set_physics_process(false)
	player.visible = false
	var gameplay_camera := world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D
	gameplay_camera.current = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 24000.0
	world.add_child(camera)
	camera.global_position = Vector3(meadow_point.x + 7.5, height + 2.15, meadow_point.y + 8.5)
	camera.look_at(Vector3(meadow_point.x - 5.0, height + 0.65, meadow_point.y - 12.0))
	camera.current = true
	world.get_node("HUD").visible = false
	paused = false
	(world.get_node("VegetationScatter") as VegetationScatter).call("_update_explicit_lod_visibility", true)

	# Deja que el gestor de celdas active el LOD y que terminen las primeras
	# compilaciones de shader antes de medir el coste real de una pradera.
	for _frame in 18:
		await process_frame
	var benchmark_started := Time.get_ticks_usec()
	for _frame in 60:
		await process_frame
	var benchmark_seconds := float(Time.get_ticks_usec() - benchmark_started) / 1000000.0
	var visible_full_instances := _visible_multimesh_instances(world.get_node("VegetationScatter/GrassCells"))
	var visible_mid_instances := _visible_multimesh_instances(world.get_node("VegetationScatter/GrassMidLODCells"))
	var visible_lod_instances := _visible_multimesh_instances(world.get_node("VegetationScatter/GrassLODCells"))
	print(
		"GRASS VISUAL PERF: %.1f fps · %d primitivas · %d draw calls · %d full + %d mid + %d LOD"
		% [
			60.0 / maxf(benchmark_seconds, 0.001),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			visible_full_instances,
			visible_mid_instances,
			visible_lod_instances,
		]
	)
	var grass_root := world.get_node("VegetationScatter/GrassCells") as Node3D
	var grass_mid_root := world.get_node("VegetationScatter/GrassMidLODCells") as Node3D
	var grass_lod_root := world.get_node("VegetationScatter/GrassLODCells") as Node3D
	grass_root.visible = false
	grass_mid_root.visible = false
	grass_lod_root.visible = false
	for _frame in 12:
		await process_frame
	var baseline_started := Time.get_ticks_usec()
	for _frame in 60:
		await process_frame
	var baseline_seconds := float(Time.get_ticks_usec() - baseline_started) / 1000000.0
	print(
		"GRASS VISUAL BASELINE: %.1f fps · %d primitivas · %d draw calls"
		% [
			60.0 / maxf(baseline_seconds, 0.001),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		]
	)
	grass_root.visible = true
	grass_mid_root.visible = true
	grass_lod_root.visible = true
	(world.get_node("VegetationScatter") as VegetationScatter).call("_update_explicit_lod_visibility", true)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("No se pudo guardar la captura de hierba: %s" % error_string(error))
		quit(1)
		return
	print("GRASS VISUAL CAPTURE: %s" % OUTPUT_PATH)
	player.visible = true
	camera.global_position = Vector3(meadow_point.x + 5.5, height + 5.8, meadow_point.y + 6.0)
	camera.look_at(Vector3(meadow_point.x, height + 0.55, meadow_point.y))
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(INTERACTION_OUTPUT_PATH)
	print("GRASS INTERACTION CAPTURE: %s" % INTERACTION_OUTPUT_PATH)
	quit()


func _find_open_meadow() -> Vector2:
	var cache := load("res://generated/vegetation_layout_cache.res") as VegetationLayoutCache
	var tree_grid: Dictionary = {}
	var cell_size := 64.0
	for offset in range(0, cache.forest_records.size(), 9):
		var point := Vector2(cache.forest_records[offset], cache.forest_records[offset + 2])
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		if not tree_grid.has(cell):
			tree_grid[cell] = []
		(tree_grid[cell] as Array).append(point)
	var best_point := Vector2(-980.0, -1060.0)
	var best_clearance := 0.0
	# Muestrear el cache mantiene esta utilidad rápida y escoge una pradera real,
	# ya filtrada de nieve, arena y bosque tenebroso.
	for offset in range(0, cache.grass_records.size(), 9 * 43):
		var candidate := Vector2(cache.grass_records[offset], cache.grass_records[offset + 2])
		if absf(candidate.x) > 3600.0 or absf(candidate.y) > 3300.0:
			continue
		var cell := Vector2i(floori(candidate.x / cell_size), floori(candidate.y / cell_size))
		var nearest := 96.0
		for cell_y in range(cell.y - 2, cell.y + 3):
			for cell_x in range(cell.x - 2, cell.x + 3):
				for tree_point in tree_grid.get(Vector2i(cell_x, cell_y), []):
					nearest = minf(nearest, candidate.distance_to(tree_point as Vector2))
		if nearest > best_clearance:
			best_clearance = nearest
			best_point = candidate
	return best_point


func _visible_multimesh_instances(root_node: Node) -> int:
	var result := 0
	for child in root_node.get_children():
		var instance := child as MultiMeshInstance3D
		if instance != null and instance.visible:
			result += instance.multimesh.instance_count
	return result
