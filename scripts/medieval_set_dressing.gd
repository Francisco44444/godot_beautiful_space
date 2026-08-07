class_name MedievalSetDressing
extends Node3D

## Villas y caseríos Quaternius a escala habitable. Las viviendas tienen entre
## dos y tres plantas, fachada de hastial cerrada y acceso a ras del terreno.

const ROOT := "res://assets/quaternius/store_bundle/glTF/"
const HOUSE_SCALE := Vector3(1.35, 1.18, 1.35)
const WALL: PackedScene = preload(ROOT + "Wall_Plaster_Straight.gltf")
const WALL_DOOR: PackedScene = preload(ROOT + "Wall_Plaster_Door_Round.gltf")
const WALL_WINDOW: PackedScene = preload(ROOT + "Wall_Plaster_Window_Wide_Round.gltf")
const WALL_TIMBER: PackedScene = preload(ROOT + "Wall_Plaster_WoodGrid.gltf")
const WALL_STONE: PackedScene = preload(ROOT + "Wall_UnevenBrick_Straight.gltf")
const WALL_ARCH: PackedScene = preload(ROOT + "Wall_Arch.gltf")
const ROOF_8X14: PackedScene = preload(ROOT + "Roof_RoundTiles_8x14.gltf")
const ROOF_FRONT_8: PackedScene = preload(ROOT + "Roof_Front_Brick8.gltf")
const BALCONY: PackedScene = preload(ROOT + "Balcony_Simple_Straight.gltf")
const FLOOR_BRICK: PackedScene = preload(ROOT + "Floor_UnevenBrick.gltf")
const TOWER_ROOF: PackedScene = preload(ROOT + "Roof_Tower_RoundTiles.gltf")
const FENCE: PackedScene = preload(ROOT + "Prop_WoodenFence_Single.gltf")
const WAGON: PackedScene = preload(ROOT + "Prop_Wagon.gltf")
const CRATE: PackedScene = preload(ROOT + "Prop_Crate.gltf")
const VINE: PackedScene = preload(ROOT + "Prop_Vine1.gltf")
const CHIMNEY: PackedScene = preload(ROOT + "Prop_Chimney.gltf")
const BREAKABLE_SCRIPT: Script = preload("res://scripts/breakable_prop.gd")

const VILLAGES: Array = [
	{"name": "Puerto Alba", "center": Vector2(0, 190), "yaw": 0.08, "castle": false},
	{"name": "Villa Robledal", "center": Vector2(-1450, 650), "yaw": 0.42, "castle": true},
	{"name": "Aldea de la Bruma", "center": Vector2(-2200, -900), "yaw": -0.36, "castle": false},
	{"name": "Bastion del Este", "center": Vector2(2260, -980), "yaw": 0.72, "castle": true},
	{"name": "Oasis Dorado", "center": Vector2(2180, 1880), "yaw": -0.25, "castle": false},
	{"name": "Castillo Boreal", "center": Vector2(-420, -2150), "yaw": 0.0, "castle": true},
]
const RURAL_HAMLETS: Array = [
	{"name": "Caserio del Molino", "center": Vector2(-720, 740), "yaw": 0.18},
	{"name": "Granjas de Robledal", "center": Vector2(-1680, 310), "yaw": -0.26},
	{"name": "Las Tres Encinas", "center": Vector2(-940, -1110), "yaw": 0.52},
	{"name": "Caserio del Puente", "center": Vector2(970, -170), "yaw": -0.38},
	{"name": "Viñedos del Sol", "center": Vector2(1510, 830), "yaw": 0.28},
	{"name": "Fincas del Este", "center": Vector2(1720, -1030), "yaw": -0.62},
	{"name": "Refugio Umbrio", "center": Vector2(-1040, -1900), "yaw": 0.12},
	{"name": "Puesto Boreal", "center": Vector2(910, -2360), "yaw": 0.46},
]

@export var terrain_path: NodePath = NodePath("../Terrain3D")
@onready var terrain: Terrain3D = get_node(terrain_path) as Terrain3D

var generated_prop_count := 0
var generated_collision_count := 0
var breakable_count := 0
var generated_house_count := 0
var generated_village_count := 0
var generated_castle_count := 0
var generated_light_count := 0
var generated_enterable_house_count := 0
var generated_hamlet_count := 0
var generated_three_storey_count := 0
var generated_roof_facade_count := 0
var _foundation_material: StandardMaterial3D


func _ready() -> void:
	_foundation_material = StandardMaterial3D.new()
	_foundation_material.albedo_color = Color(0.46, 0.48, 0.43, 1.0)
	_foundation_material.roughness = 0.96
	for village in VILLAGES:
		_build_village(village)
	for hamlet in RURAL_HAMLETS:
		_build_hamlet(hamlet)
	_build_starting_props()
	print("MEDIEVAL WORLD READY: %d villas, %d caseríos, %d casas accesibles (%d de tres pisos), %d castillos, %d piezas y %d colisiones." % [generated_village_count, generated_hamlet_count, generated_house_count, generated_three_storey_count, generated_castle_count, generated_prop_count, generated_collision_count])


func _build_village(spec: Dictionary) -> void:
	var center: Vector2 = spec.center
	var yaw: float = spec.yaw
	var village_name: String = spec.name
	generated_village_count += 1
	var layout: Array[Vector3] = [
		Vector3(-45, -30, -0.42), Vector3(45, -30, 0.38),
		Vector3(-50, 30, -0.12), Vector3(50, 32, 0.18),
		Vector3(0, 58, PI),
	]
	for index in layout.size():
		var item := layout[index]
		var local := Vector2(item.x, item.y).rotated(yaw)
		var house_center := center + local
		var house_yaw := yaw + item.z
		if index == 4:
			_build_hall(house_center, house_yaw, "%sHall" % village_name.validate_node_name())
		else:
			_build_cottage(house_center, house_yaw, "%sHouse%02d" % [village_name.validate_node_name(), index])
	# Puerto Alba deja libre el eje de salida para caminar y galopar; las otras
	# villas sí delimitan su plaza con cercas y carros.
	if center.distance_to(Vector2(0.0, 190.0)) > 10.0:
		_build_village_street(center, yaw)
	_add_village_lights(center, yaw)
	if bool(spec.castle):
		var castle_offset := Vector2(125, 3).rotated(yaw)
		_build_castle(center + castle_offset, yaw, village_name)


func _build_cottage(center: Vector2, yaw: float, house_name: String) -> void:
	_build_large_house(center, yaw, house_name, false, 2)


func _build_hall(center: Vector2, yaw: float, house_name: String) -> void:
	_build_large_house(center, yaw, house_name, true, 3)


func _build_hamlet(spec: Dictionary) -> void:
	var center: Vector2 = spec.center
	var yaw: float = spec.yaw
	var hamlet_name: String = spec.name
	var layout: Array[Vector3] = [
		Vector3(-23.0, -10.0, -0.28),
		Vector3(23.0, -9.0, 0.31),
		Vector3(0.0, 24.0, PI),
	]
	for index in layout.size():
		var item := layout[index]
		var local := Vector2(item.x, item.y).rotated(yaw)
		var floors := 3 if index == 2 and generated_hamlet_count % 2 == 0 else 2
		_build_large_house(
			center + local,
			yaw + item.z,
			"%sRuralHouse%02d" % [hamlet_name.validate_node_name(), index],
			floors == 3,
			floors
		)
	_add_village_lights(center, yaw)
	generated_hamlet_count += 1


func _build_large_house(center: Vector2, yaw: float, house_name: String, is_hall: bool, floors: int) -> void:
	var body := _create_building_body(center, yaw, house_name)
	body.scale = HOUSE_SCALE
	# El suelo interior se alinea con la cota real justo delante de la puerta,
	# no con el centro de la parcela: se entra andando, sin salto ni escalón.
	var door_world := body.to_global(Vector3(-1.0, 0.0, 7.65))
	var door_ground := _height_at(Vector2(door_world.x, door_world.z))
	body.position.y = door_ground - 0.34 * HOUSE_SCALE.y
	body.set_meta("enterable", true)
	body.set_meta("footprint", Vector2(8.0 * HOUSE_SCALE.x, 14.0 * HOUSE_SCALE.z))
	body.set_meta("door_width", 2.0 * HOUSE_SCALE.x)
	body.set_meta("floor_count", floors)
	body.set_meta("threshold_height", 0.0)
	_add_foundation(body, Vector3(8.5, 0.34, 14.5), true)

	# Pavimento Quaternius continuo: 28 losas de 2 x 2 m dentro de la casa.
	for x in [-3.0, -1.0, 1.0, 3.0]:
		for z in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
			_add_part(body, FLOOR_BRICK, Vector3(x, 0.35, z), 0.0)

	# Dos o tres pisos de módulos de tres metros. La pieza de puerta se renderiza, pero
	# deliberadamente no recibe BoxShape: el hueco puede cruzarse de verdad.
	for level in floors:
		var base_y := 0.25 + level * 3.1
		for z in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
			var left_scene := WALL_STONE if is_hall and level == 0 else (WALL_TIMBER if int(z) % 4 == 0 else WALL)
			_add_wall_part(body, left_scene, Vector3(-4.0, base_y, z), PI * 0.5)
			_add_wall_part(body, WALL_WINDOW if level == 1 or int(z) % 4 == 0 else WALL, Vector3(4.0, base_y, z), -PI * 0.5)
		for x in [-3.0, -1.0, 1.0, 3.0]:
			if level == 0 and x == -1.0:
				_add_wall_part(body, WALL_DOOR, Vector3(x, base_y, 7.0), PI, false)
			else:
				_add_wall_part(body, WALL_WINDOW if level == 1 or absf(x) == 1.0 else WALL, Vector3(x, base_y, 7.0), PI)
			_add_wall_part(body, WALL_TIMBER if level == 1 else WALL_STONE, Vector3(x, base_y, -7.0), 0.0)

	var roof_y := 0.38 + floors * 3.1
	_add_part(body, ROOF_8X14, Vector3(0.0, roof_y, 0.0), 0.0)
	# Los hastiales específicos de 8 m cierran la fachada triangular que antes
	# quedaba abierta bajo las dos vertientes del tejado.
	_add_part(body, ROOF_FRONT_8, Vector3(0.0, roof_y, 7.0), PI)
	_add_part(body, ROOF_FRONT_8, Vector3(0.0, roof_y, -7.0), 0.0)
	generated_roof_facade_count += 2
	_add_part(body, CHIMNEY, Vector3(-2.6, roof_y + 0.06, -3.4), 0.0)
	_add_part(body, VINE, Vector3(4.06, 0.42, 2.4), -PI * 0.5)
	for x in [1.0, 3.0]:
		_add_part(body, BALCONY, Vector3(x, 3.42, 7.12), PI)

	var doorway := Node3D.new()
	doorway.name = "Doorway"
	doorway.position = Vector3(-1.0, 1.15, 7.65)
	body.add_child(doorway)
	var interior := Node3D.new()
	interior.name = "InteriorPoint"
	interior.position = Vector3(-1.0, 1.15, 4.25)
	body.add_child(interior)
	var interior_light := OmniLight3D.new()
	interior_light.name = "InteriorWarmLight"
	interior_light.position = Vector3(0.0, 3.0, 0.0)
	interior_light.light_color = Color(1.0, 0.48, 0.17)
	interior_light.light_energy = 0.18
	interior_light.omni_range = 16.0
	interior_light.shadow_enabled = false
	interior_light.add_to_group("night_lantern")
	body.add_child(interior_light)
	generated_light_count += 1
	generated_house_count += 1
	generated_enterable_house_count += 1
	if floors == 3:
		generated_three_storey_count += 1


func _build_castle(center: Vector2, yaw: float, village_name: String) -> void:
	var ground := _height_at(center)
	var root := Node3D.new()
	root.name = "%sCastle" % village_name.validate_node_name()
	root.position = Vector3(center.x, ground, center.y)
	root.rotation.y = yaw
	add_child(root)
	# Patio 32x26: muros sobre la misma cuadrícula de 2 m y una puerta central.
	for x_index in range(-7, 8):
		var x := float(x_index) * 2.0
		_add_castle_solid(root, WALL_STONE, Vector3(x, 0.2, -13.0), 0.0)
		if x_index not in [-1, 0, 1]:
			_add_castle_solid(root, WALL_STONE, Vector3(x, 0.2, 13.0), PI)
	for z_index in range(-5, 6):
		var z := float(z_index) * 2.0
		_add_castle_solid(root, WALL_STONE, Vector3(-16.0, 0.2, z), PI * 0.5)
		_add_castle_solid(root, WALL_STONE, Vector3(16.0, 0.2, z), -PI * 0.5)
	_add_castle_solid(root, WALL_ARCH, Vector3(0.0, 0.2, 13.0), PI)
	for corner in [Vector3(-15.0, 0.0, -12.0), Vector3(15.0, 0.0, -12.0), Vector3(-15.0, 0.0, 12.0), Vector3(15.0, 0.0, 12.0)]:
		_build_tower(root, corner)
	generated_castle_count += 1


func _build_tower(parent: Node3D, local_position: Vector3) -> void:
	for level in 2:
		var y := 0.2 + level * 3.1
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(-1.0, y, 2.0), PI)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(1.0, y, 2.0), PI)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(-1.0, y, -2.0), 0.0)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(1.0, y, -2.0), 0.0)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(-2.0, y, -1.0), PI * 0.5)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(-2.0, y, 1.0), PI * 0.5)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(2.0, y, -1.0), -PI * 0.5)
		_add_castle_solid(parent, WALL_STONE, local_position + Vector3(2.0, y, 1.0), -PI * 0.5)
	_add_part(parent, TOWER_ROOF, local_position + Vector3(0.0, 6.6, 0.0), 0.0)


func _build_village_street(center: Vector2, yaw: float) -> void:
	for index in 12:
		var offset := Vector2(-12.0 + index * 2.2, -24.0).rotated(yaw)
		_spawn_solid(FENCE, _terrain_position(center + offset), yaw, Vector3(2.05, 0.86, 0.2), Vector3(0.0, 0.42, 0.0))
	var wagon_point := center + Vector2(11, 3).rotated(yaw)
	_spawn_solid(WAGON, _terrain_position(wagon_point), yaw + 0.25, Vector3(2.0, 1.55, 4.05), Vector3(0.0, 0.75, -1.1))


func _build_starting_props() -> void:
	for index in 5:
		_spawn_breakable_crate(Vector2(-9.0 - index * 1.25, 180.0 + (index % 2) * 1.3), index * 0.27)


func _add_village_lights(center: Vector2, yaw: float) -> void:
	for local in [Vector2(-11.0, 0.0), Vector2(12.0, 4.0)]:
		var local_point: Vector2 = local
		var point: Vector2 = center + local_point.rotated(yaw)
		var light := OmniLight3D.new()
		light.name = "VillageLantern%02d" % generated_light_count
		light.position = Vector3(point.x, _height_at(point) + 3.2, point.y)
		light.light_color = Color(1.0, 0.48, 0.16)
		light.light_energy = 4.8
		light.omni_range = 48.0
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 1.7
		light.add_to_group("night_lantern")
		add_child(light)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.31, 0.05)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.18, 0.025)
		material.emission_energy_multiplier = 4.0
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = 0.24
		glow_mesh.height = 0.48
		glow_mesh.material = material
		var glow := MeshInstance3D.new()
		glow.name = "LanternGlow"
		glow.mesh = glow_mesh
		glow.position = light.position
		glow.add_to_group("night_lantern_glow")
		add_child(glow)
		generated_light_count += 1


func _create_building_body(center: Vector2, yaw: float, node_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(center.x, _height_at(center), center.y)
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	return body


func _add_foundation(body: Node3D, size: Vector3, collidable: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _foundation_material
	var visual := MeshInstance3D.new()
	visual.name = "StoneFoundation"
	visual.mesh = mesh
	visual.position.y = size.y * 0.5
	body.add_child(visual)
	if collidable:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.name = "FloorCollision"
		collision.shape = shape
		collision.position.y = size.y * 0.5
		body.add_child(collision)
		generated_collision_count += 1
	generated_prop_count += 1


func _add_wall_part(parent: StaticBody3D, scene: PackedScene, local_position: Vector3, yaw: float, collidable: bool = true) -> void:
	_add_part(parent, scene, local_position, yaw)
	if not collidable:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 3.1, 0.42)
	var collision := CollisionShape3D.new()
	collision.name = "WallCollision%03d" % generated_collision_count
	collision.shape = shape
	collision.position = local_position + Vector3(0.0, 1.55, 0.0)
	collision.rotation.y = yaw
	parent.add_child(collision)
	generated_collision_count += 1


func _add_part(parent: Node3D, scene: PackedScene, local_position: Vector3, yaw: float) -> Node3D:
	var anchor := Node3D.new()
	anchor.position = local_position
	anchor.rotation.y = yaw
	anchor.add_child(scene.instantiate())
	parent.add_child(anchor)
	generated_prop_count += 1
	return anchor


func _add_castle_solid(parent: Node3D, scene: PackedScene, local_position: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.position = local_position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(scene.instantiate())
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 3.1, 0.42)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.55
	body.add_child(collision)
	parent.add_child(body)
	generated_prop_count += 1
	generated_collision_count += 1


func _spawn_solid(scene: PackedScene, position: Vector3, yaw: float, size: Vector3, offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "MedievalProp%03d" % generated_collision_count
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	body.rotation.y = yaw
	body.add_child(scene.instantiate())
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
