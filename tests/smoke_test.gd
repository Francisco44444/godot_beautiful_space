extends SceneTree

## Prueba mínima ejecutable con:
## godot --headless --path . --script res://tests/smoke_test.gd


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var failures: Array[String] = []
	var packed_scene := load("res://scenes/world.tscn") as PackedScene

	if packed_scene == null:
		failures.append("No se pudo cargar scenes/world.tscn")
	else:
		var world := packed_scene.instantiate()
		root.add_child(world)
		# Terrain3D carga su directorio de regiones al entrar en el árbol.
		await process_frame
		await process_frame
		_check_node(world, "Player", "CharacterBody3D", failures)
		_check_node(world, "Horse", "CharacterBody3D", failures)
		_check_node(world, "CameraRig/SpringArm3D/Camera3D", "Camera3D", failures)
		_check_node(world, "WorldEnvironment", "WorldEnvironment", failures)
		_check_node(world, "ValleyMist", "FogVolume", failures)
		_check_node(world, "AmbientAudio/Music", "AudioStreamPlayer", failures)
		_check_node(world, "AmbientAudio/Wind", "AudioStreamPlayer", failures)
		_check_node(world, "AmbientAudio/Birds", "AudioStreamPlayer", failures)
		_check_node(world, "EpicLandmark", "Node3D", failures)
		_check_node(world, "MedievalSetDressing", "Node3D", failures)
		_check_node(world, "IslandEnvironment/LowPolyOcean", "MeshInstance3D", failures)
		_check_node(world, "IslandEnvironment/NightStars", "MultiMeshInstance3D", failures)
		_check_node(world, "HUD/MiniMap", "Control", failures)
		_check_node(world, "HUD/FullMap", "Control", failures)
		_check_node(world, "Player/Visual/ModelRoot", "Node3D", failures)
		_check_node(world, "Horse/Visual/ModelRoot", "Node3D", failures)
		_check_node(world, "Player/Visual/AttackArea", "Area3D", failures)
		_check_node(world, "Terrain3D", "Terrain3D", failures)
		_check_node(world, "Lookout/Deck/Collision", "CollisionShape3D", failures)
		var terrain := world.get_node_or_null("Terrain3D")
		if terrain != null and terrain.data.get_region_count() != 16:
			failures.append("Terrain3D debería cargar dieciséis regiones para la isla de 100 km²")
		if terrain != null and absf(float(terrain.vertex_spacing) - 9.765625) > 0.001:
			failures.append("Terrain3D no está escalado a los 10 km de ancho")
		world.queue_free()
		for _frame in range(8):
			await process_frame

	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "interact", "attack", "map"]:
		if not InputMap.has_action(action):
			failures.append("Falta la acción de entrada: %s" % action)

	if failures.is_empty():
		print("SMOKE TEST OK: isla de 100 km², mar low-poly, mapa, hito, audio y controles disponibles.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_node(parent: Node, path: String, expected_class: String, failures: Array[String]) -> void:
	var node := parent.get_node_or_null(path)
	if node == null:
		failures.append("Falta el nodo: %s" % path)
	elif not node.is_class(expected_class):
		failures.append("%s debería ser %s" % [path, expected_class])
