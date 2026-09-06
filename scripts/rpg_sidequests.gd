class_name RPGSideQuests
extends Node

## Encargos secundarios: lo que hay que hacer entre acto y acto.
##
## La aventura ya tenía 200 objetivos, pero todos eran de la misma clase —llegar
## a un sitio— y ninguno pedía nada al jugador salvo caminar. Aquí los encargos
## tienen tres formas distintas, y las tres se apoyan en sistemas que ya existen:
##
##   CACERÍA  matar N criaturas de una especie concreta. Se apoya en el bestiario
##            por biomas, así que aceptar una cacería es aceptar un viaje.
##   ACOPIO   traer N unidades de un material. Se apoya en los botines, que son
##            distintos en cada bioma, y paga en lo que pide la forja.
##   ENCARGO  conseguir una pieza concreta —una llave, una corona, un tomo— y
##            entregarla. Se apoya en el kit de objetos, que estaba entero en
##            disco sin que el juego lo usara.
##
## Cada encargo lo da un habitante y paga con algo que sirve: material de forja,
## flechas, o una pieza de tesoro que abre otro encargo.

signal quest_offered(quest: Dictionary)
signal quest_progressed(quest: Dictionary, current: int, needed: int)
signal quest_completed(quest: Dictionary)

## Lo que endurece al héroe cada encargo cumplido. Menos que cerrar un acto
## —eso son 25 y 18— porque un recado no es una gesta, pero los dieciocho juntos
## pesan tanto como la campaña entera: quien se moleste en ayudar a la gente
## llega al final notablemente más fuerte que quien va derecho a los jefes.
const QUEST_HEALTH_BONUS := 5
const QUEST_STAMINA_BONUS := 4

enum Kind { HUNT, GATHER, ERRAND }

## Una cacería sólo cuenta en su comarca. El comentario de arriba prometía que
## «aceptar una cacería es aceptar un viaje» y no era verdad: valía matar la
## especie donde te la cruzaras, así que los dieciocho encargos se resolvían sin
## salir del primer kilómetro. Los centros y los radios salen de medir el mundo
## de verdad —el círculo más apretado que reúne los ejemplares que se piden— con
## margen para lo que sube la negociación altiva. Los dos de castillo van sin
## comarca a propósito: su texto dice «los tres castillos».
const NO_ZONE := 0.0

const QUESTS: Array[Dictionary] = [
	{
		"id": "limos_del_sendero", "at": Vector2(-247.0, 40.0), "zone": 300.0, "where": "En los caminos que salen de Puerto Alba.", "kind": Kind.HUNT, "giver": "maela",
		"title": "Limos en el sendero", "target": "limo_sendero", "needed": 4,
		"brief": "Maela ha dejado de dibujar. «Llevo el camino de Puerto Alba medido en pasos desde los catorce años. Ahora los carros lo rodean por el trigal y me han estropeado el mapa.» Golpea el pergamino con el dedo. «Quítame los limos y te lo dibujo otra vez bien.»",
		"reward": {"Crystal4": 2, "Arrow": 10},
	},
	{
		"id": "acero_para_orin", "where": "El cristal verde lo sueltan los limos y setales del valle.", "kind": Kind.GATHER, "giver": "orin",
		"title": "Acero para Orin", "target": "Crystal4", "needed": 3,
		"brief": "Orin tiene el yunque frío. «Se me ha ido la mano templando. La última hoja salió blanda y el chico que la compró volvió andando, que ya es suerte.» Escupe a la fragua. «Tráeme cristal verde y te hago una que no vuelva sola.»",
		"reward": {"Gold_Ingots": 1, "Potion5_Filled": 1},
	},
	{
		"id": "raices_enfermas", "at": Vector2(-1900.0, 717.0), "zone": 340.0, "where": "En los robledales al oeste de Villa Robledal.", "kind": Kind.HUNT, "giver": "tavia",
		"title": "Raíces enfermas", "target": "setal_crecido", "needed": 5,
		"brief": "Tavia lleva a un roble joven de la mano, como a un niño. «Este tiene cuatro años. Debería tener el tronco de mi muslo y lo tiene de mi brazo.» Aparta un setal del pie del árbol con la bota. «Se lo están bebiendo por debajo.»",
		"reward": {"Crystal4": 3},
	},
	{
		"id": "espinas_del_camino", "at": Vector2(-836.0, 900.0), "zone": 540.0, "where": "En el camino blanco, entre Robledal y el molino.", "kind": Kind.HUNT, "giver": "tavia",
		"title": "Espinas del camino blanco", "target": "espina_verde", "needed": 6,
		"brief": "«Al molino se iba de noche», dice Tavia. «Con una antorcha y cantando, para avisar de que ibas tú y no otra cosa.» Se encoge de hombros. «Ahora nadie canta y nadie va.»",
		"reward": {"Crystal2": 2, "Arrow": 14},
	},
	{
		"id": "la_corona_perdida", "where": "En un cofre del bosque occidental.", "kind": Kind.ERRAND, "giver": "tavia",
		"title": "La corona de la primera alcaldesa", "target": "Crown", "needed": 1,
		"brief": "«Robledal tuvo alcaldesa antes de tener casas», dice Tavia. «La enterraron con la corona puesta y alguien la desenterró para venderla, y no llegó a venderla porque el bosque se lo comió antes.» Sonríe de medio lado. «Hay quien dice que se lo tenía merecido.»",
		"reward": {"Crystal3": 2, "Gold_Ingots": 1},
	},
	{
		"id": "orcos_en_la_bruma", "at": Vector2(-2300.0, -1462.0), "zone": 320.0, "where": "Bajan de la sierra hacia la Aldea de la Bruma.", "kind": Kind.HUNT, "giver": "brenn",
		"title": "Orcos en la bruma", "target": "orco_merodeador", "needed": 6,
		"brief": "«Bajan cuando cierra la niebla», dice Brenn. «No roban comida. Roban cosas con letras: lápidas, marcas de ganado, el cartel de la posada.» Se queda callado. «No sé para qué las quieren y prefiero no saberlo.»",
		"reward": {"Crystal2": 3},
	},
	{
		"id": "voces_del_bosque", "at": Vector2(3151.0, -1196.0), "zone": 840.0, "where": "En el Bosque Tenebroso, al este de la isla.", "kind": Kind.HUNT, "giver": "brenn",
		"title": "Las voces del bosque", "target": "espectro_eco", "needed": 4,
		"brief": "Brenn habla mirando al este. «Repiten. Cogen una frase que dijo alguien que ya no está y la dicen otra vez, igual, toda la noche.» Se pasa la mano por la boca. «Una de ellas usa la voz de mi padre y a mí ya no me queda mucha cabeza para eso.»",
		"reward": {"Crystal1": 2, "Arrow": 20},
	},
	{
		"id": "llave_de_la_bruma", "where": "La guardan las grutas selladas de la sierra.", "kind": Kind.ERRAND, "giver": "brenn",
		"title": "La llave que no era suya", "target": "Key2", "needed": 1,
		"brief": "«Las grutas se sellaron por algo y las llaves las guardaba la aldea», dice Brenn. «Una salió andando en el bolsillo de un buhonero.» Aprieta la mandíbula. «Le dijimos que no. Se la llevó igual.»",
		"reward": {"Crystal1": 2, "Gold_Ingots": 1},
	},
	{
		"id": "escarcha_para_ysra", "where": "El cristal de hielo lo sueltan los yetis de las Cumbres Blancas.", "kind": Kind.GATHER, "giver": "ysra",
		"title": "Lentes para el observatorio", "target": "Crystal3", "needed": 4,
		"brief": "Ysra te enseña un cuaderno lleno de la misma cifra repetida. «El error es de once segundos de arco y no viene de mi cuenta: viene de la lente, que se ha empañado por dentro.» Cierra el cuaderno. «Se pule con cristal de hielo. No hay otra cosa que valga.»",
		"reward": {"Gold_Ingots": 2, "Potion2_Filled": 1},
	},
	{
		"id": "yetis_de_la_cumbre", "at": Vector2(-1331.0, -2700.0), "zone": 300.0, "where": "En las Cumbres Blancas, al noroeste.", "kind": Kind.HUNT, "giver": "ysra",
		"title": "Los que bajaron de la cumbre", "target": "yeti_sin_nombre", "needed": 3,
		"brief": "«Han bajado ochocientos metros de cota en dos inviernos», dice Ysra. «Eso es un dato, no un rumor: lo he medido.» Deja el lápiz. «Los que miden cosas sabemos cuándo una cifra significa que algo va mal.»",
		"reward": {"Crystal3": 3, "Gold_Ingots": 1},
	},
	{
		"id": "tomo_boreal", "where": "En un cofre del Castillo Boreal.", "kind": Kind.ERRAND, "giver": "ysra",
		"title": "El volumen que falta", "target": "Book3_Closed", "needed": 1,
		"brief": "«El observatorio tenía nueve tomos y tiene ocho», dice Ysra. «Falta el séptimo, que es justo el que explica qué se hace cuando el cielo se detiene.» Casi se ríe. «A quien lo robó le sobraba sentido del humor.»",
		"reward": {"Crystal1": 3},
	},
	{
		"id": "cactoros_del_oasis", "at": Vector2(1598.0, 1180.0), "zone": 300.0, "where": "En las dunas alrededor del Oasis Dorado.", "kind": Kind.HUNT, "giver": "nara",
		"title": "Cactoros en el agua", "target": "cactoro", "needed": 5,
		"brief": "Nara señala la orilla del oasis. «Nadie bebe de pie desde el verano. Se bebe tumbado, y se sale despacio.» Se toca una cicatriz del antebrazo. «Las espinas llegan a treinta pasos. Yo lo sé de sobra.»",
		"reward": {"Crystal5": 3},
	},
	{
		"id": "sol_para_el_arco", "where": "El cristal del desierto lo sueltan los cactoros del oasis.", "kind": Kind.GATHER, "giver": "nara",
		"title": "Cristal para el mediodía", "target": "Crystal5", "needed": 4,
		"brief": "«El cristal del desierto sólo se corta a mediodía, cuando la piedra está tan caliente que no la aguantas», dice Nara. «Por eso vale lo que vale.» Te tiende un paño. «Envuélvete la mano.»",
		"reward": {"Gold_Ingots": 2, "Arrow": 24},
	},
	{
		"id": "guardias_caidos", "at": Vector2.ZERO, "zone": 0.0, "where": "Patrullan las murallas de los tres castillos.", "kind": Kind.HUNT, "giver": "calen",
		"title": "Los que siguen de guardia", "target": "guardia_caido", "needed": 6,
		"brief": "Calen no se sienta. «Siguen la ronda. La misma ronda, a la misma hora, y se relevan entre ellos.» Traga saliva. «Reconocí a dos por la forma de andar. Ya no tienen cara con la que reconocerlos de otra manera.»",
		"reward": {"Crystal2": 4, "Gold_Ingots": 1},
	},
	{
		"id": "capitanes_de_hueso", "at": Vector2.ZERO, "zone": 0.0, "where": "Uno en cada castillo, entre la guarnición.", "kind": Kind.HUNT, "giver": "calen",
		"title": "Órdenes que nadie dio", "target": "capitan_hueso", "needed": 4,
		"brief": "«Hay alguien mandando en los tres castillos», dice Calen. «Y las órdenes son buenas: cambian los turnos, cierran los portones, mandan patrullas donde hacen falta.» Aprieta el yelmo que tiene en las manos. «Eso es lo que me quita el sueño. Que sean buenas.»",
		"reward": {"Crystal1": 3, "Gold_Ingots": 2},
	},
	{
		"id": "el_calice_del_bastion", "where": "En un cofre del Bastión del Este.", "kind": Kind.ERRAND, "giver": "calen",
		"title": "El cáliz del juramento", "target": "Chalice", "needed": 1,
		"brief": "«Sobre ese cáliz se jura fidelidad en el Bastión», dice Calen. «Desapareció la misma noche que callaron las campanas.» Aparta la vista. «No creo en las casualidades y llevo dos años sin poder jurar nada.»",
		"reward": {"Crystal1": 4, "Gold_Ingots": 2},
	},
	{
		"id": "calaveras_espectrales", "at": Vector2(4702.0, -1180.0), "zone": 340.0, "where": "En el confín oriental, Bosque Tenebroso adentro.", "kind": Kind.HUNT, "giver": "calen",
		"title": "Lo que hay más allá del confín", "target": "calavera_espectral", "needed": 5,
		"brief": "«Al este de los árboles rojos ya no hay nada que finja», dice Calen. «Ni voz, ni forma, ni pretexto.» Te mira. «Si vuelves de allí, vuelve contándomelo. Si no vuelves, lo entenderé.»",
		"reward": {"Crystal1": 4},
	},
	{
		"id": "oro_para_la_egida", "where": "Los lingotes salen de los cofres y de los jefes.", "kind": Kind.GATHER, "giver": "orin",
		"title": "Oro de verdad", "target": "Gold_Ingots", "needed": 3,
		"brief": "Orin golpea un escudo con el nudillo y suena a lata. «Esto es chapa dorada. Aguanta una vez.» Lo tira al montón. «Tráeme lingotes y te funjo uno que aguante lo que le echen. Y no me traigas monedas: las monedas llevan cara y el oro con cara no liga.»",
		"reward": {"Crystal1": 3},
	},
]


var _state: Dictionary = {}
var _inventory: Node = null
var _player: Node = null


func bind(inventory: Node, player: Node) -> void:
	_inventory = inventory
	_player = player
	for quest in QUESTS:
		_state[String(quest["id"])] = {
			"taken": false, "done": false, "count": 0,
			"needed": int(quest["needed"]), "reward_scale": 1.0, "told": true,
		}


func quests_of(giver_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest in QUESTS:
		if String(quest["giver"]) == giver_id:
			out.append(quest)
	return out


func pending_for(giver_id: String) -> Dictionary:
	## El primer encargo de ese habitante que no esté cerrado. Si ya está
	## cumplido pero sin cobrar, se devuelve igualmente para poder entregarlo.
	for quest in quests_of(giver_id):
		var record: Dictionary = _state[String(quest["id"])]
		if not bool(record["done"]):
			return quest
	return {}


func quest_by_id(quest_id: String) -> Dictionary:
	for quest in QUESTS:
		if String(quest["id"]) == quest_id:
			return quest
	return {}


func take_with_terms(quest: Dictionary, needed_delta: int, reward_scale: float, told: bool) -> void:
	## Aceptar un encargo en los términos que tú has negociado. El número y la
	## paga dejan de ser fijos: salen de cómo contestaste.
	var record: Dictionary = _state[String(quest["id"])]
	if bool(record["taken"]) or bool(record["done"]):
		return
	record["needed"] = maxi(int(quest["needed"]) + needed_delta, 2)
	record["reward_scale"] = maxf(reward_scale, 0.2)
	record["told"] = told
	take(quest)


func needed_of(quest: Dictionary) -> int:
	var record: Dictionary = _state[String(quest["id"])]
	return int(record.get("needed", int(quest["needed"])))


func was_told(quest: Dictionary) -> bool:
	var record: Dictionary = _state[String(quest["id"])]
	return bool(record.get("told", true))


func terms_line(quest: Dictionary) -> String:
	var record: Dictionary = _state[String(quest["id"])]
	var needed := needed_of(quest)
	var scale := float(record.get("reward_scale", 1.0))
	var paga := "paga igual"
	if scale > 1.05:
		paga = "paga %d%% más" % roundi((scale - 1.0) * 100.0)
	elif scale < 0.95:
		paga = "paga %d%% menos" % roundi((1.0 - scale) * 100.0)
	return "%d unidades, %s%s" % [
		needed, paga, "" if was_told(quest) else ", sin indicaciones"]


func take(quest: Dictionary) -> void:
	var record: Dictionary = _state[String(quest["id"])]
	if bool(record["taken"]) or bool(record["done"]):
		return
	record["taken"] = true
	quest_offered.emit(quest)
	_say("Encargo aceptado · %s" % String(quest["title"]))


func is_taken(quest: Dictionary) -> bool:
	return bool((_state[String(quest["id"])] as Dictionary)["taken"])


func is_done(quest: Dictionary) -> bool:
	return bool((_state[String(quest["id"])] as Dictionary)["done"])


func progress_of(quest: Dictionary) -> int:
	var record: Dictionary = _state[String(quest["id"])]
	if int(quest["kind"]) == Kind.HUNT:
		return int(record["count"])
	if _inventory == null:
		return 0
	return int(_inventory.call("get_count", String(quest["target"])))


func zone_of(quest: Dictionary) -> float:
	return float(quest.get("zone", NO_ZONE))


func zone_centre(quest: Dictionary) -> Vector2:
	return quest.get("at", Vector2.ZERO)


func counts_here(quest: Dictionary, where: Vector2) -> bool:
	var radius := zone_of(quest)
	if radius <= NO_ZONE:
		return true
	return where.distance_to(zone_centre(quest)) <= radius


func on_enemy_defeated(species_id: String, where := Vector2.ZERO) -> void:
	## El identificador del enemigo lleva su especie por delante y el número
	## detrás (`orco_merodeador_037`), así que la cacería cuenta por especie sin
	## necesidad de llevar un registro aparte de cada criatura del mundo.
	for quest in QUESTS:
		if int(quest["kind"]) != Kind.HUNT:
			continue
		if not species_id.begins_with(String(quest["target"])):
			continue
		var record: Dictionary = _state[String(quest["id"])]
		if not bool(record["taken"]) or bool(record["done"]):
			continue
		if not counts_here(quest, where):
			# Decirlo. Matar al bicho bueno en el sitio malo y no ver subir el
			# contador parece una avería, no una regla.
			_say("%s · esa no cuenta: búscalas donde te dijo" % String(quest["title"]))
			continue
		record["count"] = int(record["count"]) + 1
		var needed := needed_of(quest)
		quest_progressed.emit(quest, int(record["count"]), needed)
		if int(record["count"]) >= needed:
			_say("%s · listo para entregar" % String(quest["title"]))
		else:
			_say("%s · %d/%d" % [
				String(quest["title"]), int(record["count"]), needed_of(quest)])


func try_deliver(quest: Dictionary) -> bool:
	var record: Dictionary = _state[String(quest["id"])]
	if bool(record["done"]) or not bool(record["taken"]):
		return false
	var needed := needed_of(quest)
	if progress_of(quest) < needed:
		return false
	if int(quest["kind"]) != Kind.HUNT and _inventory != null:
		# El acopio y el encargo se cobran en material: se entrega de verdad.
		_inventory.call("remove_item", String(quest["target"]), needed, false)
	record["done"] = true
	if _inventory != null:
		var scale := float(record.get("reward_scale", 1.0))
		for item in (quest["reward"] as Dictionary):
			var amount := maxi(1, roundi(float(int(quest["reward"][item])) * scale))
			_inventory.call("add_item", String(item), amount, false)
	var runtime := get_parent()
	if runtime != null and runtime.has_method("grow_hero"):
		runtime.call("grow_hero", QUEST_HEALTH_BONUS, QUEST_STAMINA_BONUS,
			"Encargo · %s" % String(quest["title"]))
	quest_completed.emit(quest)
	_say("Encargo cumplido · %s" % String(quest["title"]))
	return true


func completed_count() -> int:
	var total := 0
	for id in _state:
		if bool((_state[id] as Dictionary)["done"]):
			total += 1
	return total


func taken_count() -> int:
	var total := 0
	for id in _state:
		var record: Dictionary = _state[id]
		if bool(record["taken"]) and not bool(record["done"]):
			total += 1
	return total


func brief_for(quest: Dictionary) -> String:
	var needed := needed_of(quest)
	var have := progress_of(quest)
	var what := "criaturas" if int(quest["kind"]) == Kind.HUNT else String(quest["target"])
	return "%s\n\n%s\n\n[b]%d/%d %s[/b]" % [
		String(quest["brief"]), _kind_line(quest), mini(have, needed), needed, what]


func reminder_for(quest: Dictionary) -> String:
	## Lo que se dice la SEGUNDA vez. Nadie te vuelve a contar la historia entera
	## cuando ya la sabes: te recuerdan lo que falta y ya está.
	var needed := needed_of(quest)
	var have := progress_of(quest)
	if have >= needed:
		return "«Ya está hecho, ¿no? Pues dámelo.»"
	var what := "criaturas" if int(quest["kind"]) == Kind.HUNT else String(quest["target"])
	return "[b]Te faltan %d de %d %s.[/b]" % [needed - have, needed, what]


func _kind_line(quest: Dictionary) -> String:
	match int(quest["kind"]):
		Kind.HUNT:
			return "Cacería: acaba con %d." % needed_of(quest)
		Kind.GATHER:
			return "Acopio: trae %d." % needed_of(quest)
		_:
			return "Encargo: consigue la pieza y tráela."


func _say(message: String) -> void:
	if _player != null and _player.has_signal("action_feedback"):
		_player.emit_signal("action_feedback", message)


func save_state() -> Dictionary:
	return _state.duplicate(true)


func load_state(state: Dictionary) -> void:
	for id in state:
		if _state.has(id):
			_state[id] = (state[id] as Dictionary).duplicate(true)
