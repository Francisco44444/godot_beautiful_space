extends SceneTree

## El diario contaba las 200 zonas y nada más. No había un solo sitio donde leer
## la historia que llevas: qué actos cerraste, a quién te ganaste, qué piensa de
## ti la gente. La crónica es esa página — y va SEPARADA de los 200 retos,
## porque mezclar las dos cuentas en una lista ya fue un error una vez.


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
	var hud := world.get_node_or_null("HUD")
	if runtime == null or hud == null:
		_fail("Falta el runtime o el HUD.")
		return

	# Partida recién empezada: la crónica dice lo que falta, no se queda muda.
	var fresh := String(runtime.call("chronicle"))
	for heading in ["HISTORIA", "ENCARGOS", "QUIENES TE ACOMPAÑAN", "LA ISLA Y TÚ"]:
		if not fresh.contains(heading):
			_fail("La crónica no tiene el bloque '%s'." % heading)
			return
	if not fresh.contains("Nombres recuperados: 0 de 5"):
		_fail("La crónica no lleva la cuenta de nombres.")
		return
	if not fresh.contains("Nadie, todavía"):
		_fail("Sin aliados la crónica debería decirlo, no callar.")
		return

	# Lo que haces aparece.
	runtime.get("_regard")["tavia"] = 2
	runtime.get("_regard")["orin"] = -3
	var quest: Dictionary = RPGSideQuests.QUESTS[0]
	runtime.get("sidequests").get("_state")[String(quest["id"])]["done"] = true
	var after := String(runtime.call("chronicle"))
	if not after.contains("Te aprecian:") or not after.contains("Te tienen por altivo:"):
		_fail("La crónica no refleja cómo te trata la gente.")
		return
	if not after.contains(String(quest["title"])):
		_fail("Un encargo cumplido no aparece en la crónica.")
		return
	if after.contains("1 de %d" % RPGSideQuests.QUESTS.size()) == false:
		_fail("La cuenta de encargos no se actualiza.")
		return

	# Las dos páginas del diario no se pisan.
	hud.call("_set_exploration_journal_open", true)
	hud.set("journal_page", 0)
	hud.call("_apply_journal_page")
	var chronicle_view: RichTextLabel = hud.get("chronicle_view")
	var zone_list: ItemList = hud.get("exploration_journal_list")
	if not chronicle_view.visible or zone_list.visible:
		_fail("En la página de crónica siguen viéndose los 200 retos.")
		return
	if not chronicle_view.text.contains("HISTORIA"):
		_fail("La página de crónica está vacía.")
		return
	if not String((hud.get("journal_title") as Label).text).contains("CRÓNICA"):
		_fail("El título no dice en qué página estás.")
		return
	hud.call("_flip_journal_page")
	if chronicle_view.visible or not zone_list.visible:
		_fail("Volver a los retos no apaga la crónica.")
		return
	if String((hud.get("journal_title") as Label).text).contains("CRÓNICA"):
		_fail("El título se quedó en la página anterior.")
		return

	print("OK · crónica con historia, encargos, aliados y trato; dos páginas que no se pisan")
	quit(0)


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
