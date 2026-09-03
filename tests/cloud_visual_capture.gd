extends SceneTree

## Captura determinista del cielo para comprobar cúmulos, disco solar y coste.

const HORIZON_OUTPUT_PATH := "/private/tmp/cloud_visual_horizon.png"
const HIGH_SKY_OUTPUT_PATH := "/private/tmp/cloud_visual_high_sky.png"
const GROUND_OUTPUT_PATH := "/private/tmp/cloud_visual_ground.png"


func _initialize() -> void:
	call_deferred("_capture_clouds")


func _capture_clouds() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var packed := load("res://scenes/world.tscn") as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.sun_cycle_enabled = true
	world.sun_cycle_radians = 0.22
	world.call("_update_sun_cycle", 0.0)
	world.sun_cycle_enabled = false
	var terrain := world.get_node("Terrain3D") as Terrain3D
	var point := Vector2(-720.0, 740.0)
	var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	var gameplay_camera := world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D
	gameplay_camera.current = false
	var camera := Camera3D.new()
	camera.fov = 66.0
	camera.far = 24000.0
	world.add_child(camera)
	# Cámara aérea para inspeccionar cielo, horizonte y transición atmosférica sin
	# que el tejado cercano tape la mayor parte de la captura.
	camera.global_position = Vector3(point.x, height + 180.0, point.y)
	camera.current = true
	var island_environment := world.get_node("IslandEnvironment")
	island_environment.call("sync_celestial_sources", camera)
	var sun_direction: Vector3 = island_environment.get("sun_source_direction")
	var horizon_direction := Vector3(sun_direction.x, maxf(sun_direction.y, 0.32), sun_direction.z).normalized()
	camera.look_at(camera.global_position + horizon_direction * 1200.0)
	var animated_clouds := world.get_node("AnimatedClouds")
	animated_clouds.call("_process", 0.0)
	world.get_node("HUD").visible = false
	for _frame in 40:
		await process_frame
	var started := Time.get_ticks_usec()
	for _frame in 60:
		await process_frame
	var seconds := float(Time.get_ticks_usec() - started) / 1000000.0
	print(
		"CLOUD VISUAL PERF: %.1f fps · %d primitivas · %d draw calls"
		% [
			60.0 / maxf(seconds, 0.001),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		]
	)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(HORIZON_OUTPUT_PATH)
	if error != OK:
		push_error("No se pudo guardar la captura de nubes: %s" % error_string(error))
		quit(1)
		return
	print("CLOUD VISUAL CAPTURE: %s" % HORIZON_OUTPUT_PATH)
	var high_sky_direction := Vector3(
		sun_direction.x,
		maxf(sun_direction.y, 0.62),
		sun_direction.z
	).normalized()
	camera.look_at(camera.global_position + high_sky_direction * 1200.0)
	animated_clouds.call("_process", 0.0)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png(HIGH_SKY_OUTPUT_PATH)
	if error != OK:
		push_error("No se pudo guardar la captura alta: %s" % error_string(error))
		quit(1)
		return
	print("CLOUD VISUAL CAPTURE: %s" % HIGH_SKY_OUTPUT_PATH)
	camera.global_position = Vector3(point.x, height + 5.0, point.y)
	var ground_direction := Vector3(
		sun_direction.x,
		maxf(sun_direction.y, 0.22),
		sun_direction.z
	).normalized()
	camera.look_at(camera.global_position + ground_direction * 1200.0)
	animated_clouds.call("_process", 0.0)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png(GROUND_OUTPUT_PATH)
	if error != OK:
		push_error("No se pudo guardar la captura desde tierra: %s" % error_string(error))
		quit(1)
		return
	print("CLOUD VISUAL CAPTURE: %s" % GROUND_OUTPUT_PATH)
	quit(0)
