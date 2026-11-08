class_name BuildingAssembler
extends RefCounted

## Convierte un plan de BuildingSolver en nodos. Aquí ya no se toma ninguna
## decisión geométrica: el solver decidió, esto sólo instancia.
##
## Dos reglas de construcción, no de disciplina:
##
## 1. LO QUE SE PISA Y LO QUE SÓLO SE MIRA VIVEN EN RAMAS DISTINTAS. La rama
##    "Estructura" es un StaticBody3D y es el único sitio donde puede colgar una
##    CollisionShape3D; "Decorado" es un Node3D pelado, así que una forma perdida
##    ahí sería inerte de todos modos. Tejados, hastiales, aleros, buhardillas,
##    galerías, vigas y enredaderas van en Decorado. Ninguno colisiona.
##
## 2. LA COLISIÓN SE DERIVA DEL PLAN, NO DE LA MALLA. Nada de trimesh: hoy el
##    castillo del juego arrastra 33 colisiones de malla completa con 19.026
##    caras, tejados incluidos, y eso en una villa grande no se sostiene. Cada
##    forma es una primitiva que sale de una línea del plan.

const CELL := 2.0
const STOREY := 3.1
const FLOOR_THICKNESS := 0.25
## La losa del kit mide 2 x 2 x 0.02 y su cara de pisar cae en y = +0.01, así que
## hay que bajarla ese centímetro para que enrase con el forjado.
const FLOOR_TILE_TOP := 0.01
## El núcleo macizo del módulo de muro: 0.20 m, todo del lado interior. El resto
## de su espesor de 0.4065 es relieve de ladrillo por fuera y cornisa por dentro,
## y ninguno de los dos choca con nada.
const WALL_CORE := 0.20
const STAIR_WIDTH := 1.7
## Luz libre de puertas y arcos. Con 1.2 m pasa el héroe de sobra y quedan
## jambas de 0.4 m a cada lado, que es lo que da el módulo de 2 m.
const DOOR_CLEAR_WIDTH := 1.2
const DOOR_CLEAR_HEIGHT := 2.2

var structure: StaticBody3D = null
var dressing: Node3D = null
var mesh_count := 0
var collision_count := 0
var origin_shift := Vector3.ZERO
var _floor_tiles: Array[Vector3] = []
static var _trimmed_roofs: Dictionary = {}


func assemble(
	plan: BuildingSolver,
	recipe: Dictionary,
	catalog: Dictionary,
	target: StaticBody3D = null
) -> Node3D:
	## Con `target` el edificio se monta DENTRO de un cuerpo que ya existe, en vez
	## de crear el suyo. El mundo cuelga cada casa como hijo directo de
	## MedievalSetDressing y la reconoce por su nombre; si envolviera las casas en
	## un contenedor propio, el mundo dejaría de verlas.
	var root: Node3D
	if target != null:
		root = target
		structure = target
	else:
		root = Node3D.new()
		root.name = String(recipe.get("id", "Edificio"))
		structure = StaticBody3D.new()
		structure.name = "Estructura"
		root.add_child(structure)
	dressing = Node3D.new()
	dressing.name = "Decorado"
	root.add_child(dressing)
	mesh_count = 0
	collision_count = 0
	origin_shift = plan.centre_offset()
	_floor_tiles.clear()

	var volumes: Array = recipe["volumes"]
	_emit_foundations(volumes, catalog)
	_emit_walls(plan, volumes, catalog)
	_emit_floors(plan, volumes)
	_emit_stairs(plan, volumes, catalog)
	_emit_roofs(plan, volumes, catalog)
	_emit_floor_tiles(catalog)
	return root


func _emit_floor_tiles(catalog: Dictionary) -> void:
	## El forjado se emitía sólo como colisión. Se pisaba, sí, pero desde la
	## planta de abajo la de arriba era un vacío: se veía el tejado por dentro.
	## Las losas van en un MultiMesh —hay 2.396 celdas en la isla— y sin colisión,
	## porque el suelo que se pisa ya lo pone la placa.
	if _floor_tiles.is_empty():
		return
	var tile := _floor_mesh(catalog)
	if tile == null:
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = tile
	multi.instance_count = _floor_tiles.size()
	var poses: Array[Transform3D] = []
	for index in _floor_tiles.size():
		var pose := Transform3D(
			Basis(Vector3.UP, float((index * 7) % 4) * PI * 0.5),
			_floor_tiles[index] + origin_shift - Vector3(0.0, FLOOR_TILE_TOP, 0.0)
		)
		multi.set_instance_transform(index,pose)
		poses.append(pose)
	var node := MultiMeshInstance3D.new()
	node.name = "Solado"
	node.multimesh = multi
	node.set_meta("oclusion_estructura",true)
	node.set_meta("poses_oclusion",poses)
	dressing.add_child(node)
	mesh_count += _floor_tiles.size()


static func _floor_mesh(catalog: Dictionary) -> Mesh:
	var path := String(catalog.get("root", BuildingCatalog.ROOT))
	var scene := load(path + String(catalog.get("floor", "Floor_UnevenBrick")) + ".gltf") as PackedScene
	if scene == null:
		return null
	var probe := scene.instantiate()
	var found: Mesh = null
	for child in probe.get_children():
		if child is MeshInstance3D:
			found = (child as MeshInstance3D).mesh
			break
	probe.queue_free()
	return found


func _emit_foundations(volumes: Array, catalog: Dictionary) -> void:
	## Una losa por cuerpo, a ras. El taller dejaba juntas con escalón entre
	## cuerpos porque cada uno traía su propia cota.
	for volume in volumes:
		var origin: Vector2i = volume["origin"]
		var size: Vector2i = volume["size"]
		var centre := Vector3(
			(float(origin.x) + float(size.x) * 0.5) * CELL,
			0.0,
			(float(origin.y) + float(size.y) * 0.5) * CELL
		)
		var base_level := int(volume.get("base_level", 0))
		if base_level > 0:
			continue
		_add_box(
			"Cimiento",
			Vector3(float(size.x) * CELL, FLOOR_THICKNESS, float(size.y) * CELL),
			centre + Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0),
			0.0
		)


func _emit_walls(plan: BuildingSolver, volumes: Array, catalog: Dictionary) -> void:
	for wall in plan.walls:
		var placement := wall_transform(wall)
		var style := String(wall["style"])
		var level := int(wall["level"])
		var mesh_name := _wall_mesh(catalog, style, level, wall)
		if not mesh_name.is_empty():
			_add_mesh(structure, mesh_name, placement, catalog)
		var opening := int(wall.get("opening", BuildingSolver.Opening.SOLID))
		var yaw := placement.basis.get_euler().y
		var inward := Vector3(0.0, 0.0, -WALL_CORE * 0.5).rotated(Vector3.UP, yaw)
		if opening == BuildingSolver.Opening.SOLID:
			_add_box(
				"Muro",
				Vector3(CELL, STOREY, WALL_CORE),
				placement.origin + inward + Vector3(0.0, STOREY * 0.5, 0.0),
				yaw
			)
			continue
		# Un hueco no lleva caja en el medio, o dejaría de ser un hueco: se
		# reduce a dos jambas y un dintel, y por el centro se pasa andando.
		var jamb := (CELL - DOOR_CLEAR_WIDTH) * 0.5
		for offset in PackedFloat32Array([-(CELL - jamb) * 0.5, (CELL - jamb) * 0.5]):
			var lateral := Vector3(offset, 0.0, 0.0).rotated(Vector3.UP, yaw)
			_add_box(
				"Jamba",
				Vector3(jamb, STOREY, WALL_CORE),
				placement.origin + lateral + inward + Vector3(0.0, STOREY * 0.5, 0.0),
				yaw
			)
		var lintel := STOREY - DOOR_CLEAR_HEIGHT
		_add_box(
			"Dintel",
			Vector3(DOOR_CLEAR_WIDTH, lintel, WALL_CORE),
			placement.origin + inward + Vector3(0.0, STOREY - lintel * 0.5, 0.0),
			yaw
		)


func wall_transform(wall: Dictionary) -> Transform3D:
	## Coloca la pieza sobre la ARISTA, no sobre la celda, y mirando afuera.
	##
	## El +Z local del módulo es su cara buena: ahí es donde el kit cuelga las
	## contraventanas (z de +0.09 a +0.56), los balcones (+0.90 a +1.10) y las
	## aceras (0 a +0.70). El núcleo macizo, en cambio, está entero del lado
	## negativo, de z=0 a z=-0.20. Por eso el giro no puede depender sólo de la
	## orientación de la arista: tiene que depender del LADO de la celda que la
	## arista cierra, o media casa acaba enseñando el revoco interior a la calle.
	var edge: Vector4i = wall["edge"]
	var y := float(edge.w) * STOREY
	var yaw := 0.0
	match int(wall["side"]):
		0:
			yaw = -PI * 0.5
		1:
			yaw = PI * 0.5
		2:
			yaw = PI
		_:
			yaw = 0.0
	var origin: Vector3
	if edge.x == 0:
		origin = Vector3(float(edge.y) * CELL, y, (float(edge.z) + 0.5) * CELL)
	else:
		origin = Vector3((float(edge.y) + 0.5) * CELL, y, float(edge.z) * CELL)
	return Transform3D(Basis(Vector3.UP, yaw), origin)


func _wall_mesh(catalog: Dictionary, style: String, level: int, wall: Dictionary) -> String:
	var family: Dictionary = catalog.get(style, catalog.get("stone", {}))
	if family.is_empty():
		return ""
	match int(wall.get("opening", BuildingSolver.Opening.SOLID)):
		BuildingSolver.Opening.DOOR:
			return String(family.get("door", ""))
		BuildingSolver.Opening.ARCH:
			return String(family.get("party", ""))
	if level == 0:
		return String(family.get("ground", ""))
	# Variedad determinista: una fachada entera de ventanas idénticas se lee como
	# un bloque de oficinas. La arista decide, así que la misma casa sale siempre
	# igual y dos casas contiguas no salen iguales.
	var edge: Vector4i = wall["edge"]
	var seed := absi(edge.y * 73856093 + edge.z * 19349663 + edge.w * 83492791)
	match seed % 4:
		0:
			return String(family.get("upper", ""))
		1:
			return String(family.get("narrow", family.get("window", family.get("upper", ""))))
		_:
			return String(family.get("window", family.get("upper", "")))


func _emit_floors(plan: BuildingSolver, volumes: Array) -> void:
	## El forjado de la planta 0 lo pone el cimiento; a partir de la 1 hace falta
	## una placa. Se emite CELDA A CELDA, saltando las que el tramo de escalera
	## necesita libres: una losa maciza de toda la planta deja la escalera
	## subiendo contra el techo, y entonces la planta alta es inalcanzable por
	## mucho que la escalera exista. Medido: la cápsula entraba y no subía.
	var holes := {}
	for stair in plan.stairs:
		for cell in stair.get("holes", []):
			holes[Vector3i((cell as Vector2i).x, (cell as Vector2i).y, int(stair["level"]) + 1)] = true
	var spiral_volumes := {}
	for stair in plan.stairs:
		if String(stair.get("kind", "straight")) == "spiral":
			spiral_volumes[int(stair["volume"])] = true

	for entry in plan.floors_plan:
		var level := int(entry["level"])
		# Una torre de caracol no lleva forjados intermedios: el propio caracol
		# es el suelo por el que se sube, como en una torre de verdad.
		if level > 0 and spiral_volumes.has(int(entry["volume"])):
			continue
		var origin: Vector2i = entry["origin"]
		var size: Vector2i = entry["size"]
		var y := float(level) * STOREY
		for i in range(origin.x, origin.x + size.x):
			for j in range(origin.y, origin.y + size.y):
				if holes.has(Vector3i(i, j, level)):
					continue
				var centre := Vector3(
					(float(i) + 0.5) * CELL, y, (float(j) + 0.5) * CELL)
				# La planta baja ya se pisa sobre el cimiento: sólo le falta la
				# losa que se ve. De la primera para arriba hace falta el forjado.
				if level > 0:
					_add_box(
						"Forjado",
						Vector3(CELL, FLOOR_THICKNESS, CELL),
						centre - Vector3(0.0, FLOOR_THICKNESS * 0.5, 0.0),
						0.0
					)
				_floor_tiles.append(centre)


func _emit_stairs(plan: BuildingSolver, volumes: Array, catalog: Dictionary) -> void:
	## Una cuña convexa por tramo: se sube andando, sin escalones de física que
	## enganchen el pie.
	for stair in plan.stairs:
		if String(stair.get("kind", "straight")) == "spiral":
			var volume: Dictionary = volumes[int(stair["volume"])]
			var origin: Vector2i = volume["origin"]
			var size: Vector2i = volume["size"]
			_emit_spiral_step(
				stair,
				(float(origin.x) + float(size.x) * 0.5) * CELL,
				(float(origin.y) + float(size.y) * 0.5) * CELL
			)
			continue
		var column := int(stair["column_cell"])
		var run_start := int(stair["run_start"])
		var ascending := bool(stair["ascending"])
		var x := (float(column) + 0.5) * CELL
		var near := float(run_start) * CELL
		var far := float(run_start + BuildingSolver.STAIR_RUN_CELLS) * CELL
		var from_z := near if ascending else far
		var to_z := far if ascending else near
		_add_ramp(
			"Escalera",
			Vector3(x, float(stair["base_y"]), from_z),
			Vector3(x, float(stair["top_y"]), to_z),
			STAIR_WIDTH
		)
		# Peldaños reales del kit, colocados sobre la misma pendiente que la
		# colisión. Antes se emitía solamente la cuña invisible.
		var yaw := PI if ascending else 0.0
		var direction := -1.0 if ascending else 1.0
		var run_scale := absf(to_z - from_z) / 4.619539
		var step_basis := Basis(Vector3.UP, yaw).scaled(Vector3(
			STAIR_WIDTH / 1.67618, STOREY / 3.024588, run_scale))
		_add_mesh(dressing, "Stair_Interior_Simple", Transform3D(step_basis,
			Vector3(x, float(stair["base_y"]), from_z - direction * 0.034729 * run_scale)), catalog)
		var rail_scale := absf(to_z - from_z) / 4.563224
		var rail_basis := Basis(Vector3.UP, yaw).scaled(Vector3(
			STAIR_WIDTH / 1.716711, STOREY / 3.024588, rail_scale))
		_add_mesh(dressing, "Stair_Interior_Rails", Transform3D(rail_basis,
			Vector3(x, float(stair["base_y"]), from_z - direction * 0.244316 * rail_scale)), catalog)
		# Un apoyo vertical bajo el desembarco evita que el tramo parezca flotar.
		_add_stair_support(Vector3(x, float(stair["base_y"]), to_z), STOREY)


func _add_stair_support(foot: Vector3, height: float) -> void:
	var post := MeshInstance3D.new()
	post.name = "StairTimberSupport"
	var box := BoxMesh.new()
	box.size = Vector3(0.16, height, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.13, 0.07)
	box.material = material
	post.mesh = box
	post.position = foot + origin_shift + Vector3(0.0, height * 0.5, 0.0)
	dressing.add_child(post)
	mesh_count += 1


func _emit_spiral_step(stair: Dictionary, centre_x: float, centre_z: float) -> void:
	## Un cuarto de vuelta del caracol de una torre, aproximado por una cuña
	## recta entre sus dos extremos: la cuerda del arco. Con cuatro por planta el
	## error contra la hélice real es de centímetros y sí es una forma convexa,
	## que es lo único que la física acepta de una pieza.
	var steps := int(BuildingSolver.SPIRAL_STEPS)
	var step := int(stair["step"])
	var radius := float(stair["radius"])
	var from_angle := TAU * float(step) / float(steps)
	var to_angle := TAU * float(step + 1) / float(steps)
	var mid := radius * 0.5
	var from := Vector3(
		centre_x + cos(from_angle) * mid, float(stair["base_y"]), centre_z + sin(from_angle) * mid)
	var to := Vector3(
		centre_x + cos(to_angle) * mid, float(stair["top_y"]), centre_z + sin(to_angle) * mid)
	_add_free_ramp("Caracol", from, to, radius)


func _add_free_ramp(node_name: String, from: Vector3, to: Vector3, width: float) -> void:
	## Cuña entre dos puntos cualesquiera, no sólo a lo largo de Z.
	var span := to - from
	var flat := Vector3(span.x, 0.0, span.z)
	if flat.length() <= 0.001:
		return
	var forward := flat.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var length := flat.length()
	var thickness := 0.35
	var half := width * 0.5
	var points := PackedVector3Array()
	var edges: PackedFloat32Array = PackedFloat32Array([-half, half])
	for edge in edges:
		var lateral: Vector3 = side * edge
		points.append(lateral)
		points.append(lateral + Vector3.DOWN * thickness)
		points.append(lateral + forward * length + Vector3.UP * span.y)
		points.append(lateral + forward * length + Vector3.UP * (span.y - thickness))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = "%s%03d" % [node_name, collision_count]
	collision.shape = shape
	collision.position = from + origin_shift
	structure.add_child(collision)
	collision_count += 1


func _emit_roofs(plan: BuildingSolver, volumes: Array, catalog: Dictionary) -> void:
	## Cubierta: sólo malla, jamás colisión. Es la regla que hace que el héroe no
	## se quede clavado en un alero ni pueda andar por encima del tejado.
	for roof in plan.roofs:
		var volume: Dictionary = volumes[int(roof["volume"])]
		var origin: Vector2i = volume["origin"]
		var size: Vector2i = volume["size"]
		var shift: Vector2 = roof.get("shift", Vector2.ZERO)
		var centre := Vector3(
			(float(origin.x) + float(size.x) * 0.5) * CELL + shift.x,
			float(roof["anchor_y"]),
			(float(origin.y) + float(size.y) * 0.5) * CELL + shift.y
		)
		_add_roof_mesh(String(roof["mesh"]), Transform3D(Basis.IDENTITY, centre), roof, catalog)
		# El hastial cierra el frontón. Sin él se ve el hueco del bajo cubierta
		# desde fuera y la casa parece a medio construir.
		var front := String(roof.get("front", ""))
		if front.is_empty():
			continue
		var half_depth := float(size.y) * CELL * 0.5
		_add_roof_mesh(
			front,
			Transform3D(Basis.IDENTITY, centre + Vector3(0.0, 0.0, half_depth)),
			roof, catalog
		)
		_add_roof_mesh(
			front,
			Transform3D(Basis(Vector3.UP, PI), centre - Vector3(0.0, 0.0, half_depth)),
			roof, catalog
		)


func _add_roof_mesh(mesh_name: String, placement: Transform3D, roof: Dictionary, catalog: Dictionary) -> void:
	var minimum: Vector2 = roof.get("clip_min", Vector2(-10000, -10000))
	var maximum: Vector2 = roof.get("clip_max", Vector2(10000, 10000))
	if minimum == Vector2(-10000, -10000) and maximum == Vector2(10000, 10000):
		_add_mesh(dressing, mesh_name, placement, catalog)
		return
	var path := String(catalog.get("root", BuildingCatalog.ROOT))
	var scene := load(path + mesh_name + ".gltf") as PackedScene
	var source := scene.instantiate() as Node3D
	# Clip in the source's coordinates, so the resulting mesh is shared by all
	# identical houses regardless of their world location or number of floors.
	var local_min := Vector2(minimum.x - placement.origin.x, minimum.y - placement.origin.z)
	var local_max := Vector2(maximum.x - placement.origin.x, maximum.y - placement.origin.z)
	var key := "%s:%s:%s:%s" % [mesh_name, local_min, local_max, placement.basis]
	var mesh: ArrayMesh = _trimmed_roofs.get(key)
	if mesh == null:
		mesh = ArrayMesh.new()
		for child in source.find_children("*", "MeshInstance3D", true, false):
			var visual := child as MeshInstance3D
			for surface in visual.mesh.get_surface_count():
				_clip_roof_surface(mesh, visual.mesh, surface, placement.basis * visual.transform.basis,
					local_min, local_max)
		_trimmed_roofs[key] = mesh
	source.free()
	if mesh.get_surface_count() == 0:
		return
	var visual := MeshInstance3D.new()
	visual.name = "%sTrimmed%03d" % [mesh_name, mesh_count]
	visual.mesh = mesh
	visual.set_meta("oclusion_estructura",true)
	visual.position = placement.origin + origin_shift
	dressing.add_child(visual)
	mesh_count += 1


func _clip_roof_surface(output: ArrayMesh, mesh: Mesh, surface: int, basis: Basis,
	minimum: Vector2, maximum: Vector2) -> void:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var emitted := 0
	for offset in range(0, count, 3):
		var polygon: Array[Dictionary] = []
		for corner in 3:
			var index := indices[offset + corner] if not indices.is_empty() else offset + corner
			polygon.append({"p": basis * vertices[index], "n": (basis * normals[index]).normalized(),
				"uv": uvs[index] if not uvs.is_empty() else Vector2.ZERO})
		for plane in [Vector3(1, 0, minimum.x), Vector3(-1, 0, -maximum.x),
			Vector3(0, 1, minimum.y), Vector3(0, -1, -maximum.y)]:
			polygon = _clip_polygon(polygon, plane)
		for corner in range(1, polygon.size() - 1):
			for point in [polygon[0], polygon[corner], polygon[corner + 1]]:
				tool.set_normal(point["n"])
				tool.set_uv(point["uv"])
				tool.add_vertex(point["p"])
				emitted += 1
	if emitted > 0:
		tool.set_material(mesh.surface_get_material(surface))
		tool.generate_tangents()
		tool.commit(output)


func _clip_polygon(polygon: Array[Dictionary], plane: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polygon.is_empty():
		return result
	var previous: Dictionary = polygon[-1]
	var previous_distance: float = previous["p"].x * plane.x + previous["p"].z * plane.y - plane.z
	for current in polygon:
		var distance: float = current["p"].x * plane.x + current["p"].z * plane.y - plane.z
		if (distance >= 0.0) != (previous_distance >= 0.0):
			var fraction := previous_distance / (previous_distance - distance)
			result.append({"p": (previous["p"] as Vector3).lerp(current["p"], fraction),
				"n": (previous["n"] as Vector3).lerp(current["n"], fraction).normalized(),
				"uv": (previous["uv"] as Vector2).lerp(current["uv"], fraction)})
		if distance >= 0.0:
			result.append(current)
		previous = current
		previous_distance = distance
	return result


func _add_mesh(parent: Node3D, mesh_name: String, placement: Transform3D, catalog: Dictionary) -> void:
	var path := String(catalog.get("root", "res://assets/quaternius/store_bundle/glTF/"))
	var scene := load(path + mesh_name + ".gltf") as PackedScene
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	if node == null:
		return
	node.name = "%s%03d" % [mesh_name, mesh_count]
	node.transform = placement.translated(origin_shift)
	node.set_meta("oclusion_estructura",true)
	parent.add_child(node)
	mesh_count += 1


func _add_box(node_name: String, box_size: Vector3, centre: Vector3, yaw: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision := CollisionShape3D.new()
	collision.name = "%s%03d" % [node_name, collision_count]
	collision.shape = shape
	collision.position = centre + origin_shift
	collision.rotation.y = yaw
	structure.add_child(collision)
	collision_count += 1


func _add_ramp(node_name: String, from: Vector3, to: Vector3, width: float) -> void:
	## Prisma convexo entre las dos cotas reales del forjado. Ocho vértices, no
	## una malla de escalones.
	# El tramo corre siempre a lo largo de Z, así que la cuña es axial: ocho
	# vértices y ninguna trigonometría que se pueda torcer.
	var rise := to.y - from.y
	var reach := to.z - from.z
	if absf(reach) <= 0.001:
		return
	var points := PackedVector3Array()
	var half := width * 0.5
	var thickness := 0.35
	var sides: PackedFloat32Array = PackedFloat32Array([-half, half])
	for side in sides:
		points.append(Vector3(side, 0.0, 0.0))
		points.append(Vector3(side, -thickness, 0.0))
		points.append(Vector3(side, rise, reach))
		points.append(Vector3(side, rise - thickness, reach))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = "%s%03d" % [node_name, collision_count]
	collision.shape = shape
	collision.position = from + origin_shift
	structure.add_child(collision)
	collision_count += 1
