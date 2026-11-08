class_name RPGStoryRuntime
extends Node3D

## Materializa la campaña de ocho capítulos: habitantes, puertas de gruta,
## monstruos y recompensas. ExplorationManager conserva los 200 objetivos y
## este nodo aporta los personajes y consecuencias físicas que los conectan.

signal dialogue_requested(speaker: String, role: String, title: String, body: String)
signal player_health_changed(current: int, maximum: int)
signal dialogue_with_choices(
	speaker: String, role: String, title: String, body: String, choices: Array)
signal chapter_reward_granted(chapter: int, item_id: String, display_name: String)

const NPC_SCRIPT: Script = preload("res://scripts/rpg_npc.gd")
const ENEMY_SCRIPT: Script = preload("res://scripts/rpg_enemy.gd")
const BOSS_SCRIPT: Script = preload("res://scripts/rpg_boss.gd")
## Una herrería por villa. El yunque va apartado del cruce de calles para que no
## estorbe el paso, y su nombre dice a qué villa pertenece.
const FORGE_SPECS: Array[Dictionary] = [
	{"name": "Herrería de Puerto Alba", "point": Vector2(-24.0, 168.0)},
	{"name": "Herrería de Robledal", "point": Vector2(-1414.0, 686.0)},
	{"name": "Fragua de la Bruma", "point": Vector2(-2176.0, -926.0)},
	{"name": "Fragua del Bastión", "point": Vector2(2288.0, -1004.0)},
	{"name": "Yunque del Oasis", "point": Vector2(2206.0, 1852.0)},
	{"name": "Fragua Boreal", "point": Vector2(-446.0, -2176.0)},
]
const GATE_SCRIPT: Script = preload("res://scripts/rpg_cave_gate.gd")
const MONSTER_ROOT := "res://assets/quaternius/Ultimate Monsters/"
const CHAPTER_REWARDS: PackedStringArray = [
	"Key1", "Axe_small_Golden", "Key2", "Armor_Metal2",
	"Key3", "Bow_Golden", "Key4", "Sword_big_Golden",
]
const NPC_SPECS: Array[Dictionary] = [
	{"id":"maela", "name":"Maela", "role":"Cartógrafa del Eco", "file":"Elf.gltf", "point":Vector2(12, 214)},
	{"id":"orin", "name":"Orin", "role":"Capitán y herrero", "file":"Viking_Male.gltf", "point":Vector2(-38, 165)},
	{"id":"tavia", "name":"Tavia", "role":"Guardiana de semillas", "file":"Viking_Female.gltf", "point":Vector2(-1438, 672)},
	{"id":"brenn", "name":"Brenn", "role":"Guardabosques de la Bruma", "file":"Cowboy_Male.gltf", "point":Vector2(-2168, -872)},
	{"id":"ysra", "name":"Ysra", "role":"Astrónoma boreal", "file":"Wizard.gltf", "point":Vector2(-404, -2122)},
	{"id":"nara", "name":"Nara", "role":"Vigía del Oasis", "file":"Ninja_Sand_Female.gltf", "point":Vector2(2204, 1870)},
	{"id":"calen", "name":"Calen", "role":"Caballero de las cuatro llaves", "file":"Knight_Male.gltf", "point":Vector2(2284, -958)},
	{"id":"lume", "name":"Lume", "role":"Bruja de los nombres", "file":"Witch.gltf", "point":Vector2(4590, -1234)},
	{"id":"elda", "name":"Elda", "role":"Posadera de Puerto Alba", "file":"OldClassy_Female.gltf", "point":Vector2(44, 178)},
	{"id":"garrik", "name":"Garrik", "role":"Cantero de Robledal", "file":"Viking_Male.gltf", "point":Vector2(-1476, 618)},
	{"id":"sira", "name":"Sira", "role":"Exploradora de las rías", "file":"Pirate_Female.gltf", "point":Vector2(-2172, 1680)},
	{"id":"aldren", "name":"Aldren", "role":"Cronista del castillo", "file":"OldClassy_Male.gltf", "point":Vector2(-390, -2180)},
	{"id":"mira", "name":"Mira", "role":"Sanadora errante", "file":"Doctor_Female_Young.gltf", "point":Vector2(940, -148)},
	{"id":"bor", "name":"Bor", "role":"Leñador de siete nudos", "file":"Worker_Male.gltf", "point":Vector2(-710, 720)},
	{"id":"aiko", "name":"Aiko", "role":"Mercader de espejismos", "file":"Kimono_Female.gltf", "point":Vector2(2154, 1910)},
	{"id":"tarik", "name":"Tarik", "role":"Guía de las dunas", "file":"Ninja_Sand.gltf", "point":Vector2(2600, 2060)},
	{"id":"frey", "name":"Frey", "role":"Centinela de las cumbres", "file":"Knight_Golden_Male.gltf", "point":Vector2(535, -2990)},
	{"id":"una", "name":"Una", "role":"Cocinera de historias", "file":"Chef_Female.gltf", "point":Vector2(-1670, 330)},
	{"id":"rurik", "name":"Rurik", "role":"Armero del Bastión", "file":"Viking_Male.gltf", "point":Vector2(2315, -1010)},
	{"id":"selene", "name":"Selene", "role":"Vigía del faro", "file":"Pirate_Female.gltf", "point":Vector2(1700, -1010)},
	{"id":"nilo", "name":"Nilo", "role":"Aprendiz de cartógrafo", "file":"Casual2_Male.gltf", "point":Vector2(900, -2340)},
	{"id":"vera", "name":"Vera", "role":"Pastora de Robledal", "file":"Casual3_Female.gltf", "point":Vector2(-1025, -1880)},
	{"id":"helga", "name":"Helga", "role":"Escudera boreal", "file":"Knight_Golden_Female.gltf", "point":Vector2(670, -3040)},
	{"id":"noa", "name":"Noa", "role":"Recolectora del bosque rojo", "file":"Goblin_Female.gltf", "point":Vector2(4260, -1510)},
]
const GATE_SPECS: Array[Dictionary] = [
	{"id":"roots", "name":"Gruta de las Raíces", "key":"Key1", "point":Vector2(-2530, 1090), "yaw":0.0, "hint":"Cripta del Corazón de Roble"},
	{"id":"frost", "name":"Observatorio Sepultado", "key":"Key2", "point":Vector2(690, -3370), "yaw":3.14159265359, "hint":"Cámara de las Constelaciones"},
	{"id":"sun", "name":"Santuario bajo la Arena", "key":"Key3", "point":Vector2(2750, 1700), "yaw":0.0, "hint":"Cámara del Mediodía"},
	{"id":"echo", "name":"Cámara sin Eco", "key":"Key4", "point":Vector2(4700, -1450), "yaw":0.0, "hint":"Guarida de Vaelor"},
]
const ENEMY_PATHS: PackedStringArray = [
	"Blob/glTF/GreenSpikyBlob.gltf", "Blob/glTF/Mushnub_Evolved.gltf",
	"Big/glTF/Orc.gltf", "Big/glTF/BlueDemon.gltf", "Big/glTF/Yeti.gltf",
	"Big/glTF/MushroomKing.gltf", "Flying/glTF/Ghost.gltf", "Flying/glTF/Dragon.gltf",
	"Flying/glTF/Ghost_Skull.gltf", "Big/glTF/Demon.gltf",
]
const ENCOUNTER_CENTERS: Array[Vector3] = [
	Vector3(-2530, 0, 1090), Vector3(-2050, 0, -420), Vector3(-2920, 0, 350),
	Vector3(690, 0, -3370), Vector3(-180, 0, -3550), Vector3(1320, 0, -3650),
	Vector3(3190, 0, 2290), Vector3(2780, 0, 1740), Vector3(3880, 0, 2480),
	Vector3(4970, 0, -1510), Vector3(4300, 0, -1850), Vector3(5200, 0, -850),
]

@export var terrain_path := NodePath("../Terrain3D")
@export var player_path := NodePath("../Player")
@export var enemy_count := 48

var generated_npc_count := 0
var generated_enemy_count := 0
var generated_boss_count := 0
var generated_forge_count := 0
var campaign: RPGCampaign = null
var sidequests: RPGSideQuests = null
var kill_cam: KillCam = null
var prologue: RPGPrologue = null
var cinematic: RPGCinematic = null
## Lo que queda de la cámara lenta del remate antes de poder encadenar.
const KILL_CAM_TAIL := 1.35
## Lo que se espera a que acabe el cierre del quinto acto antes del epílogo.
const EPILOGUE_GAP := 15.0
const START_BELLS := Vector2(0.0, 190.0)
var last_ending := ""
var _companions: Dictionary = {}
var _camera_rig: Node = null
var _hazards: Dictionary = {}
var spark_burst_count := 0
var generated_companion_count := 0
var generated_arena_pieces := 0
var generated_approach_guards := 0
var generated_arena_lights := 0
## Memoria conversacional: cuántas veces has hablado con cada habitante y
## cuántos encargos le has resuelto. Es lo que permite que te reconozcan.
var _met: Dictionary = {}
var _helped: Dictionary = {}
var _act_just_closed := false
## Cómo te trata cada habitante, según cómo le hayas contestado.
var _regard: Dictionary = {}
## La conversación abierta: a quién y sobre qué, para poder aplicar la respuesta.
var _pending: Dictionary = {}
var _act_answered: Dictionary = {}
var _act_hinted: Dictionary = {}
var _vegetation: Node = null
var wonders: Node
var generated_gate_count := 0
var generated_cave_count := 0
var player_health := 100
var player_max_health := 100
var _terrain: Terrain3D
var _player: Player
var _inventory: Node
var _exploration: Node
var _awarded_chapters: Dictionary = {}
var _damage_cooldown := 0.0
var _indice_enemigos_red: Dictionary = {}


func _ready() -> void:
	_terrain = get_node(terrain_path) as Terrain3D
	add_to_group("rpg_story_runtime")
	_player = get_node(player_path) as Player
	_inventory = get_node_or_null("/root/InventoryManager")
	_exploration = get_node_or_null("/root/ExplorationManager")
	if _exploration != null:
		_exploration.connect("story_chapter_completed", Callable(self, "_on_story_chapter_completed"))
	call_deferred("_build_story_world")


func _process(delta: float) -> void:
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)


func _build_story_world() -> void:
	await get_tree().process_frame
	for spec in NPC_SPECS:
		_spawn_npc(spec)
	wonders = preload("res://scripts/forest_wonders.gd").new()
	wonders.name = "ForestWonders"
	add_child(wonders)
	for spec in GATE_SPECS:
		_spawn_gate_and_cave(spec)
	_terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	_terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	wonders.finish_caves()
	_populate_bestiary()
	_build_campaign()
	_build_sidequests()
	_build_kill_cam()
	_build_cinematic()
	_build_prologue()
	print("RPG STORY READY: %d habitantes, %d monstruos, %d jefes de acto, %d herrerías, %d grutas, %d puertas con llave y %d piezas de arena con %d braseros y %d centinelas en las cuestas." % [
		generated_npc_count, generated_enemy_count, generated_boss_count,
		generated_forge_count, generated_cave_count, generated_gate_count,
		generated_arena_pieces, generated_arena_lights, generated_approach_guards,
	])


func _spawn_npc(spec: Dictionary) -> void:
	var npc := RPGNPC.new()
	npc.name = "NPC_%s" % String(spec.id)
	npc.npc_id = String(spec.id)
	npc.display_name = String(spec.name)
	npc.role = String(spec.role)
	npc.character_file = String(spec.file)
	npc.story_runtime = self
	add_child(npc)
	npc.global_position = _grounded_position(spec.point, 0.08)
	npc.rotation.y = float(generated_npc_count % 7) * 0.71
	generated_npc_count += 1


func _spawn_gate_and_cave(spec: Dictionary) -> void:
	wonders.create_cave(spec, generated_cave_count)
	generated_gate_count += 1
	generated_cave_count += 1


func _populate_bestiary() -> void:
	## Los enemigos ya no nacen en doce puntos fijos perdidos: se reparten por
	## las diez rutas de la isla —que es por donde se pasa de verdad— y se
	## agrupan en guaridas dentro de los bosques. Medido sobre el reparto
	## anterior: los 48 quedaban a más de 300 m del héroe y ninguno junto a un
	## camino, así que nunca te cruzabas con uno.
	var index := 0
	for patrol in RPGBestiary.patrol_points(VegetationScatter.ROAD_NETWORK, 150.0, 11.0):
		var point: Vector2 = patrol["point"]
		_spawn_creature(point, int(patrol["seed"]), index)
		index += 1
	for lair in RPGBestiary.LAIRS:
		var centre: Vector2 = lair["point"]
		var radius := float(lair["radius"])
		for member in int(lair["count"]):
			var angle := TAU * float(member) / float(maxi(int(lair["count"]), 1))
			var spot := centre + Vector2(cos(angle), sin(angle)) * radius
			_spawn_creature(spot, index * 3 + member, index, "",
				String(lair.get("species", "")))
			index += 1
	for garrison in RPGBestiary.GARRISONS:
		var keep: Vector2 = garrison["point"]
		var ring := float(garrison["radius"])
		for post in int(garrison["count"]):
			var turn := TAU * float(post) / float(maxi(int(garrison["count"]), 1))
			# El sorteo va con `post * 3 + 1`, no con `index + post`: como el
			# índice también sube en cada vuelta, `index + post` avanzaba de dos
			# en dos y caía SIEMPRE en la misma especie. Resultado medido: 18
			# guardias y CERO capitanes, con un encargo que pedía cuatro.
			_spawn_creature(keep + Vector2(cos(turn), sin(turn)) * ring, post * 3 + 1, index, "castle")
			index += 1
	for arena in RPGBestiary.ARENAS:
		_build_arena(arena)
	for boss in RPGBestiary.BOSSES:
		_spawn_boss(boss)
	for forge in FORGE_SPECS:
		_spawn_forge(forge)


func _spawn_creature(point: Vector2, pick: int, index: int, forced_biome: String = "",
		forced_species: String = "") -> void:
	var tier := RPGBestiary.tier_for(point)
	var biome := forced_biome if not forced_biome.is_empty() else _biome_at(point)
	var species := RPGBestiary.species_for(tier, biome, pick)
	if not forced_species.is_empty():
		# Una guarida puede dictar su especie: es lo que permite que un encargo
		# se cumpla donde su texto dice, sin tocar el reparto general.
		var named := RPGBestiary.species_by_id(forced_species)
		if not named.is_empty():
			species = named
	var enemy := RPGEnemy.new()
	enemy.name = "Enemy_%03d" % index
	enemy.enemy_id = "%s_%03d" % [String(species["id"]), index]
	enemy.display_name = String(species["name"])
	enemy.monster_path = RPGBestiary.MONSTER_ROOT + String(species["model"])
	enemy.max_health = int(species["health"])
	enemy.health = enemy.max_health
	enemy.attack_damage = int(species["damage"])
	enemy.move_speed = float(species["speed"])
	enemy.reward_item_id = String(species["reward"])
	enemy.reward_amount = int(species["amount"])
	enemy.style = RPGBestiary.style_for(biome)
	enemy.story_runtime = self
	add_child(enemy)
	enemy.scale = Vector3.ONE * float(species.get("scale", 1.0))
	enemy.global_position = _grounded_position(point, 0.08)
	generated_enemy_count += 1


func _build_arena(spec: Dictionary) -> void:
	## La arena se levanta ANTES que el jefe, para que el jefe caiga sobre su
	## losa y no debajo de un monolito.
	var arena := RPGBossArena.new()
	arena.name = "Arena_%s" % String(spec["id"])
	add_child(arena)
	arena.build(_terrain, spec)
	generated_arena_pieces += int(arena.get_meta("arena_pieces", 0))
	generated_arena_lights += int(arena.get_meta("arena_lights", 0))
	_guard_approach(spec, float(arena.get_meta("approach_bearing", 0.0)))
	_raise_hazard(spec, arena)


## El peligro propio del sitio. Nace apagado: se enciende solo cuando el jefe
## de esa arena está despierto, para que cruzarla antes de tiempo no castigue.
func _raise_hazard(spec: Dictionary, arena: Node) -> void:
	var hazard := RPGArenaHazard.new()
	hazard.name = "Peligro_%s" % String(spec["id"])
	hazard.style = String(spec["style"])
	hazard.centre = spec["centre"]
	hazard.radius = float(spec.get("radius", 18.0))
	hazard.floor_radius = float(spec.get("floor_radius", 13.0))
	hazard.shelters = arena.get_meta("shelter_points", PackedVector2Array())
	hazard.arena = arena
	hazard.story_runtime = self
	add_child(hazard)
	hazard.global_position = _grounded_position(hazard.centre, 1.4)
	_hazards[String(spec["id"])] = hazard


## La única cuesta subible es también por donde te esperan. Sin esto llegar al
## jefe es andar mucho, que no es lo mismo que costar.
func _guard_approach(spec: Dictionary, bearing: float) -> void:
	var centre: Vector2 = spec["centre"]
	var direction := Vector2.RIGHT.rotated(bearing)
	var across := Vector2(-direction.y, direction.x)
	var post := 0
	for span in PackedFloat32Array([58.0, 96.0, 134.0, 172.0]):
		var side := 1.0 if post % 2 == 0 else -1.0
		_spawn_creature(centre + direction * span + across * side * 7.0,
			hash(String(spec["id"])) + post * 3 + 1, generated_enemy_count)
		generated_approach_guards += 1
		post += 1


func _spawn_boss(spec: Dictionary) -> void:
	var boss := RPGBoss.new()
	if _hazards.has(String(spec["id"])):
		_hazards[String(spec["id"])].boss = boss
		boss.hazard = _hazards[String(spec["id"])]
	boss.name = "Boss_%s" % String(spec["id"])
	boss.enemy_id = String(spec["id"])
	boss.display_name = String(spec["name"])
	boss.monster_path = RPGBestiary.MONSTER_ROOT + String(spec["model"])
	boss.max_health = int(spec["health"])
	boss.health = boss.max_health
	boss.attack_damage = int(spec["damage"])
	boss.strike_damage = int(spec["damage"])
	boss.move_speed = float(spec["speed"])
	boss.reward_item_id = String(spec["reward"])
	boss.reward_amount = int(spec["amount"])
	boss.demand = int(spec.get("demand", RPGBoss.Demand.GUARD))
	boss.act_title = String(spec.get("act", "Acto"))
	boss.detection_radius = 34.0
	boss.sleep_radius = 190.0
	boss.story_runtime = self
	add_child(boss)
	boss.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	var point: Vector2 = spec["point"]
	boss.global_position = _grounded_position(point, 0.08)
	generated_boss_count += 1


func _build_campaign() -> void:
	campaign = RPGCampaign.new()
	campaign.name = "Campaign"
	add_child(campaign)
	campaign.act_completed.connect(_announce_act_end)
	campaign.campaign_finished.connect(_roll_epilogue)
	_refresh_seals()
	campaign.act_started.connect(func(_a: Dictionary) -> void: _refresh_hud_bar())
	campaign.act_completed.connect(func(_a: Dictionary, _r: String) -> void: _refresh_hud_bar())
	# El primer acto NO abre un cuadro de diálogo. El panel de historia pausa el
	# árbol, y anunciarlo en el arranque dejaba la partida congelada en el primer
	# fotograma: nada se movía y los tweens del mundo —la caída de un árbol
	# talado, por ejemplo— no llegaban a correr nunca. El acto se lee en la barra
	# superior, y el encargo completo se recibe al hablar con quien lo da, que es
	# además como debe presentarse una misión.
	campaign.begin()
	campaign.act_started.connect(_announce_act)


func _build_sidequests() -> void:
	sidequests = RPGSideQuests.new()
	sidequests.name = "SideQuests"
	add_child(sidequests)
	sidequests.bind(_inventory, _player)
	sidequests.quest_completed.connect(func(_q: Dictionary) -> void: _refresh_hud_bar())
	sidequests.quest_offered.connect(func(_q: Dictionary) -> void: _refresh_hud_bar())
	_refresh_hud_bar()


## Quién puede acompañarte, cómo pelea y con qué cara. Sólo se une quien ya te
## aprecia Y a quien le has resuelto todo lo suyo: la compañía se gana, no se
## compra ni se desbloquea por llegar a un sitio.
const COMPANIONS := {
	"brenn": {"name": "Brenn", "craft": 0, "file": "Cowboy_Male.gltf",
		"health": 52, "damage": 8, "ask": "«Llevo veinte años mirando ese bosque desde arriba. Quiero verlo de cerca contigo.»"},
	"calen": {"name": "Calen", "craft": 1, "file": "Knight_Male.gltf",
		"health": 86, "damage": 9, "ask": "«Raspé cinco nombres. Déjame estar delante cuando los recuperes.»"},
	"tavia": {"name": "Tavia", "craft": 2, "file": "Viking_Female.gltf",
		"health": 44, "damage": 4, "ask": "«No sé pelear. Sé cerrar heridas, y vas a necesitar eso más.»"},
	"orin": {"name": "Orin", "craft": 3, "file": "Viking_Male.gltf",
		"health": 74, "damage": 11, "ask": "«El martillo pesa lo mismo en la fragua que en el camino. Vamos.»"},
}
const RECRUIT_REGARD := 1


func can_recruit(npc_id: String) -> bool:
	if not COMPANIONS.has(npc_id) or _companions.has(npc_id):
		return false
	if int(_regard.get(npc_id, 0)) < RECRUIT_REGARD:
		return false
	if sidequests == null:
		return false
	return sidequests.pending_for(npc_id).is_empty()


func recruit(npc_id: String) -> void:
	if not can_recruit(npc_id):
		return
	_raise_companion(npc_id)


## Al cargar partida el aliado ya está ganado: volver a pasar por `can_recruit`
## lo perdería si los encargos aún no se han restaurado en este mismo cargado.
func _raise_companion(npc_id: String) -> void:
	if not COMPANIONS.has(npc_id) or _companions.has(npc_id):
		return
	var spec: Dictionary = COMPANIONS[npc_id]
	var mate := RPGCompanion.new()
	mate.name = "Companion_%s" % npc_id
	mate.companion_id = npc_id
	mate.display_name = String(spec["name"])
	mate.craft = int(spec["craft"])
	mate.character_file = String(spec["file"])
	mate.max_health = int(spec["health"])
	mate.health = mate.max_health
	mate.attack_damage = int(spec["damage"])
	mate.story_runtime = self
	add_child(mate)
	if _player != null:
		var behind := _player.global_position - _player.global_basis.z * -3.0
		mate.global_position = _grounded_position(Vector2(behind.x, behind.z), 0.1)
	_companions[npc_id] = true
	generated_companion_count += 1
	if _player != null:
		_player.action_feedback.emit("%s se une a ti" % String(spec["name"]))


## Sólo acuden si hay pelea de verdad. Es la regla que los hace aliados y no
## mascotas: no puedes pasearte con una escolta, los llamas cuando te ahogas.
const CALL_FIGHT_RADIUS := 52.0
const CALL_MAX_ALLIES := 2


func companion_roster() -> Array:
	var roster: Array = []
	for node in get_children():
		if node is RPGCompanion:
			roster.append(node)
	return roster


func fight_underway() -> bool:
	if _player == null:
		return false
	var here := _player.global_position
	for node in get_tree().get_nodes_in_group("rpg_enemy"):
		var foe := node as Node3D
		if foe == null or bool(foe.get("dead")):
			continue
		if here.distance_to(foe.global_position) <= CALL_FIGHT_RADIUS:
			return true
	for node in get_tree().get_nodes_in_group("rpg_boss"):
		var boss := node as Node3D
		if boss == null or bool(boss.get("dead")) or bool(boss.get("sealed")):
			continue
		if here.distance_to(boss.global_position) <= CALL_FIGHT_RADIUS * 1.6:
			return true
	return false


## Devuelve el aviso que enseñar. Cadena vacía sólo si no hay nada que decir.
func call_companions() -> String:
	var roster := companion_roster()
	if roster.is_empty():
		return "Nadie te debe nada todavía · gánate a alguien primero"
	var here: Array = []
	for mate in roster:
		if mate.is_here():
			here.append(mate.display_name)
	if not fight_underway():
		if here.is_empty():
			return "Sólo acuden si hay pelea cerca"
		return "%s ya está contigo" % ", ".join(here)
	var called: Array = []
	for mate in roster:
		if called.size() >= CALL_MAX_ALLIES:
			break
		if mate.summon(_player):
			called.append(mate.display_name)
	if not called.is_empty():
		return "%s cruza el horizonte" % ", ".join(called) if called.size() == 1 \
			else "%s cruzan el horizonte" % ", ".join(called)
	if not here.is_empty():
		return "%s ya pelea contigo" % ", ".join(here)
	var soonest := 999.0
	var who := ""
	for mate in roster:
		if mate.downed:
			continue
		if mate.cooldown_left() < soonest:
			soonest = mate.cooldown_left()
			who = mate.display_name
	if who == "":
		return "Los tuyos están tumbados · esta es tuya"
	return "%s tarda %d s en poder volver" % [who, int(ceil(soonest))]


func _witness_state() -> Dictionary:
	var out: Dictionary = {}
	for mate in companion_roster():
		out[String(mate.companion_id)] = Array(mate.witnessed)
	return out


func heal_player(amount: int, source: String) -> void:
	## Lo llama el compañero curandero. La cura no puede pasar del máximo, que
	## sube con la historia.
	if amount <= 0 or player_health >= player_max_health:
		return
	player_health = mini(player_max_health, player_health + amount)
	player_health_changed.emit(player_health, player_max_health)
	if _player != null:
		_player.action_feedback.emit("%s te cierra las heridas · %d/%d" % [
			source, player_health, player_max_health])


func _build_cinematic() -> void:
	cinematic = RPGCinematic.new()
	cinematic.name = "Cinematic"
	add_child(cinematic)


func _build_prologue() -> void:
	## La apertura sólo se pone cuando la partida está sin empezar: quien carga
	## una partida a medias ya sabe de qué va y volver a contárselo es un peaje.
	prologue = RPGPrologue.new()
	prologue.name = "Prologue"
	add_child(prologue)
	if campaign != null and int((campaign.progress() as Dictionary)["relics"]) > 0:
		return
	if prologue.should_play():
		prologue.play()


func _build_kill_cam() -> void:
	kill_cam = KillCam.new()
	kill_cam.name = "KillCam"
	add_child(kill_cam)


func _refresh_hud_bar() -> void:
	var hud := get_tree().root.find_child("HUD", true, false)
	if hud != null and hud.has_method("refresh_campaign_bar"):
		hud.call("refresh_campaign_bar")


func _spawn_forge(spec: Dictionary) -> void:
	var anvil := RPGAnvil.new()
	anvil.name = "Forge_%d" % generated_forge_count
	anvil.smith_name = String(spec["name"])
	add_child(anvil)
	anvil.global_position = _grounded_position(spec["point"], 0.0)
	generated_forge_count += 1


func _biome_at(point: Vector2) -> String:
	if _vegetation == null:
		var world := get_parent()
		if world != null:
			_vegetation = world.get_node_or_null("VegetationScatter")
	if _vegetation != null and _vegetation.has_method("biome_at"):
		return String(_vegetation.call("biome_at", Vector3(point.x, 0.0, point.y)))
	return ""


func _enemy_name(index: int) -> String:
	var names := ["Espina del Silencio", "Guardián de raíz", "Orco olvidado", "Demonio de bruma", "Yeti sin nombre", "Rey Fúngico de las Dunas", "Espectro del Eco", "Dragón menor", "Calavera errante", "Vaelorita"]
	return String(names[index % names.size()])


func begin_npc_dialogue(npc: RPGNPC, player: Node) -> void:
	## Hablar con alguien hace cuatro cosas, en este orden: SALUDARTE según el
	## trato que tengáis, cobrar el encargo cumplido, ofrecer el siguiente o
	## contar por dónde va la historia, y despedirse con una frase pegada al
	## momento. Antes sólo hacía la tercera, y siempre igual.
	var identity := npc.get_story_identity()
	var npc_id := String(identity.id)
	_met[npc_id] = int(_met.get(npc_id, 0)) + 1
	var met := int(_met[npc_id]) - 1
	var helped := int(_helped.get(npc_id, 0))
	var hello := RPGDialogue.greeting(npc_id, met, helped)
	var closing := RPGDialogue.aside(
		npc_id, _time_of_day(), _is_wounded(), _act_just_closed)

	if sidequests != null:
		var quest := sidequests.pending_for(npc_id)
		if not quest.is_empty():
			if sidequests.is_taken(quest):
				if sidequests.try_deliver(quest):
					_helped[npc_id] = helped + 1
					_speak(identity, "%s · cumplido" % String(quest["title"]), _weave([
						hello,
						"«Lo has hecho.» %s" % _thanks(npc_id),
						"Recompensa: [b]%s[/b]." % _reward_line(quest["reward"]),
						closing,
					]))
					return
				# Aceptado y sin terminar: no te repite la historia entera, te
				# recuerda lo que falta y dónde buscarlo. Nadie cuenta dos veces
				# lo mismo con las mismas palabras.
				_speak(identity, String(quest["title"]), _weave([
					hello,
					sidequests.reminder_for(quest),
					RPGDialogue.directions(npc_id, String(quest.get("where", "")),
						_bearing_to_quest(quest)),
					closing,
				]))
				return
			# El encargo NO se acepta aún: primero contestas, y lo que contestes
			# cambia cuánto piden, cuánto pagan y si te dicen dónde buscar.
			_pending = {"kind": "encargo", "npc": npc_id, "quest_id": String(quest["id"])}
			dialogue_with_choices.emit(
				String(identity.name), String(identity.role),
				"Encargo · %s" % String(quest["title"]),
				_weave([hello, String(quest["brief"]), closing,
					"[i]Elige cómo responder.[/i]"]),
				RPGDialogue.replies(npc_id))
			return
	if can_recruit(npc_id):
		_pending = {"kind": "reclutar", "npc": npc_id}
		var spec: Dictionary = COMPANIONS[npc_id]
		dialogue_with_choices.emit(
			String(identity.name), String(identity.role),
			"%s quiere acompañarte" % String(spec["name"]),
			_weave([hello, String(spec["ask"]), closing]),
			[
				{"tone": "acepta", "line": "«Vente. Me hará falta.»", "effect": {"recruit": true}},
				{"tone": "rechaza", "line": "«Quédate. Aquí haces más falta que conmigo.»",
					"effect": {"recruit": false, "regard": 0}},
			])
		return
	_tell_campaign(npc, identity, player, hello, closing)


func answer_dialogue(choice: Dictionary) -> void:
	## Lo que contestas tiene precio. Un tono altivo sube lo que te piden y lo
	## que te pagan, y te deja sin la pista: es la única consecuencia que de
	## verdad se nota con el arma en la mano.
	if _pending.is_empty():
		return
	var effect: Dictionary = choice.get("effect", {})
	var npc_id := String(_pending.get("npc", ""))
	_regard[npc_id] = int(_regard.get(npc_id, 0)) + int(effect.get("regard", 0))
	var told := bool(effect.get("hint", true))
	match String(_pending.get("kind", "")):
		"encargo":
			var quest := sidequests.quest_by_id(String(_pending["quest_id"]))
			if not quest.is_empty():
				sidequests.take_with_terms(quest,
					int(effect.get("needed", 0)), float(effect.get("reward", 1.0)), told)
				if _player != null:
					_player.action_feedback.emit(
						"%s · %s" % [String(quest["title"]), sidequests.terms_line(quest)])
		"reclutar":
			if bool(effect.get("recruit", false)):
				recruit(npc_id)
			elif _player != null:
				_player.action_feedback.emit("%s se queda" % _npc_name(npc_id))
		"acto":
			_act_answered[String(_pending["act_id"])] = true
			_act_hinted[String(_pending["act_id"])] = told
			if _player != null:
				_player.action_feedback.emit(
					"Acto aceptado" if told else "Acto aceptado · sin pista del jefe")
	_pending = {}
	_refresh_hud_bar()


func _weave(parts: Array) -> String:
	var kept := PackedStringArray()
	for part in parts:
		var line := String(part).strip_edges()
		if not line.is_empty():
			kept.append(line)
	return "\n\n".join(kept)


func _speak(identity: Dictionary, title: String, body: String) -> void:
	dialogue_requested.emit(
		String(identity.name), String(identity.role), title, body)


func _thanks(npc_id: String) -> String:
	match npc_id:
		"brenn":
			return "No añade nada más, pero tarda en soltarte la mano."
		"ysra":
			return "«Lo apunto como resuelto. Es la casilla que menos uso.»"
		"orin":
			return "«Ya era hora de que alguien sirviera para algo.»"
		"nara":
			return "«El oasis te lo devolverá cuando lo necesites.»"
		"maela":
			return "«Voy a tener que ampliar la leyenda del mapa por tu culpa.»"
		"calen":
			return "«Que conste que lo has hecho tú, no la guardia.»"
		_:
			return "«Se agradece, y no lo digo por decir.»"


func _time_of_day() -> String:
	var world := get_parent()
	if world == null:
		return "Día"
	return String(world.get("time_of_day"))


func _is_wounded() -> bool:
	return float(player_health) / float(maxi(player_max_health, 1)) < 0.55


func _bearing_to_quest(quest: Dictionary) -> String:
	if _player == null or int(quest["kind"]) != RPGSideQuests.Kind.HUNT:
		return ""
	var target := String(quest["target"])
	var best := INF
	var spot := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("rpg_enemy"):
		var creature := node as Node3D
		if creature == null or bool(creature.get("dead")):
			continue
		if not String(creature.get("enemy_id")).begins_with(target):
			continue
		var here := Vector2(creature.global_position.x, creature.global_position.z)
		var distance := here.distance_to(
			Vector2(_player.global_position.x, _player.global_position.z))
		if distance < best:
			best = distance
			spot = here
	if best == INF:
		return ""
	return bearing_line(spot)


func bearing_line(spot: Vector2) -> String:
	## Rumbo y distancia desde donde está el héroe. El norte del mundo es -Z.
	if _player == null:
		return ""
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var delta := spot - here
	var distance := delta.length()
	if distance < 2.0:
		return "está aquí mismo"
	var compass := PackedStringArray(["norte", "noreste", "este", "sureste",
		"sur", "suroeste", "oeste", "noroeste"])
	var facing: String = compass[
		int(round(posmod(rad_to_deg(atan2(delta.x, -delta.y)), 360.0) / 45.0)) % 8]
	if distance >= 1000.0:
		return "al %s, a kilómetro y pico" % facing if distance < 2000.0 \
			else "al %s, a %.1f km" % [facing, distance / 1000.0]
	return "al %s, a unos %d pasos" % [facing, roundi(distance * 1.35)]


func _reward_line(reward: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item in reward:
		parts.append("%d x %s" % [int(reward[item]), String(item)])
	return " + ".join(parts)


func _tell_campaign(npc: RPGNPC, identity: Dictionary, player: Node, hello: String, closing: String) -> void:
	var npc_id := String(identity.id)
	# Con varios caminos abiertos, cada uno habla del SUYO. Antes todos contaban
	# el mismo "acto activo" y Ysra te hablaba de la bruma de Brenn.
	var act: Dictionary = _act_of_giver(npc_id)
	if act.is_empty() and campaign != null:
		act = campaign.active_act()
	if act.is_empty():
		_speak(identity, "Aeloria vuelve a sonar", _weave([
			hello, "«Ya nadie tiene que esconder su nombre. Ni tú.»", closing]))
		return
	# Quien da el acto lo cuenta entero; los demás te orientan hacia quien lo da.
	if npc_id == String(act["giver"]):
		if not bool(_act_answered.get(String(act["id"]), false)):
			# La primera vez que te lo cuenta, contestas. Y si contestas alto,
			# no te dirá el punto débil del jefe.
			_pending = {"kind": "acto", "npc": npc_id, "act_id": String(act["id"])}
			dialogue_with_choices.emit(
				String(identity.name), String(identity.role),
				"Acto %s · %s" % [String(act["numeral"]), String(act["title"])],
				_weave([hello, String(act["opening"]),
					"Tu siguiente paso es [b]%s[/b]" % String(act["goal"]),
					closing, "[i]Elige cómo responder.[/i]"]),
				RPGDialogue.replies(npc_id))
			return
		var told := bool(_act_hinted.get(String(act["id"]), true))
		_speak(identity,
			"Acto %s · %s" % [String(act["numeral"]), String(act["title"])],
			_weave([
				hello,
				String(act["opening"]),
				"Tu siguiente paso es [b]%s[/b]" % String(act["goal"]),
				RPGDialogue.directions(npc_id, "Es %s" % bearing_line(RPGCampaign.where_of(act)), ""),
				"[i]%s[/i]" % String(act["hint"]) if told
					else "[i]No te dijo cómo se le hace daño. Tendrás que verlo tú.[/i]",
				RPGDialogue.regard_line(int(_regard.get(npc_id, 0))),
				closing,
			]))
	else:
		_speak(identity, "Lo que se cuenta", _weave([
			hello,
			_points_to(npc_id, String(act["giver"])),
			"[i]%s[/i]" % String(act["goal"]),
			closing,
		]))
	if player != null and player.has_signal("action_feedback"):
		player.emit_signal("action_feedback", "%s te orienta" % String(identity.name))


func _act_of_giver(npc_id: String) -> Dictionary:
	if campaign == null:
		return {}
	for raw in (campaign.open_acts() as Array):
		var act: Dictionary = raw
		if String(act["giver"]) == npc_id:
			return act
	return {}


func _points_to(npc_id: String, giver_id: String) -> String:
	## Un habitante que no lleva el acto no se calla: te manda con quien sí.
	## Es lo que evita que el resto del mundo sea decorado que repite una frase.
	var who := _npc_name(giver_id)
	var place := _npc_place(giver_id)
	match npc_id:
		"maela":
			return "«Eso no es cosa mía, es de %s. %s.» Marca el punto en el mapa con la uña." % [who, place]
		"orin":
			return "«A mí me traen hierro, no preguntas. Habla con %s. %s.»" % [who, place]
		"brenn":
			return "«%s sabe de eso.» Señala. «%s.»" % [who, place]
		"ysra":
			return "«No es mi campo. %s lleva la cuenta de eso. %s.»" % [who, place]
		"nara":
			return "«Esa historia la guarda %s. %s. Ve con agua.»" % [who, place]
		"calen":
			return "«Preséntate a %s de mi parte. %s.»" % [who, place]
		"tavia":
			return "«Eso pregúntaselo a %s. %s.»" % [who, place]
		_:
			return "«Pregunta a %s. %s.»" % [who, place]


## La crónica: qué llevas hecho, quién te acompaña y qué piensa de ti la isla.
## Se compone aquí y no en el HUD porque todos los datos viven aquí; el HUD
## sólo la pinta.
func chronicle() -> String:
	var lines := PackedStringArray()
	lines.append("[color=#f0d089][b]HISTORIA[/b][/color]")
	var closed := 0
	for act in RPGCampaign.ACTS:
		var act_id := String(act["id"])
		var head := "%s · %s" % [String(act["numeral"]), String(act["title"])]
		if campaign != null and campaign.is_done(act_id):
			closed += 1
			lines.append("  [color=#9ed69a]✓[/color] %s — %s" % [head, String(act["relic"])])
		elif campaign != null and campaign.is_open(act):
			lines.append("  [color=#e8c46a]○[/color] %s — abierto" % head)
		else:
			lines.append("  [color=#6b6b72]·[/color] %s — sellado" % head)
	lines.append("  [color=#b9b2a2]Nombres recuperados: %d de 5[/color]" % closed)

	lines.append("")
	lines.append("[color=#f0d089][b]ENCARGOS[/b][/color]")
	if sidequests != null:
		var done_count: int = sidequests.completed_count()
		lines.append("  [color=#b9b2a2]%d de %d cumplidos[/color]" % [
			done_count, RPGSideQuests.QUESTS.size()])
		var listed := 0
		for quest in RPGSideQuests.QUESTS:
			if bool(sidequests.is_done(quest)):
				lines.append("  [color=#9ed69a]✓[/color] %s — %s" % [
					String(quest["title"]), _npc_name(String(quest["giver"]))])
				listed += 1
		if listed == 0:
			lines.append("  [color=#6b6b72]Todavía no has cerrado ninguno.[/color]")

	lines.append("")
	lines.append("[color=#f0d089][b]QUIENES TE ACOMPAÑAN[/b][/color]")
	var roster := companion_roster()
	if roster.is_empty():
		lines.append("  [color=#6b6b72]Nadie, todavía. La compañía se gana hablando y resolviendo lo suyo.[/color]")
	for mate in roster:
		var fought: int = mate.witnessed.size()
		var tail := "%d acto%s a tu lado" % [fought, "" if fought == 1 else "s"]
		if fought == 0:
			tail = "aún no ha peleado contigo"
		lines.append("  [color=#8fb6d8]◆[/color] %s — %s" % [String(mate.display_name), tail])

	lines.append("")
	lines.append("[color=#f0d089][b]LA ISLA Y TÚ[/b][/color]")
	var warm := PackedStringArray()
	var cold := PackedStringArray()
	for who in _regard:
		var value := int(_regard[who])
		if value > 0:
			warm.append(_npc_name(String(who)))
		elif value < 0:
			cold.append(_npc_name(String(who)))
	if warm.is_empty() and cold.is_empty():
		lines.append("  [color=#6b6b72]Nadie se ha hecho una idea de ti todavía.[/color]")
	if not warm.is_empty():
		lines.append("  [color=#9ed69a]Te aprecian:[/color] %s" % ", ".join(warm))
	if not cold.is_empty():
		lines.append("  [color=#d08a80]Te tienen por altivo:[/color] %s" % ", ".join(cold))
	if not last_ending.is_empty():
		lines.append("")
		lines.append("[color=#f0d089][b]CÓMO ACABÓ[/b][/color]")
		for ending in RPGCampaign.ENDINGS:
			if String(ending["id"]) == last_ending:
				lines.append("  %s" % String(ending["title"]))
				break
	if wonders != null: lines.append(wonders.chronicle())
	return "\n".join(lines)


func _npc_name(npc_id: String) -> String:
	for spec in NPC_SPECS:
		if String(spec["id"]) == npc_id:
			return String(spec["name"])
	return "alguien de la villa"


func _npc_place(npc_id: String) -> String:
	for spec in NPC_SPECS:
		if String(spec["id"]) == npc_id:
			# Sin pronombre: los habitantes son de los dos géneros y "lo tienes"
			# chirriaba con la mitad de ellos.
			return "Está %s" % bearing_line(spec["point"])
	return "Anda por la isla"


func _advance_campaign(boss: RPGBoss) -> void:
	if campaign == null:
		return
	if not campaign.on_boss_defeated(boss.enemy_id, _inventory):
		return
	_refresh_seals()


func _refresh_seals() -> void:
	## El sello se recalcula entero en vez de abrirse uno a uno: así el estado de
	## los cinco jefes sale siempre de la campaña y no de una secuencia de avisos
	## que pudiera perderse.
	for child in get_children():
		if child is RPGBoss:
			(child as RPGBoss).set_sealed(
				not campaign.is_boss_unlocked((child as RPGBoss).enemy_id))


func _announce_act(act: Dictionary) -> void:
	if act.is_empty() or _player == null:
		return
	_player.action_feedback.emit("Acto %s · %s" % [String(act["numeral"]), String(act["title"])])
	dialogue_requested.emit(
		String(act["title"]),
		String(act["region"]),
		"Acto %s · %s" % [String(act["numeral"]), String(act["title"])],
		"%s\n\n[b]%s[/b]\n\n%s\n\n[i]%s[/i]" % [
			String(act["opening"]), String(act["goal"]),
			"Te enseñará: %s." % String(act["teaches"]), String(act["hint"])]
	)


## Lo que crece el héroe al cerrar un acto y al subir un grado en la forja.
const ACT_HEALTH_BONUS := 25
const ACT_STAMINA_BONUS := 18
const FORGE_HEALTH_BONUS := 6
const FORGE_STAMINA_BONUS := 5


func grow_hero(health_bonus: int, stamina_bonus: int, reason: String) -> void:
	## La vida y el vigor máximos no son constantes: suben con la historia y con
	## el equipo. Sin esto, el acto V se peleaba con el mismo aguante que el I y
	## los jefes acababan siendo un muro en vez de una escalada.
	player_max_health += health_bonus
	player_health = mini(player_max_health, player_health + health_bonus)
	player_health_changed.emit(player_health, player_max_health)
	if _player != null and _player.has_method("grow_vitals"):
		_player.call("grow_vitals", health_bonus, stamina_bonus)
		_player.action_feedback.emit("%s · vida máxima %d · vigor máximo %d" % [
			reason, player_max_health, roundi(float(_player.get("stamina_max")))])


func _announce_act_end(act: Dictionary, relic: String) -> void:
	grow_hero(ACT_HEALTH_BONUS, ACT_STAMINA_BONUS, "Reliquia %s" % relic)
	# Durante un rato, todo el mundo comenta lo que acabas de hacer.
	_act_just_closed = true
	get_tree().create_timer(300.0).timeout.connect(
		func() -> void: _act_just_closed = false)
	if _player == null:
		return
	_player.action_feedback.emit("Reliquia obtenida · %s" % relic)
	# La cámara lenta del golpe final está corriendo. Encadenar sin esperarla
	# pisaría la cinemática con la del remate.
	var wait := 0.0
	if kill_cam != null and bool(kill_cam.get("running")):
		wait = KILL_CAM_TAIL
	if wait > 0.0:
		get_tree().create_timer(wait).timeout.connect(
			func() -> void: _roll_act_cinematic(act, relic))
	else:
		_roll_act_cinematic(act, relic)


## El cierre de acto en bandas negras, con la cámara orbitando el sitio donde
## acaba de caer el jefe, en vez de un párrafo que congela el mundo.
func _roll_act_cinematic(act: Dictionary, relic: String) -> void:
	var focus := RPGCampaign.where_of(act)
	var spot := _grounded_position(focus, 2.4)
	if cinematic == null or cinematic.running:
		dialogue_requested.emit(
			String(act["title"]), "Acto cerrado", "%s · conseguida" % relic,
			"%s\n\n[b]%s[/b] pasa a tu zurrón." % [String(act["closing"]), relic])
		return
	var cards: Array = []
	for piece in _split_prose(String(act["closing"]), 2):
		cards.append({"text": piece, "hold": 3.2 + piece.length() * 0.014})
	# Quien estuvo en la pelea tiene una línea. Un aliado que peleó el acto y no
	# dice nada al cerrarse no es un personaje, es una torreta con nombre.
	for mate in companion_roster():
		var seen := String(mate.call("witness", String(act["id"]), relic))
		if not seen.is_empty():
			cards.append({"text": seen, "hold": 3.6})
	cards.append({"text": "[b]%s[/b]\n\nEl nombre vuelve. La campana ya sabe cómo se llama." % relic,
		"hold": 4.2})
	# El radio sale del tamaño del jefe del acto: los cinco van de escala 3,0 a
	# 5,0 y con un encuadre único la mitad no cabían.
	var bulk := 3.0
	for boss in RPGBestiary.BOSSES:
		if String(boss["id"]) == String(act.get("boss", "")):
			bulk = float(boss.get("scale", 3.0))
			break
	cinematic.play(cards, spot, _player, 13.0 + bulk * 7.0)


## Cómo te ha tratado la isla según cómo la trataste tú. Se encadena detrás del
## cierre del quinto acto, no encima: dos cinemáticas a la vez no se ven.
func _roll_epilogue() -> void:
	var closing := 0.0
	if cinematic != null and cinematic.running:
		closing = EPILOGUE_GAP
	if closing > 0.0:
		get_tree().create_timer(closing).timeout.connect(_show_epilogue)
	else:
		_show_epilogue()


func _show_epilogue() -> void:
	var ending := RPGCampaign.ending_for(
		regard_total(), sidequests.completed_count() if sidequests != null else 0,
		_companions.size(), witness_total())
	last_ending = String(ending["id"])
	if _player != null:
		_player.action_feedback.emit("Aeloria recupera su voz · %s" % String(ending["title"]))
	if cinematic == null:
		return
	var cards: Array = [{"text": "[b]%s[/b]" % String(ending["title"]), "hold": 3.4}]
	for line in ending["cards"]:
		cards.append({"text": String(line), "hold": 3.6 + String(line).length() * 0.013})
	var spot := _grounded_position(START_BELLS, 3.0)
	if _player != null:
		spot = _player.global_position
	cinematic.play(cards, spot, _player, 26.0)


func regard_total() -> int:
	var total := 0
	for who in _regard:
		total += int(_regard[who])
	return total


func witness_total() -> int:
	var total := 0
	for mate in companion_roster():
		total += mate.witnessed.size()
	return total


## Parte un párrafo en trozos por final de frase. Una tarjeta con seis frases
## no se lee: se salta.
func _split_prose(prose: String, pieces: int) -> PackedStringArray:
	var sentences := PackedStringArray()
	var current := ""
	for chunk in prose.split(" "):
		current += ("" if current.is_empty() else " ") + chunk
		if chunk.ends_with(".") or chunk.ends_with("»") or chunk.ends_with("!"):
			sentences.append(current)
			current = ""
	if not current.strip_edges().is_empty():
		sentences.append(current)
	if sentences.size() <= pieces:
		return sentences
	var out := PackedStringArray()
	var per := int(ceil(float(sentences.size()) / float(pieces)))
	var index := 0
	while index < sentences.size():
		var block := ""
		for step in per:
			if index + step >= sentences.size():
				break
			block += ("" if block.is_empty() else " ") + sentences[index + step]
		out.append(block)
		index += per
	return out


func on_enemy_defeated(enemy: RPGEnemy) -> void:
	if _inventory != null:
		_inventory.call("add_item", enemy.reward_item_id, enemy.reward_amount)
	if _player != null:
		_player.action_feedback.emit("%s derrotado · recompensa obtenida" % enemy.display_name)
	if sidequests != null:
		sidequests.on_enemy_defeated(enemy.enemy_id)
	if kill_cam != null:
		if enemy is RPGBoss:
			kill_cam.flourish(KillCam.Beat.FEAT, "%s ha caído" % enemy.display_name)
		else:
			kill_cam.flourish(KillCam.Beat.SKIRMISH)
	if enemy is RPGBoss:
		_advance_campaign(enemy as RPGBoss)


func on_gate_opened(gate: RPGCaveGate) -> void:
	if _player != null:
		_player.action_feedback.emit("La voz del interior de %s ya puede oírte" % gate.display_name)


## Punto único para sacudir la cámara. Lo llaman el enemigo, el jefe y el héroe:
## si cada uno buscara el nodo por su cuenta, media docena de rutas frágiles.
## Chispas. Un golpe que la coraza aguanta tiene que VERSE distinto del que
## entra, o el jugador no sabe si está resolviendo la mecánica o pegando en
## balde. Vive aquí y no en cada bicho: una sola implementación que se borra
## sola, en vez de una copia por script dejando nodos muertos en el árbol.
func burst_sparks(point: Vector3, colour: Color, count: int, force: float, life: float) -> void:
	var burst := GPUParticles3D.new()
	burst.amount = count
	burst.lifetime = life
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	# Sin `visibility_aabb` explícito el motor recorta el estallido y NO se ve
	# nada, aunque el nodo exista y esté emitiendo. Medido: chispas confirmadas
	# por sonda pero invisibles en pantalla hasta poner esta caja.
	burst.visibility_aabb = AABB(Vector3(-14, -14, -14), Vector3(28, 28, 28))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.35
	process.direction = Vector3.UP
	process.spread = 78.0
	process.initial_velocity_min = force * 0.5
	process.initial_velocity_max = force
	process.gravity = Vector3.DOWN * 15.0
	process.scale_min = 0.8
	process.scale_max = 2.1
	process.color = colour
	burst.process_material = process
	var mote := SphereMesh.new()
	# El tamaño sale de la fuerza: un rechazo (5,4) chispea fino y romper la
	# guardia (11,5) escupe brasas gordas. Con un tamaño fijo los dos momentos
	# se veían igual y no se distinguía si estabas resolviendo la mecánica.
	mote.radius = clampf(force * 0.019, 0.10, 0.28)
	mote.height = mote.radius * 2.0
	mote.radial_segments = 5
	mote.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = colour
	glow.emission_enabled = true
	glow.emission = colour
	glow.emission_energy_multiplier = 3.6
	mote.material = glow
	burst.draw_pass_1 = mote
	# Cuelga del runtime, no de `current_scene`: en las pruebas el mundo se añade
	# a la raíz a mano y `current_scene` es null, así que reventaba al primer golpe.
	add_child(burst)
	burst.global_position = point
	burst.emitting = true
	# Se borra solo: si se queda, cada golpe deja un nodo muerto en el árbol.
	get_tree().create_timer(life + 0.6).timeout.connect(burst.queue_free)
	spark_burst_count += 1




func shake_camera(point: Vector3, amount: float, reach: float) -> void:
	if _camera_rig == null:
		_camera_rig = get_tree().get_first_node_in_group("camera_rig")
		if _camera_rig == null:
			var world := get_parent()
			if world != null:
				_camera_rig = world.get_node_or_null("CameraRig")
		if _camera_rig == null:
			return
	_camera_rig.call("add_shake_from", point, amount, reach)


func damage_player(amount: int, source_position: Vector3, source_name: String) -> void:
	if _damage_cooldown > 0.0 or _player == null:
		return
	_damage_cooldown = 0.72
	# La guardia con escudo absorbe la mayor parte del golpe.
	var guarded := amount
	if _player != null and _player.has_method("get_damage_multiplier"):
		guarded = int(round(float(amount) * float(_player.call("get_damage_multiplier"))))
	player_health = maxi(0, player_health - maxi(1, guarded))
	# Cuanto más te quitan, más te mueve. Un arañazo no puede sacudir igual que
	# un mazazo del Coloso.
	shake_camera(_player.global_position, clampf(0.16 + guarded * 0.022, 0.16, 0.62), 90.0)
	var away := _player.global_position - source_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		_player.velocity += away.normalized() * 5.2 + Vector3.UP * 2.0
	if _player.has_method("react_to_hit"):
		_player.call("react_to_hit")
	_player.action_feedback.emit("%s te hiere · vida %d/%d" % [source_name, player_health, player_max_health])
	player_health_changed.emit(player_health, player_max_health)
	if player_health <= 0:
		_fall_and_wake_in_a_village()


## Dónde te recogen al caer. El héroe no vuelve al punto de partida de la isla:
## lo llevan a la villa más cercana, que es lo que hace que morir lejos duela.
const REFUGES: Array[Dictionary] = [
	{"name": "Puerto Alba", "point": Vector2(0.0, 190.0)},
	{"name": "Villa Robledal", "point": Vector2(-1450.0, 650.0)},
	{"name": "Aldea de la Bruma", "point": Vector2(-2200.0, -900.0)},
	{"name": "Bastión del Este", "point": Vector2(2260.0, -980.0)},
	{"name": "Oasis Dorado", "point": Vector2(2180.0, 1880.0)},
	{"name": "Castillo Boreal", "point": Vector2(-420.0, -2150.0)},
	{"name": "Caserío del Molino", "point": Vector2(-720.0, 740.0)},
	{"name": "Granjas de Robledal", "point": Vector2(-1680.0, 310.0)},
]


func _fall_and_wake_in_a_village() -> void:
	## Al caer te llevan a la villa más cercana y despiertas con LA MITAD de la
	## vida, no con toda: reponerse cuesta, y volver a bajar es una decisión.
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var refuge: Dictionary = REFUGES[0]
	var best := INF
	for candidate in REFUGES:
		var distance: float = here.distance_to(candidate["point"] as Vector2)
		if distance < best:
			best = distance
			refuge = candidate
	if kill_cam != null:
		kill_cam.flourish(KillCam.Beat.FALL, "Has caído")
	player_health = maxi(1, player_max_health / 2)
	var point: Vector2 = refuge["point"]
	var landing := _grounded_position(point + Vector2(14.0, 10.0), 1.1)
	_player.set_deferred("global_position", landing)
	_player.set_deferred("velocity", Vector3.ZERO)
	_player.action_feedback.emit(
		"Has caído. Despiertas en %s con media vida (%d/%d)." % [
			String(refuge["name"]), player_health, player_max_health])
	player_health_changed.emit(player_health, player_max_health)


func is_world_authority() -> bool:
	var session := get_node_or_null("/root/NetworkSession")
	return bool(session.call("is_world_authority")) if session != null else true


func get_save_state() -> Dictionary:
	var gates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("rpg_cave_gate"):
		gates.append((node as RPGCaveGate).get_save_state())
	return {
		"health": player_health,
		"awarded_chapters": _awarded_chapters.keys(),
		"gates": gates,
		"wonders": wonders.save_state() if wonders != null else {},
		# Con quién has hablado y a quién has ayudado: sin esto, cargar una
		# partida hacía que todo el mundo volviera a presentarse desde cero.
		"met": _met.duplicate(true),
		"helped": _helped.duplicate(true),
		"regard": _regard.duplicate(true),
		"act_answered": _act_answered.duplicate(true),
		"act_hinted": _act_hinted.duplicate(true),
		"companions": _companions.keys(),
		"witnessed": _witness_state(),
		"last_ending": last_ending,
		"campaign": campaign.save_state() if campaign != null else {},
		"quests": sidequests.save_state() if sidequests != null else {},
	}


func apply_save_state(state: Dictionary) -> void:
	if wonders != null:
		wonders.load_state(state.get("wonders", {}))
	player_health = clampi(int(state.get("health", player_max_health)), 1, player_max_health)
	_awarded_chapters.clear()
	for raw_chapter in state.get("awarded_chapters", []):
		_awarded_chapters[int(raw_chapter)] = true
	_met = (state.get("met", {}) as Dictionary).duplicate(true)
	_helped = (state.get("helped", {}) as Dictionary).duplicate(true)
	_regard = (state.get("regard", {}) as Dictionary).duplicate(true)
	_act_answered = (state.get("act_answered", {}) as Dictionary).duplicate(true)
	_act_hinted = (state.get("act_hinted", {}) as Dictionary).duplicate(true)
	for raw_mate in state.get("companions", []):
		_raise_companion(String(raw_mate))
	last_ending = String(state.get("last_ending", ""))
	var memories: Dictionary = state.get("witnessed", {})
	for mate in companion_roster():
		var kept: Array = memories.get(String(mate.companion_id), [])
		mate.witnessed = PackedStringArray(kept)
	if campaign != null and state.has("campaign"):
		campaign.load_state(state["campaign"] as Dictionary)
		_refresh_seals()
	if sidequests != null and state.has("quests"):
		sidequests.load_state(state["quests"] as Dictionary)
	_refresh_hud_bar()
	var by_id := {}
	for gate_state in state.get("gates", []):
		if gate_state is Dictionary:
			by_id[String(gate_state.get("id", ""))] = gate_state
	for node in get_tree().get_nodes_in_group("rpg_cave_gate"):
		var gate := node as RPGCaveGate
		gate.apply_save_state(by_id.get(gate.gate_id, {"id":gate.gate_id,"opened":false}))
	player_health_changed.emit(player_health, player_max_health)


func registrar_enemigo_red(enemigo: Node) -> void:
	_indice_enemigos_red[String(enemigo.enemy_id)] = enemigo


func get_network_enemy_state() -> Array[Dictionary]:
	var estados: Array[Dictionary] = []
	var retirados: Array[String] = []
	for id in _indice_enemigos_red:
		var enemigo = _indice_enemigos_red[id]
		if is_instance_valid(enemigo): estados.append(enemigo.get_network_state())
		else: retirados.append(id)
	for id in retirados: _indice_enemigos_red.erase(id)
	return estados


func apply_network_enemy_state(estados: Array) -> void:
	# El índice se construye al nacer cada enemigo. Un paquete ya identifica sus
	# objetivos: reconstruir otro diccionario y recorrer ambos grupos era redundante.
	for estado in estados:
		if not estado is Dictionary: continue
		var enemigo = _indice_enemigos_red.get(String(estado.get("id","")))
		if is_instance_valid(enemigo): enemigo.apply_network_state(estado)


func _grounded_position(point: Vector2, offset: float) -> Vector3:
	var height := _terrain.data.get_height(Vector3(point.x, 0.0, point.y)) if _terrain != null else NAN
	return Vector3(point.x, height + offset if not is_nan(height) else offset, point.y)
