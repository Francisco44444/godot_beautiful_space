class_name RPGCampaign
extends Node

## La columna vertebral de la aventura: cinco actos, cinco jefes, cinco
## reliquias.
##
## EL HILO. Las campanas de Aeloria no tocaban las horas: sujetaban algo. Cada
## campana llevaba grabado el nombre de quien la fundió, y ese nombre era lo que
## la ataba. Alguien raspó los nombres. Lo que sujetaban despertó.
##
## Vaelor no es "todo lo que la isla decidió olvidar", que no significa nada: es
## lo que queda de una persona cuando le quitas el nombre. Las cuatro reliquias
## son los cuatro nombres raspados, y por eso pesan y laten. Y hay un quinto,
## que es el motivo por el que en toda Aeloria nadie te llama por el tuyo.
##
## Los 200 objetivos que ya existían son la carne —lugares que descubrir,
## bestiario, cofres— pero no eran un hilo: se completaban en cualquier orden y
## ninguno cerraba nada. La campaña pone encima una espina dorsal con principio
## y final, y la ata al mundo de tres maneras:
##
##   1. CADA ACTO TERMINA EN UN JEFE, y cada jefe exige una mecánica distinta
##      del repertorio del héroe. No se pasa de acto machacando el botón: se
##      pasa aprendiendo a cubrirse, a disparar, a cargar y a esquivar.
##   2. LA ESTRUCTURA NO ES UNA FILA INDIA. El Acto I es el prólogo y hay que
##      hacerlo: es donde se entiende de qué va esto. Pero los tres del medio
##      —bruma, hielo y arena— se abren A LA VEZ y se hacen en el orden que
##      quieras, o ninguno, o los tres. El V pide los cuatro nombres.
##      Así la isla es un abanico y no un pasillo, y quien vaya al hielo antes
##      que a la bruma se encontrará al Coloso con la espada de Robledal, que
##      es una decisión y no un error.
##   3. CADA ACTO PAGA EN MATERIAL DE FORJA, y el material que paga es el que
##      pide la siguiente mejora. Así el equipo sube al mismo ritmo que la
##      historia en vez de por su cuenta.

signal act_started(act: Dictionary)
signal act_completed(act: Dictionary, relic: String)
signal campaign_finished()

## El sitio de un acto es donde está su jefe. Tenerlo escrito aquí además de en
## el bestiario hacía que mover una arena dejase la brújula apuntando al hueco
## que dejó, sin que nada avisara.
## Los cinco finales. No es una puntuación: es cómo te ha tratado la isla según
## cómo la trataste tú. El hilo entero va de nombres raspados, así que lo que
## cambia al final es si alguien dice el tuyo.
##
## Se decide con función pura —sin mundo, sin nodos— para poder probar las cinco
## ramas de verdad en vez de confiar en que la que salga esté bien.
const ENDINGS: Array[Dictionary] = [
	{
		"id": "los_cinco_y_uno",
		"title": "Los cinco y uno",
		"cards": [
			"Las cinco campanas suenan a la vez por primera vez en tres años.",
			"Y no suenan solas. Brenn, Calen, Tavia, Orin: cada uno pone la mano en el bronce que le toca, y el nombre grabado vuelve a leerse bajo los dedos.",
			"Queda una campana sin nombre. La sexta, la que nadie recordaba haber fundido.\n\nTe miran. Esperan.\n\nY lo dices.",
		],
	},
	{
		"id": "el_nombre_dicho",
		"title": "El nombre dicho",
		"cards": [
			"Las cinco campanas suenan. La isla entera sale a la puerta a oírlas.",
			"Maela llega con el mapa terminado. En el margen, donde van los nombres de quien abrió cada camino, hay un hueco con tu letra pendiente.",
			"«Dínoslo», dice. «Llevamos tres años sin poder llamar a nadie por su nombre.»\n\nY lo dices.",
		],
	},
	{
		"id": "el_nombre_raspado",
		"title": "El nombre raspado",
		"cards": [
			"Las cinco campanas suenan. Nadie sale a la puerta.",
			"Cumpliste lo que dijiste que ibas a cumplir, y cobraste lo que dijiste que ibas a cobrar. Nadie te debe nada. Tú tampoco.",
			"Cuando te vas, alguien sube al campanario con una lima.\n\nNo por rencor: por costumbre. Aquí los nombres se raspan.",
		],
	},
	{
		"id": "el_que_paso_de_largo",
		"title": "El que pasó de largo",
		"cards": [
			"Las cinco campanas suenan sobre una isla que apenas conociste.",
			"Fuiste derecho a los cinco. Funcionó. Los caminos siguen sin arreglar, los pozos sin cavar y los encargos donde estaban.",
			"Aeloria recupera su voz y la usa para hablar de otras cosas.\n\nDe ti no se acuerda casi nadie.",
		],
	},
	{
		"id": "la_sexta_campana",
		"title": "La sexta campana",
		"cards": [
			"Las cinco campanas suenan, y hay una sexta que no está.",
			"La fundieron el mismo año que las otras. Está en todos los inventarios y en ningún campanario.",
			"Te vas antes de que amanezca, como llegaste.\n\nAlguien, años después, encontrará el molde con un nombre a medio raspar y no sabrá de quién era.",
		],
	},
]


## `regard` es la suma del aprecio de toda la isla, `quests` los encargos
## cumplidos de dieciocho, `allies` los aliados ganados y `witnessed` cuántos
## actos peleaste acompañado.
static func ending_for(regard: int, quests: int, allies: int, witnessed: int) -> Dictionary:
	# Dos ejes: lo que HICISTE por la gente y CÓMO se lo dijiste. Poner el
	# aprecio por delante hacía que el final malo cayera encima de quien había
	# resuelto los dieciocho encargos sólo por contestar seco, y se llevaba el
	# 42% del espacio de partidas. Los hechos mandan; el trato decide el matiz.
	var kind := regard >= 6
	var harsh := regard <= -4
	var helped := quests >= 9
	if helped and kind and allies >= 3 and quests >= 12 and witnessed >= 3:
		return ENDINGS[0]
	if helped and kind:
		return ENDINGS[1]
	if quests <= 4 and harsh:
		return ENDINGS[2]
	if quests <= 4:
		return ENDINGS[3]
	# Ayudaste, pero nunca dejaste que nadie se acercara. Es exactamente la
	# campana que está en todos los inventarios y en ningún campanario.
	return ENDINGS[4]


static func where_of(act: Dictionary) -> Vector2:
	for boss in RPGBestiary.BOSSES:
		if String(boss["id"]) == String(act.get("boss", "")):
			return boss["point"]
	return Vector2.ZERO


const ACTS: Array[Dictionary] = [
	{
		"id": "corazon_de_roble", "needs": [],
		"numeral": "I",
		"title": "El Corazón de Roble",
		"region": "Villa Robledal y el bosque occidental",
		"giver": "tavia",
		"boss": "rey_fungico",
		"relic": "El nombre de Mira",
		"teaches": "Cubrirse con el escudo",
		"goal": "Encuentra la raíz enferma al oeste de Robledal y arranca lo que vive debajo.",
		"opening": "Tavia te pone tres semillas negras en la mano. «Toca. Están huecas. Llevan así desde que la campana dejó de sonar, y el roble grande del oeste está criando algo que no es raíz.» Se limpia las manos en el delantal. «Mi hermana la fundió, esa campana. Ahora no me acuerdo de cómo se llamaba y estoy segura de haberlo sabido.»",
		"closing": "Lo que crecía bajo el roble se deshace, y en el hueco queda una lámina de bronce con un nombre a medio raspar: MIRA. Tavia lo lee dos veces y se echa a llorar sin ruido, porque acaba de recordar a su hermana.",
		"hint": "Su embestida se anuncia antes de caer. Cúbrete y quedará abierto.",
		"reward": {"Crystal4": 4, "Gold_Ingots": 1},
	},
	{
		"id": "la_bruma_que_habla",
		"needs": ["corazon_de_roble"],
		"numeral": "II",
		"title": "La bruma que habla",
		"region": "Aldea de la Bruma y la Sierra del Viento",
		"giver": "brenn",
		"boss": "centinela_bruma",
		"relic": "El nombre de Doro",
		"teaches": "El arco",
		"goal": "Baja a la hondonada al sur de la Aldea de la Bruma y calla lo que repite allí.",
		"opening": "Brenn tarda en hablar. «Abajo hay una voz que dice cosas que dijo mi padre. Palabra por palabra.» Mira el suelo. «Bajé una vez. Le contesté.» No dice qué pasó después, ni tú se lo preguntas.",
		"closing": "La bruma se abre como una boca que termina una frase, y lo que cae al barro es media campana con el nombre DORO todavía legible en el borde. Brenn la recoge, la limpia con el pulgar, y por primera vez desde que lo conoces te mira a la cara.",
		"hint": "Se envuelve en bruma y el acero no le entra. Rómpela a flechazos primero.",
		"reward": {"Crystal2": 4, "Gold_Ingots": 1},
	},
	{
		"id": "cielo_detenido",
		"needs": ["corazon_de_roble"],
		"numeral": "III",
		"title": "El cielo detenido",
		"region": "Castillo Boreal y las Cumbres Blancas",
		"giver": "ysra",
		"boss": "coloso_escarcha",
		"relic": "El nombre de Ysra",
		"teaches": "El ataque cargado",
		"goal": "Sube a las Cumbres Blancas y abre la coraza de lo que duerme bajo el hielo.",
		"opening": "Ysra habla sin apartar el ojo del tubo. «Cuarenta y un años midiendo esa constelación. Gira una vez por invierno. Este invierno no ha girado.» Anota algo. «He revisado el cálculo once veces. El cálculo está bien. Lo que falla es el cielo.»",
		"closing": "La coraza revienta en escamas y el cielo del norte reanuda su vuelta con un chasquido que se oye en todo el valle. En el hielo queda un nombre grabado del revés, como se graba en un molde: YSRA. Ella lo mira mucho rato. «No fundí ninguna campana», dice. «Todavía.»",
		"hint": "Sólo el giro cargado abre su coraza. Mantén el ataque hasta que arrecie la tormenta.",
		"reward": {"Crystal3": 4, "Gold_Ingots": 2},
	},
	{
		"id": "sol_bajo_la_arena",
		"needs": ["corazon_de_roble"],
		"numeral": "IV",
		"title": "El sol bajo la arena",
		"region": "Oasis Dorado y el desierto",
		"giver": "nara",
		"boss": "guardian_solar",
		"relic": "El nombre de Halim",
		"teaches": "La esquiva",
		"goal": "Cruza las dunas hasta el santuario del Oasis y derriba a lo que lo guarda.",
		"opening": "Nara no te ofrece agua hasta que te sientas. «Aquí enterramos a la gente con su nombre en la boca. Un guijarro grabado, bajo la lengua. Es lo único que se lleva uno.» Señala el santuario con la barbilla. «Hace dos años abrimos una tumba para meter a otro. El guijarro estaba liso.»",
		"closing": "El guardián se estrella por última vez y la arena se vitrifica alrededor. En el cristal, atrapado como un insecto en ámbar, hay un guijarro con una palabra: HALIM. Nara lo saca con cuidado. «Mi marido», dice, sin más.",
		"hint": "No se bloquea: pica en línea recta. Rueda a un lado y se estrellará solo.",
		"reward": {"Crystal5": 4, "Gold_Ingots": 2},
	},
	{
		"id": "la_voz_del_horizonte",
		"needs": ["la_bruma_que_habla", "cielo_detenido", "sol_bajo_la_arena"],
		"numeral": "V",
		"title": "La voz del horizonte",
		"region": "Bosque Tenebroso, en el confín oriental",
		"giver": "calen",
		"boss": "vaelor",
		"relic": "Tu propio nombre",
		"teaches": "Todo lo aprendido",
		"goal": "Lleva los cuatro nombres al Bosque Tenebroso y enfréntate a Vaelor.",
		"opening": "Calen alinea los cuatro nombres sobre la mesa y no los suelta. «Fui yo. Me mandaron raspar uno y raspé cinco, porque el quinto era el que había que esconder.» Levanta la vista. «¿Te has fijado en que nadie de esta isla te ha llamado por tu nombre? Ni yo. Llevo semanas intentándolo.»",
		"closing": "Vaelor se deshace en un sonido largo que no es un grito: es alguien diciendo su propio nombre después de mucho tiempo. Luego suenan las campanas, las cinco, y por primera vez desde que llegaste alguien te llama. Te vuelves. Era Tavia. Y sabe cómo te llamas.",
		"hint": "Cambia de respuesta en cada fase: escudo, arco, carga y esquiva.",
		"reward": {"Crystal1": 6, "Gold_Ingots": 4},
	},
]

## Qué actos están cerrados, por identificador. Sustituye al índice único: con
## un índice sólo se puede avanzar en línea, y aquí hay tres caminos abiertos.
var _done: Dictionary = {}
var relics: PackedStringArray = PackedStringArray()
var _finished := false


func act_by_id(act_id: String) -> Dictionary:
	for act in ACTS:
		if String(act["id"]) == act_id:
			return act
	return {}


func is_done(act_id: String) -> bool:
	return bool(_done.get(act_id, false))


func is_open(act: Dictionary) -> bool:
	## Un acto está abierto si no está hecho y todos los que pide ya lo están.
	if is_done(String(act["id"])):
		return false
	for needed in (act.get("needs", []) as Array):
		if not is_done(String(needed)):
			return false
	return true


func open_acts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for act in ACTS:
		if is_open(act):
			out.append(act)
	return out


func active_act() -> Dictionary:
	## El "acto activo" ya no es una posición: es el primero de los abiertos, y
	## sirve sólo para tener algo que enseñar cuando hace falta uno solo.
	var open := open_acts()
	return {} if open.is_empty() else open[0]


func act_of_boss(boss_id: String) -> int:
	for index in ACTS.size():
		if String(ACTS[index]["boss"]) == boss_id:
			return index
	return -1


func is_boss_unlocked(boss_id: String) -> bool:
	## Un jefe despierta cuando SU acto está abierto. Con tres abiertos a la vez,
	## hay tres jefes despiertos y eliges tú por dónde empezar.
	var index := act_of_boss(boss_id)
	return index >= 0 and is_open(ACTS[index])


func begin() -> void:
	if _finished:
		return
	for act in open_acts():
		act_started.emit(act)


func on_boss_defeated(boss_id: String, inventory: Node) -> bool:
	var index := act_of_boss(boss_id)
	if index < 0:
		return false
	var act := ACTS[index]
	if not is_open(act):
		return false
	_done[String(act["id"])] = true
	var relic := String(act["relic"])
	relics.append(relic)
	if inventory != null:
		for item in (act["reward"] as Dictionary):
			inventory.call("add_item", String(item), int(act["reward"][item]), false)
	act_completed.emit(act, relic)
	if _done.size() >= ACTS.size():
		_finished = true
		campaign_finished.emit()
	else:
		# Cerrar un acto puede abrir varios: el I abre tres de golpe.
		for opened in open_acts():
			act_started.emit(opened)
	return true


func progress() -> Dictionary:
	return {
		"index": _done.size(),
		"total": ACTS.size(),
		"relics": relics.size(),
		"finished": _finished,
		"act": active_act(),
		"open": open_acts().size(),
	}


func headline() -> String:
	## Lo que se lee en el seguidor. Con varios caminos abiertos, decirlo.
	if _finished:
		return "Aeloria · la voz devuelta"
	var open := open_acts()
	if open.is_empty():
		return "Aeloria calla"
	if open.size() == 1:
		return "Acto %s · %s" % [String(open[0]["numeral"]), String(open[0]["title"])]
	return "%d caminos abiertos" % open.size()


func save_state() -> Dictionary:
	return {"done": _done.duplicate(true), "relics": relics, "finished": _finished}


func load_state(state: Dictionary) -> void:
	_done = (state.get("done", {}) as Dictionary).duplicate(true)
	relics = PackedStringArray(state.get("relics", []))
	_finished = bool(state.get("finished", false))
