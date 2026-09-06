extends SceneTree

## Un encargo tiene que obligar a viajar, y tiene que poder cumplirse. Las dos
## cosas se rompen en direcciones opuestas: sin comarca, los dieciocho se
## resolvían sin salir del primer kilómetro; con una comarca mal puesta, el
## encargo es imposible y no hay forma de saberlo jugando.


## La negociación altiva sube en 2 lo que piden, así que la comarca tiene que
## reunir eso de más o el encargo se vuelve imposible al regatear.
const HAGGLE_MARGIN := 2
## Ninguna cacería con comarca puede resolverse sin salir de Puerto Alba.
const START := Vector2(0.0, 190.0)
const MIN_TRAVEL := 240.0
const EXPECTED_ZONED := 8


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
	var quests: Node = runtime.get("sidequests")
	if quests == null:
		_fail("Faltan los encargos.")
		return

	var alive: Dictionary = {}
	for node in root.get_tree().get_nodes_in_group("rpg_enemy"):
		var enemy := node as Node3D
		if enemy == null or bool(enemy.get("dead")):
			continue
		var id := String(enemy.get("enemy_id"))
		var species := id.substr(0, id.rfind("_"))
		if not alive.has(species):
			alive[species] = []
		(alive[species] as Array).append(Vector2(enemy.global_position.x, enemy.global_position.z))

	var zoned := 0
	var farthest := 0.0
	for quest in RPGSideQuests.QUESTS:
		if int(quest["kind"]) != RPGSideQuests.Kind.HUNT:
			continue
		var id := String(quest["id"])
		var radius: float = quests.call("zone_of", quest)
		if radius <= 0.0:
			# Sin comarca sólo los de castillo, que piden los tres castillos.
			if not id in ["guardias_caidos", "capitanes_de_hueso"]:
				_fail("%s no exige viaje: cuenta en cualquier parte de la isla." % id)
				return
			continue
		zoned += 1
		var centre: Vector2 = quests.call("zone_centre", quest)
		var spots: Array = alive.get(String(quest["target"]), [])
		var inside := 0
		for spot in spots:
			if centre.distance_to(spot) <= radius:
				inside += 1
		var needed := int(quest["needed"])
		if inside < needed + HAGGLE_MARGIN:
			_fail("%s pide %d (+%d al regatear) y en su comarca sólo hay %d de %s." % [
				id, needed, HAGGLE_MARGIN, inside, String(quest["target"])])
			return
		var travel := START.distance_to(centre)
		farthest = maxf(farthest, travel)
		if travel < MIN_TRAVEL:
			_fail("%s se resuelve a %.0f m de Puerto Alba: eso no es un viaje." % [id, travel])
			return

	if zoned != EXPECTED_ZONED:
		_fail("Se esperaban %d cacerías con comarca y hay %d." % [EXPECTED_ZONED, zoned])
		return

	# Matar la especie buena en el sitio malo NO puede contar.
	var probe: Dictionary = {}
	for quest in RPGSideQuests.QUESTS:
		if float(quest.get("zone", 0.0)) > 0.0:
			probe = quest
			break
	quests.call("take", probe)
	var before: int = quests.call("progress_of", probe)
	var centre: Vector2 = quests.call("zone_centre", probe)
	var radius: float = quests.call("zone_of", probe)
	quests.call("on_enemy_defeated", "%s_999" % String(probe["target"]),
		centre + Vector2(radius + 260.0, 0.0))
	if int(quests.call("progress_of", probe)) != before:
		_fail("%s contó una presa cazada fuera de su comarca." % String(probe["id"]))
		return
	quests.call("on_enemy_defeated", "%s_998" % String(probe["target"]), centre)
	if int(quests.call("progress_of", probe)) != before + 1:
		_fail("%s no contó una presa cazada dentro de su comarca." % String(probe["id"]))
		return

	print("OK · %d cacerías con comarca, la más lejana a %.0f m de Puerto Alba, y fuera no cuenta" % [
		zoned, farthest])
	quit(0)


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
