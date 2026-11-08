extends SceneTree

## Cerrar un acto tiene que ser una escena, no un párrafo que congela la isla.
## El cuadro de diálogo de historia PAUSA el árbol: usarlo justo después de
## tumbar a un jefe dejaba el cadáver a medio caer y el polvo quieto mientras
## leías. Aquí se fija que la cinemática mire el sitio, deje el mundo vivo, se
## pueda saltar y mida en segundos reales.


const MIN_CARDS := 2
## La cámara lenta del remate baja la escala a 0,16. Con el reloj de juego una
## tarjeta de 4 s duraría veinticinco.
const SLOW_SCALE := 0.16


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 7:
		await process_frame

	var runtime := world.get_node_or_null("RPGStoryRuntime")
	if runtime == null:
		_fail("Falta RPGStoryRuntime.")
		return
	var film: RPGCinematic = runtime.get("cinematic")
	if film == null:
		_fail("El runtime no monta la cinemática.")
		return
	var player := root.get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		_fail("No hay héroe.")
		return

	# El texto se parte en tarjetas: una con seis frases no se lee, se salta.
	var act: Dictionary = RPGCampaign.ACTS[0]
	var pieces: PackedStringArray = runtime.call("_split_prose", String(act["closing"]), 2)
	if pieces.size() < MIN_CARDS:
		_fail("El cierre no se parte en tarjetas: %d trozo(s)." % pieces.size())
		return
	for piece in pieces:
		if piece.strip_edges().is_empty():
			_fail("Una tarjeta salió vacía al partir la prosa.")
			return

	var before := film.plays
	runtime.call("_roll_act_cinematic", act, "El nombre de Mira")
	if film.plays != before + 1 or not film.running:
		_fail("Cerrar un acto no arranca la cinemática.")
		return

	# Lo que el panel de texto hacía mal: pausar el mundo.
	if paused:
		_fail("La cinemática pausó el árbol: el mundo se congela detrás.")
		return
	# La cámara la lleva ella.
	var eye := root.get_viewport().get_camera_3d()
	if eye == null or eye.name != "CinematicEye":
		_fail("La cinemática no toma la cámara (lleva %s)." % [eye.name if eye != null else "ninguna"])
		return
	for fotograma in 2: await process_frame
	if world.get_node("Terrain3D").get_camera()!=eye:
		_fail("El terreno no centra su detalle en la cámara de la cinemática.")
		return
	# Y mira al sitio del jefe, no a donde estuviera el héroe.
	var target := RPGCampaign.where_of(act)
	var eye_flat := Vector2(eye.global_position.x, eye.global_position.z)
	if eye_flat.distance_to(target) > 60.0:
		_fail("La cámara está a %.0f m del sitio del acto." % eye_flat.distance_to(target))
		return

	# Mide en segundos REALES. Comprobar sólo que "avanza algo" no vale: con el
	# reloj de juego también avanza, seis veces más despacio. Se contrasta el
	# descuento de la tarjeta contra el reloj de pared, que la escala de tiempo
	# no toca.
	Engine.time_scale = SLOW_SCALE
	var held := film._left
	var wall_start := Time.get_ticks_msec()
	for _frame in 60:
		await process_frame
	var wall := float(Time.get_ticks_msec() - wall_start) / 1000.0
	Engine.time_scale = 1.0
	var burned := held - film._left
	if wall < 0.05:
		_fail("La medida no tuvo tiempo suficiente (%.3f s de reloj)." % wall)
		return
	if burned < wall * 0.6:
		_fail("La tarjeta gastó %.2f s mientras pasaban %.2f s reales: mide en tiempo de juego y a escala %.2f duraría %.0f veces más." % [
			burned, wall, SLOW_SCALE, 1.0 / SLOW_SCALE])
		return

	# Se puede saltar, y al terminar devuelve la cámara y suelta al héroe.
	film.skip()
	# El fundido de salida dura 0,85 s reales y el bucle sin ventana corre a
	# ~145 fps: 90 fotogramas se quedaban cortos por medio segundo.
	for _frame in 400:
		await process_frame
		if not film.running:
			break
	if film.running:
		_fail("Saltar la cinemática no la cierra.")
		return
	var back := root.get_viewport().get_camera_3d()
	if back != null and back.name == "CinematicEye":
		_fail("Al terminar no devuelve la cámara del juego.")
		return
	for fotograma in 2: await process_frame
	if back!=null and world.get_node("Terrain3D").get_camera()!=back:
		_fail("El terreno no recupera la cámara de juego al acabar la cinemática.")
		return
	if not player.is_physics_processing():
		_fail("El héroe se queda sin mando después de la cinemática.")
		return

	# El epílogo: cerrar la campaña tiene que rodar una escena y dejar dicho
	# cuál de los cinco finales te tocó.
	runtime.get("_regard")["tavia"] = 9
	var plays_before := film.plays
	runtime.call("_show_epilogue")
	if film.plays != plays_before + 1 or not film.running:
		_fail("Terminar la campaña no rueda el epílogo.")
		return
	if String(runtime.get("last_ending")).is_empty():
		_fail("El epílogo no deja constancia de qué final salió.")
		return
	var chosen := String(runtime.get("last_ending"))
	var known := false
	for ending in RPGCampaign.ENDINGS:
		if String(ending["id"]) == chosen:
			known = true
			break
	if not known:
		_fail("El final '%s' no está entre los cinco." % chosen)
		return
	film.skip()
	for _frame in 400:
		await process_frame
		if not film.running:
			break

	print("OK · %d tarjetas, mundo vivo, cámara sobre el jefe y devuelta, saltable; epílogo '%s'" % [
		pieces.size(), chosen])
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
