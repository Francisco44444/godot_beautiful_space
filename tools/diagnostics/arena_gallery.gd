extends SceneTree
const OUT := "/private/tmp/claude-501/-Users-francisco-Documents-Juego-de-paisajes/11e0f619-b5fe-4e95-a899-e4124ff5129a/scratchpad/"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1440, 810))
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _f in 18: await process_frame
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false); player.visible = false
	(world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D).current = false
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.far = 3000.0
	var hud := world.get_node_or_null("HUD")
	if hud != null: hud.visible = false
	var terr := world.get_node("Terrain3D")
	var rt := world.get_node("RPGStoryRuntime")
	for c in rt.get_children():
		if c is RPGBoss: (c as RPGBoss).set_sealed(false)
	var i := 0
	for arena in RPGBestiary.ARENAS:
		var p: Vector2 = arena["centre"]
		var h: float = terr.data.get_height(Vector3(p.x, 0.0, p.y))
		if is_nan(h): h = 0.0
		cam.global_position = Vector3(p.x + 30.0, h + 19.0, p.y + 30.0)
		cam.look_at(Vector3(p.x, h + 3.0, p.y), Vector3.UP)
		for _f in 12: await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OUT + "arena_%d_%s.png" % [i, String(arena["id"])])
		print("arena %d: %s" % [i, String(arena["id"])])
		i += 1
	quit()
