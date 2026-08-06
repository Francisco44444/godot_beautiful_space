extends SceneTree

## Valida el hito terrestre Quaternius y que la cascada retirada no reaparezca.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 4:
		await process_frame

	var landmark := world.get_node_or_null("EpicLandmark") as EpicLandmark
	if landmark == null:
		_fail("Falta EpicLandmark en el mundo.")
		return
	if landmark.cliff_piece_count != 16 or landmark.fortress_piece_count != 8:
		_fail("El hito debe conservar 16 rocas y 8 módulos de fortaleza Quaternius.")
		return
	if is_nan(landmark.landmark_ground_height):
		_fail("EpicLandmark no pudo leer la altura del terreno.")
		return
	if landmark.has_node("Waterfall") or landmark.has_node("Pool"):
		_fail("La cascada, la poza y el río deben permanecer eliminados.")
		return

	for root_name in ["EpicCliffs", "Fortress"]:
		var category := landmark.get_node_or_null(root_name) as Node3D
		if category == null or category.get_child_count() == 0:
			_fail("La sección terrestre %s del hito está vacía." % root_name)
			return

	for collision_path in [
		"EpicCliffs/CliffCollisionCenter",
		"EpicCliffs/CliffCollisionWest",
		"EpicCliffs/CliffCollisionEast",
		"Fortress/FortressCollision",
	]:
		var body := landmark.get_node_or_null(collision_path) as StaticBody3D
		if body == null or body.get_child_count() != 1:
			_fail("Falta la colisión sólida %s." % collision_path)
			return

	var ambient_audio := world.get_node("AmbientAudio") as AmbientAudio
	ambient_audio.music.stop()
	ambient_audio.wind.stop()
	ambient_audio.birds.stop()
	world.queue_free()
	for _frame in 8:
		await process_frame
	print("EPIC LANDMARK TEST OK: riscos y fortaleza Quaternius operativos, sin cascada ni agua.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
