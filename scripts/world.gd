extends Node3D

## Conecta el mundo ampliado de 12 x 12 km y gobierna un ciclo completo con amanecer,
## atardecer y noche real, incluida la iluminación ambiental.

const FAST_TRAVEL_POINTS: Array[Dictionary] = [
	{"name": "Dunas Doradas", "position": Vector2(2350.0, 2050.0)},
	{"name": "Cumbres Blancas", "position": Vector2(520.0, -3000.0)},
	{"name": "Villa Robledal", "position": Vector2(-1450.0, 650.0)},
	{"name": "Bosque Umbrío", "position": Vector2(-2180.0, 1650.0)},
	{"name": "Bosque Tenebroso", "position": Vector2(4620.0, -1260.0)},
]
const BOSS_TRAVEL_POINTS: Array[Dictionary] = [
	{"name": "Guardián del Corazón de Roble", "position": Vector2(-2518.0, 1102.0)},
	{"name": "Guardián de la Corona de Escarcha", "position": Vector2(702.0, -3358.0)},
	{"name": "Guardián del Santuario Solar", "position": Vector2(3178.0, 2302.0)},
	{"name": "Vaelor, Señor del Silencio", "position": Vector2(4958.0, -1498.0)},
]
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SEA_BOUNDARY_SEGMENTS := 112
const CLIFF_BARRIER_SAMPLES := 512
const CLIFF_TEXTURE_ID := 6
const CLIFF_SLOPE_DEGREES := 48.0
const CLIFF_BARRIER_HEIGHT := 4.6
const TIDE_DRY_CLEARANCE := 1.65
const TIDE_WARNING_CLEARANCE := 2.15
const TIDE_PUSH_SPEED := 7.5
const TIDE_RESCUE_SPEED := 22.0
const TIDE_RETREAT_RADII: PackedFloat32Array = [8.0, 16.0, 28.0, 44.0, 68.0, 104.0, 156.0, 232.0, 320.0, 440.0, 620.0]
const CLIFF_SAFE_DESCENTS: Array = [
	[Vector2(2780, 1480), Vector2(3070, 1540), Vector2(3340, 1640), Vector2(3600, 1770), Vector2(3890, 1900)],
	[Vector2(3480, -1320), Vector2(4140, -1260), Vector2(4920, -1080)],
]

@export_category("Ciclo de luz")
@export var sun_cycle_enabled := true
@export_range(120.0, 1800.0, 10.0) var sun_cycle_seconds := 480.0

@onready var terrain: Terrain3D = $Terrain3D
@onready var player: Player = $Player
@onready var horse: Horse = $Horse
@onready var lookout: Node3D = $Lookout
@onready var sun: DirectionalLight3D = $Sun
@onready var sky_fill: DirectionalLight3D = $SkyFill
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var camera_rig: ThirdPersonCamera = $CameraRig
@onready var island_environment: IslandEnvironment = $IslandEnvironment

var sun_cycle_radians := 0.86
var daylight_factor := 1.0
var time_of_day := "Día"
var day_duration_seconds := 320.0
var night_duration_seconds := 160.0
var last_fast_travel_slot := 0
var last_boss_travel_index := -1
var sea_boundary: StaticBody3D
var sea_boundary_segment_count := 0
var blocked_sea_entries := 0
var coastal_cliff_barrier: StaticBody3D
var coastal_cliff_barrier_segment_count := 0
var tide_push_event_count := 0
var tide_rescue_count := 0
var _last_dry_player_position := Vector3.ZERO
var _last_dry_horse_position := Vector3.ZERO
var lod_distance_metres := 340.0
var mesh_lod_threshold := 1.0
var systematic_lod_enabled := true
var network_players: Node3D
var _last_exploration_time_of_day := ""


func _ready() -> void:
	_place_on_terrain(player, 0.12)
	player.spawn_position = player.global_position
	_place_on_terrain(horse, 0.12)
	horse.spawn_position = horse.global_position
	_place_on_terrain(lookout, 0.04)
	_last_dry_player_position = player.global_position
	_last_dry_horse_position = horse.global_position
	_build_sea_boundary()
	_build_coastal_cliff_barrier()
	GameSettings.lod_distance_changed.connect(_apply_lod_distance)
	_apply_lod_distance(GameSettings.lod_distance_metres)
	_setup_network_players()
	NetworkSession.world_state_received.connect(_on_network_world_state_received)
	NetworkSession.world_resource_break_requested.connect(
		_on_network_world_resource_break_requested
	)
	SaveGameManager.bind_world(self)
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration != null:
		exploration.set("handle_interact_input", false)
		exploration.call("bind_terrain", terrain)
		exploration.call("set_tracked_player", player)
		_sync_exploration_time(exploration)
	set_meta("systematic_mesh_lod", true)
	set_meta("lod_sources", "imported glTF/OBJ + explicit vegetation HLOD")


func _process(delta: float) -> void:
	if NetworkSession.is_world_authority():
		_update_sun_cycle(delta)
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration != null and time_of_day != _last_exploration_time_of_day:
		_sync_exploration_time(exploration)


func _sync_exploration_time(exploration: Node) -> void:
	_last_exploration_time_of_day = time_of_day
	exploration.call("update_time_of_day", time_of_day)


func _physics_process(delta: float) -> void:
	# Durante la pleamar no basta con recordar la última orilla: ese mismo punto
	# puede quedar cubierto unos segundos después. La zona de aviso empuja hacia
	# terreno alto antes de que llegue el agua y el rescate continúa tierra adentro
	# si el actor ya está mojado, tanto a pie como a caballo.
	var water_height := island_environment.tide_height if island_environment != null else -0.55
	var rising := island_environment.tide_rising if island_environment != null else false
	_last_dry_horse_position = _guard_actor_from_water(horse, _last_dry_horse_position, water_height, rising, delta)
	_last_dry_player_position = _guard_actor_from_water(player, _last_dry_player_position, water_height, rising, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	var slot := 0
	match pressed_key:
		KEY_0:
			if fast_travel_to_next_boss():
				get_viewport().set_input_as_handled()
			return
		KEY_5:
			slot = 1
		KEY_6:
			slot = 2
		KEY_7:
			slot = 3
		KEY_8:
			slot = 4
		KEY_9:
			slot = 5
	if slot > 0 and fast_travel_to(slot):
		get_viewport().set_input_as_handled()


func fast_travel_to(slot: int) -> bool:
	if slot < 1 or slot > FAST_TRAVEL_POINTS.size() or terrain.data == null:
		return false
	var destination: Dictionary = FAST_TRAVEL_POINTS[slot - 1]
	var point: Vector2 = destination.position
	var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	if is_nan(height):
		push_warning("No se pudo encontrar terreno para el viaje rápido %d." % slot)
		return false
	var was_mounted := player.is_mounted()
	if was_mounted:
		player.dismount()
	player.global_position = Vector3(point.x, height + 0.18, point.y)
	player.velocity = Vector3.ZERO
	player.spawn_position = player.global_position
	_last_dry_player_position = player.global_position
	last_fast_travel_slot = slot
	if camera_rig != null:
		camera_rig.snap_to_target()
	return true


func get_fast_travel_count() -> int:
	return FAST_TRAVEL_POINTS.size()


func get_fast_travel_position(slot: int) -> Vector2:
	if slot < 1 or slot > FAST_TRAVEL_POINTS.size():
		return Vector2(INF, INF)
	return FAST_TRAVEL_POINTS[slot - 1].position


func fast_travel_to_next_boss() -> bool:
	if BOSS_TRAVEL_POINTS.is_empty():
		return false
	var next_index := (last_boss_travel_index + 1) % BOSS_TRAVEL_POINTS.size()
	if not _travel_player_to_point(BOSS_TRAVEL_POINTS[next_index].position):
		return false
	last_boss_travel_index = next_index
	player.action_feedback.emit("0 · Jefe %d/%d: %s" % [
		next_index + 1,
		BOSS_TRAVEL_POINTS.size(),
		String(BOSS_TRAVEL_POINTS[next_index].name),
	])
	return true


func get_boss_travel_count() -> int:
	return BOSS_TRAVEL_POINTS.size()


func get_boss_travel_position(index: int) -> Vector2:
	if index < 0 or index >= BOSS_TRAVEL_POINTS.size():
		return Vector2(INF, INF)
	return BOSS_TRAVEL_POINTS[index].position


func _travel_player_to_point(point: Vector2) -> bool:
	if terrain.data == null:
		return false
	var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	if is_nan(height):
		return false
	if player.is_mounted():
		player.dismount()
	player.global_position = Vector3(point.x, height + 0.18, point.y)
	player.velocity = Vector3.ZERO
	player.spawn_position = player.global_position
	_last_dry_player_position = player.global_position
	if camera_rig != null:
		camera_rig.snap_to_target()
	return true


func _setup_network_players() -> void:
	network_players = Node3D.new()
	network_players.name = "NetworkPlayers"
	add_child(network_players)
	NetworkSession.roster_changed.connect(_on_network_roster_changed)
	NetworkSession.remote_state_received.connect(_on_remote_state_received)
	NetworkSession.session_ended.connect(_clear_network_players)
	_on_network_roster_changed(NetworkSession.get_roster())


func _on_network_roster_changed(roster: Dictionary) -> void:
	if network_players == null:
		return
	var local_peer_id := multiplayer.get_unique_id() if NetworkSession.is_networked() else 1
	var expected := {}
	for raw_peer_id in roster:
		var peer_id := int(raw_peer_id)
		if peer_id == local_peer_id:
			continue
		expected[peer_id] = true
		var identity := roster[raw_peer_id] as Dictionary
		var replica := network_players.get_node_or_null("Peer_%d" % peer_id) as Player
		if replica == null:
			replica = PLAYER_SCENE.instantiate() as Player
			replica.name = "Peer_%d" % peer_id
			replica.configure_network_replica(
				String(identity.get("name", "Aventurero %d" % peer_id)),
				int(identity.get("character_index", 0))
			)
			replica.set_meta("network_peer_id", peer_id)
			network_players.add_child(replica)
			replica.global_position = player.global_position + Vector3(float(peer_id % 4) * 1.2, 0.0, 1.8)
		else:
			replica.apply_identity(
				String(identity.get("name", "Aventurero %d" % peer_id)),
				int(identity.get("character_index", 0))
			)
	for child in network_players.get_children():
		var remote := child as Player
		if remote == null:
			continue
		var remote_peer_id := int(remote.get_meta("network_peer_id", 0))
		if not expected.has(remote_peer_id):
			network_players.remove_child(remote)
			remote.queue_free()


func _on_remote_state_received(
	peer_id: int,
	position: Vector3,
	yaw: float,
	velocity: Vector3,
	equipped_slot: int
) -> void:
	if network_players == null:
		return
	var replica := network_players.get_node_or_null("Peer_%d" % peer_id) as Player
	if replica == null:
		var identity := NetworkSession.get_identity(peer_id)
		replica = PLAYER_SCENE.instantiate() as Player
		replica.name = "Peer_%d" % peer_id
		replica.configure_network_replica(String(identity.name), int(identity.character_index))
		replica.set_meta("network_peer_id", peer_id)
		network_players.add_child(replica)
	replica.apply_network_state(position, yaw, velocity, equipped_slot)


func _clear_network_players() -> void:
	if network_players == null:
		return
	for child in network_players.get_children():
		network_players.remove_child(child)
		child.queue_free()


func get_tide_dry_clearance() -> float:
	return TIDE_DRY_CLEARANCE


func call_horse_to_player() -> bool:
	if horse == null or player == null or player.is_mounted():
		return false
	horse.call_to(player)
	return true


func get_local_player_save_state() -> Dictionary:
	var inventory := get_node_or_null("/root/InventoryManager")
	return {
		"name": GameSettings.player_name,
		"character_index": GameSettings.character_index,
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"yaw": player.get_network_facing_yaw(),
		"equipped_slot": player.equipped_slot,
		"inventory": inventory.call("get_save_state") if inventory != null else {},
	}


func apply_local_player_save_state(state: Dictionary) -> bool:
	var position = state.get("position", [])
	if not position is Array or (position as Array).size() != 3:
		return false
	if player.is_mounted():
		player.dismount()
	var target := Vector3(float(position[0]), float(position[1]), float(position[2]))
	if absf(target.x) > 6200.0 or absf(target.z) > 6200.0 or absf(target.y) > 1800.0:
		return false
	player.global_position = target
	player.velocity = Vector3.ZERO
	player.spawn_position = target
	_last_dry_player_position = target
	var slot := clampi(int(state.get("equipped_slot", 1)), 1, 4)
	player.call_deferred("equip_item", slot)
	if camera_rig != null:
		camera_rig.call_deferred("snap_to_target")
	return true


func get_shared_world_save_state() -> Dictionary:
	var story := get_node_or_null("RPGStoryRuntime")
	var vegetation := get_node_or_null("VegetationScatter")
	var adventure := get_node_or_null("AdventureSystem")
	return {
		"sun_cycle_radians": sun_cycle_radians,
		"tide_phase": island_environment.tide_phase if island_environment != null else 0.18,
		"horse_position": [horse.global_position.x, horse.global_position.y, horse.global_position.z],
		"story": story.call("get_save_state") if story != null else {},
		"vegetation_resources": vegetation.call("get_save_state") if vegetation != null else {},
		"adventure_resources": adventure.call("get_save_state") if adventure != null else {},
	}


func apply_shared_world_save_state(state: Dictionary) -> void:
	sun_cycle_radians = fposmod(float(state.get("sun_cycle_radians", sun_cycle_radians)), TAU)
	_update_sun_cycle(0.0)
	if island_environment != null:
		island_environment.apply_network_tide_state(float(state.get("tide_phase", island_environment.tide_phase)))
	var horse_position = state.get("horse_position", [])
	if horse_position is Array and (horse_position as Array).size() == 3 and not horse.mounted:
		horse.global_position = Vector3(float(horse_position[0]), float(horse_position[1]), float(horse_position[2]))
		horse.velocity = Vector3.ZERO
	var story := get_node_or_null("RPGStoryRuntime")
	if story != null:
		story.call_deferred("apply_save_state", state.get("story", {}))
	var vegetation := get_node_or_null("VegetationScatter")
	if vegetation != null:
		vegetation.call("apply_save_state", state.get("vegetation_resources", {}))
	var adventure := get_node_or_null("AdventureSystem")
	if adventure != null:
		adventure.call("apply_save_state", state.get("adventure_resources", {}))


func get_network_world_state() -> Dictionary:
	var wildlife := get_node_or_null("QuaterniusWildlife")
	var story := get_node_or_null("RPGStoryRuntime")
	var vegetation := get_node_or_null("VegetationScatter")
	var adventure := get_node_or_null("AdventureSystem")
	return {
		"sun_cycle_radians": sun_cycle_radians,
		"tide_phase": island_environment.tide_phase if island_environment != null else 0.18,
		"wildlife": wildlife.call("get_network_state") if wildlife != null else [],
		"enemies": story.call("get_network_enemy_state") if story != null else [],
		"vegetation_resources": vegetation.call("get_save_state") if vegetation != null else {},
		"adventure_resources": adventure.call("get_save_state") if adventure != null else {},
	}


func _on_network_world_state_received(state: Dictionary) -> void:
	if NetworkSession.session_mode != NetworkSession.SessionMode.CLIENT:
		return
	sun_cycle_radians = fposmod(float(state.get("sun_cycle_radians", sun_cycle_radians)), TAU)
	_update_sun_cycle(0.0)
	if island_environment != null:
		island_environment.apply_network_tide_state(float(state.get("tide_phase", island_environment.tide_phase)))
	var wildlife := get_node_or_null("QuaterniusWildlife")
	if wildlife != null:
		wildlife.call("apply_network_state", state.get("wildlife", []))
	var story := get_node_or_null("RPGStoryRuntime")
	if story != null:
		story.call("apply_network_enemy_state", state.get("enemies", []))
	var vegetation := get_node_or_null("VegetationScatter")
	if vegetation != null:
		vegetation.call("apply_save_state", state.get("vegetation_resources", {}))
	var adventure := get_node_or_null("AdventureSystem")
	if adventure != null:
		adventure.call("apply_save_state", state.get("adventure_resources", {}))


func _on_network_world_resource_break_requested(
	peer_id: int,
	domain: String,
	resource_id: String
) -> bool:
	## Solo se ejecuta en el anfitrión. La réplica contiene la última posición y
	## ranura de equipo recibidas de ese peer; los sistemas de recursos vuelven a
	## comprobar distancia, existencia y que la ranura 2 sea realmente el hacha.
	if (
		NetworkSession.session_mode != NetworkSession.SessionMode.HOST
		or not multiplayer.is_server()
		or network_players == null
	):
		return false
	var remote_player := network_players.get_node_or_null("Peer_%d" % peer_id) as Player
	if remote_player == null or remote_player.equipped_slot != 2:
		return false
	var accepted := false
	if domain == "vegetation":
		var vegetation := get_node_or_null("VegetationScatter")
		if vegetation != null and vegetation.has_method("network_break_resource"):
			accepted = bool(vegetation.call(
				"network_break_resource", resource_id, remote_player
			))
	elif domain == "adventure":
		var adventure := get_node_or_null("AdventureSystem")
		if adventure != null and adventure.has_method("network_break_resource"):
			accepted = bool(adventure.call(
				"network_break_resource", resource_id, remote_player
			))
	if not accepted:
		return false
	NetworkSession.broadcast_world_state_now()
	# El autoguardado periódico sigue activo, pero una alteración permanente del
	# mundo autorizada por un invitado se escribe también en este mismo instante.
	SaveGameManager.save_current_game("recurso cooperativo roto")
	return true


func _apply_lod_distance(distance_metres: float) -> void:
	lod_distance_metres = clampf(distance_metres, 180.0, 900.0)
	# Godot genera LOD para los glTF/OBJ importados y los selecciona para todo el
	# Viewport en espacio de pantalla. Una distancia mayor conserva detalle más
	# tiempo, por lo que necesita un umbral de píxeles menor.
	mesh_lod_threshold = clampf(340.0 / lod_distance_metres, 0.38, 1.90)
	get_viewport().mesh_lod_threshold = mesh_lod_threshold
	var scatter := get_node_or_null("VegetationScatter") as VegetationScatter
	if scatter != null:
		scatter.set_lod_switch_distance(lod_distance_metres)
	set_meta("lod_distance_metres", lod_distance_metres)
	set_meta("mesh_lod_threshold", mesh_lod_threshold)


func _place_on_terrain(node: Node3D, vertical_offset: float) -> void:
	var height := terrain.data.get_height(node.global_position)
	if not is_nan(height):
		node.global_position.y = height + vertical_offset


func _build_sea_boundary() -> void:
	sea_boundary = StaticBody3D.new()
	sea_boundary.name = "SeaBoundary"
	sea_boundary.collision_layer = 1
	sea_boundary.collision_mask = 0
	sea_boundary.set_meta("forbids_swimming", true)
	for index in SEA_BOUNDARY_SEGMENTS:
		var angle_a := TAU * float(index) / float(SEA_BOUNDARY_SEGMENTS)
		var angle_b := TAU * float(index + 1) / float(SEA_BOUNDARY_SEGMENTS)
		var start := Vector2(cos(angle_a), sin(angle_a)) * _coast_radius_at_angle(angle_a) * 0.920
		var finish := Vector2(cos(angle_b), sin(angle_b)) * _coast_radius_at_angle(angle_b) * 0.920
		var segment := finish - start
		var collider := CollisionShape3D.new()
		collider.name = "Shore_%03d" % index
		var shape := BoxShape3D.new()
		shape.size = Vector3(segment.length() + 4.0, 26.0, 8.0)
		collider.shape = shape
		var midpoint := (start + finish) * 0.5
		collider.position = Vector3(midpoint.x, 4.0, midpoint.y)
		collider.rotation.y = -atan2(segment.y, segment.x)
		sea_boundary.add_child(collider)
		sea_boundary_segment_count += 1
	add_child(sea_boundary)


func _build_coastal_cliff_barrier() -> void:
	coastal_cliff_barrier = StaticBody3D.new()
	coastal_cliff_barrier.name = "CoastalCliffBarrier"
	coastal_cliff_barrier.collision_layer = 1
	coastal_cliff_barrier.collision_mask = 0
	coastal_cliff_barrier.set_meta("coastal_only", true)
	coastal_cliff_barrier.set_meta("slope_threshold_degrees", CLIFF_SLOPE_DEGREES)
	coastal_cliff_barrier.set_meta("jump_proof_height", CLIFF_BARRIER_HEIGHT)
	coastal_cliff_barrier.set_meta("terrain_texture_id", CLIFF_TEXTURE_ID)
	var crests: Array[Vector3] = []
	crests.resize(CLIFF_BARRIER_SAMPLES)
	for index in CLIFF_BARRIER_SAMPLES:
		var angle := TAU * float(index) / float(CLIFF_BARRIER_SAMPLES)
		crests[index] = _find_coastal_cliff_crest(angle)
	for index in CLIFF_BARRIER_SAMPLES:
		var start := crests[index]
		var finish := crests[(index + 1) % CLIFF_BARRIER_SAMPLES]
		if is_inf(start.x) or is_inf(finish.x):
			continue
		var flat_start := Vector2(start.x, start.z)
		var flat_finish := Vector2(finish.x, finish.z)
		var segment := flat_finish - flat_start
		if segment.length() < 2.0 or segment.length() > 110.0:
			continue
		var collider := CollisionShape3D.new()
		collider.name = "CliffCrest_%03d" % index
		var shape := BoxShape3D.new()
		shape.size = Vector3(segment.length() + 3.0, absf(finish.y - start.y) + CLIFF_BARRIER_HEIGHT, 2.6)
		collider.shape = shape
		var midpoint := (flat_start + flat_finish) * 0.5
		collider.position = Vector3(midpoint.x, (start.y + finish.y) * 0.5 + CLIFF_BARRIER_HEIGHT * 0.42, midpoint.y)
		collider.rotation.y = -atan2(segment.y, segment.x)
		coastal_cliff_barrier.add_child(collider)
		coastal_cliff_barrier_segment_count += 1
	add_child(coastal_cliff_barrier)


func _find_coastal_cliff_crest(angle: float) -> Vector3:
	var direction := Vector2(cos(angle), sin(angle))
	var coast_radius := _coast_radius_at_angle(angle)
	var start_radius := coast_radius * 0.79
	var finish_radius := coast_radius * 0.965
	var sample_step := 12.0
	var best_drop := 0.0
	var best_point := Vector3(INF, INF, INF)
	var radius := start_radius
	while radius <= finish_radius:
		var point := direction * radius
		if _is_near_safe_cliff_descent(point):
			radius += sample_step
			continue
		var outer_point := direction * (radius + sample_step)
		var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
		var outer_height := terrain.data.get_height(Vector3(outer_point.x, 0.0, outer_point.y))
		if is_nan(height) or is_nan(outer_height) or height < 7.0:
			radius += sample_step
			continue
		var outward_drop := height - outer_height
		var slope_degrees := rad_to_deg(atan(maxf(outward_drop, 0.0) / sample_step))
		var texture_ids := terrain.data.get_texture_id(Vector3(point.x, 0.0, point.y))
		if slope_degrees >= CLIFF_SLOPE_DEGREES and int(texture_ids.x) == CLIFF_TEXTURE_ID and outward_drop > best_drop:
			best_drop = outward_drop
			best_point = Vector3(point.x, height, point.y)
		radius += sample_step
	return best_point


func _is_near_safe_cliff_descent(point: Vector2) -> bool:
	for route in CLIFF_SAFE_DESCENTS:
		for index in range(route.size() - 1):
			if _distance_to_segment(point, route[index], route[index + 1]) < 34.0:
				return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)


func _guard_actor_from_water(
	actor: CharacterBody3D,
	last_dry_position: Vector3,
	water_height: float,
	tide_is_rising: bool,
	delta: float
) -> Vector3:
	if actor == null or terrain.data == null:
		return last_dry_position
	var point := Vector3(actor.global_position.x, 0.0, actor.global_position.z)
	var ground_height := terrain.data.get_height(point)
	if is_nan(ground_height):
		return last_dry_position
	var clearance := ground_height - water_height
	if clearance > TIDE_WARNING_CLEARANCE:
		return actor.global_position
	# En bajamar se permite caminar por arena húmeda mientras aún exista margen.
	if not tide_is_rising and clearance > 0.72:
		return actor.global_position
	var retreat := _find_tide_retreat_target(Vector2(point.x, point.z), last_dry_position, water_height)
	if is_inf(retreat.x):
		if _is_position_dry(last_dry_position, water_height, TIDE_DRY_CLEARANCE):
			actor.global_position = last_dry_position
			actor.velocity = Vector3.ZERO
			blocked_sea_entries += 1
		return last_dry_position
	var current_flat := Vector2(actor.global_position.x, actor.global_position.z)
	var target_flat := Vector2(retreat.x, retreat.z)
	var direction := (target_flat - current_flat).normalized()
	var submerged := clearance <= 0.72
	var push_speed := TIDE_RESCUE_SPEED if submerged else TIDE_PUSH_SPEED
	var moved_flat := current_flat.move_toward(target_flat, push_speed * maxf(delta, 0.016))
	var moved_height := terrain.data.get_height(Vector3(moved_flat.x, 0.0, moved_flat.y))
	if not is_nan(moved_height):
		actor.global_position = Vector3(moved_flat.x, moved_height + 0.12, moved_flat.y)
	actor.velocity.x = direction.x * push_speed
	actor.velocity.z = direction.y * push_speed
	actor.velocity.y = 0.0
	tide_push_event_count += 1
	if submerged:
		blocked_sea_entries += 1
	var new_clearance := moved_height - water_height if not is_nan(moved_height) else clearance
	if new_clearance > TIDE_DRY_CLEARANCE:
		tide_rescue_count += 1
		return actor.global_position
	return last_dry_position


func _find_tide_retreat_target(point: Vector2, last_dry_position: Vector3, water_height: float) -> Vector3:
	if (
		_is_position_dry(last_dry_position, water_height, TIDE_WARNING_CLEARANCE)
		and point.distance_to(Vector2(last_dry_position.x, last_dry_position.z)) < 280.0
	):
		return last_dry_position
	var best_target := Vector3(INF, INF, INF)
	var best_score := -INF
	for radius in TIDE_RETREAT_RADII:
		for direction_index in 16:
			var angle := TAU * float(direction_index) / 16.0
			var candidate := point + Vector2(cos(angle), sin(angle)) * radius
			var candidate_height := terrain.data.get_height(Vector3(candidate.x, 0.0, candidate.y))
			if is_nan(candidate_height) or candidate_height <= water_height + TIDE_DRY_CLEARANCE:
				continue
			# Prioriza el refugio seco más cercano; dentro del mismo anillo vence la
			# mayor cota para que el avance de la marea no lo alcance de inmediato.
			var score := candidate_height - radius * 0.055
			if score > best_score:
				best_score = score
				best_target = Vector3(candidate.x, candidate_height + 0.12, candidate.y)
		if not is_inf(best_target.x):
			break
	return best_target


func _is_position_dry(position: Vector3, water_height: float, clearance: float) -> bool:
	var height := terrain.data.get_height(Vector3(position.x, 0.0, position.z))
	return not is_nan(height) and height > water_height + clearance


func _update_sun_cycle(delta: float) -> void:
	if not sun_cycle_enabled or sun_cycle_seconds <= 0.0:
		return
	# El arco visible del sol ocupa dos tercios del ciclo; la noche recorre su
	# media vuelta en el tercio restante. Día y noche duran exactamente 2:1.
	day_duration_seconds = sun_cycle_seconds * (2.0 / 3.0)
	night_duration_seconds = sun_cycle_seconds * (1.0 / 3.0)
	var is_day_arc := sin(sun_cycle_radians) >= 0.0
	var speed_multiplier := 0.75 if is_day_arc else 1.50
	sun_cycle_radians = fmod(sun_cycle_radians + delta * TAU / sun_cycle_seconds * speed_multiplier, TAU)
	var solar_height := sin(sun_cycle_radians)
	daylight_factor = smoothstep(-0.15, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.02, 0.34, absf(solar_height))
	sun.rotation_degrees.x = -rad_to_deg(sun_cycle_radians)
	sun.rotation_degrees.y = -122.0 + sin(sun_cycle_radians * 0.5) * 18.0
	if island_environment != null:
		island_environment.sync_celestial_sources()
	sun.light_energy = daylight_factor * lerpf(0.62, 1.35, maxf(solar_height, 0.0))
	sun.light_color = Color(1.0, 0.58, 0.32).lerp(Color(1.0, 0.93, 0.79), smoothstep(0.05, 0.62, solar_height))
	sky_fill.light_energy = lerpf(0.19, 0.22, daylight_factor)
	sky_fill.light_color = Color(0.34, 0.44, 0.78).lerp(Color(0.58, 0.7, 0.92), daylight_factor)
	if daylight_factor < 0.14:
		time_of_day = "Noche"
	elif twilight > 0.48 and sun_cycle_radians > PI * 0.5:
		time_of_day = "Atardecer"
	elif twilight > 0.48:
		time_of_day = "Amanecer"
	else:
		time_of_day = "Día"

	var environment := world_environment.environment
	if environment == null or environment.sky == null:
		return
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material == null:
		return
	var night_top := Color(0.012, 0.025, 0.10)
	var night_horizon := Color(0.075, 0.11, 0.20)
	var day_top := Color(0.16, 0.50, 0.88)
	var day_horizon := Color(0.82, 0.94, 1.0)
	var sunset_horizon := Color(1.0, 0.36, 0.12)
	sky_material.sky_top_color = night_top.lerp(day_top, daylight_factor)
	sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight_factor).lerp(sunset_horizon, twilight * 0.72)
	sky_material.ground_bottom_color = Color(0.018, 0.025, 0.045).lerp(Color(0.20, 0.31, 0.18), daylight_factor)
	# El color bajo el horizonte coincide con el mar distante para borrar la
	# línea blanca del final del mapa y reforzar la curvatura falsa del océano.
	sky_material.ground_horizon_color = Color(0.035, 0.075, 0.16).lerp(Color(0.34, 0.64, 0.76), daylight_factor).lerp(sunset_horizon, twilight * 0.28)
	environment.ambient_light_energy = lerpf(0.22, 0.66, daylight_factor)
	environment.ambient_light_color = Color(0.28, 0.36, 0.62).lerp(Color(0.91, 0.93, 0.87), daylight_factor)
	environment.tonemap_exposure = lerpf(0.84, 0.98, daylight_factor)
	for lantern in get_tree().get_nodes_in_group("night_lantern"):
		(lantern as OmniLight3D).light_energy = lerpf(4.8, 0.18, daylight_factor)
	for glow in get_tree().get_nodes_in_group("night_lantern_glow"):
		(glow as MeshInstance3D).visible = daylight_factor < 0.72


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
