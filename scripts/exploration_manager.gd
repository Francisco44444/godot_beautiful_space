extends Node

## Catálogo y progreso de exploración independiente de la escena. Genera siempre
## los mismos 200 retos: visitas, fauna, cofres, tala, minería, reliquias y dos
## observaciones temporales. Las visitas se confirman con E; las tareas físicas
## sólo cuentan cuando se realiza la acción sobre su objeto concreto.

signal catalog_ready(total: int)
signal nearby_zone_changed(zone: Dictionary)
signal zone_discovered(zone: Dictionary, completed: int, total: int)
signal progress_changed(completed: int, total: int, ratio: float)
signal selected_zone_changed(zone: Dictionary)
signal progress_loaded(completed: int, total: int)
signal save_completed(path: String)
signal save_failed(path: String, error: String)
signal objective_action_completed(zone: Dictionary, action_key: String)

const SAVE_VERSION := 2
const TOTAL_ZONES := 200
const GEOGRAPHIC_ZONE_COUNT := 198
const DEFAULT_SAVE_PATH := "user://exploration_progress_v1.json"
const DEFAULT_DISCOVERY_RADIUS := 34.0
const TRACK_INTERVAL_SECONDS := 0.16
const TERRAIN_SAMPLE_STEP := 4.6875
const MAX_ACCESSIBLE_SLOPE := 0.72
const ACCESSIBLE_SEARCH_STEP := 32.0
const ACCESSIBLE_SEARCH_RINGS := 18
const ACCESSIBLE_SEARCH_DIRECTIONS := 16

const GOLDEN_RATIO_FRACTION := 0.618033988749895
const SECOND_LOW_DISCREPANCY_STEP := 0.754877666246693
const ANIMAL_NAMES: PackedStringArray = [
	"alpaca", "toro", "vaca", "ciervo", "burro", "zorro",
	"caballo salvaje", "caballo blanco", "husky", "shiba inu", "venado", "lobo",
]

const REGION_LAYOUT: Array[Dictionary] = [
	{
		"biome": "pradera",
		"type": "paraje",
		"count": 36,
		"center": Vector2(0.0, 550.0),
		"radii": Vector2(3000.0, 2050.0),
		"phase": 0.07,
		"title": "Paraje de la Pradera",
		"description": "Un rincón abierto de las praderas centrales, lejos de los caminos principales.",
	},
	{
		"biome": "bosque",
		"type": "claro",
		"count": 36,
		"center": Vector2(-2450.0, 520.0),
		"radii": Vector2(1760.0, 2350.0),
		"phase": 0.19,
		"title": "Claro del Bosque",
		"description": "Un claro oculto entre los bosques occidentales de la isla.",
	},
	{
		"biome": "nieve",
		"type": "cumbre",
		"count": 26,
		"center": Vector2(180.0, -3020.0),
		"radii": Vector2(2950.0, 900.0),
		"phase": 0.31,
		"title": "Hito de las Cumbres",
		"description": "Una cornisa de las Cumbres Blancas, entre hielo, roca y viento.",
	},
	{
		"biome": "desierto",
		"type": "duna",
		"count": 24,
		"center": Vector2(2450.0, 2050.0),
		"radii": Vector2(1960.0, 1250.0),
		"phase": 0.43,
		"title": "Secreto de las Dunas",
		"description": "Una formación singular entre las dunas y barrancos del sureste.",
	},
	{
		"biome": "costa",
		"type": "costa",
		"count": 26,
		"phase": 0.11,
		"title": "Rincón de la Costa",
		"description": "Un cabo, playa o ensenada donde la tierra se encuentra con el mar.",
	},
	{
		"biome": "montaña",
		"type": "mirador",
		"count": 20,
		"center": Vector2(-420.0, -650.0),
		"radii": Vector2(3650.0, 2800.0),
		"phase": 0.59,
		"title": "Mirador de la Sierra",
		"description": "Un paso elevado con vistas a los valles y cordilleras de la isla.",
	},
	{
		"biome": "tenebroso",
		"type": "misterio",
		"count": 16,
		"center": Vector2(4520.0, -1160.0),
		"radii": Vector2(1030.0, 1180.0),
		"phase": 0.71,
		"title": "Misterio del Bosque Tenebroso",
		"description": "Una presencia extraña se percibe bajo el dosel azulado del este.",
	},
	{
		"biome": "poblado",
		"type": "historia",
		"count": 14,
		"phase": 0.83,
		"title": "Historia de los Poblados",
		"description": "Un detalle humano escondido entre villas, fortalezas y caseríos.",
	},
]

const SETTLEMENT_LANDMARKS: Array[Dictionary] = [
	{"name": "Puerto Alba", "kind": "aldea", "point": Vector2(0.0, 190.0)},
	{"name": "Castillo de Villa Robledal", "kind": "castillo", "point": Vector2(-1333.0, 696.0)},
	{"name": "Aldea de la Bruma", "kind": "aldea", "point": Vector2(-2200.0, -900.0)},
	{"name": "Castillo del Bastión del Este", "kind": "castillo", "point": Vector2(2350.0, -894.0)},
	{"name": "Oasis Dorado", "kind": "aldea", "point": Vector2(2180.0, 1880.0)},
	{"name": "Castillo Boreal", "kind": "castillo", "point": Vector2(-295.0, -2147.0)},
	{"name": "Casa del Caserío del Molino", "kind": "casa", "point": Vector2(-720.0, 740.0)},
	{"name": "Casa de las Granjas de Robledal", "kind": "casa", "point": Vector2(-1680.0, 310.0)},
	{"name": "Casa de las Tres Encinas", "kind": "casa", "point": Vector2(-940.0, -1110.0)},
	{"name": "Casa del Caserío del Puente", "kind": "casa", "point": Vector2(970.0, -170.0)},
	{"name": "Casa de los Viñedos del Sol", "kind": "casa", "point": Vector2(1510.0, 830.0)},
	{"name": "Casa de las Fincas del Este", "kind": "casa", "point": Vector2(1720.0, -1030.0)},
	{"name": "Refugio Umbrío", "kind": "casa", "point": Vector2(-1040.0, -1900.0)},
	{"name": "Puesto Boreal", "kind": "casa", "point": Vector2(910.0, -2360.0)},
]

@export_file("*.json") var save_path := DEFAULT_SAVE_PATH
@export var autosave_enabled := true
@export var auto_load_on_ready := true
@export var auto_track_local_player := true
@export var handle_interact_input := true
@export var local_player_group: StringName = &"local_player"

var _zones: Array[Dictionary] = []
var _zones_by_id: Dictionary = {}
var _discovered: Dictionary = {}
var _selected_zone_id := ""
var _nearby_zone_id := ""
var _active_events: Dictionary = {"amanecer": false, "atardecer": false}
var _tracked_player: Node3D
var _track_accumulator := 0.0
var _initialized := false
var _terrain_data: Object


func _ready() -> void:
	initialize(auto_load_on_ready)


func _physics_process(delta: float) -> void:
	if not auto_track_local_player:
		return
	_track_accumulator += delta
	if _track_accumulator < TRACK_INTERVAL_SECONDS:
		return
	_track_accumulator = 0.0
	if not is_instance_valid(_tracked_player):
		_tracked_player = get_tree().get_first_node_in_group(local_player_group) as Node3D
	if is_instance_valid(_tracked_player):
		update_player_position(_tracked_player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if not handle_interact_input:
		return
	if not event.is_action_pressed(&"interact"):
		return
	var discovered_zone := confirm_current_zone()
	if not discovered_zone.is_empty() and is_inside_tree():
		get_viewport().set_input_as_handled()


func initialize(load_saved_progress: bool = true) -> void:
	if _initialized:
		if load_saved_progress:
			load_progress()
		return
	_build_catalog()
	_initialized = true
	catalog_ready.emit(_zones.size())
	if load_saved_progress:
		load_progress()
	else:
		progress_loaded.emit(0, _zones.size())
		_emit_progress()


func get_zones() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for zone in _zones:
		copy.append(_zone_with_status(zone))
	return copy


func get_zone(zone_id: String) -> Dictionary:
	var zone: Dictionary = _zones_by_id.get(zone_id, {})
	return _zone_with_status(zone) if not zone.is_empty() else {}


func get_zone_count() -> int:
	return _zones.size()


func get_completed_count() -> int:
	return _discovered.size()


func get_progress_ratio() -> float:
	return float(_discovered.size()) / float(maxi(_zones.size(), 1))


func get_discovered_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for zone_id in _discovered.keys():
		result.append(String(zone_id))
	result.sort()
	return result


func is_discovered(zone_id: String) -> bool:
	return _discovered.has(zone_id)


func get_zones_by_biome(biome: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized := biome.strip_edges().to_lower()
	for zone in _zones:
		if String(zone.biome).to_lower() == normalized:
			result.append(_zone_with_status(zone))
	return result


func set_tracked_player(player: Node3D) -> void:
	_tracked_player = player
	if is_instance_valid(_tracked_player):
		update_player_position(_tracked_player.global_position)


func bind_terrain(terrain_node: Node) -> bool:
	# El catálogo nace antes que la escena. Al recibir Terrain3D, cada marcador se
	# proyecta sobre una superficie cercana transitable y guarda su altura real.
	# Esto evita validar una cumbre estando verticalmente debajo de ella.
	if terrain_node == null:
		return false
	_terrain_data = terrain_node.get("data") as Object
	if _terrain_data == null:
		return false
	for index in _zones.size():
		var zone := _zones[index].duplicate(true) as Dictionary
		var current: Vector3 = zone.position
		var accessible := _find_accessible_terrain_point(Vector2(current.x, current.z))
		zone.position = accessible
		_zones[index] = zone
		_zones_by_id[String(zone.id)] = zone
	selected_zone_changed.emit(get_selected_zone())
	if is_instance_valid(_tracked_player):
		update_player_position(_tracked_player.global_position)
	return true


func update_player_position(world_position: Vector3) -> Dictionary:
	var best_id := ""
	var best_distance := INF
	for zone in _zones:
		var zone_id := String(zone.id)
		if _discovered.has(zone_id) or not _event_requirement_is_met(zone):
			continue
		var location: Vector3 = zone.position
		var radius := float(zone.radius)
		var horizontal_distance := Vector2(world_position.x - location.x, world_position.z - location.z).length()
		var vertically_near := _terrain_data == null or absf(world_position.y - location.y) <= maxf(18.0, radius * 0.85)
		if vertically_near and horizontal_distance <= radius and horizontal_distance < best_distance:
			best_id = zone_id
			best_distance = horizontal_distance
	if best_id != _nearby_zone_id:
		_nearby_zone_id = best_id
		nearby_zone_changed.emit(get_nearby_zone())
	return get_nearby_zone()


func get_nearby_zone() -> Dictionary:
	return get_zone(_nearby_zone_id) if not _nearby_zone_id.is_empty() else {}


func can_confirm_current_zone() -> bool:
	if _nearby_zone_id.is_empty() or _discovered.has(_nearby_zone_id):
		return false
	var zone: Dictionary = _zones_by_id.get(_nearby_zone_id, {})
	var requirement := String(zone.get("requirement", "visit"))
	return not zone.is_empty() and requirement in ["visit", "event"] and _event_requirement_is_met(zone)


func confirm_current_zone() -> Dictionary:
	if not can_confirm_current_zone():
		return {}
	var zone: Dictionary = _zones_by_id.get(_nearby_zone_id, {})
	if zone.is_empty() or not _event_requirement_is_met(zone):
		return {}
	return _complete_zone(String(zone.id))


func register_world_action(zone_id: String, action_key: String) -> Dictionary:
	if zone_id.is_empty() or _discovered.has(zone_id):
		return {}
	var zone: Dictionary = _zones_by_id.get(zone_id, {})
	if zone.is_empty() or String(zone.get("requirement", "visit")) != action_key:
		return {}
	var completed := _complete_zone(zone_id)
	if not completed.is_empty():
		objective_action_completed.emit(completed, action_key)
	return completed


func _complete_zone(zone_id: String) -> Dictionary:
	var zone: Dictionary = _zones_by_id.get(zone_id, {})
	if zone.is_empty() or _discovered.has(zone_id):
		return {}
	_discovered[zone_id] = true
	if _nearby_zone_id == zone_id:
		_nearby_zone_id = ""
	if autosave_enabled:
		save_progress()
	var completed_zone := _zone_with_status(zone)
	zone_discovered.emit(completed_zone, _discovered.size(), _zones.size())
	_emit_progress()
	nearby_zone_changed.emit({})
	return completed_zone


func set_world_event_active(event_key: String, active: bool) -> void:
	var normalized := _normalize_event_key(event_key)
	if normalized.is_empty():
		return
	_active_events[normalized] = active
	_refresh_nearby_after_event_change()


func update_time_of_day(time_label: String) -> void:
	var normalized := _normalize_event_key(time_label)
	_active_events["amanecer"] = normalized == "amanecer"
	_active_events["atardecer"] = normalized == "atardecer"
	_refresh_nearby_after_event_change()


func is_world_event_active(event_key: String) -> bool:
	var normalized := _normalize_event_key(event_key)
	return bool(_active_events.get(normalized, false))


func select_zone(zone_id: String, persist: bool = true) -> bool:
	if zone_id.is_empty():
		_selected_zone_id = ""
		selected_zone_changed.emit({})
		if persist and autosave_enabled:
			save_progress()
		return true
	if not _zones_by_id.has(zone_id):
		return false
	_selected_zone_id = zone_id
	selected_zone_changed.emit(get_selected_zone())
	if persist and autosave_enabled:
		save_progress()
	return true


func clear_selected_zone(persist: bool = true) -> void:
	select_zone("", persist)


func get_selected_zone() -> Dictionary:
	return get_zone(_selected_zone_id) if not _selected_zone_id.is_empty() else {}


func get_selected_world_position() -> Vector3:
	var zone: Dictionary = _zones_by_id.get(_selected_zone_id, {})
	return zone.position if not zone.is_empty() else Vector3(INF, INF, INF)


func clear_progress(persist: bool = true) -> void:
	_discovered.clear()
	_nearby_zone_id = ""
	_selected_zone_id = ""
	if persist and autosave_enabled:
		save_progress()
	_emit_progress()
	nearby_zone_changed.emit({})
	selected_zone_changed.emit({})


func get_save_state() -> Dictionary:
	if not _initialized:
		initialize(false)
	return {
		"discovered_ids": Array(get_discovered_ids()),
		"selected_zone_id": _selected_zone_id,
	}


func apply_save_state(state: Dictionary, persist: bool = true) -> bool:
	if not _initialized:
		initialize(false)
	var ids = state.get("discovered_ids", [])
	if not ids is Array:
		return false
	_discovered.clear()
	for raw_id in ids:
		var zone_id := String(raw_id)
		if _zones_by_id.has(zone_id):
			_discovered[zone_id] = true
	var stored_selection := String(state.get("selected_zone_id", ""))
	_selected_zone_id = stored_selection if _zones_by_id.has(stored_selection) else ""
	_nearby_zone_id = ""
	progress_loaded.emit(_discovered.size(), _zones.size())
	_emit_progress()
	nearby_zone_changed.emit({})
	selected_zone_changed.emit(get_selected_zone())
	if persist and autosave_enabled:
		save_progress()
	return true


func save_progress() -> bool:
	if not _initialized:
		initialize(false)
	var discovered_ids := get_discovered_ids()
	var payload := {
		"schema_version": SAVE_VERSION,
		"catalog_signature": _catalog_signature(),
		"total_zones": _zones.size(),
		"discovered_ids": Array(discovered_ids),
		"selected_zone_id": _selected_zone_id,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	var encoded := JSON.stringify(payload, "\t")
	var temporary_path := save_path + ".tmp"
	if not _write_text_file(temporary_path, encoded):
		save_failed.emit(save_path, "No se pudo escribir el archivo temporal.")
		return false
	# Conserva una copia legible anterior. Si el proceso se interrumpe durante la
	# escritura final, la siguiente carga puede recuperar automáticamente el backup.
	if FileAccess.file_exists(save_path):
		var previous := _read_text_file(save_path)
		if _validated_payload(previous) != null:
			_write_text_file(save_path + ".bak", previous)
	if not _write_text_file(save_path, encoded):
		save_failed.emit(save_path, "No se pudo sustituir el guardado principal.")
		return false
	_remove_owned_file(temporary_path)
	save_completed.emit(save_path)
	return true


func load_progress() -> bool:
	if not _initialized:
		initialize(false)
	var payload = _validated_payload(_read_text_file(save_path))
	if payload == null:
		payload = _validated_payload(_read_text_file(save_path + ".bak"))
	if payload == null:
		_discovered.clear()
		_selected_zone_id = ""
		progress_loaded.emit(0, _zones.size())
		_emit_progress()
		return false
	_discovered.clear()
	for raw_id in payload.get("discovered_ids", []):
		var zone_id := String(raw_id)
		if _zones_by_id.has(zone_id):
			_discovered[zone_id] = true
	var stored_selection := String(payload.get("selected_zone_id", ""))
	_selected_zone_id = stored_selection if _zones_by_id.has(stored_selection) else ""
	progress_loaded.emit(_discovered.size(), _zones.size())
	_emit_progress()
	selected_zone_changed.emit(get_selected_zone())
	return true


func _build_catalog() -> void:
	_zones.clear()
	_zones_by_id.clear()
	var global_index := 0
	for layout in REGION_LAYOUT:
		var count := int(layout.count)
		for local_index in count:
			global_index += 1
			var point := _point_for_layout(layout, local_index, global_index)
			var objective := _objective_for_zone(layout, local_index, global_index)
			var zone := {
				"id": "zone_%03d" % global_index,
				"name": String(objective.name),
				"position": Vector3(point.x, 0.0, point.y),
				"description": String(objective.description),
				"type": String(objective.type),
				"biome": String(layout.biome),
				"radius": DEFAULT_DISCOVERY_RADIUS + float((global_index * 7) % 4) * 4.0,
				"requires_event": "",
				"requirement": String(objective.requirement),
				"objective_hint": String(objective.hint),
				"target_id": "zone_%03d" % global_index,
				"variant": int(objective.variant),
			}
			_add_zone(zone)
	_add_zone({
		"id": "zone_199_amanecer",
		"name": "El primer rayo",
		"position": Vector3(3790.0, 0.0, -690.0),
		"description": "Contempla el amanecer desde el Bastión del Este y pulsa E mientras nace el día.",
		"type": "evento",
		"biome": "costa",
		"radius": 90.0,
		"requires_event": "amanecer",
		"requirement": "event",
		"objective_hint": "E · contemplar el amanecer",
		"target_id": "zone_199_amanecer",
		"variant": 0,
	})
	_add_zone({
		"id": "zone_200_atardecer",
		"name": "La última luz",
		"position": Vector3(-3840.0, 0.0, 620.0),
		"description": "Contempla el atardecer desde el cabo occidental y pulsa E antes de que llegue la noche.",
		"type": "evento",
		"biome": "costa",
		"radius": 90.0,
		"requires_event": "atardecer",
		"requirement": "event",
		"objective_hint": "E · contemplar el atardecer",
		"target_id": "zone_200_atardecer",
		"variant": 0,
	})
	assert(_zones.size() == TOTAL_ZONES)


func _objective_for_zone(layout: Dictionary, local_index: int, global_index: int) -> Dictionary:
	var biome := String(layout.biome)
	var rank := posmod(global_index * 73, GEOGRAPHIC_ZONE_COUNT)
	var requirement := "visit"
	if rank >= 70 and rank < 94:
		requirement = "discover_animal"
	elif rank >= 94 and rank < 130:
		requirement = "open_chest"
	elif rank >= 130 and rank < 158:
		requirement = "chop_tree"
	elif rank >= 158 and rank < 182:
		requirement = "mine_rock"
	elif rank >= 182:
		requirement = "recover_relic"
	# Las casas y castillos se exploran de verdad; en dunas y costa sustituimos
	# árboles fuera de lugar por minería o tesoros enterrados.
	if biome == "poblado":
		requirement = "visit"
	elif requirement == "chop_tree" and biome == "desierto":
		requirement = "mine_rock"
	elif requirement == "chop_tree" and biome == "costa":
		requirement = "open_chest"

	var suffix := "%02d" % (local_index + 1)
	match requirement:
		"discover_animal":
			var animal_name := ANIMAL_NAMES[(global_index + local_index) % ANIMAL_NAMES.size()]
			return {
				"name": "Rastro de %s %s" % [animal_name.capitalize(), suffix],
				"description": "Acércate con calma, observa al %s y pulsa E para registrarlo en el bestiario." % animal_name,
				"type": "fauna", "requirement": requirement,
				"hint": "E · descubrir %s" % animal_name, "variant": (global_index + local_index) % ANIMAL_NAMES.size(),
			}
		"open_chest":
			return {
				"name": "Cofre perdido %s" % suffix,
				"description": "Encuentra y abre el cofre. Puede contener cualquiera de los tesoros y armas RPG de Quaternius.",
				"type": "tesoro", "requirement": requirement,
				"hint": "E · abrir el cofre", "variant": global_index % 4,
			}
		"chop_tree":
			return {
				"name": "El árbol marcado %s" % suffix,
				"description": "Equipa el hacha con 2, tala el árbol marcado y recoge el tronco al pasar sobre él.",
				"type": "tala", "requirement": requirement,
				"hint": "2 Hacha · corta el árbol", "variant": global_index % 5,
			}
		"mine_rock":
			return {
				"name": "Veta de rubí %s" % suffix,
				"description": "Rompe la roca mineral con el hacha y recoge los cristales que desprenda.",
				"type": "minería", "requirement": requirement,
				"hint": "2 Hacha · rompe la veta", "variant": global_index % 3,
			}
		"recover_relic":
			return {
				"name": "Reliquia olvidada %s" % suffix,
				"description": "Localiza la reliquia de Quaternius y recógela para incorporarla al inventario.",
				"type": "reliquia", "requirement": requirement,
				"hint": "E · recuperar la reliquia", "variant": global_index,
			}
		_:
			var visit_name := "%s %s" % [String(layout.title), suffix]
			var visit_description := String(layout.description)
			if biome == "poblado":
				var landmark: Dictionary = SETTLEMENT_LANDMARKS[local_index % SETTLEMENT_LANDMARKS.size()]
				visit_name = String(landmark.name)
				var landmark_kind := String(landmark.kind)
				visit_description = "Llega a este %s real del mapa, explora su entorno y pulsa E para registrarlo en el diario." % landmark_kind
			return {
				"name": visit_name, "description": visit_description,
				"type": String(layout.type), "requirement": "visit",
				"hint": "E · registrar el lugar", "variant": global_index,
			}


func _add_zone(zone: Dictionary) -> void:
	var frozen_zone := zone.duplicate(true)
	_zones.append(frozen_zone)
	_zones_by_id[String(frozen_zone.id)] = frozen_zone


func _point_for_layout(layout: Dictionary, local_index: int, global_index: int) -> Vector2:
	var biome := String(layout.biome)
	if biome == "costa":
		var angle := TAU * (float(local_index) + 0.37) / float(int(layout.count))
		angle += sin(float(local_index) * 2.17) * 0.035
		var coast_radius := _coast_radius_at_angle(angle) - 330.0 - float(local_index % 3) * 38.0
		return Vector2(cos(angle), sin(angle)) * coast_radius
	if biome == "poblado":
		var landmark: Dictionary = SETTLEMENT_LANDMARKS[local_index % SETTLEMENT_LANDMARKS.size()]
		return _fit_inside_island(landmark.point, 280.0)
	var center: Vector2 = layout.center
	var radii: Vector2 = layout.radii
	var phase := float(layout.phase)
	var angle_fraction := fmod((float(local_index) + 1.0) * GOLDEN_RATIO_FRACTION + phase, 1.0)
	var radius_fraction := sqrt(fmod((float(local_index) + 1.0) * SECOND_LOW_DISCREPANCY_STEP + phase * 0.73, 1.0))
	var angle := TAU * angle_fraction
	var point := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * radius_fraction
	# Una oscilación determinista evita que la distribución parezca una cuadrícula
	# sin depender del estado global de RandomNumberGenerator.
	point += Vector2(sin(float(global_index) * 4.13), cos(float(global_index) * 3.71)) * 31.0
	return _fit_inside_island(point, 280.0)


func _fit_inside_island(point: Vector2, margin: float) -> Vector2:
	if point.length_squared() < 1.0:
		return point
	var angle := atan2(point.y, point.x)
	var maximum_radius := maxf(_coast_radius_at_angle(angle) - margin, 300.0)
	if point.length() > maximum_radius:
		return point.normalized() * maximum_radius
	return point


func _find_accessible_terrain_point(origin: Vector2) -> Vector3:
	var fallback_height := _terrain_height(origin)
	for ring in ACCESSIBLE_SEARCH_RINGS:
		var radius := float(ring) * ACCESSIBLE_SEARCH_STEP
		var direction_count := 1 if ring == 0 else ACCESSIBLE_SEARCH_DIRECTIONS
		for direction_index in direction_count:
			var angle := TAU * float(direction_index) / float(direction_count) + float(ring) * 0.37
			var candidate := origin + Vector2(cos(angle), sin(angle)) * radius
			candidate = _fit_inside_island(candidate, 260.0)
			var height := _terrain_height(candidate)
			if is_nan(height) or height < 1.2:
				continue
			if _terrain_slope(candidate) <= MAX_ACCESSIBLE_SLOPE:
				return Vector3(candidate.x, height + 0.15, candidate.y)
	return Vector3(origin.x, fallback_height + 0.15 if not is_nan(fallback_height) else 0.0, origin.y)


func _terrain_height(point: Vector2) -> float:
	if _terrain_data == null:
		return NAN
	return float(_terrain_data.call("get_height", Vector3(point.x, 0.0, point.y)))


func _terrain_slope(point: Vector2) -> float:
	var left := _terrain_height(point - Vector2(TERRAIN_SAMPLE_STEP, 0.0))
	var right := _terrain_height(point + Vector2(TERRAIN_SAMPLE_STEP, 0.0))
	var back := _terrain_height(point - Vector2(0.0, TERRAIN_SAMPLE_STEP))
	var forward := _terrain_height(point + Vector2(0.0, TERRAIN_SAMPLE_STEP))
	if is_nan(left) or is_nan(right) or is_nan(back) or is_nan(forward):
		return INF
	var gradient := Vector2(right - left, forward - back) / (TERRAIN_SAMPLE_STEP * 2.0)
	return gradient.length()


func _coast_radius_at_angle(angle: float) -> float:
	var cosine := cos(angle)
	var sine := sin(angle)
	var ellipse_radius := 1.0 / sqrt((cosine * cosine) / (4740.0 * 4740.0) + (sine * sine) / (4540.0 * 4540.0))
	var mystery_angle := atan2(sin(angle + 0.27), cos(angle + 0.27))
	var mystery_peninsula := 1200.0 * exp(-(mystery_angle * mystery_angle) / (2.0 * 0.27 * 0.27))
	var desert_angle := atan2(sin(angle - 0.50), cos(angle - 0.50))
	var desert_shoulder := 420.0 * exp(-(desert_angle * desert_angle) / (2.0 * 0.32 * 0.32))
	var north_neck_angle := atan2(sin(angle + 0.82), cos(angle + 0.82))
	var north_inlet := 350.0 * exp(-(north_neck_angle * north_neck_angle) / (2.0 * 0.20 * 0.20))
	var south_neck_angle := atan2(sin(angle - 0.04), cos(angle - 0.04))
	var south_inlet := 430.0 * exp(-(south_neck_angle * south_neck_angle) / (2.0 * 0.18 * 0.18))
	var wobble := sin(angle * 7.0) * 0.018 + sin(angle * 13.0 + 0.7) * 0.009
	return (ellipse_radius + mystery_peninsula + desert_shoulder - north_inlet - south_inlet) / (1.0 + wobble)


func _event_requirement_is_met(zone: Dictionary) -> bool:
	var required_event := String(zone.get("requires_event", ""))
	return required_event.is_empty() or bool(_active_events.get(required_event, false))


func _refresh_nearby_after_event_change() -> void:
	if is_instance_valid(_tracked_player):
		update_player_position(_tracked_player.global_position)
		return
	var nearby: Dictionary = _zones_by_id.get(_nearby_zone_id, {})
	if not nearby.is_empty() and not _event_requirement_is_met(nearby):
		_nearby_zone_id = ""
		nearby_zone_changed.emit({})


func _normalize_event_key(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ["amanecer", "dawn", "sunrise"]:
		return "amanecer"
	if normalized in ["atardecer", "ocaso", "sunset", "dusk"]:
		return "atardecer"
	return ""


func _zone_with_status(zone: Dictionary) -> Dictionary:
	if zone.is_empty():
		return {}
	var result := zone.duplicate(true)
	result["discovered"] = _discovered.has(String(zone.id))
	result["selected"] = String(zone.id) == _selected_zone_id
	result["event_active"] = _event_requirement_is_met(zone)
	return result


func _emit_progress() -> void:
	progress_changed.emit(_discovered.size(), _zones.size(), get_progress_ratio())


func _catalog_signature() -> String:
	var identifiers := PackedStringArray()
	for zone in _zones:
		var position: Vector3 = zone.position
		identifiers.append("%s:%s:%s:%.1f:%.1f" % [
			String(zone.id), String(zone.get("requirement", "visit")), String(zone.name), position.x, position.z,
		])
	return "%d:%d:%s" % [SAVE_VERSION, _zones.size(), String.num_int64("|".join(identifiers).hash())]


func _validated_payload(text: String):
	if text.is_empty():
		return null
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return null
	var payload := parser.data as Dictionary
	if (
		int(payload.get("schema_version", -1)) != SAVE_VERSION
		or int(payload.get("total_zones", -1)) != _zones.size()
		or String(payload.get("catalog_signature", "")) != _catalog_signature()
		or not payload.get("discovered_ids", null) is Array
	):
		return null
	var seen := {}
	for raw_id in payload.discovered_ids:
		if not raw_id is String:
			return null
		var zone_id := String(raw_id)
		if not _zones_by_id.has(zone_id) or seen.has(zone_id):
			return null
		seen[zone_id] = true
	var selection = payload.get("selected_zone_id", "")
	if not selection is String:
		return null
	if not String(selection).is_empty() and not _zones_by_id.has(String(selection)):
		return null
	return payload


func _write_text_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	return file.get_error() == OK


func _read_text_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _remove_owned_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
