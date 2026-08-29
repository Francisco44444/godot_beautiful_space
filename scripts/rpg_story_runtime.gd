class_name RPGStoryRuntime
extends Node3D

## Materializa la campaña de ocho capítulos: habitantes, puertas de gruta,
## monstruos y recompensas. ExplorationManager conserva los 200 objetivos y
## este nodo aporta los personajes y consecuencias físicas que los conectan.

signal dialogue_requested(speaker: String, role: String, title: String, body: String)
signal player_health_changed(current: int, maximum: int)
signal chapter_reward_granted(chapter: int, item_id: String, display_name: String)

const NPC_SCRIPT: Script = preload("res://scripts/rpg_npc.gd")
const ENEMY_SCRIPT: Script = preload("res://scripts/rpg_enemy.gd")
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
	{"id":"garrik", "name":"Garrik", "role":"Cantero de Robledal", "file":"Worker_Male.gltf", "point":Vector2(-1476, 618)},
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
	{"id":"roots", "name":"Gruta de las Raíces", "key":"Key1", "point":Vector2(-2530, 1090), "yaw":0.55, "hint":"Cripta del Corazón de Roble"},
	{"id":"frost", "name":"Observatorio Sepultado", "key":"Key2", "point":Vector2(690, -3370), "yaw":-0.15, "hint":"Cámara de las Constelaciones"},
	{"id":"sun", "name":"Santuario bajo la Arena", "key":"Key3", "point":Vector2(3190, 2290), "yaw":1.15, "hint":"Cámara del Mediodía"},
	{"id":"echo", "name":"Cámara sin Eco", "key":"Key4", "point":Vector2(4970, -1510), "yaw":-1.25, "hint":"Guarida de Vaelor"},
]
const ENEMY_PATHS: PackedStringArray = [
	"Blob/glTF/GreenSpikyBlob.gltf", "Blob/glTF/Mushnub_Evolved.gltf",
	"Big/glTF/Orc.gltf", "Big/glTF/BlueDemon.gltf", "Big/glTF/Yeti.gltf",
	"Big/glTF/Cactoro.gltf", "Flying/glTF/Ghost.gltf", "Flying/glTF/Dragon.gltf",
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


func _ready() -> void:
	_terrain = get_node(terrain_path) as Terrain3D
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
	for spec in GATE_SPECS:
		_spawn_gate_and_cave(spec)
	for index in enemy_count:
		_spawn_enemy(index)
	print("RPG STORY READY: %d habitantes, %d monstruos, %d grutas y %d puertas con llave." % [
		generated_npc_count, generated_enemy_count, generated_cave_count, generated_gate_count,
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
	var cave := Node3D.new()
	cave.name = "Cave_%s" % String(spec.id)
	add_child(cave)
	cave.global_position = _grounded_position(spec.point, 0.02)
	cave.rotation.y = float(spec.yaw)
	_build_cave_rocks(cave)
	var gate := RPGCaveGate.new()
	gate.name = "Gate_%s" % String(spec.id)
	gate.gate_id = String(spec.id)
	gate.display_name = String(spec.name)
	gate.key_item_id = String(spec.key)
	gate.destination_hint = String(spec.hint)
	gate.story_runtime = self
	cave.add_child(gate)
	gate.position = Vector3(0.0, 0.0, 1.1)
	generated_gate_count += 1
	generated_cave_count += 1


func _build_cave_rocks(cave: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.22, 0.25)
	material.roughness = 0.98
	for index in 16:
		var angle := PI * float(index) / 15.0
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 1.45 + float(index % 3) * 0.34
		mesh.height = mesh.radius * 1.7
		mesh.radial_segments = 7
		mesh.rings = 4
		mesh.material = material
		rock.mesh = mesh
		rock.scale = Vector3(1.5, 1.25, 1.0)
		rock.position = Vector3(cos(angle) * 4.0, sin(angle) * 4.2 + 0.3, -0.15 + absf(cos(angle)) * 0.7)
		cave.add_child(rock)
	var darkness := MeshInstance3D.new()
	darkness.name = "CaveDepth"
	var depth_mesh := BoxMesh.new()
	depth_mesh.size = Vector3(7.0, 5.2, 18.0)
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.012, 0.015, 0.025)
	dark_material.roughness = 1.0
	depth_mesh.material = dark_material
	darkness.mesh = depth_mesh
	darkness.position = Vector3(0.0, 2.4, -8.5)
	cave.add_child(darkness)


func _spawn_enemy(index: int) -> void:
	var center := ENCOUNTER_CENTERS[index % ENCOUNTER_CENTERS.size()]
	var ring := 7.5 + float((index / ENCOUNTER_CENTERS.size()) % 4) * 5.0
	var angle := TAU * float(index * 7 % 19) / 19.0
	var point := Vector2(center.x + cos(angle) * ring, center.z + sin(angle) * ring)
	var enemy := RPGEnemy.new()
	enemy.name = "Enemy_%02d" % index
	enemy.enemy_id = "silence_%02d" % index
	enemy.display_name = _enemy_name(index)
	enemy.monster_path = MONSTER_ROOT + ENEMY_PATHS[index % ENEMY_PATHS.size()]
	enemy.max_health = 4 + (index % 5) * 2
	enemy.health = enemy.max_health
	enemy.move_speed = 2.8 + float(index % 4) * 0.45
	enemy.reward_item_id = "Crystal4" if index % 3 == 0 else ("Arrow" if index % 3 == 1 else "Coin_Skull")
	enemy.reward_amount = 1 + int(index % 9 == 0)
	enemy.story_runtime = self
	add_child(enemy)
	enemy.global_position = _grounded_position(point, 0.10)
	generated_enemy_count += 1


func _enemy_name(index: int) -> String:
	var names := ["Espina del Silencio", "Guardián de raíz", "Orco olvidado", "Demonio de bruma", "Yeti sin nombre", "Cactoro centinela", "Espectro del Eco", "Dragón menor", "Calavera errante", "Vaelorita"]
	return String(names[index % names.size()])


func begin_npc_dialogue(npc: RPGNPC, player: Node) -> void:
	var identity := npc.get_story_identity()
	var current := _exploration.call("get_current_story_objective") as Dictionary if _exploration != null else {}
	var chapter := int(current.get("chapter_index", 1))
	var title := String(current.get("chapter_title", "El eco roto"))
	var objective := String(current.get("name", "Los senderos de Aeloria"))
	var body := "%s te observa como si ya conociera tu nombre.\n\n«%s»\n\nTu siguiente paso es [b]%s[/b]. %s" % [
		String(identity.name), _npc_line(String(identity.id), chapter), objective,
		String(current.get("description", "Sigue las marcas que responden a tu voz.")),
	]
	dialogue_requested.emit(String(identity.name), String(identity.role), title, body)
	if player != null and player.has_signal("action_feedback"):
		player.emit_signal("action_feedback", "%s ha actualizado tu pista" % String(identity.name))
	if _exploration != null and player is Node3D and String(current.get("npc_id", "")) == String(identity.id):
		_exploration.call("update_player_position", (player as Node3D).global_position)
		if String(current.get("requirement", "visit")) == "visit":
			_exploration.call("confirm_current_zone")


func _npc_line(npc_id: String, chapter: int) -> String:
	var lines := {
		"maela":"El mapa no dibuja la isla: recuerda aquello que la isla teme perder.",
		"orin":"Un arma vale por el juramento que protege, no por el metal de su filo.",
		"tavia":"Las raíces dicen que el Silencio estuvo aquí antes que nosotros.",
		"brenn":"Cuando dejen de cantar los pájaros, no sigas ninguna voz salvo la tuya.",
		"ysra":"La luna y sus sombras vuelven a coincidir. Es una señal, Portador.",
		"nara":"Bajo cada duna duerme una puerta; algunas sueñan con ser abiertas.",
		"calen":"Cuatro llaves, ocho voces y una sola oportunidad de llegar a Vaelor.",
		"lume":"El bosque rojo no quiere matarte. Quiere que olvides por qué llegaste.",
	}
	return String(lines.get(npc_id, "He oído tu nombre en los caminos. El capítulo %d ya ha comenzado." % chapter))


func _on_story_chapter_completed(chapter: Dictionary) -> void:
	var chapter_index := int(chapter.get("index", 0))
	if chapter_index < 1 or chapter_index > CHAPTER_REWARDS.size() or _awarded_chapters.has(chapter_index):
		return
	_awarded_chapters[chapter_index] = true
	var item_id := CHAPTER_REWARDS[chapter_index - 1]
	if _inventory != null and not bool(_inventory.call("has_item", item_id)):
		_inventory.call("add_item", item_id, 1)
	var definition := _inventory.call("get_item_definition", item_id) as Dictionary if _inventory != null else {}
	var display_name := String(definition.get("display_name", item_id.replace("_", " ")))
	chapter_reward_granted.emit(chapter_index, item_id, display_name)
	if _player != null:
		_player.action_feedback.emit("Capítulo completado · has recibido %s" % display_name)


func on_enemy_defeated(enemy: RPGEnemy) -> void:
	if _inventory != null:
		_inventory.call("add_item", enemy.reward_item_id, enemy.reward_amount)
	if _player != null:
		_player.action_feedback.emit("%s derrotado · recompensa obtenida" % enemy.display_name)


func on_gate_opened(gate: RPGCaveGate) -> void:
	if _player != null:
		_player.action_feedback.emit("La voz del interior de %s ya puede oírte" % gate.display_name)


func damage_player(amount: int, source_position: Vector3, source_name: String) -> void:
	if _damage_cooldown > 0.0 or _player == null:
		return
	_damage_cooldown = 0.72
	player_health = maxi(0, player_health - maxi(1, amount))
	var away := _player.global_position - source_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		_player.velocity += away.normalized() * 5.2 + Vector3.UP * 2.0
	_player.action_feedback.emit("%s te hiere · vida %d/%d" % [source_name, player_health, player_max_health])
	player_health_changed.emit(player_health, player_max_health)
	if player_health <= 0:
		player_health = player_max_health
		_player.call_deferred("_respawn")
		player_health_changed.emit(player_health, player_max_health)


func is_world_authority() -> bool:
	var session := get_node_or_null("/root/NetworkSession")
	return bool(session.call("is_world_authority")) if session != null else true


func get_save_state() -> Dictionary:
	var gates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("rpg_cave_gate"):
		gates.append((node as RPGCaveGate).get_save_state())
	return {"health": player_health, "awarded_chapters": _awarded_chapters.keys(), "gates": gates}


func apply_save_state(state: Dictionary) -> void:
	player_health = clampi(int(state.get("health", player_max_health)), 1, player_max_health)
	_awarded_chapters.clear()
	for raw_chapter in state.get("awarded_chapters", []):
		_awarded_chapters[int(raw_chapter)] = true
	var by_id := {}
	for gate_state in state.get("gates", []):
		if gate_state is Dictionary:
			by_id[String(gate_state.get("id", ""))] = gate_state
	for node in get_tree().get_nodes_in_group("rpg_cave_gate"):
		var gate := node as RPGCaveGate
		if by_id.has(gate.gate_id):
			gate.apply_save_state(by_id[gate.gate_id])
	player_health_changed.emit(player_health, player_max_health)


func get_network_enemy_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("rpg_enemy"):
		result.append((node as RPGEnemy).get_network_state())
	return result


func apply_network_enemy_state(states: Array) -> void:
	var by_id := {}
	for state in states:
		if state is Dictionary:
			by_id[String(state.get("id", ""))] = state
	for node in get_tree().get_nodes_in_group("rpg_enemy"):
		var enemy := node as RPGEnemy
		if by_id.has(enemy.enemy_id):
			enemy.apply_network_state(by_id[enemy.enemy_id])


func _grounded_position(point: Vector2, offset: float) -> Vector3:
	var height := _terrain.data.get_height(Vector3(point.x, 0.0, point.y)) if _terrain != null else NAN
	return Vector3(point.x, height + offset if not is_nan(height) else offset, point.y)
