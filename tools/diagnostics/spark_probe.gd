extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _f in 7: await process_frame
	var rt := world.get_node("RPGStoryRuntime")
	var player := world.get_node("Player")
	var boss: RPGBoss = null
	for c in rt.get_children():
		if c is RPGBoss and (c as RPGBoss).demand == RPGBoss.Demand.BOW:
			boss = c as RPGBoss
			break
	boss.set_sealed(false)
	boss.receive_tool_hit("sword", "Sword", boss.global_position + Vector3(0, 3.0, 1.6), player)
	for _f in 3: await process_frame
	var found := 0
	for c in rt.get_children():
		if c is CPUParticles3D:
			var p := c as CPUParticles3D
			found += 1
			print("burst: emitting=%s amount=%d pos=%.1f,%.1f,%.1f  visible=%s  layers=%d" % [
				p.emitting, p.amount, p.global_position.x, p.global_position.y, p.global_position.z,
				p.visible, p.layers])
			print("       jefe en %.1f,%.1f,%.1f  malla=%s" % [
				boss.global_position.x, boss.global_position.y, boss.global_position.z,
				p.mesh != null])
	print("nodos de chispas: %d   contador=%d" % [found, int(rt.get("spark_burst_count"))])
	quit()
