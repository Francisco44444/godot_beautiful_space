extends SceneTree

## Cinco finales sólo son cinco si a los cinco se puede llegar. Un final tapado
## por otro —porque su condición es más estricta y va después— no existe, y
## jugando no hay forma de descubrirlo: siempre sale el mismo.
##
## `ending_for` es función pura a propósito: aquí se recorren miles de partidas
## posibles sin instanciar el mundo.


const MAX_REGARD := 18
const MIN_REGARD := -18
const TOTAL_QUESTS := 18
const TOTAL_ALLIES := 4


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	if RPGCampaign.ENDINGS.size() != 5:
		_fail("Se esperaban 5 finales y hay %d." % RPGCampaign.ENDINGS.size())
		return

	# Barrido de todas las partidas plausibles: qué finales salen y cuántas
	# veces. Cero para alguno significa que está tapado.
	var tally: Dictionary = {}
	for ending in RPGCampaign.ENDINGS:
		tally[String(ending["id"])] = 0
	var runs := 0
	for regard in range(MIN_REGARD, MAX_REGARD + 1, 2):
		for quests in TOTAL_QUESTS + 1:
			for allies in TOTAL_ALLIES + 1:
				for witnessed in [0, 2, 3, 5]:
					var got: Dictionary = RPGCampaign.ending_for(
						regard, quests, allies, int(witnessed))
					if got.is_empty() or not tally.has(String(got["id"])):
						_fail("ending_for devolvió algo que no está en ENDINGS.")
						return
					tally[String(got["id"])] += 1
					runs += 1
	for id in tally:
		if int(tally[id]) == 0:
			_fail("El final '%s' no lo alcanza ninguna partida: está tapado." % id)
			return

	# Los dos extremos tienen que ser los que uno espera, o el final no premia
	# ni castiga nada.
	var best: Dictionary = RPGCampaign.ending_for(14, 18, 4, 5)
	if String(best["id"]) != "los_cinco_y_uno":
		_fail("Ayudar a todo el mundo con cuatro aliados da '%s'." % String(best["id"]))
		return
	# Los hechos mandan sobre el trato: quien resolvió los dieciocho encargos no
	# puede acabar con el nombre raspado por contestar seco.
	var harsh_helper: Dictionary = RPGCampaign.ending_for(-12, 18, 4, 5)
	if String(harsh_helper["id"]) != "la_sexta_campana":
		_fail("Ayudar a todos con mal trato da '%s'." % String(harsh_helper["id"]))
		return
	var worst: Dictionary = RPGCampaign.ending_for(-12, 1, 0, 0)
	if String(worst["id"]) != "el_nombre_raspado":
		_fail("Ni ayudar ni tratar bien da '%s'." % String(worst["id"]))
		return
	var rushed: Dictionary = RPGCampaign.ending_for(0, 0, 0, 0)
	if String(rushed["id"]) != "el_que_paso_de_largo":
		_fail("Ir derecho a los jefes da '%s'." % String(rushed["id"]))
		return

	# Cada final tiene que tener texto de verdad, no un hueco.
	for ending in RPGCampaign.ENDINGS:
		if String(ending["title"]).is_empty() or (ending["cards"] as Array).size() < 2:
			_fail("El final '%s' no tiene escena." % String(ending["id"]))
			return
		for card in ending["cards"]:
			if String(card).strip_edges().length() < 30:
				_fail("Una tarjeta de '%s' está casi vacía." % String(ending["id"]))
				return

	var summary := PackedStringArray()
	for id in tally:
		summary.append("%s %d" % [id, int(tally[id])])
	print("OK · 5 finales, %d partidas recorridas · %s" % [runs, ", ".join(summary)])
	quit(0)


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
