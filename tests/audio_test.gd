extends SceneTree

## Valida buses, loops ambientales y cascos sincronizados con el galope.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := scene.instantiate()
	root.add_child(world)
	var audio := world.get_node("AmbientAudio") as AmbientAudio
	var player := world.get_node("Player") as Player
	var horse := world.get_node("Horse") as Horse

	for _frame in range(8):
		await physics_frame

	for bus_name in [&"Music", &"Ambience", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("Falta el bus de audio %s." % bus_name)
			return
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Music")) < 1:
		_fail("La música no tiene el espacio de reverberación configurado.")
		return
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Ambience")) < 1:
		_fail("El ambiente no tiene reverberación de valle.")
		return

	if audio.layers_started != 3 or not audio.all_layers_playing():
		_fail("Las tres capas ambientales no comenzaron a reproducirse.")
		return
	if audio.music.stream.get_length() < 47.5:
		_fail("La composición ambiental está incompleta.")
		return
	if audio.wind.stream.get_length() < 23.5 or audio.birds.stream.get_length() < 31.5:
		_fail("Los loops de viento o pájaros están incompletos.")
		return
	for layer in [audio.music, audio.wind, audio.birds]:
		if not (layer.stream as AudioStreamOggVorbis).loop:
			_fail("Una capa ambiental no está configurada en loop.")
			return
	audio.music.volume_db = audio.music_volume_db
	audio.wind.volume_db = audio.wind_volume_db
	audio.birds.volume_db = audio.birds_volume_db

	player.global_position = horse.global_position + horse.visual.global_basis.x * 2.0
	await physics_frame
	if not player.mount_horse(horse):
		_fail("No se pudo montar para probar los cascos.")
		return
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _frame in range(105):
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")

	if horse.hoofbeat_count < 3:
		_fail("El galope no disparó suficientes cascos: %d" % horse.hoofbeat_count)
		return
	if horse.hoof_audio.bus != &"SFX" or horse.hoof_audio.max_distance < 30.0:
		_fail("Los cascos no usan el bus o alcance 3D previstos.")
		return
	if audio.wind.volume_db < audio.wind_volume_db + 3.5:
		_fail("La mezcla adaptativa no elevó el viento durante el galope.")
		return
	if audio.music.volume_db > audio.music_volume_db - 1.2:
		_fail("La música no dejó espacio al galope en la mezcla adaptativa.")
		return

	print(
		"AUDIO TEST OK: música %.0f s, viento %.0f s, pájaros %.0f s y %d cascos."
		% [
			audio.music.stream.get_length(),
			audio.wind.stream.get_length(),
			audio.birds.stream.get_length(),
			horse.hoofbeat_count,
		]
	)
	audio.music.stop()
	audio.wind.stop()
	audio.birds.stop()
	horse.hoof_audio.stop()
	for _frame in range(8):
		await process_frame
	quit(0)


func _fail(message: String) -> void:
	Input.action_release("move_forward")
	Input.action_release("sprint")
	push_error(message)
	quit(1)
