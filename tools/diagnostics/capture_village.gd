extends SceneTree
const OUT := "/private/tmp/claude-501/-Users-francisco-Documents-Juego-de-paisajes/11e0f619-b5fe-4e95-a899-e4124ff5129a/scratchpad/"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _f in 8: await process_frame
	# Dejar que los vecinos echen a andar antes de retratarlos.
	for _f in 700: await physics_frame
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.visible = false
	(world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D).current = false
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.far = 4000.0

	var tomas := [
		["villa_gente", Vector3(-1431.2, 25.7, 608.0), Vector3(-1482.6, 25.6, 723.0)],
		["villa_aerea", Vector3(-1450, 340, 980), Vector3(-1440, 20, 660)],
	]
	for t in tomas:
		cam.global_position = t[1]
		cam.look_at(t[2], Vector3.UP)
		for _f in 12: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OUT + "robledal_" + String(t[0]) + ".png")
	print("capturas de villa listas")
	quit()
