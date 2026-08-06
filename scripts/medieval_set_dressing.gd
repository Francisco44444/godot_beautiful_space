class_name MedievalSetDressing
extends Node3D

## Tres pequeños núcleos, cercas, carros y ruinas hechos con módulos CC0 de
## Quaternius. Toda pieza sólida recibe una colisión simplificada.

const WALL_DOOR: PackedScene = preload("res://assets/models/medieval_village/Wall_Plaster_Door_Round.gltf")
const WALL_TIMBER: PackedScene = preload("res://assets/models/medieval_village/Wall_Plaster_WoodGrid.gltf")
const WALL_STONE: PackedScene = preload("res://assets/models/medieval_village/Wall_UnevenBrick_Straight.gltf")
const WALL_WINDOW: PackedScene = preload("res://assets/models/medieval_village/Wall_UnevenBrick_Window_Wide_Round.gltf")
const WALL_ARCH: PackedScene = preload("res://assets/models/medieval_village/Wall_Arch.gltf")
const ROOF: PackedScene = preload("res://assets/models/medieval_village/Roof_RoundTiles_4x6.gltf")
const STAIRS: PackedScene = preload("res://assets/models/medieval_village/Stairs_Exterior_Straight.gltf")
const FENCE: PackedScene = preload("res://assets/models/medieval_village/Prop_WoodenFence_Single.gltf")
const WAGON: PackedScene = preload("res://assets/models/medieval_village/Prop_Wagon.gltf")
const CRATE: PackedScene = preload("res://assets/models/medieval_village/Prop_Crate.gltf")
const VINE: PackedScene = preload("res://assets/models/medieval_village/Prop_Vine1.gltf")
const BREAKABLE_SCRIPT: Script = preload("res://scripts/breakable_prop.gd")

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@onready var terrain: Terrain3D = get_node(terrain_path) as Terrain3D

var generated_prop_count := 0
var generated_collision_count := 0
var breakable_count := 0
var generated_house_count := 0
var generated_village_count := 0


func _ready() -> void:
	_build_start_hamlet()
	_build_meadow_village()
	_build_eastern_village()
	_build_roadside_fences()
	_build_lookout_ruins()
	print(
		"MEDIEVAL SET READY: %d pueblos, %d casas, %d piezas, %d colisiones y %d cajas rompibles."
		% [generated_village_count, generated_house_count, generated_prop_count, generated_collision_count, breakable_count]
	)


func _build_start_hamlet() -> void:
	generated_village_count += 1
	_build_house(Vector2(-17.5, 171.0), 0.05, "Camino")
	_build_house(Vector2(-31.0, 158.5), 1.24, "Posada")
	_spawn_solid(WAGON, _terrain_position(Vector2(-8.0, 181.0)), -0.3, Vector3(2.0, 1.55, 4.05), Vector3(0.0, 0.75, -1.1))
	_spawn_breakable_crate(Vector2(-9.8, 179.4), 0.12)
	_spawn_breakable_crate(Vector2(-10.7, 180.3), -0.18)
	_spawn_breakable_crate(Vector2(-8.6, 178.5), 0.34)


func _build_meadow_village() -> void:
	generated_village_count += 1
	_build_house(Vector2(-105.0, 59.0), 0.32, "PradoNorte")
	_build_house(Vector2(-84.0, 60.0), -0.42, "PradoEste")
	_build_house(Vector2(-94.0, 39.5), PI - 0.08, "PradoSur")
	_spawn_solid(WALL_ARCH, _terrain_position(Vector2(-94.0, 72.0)), 0.0, Vector3(3.8, 3.4, 0.5), Vector3(0.0, 1.65, 0.0))
	_spawn_solid(WAGON, _terrain_position(Vector2(-94.0, 52.0)), 0.72, Vector3(2.0, 1.55, 4.05), Vector3(0.0, 0.75, -1.1))
	_spawn_breakable_crate(Vector2(-90.5, 50.0), 0.2)
	_spawn_breakable_crate(Vector2(-88.9, 49.4), -0.25)


func _build_eastern_village() -> void:
	generated_village_count += 1
	_build_house(Vector2(116.0, -22.0), 0.86, "EsteNorte")
	_build_house(Vector2(137.0, -33.0), -0.64, "EsteCentro")
	_build_house(Vector2(120.0, -48.0), 2.65, "EsteSur")
	_spawn_solid(WAGON, _terrain_position(Vector2(127.0, -34.0)), -1.1, Vector3(2.0, 1.55, 4.05), Vector3(0.0, 0.75, -1.1))
	_spawn_breakable_crate(Vector2(129.5, -31.5), 0.0)
	_spawn_breakable_crate(Vector2(130.8, -32.3), 0.35)


func _build_house(center: Vector2, yaw: float, house_name: String) -> void:
	var ground := _height_at(center)
	var wall_offset := Vector3(0.0, 1.5, 0.0)
	# Cada casa es un volumen cerrado de unos 6 x 8 metros. La rotación local
	# permite formar calles irregulares sin que parezcan copias alineadas.
	for z_offset in [-2.25, 0.0, 2.25]:
		_spawn_house_solid(WALL_TIMBER, center, ground, Vector2(-2.72, z_offset), yaw + PI * 0.5, yaw, Vector3(0.38, 3.1, 2.0), wall_offset)
	_spawn_house_solid(WALL_DOOR, center, ground, Vector2(2.72, 0.0), yaw - PI * 0.5, yaw, Vector3(0.38, 3.1, 2.0), wall_offset)
	_spawn_house_solid(WALL_WINDOW, center, ground, Vector2(2.72, -2.25), yaw - PI * 0.5, yaw, Vector3(0.38, 3.1, 2.0), wall_offset)
	_spawn_house_solid(WALL_TIMBER, center, ground, Vector2(2.72, 2.25), yaw - PI * 0.5, yaw, Vector3(0.38, 3.1, 2.0), wall_offset)
	for x_offset in [-1.9, 0.0, 1.9]:
		_spawn_house_solid(WALL_WINDOW, center, ground, Vector2(x_offset, -3.72), yaw, yaw, Vector3(2.0, 3.1, 0.38), wall_offset)
		_spawn_house_solid(WALL_STONE, center, ground, Vector2(x_offset, 3.72), yaw + PI, yaw, Vector3(2.0, 3.1, 0.38), wall_offset)
	_spawn_model(ROOF, Vector3(center.x, ground + 3.05, center.y), yaw, "%sRoof" % house_name)
	var vine_point := center + Vector2(2.92, 1.72).rotated(yaw)
	_spawn_model(VINE, Vector3(vine_point.x, ground + 0.12, vine_point.y), yaw - PI * 0.5, "%sVine" % house_name)
	var stair_point := center + Vector2(3.95, 0.0).rotated(yaw)
	_spawn_solid(STAIRS, _terrain_position(stair_point), yaw - PI * 0.5, Vector3(1.8, 0.8, 2.2), Vector3(0.0, 0.35, 0.0))
	generated_house_count += 1


func _spawn_house_solid(scene: PackedScene, center: Vector2, ground: float, local_point: Vector2, part_yaw: float, house_yaw: float, size: Vector3, offset: Vector3) -> void:
	var point := center + local_point.rotated(house_yaw)
	_spawn_solid(scene, Vector3(point.x, ground, point.y), part_yaw, size, offset)


func _build_roadside_fences() -> void:
	for index in 7:
		_spawn_solid(FENCE, _terrain_position(Vector2(7.4, 191.0 - index * 2.15)), 0.03, Vector3(2.05, 0.86, 0.2), Vector3(0.0, 0.42, 0.0))
	for index in 5:
		_spawn_solid(FENCE, _terrain_position(Vector2(-8.2, 146.0 - index * 2.15)), -0.04, Vector3(2.05, 0.86, 0.2), Vector3(0.0, 0.42, 0.0))
	_spawn_solid(WALL_ARCH, _terrain_position(Vector2(8.6, 158.0)), PI * 0.5, Vector3(0.25, 3.0, 2.0), Vector3(0.0, 1.5, 0.0))


func _build_lookout_ruins() -> void:
	var ruin_points := [
		[Vector2(87.0, -105.0), 0.15],
		[Vector2(89.2, -105.3), 0.15],
		[Vector2(91.0, -106.5), PI * 0.5],
		[Vector2(105.0, -103.0), -0.25],
		[Vector2(106.8, -104.1), PI * 0.5],
	]
	for item in ruin_points:
		_spawn_solid(WALL_STONE, _terrain_position(item[0]), item[1], Vector3(2.0, 3.1, 0.4), Vector3(0.0, 1.5, 0.0))
	_spawn_breakable_crate(Vector2(90.0, -101.8), 0.4)
	_spawn_breakable_crate(Vector2(104.0, -101.2), -0.25)


func _spawn_solid(scene: PackedScene, position: Vector3, yaw: float, size: Vector3, offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "MedievalSolid%03d" % generated_collision_count
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	body.rotation.y = yaw
	var model := scene.instantiate() as Node3D
	body.add_child(model)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = offset
	body.add_child(collision)
	add_child(body)
	generated_prop_count += 1
	generated_collision_count += 1
	return body


func _spawn_model(scene: PackedScene, position: Vector3, yaw: float, node_name: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = node_name
	anchor.position = position
	anchor.rotation.y = yaw
	anchor.add_child(scene.instantiate())
	add_child(anchor)
	generated_prop_count += 1
	return anchor


func _spawn_breakable_crate(point: Vector2, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BreakableCrate%02d" % breakable_count
	body.set_script(BREAKABLE_SCRIPT)
	body.collision_layer = 5
	body.collision_mask = 0
	body.position = _terrain_position(point)
	body.rotation.y = yaw
	body.add_child(CRATE.instantiate())
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.08, 1.06, 1.08)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.53
	body.add_child(collision)
	add_child(body)
	body.add_to_group("melee_target")
	breakable_count += 1
	generated_prop_count += 1
	generated_collision_count += 1
	return body


func _terrain_position(point: Vector2) -> Vector3:
	return Vector3(point.x, _height_at(point), point.y)


func _height_at(point: Vector2) -> float:
	var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	return 0.0 if is_nan(height) else height
