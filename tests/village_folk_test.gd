extends SceneTree

## Comprueba la villa grande: que sus casas no se pisen entre ellas y que sus
## vecinos caminen de verdad.
##
## Los dos fallos que caza son los que aparecieron al montarlos:
##   - Terrain3D sólo genera colisión de suelo en un radio alrededor del jugador,
##     y Villa Robledal está a 1.600 m del punto de partida. Los primeros
##     vecinos, que se movían por física, no caminaban: se caían al vacío. La
##     cifra medida fue de 1.164 m en diez segundos, que es exactamente caída
##     libre a 22 m/s². Aquí se exige que sigan pegados al terreno.
##   - Y un porteador que tirase en línea recta hacia una puerta del otro lado de
##     la villa atravesaba las casas de en medio. Aquí se exige que ningún vecino
##     acabe dentro de un edificio.
##
## Y el trazado: colocar veintisiete casas automáticamente reprodujo a escala de
## villa el defecto del taller. La segunda hilera choca con el eje transversal en
## las diagonales, y sin filtrar las parcelas salían SEIS parejas de casas metidas
## una en otra, la peor con 17,69 m de mordisco. Aquí se exige cero.

const SIMULATED_FRAMES := 900
const MIN_FOLK := 12
## Cuánto puede separarse un vecino de la cota del terreno bajo sus pies.
const MAX_GROUND_ERROR := 0.6
## Cuánto tiene que haber recorrido de media para considerar que camina.
const MIN_AVERAGE_WALK := 6.0
## La villa grande sustituye a la de cinco casas: tiene que ser claramente mayor.
const MIN_VILLAGE_HOUSES := 22
## Villa Robledal y el alcance de su casco, para no confundirla con el caserío
## "Granjas de Robledal", que está a dos kilómetros y comparte nombre.
const GRAND_VILLAGE_CENTRE := Vector2(-1450.0, 650.0)
const GRAND_VILLAGE_REACH := VillageLayout.RADIUS + 60.0
## Dos casas vecinas pueden rozarse el alero, no morderse el cuerpo.
const MAX_HOUSE_BITE := 0.02


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for singleton_name in ["InventoryManager", "ExplorationManager"]:
		root.get_node(singleton_name).set("autosave_enabled", false)
	var saves := root.get_node("SaveGameManager")
	saves.set_process(false)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	saves.call("bind_world", null)
	for _frame in 8:
		await process_frame

	var terrain := world.get_node("Terrain3D") as Terrain3D
	var folk := world.find_child("*Vecinos", true, false)
	if folk == null:
		_fail("La villa grande no tiene vecinos.")
		return
	var count := int(folk.get_meta("folk_count", 0))
	if count < MIN_FOLK:
		_fail("Sólo hay %d vecinos y hacen falta al menos %d." % [count, MIN_FOLK])
		return
	if int(folk.get_meta("graph_node_count", 0)) <= 0:
		_fail("Los vecinos no tienen grafo de calles por el que andar.")
		return

	var overlaps := _village_overlaps(world)
	if overlaps["pairs"] > 0:
		_fail(
			"En la villa grande hay %d parejas de casas que se pisan; la peor se muerde %.2f m (%s)."
			% [overlaps["pairs"], overlaps["worst"], overlaps["who"]]
		)
		return
	if int(overlaps["houses"]) < MIN_VILLAGE_HOUSES:
		_fail("La villa grande sólo tiene %d casas y debería tener al menos %d." % [
			overlaps["houses"], MIN_VILLAGE_HOUSES])
		return

	var walkers: Array[Node3D] = []
	var origins: Array[Vector3] = []
	for child in folk.get_children():
		if child is VillageNeighbour:
			walkers.append(child as Node3D)
			origins.append((child as Node3D).global_position)
	if walkers.size() != count:
		_fail("Se declaran %d vecinos y hay %d nodos." % [count, walkers.size()])
		return
	var professions := {}
	var outfits := {}
	var riders := 0
	for node in walkers:
		var neighbour := node as VillageNeighbour
		if not neighbour is CharacterBody3D or neighbour.collision_mask & 1 == 0:
			_fail("Un vecino no usa colisión física contra las paredes.")
			return
		if neighbour.visual == null or int(neighbour.visual.get_meta("human_skin_surface_count", 0)) == 0:
			_fail("%s conserva la piel negra del paquete original." % neighbour.name)
			return
		var outfit := String(neighbour.visual.get_meta("character_file", ""))
		outfits[outfit] = true
		if not (outfit.begins_with("Viking_") or outfit.begins_with("Knight_") or outfit.begins_with("Pirate_") or outfit in ["Wizard.gltf", "Witch.gltf", "Elf.gltf"]):
			_fail("Traje ajeno a la villa medieval: %s." % outfit)
			return
		if neighbour.work_station != null:
			professions[neighbour.trade] = true
		if neighbour.has_meta("mounted_patrol"):
			riders += 1
			if neighbour.horse_animator == null or neighbour.animator.assigned_animation != "SitDown":
				_fail("El guardia a caballo no conserva la postura de jinete.")
				return
	if outfits.size() < 8:
		_fail("La villa debe combinar al menos ocho modelos medievales, no repetir dos cuerpos.")
		return
	if professions.size() < 4 or riders < 1:
		_fail("Faltan los cuatro oficios visibles o el guardia montado.")
		return

	for _frame in SIMULATED_FRAMES:
		await physics_frame
		if _frame % 30 == 0 and _folk_inside_buildings(world, walkers) > 0:
			_fail("Un vecino atraviesa un muro durante su recorrido.")
			return

	var travelled := 0.0
	for index in walkers.size():
		var walker := walkers[index]
		var here := walker.global_position
		travelled += origins[index].distance_to(here)
		# Pegados al suelo: si se estuvieran cayendo, esto se dispararía a cientos
		# de metros en cuestión de segundos.
		var ground: float = terrain.data.get_height(Vector3(here.x, 0.0, here.z))
		if is_nan(ground):
			continue
		if absf(here.y - ground) > MAX_GROUND_ERROR:
			_fail(
				"%s está a %.2f m de la cota del terreno (%.2f frente a %.2f): se cae o flota."
				% [walker.name, absf(here.y - ground), here.y, ground]
			)
			return

	var average := travelled / float(walkers.size())
	if average < MIN_AVERAGE_WALK:
		_fail("Los vecinos apenas se mueven: %.1f m de media." % average)
		return
	# Y que no sea una carrera desbocada: a paso de persona, en quince segundos
	# de simulación no se cruza la villa entera dos veces.
	if average > 120.0:
		_fail("Los vecinos recorren %.1f m de media: van demasiado rápido." % average)
		return

	var inside := _folk_inside_buildings(world, walkers)
	if inside > 0:
		_fail("%d vecinos han acabado dentro de un edificio." % inside)
		return

	# Y que se les pueda hablar, con el mismo contrato que el resto del juego:
	# estar en el grupo "adventure_interactable" y responder a interact().
	var greeted := await _greet_one(world, walkers)
	if not greeted.is_empty():
		_fail(greeted)
		return

	print("%d casas sin pisarse, %d vecinos medievales caminando %.1f m de media, cero cruces de muro, 4 oficios y un jinete; piel y saludo correctos." % [
		overlaps["houses"], walkers.size(), average])
	quit()


func _greet_one(world: Node, walkers: Array[Node3D]) -> String:
	## Devuelve el motivo del fallo, o vacío si el saludo funciona.
	var neighbour := walkers[0] as VillageNeighbour
	if neighbour == null:
		return "El primer vecino no es un VillageNeighbour."
	if not neighbour.is_in_group("adventure_interactable"):
		return "%s no está en el grupo de cosas con las que se puede interactuar." % neighbour.name
	var prompt := neighbour.get_interaction_prompt()
	if prompt.is_empty() or neighbour.display_name not in prompt:
		return "El aviso de %s no nombra al vecino: '%s'." % [neighbour.name, prompt]

	var player := world.get_node_or_null("Player")
	if player == null:
		return "No hay héroe con quien saludar."
	var heard: Array[String] = []
	player.connect(
		"action_feedback",
		func(message: String) -> void: heard.append(message)
	)
	var before := neighbour.global_position
	if not neighbour.interact(player):
		return "%s no responde al saludo." % neighbour.name
	if heard.is_empty():
		return "Saludar a %s no dice nada por pantalla." % neighbour.name
	# Y se queda quieto mientras habla, en vez de irse a media frase.
	for _frame in 60:
		await physics_frame
	if before.distance_to(neighbour.global_position) > 0.5:
		return "%s se marcha mientras habla." % neighbour.name
	return ""


func _village_overlaps(world: Node) -> Dictionary:
	## Mide la caja real de cada casa a partir de sus propias colisiones y cruza
	## todas las parejas. Es la misma medición con la que se diagnosticaron las
	## casas del taller, aplicada ahora al reparto de parcelas.
	var medieval := world.get_node("MedievalSetDressing")
	var boxes: Array = []
	for child in medieval.get_children():
		if not child is StaticBody3D:
			continue
		if "House" not in child.name and "Hall" not in child.name:
			continue
		# Por nombre no basta: "Granjas de Robledal" es un caserío a dos
		# kilómetros y contiene la misma palabra. Se filtra por cercanía al
		# centro de la villa, que es lo que de verdad se quiere medir.
		if Vector2(child.global_position.x, child.global_position.z).distance_to(
			GRAND_VILLAGE_CENTRE) > GRAND_VILLAGE_REACH:
			continue
		var low := Vector3(INF, INF, INF)
		var high := -low
		for part in child.get_children():
			if not (part is CollisionShape3D):
				continue
			var collision := part as CollisionShape3D
			if not (collision.shape is BoxShape3D):
				continue
			var size: Vector3 = (collision.shape as BoxShape3D).size
			for sx in [-0.5, 0.5]:
				for sy in [-0.5, 0.5]:
					for sz in [-0.5, 0.5]:
						var corner: Vector3 = collision.global_transform * Vector3(
							size.x * sx, size.y * sy, size.z * sz)
						low = low.min(corner)
						high = high.max(corner)
		if low.x == INF:
			continue
		boxes.append([child.name, AABB(low, high - low)])
	var pairs := 0
	var worst := 0.0
	var who := ""
	for a in boxes.size():
		for b in range(a + 1, boxes.size()):
			var first: AABB = boxes[a][1]
			var second: AABB = boxes[b][1]
			var overlap := Vector3(
				minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x),
				minf(first.end.y, second.end.y) - maxf(first.position.y, second.position.y),
				minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z)
			)
			if overlap.x <= 0.0 or overlap.y <= 0.0 or overlap.z <= 0.0:
				continue
			var bite := minf(overlap.x, overlap.z)
			if bite <= MAX_HOUSE_BITE:
				continue
			pairs += 1
			if bite > worst:
				worst = bite
				who = "%s x %s" % [boxes[a][0], boxes[b][0]]
	return {"houses": boxes.size(), "pairs": pairs, "worst": worst, "who": who}


func _folk_inside_buildings(world: Node, walkers: Array[Node3D]) -> int:
	## Un vecino dentro de una casa se detecta consultando la física en su propia
	## posición: si el punto cae dentro de la caja de un muro, está atravesándolo.
	var space := (world as Node3D).get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.collide_with_bodies = true
	query.collision_mask = 1
	# Los propios vecinos van en la capa 5, que en binario es 101 e incluye la
	# capa 1: sin excluirlos, la consulta se choca con ellos mismos y los 18 dan
	# positivo. Es la clase de aserto que parece funcionar y no prueba nada.
	var exclude: Array[RID] = []
	for walker in walkers:
		if walker is CollisionObject3D:
			exclude.append((walker as CollisionObject3D).get_rid())
	query.exclude = exclude
	var inside := 0
	for walker in walkers:
		query.position = walker.global_position + Vector3.UP * 1.0
		var hits := space.intersect_point(query, 4)
		if hits.is_empty():
			continue
		inside += 1
		var names: Array[String] = []
		for hit in hits:
			var collider = hit.get("collider")
			names.append(String(collider.name) if collider != null else "?")
		printerr("%s está dentro de %s, en %s." % [walker.name, names, walker.global_position])
	return inside


func _fail(message: String) -> void:
	push_error(message)
	printerr(message)
	quit(1)
