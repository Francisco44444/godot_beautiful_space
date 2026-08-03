class_name MedievalSetDressing
extends Node3D

## Pequeño caserío, cercas, carro y ruinas hechos con módulos CC0 de
## Quaternius. Toda pieza sólida recibe una colisión simplificada.

const WALL_DOOR: PackedScene = preload("res://assets/models/medieval_village/Wall_Plaster_Door_Round.gltf")
const WALL_TIMBER: PackedScene = preload("res://assets/models/medieval_village/Wall_Plaster_WoodGrid.gltf")
const WALL_STONE: PackedScene = preload("res://assets/models/medieval_village/Wall_UnevenBrick_Straight.gltf")
const WALL_WINDOW: PackedScene = preload("res://assets/models/medieval_village/Wall_UnevenBrick_Window_Wide_Round.gltf")
const WALL_ARCH: PackedScene = preload("res://assets/models/medieval_village/Wall_Arch.gltf")
const ROOF: PackedScene = preload("res://assets/models/medieval_village/Roof_RoundTiles_4x6.gltf")
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


func _ready() -> void:
	_build_traveler_lodge()
	_build_roadside_fences()
	_build_lookout_ruins()
	print("MEDIEVAL SET READY: %d piezas, %d colisiones, %d cajas rompibles." % [generated_prop_count, generated_collision_count, breakable_count])


func _build_traveler_lodge() -> void:
	var center := Vector2(-14.5, 174.0)
	var ground := _height_at(center)
	# Casa de entramado: 6 x 8 m, situada fuera del corredor del sendero.
	for z_offset in [-2.25, 0.0, 2.25]:
		_spawn_solid(WALL_TIMBER, Vector3(center.x - 2.72, ground, center.y + z_offset), PI * 0.5, Vector3(0.38, 3.1, 2.0))
	_spawn_solid(WALL_DOOR, Vector3(center.x + 2.72, ground, center.y), -PI * 0.5, Vector3(0.38, 3.1, 2.0))
	_spawn_solid(WALL_WINDOW, Vector3(center.x + 2.72, ground, center.y - 2.25), -PI * 0.5, Vector3(0.38, 3.1, 2.0))
	_spawn_solid(WALL_TIMBER, Vector3(center.x + 2.72, ground, center.y + 2.25), -PI * 0.5, Vector3(0.38, 3.1, 2.0))
	for x_offset in [-1.9, 0.0, 1.9]:
		_spawn_solid(WALL_TIMBER, Vector3(center.x + x_offset, ground, center.y - 3.72), 0.0, Vector3(2.0, 3.1, 0.38))
		_spawn_solid(WALL_STONE, Vector3(center.x + x_offset, ground, center.y + 3.72), PI, Vector3(2.0, 3.1, 0.38))
	_spawn_model(ROOF, Vector3(center.x, ground + 3.05, center.y), 0.0, "LodgeRoof")
	_spawn_model(VINE, Vector3(center.x + 2.93, ground + 0.12, center.y + 1.75), -PI * 0.5, "LodgeVine")

	_spawn_solid(WAGON, _terrain_position(Vector2(-7.8, 181.5)), -0.3, Vector3(2.0, 1.55, 4.05), Vector3(0.0, 0.75, -1.1))
	_spawn_breakable_crate(Vector2(-9.8, 179.4), 0.12)
	_spawn_breakable_crate(Vector2(-10.7, 180.3), -0.18)
	_spawn_breakable_crate(Vector2(-8.6, 178.5), 0.34)


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
	body.add_to_group("sword_target")
	breakable_count += 1
	generated_prop_count += 1
	generated_collision_count += 1
	return body


func _terrain_position(point: Vector2) -> Vector3:
	return Vector3(point.x, _height_at(point), point.y)


func _height_at(point: Vector2) -> float:
	var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	return 0.0 if is_nan(height) else height
