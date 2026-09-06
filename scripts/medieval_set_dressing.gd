class_name MedievalSetDressing
extends Node3D

## Villas y caseríos Quaternius a escala habitable. Las viviendas tienen entre
## dos y tres plantas, fachada de hastial cerrada y acceso a ras del terreno.

const ROOT := "res://assets/quaternius/store_bundle/glTF/"
# Escala uniforme: Jolt conserva exactamente las colisiones de suelos, paredes
# y rampas. Cada módulo pasa de 3,1 a 4,8 m de altura y de 8 x 14 a 12,4 x 21,7 m.
const HOUSE_SCALE := Vector3(1.55, 1.55, 1.55)
const STOREY_HEIGHT := 3.1
const FLOOR_LEVEL := 0.35
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
const FLOOR_WOOD: PackedScene = preload(ROOT + "Floor_WoodDark.gltf")
const INTERIOR_STAIR_RAILS: PackedScene = preload(ROOT + "Stair_Interior_Rails.gltf")
const INTERIOR_STAIR_SIMPLE: PackedScene = preload(ROOT + "Stair_Interior_Simple.gltf")
const EXTERIOR_STAIR: PackedScene = preload(ROOT + "Stairs_Exterior_Straight.gltf")
const TOWER_ROOF: PackedScene = preload(ROOT + "Roof_Tower_RoundTiles.gltf")
const FENCE: PackedScene = preload(ROOT + "Prop_WoodenFence_Single.gltf")
const WAGON: PackedScene = preload(ROOT + "Prop_Wagon.gltf")
const CRATE: PackedScene = preload(ROOT + "Prop_Crate.gltf")
const VINE: PackedScene = preload(ROOT + "Prop_Vine1.gltf")
const CHIMNEY: PackedScene = preload(ROOT + "Prop_Chimney.gltf")
const BREAKABLE_SCRIPT: Script = preload("res://scripts/breakable_prop.gd")

# Castillo modular original de Quaternius (julio de 2017). Los OBJ conservan
# sus materiales low-poly y permiten montar una fortaleza grande pieza a pieza.
const CASTLE_ROOT := "res://assets/quaternius/Modular Medieval Buildings - Jul 2017/OBJ/"
const CASTLE_TALL_WALL: Mesh = preload(CASTLE_ROOT + "TallWall.obj")
const CASTLE_TALL_WALL_BRICKS: Mesh = preload(CASTLE_ROOT + "TallWallBricks.obj")
const CASTLE_GATE: Mesh = preload(CASTLE_ROOT + "TallWallEntrance.obj")
const CASTLE_LARGE_TOWER: Mesh = preload(CASTLE_ROOT + "LargeTower.obj")
const CASTLE_SQUARE_TOWER: Mesh = preload(CASTLE_ROOT + "LargeSquareTowerBricks.obj")
const CASTLE_POINTY_TOWER: Mesh = preload(CASTLE_ROOT + "PointyTower.obj")
const CASTLE_WATCHTOWER: Mesh = preload(CASTLE_ROOT + "WatchTowerWRoof.obj")
const CASTLE_BRIDGE: Mesh = preload(CASTLE_ROOT + "Bridge.obj")
const CASTLE_BANNER: Mesh = preload(CASTLE_ROOT + "Banner.obj")
const CASTLE_WELL: Mesh = preload(CASTLE_ROOT + "Well.obj")
const CASTLE_TARGET: Mesh = preload(CASTLE_ROOT + "TargetWithArrows.obj")
const CASTLE_SCALE := Vector3(8.0, 8.0, 8.0)
const CASTLE_COURTYARD_Y := 1.85
const KEEP_SCALE := 1.75
const KEEP_FLOORS := 10
const KEEP_STOREY_HEIGHT := STOREY_HEIGHT * KEEP_SCALE
const STAIR_SIMPLE_RUN := 4.619539
const STAIR_SIMPLE_BOTTOM_Z := 0.034729
const STAIR_SIMPLE_HEIGHT := 3.024588
const STAIR_RAIL_RUN := 4.563224
const STAIR_RAIL_BOTTOM_Z := 0.244316
const STAIR_RAIL_HEIGHT := 3.953075
const CITADEL_ZONES: Array[String] = [
	"Gran Salon y Cocinas",
	"Cuartel de la Guardia",
	"Armeria Real",
	"Biblioteca y Archivo",
	"Sala del Consejo",
	"Aposentos Nobles",
	"Sala de Guerra",
	"Camara del Tesoro",
	"Capilla Alta",
	"Observatorio de la Corona",
]

const VILLAGES: Array = [
	{"name": "Puerto Alba", "center": Vector2(0, 190), "yaw": 0.08, "castle": false},
	{"name": "Villa Robledal", "center": Vector2(-1450, 650), "yaw": 0.42, "castle": true, "grand": true},
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
var generated_folk_count := 0
var generated_tower_roof_count := 0
var _tower_roof_material: StandardMaterial3D = null
var generated_roof_facade_count := 0
var generated_upper_floor_count := 0
var generated_stair_count := 0
var generated_castle_keep_count := 0
var generated_castle_gate_count := 0
var generated_escape_stair_count := 0
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
	print("MEDIEVAL WORLD READY: %d villas, %d caseríos, %d casas accesibles (%d de tres pisos), %d castillos, %d vecinos, %d piezas y %d colisiones." % [generated_village_count, generated_hamlet_count, generated_house_count, generated_three_storey_count, generated_castle_count, generated_folk_count, generated_prop_count, generated_collision_count])


## Radio del casco de la villa grande, en metros. Tiene que caber dentro del
## claro de vegetación de su villa o los pinos brotan dentro de las casas.
const GRAND_VILLAGE_RADIUS := VillageLayout.RADIUS
## Paso entre parcelas a lo largo de la calle. La receta más ancha mide 31 m, así
## que con 40 quedan nueve metros de aire entre vecinas.
const GRAND_PLOT_PITCH := VillageLayout.PITCH
## Cuánto se retira la fachada del eje de la calle.
const GRAND_STREET_SETBACK := VillageLayout.SETBACK
## Fondo de la segunda hilera. La receta más profunda mide 27,9 m, así que con
## 40 m de separación entre hileras quedan doce metros de patio entre traseras.
const GRAND_SECOND_RANK := VillageLayout.SECOND_RANK
## Cuadrado reservado por parcela: 31 m de la receta más ancha más 5 de patio.
const GRAND_PLOT_RESERVE := VillageLayout.RESERVE


func _build_village(spec: Dictionary) -> void:
	var center: Vector2 = spec.center
	var yaw: float = spec.yaw
	var village_name: String = spec.name
	generated_village_count += 1
	if bool(spec.get("grand", false)):
		# La fortaleza ocupa 126 x 100 m al este del centro. Sin vetar esa zona,
		# la calle transversal entra dentro del recinto y algunas parcelas caen
		# sobre él: un vecino acababa caminando dentro de la muralla.
		var keep_out := Rect2()
		if bool(spec.castle):
			keep_out = Rect2(125.0 - 68.0, 3.0 - 56.0, 136.0, 112.0)
		_build_grand_village(center, yaw, village_name, keep_out)
		if bool(spec.castle):
			var grand_castle := Vector2(125, 3).rotated(yaw)
			_build_castle(center + grand_castle, yaw, village_name)
		return
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


func _build_grand_village(
	center: Vector2, yaw: float, village_name: String, keep_out: Rect2
) -> void:
	## Villa de calle, no de corro. Las casas se alinean a los dos lados de dos
	## ejes cruzados y MIRAN a la calle: la puerta de cada receta cae en su cara
	## +Z, así que el giro de cada hilera se deriva del lado que ocupa y no se
	## escribe a mano casa por casa.
	var slug := village_name.validate_node_name()
	var index := 0
	for plot in _grand_village_plots():
		var local: Vector2 = plot["offset"]
		if _blocked(keep_out, local):
			continue
		var house_center := center + local.rotated(yaw)
		# Vector2.rotated y la rotación Y de Node3D tienen signos opuestos en XZ.
		var house_yaw := -yaw + float(plot["facing"])
		if bool(plot["hall"]):
			_build_hall(house_center, house_yaw, "%sHall%02d" % [slug, index])
		else:
			_build_cottage(house_center, house_yaw, "%sHouse%02d" % [slug, index])
		index += 1
	_build_grand_streets(center, yaw, keep_out)
	# La cerca y el carro del corro pequeño caen justo en medio de la calzada de
	# la villa grande: aquí el carro se arrima a la plaza y la cerca no va.
	# El carro va al patio ENTRE las dos hileras, no junto a la plaza: por la
	# plaza pasan los vecinos y uno acabó metido dentro del carro.
	var wagon_point := center + Vector2(56.0, 20.0).rotated(yaw)
	_spawn_solid(
		WAGON, _terrain_position(wagon_point), yaw + 0.25,
		Vector3(2.0, 1.55, 4.05), Vector3(0.0, 0.75, -1.1)
	)
	_add_village_lights(center, yaw)
	_populate_village(center, yaw, slug, keep_out)


func _populate_village(center: Vector2, yaw: float, slug: String, keep_out: Rect2) -> void:
	## Vecinos que caminan la villa y hacen cosas. Los umbrales de las casas ya
	## existen como nodos "Doorway", así que se reutilizan como destinos y un
	## porteador va de verdad a una puerta y no a un punto inventado.
	var folk := VillageFolk.new()
	folk.name = "%sVecinos" % slug
	# Un vecino y medio por casa: con dieciocho para veintisiete casas la villa
	# se veía vacía. Se deriva del reparto, así que si la villa crece, crece la
	# gente sin tocar un número.
	folk.folk_count = int(round(float(_grand_village_plots().size()) * 1.5))
	add_child(folk)
	folk.build(terrain, center, yaw, GRAND_VILLAGE_RADIUS, keep_out)
	folk.collect_doors(self)
	generated_folk_count += folk.generated_folk_count


static func _blocked(keep_out: Rect2, local: Vector2) -> bool:
	return keep_out.size.x > 0.0 and keep_out.has_point(local)


func _build_grand_streets(center: Vector2, yaw: float, keep_out: Rect2) -> void:
	var roads := VillageLayout.street_segments()
	for child in get_children():
		if not String(child.name).begins_with("Villa Robledal"):
			continue
		var approach := child.get_node_or_null("ApproachPoint") as Node3D
		if approach != null:
			var local := (Vector2(approach.global_position.x, approach.global_position.z) - center).rotated(-yaw)
			roads.append([local, VillageLayout.nearest_street(local), 2.0])
	var node := MeshInstance3D.new()
	node.name = "CalleEmpedrada%02d" % generated_village_count
	node.mesh = VillageStreet.build(terrain, center, yaw, GRAND_VILLAGE_RADIUS, keep_out, roads)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("terrain_following", true)
	node.set_meta("street_width", float(VillageStreet.HALF_WIDTH * 2))
	add_child(node)
	generated_prop_count += 1


func _grand_village_plots() -> Array[Dictionary]:
	return VillageLayout.plots()

func _build_cottage(center: Vector2, yaw: float, house_name: String) -> void:
	var floors := 3 + generated_house_count % 3 if house_name.begins_with("VillaRobledal") or house_name.begins_with("Villa Robledal") else 2
	_build_large_house(center, yaw, house_name, false, floors)


func _build_hall(center: Vector2, yaw: float, house_name: String) -> void:
	var floors := 5 if "Robledal" in house_name else 3
	_build_large_house(center, yaw, house_name, true, floors)


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
	## Casa generada por BuildingSolver: la geometría se resuelve en celdas
	## enteras ANTES de instanciar nada, así que no puede haber cuerpos que se
	## pisen ni muros duplicados en la cara compartida. El generador anterior
	## levantaba una única caja cerrada con una sola escalera por planta, en el
	## extremo contrario cada vez.
	var body := _create_building_body(center, yaw, house_name)
	body.scale = VillageLayout.SCALE if house_name.begins_with("Villa Robledal") else HOUSE_SCALE
	var variant := generated_house_count + (1 if is_hall else 0)
	var recipe := BuildingRecipes.for_house(floors, variant)
	var solver := BuildingSolver.new()
	if not solver.solve(recipe, BuildingCatalog.roof_metrics()):
		push_error(
			"La receta '%s' no resuelve limpia: %s"
			% [recipe["display_name"], solver.errors]
		)
		body.queue_free()
		return
	var assembler := BuildingAssembler.new()
	assembler.assemble(solver, recipe, BuildingCatalog.families(), body)
	generated_prop_count += assembler.mesh_count
	generated_collision_count += assembler.collision_count

	# Toda la planta queda encima del terreno, incluidos los rincones del ala.
	# Mirar sólo la cota de la puerta dejaba lomas dentro y bloqueaba la salida.
	_fit_house_to_terrain(body, solver)

	var box := solver.footprint()
	_add_house_markers(body, solver, box)
	_add_house_entrance_ramp(body, solver)
	_publish_house_metrics(body, solver, recipe, box, floors)
	HouseInterior.decorate(body, solver, variant)
	generated_house_count += 1
	if floors >= 3:
		generated_three_storey_count += 1


func _fit_house_to_terrain(body: StaticBody3D, solver: BuildingSolver) -> void:
	var highest := -INF
	var lowest := INF
	var shift := solver.centre_offset()
	for entry in solver.floors_plan:
		if int(entry["level"]) != 0:
			continue
		var origin: Vector2i = entry["origin"]
		var size: Vector2i = entry["size"]
		for x in range(size.x * 2 + 1):
			for z in range(size.y * 2 + 1):
				var point := body.to_global(Vector3(origin.x * BuildingSolver.CELL + x,
					0.0, origin.y * BuildingSolver.CELL + z) + shift)
				var ground := _height_at(Vector2(point.x, point.z))
				highest = maxf(highest, ground)
				lowest = minf(lowest, ground)
	body.position.y = highest + 0.16
	var depth := maxf((body.position.y - lowest + 0.35) / body.scale.y, 0.34)
	body.set_meta("foundation_depth", depth)
	body.set_meta("terrain_max_height", highest)
	for child in body.get_children():
		if child is CollisionShape3D and String(child.name).begins_with("Cimiento"):
			var shape := (child as CollisionShape3D).shape as BoxShape3D
			shape.size.y = depth
			child.position.y = -depth * 0.5


func _add_house_entrance_ramp(body: StaticBody3D, solver: BuildingSolver) -> void:
	var door := solver.door_position()
	var outward := solver.door_outward()
	var reach := 3.0
	var outside := door + outward * reach
	var ground := 0.0
	for _attempt in 4:
		outside = door + outward * reach
		var point := body.to_global(outside)
		ground = _height_at(Vector2(point.x, point.z))
		var rise := maxf((body.position.y - ground) / body.scale.y, 0.0)
		if rise / reach < 0.24:
			break
		reach = maxf(reach + 1.0, rise / 0.24)
	outside.y = (ground - body.position.y) / body.scale.y - 0.025
	var inside := door - outward * 0.26
	var side := outward.cross(Vector3.UP).normalized() * 1.12
	var thickness := maxf(0.3, -outside.y + 0.18)
	var points := PackedVector3Array([
		outside - side, outside + side, inside - side, inside + side,
		outside - side - Vector3.UP * 0.18, outside + side - Vector3.UP * 0.18,
		inside - side - Vector3.UP * thickness, inside + side - Vector3.UP * thickness,
	])
	var ramp := CollisionShape3D.new()
	ramp.name = "EntranceRamp"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	ramp.shape = shape
	body.add_child(ramp)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[0, 2, 3], [0, 3, 1], [0, 4, 6], [0, 6, 2], [1, 3, 7],
		[1, 7, 5], [4, 5, 7], [4, 7, 6], [0, 1, 5], [0, 5, 4], [2, 6, 7], [2, 7, 3]]:
		for index in triangle:
			surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, _foundation_material)
	var visual := MeshInstance3D.new()
	visual.name = "StoneEntranceRamp"
	visual.mesh = mesh
	body.add_child(visual)
	var marker := Marker3D.new()
	marker.name = "ApproachPoint"
	marker.position = outside + Vector3.UP * 0.025
	body.add_child(marker)
	body.set_meta("entrance_ramp_length", reach * body.scale.z)
	body.set_meta("entrance_ramp_width", 2.24 * body.scale.x)
	generated_prop_count += 1
	generated_collision_count += 1


func _add_house_markers(body: StaticBody3D, solver: BuildingSolver, box: Rect2) -> void:
	## Losa, umbral, punto interior y luz cálida. El umbral y el punto interior no
	## son adorno: son las dos referencias con las que un habitante sabe por dónde
	## se entra y hacia dónde ir una vez dentro.
	# Una losa por cuerpo, no una sola de toda la huella: con planta en L, la
	# caja envolvente asomaba como una acera gris en las esquinas vacías.
	var foundation := MeshInstance3D.new()
	foundation.name = "StoneFoundation"
	foundation.mesh = _foundation_mesh(solver, float(body.get_meta("foundation_depth", 0.34)))
	body.add_child(foundation)
	generated_prop_count += 1

	var door_local := solver.door_position()
	var outward := solver.door_outward()
	var doorway := Node3D.new()
	doorway.name = "Doorway"
	doorway.position = door_local + outward * 0.6 + Vector3.UP * 1.1
	body.add_child(doorway)
	var interior := Node3D.new()
	interior.name = "InteriorPoint"
	interior.position = door_local - outward * 2.4 + Vector3.UP * 1.1
	body.add_child(interior)

	var interior_light := OmniLight3D.new()
	interior_light.name = "InteriorWarmLight"
	interior_light.position = Vector3(0.0, 2.4, 0.0)
	interior_light.light_color = Color(1.0, 0.48, 0.17)
	interior_light.light_energy = 0.18
	interior_light.omni_range = 16.0
	interior_light.shadow_enabled = false
	interior_light.add_to_group("night_lantern")
	body.add_child(interior_light)
	generated_light_count += 1


func _foundation_mesh(solver: BuildingSolver, slab: float = 0.34) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shift := solver.centre_offset()
	for entry in solver.floors_plan:
		if int(entry["level"]) != 0:
			continue
		var origin: Vector2i = entry["origin"]
		var size: Vector2i = entry["size"]
		var centre := Vector3(
			(float(origin.x) + float(size.x) * 0.5) * BuildingSolver.CELL,
			-slab * 0.5 - 0.04,
			(float(origin.y) + float(size.y) * 0.5) * BuildingSolver.CELL
		) + shift
		# Un pelo más ancha que el muro, para que se lea como zócalo.
		_append_box(
			tool,
			centre,
			Vector3(
				float(size.x) * BuildingSolver.CELL + 0.24,
				slab,
				float(size.y) * BuildingSolver.CELL + 0.24
			)
		)
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	mesh.surface_set_material(0, _foundation_material)
	return mesh


func _append_box(tool: SurfaceTool, centre: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var corners: Array[Vector3] = []
	for index in 8:
		corners.append(centre + Vector3(
			half.x if index & 1 else -half.x,
			half.y if index & 2 else -half.y,
			half.z if index & 4 else -half.z
		))
	var faces: Array = [
		[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4],
		[2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5],
	]
	for face in faces:
		tool.add_vertex(corners[face[0]])
		tool.add_vertex(corners[face[1]])
		tool.add_vertex(corners[face[2]])
		tool.add_vertex(corners[face[0]])
		tool.add_vertex(corners[face[2]])
		tool.add_vertex(corners[face[3]])


func _publish_house_metrics(
	body: StaticBody3D,
	solver: BuildingSolver,
	recipe: Dictionary,
	box: Rect2,
	floors: int
) -> void:
	## El propio generador publica lo que ha comprobado. Si alguna de estas cifras
	## deja de ser cero, la casa está mal construida y la prueba lo caza sin tener
	## que volver a medir la geometría desde fuera.
	var report: Dictionary = solver.report
	body.set_meta("enterable", true)
	body.set_meta("recipe", String(recipe["display_name"]))
	body.set_meta("footprint", Vector2(box.size.x * body.scale.x, box.size.y * body.scale.z))
	body.set_meta("floor_count", floors)
	body.set_meta("upper_floor_count", floors - 1)
	body.set_meta("volume_count", (recipe["volumes"] as Array).size())
	body.set_meta("storey_clearance", BuildingSolver.STOREY * body.scale.y)
	body.set_meta("stairs_traversable", true)
	body.set_meta("stairs_per_transition", 2)
	body.set_meta("stair_layout", "double_opposed_switchback")
	body.set_meta("stair_count", int(report["stair_count"]))
	body.set_meta("stair_pitch_degrees", _first_stair_pitch(solver))
	body.set_meta("door_count", int(report["door_count"]))
	body.set_meta("arch_count", int(report["arch_count"]))
	body.set_meta("wall_count", int(report["wall_count"]))
	body.set_meta("cell_conflicts", int(report["cell_conflicts"]))
	body.set_meta("duplicate_edges", int(report["duplicate_edges"]))
	body.set_meta("roof_below_eave_count", int(report["roof_below_eave_count"]))
	body.set_meta("worst_roof_dip", float(report["worst_roof_dip"]))
	body.set_meta("unreachable_cells", int(report["unreachable_cells"]))
	body.set_meta("unsupported_cells", int(report["unsupported_cells"]))


func _first_stair_pitch(solver: BuildingSolver) -> float:
	for stair in solver.stairs:
		if String(stair.get("kind", "straight")) == "straight":
			return float(stair["pitch_degrees"])
	return 0.0


func _build_interior_storeys(body: StaticBody3D, floors: int) -> void:
	# Cada planta superior usa baldosas de madera Quaternius. El hueco cambia de
	# lado en cada nivel: de ese modo el tramo siguiente jamás queda encima del
	# anterior y el recorrido entre ambos forma un descansillo amplio y seguro.
	for level in range(1, floors):
		var floor_y := FLOOR_LEVEL + level * STOREY_HEIGHT
		var hole_x := 3.0 if (level - 1) % 2 == 0 else -3.0
		for x in [-3.0, -1.0, 1.0, 3.0]:
			for z in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
				if is_equal_approx(x, hole_x) and absf(z) <= 2.0:
					continue
				var tile := _add_part(body, FLOOR_WOOD, Vector3(x, floor_y, z), 0.0)
				tile.name = "UpperFloorL%d_%d_%d" % [level, int(x), int(z)]
		_add_upper_floor_collisions(body, level, floor_y, hole_x)
		# El tramo que llega a esta planta determina el único extremo abierto.
		var incoming_direction := 1.0 if (level - 1) % 2 == 0 else -1.0
		_add_stair_guardrail(body, "HouseGuardL%d" % level, floor_y, hole_x, 0.0, 2.0, 6.0, incoming_direction)
		generated_upper_floor_count += 1

	# Cada transición combina la pieza sólida con peldaños y la pieza de
	# barandillas. Antes solo se instanciaba la segunda y parecía una barandilla
	# flotante sin escalera.
	for level in range(floors - 1):
		var base_y := FLOOR_LEVEL + level * STOREY_HEIGHT
		var stair_yaw := 0.0 if level % 2 == 0 else PI
		var stair_direction := 1.0 if level % 2 == 0 else -1.0
		var stair_x := 3.0 if level % 2 == 0 else -3.0
		var visible_run := 6.0
		var step_z_scale := visible_run / STAIR_SIMPLE_RUN
		var step_origin_z := visible_run * 0.5 - STAIR_SIMPLE_BOTTOM_Z * step_z_scale
		var rail_z_scale := visible_run / STAIR_RAIL_RUN
		var rail_origin_z := visible_run * 0.5 - STAIR_RAIL_BOTTOM_Z * rail_z_scale
		var steps := _add_part(body, INTERIOR_STAIR_SIMPLE, Vector3(stair_x, base_y, stair_direction * step_origin_z), stair_yaw)
		steps.name = "InteriorStairStepsL%d" % level
		steps.scale = Vector3(1.0, STOREY_HEIGHT / STAIR_SIMPLE_HEIGHT, step_z_scale)
		var rails := _add_part(body, INTERIOR_STAIR_RAILS, Vector3(stair_x, base_y, stair_direction * rail_origin_z), stair_yaw)
		rails.name = "InteriorStairRailsL%d" % level
		rails.scale = Vector3(1.0, STOREY_HEIGHT / STAIR_RAIL_HEIGHT, rail_z_scale)
		_add_stair_collision(body, level, base_y, stair_x, stair_direction, stair_yaw)
		generated_stair_count += 1


func _add_upper_floor_collisions(body: StaticBody3D, level: int, floor_y: float, hole_x: float) -> void:
	# Tres placas dejan un hueco de 2 x 6 m en un único lateral. La composición
	# se refleja en las plantas pares para acompañar la nueva columna de escalera.
	var solid_center_x := -1.125 if hole_x > 0.0 else 1.125
	var hole_strip_x := 3.125 if hole_x > 0.0 else -3.125
	_add_floor_collision(body, "UpperFloorCollisionL%d_Main" % level, Vector3(6.25, 0.18, 14.5), Vector3(solid_center_x, floor_y, 0.0))
	_add_floor_collision(body, "UpperFloorCollisionL%d_Back" % level, Vector3(2.25, 0.18, 4.25), Vector3(hole_strip_x, floor_y, -5.125))
	_add_floor_collision(body, "UpperFloorCollisionL%d_Front" % level, Vector3(2.25, 0.18, 4.25), Vector3(hole_strip_x, floor_y, 5.125))


func _add_floor_collision(body: StaticBody3D, collision_name: String, size: Vector3, local_position: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = collision_name
	collision.shape = shape
	collision.position = local_position
	body.add_child(collision)
	generated_collision_count += 1


func _add_stair_collision(body: StaticBody3D, level: int, base_y: float, stair_x: float, stair_direction: float, stair_yaw: float) -> void:
	# Cuña con su cara superior definida por las cotas reales de ambos suelos.
	# La primera planta parte de la cimentación; las siguientes, del forjado.
	var base_surface_y := 0.34 if level == 0 else base_y + 0.09
	var destination_surface_y := base_y + STOREY_HEIGHT + 0.09
	_add_stair_wedge_collision(
		body,
		"StairRampCollisionL%d" % level,
		stair_x,
		1.62,
		stair_direction * 4.05,
		-stair_direction * 3.0,
		base_surface_y,
		destination_surface_y,
		0.24
	)


func _build_castle(center: Vector2, yaw: float, village_name: String) -> void:
	var ground := _height_at(center)
	var root := StaticBody3D.new()
	root.name = "%sCastle" % village_name.validate_node_name()
	root.position = Vector3(center.x, ground, center.y)
	root.rotation.y = yaw
	root.collision_layer = 1
	root.collision_mask = 0
	root.set_meta("complete_fortress", true)
	root.set_meta("open_gate_count", 2)
	root.set_meta("escape_stair_count", 2)
	root.set_meta("modular_pack", "Modular Medieval Buildings - Jul 2017")
	root.set_meta("fortress_size", Vector2(126.0, 100.0))
	root.set_meta("interior_room_count", 40)
	root.set_meta("interior_floor_count", KEEP_FLOORS)
	root.set_meta("citadel_footprint", Vector2(42.0, 24.5))
	root.set_meta("citadel_staircase_count", (KEEP_FLOORS - 1) * 2)
	root.set_meta("citadel_guardrail_count", (KEEP_FLOORS - 1) * 2 * 3)
	root.set_meta("citadel_stair_layout", "double_side_switchback")
	root.set_meta("citadel_stair_transition_is_flush", true)
	root.set_meta("citadel_stair_visual", "Stair_Interior_Simple")
	root.set_meta("observation_deck_open", true)
	root.set_meta("observation_deck_parapet_count", 4)
	root.set_meta("observation_deck_roof", false)
	root.set_meta("citadel_zone_count", CITADEL_ZONES.size())
	root.set_meta("citadel_height", KEEP_FLOORS * KEEP_STOREY_HEIGHT)
	root.set_meta("citadel_origin", Vector3(0.0, CASTLE_COURTYARD_Y + 0.05, -8.0))
	root.set_meta("citadel_storey_height", KEEP_STOREY_HEIGHT)
	root.set_meta("wall_passage_count", 2)
	add_child(root)

	# Explanada dividida: sostiene murallas y torres, pero deja trincheras reales
	# en ambos portones. Una caja única creaba una pared vertical invisible justo
	# donde las rampas parecían entrar al patio.
	_add_castle_foundation(root)

	# Murallas Quaternius de casi 19 m. La pieza central es un arco abierto; su
	# colisión se divide en jambas y dintel para poder atravesarlo de verdad.
	for x_index in range(-4, 5):
		var x := float(x_index) * 12.15
		if x_index == 0:
			_add_castle_mesh(root, CASTLE_GATE, Vector3(x, CASTLE_COURTYARD_Y, 43.0), PI, CASTLE_SCALE, "MainGate")
			_add_castle_mesh(root, CASTLE_GATE, Vector3(x, CASTLE_COURTYARD_Y, -43.0), 0.0, CASTLE_SCALE, "RearGate")
			_add_gate_collision(root, Vector3(x, CASTLE_COURTYARD_Y, 43.0), PI)
			_add_gate_collision(root, Vector3(x, CASTLE_COURTYARD_Y, -43.0), 0.0)
		else:
			var mesh := CASTLE_TALL_WALL_BRICKS if abs(x_index) % 2 == 0 else CASTLE_TALL_WALL
			_add_castle_wall(root, mesh, Vector3(x, CASTLE_COURTYARD_Y, 43.0), PI)
			_add_castle_wall(root, mesh, Vector3(x, CASTLE_COURTYARD_Y, -43.0), 0.0)
	for z_index in range(-3, 4):
		var z := float(z_index) * 12.15
		var mesh := CASTLE_TALL_WALL_BRICKS if abs(z_index) % 2 == 1 else CASTLE_TALL_WALL
		_add_castle_wall(root, mesh, Vector3(-55.0, CASTLE_COURTYARD_Y, z), PI * 0.5)
		_add_castle_wall(root, mesh, Vector3(55.0, CASTLE_COURTYARD_Y, z), -PI * 0.5)
	# Dos cuerpos de guardia flanquean cada acceso. Queda un vano central de más
	# de nueve metros, pero la entrada adquiere el volumen propio de un castillo.
	for gate_z in [-43.0, 43.0]:
		for gate_x in [-10.0, 10.0]:
			_paint_tower_roof(_add_castle_mesh(root, CASTLE_WATCHTOWER, Vector3(gate_x, CASTLE_COURTYARD_Y, gate_z), 0.0, Vector3(7.0, 7.0, 7.0), "GatehouseTower"))
			_add_castle_trimesh_collision(root, CASTLE_WATCHTOWER, Vector3(gate_x, CASTLE_COURTYARD_Y, gate_z), 0.0, Vector3(7.0, 7.0, 7.0), "GatehouseTowerMeshCollision")
	generated_castle_gate_count += 2

	# Cuatro torres de 36 m rematan el recinto.
	for corner in [Vector3(-55.0, CASTLE_COURTYARD_Y, -43.0), Vector3(55.0, CASTLE_COURTYARD_Y, -43.0), Vector3(-55.0, CASTLE_COURTYARD_Y, 43.0), Vector3(55.0, CASTLE_COURTYARD_Y, 43.0)]:
		_build_tower(root, corner)
	_build_castle_keep(root)
	_add_castle_access_stair(root, 1.0)
	_add_castle_access_stair(root, -1.0)
	_add_castle_mesh(root, CASTLE_WELL, Vector3(25.0, CASTLE_COURTYARD_Y, 8.0), 0.0, Vector3(5.0, 5.0, 5.0), "CourtyardWell")
	_add_castle_mesh(root, CASTLE_TARGET, Vector3(38.0, CASTLE_COURTYARD_Y, -20.0), -PI * 0.5, Vector3(4.0, 4.0, 4.0), "ArcheryTarget")
	for banner_x in [-8.0, 8.0]:
		_add_castle_mesh(root, CASTLE_BANNER, Vector3(banner_x, 9.0, 42.2), PI, Vector3(5.0, 5.0, 5.0), "GateBanner")
	generated_castle_count += 1


func _build_castle_keep(parent: Node3D) -> void:
	# Ciudadela habitable de diez plantas: cinco pisos de palacio con tres alas
	# y una torre central de cinco pisos más. Suma 40 estancias comunicadas.
	var keep_origin := Vector3(0.0, CASTLE_COURTYARD_Y + 0.05, -8.0)
	var full_facade_modules: Array[float] = [-11.0, -9.0, -7.0, -5.0, -3.0, -1.0, 1.0, 3.0, 5.0, 7.0, 9.0, 11.0]
	var tower_facade_modules: Array[float] = [-3.0, -1.0, 1.0, 3.0]
	var side_modules: Array[float] = [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]
	for level in KEEP_FLOORS:
		var base_y := keep_origin.y + level * KEEP_STOREY_HEIGHT
		# La décima planta es una torre-mirador completamente abierta. El forjado,
		# las dos escaleras y sus protecciones se generan más abajo, pero aquí no se
		# levantan fachadas, tabiques ni arcos que interrumpan la panorámica.
		if level == KEEP_FLOORS - 1:
			continue
		var wide_level := level < 5
		var half_width := 12.0 if wide_level else 4.0
		var facade_modules: Array[float] = full_facade_modules if wide_level else tower_facade_modules
		for z in side_modules:
			var side_scene := WALL_WINDOW if level > 0 and int(z) % 4 == 0 else WALL_STONE
			_add_keep_wall(parent, side_scene, Vector3(keep_origin.x - half_width * KEEP_SCALE, base_y, keep_origin.z + z * KEEP_SCALE), PI * 0.5)
			_add_keep_wall(parent, side_scene, Vector3(keep_origin.x + half_width * KEEP_SCALE, base_y, keep_origin.z + z * KEEP_SCALE), -PI * 0.5)
		for x in facade_modules:
			var front_position := Vector3(keep_origin.x + x * KEEP_SCALE, base_y, keep_origin.z + 7.0 * KEEP_SCALE)
			if level == 0 and absf(x) == 1.0:
				# Entrada ceremonial doble de siete metros, sin caja invisible.
				_add_scaled_part(parent, WALL_ARCH, front_position, PI, Vector3.ONE * KEEP_SCALE)
			else:
				var facade_scene := WALL_WINDOW if level > 0 and absf(x) not in [5.0] else (WALL_TIMBER if level == 2 else WALL_STONE)
				_add_keep_wall(parent, facade_scene, front_position, PI)
			var rear_scene := WALL_WINDOW if level > 0 and int(absf(x)) % 4 == 1 else WALL_STONE
			_add_keep_wall(parent, rear_scene, Vector3(keep_origin.x + x * KEEP_SCALE, base_y, keep_origin.z - 7.0 * KEEP_SCALE), 0.0)

		# Tabique transversal: comunica las crujías. Los ejes de las escaleras que
		# llegan o salen de esta planta quedan totalmente vacíos; un arco decorativo
		# aquí estrechaba el acceso y podía atrapar al personaje.
		var stair_openings: Array[float] = []
		if level > 0:
			stair_openings.append(_citadel_stair_module(level - 1))
		if level < KEEP_FLOORS - 1:
			stair_openings.append(_citadel_stair_module(level))
		for x in facade_modules:
			var cross_position := Vector3(keep_origin.x + x * KEEP_SCALE, base_y, keep_origin.z)
			if stair_openings.has(absf(x)):
				continue
			if absf(x) == 1.0:
				var passage := _add_scaled_part(parent, WALL_ARCH, cross_position, 0.0, Vector3.ONE * KEEP_SCALE)
				passage.name = "CitadelCrossPassageL%dX%d" % [level, int(x)]
			else:
				_add_keep_wall(parent, WALL_STONE, cross_position, 0.0)
		# Dos tabiques longitudinales forman tres alas. Cada uno deja pasos amplios.
		if wide_level:
			for partition_x in [-4.0, 4.0]:
				for z in side_modules:
					var partition_position := Vector3(keep_origin.x + partition_x * KEEP_SCALE, base_y, keep_origin.z + z * KEEP_SCALE)
					if absf(z) == 2.0:
						_add_scaled_part(parent, WALL_ARCH, partition_position, PI * 0.5, Vector3.ONE * KEEP_SCALE)
					else:
						_add_keep_wall(parent, WALL_STONE, partition_position, PI * 0.5)

	# Forjados completos de 42 m, salvo dos huecos de escalera simétricos.
	for level in KEEP_FLOORS:
		var floor_y := keep_origin.y + level * KEEP_STOREY_HEIGHT
		var floor_modules: Array[float] = full_facade_modules if level < 5 else tower_facade_modules
		var incoming_stair_module := _citadel_stair_module(level - 1) if level > 0 else 9.0
		for x in floor_modules:
			for z in side_modules:
				var wide_stair_hole := level > 0 and level < 5 and absf(x) == incoming_stair_module and absf(z) <= 2.0
				var tower_stair_hole := level >= 5 and absf(x) == incoming_stair_module and absf(z) <= 2.0
				if wide_stair_hole or tower_stair_hole:
					continue
				_add_scaled_part(parent, FLOOR_WOOD if level > 0 else FLOOR_BRICK, Vector3(keep_origin.x + x * KEEP_SCALE, floor_y, keep_origin.z + z * KEEP_SCALE), 0.0, Vector3.ONE * KEEP_SCALE)
		if level > 0:
			_add_keep_floor_collisions(parent, level, keep_origin, floor_y, incoming_stair_module)
			var incoming_direction := 1.0 if (level - 1) % 2 == 0 else -1.0
			var guard_columns := [-incoming_stair_module, incoming_stair_module]
			for guard_x in guard_columns:
				var landing_x: float = keep_origin.x + float(guard_x) * KEEP_SCALE
				_add_stair_guardrail(
					parent,
					"CitadelGuardL%d" % level,
					floor_y,
					landing_x,
					keep_origin.z,
					2.0 * KEEP_SCALE,
					6.0 * KEEP_SCALE,
					incoming_direction,
					KEEP_SCALE
				)
	for level in KEEP_FLOORS - 1:
		var stair_y := keep_origin.y + level * KEEP_STOREY_HEIGHT
		var stair_yaw := 0.0 if level % 2 == 0 else PI
		var stair_direction := 1.0 if level % 2 == 0 else -1.0
		var stair_module := _citadel_stair_module(level)
		var visible_run := 6.0 * KEEP_SCALE
		var step_z_scale := visible_run / STAIR_SIMPLE_RUN
		var step_origin_z := visible_run * 0.5 - STAIR_SIMPLE_BOTTOM_Z * step_z_scale
		var rail_z_scale := visible_run / STAIR_RAIL_RUN
		var rail_origin_z := visible_run * 0.5 - STAIR_RAIL_BOTTOM_Z * rail_z_scale
		var stair_columns := [-stair_module, stair_module]
		for stair_x in stair_columns:
			var stair_x_position: float = keep_origin.x + float(stair_x) * KEEP_SCALE
			var column_name := "Left" if stair_x < 0.0 else "Right"
			var steps := _add_scaled_part(
				parent,
				INTERIOR_STAIR_SIMPLE,
				Vector3(stair_x_position, stair_y, keep_origin.z + stair_direction * step_origin_z),
				stair_yaw,
				Vector3(KEEP_SCALE, KEEP_STOREY_HEIGHT / STAIR_SIMPLE_HEIGHT, step_z_scale)
			)
			steps.name = "CitadelStairStepsL%d%s" % [level, column_name]
			var rails := _add_scaled_part(
				parent,
				INTERIOR_STAIR_RAILS,
				Vector3(stair_x_position, stair_y, keep_origin.z + stair_direction * rail_origin_z),
				stair_yaw,
				Vector3(KEEP_SCALE, KEEP_STOREY_HEIGHT / STAIR_RAIL_HEIGHT, rail_z_scale)
			)
			rails.name = "CitadelStairRailsL%d%s" % [level, column_name]
			_add_keep_stair_collision(parent, level, keep_origin, stair_y, stair_x, stair_direction, stair_yaw)

	# Las alas laterales rematan en el quinto piso; la torre central continúa
	# hasta la décima planta. Esta silueta escalonada mantiene el lenguaje medieval.
	var wing_roof_y := keep_origin.y + 5.0 * KEEP_STOREY_HEIGHT
	for roof_x in [-8.0, 8.0]:
		var world_roof_x: float = keep_origin.x + float(roof_x) * KEEP_SCALE
		_add_scaled_part(parent, ROOF_8X14, Vector3(world_roof_x, wing_roof_y, keep_origin.z), 0.0, Vector3.ONE * KEEP_SCALE)
		_add_scaled_part(parent, ROOF_FRONT_8, Vector3(world_roof_x, wing_roof_y, keep_origin.z + 7.0 * KEEP_SCALE), PI, Vector3.ONE * KEEP_SCALE)
		_add_scaled_part(parent, ROOF_FRONT_8, Vector3(world_roof_x, wing_roof_y, keep_origin.z - 7.0 * KEEP_SCALE), 0.0, Vector3.ONE * KEEP_SCALE)
		_add_scaled_part(parent, CHIMNEY, Vector3(world_roof_x - 2.4 * KEEP_SCALE, wing_roof_y + 0.05, keep_origin.z - 2.7 * KEEP_SCALE), 0.0, Vector3.ONE * KEEP_SCALE)
	_add_observation_deck_parapet(parent, keep_origin)

	# Tres torres propias convierten el edificio en una ciudadela, no en una casa.
	for tower_x in [-31.0, 31.0]:
		_paint_tower_roof(_add_castle_mesh(parent, CASTLE_SQUARE_TOWER, Vector3(tower_x, CASTLE_COURTYARD_Y, keep_origin.z), 0.0, Vector3(15.0, 15.0, 15.0), "CitadelFlankTower"))
		_add_castle_trimesh_collision(parent, CASTLE_SQUARE_TOWER, Vector3(tower_x, CASTLE_COURTYARD_Y, keep_origin.z), 0.0, Vector3(15.0, 15.0, 15.0), "CitadelFlankTowerMeshCollision")
	# Desplazada del eje para mantener expedito el postigo trasero y hacer visible
	# su cubierta roja por detrás de los hastiales del palacio.
	_paint_tower_roof(_add_castle_mesh(parent, CASTLE_POINTY_TOWER, Vector3(-14.0, CASTLE_COURTYARD_Y, -31.0), 0.0, Vector3(13.0, 13.0, 13.0), "CitadelCrownTower"))
	_add_castle_trimesh_collision(parent, CASTLE_POINTY_TOWER, Vector3(-14.0, CASTLE_COURTYARD_Y, -31.0), 0.0, Vector3(13.0, 13.0, 13.0), "CitadelCrownTowerMeshCollision")
	for banner_x in [-14.0, 14.0]:
		_add_castle_mesh(parent, CASTLE_BANNER, Vector3(banner_x, 15.0, keep_origin.z + 12.0), PI, Vector3(5.5, 5.5, 5.5), "CitadelBanner")
	# Luz cálida por ala y planta: al entrar se leen las habitaciones y escaleras,
	# incluso durante la noche, sin activar sombras caras en 24 estancias.
	for light_level in KEEP_FLOORS:
		for light_x in [-8.0, 8.0]:
			var interior_light := OmniLight3D.new()
			interior_light.name = "GreatKeepWarmLightL%d" % light_level
			interior_light.position = Vector3(light_x * KEEP_SCALE, keep_origin.y + light_level * KEEP_STOREY_HEIGHT + 3.0, keep_origin.z)
			interior_light.light_color = Color(1.0, 0.52, 0.2)
			interior_light.light_energy = 1.35
			interior_light.omni_range = 19.0
			interior_light.shadow_enabled = false
			parent.add_child(interior_light)
	_add_citadel_zone_markers(parent, keep_origin)
	generated_castle_keep_count += 1


func _add_observation_deck_parapet(parent: Node3D, keep_origin: Vector3) -> void:
	var deck_y := keep_origin.y + (KEEP_FLOORS - 1) * KEEP_STOREY_HEIGHT
	var parapet_height := 1.25
	var parapet_thickness := 0.70
	var segments: Array[Dictionary] = [
		{"name": "West", "size": Vector3(parapet_thickness, parapet_height, 24.5), "position": Vector3(keep_origin.x - 6.65, deck_y + parapet_height * 0.5, keep_origin.z)},
		{"name": "East", "size": Vector3(parapet_thickness, parapet_height, 24.5), "position": Vector3(keep_origin.x + 6.65, deck_y + parapet_height * 0.5, keep_origin.z)},
		{"name": "North", "size": Vector3(14.0, parapet_height, parapet_thickness), "position": Vector3(keep_origin.x, deck_y + parapet_height * 0.5, keep_origin.z - 11.90)},
		{"name": "South", "size": Vector3(14.0, parapet_height, parapet_thickness), "position": Vector3(keep_origin.x, deck_y + parapet_height * 0.5, keep_origin.z + 11.90)},
	]
	for segment in segments:
		var mesh := BoxMesh.new()
		mesh.size = segment.size
		mesh.material = _foundation_material
		var visual := MeshInstance3D.new()
		visual.name = "ObservationDeckParapet%s" % segment.name
		visual.mesh = mesh
		visual.position = segment.position
		parent.add_child(visual)
		var shape := BoxShape3D.new()
		shape.size = segment.size
		var collision := CollisionShape3D.new()
		collision.name = "ObservationDeckParapet%sCollision" % segment.name
		collision.shape = shape
		collision.position = segment.position
		parent.add_child(collision)
		generated_prop_count += 1
		generated_collision_count += 1
	var marker := Node3D.new()
	marker.name = "CrownObservationDeck"
	marker.position = Vector3(keep_origin.x, deck_y + 1.1, keep_origin.z)
	marker.set_meta("zone_name", "Torre Mirador")
	parent.add_child(marker)


func _citadel_stair_module(transition_level: int) -> float:
	if transition_level < 4:
		return 9.0 if transition_level % 2 == 0 else 7.0
	return 3.0 if transition_level % 2 == 0 else 1.0


func _add_castle_access_stair(parent: StaticBody3D, gate_direction: float) -> void:
	# Rampa monolítica de piedra: su cara superior empieza exactamente a la cota
	# del terreno y termina a la cota del patio. Sustituye el puente decorativo,
	# cuyo arco dejaba una grieta y una colisión imposible de atravesar.
	var run := 18.0
	var rise := CASTLE_COURTYARD_Y
	var thickness := 0.34
	var pitch := atan2(rise, run)
	var slope_length := sqrt(run * run + rise * rise)
	var yaw := 0.0 if gate_direction > 0.0 else PI
	var center := Vector3(
		0.0,
		rise * 0.5 - thickness * 0.5 * cos(pitch),
		gate_direction * 50.0
	)
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(5.5, thickness, slope_length)
	ramp_mesh.material = _foundation_material
	var visual := MeshInstance3D.new()
	visual.name = "CastleAccessRampVisual%02d" % generated_escape_stair_count
	visual.mesh = ramp_mesh
	visual.position = center
	visual.rotation = Vector3(pitch, yaw, 0.0)
	parent.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = ramp_mesh.size
	var collision := CollisionShape3D.new()
	collision.name = "CastleAccessRampCollision%02d" % generated_escape_stair_count
	collision.shape = shape
	collision.position = center
	collision.rotation = visual.rotation
	parent.add_child(collision)
	generated_prop_count += 1
	generated_collision_count += 1
	generated_escape_stair_count += 1


## Remate de teja roja de los torreones. La malla del pack llama "Celing" (así,
## mal escrito) a la superficie del chapitel, y es la única que hay que teñir.
const TOWER_ROOF_SURFACE := "Celing"
const TOWER_ROOF_COLOUR := Color(0.32, 0.055, 0.035)


func _build_tower(parent: Node3D, local_position: Vector3) -> void:
	## Chapitel octogonal y puntiagudo en las cuatro esquinas, no la torre maciza
	## de antes: es la silueta del recinto del taller, que es la que se quería.
	var tower_scale := Vector3(8.5, 8.5, 8.5)
	var visual := _add_castle_mesh(
		parent, CASTLE_POINTY_TOWER, local_position, 0.0, tower_scale, "CornerTower"
	)
	_paint_tower_roof(visual)
	visual.set_meta("pointed_tower", true)
	_add_castle_trimesh_collision(
		parent, CASTLE_POINTY_TOWER, local_position, 0.0, tower_scale, "CornerTowerMeshCollision"
	)


func _paint_tower_roof(visual: MeshInstance3D) -> void:
	if visual == null or visual.mesh == null:
		return
	if _tower_roof_material == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = TOWER_ROOF_COLOUR
		material.roughness = 0.94
		_tower_roof_material = material
	for surface in visual.mesh.get_surface_count():
		var existing := visual.mesh.surface_get_material(surface)
		if existing == null:
			continue
		if TOWER_ROOF_SURFACE in existing.resource_name:
			visual.set_surface_override_material(surface, _tower_roof_material)
			generated_tower_roof_count += 1


func _add_castle_mesh(parent: Node3D, mesh: Mesh, local_position: Vector3, yaw: float, mesh_scale: Vector3, node_name: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = "%s%03d" % [node_name, generated_prop_count]
	visual.mesh = mesh
	visual.position = local_position
	visual.rotation.y = yaw
	visual.scale = mesh_scale
	parent.add_child(visual)
	generated_prop_count += 1
	return visual


func _add_castle_trimesh_collision(
	parent: Node3D,
	mesh: Mesh,
	local_position: Vector3,
	yaw: float,
	mesh_scale: Vector3,
	collision_name: String
) -> void:
	# Las cajas antiguas rellenaban por completo torres huecas y producían
	# paredes invisibles. El trimesh estático sigue exactamente arcos y vanos.
	var collision := CollisionShape3D.new()
	collision.name = "%s%03d" % [collision_name, generated_collision_count]
	collision.shape = mesh.create_trimesh_shape()
	collision.position = local_position
	collision.rotation.y = yaw
	collision.scale = mesh_scale
	parent.add_child(collision)
	generated_collision_count += 1


func _add_castle_wall(parent: Node3D, mesh: Mesh, local_position: Vector3, yaw: float) -> void:
	_add_castle_mesh(parent, mesh, local_position, yaw, CASTLE_SCALE, "CurtainWall")
	_add_box_collision(
		parent,
		"CurtainWallCollision",
		Vector3(12.35, 18.4, 3.0),
		local_position + Vector3(0.0, 9.2, 0.0),
		yaw
	)


func _add_gate_collision(parent: Node3D, local_position: Vector3, yaw: float) -> void:
	# Abertura útil de 5,6 x 10,5 m: pasa el héroe, el caballo y un carruaje.
	for offset_x in [-4.6, 4.6]:
		var offset := Vector3(offset_x, 9.2, 0.0).rotated(Vector3.UP, yaw)
		_add_box_collision(parent, "GatePillarCollision", Vector3(3.15, 18.4, 3.0), local_position + offset, yaw)
	_add_box_collision(parent, "GateLintelCollision", Vector3(6.1, 7.9, 3.0), local_position + Vector3(0.0, 14.45, 0.0), yaw)


func _add_scaled_part(parent: Node3D, scene: PackedScene, local_position: Vector3, yaw: float, part_scale: Vector3) -> Node3D:
	var anchor := _add_part(parent, scene, local_position, yaw)
	anchor.scale = part_scale
	return anchor


func _add_keep_wall(parent: Node3D, scene: PackedScene, local_position: Vector3, yaw: float) -> void:
	_add_scaled_part(parent, scene, local_position, yaw, Vector3.ONE * KEEP_SCALE)
	_add_box_collision(
		parent,
		"KeepWallCollision",
		Vector3(2.0 * KEEP_SCALE, STOREY_HEIGHT * KEEP_SCALE, 0.42 * KEEP_SCALE),
		local_position + Vector3(0.0, KEEP_STOREY_HEIGHT * 0.5, 0.0),
		yaw
	)


func _add_keep_floor_collisions(parent: Node3D, level: int, origin: Vector3, floor_y: float, hole_module: float) -> void:
	if level < 5:
		# Cinco placas dejan dos huecos ajustados de 3,5 x 10,5 m. La anchura
		# de las placas cambia cuando la pareja de huecos alterna entre columnas.
		var hole_center := hole_module * KEEP_SCALE
		var hole_half := KEEP_SCALE
		var inner_edge := hole_center - hole_half
		var outer_edge := hole_center + hole_half
		var outer_width := 21.0 - outer_edge
		_add_box_collision(parent, "KeepFloorL%dRear" % level, Vector3(42.0, 0.24, 7.0), Vector3(origin.x, floor_y, origin.z - 8.75))
		_add_box_collision(parent, "KeepFloorL%dFront" % level, Vector3(42.0, 0.24, 7.0), Vector3(origin.x, floor_y, origin.z + 8.75))
		_add_box_collision(parent, "KeepFloorL%dCenter" % level, Vector3(inner_edge * 2.0, 0.24, 10.5), Vector3(origin.x, floor_y, origin.z))
		_add_box_collision(parent, "KeepFloorL%dLeftEdge" % level, Vector3(outer_width, 0.24, 10.5), Vector3(origin.x - (outer_edge + outer_width * 0.5), floor_y, origin.z))
		_add_box_collision(parent, "KeepFloorL%dRightEdge" % level, Vector3(outer_width, 0.24, 10.5), Vector3(origin.x + outer_edge + outer_width * 0.5, floor_y, origin.z))
	else:
		# En la torre, las parejas alternan entre los bordes y el centro. Cuando
		# ocupan el centro queda suelo en ambos laterales, nunca bajo el hueco.
		_add_box_collision(parent, "TowerFloorL%dRear" % level, Vector3(14.0, 0.24, 7.0), Vector3(origin.x, floor_y, origin.z - 8.75))
		_add_box_collision(parent, "TowerFloorL%dFront" % level, Vector3(14.0, 0.24, 7.0), Vector3(origin.x, floor_y, origin.z + 8.75))
		if is_equal_approx(hole_module, 3.0):
			_add_box_collision(parent, "TowerFloorL%dCenter" % level, Vector3(7.0, 0.24, 10.5), Vector3(origin.x, floor_y, origin.z))
		else:
			_add_box_collision(parent, "TowerFloorL%dLeftEdge" % level, Vector3(3.5, 0.24, 10.5), Vector3(origin.x - 5.25, floor_y, origin.z))
			_add_box_collision(parent, "TowerFloorL%dRightEdge" % level, Vector3(3.5, 0.24, 10.5), Vector3(origin.x + 5.25, floor_y, origin.z))


func _add_keep_stair_collision(parent: Node3D, level: int, origin: Vector3, base_y: float, stair_x: float, stair_direction: float, stair_yaw: float) -> void:
	# En la planta baja la cota correcta es el patio (1,85 m), no el origen del
	# modelo (1,90 m). Arriba se enlaza con la cara superior del forjado, no con
	# su centro: así desaparecen el salto inicial y el bordillo final.
	var base_surface_y := CASTLE_COURTYARD_Y if level == 0 else base_y + 0.12
	var destination_surface_y := base_y + KEEP_STOREY_HEIGHT + 0.12
	_add_stair_wedge_collision(
		parent,
		"KeepStairRampL%d" % level,
		origin.x + stair_x * KEEP_SCALE,
		1.62 * KEEP_SCALE,
		origin.z + stair_direction * 6.40,
		origin.z - stair_direction * 5.25,
		base_surface_y,
		destination_surface_y,
		0.30
	)


func _add_stair_wedge_collision(
	parent: Node3D,
	collision_name: String,
	center_x: float,
	width: float,
	start_z: float,
	end_z: float,
	start_surface_y: float,
	end_surface_y: float,
	thickness: float
) -> void:
	# Prisma convexo cuya cara transitable coincide exactamente con los dos
	# pavimentos. A diferencia de una caja rotada, no deja una cara vertical en
	# ninguno de los extremos ni depende del grosor del forjado.
	var half_width := width * 0.5
	var points := PackedVector3Array()
	for x_offset in [-half_width, half_width]:
		points.append(Vector3(center_x + x_offset, start_surface_y, start_z))
		points.append(Vector3(center_x + x_offset, end_surface_y, end_z))
		points.append(Vector3(center_x + x_offset, start_surface_y - thickness, start_z))
		points.append(Vector3(center_x + x_offset, end_surface_y - thickness, end_z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = "%s%03d" % [collision_name, generated_collision_count]
	collision.shape = shape
	parent.add_child(collision)
	generated_collision_count += 1


func _add_citadel_zone_markers(parent: Node3D, origin: Vector3) -> void:
	for level in CITADEL_ZONES.size():
		var marker := Node3D.new()
		marker.name = "CitadelZone%02d_%s" % [level + 1, CITADEL_ZONES[level].validate_node_name()]
		marker.position = Vector3(origin.x, origin.y + level * KEEP_STOREY_HEIGHT + 2.2, origin.z)
		marker.set_meta("zone_name", CITADEL_ZONES[level])
		marker.set_meta("floor_number", level + 1)
		marker.set_meta("room_count", 6)
		parent.add_child(marker)


func _add_stair_guardrail(
	parent: Node3D,
	rail_name: String,
	floor_y: float,
	center_x: float,
	center_z: float,
	hole_width: float,
	hole_length: float,
	closed_end_direction: float,
	visual_scale_y: float = 1.0
) -> void:
	# Barandilla en U: dos laterales y un cierre. El extremo donde desembarca
	# la escalera queda abierto para formar un descansillo continuo.
	var rail_height := 1.10 * visual_scale_y
	var rail_thickness := 0.16 * visual_scale_y
	for side in [-1.0, 1.0]:
		var side_x: float = center_x + float(side) * hole_width * 0.5
		var side_visual := _add_part(parent, FENCE, Vector3(side_x, floor_y + 0.03, center_z), PI * 0.5)
		side_visual.name = "%sSideVisual" % rail_name
		side_visual.scale = Vector3(hole_length * 0.5, visual_scale_y, visual_scale_y)
		_add_box_collision(
			parent,
			"%sSideCollision" % rail_name,
			Vector3(rail_thickness, rail_height, hole_length - rail_thickness),
			Vector3(side_x, floor_y + rail_height * 0.5, center_z)
		)
	var end_z: float = center_z + closed_end_direction * hole_length * 0.5
	var end_visual := _add_part(parent, FENCE, Vector3(center_x, floor_y + 0.03, end_z), 0.0)
	end_visual.name = "%sEndVisual" % rail_name
	end_visual.scale = Vector3(hole_width * 0.5, visual_scale_y, visual_scale_y)
	_add_box_collision(
		parent,
		"%sEndCollision" % rail_name,
		Vector3(hole_width + rail_thickness, rail_height, rail_thickness),
		Vector3(center_x, floor_y + rail_height * 0.5, end_z)
	)


func _add_box_collision(parent: Node3D, collision_name: String, size: Vector3, local_position: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%s%03d" % [collision_name, generated_collision_count]
	collision.shape = shape
	collision.position = local_position
	collision.rotation = Vector3(pitch, yaw, 0.0)
	parent.add_child(collision)
	generated_collision_count += 1


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


func _add_castle_foundation(body: Node3D) -> void:
	# Patio central hasta z=±41 y cuatro hombros bajo las murallas. Entre los
	# hombros queda un corredor de 5,5 m, exactamente igual de ancho que la rampa.
	_add_foundation_block(body, "StoneFoundation", Vector3(126.0, CASTLE_COURTYARD_Y, 82.0), Vector3.ZERO)
	var gate_corridor_width := 5.5
	var shoulder_width := (126.0 - gate_corridor_width) * 0.5
	var shoulder_x := gate_corridor_width * 0.5 + shoulder_width * 0.5
	for gate_direction in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_add_foundation_block(
				body,
				"CastleFoundationShoulder",
				Vector3(shoulder_width, CASTLE_COURTYARD_Y, 9.0),
				Vector3(float(side) * shoulder_x, 0.0, float(gate_direction) * 45.5)
			)


func _add_foundation_block(body: Node3D, block_name: String, size: Vector3, base_position: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _foundation_material
	var visual := MeshInstance3D.new()
	visual.name = block_name
	visual.mesh = mesh
	visual.position = base_position + Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision%03d" % [block_name, generated_collision_count]
	collision.shape = shape
	collision.position = visual.position
	body.add_child(collision)
	generated_prop_count += 1
	generated_collision_count += 1


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
