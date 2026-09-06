extends SceneTree
const OUT := "/private/tmp/claude-501/-Users-francisco-Documents-Juego-de-paisajes/11e0f619-b5fe-4e95-a899-e4124ff5129a/scratchpad/"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1440, 810))
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _f in 18: await process_frame
	var rt := world.get_node("RPGStoryRuntime")
	var player := world.get_node("Player") as CharacterBody3D
	var boss: RPGBoss = null
	for c in rt.get_children():
		if c is RPGBoss and (c as RPGBoss).demand == RPGBoss.Demand.BOW:
			boss = c as RPGBoss
			break
	boss.set_sealed(false)
	(world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D).current = false
	var cam := Camera3D.new(); world.add_child(cam); cam.current = true; cam.far = 900.0
	var hud := world.get_node_or_null("HUD")
	if hud != null: hud.visible = false
	player.global_position = boss.global_position + Vector3(7.0, 0.0, 7.0)
	var eye := boss.global_position + Vector3(11.0, 6.5, 11.0)
	cam.global_position = eye
	cam.look_at(boss.global_position + Vector3.UP * 3.5, Vector3.UP)
	for _f in 6: await process_frame
	# Rechazo: la coraza aguanta.
	boss.receive_tool_hit("sword", "Sword", boss.global_position + Vector3(0.0, 5.0, 3.4), player)
	for _f in 8: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + "chispas_rechazo.png")
	print("rechazo guardado")
	# Rotura: la guardia cede.
	while boss.stance != RPGBoss.Stance.OPEN and boss._ward > 0:
		boss.receive_projectile_hit(boss.global_position + Vector3(0, 3.0, 1.4), player)
	for _f in 8: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + "chispas_rotura.png")
	print("rotura guardada")
	quit()
