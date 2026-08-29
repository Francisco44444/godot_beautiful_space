class_name RPGStoryCatalog
extends RefCounted

## Estructura narrativa determinista para los 200 objetivos existentes.
## No mueve los marcadores: únicamente los ordena como una campaña en ocho
## capítulos y aporta nombres, contexto, recompensas y personajes relacionados.

const CHAPTERS: Array[Dictionary] = [
	{
		"id": "el_eco_roto", "title": "I · El eco roto", "region": "Puerto Alba y las praderas",
		"summary": "Las campanas de Aeloria han dejado de responder. Maela, la cartógrafa, reconoce en ti al Portador del Eco y te pide reunir a los primeros testigos.",
		"finale": "Recupera el Fragmento del Alba antes de que el Silencio borre el camino a Robledal.",
	},
	{
		"id": "raices_de_robledal", "title": "II · Raíces de Robledal", "region": "Robledal y el bosque occidental",
		"summary": "Las raíces recuerdan una melodía que los hombres olvidaron. La herborista Tavia guía la búsqueda del segundo fragmento entre bestias inquietas y árboles marcados.",
		"finale": "Despierta el Corazón de Roble y descubre quién está envenenando los senderos.",
	},
	{
		"id": "la_bruma_que_habla", "title": "III · La bruma que habla", "region": "Bosque Umbrío y Sierra del Viento",
		"summary": "Voces perdidas vagan bajo la niebla. El guardabosques Brenn asegura que una de ellas pertenece a la antigua reina de la isla.",
		"finale": "Cruza la senda de los susurros y libera la voz atrapada en la Piedra de la Bruma.",
	},
	{
		"id": "corona_de_invierno", "title": "IV · La corona de invierno", "region": "Cordilleras y Cumbres Blancas",
		"summary": "El Silencio congela los nombres de quienes suben al norte. Ysra, astrónoma boreal, busca tres runas capaces de encender de nuevo el cielo.",
		"finale": "Abre el observatorio sepultado y reclama la Corona de Escarcha.",
	},
	{
		"id": "sol_bajo_la_arena", "title": "V · El sol bajo la arena", "region": "Cumbres Blancas y Oasis Dorado",
		"summary": "Una ciudad duerme bajo las dunas. Nara, última vigía del oasis, conoce la llave de sus cámaras y el precio que exigió el antiguo rey.",
		"finale": "Desciende al Santuario Solar y rescata la Brasa que no se apaga.",
	},
	{
		"id": "mareas_de_cristal", "title": "VI · Mareas de cristal", "region": "Dunas, playas y rías",
		"summary": "Las mareas traen cristales con recuerdos ajenos. El capitán Orin necesita reparar el faro para impedir que esas memorias alimenten al enemigo.",
		"finale": "Enciende el Faro de las Mareas y recupera la Perla de los Navegantes.",
	},
	{
		"id": "las_cuatro_llaves", "title": "VII · Las cuatro llaves", "region": "Costa, castillos y frontera oriental",
		"summary": "Los cuatro fragmentos señalan puertas más antiguas que los castillos. Reúne las llaves de sus guardianes y prepara a las villas para la última noche.",
		"finale": "Abre las grutas selladas y forja el arma capaz de herir al Silencio.",
	},
	{
		"id": "la_voz_del_horizonte", "title": "VIII · La voz del horizonte", "region": "Bosque Tenebroso",
		"summary": "En el confín oriental, los árboles rojos crecen alrededor de una voz sin cuerpo. Allí aguarda Vaelor, criatura nacida de todo lo que Aeloria decidió olvidar.",
		"finale": "Entra en la Cámara sin Eco, derrota a Vaelor y devuelve su voz a la isla.",
	},
]

const OBJECTIVE_TITLES: Array = [
	[
		"La carta que llegó sin mensajero", "Una campana bajo el agua", "Maela y el mapa incompleto", "Huellas frente a Puerto Alba", "El cofre del viejo embarcadero",
		"La casa de las ventanas azules", "Un ciervo que no proyecta sombra", "El árbol de los siete nudos", "Piedras con nombre", "La promesa del herrero",
		"El puente que canta al alba", "Rastros junto al molino", "La llave de cobre", "El jardín abandonado", "El mensajero de Robledal",
		"Una luz entre los trigales", "El juramento de Brisa", "Los bandidos del camino blanco", "El rubí de la acequia", "La posada del último cuento",
		"Vigilia sobre la colina", "El escondite del cartógrafo", "La primera nota", "Donde despiertan los senderos", "El Fragmento del Alba",
	],
	[
		"La puerta entre raíces", "Tavia, guardiana de semillas", "El zorro de orejas plateadas", "Tres árboles enfermos", "El cofre del leñador desaparecido",
		"Hongos bajo la luna", "El pacto de la encina", "Colmillos en el sotobosque", "La savia oscura", "El sendero que cambia de lugar",
		"Cartas clavadas en un tronco", "El claro de las luciérnagas", "La veta bajo el roble", "El lobo que recuerda", "El altar cubierto de musgo",
		"Las botas de Brenn", "El enjambre silencioso", "El hacha del primer guardabosques", "Una corona de ramas", "El huésped de la cabaña",
		"El pozo de las raíces", "Semillas para el mañana", "La canción enterrada", "La bestia del roble hueco", "El Corazón de Roble",
	],
	[
		"Niebla sobre el camino viejo", "La voz detrás de los helechos", "Brenn y la linterna apagada", "Campanas en la espesura", "El venado de cristal",
		"La cueva de las marcas blancas", "Un cofre sin cerradura", "El paso de los gigantes", "La torre que olvidó su puerta", "Ecos en la cantera",
		"La piedra que pronuncia tu nombre", "Sombras alrededor del fuego", "El arco del vigía", "La garganta del viento", "Reliquias de una patrulla perdida",
		"El nido sobre el abismo", "La escalera de la lluvia", "Los tres susurros", "El guardián de granito", "Una voz en la tormenta",
		"El camino por encima de las nubes", "La runa de la memoria", "El último campamento", "La reina en la niebla", "La Piedra de la Bruma",
	],
	[
		"El primer copo negro", "Ysra y las estrellas inmóviles", "El refugio bajo la avalancha", "La huella del yeti", "El cofre de los montañeros",
		"La runa del norte", "Hielo sobre las almenas", "El lobo blanco", "La mina congelada", "La torre de los astrónomos",
		"Un fuego que no da calor", "La cornisa de las águilas", "El espejo de escarcha", "El guardián del puerto de montaña", "La segunda runa",
		"Las voces bajo el glaciar", "El puente de hielo azul", "La llave de plata", "La cámara de las constelaciones", "La noche más larga",
		"El gigante dormido", "La tercera runa", "El cielo vuelve a girar", "La cima sin bandera", "La Corona de Escarcha",
	],
	[
		"Deshielo hacia el sur", "El mapa grabado en sal", "Nara, vigía del oasis", "El cactus de flores rojas", "La caravana inmóvil",
		"Huellas que terminan en el aire", "El cofre bajo la duna", "La llave del escorpión", "Cristales al mediodía", "La tumba del rey sin rostro",
		"Un pozo lleno de estrellas", "El ladrón de cantimploras", "La aguja solar", "El cactoro centinela", "Las columnas enterradas",
		"El mercado de los espejismos", "La canción de Nara", "El sello de arenisca", "La cámara del mediodía", "Una sombra sin dueño",
		"El guardián de oro", "El puente sobre el vacío", "La llama cautiva", "El juramento del oasis", "La Brasa Eterna",
	],
	[
		"El río que vuelve al mar", "Orin y el faro apagado", "Botellas en la bajamar", "La playa de los rubíes", "El cofre del barco hundido",
		"Cantos desde la ría", "El cangrejo coronado", "La gruta de la marea baja", "Maderas para el faro", "La boya del navegante",
		"Una isla que aparece de noche", "El timón sin barco", "La campana del arrecife", "El tesoro del contrabandista", "Las escaleras de espuma",
		"La llave de coral", "El monstruo de la ensenada", "Cristales en la arena", "El último farero", "La lente quebrada",
		"La torre vuelve a brillar", "La ruta de las gaviotas", "El naufragio de la reina", "La marea recuerda", "La Perla de los Navegantes",
	],
	[
		"Consejo en Puerto Alba", "La forja de Orin", "La llave de Robledal", "La llave de la Bruma", "La llave Boreal",
		"La llave del Sol", "Las murallas del este", "Mensajeros para las villas", "El escudo de los antiguos", "La primera gruta sellada",
		"La biblioteca subterránea", "El caballero sin estandarte", "La segunda gruta", "El taller de las armas cantoras", "Una espada para el Eco",
		"La tercera puerta", "Prisioneros bajo la costa", "El monstruo del puente", "La cuarta gruta", "El mapa de la Cámara sin Eco",
		"Ocho voces para una canción", "La vigilia de los castillos", "El último banquete", "La marcha hacia el este", "La puerta del Bosque Tenebroso",
	],
	[
		"Árboles de hojas carmesí", "El sendero sin pájaros", "La cabaña de la bruja Lume", "Rocas que respiran", "El ejército de madera seca",
		"La llave que sangra luz", "El pantano de los nombres", "La criatura de ojos azules", "Un amigo convertido en sombra", "La cascada invertida",
		"El jardín de estatuas", "El último cofre de la reina", "La torre inclinada", "El dragón del horizonte", "El corazón del bosque rojo",
		"La escalera hacia ninguna parte", "El coro de los olvidados", "La máscara de Vaelor", "La Cámara sin Eco", "El combate por la memoria",
		"La voz recuperada", "Las campanas de Aeloria", "El amanecer prometido", "La última luz del Silencio", "La colina conoce tu voz",
	],
]

const ACTION_CONTEXT := {
	"visit": "Llega al lugar señalado, busca la marca del Eco y confirma el descubrimiento.",
	"discover_animal": "Acércate sin asustar a la criatura y registra su reacción en el bestiario de Maela.",
	"open_chest": "Encuentra el cofre vinculado a esta pista y ábrelo para recuperar lo que protegían los guardianes.",
	"chop_tree": "Equipa un hacha, tala únicamente el árbol marcado y recoge la madera resonante.",
	"mine_rock": "Rompe la veta señalada con el hacha y recoge todos los cristales desprendidos.",
	"recover_relic": "Localiza la reliquia, recógela y conserva su memoria en el inventario.",
	"event": "Permanece en el mirador durante el momento indicado y confirma la visión.",
}

const CHAPTER_REWARDS: PackedStringArray = [
	"Key1", "Axe_small_Golden", "Key2", "Armor_Metal2",
	"Key3", "Bow_Golden", "Key4", "Sword_big_Golden",
]


static func get_chapters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for chapter in CHAPTERS:
		result.append(chapter.duplicate(true))
	return result


static func decorate_zones(source_zones: Array[Dictionary]) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for source in source_zones:
		by_id[String(source.get("id", ""))] = source
	var route := _build_story_route()
	var result_by_id: Dictionary = {}
	for route_index in route.size():
		var zone_id := String(route[route_index])
		if not by_id.has(zone_id):
			continue
		var zone := (by_id[zone_id] as Dictionary).duplicate(true)
		var chapter_index := mini(route_index / 25, CHAPTERS.size() - 1)
		var step_index := route_index % 25
		var chapter: Dictionary = CHAPTERS[chapter_index]
		var title := String(OBJECTIVE_TITLES[chapter_index][step_index])
		var requirement := String(zone.get("requirement", "visit"))
		zone["name"] = title
		zone["description"] = "%s\n\n%s" % [
			String(chapter.summary),
			String(ACTION_CONTEXT.get(requirement, ACTION_CONTEXT.visit)),
		]
		zone["story_order"] = route_index + 1
		zone["chapter_index"] = chapter_index + 1
		zone["chapter_id"] = String(chapter.id)
		zone["chapter_title"] = String(chapter.title)
		zone["chapter_region"] = String(chapter.region)
		zone["story_beat"] = title
		zone["story_critical"] = step_index in [0, 4, 9, 14, 19, 24]
		zone["reward_preview"] = _reward_for_step(chapter_index, step_index, requirement)
		zone["npc_id"] = _npc_for_step(chapter_index, step_index)
		zone["objective_hint"] = "%s  ·  P: pista completa" % String(zone.get("objective_hint", "E · investigar"))
		result_by_id[zone_id] = zone
	var decorated: Array[Dictionary] = []
	for original in source_zones:
		var original_id := String(original.get("id", ""))
		decorated.append((result_by_id.get(original_id, original) as Dictionary).duplicate(true))
	return decorated


static func _build_story_route() -> PackedStringArray:
	var route := PackedStringArray()
	_append_numeric_range(route, 185, 198) # Comenzar hablando con villas y castillos.
	_append_numeric_range(route, 1, 72)    # Pradera y bosque occidental.
	_append_numeric_range(route, 149, 168) # Sierra antes del ascenso boreal.
	_append_numeric_range(route, 73, 98)   # Nieve.
	_append_numeric_range(route, 99, 122)  # Desierto.
	_append_numeric_range(route, 123, 148) # Costa.
	_append_numeric_range(route, 169, 184) # Bosque Tenebroso.
	route.append("zone_199_amanecer")
	route.append("zone_200_atardecer")
	return route


static func _append_numeric_range(target: PackedStringArray, first: int, last: int) -> void:
	for value in range(first, last + 1):
		target.append("zone_%03d" % value)


static func _reward_for_step(chapter_index: int, step_index: int, requirement: String) -> String:
	if step_index == 24:
		return CHAPTER_REWARDS[chapter_index]
	match requirement:
		"open_chest": return "Tesoro y flechas"
		"chop_tree": return "Madera resonante"
		"mine_rock": return "Rubíes de Aeloria"
		"recover_relic": return "Reliquia y memoria"
		"discover_animal": return "Entrada de bestiario"
		_: return "Progreso de historia"


static func _npc_for_step(chapter_index: int, step_index: int) -> String:
	if step_index not in [0, 12, 24]:
		return ""
	var npc_ids := [
		["maela", "orin", "maela"], ["tavia", "brenn", "tavia"],
		["brenn", "lume", "brenn"], ["ysra", "calen", "ysra"],
		["nara", "orin", "nara"], ["orin", "maela", "orin"],
		["calen", "tavia", "calen"], ["lume", "ysra", "maela"],
	]
	var milestone := 0 if step_index == 0 else (1 if step_index == 12 else 2)
	return String(npc_ids[chapter_index][milestone])
