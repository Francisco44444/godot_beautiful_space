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
	var player := world.get_node("Player") as CharacterBody3D

	# Unos fotogramas para que el personaje se apoye sobre el suelo.
	for _frame in range(12):
		await physics_frame

	var start_position := player.global_position
	Input.action_press("move_forward")
	for _frame in range(30):
		await physics_frame
	Input.action_release("move_forward")

	var horizontal_distance := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	if horizontal_distance < 0.8:
		_fail("El personaje no avanzó lo esperado: %.3f m" % horizontal_distance)
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

	print("MOVEMENT TEST OK: avance %.2f m y salto funcional." % horizontal_distance)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

