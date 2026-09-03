class_name AdventureSystem
extends Node3D

## Materializa las tareas del diario sobre el terreno: 23 avistamientos,
## docenas de cofres, árboles talables, vetas y reliquias. Las mallas se cachean
## para que cientos de objetos compartan geometría y LOD del importador.

const OBJ_LOADER: Script = preload("res://scripts/quaternius_obj_loader.gd")
const PICKUP_SCRIPT: Script = preload("res://scripts/adventure_pickup.gd")
const RESOURCE_SCRIPT: Script = preload("res://scripts/adventure_resource.gd")
const NATURE_ROOT := "res://assets/quaternius/store_bundle/glTF/"
const ANIMAL_ROOT := "res://assets/quaternius/ultimate_animated_animals/glTF/"
const RPG_OBJ_ROOT := "res://assets/quaternius/Ultimate RPG Items Pack - Aug 2019/OBJ/"
const ANIMAL_FILES: PackedStringArray = [
	"Alpaca.gltf", "Bull.gltf", "Cow.gltf", "Deer.gltf", "Donkey.gltf", "Fox.gltf",
	"Horse.gltf", "Horse_White.gltf", "Husky.gltf", "ShibaInu.gltf", "Stag.gltf", "Wolf.gltf",
]
const TREE_FILES: PackedStringArray = [
	"CommonTree_1.gltf", "CommonTree_2.gltf", "CommonTree_3.gltf",
	"CommonTree_4.gltf", "CommonTree_5.gltf",
]
const ROCK_FILES: PackedStringArray = ["Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf"]

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@export var player_path: NodePath = NodePath("../Player")

var generated_chest_count := 0
var generated_tree_count := 0
var generated_rock_count := 0
var generated_animal_count := 0
var generated_relic_count := 0
var generated_pickup_count := 0
var _terrain: Terrain3D
var _player: Player
var _mesh_cache: Dictionary = {}
var _inventory: Node
var _exploration: Node
var _resources_by_id: Dictionary = {}
var _destroyed_resource_ids: Dictionary = {}


func _ready() -> void:
	_terrain = get_node(terrain_path) as Terrain3D
	_player = get_node(player_path) as Player
	_inventory = get_node_or_null("/root/InventoryManager")
	_exploration = get_node_or_null("/root/ExplorationManager")
	call_deferred("_build_adventure_world")


func _build_adventure_world() -> void:
	# World enlaza primero el catálogo a Terrain3D; esperar un frame garantiza
	# que todas las posiciones ya contienen la altura transitable definitiva.
	await get_tree().process_frame
	if _exploration == null or _inventory == null:
		return
	for zone_value in _exploration.call("get_zones") as Array:
		var zone := zone_value as Dictionary
		if bool(zone.get("discovered", false)):
			continue
		match String(zone.get("requirement", "visit")):
			"open_chest":
				_spawn_chest(zone)
			"chop_tree":
				_spawn_tree(zone)
			"mine_rock":
				_spawn_rock(zone)
			"discover_animal":
				_spawn_animal(zone)
			"recover_relic":
				_spawn_relic(zone)
	print("ADVENTURE WORLD READY: %d cofres, %d árboles talables, %d vetas, %d animales y %d reliquias." % [
		generated_chest_count, generated_tree_count, generated_rock_count, generated_animal_count, generated_relic_count,
	])


func _spawn_chest(zone: Dictionary) -> void:
	var resource := _new_resource(zone, "chest")
	var mesh := _add_obj_visual(resource, RPG_OBJ_ROOT + "Chest_Closed.obj", 1.30)
	if mesh != null:
		mesh.name = "ClosedChest"
	_add_box_collision(resource, Vector3(1.8, 1.25, 1.25), Vector3(0.0, 0.62, 0.0))
	_add_marker(resource, "COFRE", Color(1.0, 0.76, 0.24))
	generated_chest_count += 1


func _spawn_tree(zone: Dictionary) -> void:
	var resource := _new_resource(zone, "tree")
	resource.required_category = "axe"
	resource.health = 3
	var variant := int(zone.get("variant", 0)) % TREE_FILES.size()
	var scene := load(NATURE_ROOT + TREE_FILES[variant]) as PackedScene
	if scene != null:
		var visual := scene.instantiate() as Node3D
		visual.name = "StandingTree"
		visual.scale = Vector3.ONE * 3.65
		resource.add_child(visual)
	_add_capsule_collision(resource, 1.72, 15.72, Vector3(0.0, 7.86, 0.0))
	_add_marker(resource, "ÁRBOL MARCADO", Color(0.52, 0.95, 0.36))
	_apply_saved_resource_state(resource)
	generated_tree_count += 1


func _spawn_rock(zone: Dictionary) -> void:
	var resource := _new_resource(zone, "rock")
	resource.required_category = "axe"
	resource.health = 3
	var variant := int(zone.get("variant", 0)) % ROCK_FILES.size()
	var scene := load(NATURE_ROOT + ROCK_FILES[variant]) as PackedScene
	if scene != null:
		var visual := scene.instantiate() as Node3D
		visual.name = "MineralRock"
		visual.scale = Vector3.ONE * 1.75
		resource.add_child(visual)
	_add_box_collision(resource, Vector3(3.2, 2.5, 3.0), Vector3(0.0, 1.15, 0.0))
	_add_marker(resource, "VETA DE RUBÍ", Color(1.0, 0.28, 0.56))
	_apply_saved_resource_state(resource)
	generated_rock_count += 1


func _spawn_animal(zone: Dictionary) -> void:
	var resource := _new_resource(zone, "animal")
	var variant := int(zone.get("variant", 0)) % ANIMAL_FILES.size()
	var scene := load(ANIMAL_ROOT + ANIMAL_FILES[variant]) as PackedScene
	if scene != null:
		var visual := scene.instantiate() as Node3D
		visual.name = "AnimalVisual"
		visual.rotation_degrees.y = float((variant * 47) % 360)
		resource.add_child(visual)
		var animator := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator != null and animator.has_animation("Idle"):
			animator.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			animator.play("Idle")
	_add_capsule_collision(resource, 0.72, 1.9, Vector3(0.0, 0.95, 0.0))
	_add_marker(resource, "FAUNA POR DESCUBRIR", Color(0.42, 0.88, 1.0))
	generated_animal_count += 1


func _spawn_relic(zone: Dictionary) -> void:
	var resource := _new_resource(zone, "relic")
	var reward_id := String(_inventory.call("get_random_reward_id", int(zone.get("variant", 0)) + 941))
	resource.reward_item_id = reward_id
	var definition := _inventory.call("get_item_definition", reward_id) as Dictionary
	var path := String(definition.get("obj_path", ""))
	if not path.is_empty():
		var mesh := _add_obj_visual(resource, path, _pickup_scale_for(reward_id) * 1.25)
		if mesh != null:
			mesh.position.y = 0.55
	_add_sphere_collision(resource, 0.75, Vector3(0.0, 0.65, 0.0))
	_add_marker(resource, "RELIQUIA", Color(0.78, 0.48, 1.0))
	generated_relic_count += 1


func _new_resource(zone: Dictionary, kind: String) -> AdventureResource:
	var resource := AdventureResource.new()
	resource.name = "%s_%s" % [kind.capitalize(), String(zone.id)]
	resource.kind = kind
	resource.zone_id = String(zone.id)
	resource.adventure_system = self
	resource.position = zone.position
	resource.rotation.y = float(int(zone.get("variant", 0)) % 17) * 0.37
	resource.set_meta("initial_transform", resource.transform)
	add_child(resource)
	_resources_by_id[resource.zone_id] = resource
	return resource


func open_chest(chest: AdventureResource, player: Player) -> void:
	var closed := chest.get_node_or_null("ClosedChest") as MeshInstance3D
	if closed != null:
		closed.visible = false
	var opened := _add_obj_visual(chest, RPG_OBJ_ROOT + "Chest_Open.obj", 1.30)
	if opened != null:
		opened.name = "OpenChest"
	_exploration.call("register_world_action", chest.zone_id, "open_chest")
	player.action_feedback.emit("Cofre abierto: recoge sus recompensas")
	var seed_value: int = absi(chest.zone_id.hash())
	spawn_pickup("Arrow", 5 + posmod(seed_value, 6), chest.global_position + Vector3(-0.75, 0.8, 0.15))
	for reward_index in 2:
		var reward_id := String(_inventory.call("get_random_reward_id", seed_value + reward_index * 137))
		spawn_pickup(reward_id, 1, chest.global_position + Vector3(0.55 + reward_index * 0.62, 0.8, -0.15))


func break_resource(resource: AdventureResource, player: Player) -> void:
	var network := get_node_or_null("/root/NetworkSession")
	if (
		network != null
		and bool(network.call("is_networked"))
		and not bool(network.call("is_world_authority"))
	):
		network.call("request_world_resource_break", "adventure", resource.zone_id)
	_destroyed_resource_ids[resource.zone_id] = true
	resource.disable_collisions()
	if resource.label != null:
		resource.label.visible = false
	if resource.kind == "tree":
		player.action_feedback.emit("Árbol talado: recoge el tronco")
		var tween := resource.create_tween()
		tween.tween_property(resource, "rotation:z", resource.rotation.z + deg_to_rad(86.0), 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			resource.visible = false
			_spawn_stump(resource.global_position)
			spawn_pickup("WoodLog", 1, resource.global_position + Vector3(1.2, 0.45, 0.0), resource.zone_id, "chop_tree")
		)
	elif resource.kind == "rock":
		player.action_feedback.emit("Veta rota: recoge los rubíes")
		var tween := resource.create_tween()
		tween.tween_property(resource, "scale", Vector3(1.35, 0.12, 1.35), 0.28).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(func() -> void:
			resource.visible = false
			# Crystal4 es el cristal rojo del pack: se usa como rubí real, no una
			# mezcla arbitraria de gemas moradas, verdes y cian.
			spawn_pickup("Crystal4", 1 + absi(resource.zone_id.hash()) % 3, resource.global_position + Vector3(0.0, 0.55, 0.0), resource.zone_id, "mine_rock")
		)
	var save_manager := get_node_or_null("/root/SaveGameManager")
	if save_manager != null:
		save_manager.call("save_current_game", "recurso roto")


func network_break_resource(resource_id: String, remote_player: Player) -> bool:
	## El anfitrión reconstruye y valida el golpe final recibido por red antes de
	## alterar una misión. Los cofres, animales y reliquias no pasan por esta ruta.
	if (
		not _is_network_host()
		or remote_player == null
		or remote_player.equipped_slot != 2
		or _destroyed_resource_ids.has(resource_id)
	):
		return false
	var resource := _resources_by_id.get(resource_id) as AdventureResource
	if resource == null or resource.broken or resource.kind not in ["tree", "rock"]:
		return false
	var delta := remote_player.global_position - resource.global_position
	if Vector2(delta.x, delta.z).length() > 7.0 or absf(delta.y) > 8.0:
		return false
	resource.health = 0
	resource.broken = true
	break_resource(resource, remote_player)
	return true


func _is_network_host() -> bool:
	var network := get_node_or_null("/root/NetworkSession")
	return network != null and bool(network.call("is_host"))


func _apply_saved_resource_state(resource: AdventureResource) -> void:
	if not _destroyed_resource_ids.has(resource.zone_id):
		return
	resource.broken = true
	resource.visible = false
	resource.disable_collisions()
	if resource.label != null:
		resource.label.visible = false


func get_save_state() -> Dictionary:
	var ids := PackedStringArray(_destroyed_resource_ids.keys())
	ids.sort()
	return {"destroyed_resource_ids": Array(ids)}


func apply_save_state(state: Dictionary) -> void:
	_destroyed_resource_ids.clear()
	for id_value in state.get("destroyed_resource_ids", []):
		_destroyed_resource_ids[String(id_value)] = true
	for resource_id in _resources_by_id:
		var resource := _resources_by_id[resource_id] as AdventureResource
		if _destroyed_resource_ids.has(resource_id):
			_apply_saved_resource_state(resource)
		else:
			resource.broken = false
			resource.visible = true
			resource.set_collisions_enabled(true)
			var initial_transform = resource.get_meta("initial_transform", null)
			if initial_transform is Transform3D:
				resource.transform = initial_transform as Transform3D
			if resource.label != null:
				resource.label.visible = true


func spawn_pickup(item_id: String, amount: int, world_position: Vector3, zone_id: String = "", action_key: String = "") -> AdventurePickup:
	var pickup := AdventurePickup.new()
	pickup.name = "Pickup_%s_%03d" % [item_id, generated_pickup_count]
	pickup.item_id = item_id
	pickup.amount = amount
	pickup.zone_id = zone_id
	pickup.completion_action = action_key
	pickup.position = world_position
	var definition := _inventory.call("get_item_definition", item_id) as Dictionary
	var path := String(definition.get("obj_path", ""))
	if item_id == "WoodLog":
		_add_log_visual(pickup)
	elif not path.is_empty():
		var mesh := _add_obj_visual(pickup, path, _pickup_scale_for(item_id))
		if mesh != null:
			mesh.position.y = 0.35
	_add_sphere_collision(pickup, 0.72, Vector3(0.0, 0.48, 0.0))
	add_child(pickup)
	generated_pickup_count += 1
	return pickup


func _spawn_stump(world_position: Vector3) -> void:
	var stump := MeshInstance3D.new()
	stump.name = "TreeStump"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.88
	mesh.height = 0.75
	mesh.radial_segments = 8
	mesh.material = _wood_material()
	stump.mesh = mesh
	stump.position = world_position + Vector3.UP * 0.36
	add_child(stump)


func _add_log_visual(parent: Node3D) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.38
	mesh.height = 1.65
	mesh.radial_segments = 8
	mesh.material = _wood_material()
	visual.mesh = mesh
	visual.rotation.z = PI * 0.5
	visual.position.y = 0.40
	parent.add_child(visual)


func _wood_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6e3d22")
	material.roughness = 0.94
	return material


func _add_obj_visual(parent: Node3D, path: String, scale_value: float) -> MeshInstance3D:
	var mesh := _mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = OBJ_LOADER.load_mesh(path)
		if mesh == null:
			return null
		_mesh_cache[path] = mesh
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.scale = Vector3.ONE * scale_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(visual)
	return visual


func _pickup_scale_for(item_id: String) -> float:
	var definition := _inventory.call("get_item_definition", item_id) as Dictionary
	var category := String(definition.get("category", "treasure"))
	match category:
		"sword", "axe", "bow", "shield":
			return 0.72
		"ammo":
			return 0.95
		"armor":
			return 0.82
		_:
			return 1.05


func _add_marker(parent: AdventureResource, text: String, color: Color) -> void:
	var marker := Label3D.new()
	marker.name = "ObjectiveMarker"
	marker.position = Vector3(0.0, 3.2 if parent.kind != "tree" else 10.8, 0.0)
	marker.text = "◆ %s" % text
	marker.font_size = 28
	marker.outline_size = 7
	marker.modulate = color
	marker.outline_modulate = Color(0.03, 0.04, 0.04, 0.92)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.visibility_range_end = 95.0
	marker.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(marker)
	parent.label = marker


func _add_box_collision(parent: Node3D, size: Vector3, offset: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = offset
	parent.add_child(collision)


func _add_capsule_collision(parent: Node3D, radius: float, height: float, offset: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position = offset
	parent.add_child(collision)


func _add_sphere_collision(parent: Node3D, radius: float, offset: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	collision.position = offset
	parent.add_child(collision)
