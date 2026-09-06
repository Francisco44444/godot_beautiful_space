class_name VillageFolk
extends Node3D

## Calles conectadas más colisión real. Muestreamos sólo la cota del terreno:
## Terrain3D no genera suelo físico lejos del jugador, pero los muros sí existen.
const CHARACTER_ROOT := "res://assets/quaternius/ultimate_animated_characters/glTF/"
const APPEARANCE: Script = preload("res://scripts/medieval_villager_visual.gd")
const ITEMS_ROOT := "res://assets/quaternius/Ultimate RPG Items Pack - Aug 2019/OBJ/"
const NEIGHBOUR_NAMES: PackedStringArray = ["Bruna", "Teodor", "Mailén", "Gorka", "Sabela", "Arnau", "Lucía", "Beltrán", "Ondiz", "Roque", "Xiana", "Fermín", "Aldara", "Cosme"]
enum Trade { NEIGHBOUR, PORTER, MERCHANT, SMITH, CARPENTER, HERBALIST, RIDER }
const NODE_SPACING := 20.0
const WALK_SPEED := 1.45
const CARRY_SPEED := 1.15
const ARRIVE_RADIUS := 0.55
const DOOR_STANDOFF := 3.0
const AVOID_RADIUS := 2.0
const AVOID_STRENGTH := 1.1
const WORKER_TRADES: Array[int] = [Trade.SMITH, Trade.CARPENTER, Trade.HERBALIST, Trade.MERCHANT]

@export var folk_count := 18
var _terrain: Node
var _street_nodes := PackedVector3Array()
var _door_nodes := PackedVector3Array()
var _walkers: Array[VillageNeighbour] = []
var _rng := RandomNumberGenerator.new()
var _graph := AStar3D.new()
var _graph_ready := false
var _center := Vector2.ZERO
var _yaw := 0.0
var _network_clock := 0.0
var generated_folk_count := 0
var generated_node_count := 0


func build(terrain: Node, center: Vector2, yaw: float, radius: float, keep_out: Rect2) -> void:
	_terrain = terrain
	_center = center
	_yaw = yaw
	_rng.seed = hash(Vector2i(int(center.x), int(center.y)))
	_build_graph(center, yaw, radius, keep_out)
	generated_node_count = _street_nodes.size()
	for index in folk_count:
		_spawn_walker(index)
	set_meta("folk_count", generated_folk_count)
	set_meta("graph_node_count", generated_node_count)
	set_meta("physics_wall_collision", true)
	set_meta("medieval_occupations", WORKER_TRADES.size())
	call_deferred("_finish_graph")


func collect_doors(village_root: Node) -> void:
	for child in village_root.get_children():
		if not child is StaticBody3D:
			continue
		var doorway := child.get_node_or_null("Doorway") as Node3D
		if doorway == null or _street_nodes.is_empty():
			continue
		var point := doorway.global_position
		if point.distance_to(_nearest(_street_nodes, point)) > NODE_SPACING * 3.0:
			continue
		var approach := child.get_node_or_null("ApproachPoint") as Node3D
		if approach != null:
			point = approach.global_position
		else:
			point += (child as Node3D).global_basis.z.normalized() * DOOR_STANDOFF
			point.y = _height(Vector2(point.x, point.z))
		_door_nodes.append(point)


func _build_graph(center: Vector2, yaw: float, radius: float, keep_out: Rect2) -> void:
	var points: Dictionary = {}
	for segment in VillageLayout.street_segments():
		var start: Vector2 = segment[0]
		var finish: Vector2 = segment[1]
		var steps := ceili(start.distance_to(finish) / 10.0)
		for step in range(steps + 1):
			var local := start.lerp(finish, float(step) / maxi(steps, 1))
			if keep_out.grow(2).has_point(local):
				continue
			var point := center + local.rotated(yaw)
			var key := Vector2i(roundi(point.x), roundi(point.y))
			if not points.has(key):
				points[key] = true
				_street_nodes.append(Vector3(point.x, _height(point), point.y))

func _finish_graph() -> void:
	await get_tree().physics_frame
	for index in _street_nodes.size():
		_graph.add_point(index, _street_nodes[index])
	for first in _street_nodes.size():
		for second in range(first + 1, _street_nodes.size()):
			if _street_nodes[first].distance_to(_street_nodes[second]) > NODE_SPACING * 1.12:
				continue
			if _clear_segment(_street_nodes[first], _street_nodes[second]):
				_graph.connect_points(first, second)
	for door in _door_nodes:
		var nearest_id := _graph.get_closest_point(door)
		if nearest_id < 0 or not _clear_segment(_graph.get_point_position(nearest_id), door):
			continue
		var id := _graph.get_available_point_id()
		_graph.add_point(id, door)
		_graph.connect_points(nearest_id, id)
	generated_node_count = _graph.get_point_count()
	set_meta("graph_node_count", generated_node_count)
	_graph_ready = true
	for walker in _walkers:
		if walker.work_station == null:
			walker.route = _pick_route(walker)


func _clear_segment(from: Vector3, to: Vector3) -> bool:
	# Un corredor de 1,44 m: ni personas ni caballo recortan las esquinas.
	var right := Vector3(to.z - from.z, 0, from.x - to.x).normalized() * 0.72
	for offset in [Vector3.ZERO, right, -right]:
		var query := PhysicsRayQueryParameters3D.create(from + offset + Vector3.UP, to + offset + Vector3.UP, 1)
		var people: Array[RID] = []
		for walker in _walkers:
			people.append(walker.get_rid())
		query.exclude = people
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _spawn_walker(index: int) -> void:
	if _street_nodes.is_empty():
		return
	var trade: int = WORKER_TRADES[index] if index < WORKER_TRADES.size() else (Trade.RIDER if index == 4 else (Trade.PORTER if index % 4 == 0 else Trade.NEIGHBOUR))
	var walker := VillageNeighbour.new()
	walker.name = "Vecino%02d" % index
	walker.setup(trade, _neighbour_name(index), index)
	var start := _street_nodes[posmod(index * 7, _street_nodes.size())]
	var group := index / _street_nodes.size()
	var lane := float(group) * 1.6 - 1.6
	walker.position = start + Vector3(lane, 0.0, 0.55 + float(group) * 1.2)
	add_child(walker)
	var pool := _trade_characters(trade)
	var file := pool[posmod(index * 7 + index / 3, pool.size())]
	var visual := (load(CHARACTER_ROOT + file) as PackedScene).instantiate() as Node3D
	visual.name = "VecinoVisual"
	visual.scale = Vector3.ONE * 0.95
	visual.set_meta("character_file", file)
	walker.add_child(visual)
	walker.visual = visual
	APPEARANCE.apply(visual, index, APPEARANCE.player_skin(self))
	walker.animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if walker.animator != null:
		for animation_name in ["Idle", "Walk", "Walk_Carry", "Punch", "PickUp"]:
			if walker.animator.has_animation(animation_name):
				walker.animator.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	if trade == Trade.RIDER:
		_build_rider(walker)
	elif index < WORKER_TRADES.size():
		_build_work_station(walker, index)
	elif trade == Trade.PORTER:
		var crate := (load("res://assets/models/medieval_village/Prop_Crate.gltf") as PackedScene).instantiate() as Node3D
		_normalize_prop(crate, 0.62)
		visual.add_child(crate)
		crate.position = Vector3(0, 0.93, 0.49)
		crate.name = "CargaDeGrano"
	walker.play("Idle")
	_walkers.append(walker)
	generated_folk_count += 1


static func _trade_characters(trade: int) -> PackedStringArray:
	match trade:
		Trade.RIDER:
			return ["Knight_Male.gltf"]
		Trade.MERCHANT:
			return ["Pirate_Male.gltf", "Pirate_Female.gltf"]
		Trade.HERBALIST:
			return ["Viking_Female.gltf"]
		Trade.SMITH:
			return ["Viking_Female.gltf"]
		Trade.CARPENTER:
			return ["Viking_Male.gltf"]
		_:
			return ["Viking_Male.gltf", "Viking_Female.gltf", "Pirate_Male.gltf", "Pirate_Female.gltf", "Wizard.gltf", "Witch.gltf", "Elf.gltf", "Knight_Golden_Female.gltf"]


static func _neighbour_name(index: int) -> String:
	return NEIGHBOUR_NAMES[posmod(index, NEIGHBOUR_NAMES.size())]


func _pick_route(walker: VillageNeighbour) -> Array[Vector3]:
	var route: Array[Vector3] = []
	if not _graph_ready:
		return route
	var start := _graph.get_closest_point(walker.global_position)
	var ids := _graph.get_point_ids()
	for _attempt in 12:
		var destination := ids[_rng.randi_range(0, ids.size() - 1)]
		if walker.trade != Trade.PORTER and destination >= _street_nodes.size():
			continue
		if start == destination:
			continue
		var path := _graph.get_point_path(start, destination)
		if path.size() < 2:
			continue
		for point in path:
			route.append(point)
		return route
	return route


func _physics_process(delta: float) -> void:
	if not _graph_ready:
		return
	var network := get_node_or_null("/root/NetworkSession")
	if network != null and not bool(network.call("is_world_authority")):
		for walker in _walkers:
			if walker.has_network_state:
				walker.position = walker.position.lerp(walker.network_position, minf(delta * 12.0, 1.0))
				walker.rotation.y = lerp_angle(walker.rotation.y, walker.network_yaw, minf(delta * 12.0, 1.0))
		return
	for walker in _walkers:
		_advance(walker, delta)
	_network_clock += delta
	if _network_clock >= 0.15 and network != null and bool(network.call("is_host")) and not multiplayer.get_peers().is_empty():
		_network_clock = 0.0
		var state: Array = []
		for walker in _walkers:
			state.append([walker.position, walker.rotation.y, walker.current_action])
		_receive_folk_state.rpc(state)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_folk_state(state: Array) -> void:
	for index in mini(state.size(), _walkers.size()):
		var walker := _walkers[index]
		var entry: Array = state[index]
		if entry.size() != 3 or not entry[0] is Vector3:
			continue
		walker.network_position = entry[0]
		walker.network_yaw = float(entry[1])
		if not walker.has_network_state:
			walker.position = walker.network_position
			walker.rotation.y = walker.network_yaw
		walker.has_network_state = true
		walker.play(String(entry[2]))


func _advance(walker: VillageNeighbour, delta: float) -> void:
	if walker.pause_left > 0.0:
		walker.pause_left -= delta
		return
	if walker.work_station != null:
		walker.rotation.y = walker.work_station.rotation.y
		walker.work_pose.active = true
		walker.play("Idle")
		return
	if walker.route.is_empty():
		_arrive(walker)
		return
	var target: Vector3 = walker.route[0]
	var flat := Vector3(target.x - walker.global_position.x, 0.0, target.z - walker.global_position.z)
	if flat.length() < ARRIVE_RADIUS:
		walker.route.remove_at(0)
		if walker.route.is_empty():
			_arrive(walker)
		return
	var direction := (flat.normalized() + _avoidance(walker)).normalized()
	var speed := 2.4 if walker.trade == Trade.RIDER else (CARRY_SPEED if walker.trade == Trade.PORTER else WALK_SPEED)
	var step := direction * minf(speed * delta, flat.length())
	var before := walker.global_position
	var next := before + step
	step.y = clampf(_height(Vector2(next.x, next.z)) - before.y, -0.25, 0.25)
	var collision := walker.move_and_collide(step)
	if collision != null:
		walker.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	if before.distance_to(walker.global_position) < speed * delta * 0.15:
		walker.blocked_seconds += delta
		if walker.blocked_seconds > 1.5:
			walker.route = _pick_route(walker)
			walker.blocked_seconds = 0.0
	else:
		walker.blocked_seconds = 0.0
	walker.rotation.y = lerp_angle(walker.rotation.y, atan2(direction.x, direction.z), minf(delta * 6.0, 1.0))
	walker.play("Walk_Carry" if walker.trade == Trade.PORTER else "Walk")


func _avoidance(walker: VillageNeighbour) -> Vector3:
	var push := Vector3.ZERO
	for other in _walkers:
		if other == walker:
			continue
		var away := walker.global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > AVOID_RADIUS or distance < 0.001:
			continue
		push += away.normalized() * (1.0 - distance / AVOID_RADIUS) * AVOID_STRENGTH
	return push.limit_length(0.55)


func _arrive(walker: VillageNeighbour) -> void:
	walker.play("PickUp" if walker.trade == Trade.PORTER else "Idle")
	walker.pause_left = _rng.randf_range(1.2, 3.5)
	walker.route = _pick_route(walker)


func _build_rider(walker: VillageNeighbour) -> void:
	var horse := (load("res://assets/quaternius/ultimate_animated_animals/glTF/Horse.gltf") as PackedScene).instantiate() as Node3D
	horse.name = "CaballoDeLaGuardia"
	horse.scale = Vector3.ONE * 1.05
	walker.add_child(horse)
	walker.horse_animator = horse.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for action in ["Walk", "Idle"]:
		walker.horse_animator.get_animation(action).loop_mode = Animation.LOOP_LINEAR
	walker.visual.position = Vector3(0, 2.65, 0.08)
	if walker.animator.has_animation("SitDown"):
		walker.animator.play("SitDown")
		walker.animator.seek(walker.animator.get_animation("SitDown").length, true)
		walker.animator.pause()
	var skeletons := walker.visual.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var reins: SkeletonModifier3D = preload("res://scripts/village_rider_pose.gd").new()
		reins.name = "ManosEnLasRiendas"
		reins.set("left_target", Vector3(0.20, 1.24, 0.52))
		reins.set("right_target", Vector3(-0.20, 1.24, 0.52))
		reins.set("left_influence", 1.0)
		reins.set("right_influence", 1.0)
		skeletons[0].add_child(reins)
	walker.set_meta("mounted_patrol", true)


func _build_work_station(walker: VillageNeighbour, index: int) -> void:
	var station := Node3D.new()
	station.name = "Oficio_%s" % walker.trade_label()
	add_child(station)
	var corners: Array[Vector2] = [Vector2(-11, -11), Vector2(11, -11), Vector2(-11, 11), Vector2(11, 11)]
	var point := _center + corners[index].rotated(_yaw)
	station.global_position = Vector3(point.x, _height(point), point.y)
	station.rotation.y = -_yaw
	walker.work_station = station
	walker.global_position = station.to_global(Vector3(0, 0, -1.5))
	walker.global_position.y = _height(Vector2(walker.global_position.x, walker.global_position.z))
	walker.rotation.y = station.rotation.y
	var tabletop := StaticBody3D.new()
	tabletop.name = "BancoDeTrabajo"
	tabletop.collision_layer = 1
	station.add_child(tabletop)
	var furniture := "Anvil_Log" if walker.trade == Trade.SMITH else ("Workbench" if walker.trade == Trade.CARPENTER else "Table_Large")
	var furniture_path := "res://assets/quaternius/Fantasy Props MegaKit/Exports/glTF/%s.gltf" % furniture
	var bench := (load(furniture_path) as PackedScene).instantiate() as Node3D
	bench.name = furniture
	tabletop.add_child(bench)
	var bounds := _prop_bounds(bench)
	var furniture_scale := 1.05 / maxf(bounds.size.y, 0.01)
	bench.scale = Vector3.ONE * furniture_scale
	bench.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * furniture_scale
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(bounds.size.x * furniture_scale, 1.05, bounds.size.z * furniture_scale)
	collider.shape = shape
	collider.position.y = 0.525
	tabletop.add_child(collider)
	walker.global_position = station.to_global(Vector3(0, 0, -shape.size.z * 0.5 - 0.58))
	walker.global_position.y = _height(Vector2(walker.global_position.x, walker.global_position.z))
	var work_skeletons := walker.visual.find_children("*", "Skeleton3D", true, false)
	if not work_skeletons.is_empty():
		walker.work_pose = preload("res://scripts/village_work_pose.gd").new()
		walker.work_pose.set("trade", walker.trade)
		work_skeletons[0].add_child(walker.work_pose)
	var items: Array[String] = ["Sword", "Axe_small", "Potion1_Filled", "Coin"]
	_add_item(station, items[index], Vector3(0.0, 1.08, 0.0), 0.65)
	if walker.trade == Trade.HERBALIST:
		_add_item(station, "Potion3_Filled", Vector3(-0.75, 1.08, 0.0), 0.32)
		_add_item(station, "Book1_Open", Vector3(0.65, 1.08, 0.0), 0.48)
	elif walker.trade == Trade.MERCHANT:
		_add_item(station, "Parchment", Vector3(0.75, 1.08, 0.0), 0.5)
		_add_item(station, "Backpack", Vector3(-0.65, 1.05, 0.0), 0.6)
	else:
		var skeletons := walker.visual.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			var skeleton := skeletons[0] as Skeleton3D
			if skeleton.find_bone("Fist.R") >= 0:
				var socket := BoneAttachment3D.new()
				socket.name = "HerramientaDelOficio"
				socket.bone_name = "Fist.R"
				skeleton.add_child(socket)
				_add_item(socket, "Hammer_Double" if walker.trade == Trade.SMITH else "Axe_small", Vector3.ZERO, 0.62)
	var label := Label3D.new()
	label.text = "%s · %s" % [walker.display_name, walker.trade_label()]
	label.font_size = 26
	label.outline_size = 5
	label.position.y = 2.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 22.0
	station.add_child(label)


func _add_item(parent: Node3D, item: String, at: Vector3, size: float) -> void:
	var path := ITEMS_ROOT + item + ".obj"
	if not ResourceLoader.exists(path):
		return
	var prop := MeshInstance3D.new()
	prop.name = item
	prop.mesh = load(path) as Mesh
	if prop.mesh == null:
		return
	parent.add_child(prop)
	var bounds := prop.mesh.get_aabb()
	var factor := size / maxf(bounds.size.length(), 0.001)
	prop.scale = Vector3.ONE * factor
	prop.position = at - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor


func _normalize_prop(prop: Node3D, size: float) -> void:
	var bounds := AABB()
	for node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			bounds = bounds.merge(mesh.transform * mesh.mesh.get_aabb())
	prop.scale = Vector3.ONE * (size / maxf(bounds.size.length(), 0.001))


func _prop_bounds(prop: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := (prop.global_transform.affine_inverse() * mesh.global_transform) * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _nearest(points: PackedVector3Array, to: Vector3) -> Vector3:
	var best := to
	var best_distance := INF
	for point in points:
		var distance := point.distance_to(to)
		if distance < best_distance:
			best_distance = distance
			best = point
	return best


func _height(point: Vector2) -> float:
	if _terrain == null:
		return 0.0
	var data = _terrain.get("data")
	if data == null:
		return 0.0
	var height: float = data.get_height(Vector3(point.x, 0.0, point.y))
	return 0.0 if is_nan(height) else height
