class_name EpicLandmark
extends Node3D

## Hito lejano del valle: pared rocosa, madera caída y una fortaleza construida
## sólo con piezas CC0 de Quaternius. La cascada y todo su sistema de agua se
## retiraron para conservar una composición terrestre más limpia.

const QUATERNIUS_ROOT := "res://assets/quaternius/store_bundle/glTF/"
const LANDMARK_CENTER := Vector2(64.0, -155.0)

@export var terrain_path: NodePath = NodePath("../Terrain3D")

@onready var epic_cliffs: Node3D = $EpicCliffs
@onready var fortress: Node3D = $Fortress

var cliff_piece_count := 0
var fortress_piece_count := 0
var landmark_ground_height := 0.0

var _terrain: Terrain3D
var _mountainside_mesh: Mesh
var _rock_face_mesh: Mesh
var _dead_tree_mesh: Mesh
var _stump_mesh: Mesh
var _fort_meshes: Dictionary = {}


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain3D
	landmark_ground_height = _height_at(LANDMARK_CENTER)
	_cache_source_meshes()
	_build_cliff_wall()
	_build_fortress()
	_build_fallen_timber()
	print(
		"EPIC LANDMARK READY: %d rocas, %d módulos de fortaleza, sin cascada."
		% [cliff_piece_count, fortress_piece_count]
	)


func _cache_source_meshes() -> void:
	_mountainside_mesh = _load_quaternius_mesh("Rock_Medium_1.gltf")
	_rock_face_mesh = _load_quaternius_mesh("Rock_Medium_2.gltf")
	_dead_tree_mesh = _load_quaternius_mesh("DeadTree_2.gltf")
	_stump_mesh = _load_quaternius_mesh("DeadTree_5.gltf")
	_fort_meshes["tower_round"] = _load_quaternius_mesh("Roof_Tower_RoundTiles.gltf")
	_fort_meshes["wall"] = _load_quaternius_mesh("Wall_UnevenBrick_Straight.gltf")
	_fort_meshes["gate"] = _load_quaternius_mesh("Wall_Arch.gltf")
	_fort_meshes["corner"] = _load_quaternius_mesh("Wall_Plaster_WoodGrid.gltf")


func _build_cliff_wall() -> void:
	var cliff_layout: Array[Array] = [
		[Vector2(8.0, -167.0), 0.18, Vector3(4.8, 4.2, 4.1), 0.0],
		[Vector2(25.0, -163.0), -0.22, Vector3(5.1, 4.6, 4.2), 0.0],
		[Vector2(43.0, -161.0), 0.12, Vector3(5.2, 4.8, 4.4), 0.0],
		[Vector2(64.0, -160.0), -0.08, Vector3(5.8, 5.0, 4.7), 0.0],
		[Vector2(85.0, -161.0), 0.19, Vector3(5.3, 4.7, 4.4), 0.0],
		[Vector2(104.0, -164.0), -0.27, Vector3(5.0, 4.4, 4.1), 0.0],
		[Vector2(122.0, -168.0), 0.24, Vector3(4.6, 4.0, 3.9), 0.0],
		[Vector2(19.0, -169.0), -0.16, Vector3(4.7, 4.1, 4.0), 7.0],
		[Vector2(38.0, -166.0), 0.23, Vector3(5.0, 4.5, 4.2), 7.5],
		[Vector2(58.0, -165.0), -0.12, Vector3(5.4, 4.8, 4.4), 8.0],
		[Vector2(78.0, -165.0), 0.18, Vector3(5.2, 4.6, 4.3), 7.6],
		[Vector2(98.0, -168.0), -0.20, Vector3(4.8, 4.3, 4.1), 7.0],
		[Vector2(32.0, -171.0), 0.16, Vector3(4.5, 3.8, 3.8), 14.0],
		[Vector2(52.0, -169.0), -0.21, Vector3(4.8, 4.1, 4.0), 14.5],
		[Vector2(73.0, -169.0), 0.10, Vector3(4.9, 4.2, 4.0), 14.8],
		[Vector2(93.0, -171.0), -0.14, Vector3(4.4, 3.8, 3.7), 14.0],
	]
	for index in cliff_layout.size():
		var entry := cliff_layout[index]
		var point: Vector2 = entry[0]
		var height := _height_at(point)
		_spawn_visual(
			epic_cliffs,
			"QuaterniusCliff%02d" % index,
			_mountainside_mesh if index % 2 == 0 else _rock_face_mesh,
			Vector3(point.x, height - 0.35 + float(entry[3]), point.y),
			Vector3(0.0, entry[1], 0.0),
			entry[2]
		)
		cliff_piece_count += 1

	_add_box_collider(epic_cliffs, "CliffCollisionCenter", Vector3(64.0, landmark_ground_height + 16.0, -160.0), Vector3(70.0, 33.0, 17.0), 0.0)
	_add_box_collider(epic_cliffs, "CliffCollisionWest", Vector3(17.0, _height_at(Vector2(17.0, -165.0)) + 13.0, -165.0), Vector3(42.0, 27.0, 16.0), 0.08)
	_add_box_collider(epic_cliffs, "CliffCollisionEast", Vector3(111.0, _height_at(Vector2(111.0, -165.0)) + 13.0, -165.0), Vector3(42.0, 27.0, 16.0), -0.08)


func _build_fortress() -> void:
	var fort_base := landmark_ground_height + 38.0
	var tower_mesh: Mesh = _fort_meshes.get("tower_round") as Mesh
	var wall_mesh: Mesh = _fort_meshes.get("wall") as Mesh
	var gate_mesh: Mesh = _fort_meshes.get("gate") as Mesh
	var corner_mesh: Mesh = _fort_meshes.get("corner") as Mesh

	_spawn_fort_piece("WestTower", corner_mesh, Vector3(46.0, fort_base, -163.0), 0.0, Vector3.ONE * 2.8)
	_spawn_fort_piece("WestTowerRoof", tower_mesh, Vector3(46.0, fort_base + 8.0, -163.0), 0.0, Vector3.ONE * 2.6)
	_spawn_fort_piece("EastTower", corner_mesh, Vector3(80.0, fort_base, -163.0), 0.0, Vector3.ONE * 2.8)
	_spawn_fort_piece("EastTowerRoof", tower_mesh, Vector3(80.0, fort_base + 8.0, -163.0), 0.0, Vector3.ONE * 2.6)
	_spawn_fort_piece("WallWest", wall_mesh, Vector3(51.0, fort_base, -158.0), PI * 0.5, Vector3.ONE * 2.8)
	_spawn_fort_piece("WallEast", wall_mesh, Vector3(72.0, fort_base, -158.0), PI * 0.5, Vector3.ONE * 2.8)
	_spawn_fort_piece("CentralGate", gate_mesh, Vector3(63.0, fort_base, -153.0), PI * 0.5, Vector3.ONE * 3.2)
	_spawn_fort_piece("RearCorner", wall_mesh, Vector3(63.0, fort_base, -171.0), 0.0, Vector3.ONE * 2.8)

	_add_box_collider(fortress, "FortressCollision", Vector3(64.0, fort_base + 5.2, -162.0), Vector3(48.0, 11.0, 20.0), 0.0)
	_add_fortress_beacon(Vector3(47.0, fort_base + 11.2, -158.0))
	_add_fortress_beacon(Vector3(79.0, fort_base + 11.2, -158.0))


func _build_fallen_timber() -> void:
	var timber_layout: Array[Array] = [
		[Vector2(47.0, -137.0), -0.18, 1.8],
		[Vector2(79.0, -134.0), 0.32, 1.55],
		[Vector2(84.0, -150.0), -0.52, 1.35],
	]
	for index in timber_layout.size():
		var entry := timber_layout[index]
		var point: Vector2 = entry[0]
		_spawn_visual(epic_cliffs, "FallenTrunk%02d" % index, _dead_tree_mesh, Vector3(point.x, _height_at(point) + 0.18, point.y), Vector3(0.0, entry[1], 0.06), Vector3.ONE * float(entry[2]))
	for index in 4:
		var point := Vector2(51.0 + index * 9.0, -130.0 - (index % 2) * 4.0)
		_spawn_visual(epic_cliffs, "TreeStump%02d" % index, _stump_mesh, Vector3(point.x, _height_at(point), point.y), Vector3(0.0, index * 1.41, 0.0), Vector3.ONE * (1.1 + index * 0.12))


func _spawn_fort_piece(piece_name: String, mesh: Mesh, piece_position: Vector3, yaw: float, piece_scale: Vector3) -> void:
	if mesh == null:
		push_warning("No se encontró el módulo de fortaleza: %s" % piece_name)
		return
	_spawn_visual(fortress, piece_name, mesh, piece_position, Vector3(0.0, yaw, 0.0), piece_scale)
	fortress_piece_count += 1


func _spawn_visual(parent: Node3D, node_name: String, mesh: Mesh, visual_position: Vector3, visual_rotation: Vector3, visual_scale: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = visual_position
	instance.rotation = visual_rotation
	instance.scale = visual_scale
	instance.visibility_range_end = 900.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_box_collider(parent: Node3D, node_name: String, body_position: Vector3, size: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = body_position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _add_fortress_beacon(beacon_position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "Beacon"
	light.position = beacon_position
	light.light_color = Color(1.0, 0.42, 0.12, 1.0)
	light.light_energy = 3.4
	light.omni_range = 18.0
	light.shadow_enabled = false
	fortress.add_child(light)

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = Color(1.0, 0.25, 0.035, 1.0)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.15, 0.02, 1.0)
	glow_material.emission_energy_multiplier = 4.5
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.32
	glow_mesh.height = 0.64
	glow_mesh.material = glow_material
	var glow := MeshInstance3D.new()
	glow.name = "BeaconGlow"
	glow.position = beacon_position
	glow.mesh = glow_mesh
	fortress.add_child(glow)


func _load_quaternius_mesh(file_name: String) -> Mesh:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := QUATERNIUS_ROOT + file_name
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el módulo Quaternius: %s (%s)" % [path, error_string(error)])
		return null
	var instance := document.generate_scene(state)
	var result := _find_mesh(instance)
	instance.free()
	return result


func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var result := _find_mesh(child)
		if result != null:
			return result
	return null


func _height_at(point: Vector2) -> float:
	if _terrain == null or _terrain.data == null:
		return landmark_ground_height
	var world_point := to_global(Vector3(point.x, 0.0, point.y))
	var height := _terrain.data.get_height(world_point)
	return landmark_ground_height if is_nan(height) else height
