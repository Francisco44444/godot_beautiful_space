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

	if audio.layers_started != 5 or not audio.all_layers_playing():
		_fail("Las cinco capas de música y ambiente no comenzaron a reproducirse.")
		return
	if (
		not audio.music.stream is AudioStreamMP3
		or audio.music.stream.resource_path != "res://assets/music/The Hill that Knows your Voice.mp3"
		or audio.music.stream.get_length() < 197.0
		or not (audio.music.stream as AudioStreamMP3).loop
	):
		_fail("The Hill that Knows your Voice no está cargada y configurada en loop.")
		return
	if (
		not audio.snow_music.stream is AudioStreamMP3
		or audio.snow_music.stream.resource_path != "res://assets/music/Promise - nieve.mp3"
		or audio.snow_music.stream.get_length() < 165.0
		or not (audio.snow_music.stream as AudioStreamMP3).loop
	):
		_fail("Promise no está cargada como música en bucle para la nieve.")
		return
	if (
		not audio.desert_music.stream is AudioStreamMP3
		or audio.desert_music.stream.resource_path != "res://assets/music/Ashes-desierto.mp3"
		or audio.desert_music.stream.get_length() < 79.0
		or not (audio.desert_music.stream as AudioStreamMP3).loop
	):
		_fail("Ashes no está cargada como música en bucle para el desierto.")
		return
	if audio.wind.stream.get_length() < 23.5 or audio.birds.stream.get_length() < 31.5:
		_fail("Los loops de viento o pájaros están incompletos.")
		return
	for layer in [audio.wind, audio.birds]:
		if not (layer.stream as AudioStreamOggVorbis).loop:
			_fail("Una capa de ambiente original no está configurada en loop.")
			return
	audio.music.volume_db = audio.music_volume_db
	audio.snow_music.volume_db = -60.0
	audio.desert_music.volume_db = -60.0
	audio.wind.volume_db = audio.wind_volume_db
	audio.birds.volume_db = audio.birds_volume_db
	audio.fade_in_seconds = 0.1
	var terrain := world.get_node("Terrain3D") as Terrain3D
	var desert_point := Vector2(2350.0, 2050.0)
	player.global_position = Vector3(desert_point.x, terrain.data.get_height(Vector3(desert_point.x, 0.0, desert_point.y)), desert_point.y)
	audio.call("_process", 1.0)
	if audio.current_music_zone != "desert" or audio.desert_music.volume_db < audio.music.volume_db + 35.0 or audio.desert_music_weight < 0.95:
		_fail("Ashes no toma la mezcla al entrar en las Dunas Doradas.")
		return
	if audio.birds.volume_db > -58.0:
		_fail("Los pájaros del valle continúan sonando dentro del desierto: %.2f dB" % audio.birds.volume_db)
		return
	var snow_point := Vector2(520.0, -3000.0)
	player.global_position = Vector3(snow_point.x, terrain.data.get_height(Vector3(snow_point.x, 0.0, snow_point.y)), snow_point.y)
	audio.call("_process", 1.0)
	if audio.current_music_zone != "snow" or audio.snow_music.volume_db < audio.music.volume_db + 35.0 or audio.snow_music_weight < 0.90:
		_fail("Promise no toma la mezcla al entrar en Cumbres Blancas.")
		return
	var valley_point := Vector2(0.0, 190.0)
	player.global_position = Vector3(valley_point.x, terrain.data.get_height(Vector3(valley_point.x, 0.0, valley_point.y)), valley_point.y)
	audio.call("_process", 1.0)
	if audio.current_music_zone != "valley" or audio.music.volume_db < audio.snow_music.volume_db + 35.0 or audio.music.volume_db < audio.desert_music.volume_db + 35.0:
		_fail("La Colina que Conoce tu Voz no vuelve al abandonar los biomas especiales.")
		return
	if audio.birds.volume_db < audio.birds_volume_db - 1.0:
		_fail("Los pájaros no vuelven al abandonar el desierto: %.2f dB" % audio.birds.volume_db)
		return

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
		"AUDIO TEST OK: tres músicas por bioma (%.0f/%.0f/%.0f s), desierto sin pájaros, viento y %d cascos."
		% [
			audio.music.stream.get_length(),
			audio.snow_music.stream.get_length(),
			audio.desert_music.stream.get_length(),
			horse.hoofbeat_count,
		]
	)
	audio.music.stop()
	audio.snow_music.stop()
	audio.desert_music.stop()
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
