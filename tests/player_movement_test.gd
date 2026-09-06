extends SceneTree

## Prueba funcional: deja caer al personaje, simula avance y salto,
## y verifica que CharacterBody3D responde a la entrada y a la física.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/world.tscn") as PackedScene
	if packed_scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := packed_scene.instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as Player

	# Unos fotogramas para que el personaje se apoye sobre el suelo.
	for _frame in range(12):
		await physics_frame

	var shift_binding_found := false
	for event in InputMap.action_get_events("sprint"):
		var key_event := event as InputEventKey
		if key_event != null and (key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT):
			shift_binding_found = true
			break
	if not shift_binding_found:
		_fail("La acción sprint no está vinculada correctamente a Mayús.")
		return

	var start_position := player.global_position
	Input.action_press("move_forward")
	for _frame in range(45):
		await physics_frame
	var walking_animation := player.animation_player.current_animation
	Input.action_release("move_forward")

	var horizontal_distance := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	if horizontal_distance < 0.8:
		_fail("El personaje no avanzó lo esperado: %.3f m" % horizontal_distance)
		return
	if walking_animation != "Walk":
		_fail("El personaje no usó Walk durante la marcha normal: %s" % walking_animation)
		return

	for _frame in range(12):
		await physics_frame
	var sprint_start := player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _frame in range(45):
		await physics_frame
	var running_animation := player.animation_player.current_animation
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var sprint_distance := Vector2(
		player.global_position.x - sprint_start.x,
		player.global_position.z - sprint_start.z
	).length()
	if sprint_distance < horizontal_distance * 1.35:
		_fail("Mayús no aumentó claramente la velocidad: caminar %.2f m, correr %.2f m." % [horizontal_distance, sprint_distance])
		return
	if running_animation != "Run":
		_fail("El personaje no usó Run al correr con Mayús: %s" % running_animation)
		return
	if player.walk_animation_rate < 1.25:
		_fail("La animación Walk sigue configurada demasiado lenta.")
		return

	# Esperamos a que vuelva a estar bien apoyado y disparamos un salto.
	for _frame in range(8):
		await physics_frame
	var floor_height := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for _frame in range(8):
		await physics_frame

	if player.global_position.y <= floor_height + 0.15:
		_fail("El personaje no respondió al salto.")
		return

	# El salto no puede ser un globo: a 1.43 m de altura y más de un segundo en
	# el aire parecía que el héroe bajaba flotando de pie. Se comprueba el ápice
	# y que la bajada sea más rápida que la subida.
	var apex := player.global_position.y - floor_height
	var rise_frames := 8
	var air_frames := 8
	for frame_index in range(200):
		await physics_frame
		air_frames += 1
		var height := player.global_position.y - floor_height
		if height > apex:
			apex = height
			rise_frames = air_frames
		if player.is_on_floor():
			break
	if apex > 1.15:
		_fail("El salto sube demasiado: %.2f m." % apex)
		return
	if air_frames - rise_frames >= rise_frames:
		_fail("La bajada del salto no es más rápida que la subida: parece flotar.")
		return

	print("MOVEMENT TEST OK: caminar %.2f m, correr %.2f m con Mayús y salto de %.2f m que cae más rápido de lo que sube." % [
		horizontal_distance, sprint_distance, apex])
	quit(0)


func _fail(message: String) -> void:
	Input.action_release("move_forward")
	Input.action_release("sprint")
	push_error(message)
	quit(1)
