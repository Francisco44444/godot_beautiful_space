extends SceneTree

## Mantiene el juego vivo durante tres segundos y cierra el audio de forma
## ordenada, evitando que un --quit-after interrumpa streams a mitad de mezcla.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		push_error("No se pudo cargar la escena principal.")
		quit(1)
		return

	var world := scene.instantiate()
	root.add_child(world)
	for _frame in range(180):
		await process_frame

	var audio := world.get_node("AmbientAudio") as AmbientAudio
	var horse := world.get_node("Horse") as Horse
	audio.music.stop()
	audio.wind.stop()
	audio.birds.stop()
	horse.hoof_audio.stop()
	for _frame in range(8):
		await process_frame
	print("RUNTIME STABILITY TEST OK: 180 fotogramas con audio y paisaje activos.")
	quit(0)
