extends SceneTree

## Cada arena tiene que castigar una postura distinta y ofrecer un refugio
## distinto. Dos cosas se rompen por separado: un peligro sin refugio alcanzable
## vuelve la arena insuperable, y un peligro que muerde con el jefe sellado
## castiga a quien sólo pasaba por allí.


const STYLES_WITH_STONE := ["piedras", "solar", "eco"]
const MIN_SHELTERS := 4


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
	var player := root.get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		_fail("No hay héroe.")
		return

	var seen: Dictionary = {}
	for arena in RPGBestiary.ARENAS:
		var id := String(arena["id"])
		var hazard := runtime.get_node_or_null("Peligro_%s" % id) as RPGArenaHazard
		if hazard == null:
			_fail("La arena de %s no levanta su peligro." % id)
			return
		seen[hazard.style] = true

		# Refugio alcanzable: sin piedras, el sitio es insuperable.
		if hazard.style in STYLES_WITH_STONE:
			if hazard.shelters.size() < MIN_SHELTERS:
				_fail("%s (%s) sólo tiene %d refugios: la arena sería insuperable." % [
					id, hazard.style, hazard.shelters.size()])
				return
			var stone: Vector2 = hazard.shelters[0]
			if not hazard.sheltered(stone):
				_fail("%s: pegado a una piedra el sitio sigue mordiendo." % id)
				return
			# Y en campo abierto no protege.
			var open := hazard.centre + Vector2(hazard.radius * 0.5, 0.0)
			var clear := true
			for shelter in hazard.shelters:
				if open.distance_to(shelter) <= RPGArenaHazard.SHELTER_REACH:
					clear = false
					break
			if clear and hazard.sheltered(open):
				_fail("%s: en campo abierto se comporta como si hubiera refugio." % id)
				return
		elif hazard.style == "raices":
			if not hazard.sheltered(hazard.centre):
				_fail("%s: sobre la losa las esporas siguen subiendo." % id)
				return
			if hazard.sheltered(hazard.centre + Vector2(hazard.floor_radius + 4.0, 0.0)):
				_fail("%s: fuera de la losa debería haber esporas." % id)
				return

		# Con el jefe sellado el sitio no castiga a quien sólo pasa.
		var boss: Node = hazard.boss
		if boss == null:
			_fail("El peligro de %s no sabe de qué jefe depende." % id)
			return
		boss.set("sealed", true)
		hazard.set("_left", 0.001)
		var quiet := hazard.bites
		player.global_position = Vector3(hazard.centre.x, player.global_position.y, hazard.centre.y)
		for _frame in 12:
			await process_frame
		if hazard.bites != quiet:
			_fail("%s muerde con el jefe todavía sellado." % id)
			return

	if seen.size() != 5:
		_fail("Se esperaban cinco peligros distintos y hay %d." % seen.size())
		return

	# Y despierto, castiga a quien está fuera de refugio.
	var probe := runtime.get_node_or_null("Peligro_centinela_bruma") as RPGArenaHazard
	probe.boss.set("sealed", false)
	var far := probe.centre
	for shelter in probe.shelters:
		while far.distance_to(shelter) <= RPGArenaHazard.SHELTER_REACH + 1.0:
			far += Vector2(1.5, 1.5)
	player.global_position = Vector3(far.x, player.global_position.y, far.y)
	var before := probe.bites
	for _frame in 240:
		await process_frame
		if probe.bites > before:
			break
	if probe.bites <= before:
		_fail("Con el jefe despierto y sin refugio, la bruma no muerde.")
		return

	# La pieza que se hunde tiene que ser la del refugio que cae. El par va por
	# orden de creación: si se desalinea, el jefe derriba un menhir y desaparece
	# otro, y el jugador ve cobijo donde ya no lo hay.
	var solar := runtime.get_node_or_null("Arena_guardian_solar")
	var stones: PackedVector2Array = solar.get("shelter_points")
	var pieces: Array = solar.get("shelter_visuals")
	if stones.size() != pieces.size() or stones.is_empty():
		_fail("Los refugios y sus piezas no van emparejados (%d vs %d)." % [
			stones.size(), pieces.size()])
		return
	for index in stones.size():
		var piece := pieces[index] as Node3D
		if piece == null or not is_instance_valid(piece):
			_fail("El refugio %d no tiene pieza visible." % index)
			return
		var flat := Vector2(piece.global_position.x, piece.global_position.z)
		if flat.distance_to(stones[index]) > 1.0:
			_fail("El refugio %d apunta a una pieza que está a %.1f m." % [
				index, flat.distance_to(stones[index])])
			return

	# Cada fase del jefe cierra una salida — y ninguna arena puede quedarse sin
	# ninguna. Un sitio sin escapatoria no es difícil, es imposible.
	for arena in RPGBestiary.ARENAS:
		var id := String(arena["id"])
		var site := runtime.get_node_or_null("Peligro_%s" % id) as RPGArenaHazard
		if site.boss.hazard != site:
			_fail("El jefe de %s no sabe cerrar su arena." % id)
			return
		var mercy_before := _mercy(site)
		# Tres fases: el jefe aprieta dos veces.
		for _phase in 2:
			if String(site.call("tighten")).is_empty():
				_fail("Apretar %s no dice qué se ha cerrado." % id)
				return
		var mercy_after := _mercy(site)
		if mercy_after >= mercy_before:
			_fail("%s (%s) no se cierra al cambiar de fase: %.1f -> %.1f" % [
				id, site.style, mercy_before, mercy_after])
			return
		if not _has_escape(site):
			_fail("%s se queda sin salida tras dos fases: imposible, no difícil." % id)
			return

	# La regla se dice: un sitio que castiga sin explicar parece una avería.
	for arena in RPGBestiary.ARENAS:
		var check := runtime.get_node_or_null("Peligro_%s" % String(arena["id"])) as RPGArenaHazard
		var rule := String(check.call("_rule"))
		if rule.length() < 30 or not rule.contains("·"):
			_fail("El peligro de %s no explica su regla: '%s'" % [String(arena["id"]), rule])
			return
		if String(check.call("_source")).length() > 20:
			_fail("El nombre corto de %s no cabe en «X te hiere»." % String(arena["id"]))
			return

	print("OK · 5 peligros de arena que el jefe cierra por fases sin dejarte sin salida, mudos con el jefe sellado")
	quit(0)


## Cuánta clemencia queda en el sitio: para cada estilo, lo que te salva.
func _mercy(site: RPGArenaHazard) -> float:
	match site.style:
		"raices":
			return site.floor_radius
		"observatorio":
			# Cuanto más rápido hay que ir, menos clemencia: se invierte.
			return -site.still_speed
		_:
			return site.shelter_reach * float(maxi(site.shelters.size(), 1))


## Que quede algún sitio donde el peligro no muerda.
func _has_escape(site: RPGArenaHazard) -> bool:
	match site.style:
		"raices":
			return site.floor_radius > 3.0
		"observatorio":
			# Correr es 6,4 m/s en este juego: el umbral no puede pasar de ahí.
			return site.still_speed < 6.0
		_:
			return not site.shelters.is_empty() and site.shelter_reach > 1.8


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
