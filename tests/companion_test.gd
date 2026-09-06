extends SceneTree

## Los aliados no son escolta: se ganan hablando, sólo acuden si hay pelea y
## llegan cruzando el horizonte. Cada una de esas tres reglas se rompe sola en
## cuanto alguien "simplifica" el sistema, así que van fijadas aquí.


## El caballo aparece a 58 m. Menos que esto y el aliado se materializa encima
## del héroe, que es justo lo que no queremos.
const MIN_HORIZON := 40.0
const EXPECTED_RECRUITABLE := 4


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

	var runtime := world.get_node_or_null("RPGStoryRuntime") as Node
	if runtime == null:
		_fail("Falta RPGStoryRuntime.")
		return
	var player := root.get_tree().get_first_node_in_group("local_player") as Node3D
	if player == null:
		_fail("No hay héroe al que acudir.")
		return

	if runtime.get("COMPANIONS").size() != EXPECTED_RECRUITABLE:
		_fail("Se esperaban %d aliados reclutables." % EXPECTED_RECRUITABLE)
		return

	# Nadie se une por llegar: hace falta aprecio y no dejarle encargos a medias.
	for mate_id in runtime.get("COMPANIONS").keys():
		if runtime.call("can_recruit", String(mate_id)):
			_fail("%s se une sin haberte ganado nada." % mate_id)
			return

	var empty := String(runtime.call("call_companions"))
	if empty == "" or not empty.contains("Nadie"):
		_fail("Llamar sin aliados debe explicarse, no callar: '%s'" % empty)
		return

	# Ganárselo de verdad: aprecio alto y ningún encargo suyo abierto.
	var sidequests: Node = runtime.get("sidequests")
	for quest in sidequests.call("quests_of", "orin"):
		sidequests.get("_state")[String(quest["id"])]["done"] = true
	runtime.get("_regard")["orin"] = 3
	if not bool(runtime.call("can_recruit", "orin")):
		_fail("Con aprecio y encargos cerrados debería poder unirse.")
		return
	# El camino real: hablas con él y te lo ofrece. Si esto se rompe, reclutar
	# sólo funciona desde código y el jugador no encuentra la puerta.
	var offered: Array = []
	runtime.connect("dialogue_with_choices",
		func(_who, _role, _title, _body, choices): offered.assign(choices))
	var him: Node = null
	for node in root.get_tree().get_nodes_in_group("rpg_npc"):
		if String(node.get("npc_id")) == "orin":
			him = node
			break
	if him == null:
		_fail("No se encontró a Orin en el mundo.")
		return
	runtime.call("begin_npc_dialogue", him, player)
	if offered.size() != 2 or not String(offered[0].get("tone", "")).contains("acepta"):
		_fail("Hablar con él no ofrece que se una: %s" % str(offered))
		return
	runtime.call("answer_dialogue", offered[0])
	if not paused:
		_fail("El panel de diálogo debería haber pausado el mundo.")
		return
	# En juego lo despausa el HUD al elegir opción; aquí lo hago a mano porque
	# lo que se prueba es al aliado, no el panel.
	paused = false
	var roster: Array = runtime.call("companion_roster")
	if roster.size() != 1:
		_fail("El reclutamiento no creó al aliado.")
		return
	var mate: RPGCompanion = roster[0] as RPGCompanion
	if mate.visible or mate.duty != RPGCompanion.Duty.AWAY:
		_fail("Un aliado recién ganado debe estar en lo suyo, no pegado a ti.")
		return

	# Sin pelea no viene: es lo que impide que sea una escolta permanente.
	runtime.call("call_companions")
	if mate.duty != RPGCompanion.Duty.AWAY:
		_fail("Acudió sin que hubiera pelea.")
		return

	var foe: Node3D = null
	for node in root.get_tree().get_nodes_in_group("rpg_enemy"):
		if not bool(node.get("dead")):
			foe = node as Node3D
			break
	if foe == null:
		_fail("No hay enemigos con los que probar la llamada.")
		return
	foe.global_position = player.global_position + Vector3(9.0, 0.0, 4.0)
	if not bool(runtime.call("fight_underway")):
		_fail("Un enemigo a 10 m debería contar como pelea.")
		return

	var notice := String(runtime.call("call_companions"))
	if not notice.contains("horizonte"):
		_fail("La llamada con pelea debe anunciar la llegada: '%s'" % notice)
		return
	if mate.duty != RPGCompanion.Duty.ARRIVING or not mate.visible:
		_fail("Tras la llamada el aliado debe venir de camino.")
		return
	var span := mate.global_position.distance_to(player.global_position)
	if span < MIN_HORIZON:
		_fail("Apareció a %.1f m: eso es un teletransporte, no una llegada." % span)
		return
	var terrain = runtime.get("_terrain")
	var ground: float = terrain.data.get_height(
		Vector3(mate.global_position.x, 0.0, mate.global_position.z))
	if is_nan(ground) or ground < 0.6:
		_fail("Apareció sobre el mar (suelo=%.1f)." % ground)
		return
	if absf(mate.global_position.y - ground) > 0.6:
		_fail("Apareció a %.1f m del suelo (%.1f vs %.1f): flota o está enterrado." % [
			absf(mate.global_position.y - ground), mate.global_position.y, ground])
		return

	# Llegar y marcharse: el plazo se agota y vuelve a lo suyo con espera.
	mate.global_position = player.global_position + Vector3(5.0, 0.0, 0.0)
	for _frame in 40:
		await process_frame
	if mate.duty != RPGCompanion.Duty.MUSTERED:
		_fail("No pasó a pelear al llegar junto al héroe.")
		return
	foe.set("dead", true)
	mate.set("_muster_left", 0.05)
	for _frame in 30:
		await process_frame
		if mate.duty == RPGCompanion.Duty.AWAY:
			break
	if mate.duty != RPGCompanion.Duty.AWAY or mate.visible:
		_fail("Terminada la pelea debería marcharse.")
		return
	var wait_left: float = mate.cooldown_left()
	if wait_left <= 0.0:
		_fail("Debe haber espera antes de poder volver a llamarlo.")
		return

	# La tira del HUD: sin ella no sabes si un aliado está vivo, tumbado o
	# cuánto falta para poder volver a llamarlo.
	var hud := world.get_node_or_null("HUD")
	var strip: PanelContainer = hud.get("ally_strip")
	if strip == null:
		_fail("El HUD no monta la tira de aliados.")
		return
	hud.call("refresh_ally_strip")
	if not strip.visible:
		_fail("Con un aliado ganado la tira sigue escondida.")
		return
	var rows: VBoxContainer = hud.get("ally_strip_rows")
	for _frame in 2:
		await process_frame
	if rows.get_child_count() != 1:
		_fail("La tira enseña %d aliados y hay 1." % rows.get_child_count())
		return
	if not String((rows.get_child(0) as Label).text).contains(mate.display_name.to_upper()):
		_fail("La tira no nombra al aliado: '%s'" % String((rows.get_child(0) as Label).text))
		return
	# Los tres estados tienen que leerse distintos.
	mate.duty = RPGCompanion.Duty.AWAY
	mate.set("_call_cooldown", 0.0)
	mate.downed = false
	var ready_line := String(mate.call("status_line"))
	mate.set("_call_cooldown", 22.0)
	var waiting := String(mate.call("status_line"))
	mate.downed = true
	mate.set("_recover", 31.0)
	var fallen := String(mate.call("status_line"))
	mate.downed = false
	mate.set("_call_cooldown", 0.0)
	if ready_line == waiting or waiting == fallen or ready_line == fallen:
		_fail("Listo, esperando y tumbado se leen igual: '%s' / '%s' / '%s'" % [
			ready_line, waiting, fallen])
		return
	if not waiting.contains("22") or not fallen.contains("31"):
		_fail("La tira no dice cuánto falta: '%s' / '%s'" % [waiting, fallen])
		return

	# Pelean contra los jefes despiertos, y con sus reglas: el arquero rompe la
	# coraza que sólo cede al arco. Traer al aliado adecuado es media mecánica.
	var boss: RPGBoss = null
	for node in root.get_tree().get_nodes_in_group("rpg_boss"):
		var candidate := node as RPGBoss
		if candidate != null and candidate.demand == RPGBoss.Demand.BOW:
			boss = candidate
			break
	if boss == null:
		_fail("No hay jefe con coraza de flechas.")
		return
	mate.duty = RPGCompanion.Duty.MUSTERED
	mate.global_position = boss.global_position + Vector3(4.0, 0.0, 0.0)
	if boss.sealed:
		if mate.call("_closest_foe") != null:
			_fail("El aliado ataca a un jefe todavía sellado.")
			return
		boss.set_sealed(false)
	if mate.call("_closest_foe") != boss:
		_fail("El aliado no toma por objetivo al jefe despierto que tiene al lado.")
		return
	var archer := roster[0] as RPGCompanion
	archer.craft = RPGCompanion.Craft.ARCHER
	archer.global_position = boss.global_position + Vector3(4.0, 0.0, 0.0)
	archer.set("_target", boss)
	var ward_before := int(boss.get("_ward"))
	for _shot in 12:
		archer.set("_cooldown", 0.0)
		archer.call("_strike")
		archer.set("_cooldown", 0.0)
		if int(boss.get("_ward")) < ward_before or boss.stance == RPGBoss.Stance.OPEN:
			break
	if int(boss.get("_ward")) >= ward_before and boss.stance != RPGBoss.Stance.OPEN:
		_fail("Las flechas del arquero no muerden la coraza (guardia %d)." % ward_before)
		return

	# Nadie reclama una gesta que no peleó. Y quien la peleó, la recuerda.
	var act: Dictionary = RPGCampaign.ACTS[0]
	mate.duty = RPGCompanion.Duty.AWAY
	if String(mate.call("witness", String(act["id"]), "El nombre de Mira")) != "":
		_fail("Un aliado que no estaba en la pelea reclama el acto.")
		return
	mate.duty = RPGCompanion.Duty.MUSTERED
	var seen := String(mate.call("witness", String(act["id"]), "El nombre de Mira"))
	if seen == "" or not seen.contains(mate.display_name):
		_fail("El aliado que peleó el acto no dice nada: '%s'" % seen)
		return
	if not mate.witnessed.has(String(act["id"])):
		_fail("No recuerda el acto que acaba de pelear.")
		return
	if mate.call("veteran_line") == "":
		_fail("Tras cerrar un acto contigo debería hablarte distinto.")
		return
	mate.duty = RPGCompanion.Duty.AWAY

	# Guardar y cargar no puede costarte un aliado ni su memoria, aunque los
	# encargos se restauren después que ellos.
	var saved: Dictionary = runtime.call("get_save_state")
	for quest in sidequests.call("quests_of", "orin"):
		sidequests.get("_state")[String(quest["id"])]["done"] = false
	for gone in runtime.call("companion_roster"):
		gone.queue_free()
	runtime.get("_companions").clear()
	await process_frame
	runtime.call("apply_save_state", saved)
	var back: Array = runtime.call("companion_roster")
	if back.size() != 1:
		_fail("Cargar la partida perdió al aliado ganado.")
		return
	if not (back[0] as RPGCompanion).witnessed.has(String(act["id"])):
		_fail("Cargar la partida le borró el acto que peleó contigo.")
		return

	print("OK · %d aliados reclutables, llegada a %.1f m, espera de %d s" % [
		EXPECTED_RECRUITABLE, span, int(wait_left)])
	quit(0)


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
