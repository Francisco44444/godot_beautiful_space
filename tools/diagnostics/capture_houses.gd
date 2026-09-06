extends SceneTree

const OUT := "/private/tmp/claude-501/-Users-francisco-Documents-Juego-de-paisajes/11e0f619-b5fe-4e95-a899-e4124ff5129a/scratchpad/"
const ROOT := "res://assets/quaternius/store_bundle/glTF/"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var world := Node3D.new()
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(38.0), 0.0)
	light.light_energy = 1.25
	world.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.74)
	e.ambient_light_energy = 0.85
	env.environment = e
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true

	var metrics := _roof_metrics()
	var catalog := BuildingCatalog.families()
	var vistas := [
		["casa_del_rio", BuildingRecipes.cottage(), Vector3(21, 11, 21)],
		["mercader", BuildingRecipes.merchant_house(), Vector3(30, 18, 30)],
		["posada", BuildingRecipes.tavern(), Vector3(34, 19, 32)],
		["valdoria", BuildingRecipes.manor(), Vector3(40, 24, 40)],
	]
	for vista in vistas:
		var solver := BuildingSolver.new()
		solver.solve(vista[1], metrics)
		var assembler := BuildingAssembler.new()
		var node := assembler.assemble(solver, vista[1], catalog)
		world.add_child(node)
		var eye: Vector3 = vista[2]
		cam.global_position = eye
		cam.look_at(Vector3(0.0, 4.5, 0.0), Vector3.UP)
		for _f in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_png(OUT + "casa_" + String(vista[0]) + ".png")
		# Y un corte por dentro, desde arriba, para ver plantas y escaleras.
		cam.global_position = Vector3(0.0, 34.0, 0.1)
		cam.look_at(Vector3.ZERO, Vector3.FORWARD)
		for _f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OUT + "planta_" + String(vista[0]) + ".png")
		node.queue_free()
		await process_frame
	print("capturas listas")
	quit()

func _roof_metrics() -> Dictionary:
	var m := {}
	for n in BuildingRecipes.ROOF_MESHES:
		var sc := load(ROOT + n + ".gltf") as PackedScene
		if sc == null: continue
		var inst := sc.instantiate()
		var box := AABB(); var first := true
		for mi in _meshes(inst):
			var t := Transform3D.IDENTITY
			var w: Node = mi
			while w != null and w != inst.get_parent():
				if w is Node3D: t = (w as Node3D).transform * t
				w = w.get_parent()
			var b: AABB = t * mi.get_aabb()
			box = b if first else box.merge(b); first = false
		inst.queue_free()
		if not first: m[n] = box
	return m

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D: out.append(node)
	for c in node.get_children(): out.append_array(_meshes(c))
	return out
