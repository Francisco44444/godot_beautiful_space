extends SceneTree

## Verifica que el antiguo hito de la cascada se haya eliminado por completo.


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

	for forbidden_name in [
		"EpicLandmark", "Waterfall", "Pool", "WestTowerRoof", "EastTowerRoof",
		"CliffCollisionCenter", "CliffCollisionWest", "CliffCollisionEast",
	]:
		if world.find_child(forbidden_name, true, false) != null:
			_fail("Todavía existe un resto del antiguo hito: %s." % forbidden_name)
			return

	var ambient_audio := world.get_node("AmbientAudio") as AmbientAudio
	ambient_audio.music.stop()
	ambient_audio.wind.stop()
	ambient_audio.birds.stop()
	world.queue_free()
	for _frame in 8:
		await process_frame
	print("EPIC LANDMARK TEST OK: cascada, tejados flotantes y rocas antiguas eliminados.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
