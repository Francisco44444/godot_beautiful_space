extends SceneTree

## La contrapartida física de la prueba del solver: aquí los edificios se montan
## de verdad y se miden los nodos resultantes, que es donde el usuario veía el
## desastre. "Bonito por fuera, fatal por dentro" se traduce en cuatro números
## que tienen que dar cero.

const Recipes := preload("res://scripts/building_recipes.gd")
const Solver := preload("res://scripts/building_solver.gd")
const Assembler := preload("res://scripts/building_assembler.gd")
const ROOT := "res://assets/quaternius/store_bundle/glTF/"

## Qué cuenta como cruce. Dos muros que se encuentran en una esquina comparten
## el poste: se solapan medio espesor en x y medio en z, 0.205 m cada uno, y eso
## es construcción normal. Lo que NO es normal es la firma medida en el taller,
## 0.41 x 3.12 x 2.00 m, que son dos módulos idénticos en la misma ranura: se
## solapan un módulo entero A LO LARGO y una planta entera de alto. El
## discriminante, por tanto, no es el solape total sino en cuántos ejes supera
## el metro: la esquina en uno, el muro doblado en dos.
const CROSS_SPAN := 1.0
## Y aun sin llegar a duplicarse, ninguna pieza debe morder a otra más de lo que
## mide de espesor.
const MAX_BITE := 0.45


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var metrics := _measure(Recipes.ROOF_MESHES)
	var catalog := _catalog()
	for recipe in Recipes.all():
		var name: String = recipe["display_name"]
		var solver = Solver.new()
		if not solver.solve(recipe, metrics):
			_fail("'%s' no resuelve: %s" % [name, solver.errors])
			return
		var assembler = Assembler.new()
		var building: Node3D = assembler.assemble(solver, recipe, catalog)
		root.add_child(building)
		await process_frame

		var estructura := building.get_node_or_null("Estructura") as StaticBody3D
		var decorado := building.get_node_or_null("Decorado") as Node3D
		if estructura == null or decorado == null:
			_fail("'%s' no separa Estructura de Decorado." % name)
			return

		# 1. Ni una forma de colisión fuera del cuerpo estático.
		var loose := _collision_shapes(decorado)
		if loose.size() != 0:
			_fail("'%s' cuelga %d colisiones del Decorado." % [name, loose.size()])
			return

		# 2. Ni una colisión de malla completa. El castillo actual arrastra 33
		#    con 19.026 caras, tejados incluidos; en una villa grande no cabe.
		var trimesh := 0
		for shape in _collision_shapes(estructura):
			if shape.shape is ConcavePolygonShape3D:
				trimesh += 1
		if trimesh != 0:
			_fail("'%s' usa %d colisiones de malla completa." % [name, trimesh])
			return

		# 3. Ninguna colisión por encima del alero: el tejado no se pisa.
		var eave := _highest_eave(solver)
		for shape in _collision_shapes(estructura):
			var top := shape.global_transform.origin.y + _shape_half_height(shape)
			if top > eave + 0.05:
				_fail("'%s' tiene colisión a %.2f m, por encima del alero (%.2f m): %s" % [
					name, top, eave, shape.name])
				return

		# 4. Ninguna pieza estructural cruzada con otra.
		var measured := _count_crossings(estructura)
		if int(measured["crossings"]) != 0:
			_fail("'%s' tiene %d piezas estructurales cruzadas (la peor, %s)." % [
				name, measured["crossings"], measured["worst_pair"]])
			return
		if float(measured["worst_bite"]) > MAX_BITE:
			_fail("'%s' tiene dos piezas mordiéndose %.3f m (máximo %.2f): %s" % [
				name, measured["worst_bite"], MAX_BITE, measured["worst_pair"]])
			return

		print("[ok] %s: %d mallas, %d colisiones, 0 cruces, 0 trimesh." % [
			name, assembler.mesh_count, assembler.collision_count])
		building.queue_free()
		await process_frame

	print("Edificios montados y medidos: geometría limpia.")
	quit()


func _catalog() -> Dictionary:
	return BuildingCatalog.families()


func _highest_eave(solver) -> float:
	var top := 0.0
	for roof in solver.roofs:
		top = maxf(top, float(roof["anchor_y"]))
	for entry in solver.floors_plan:
		top = maxf(top, float(entry["y"]) + Solver.STOREY)
	return top


func _shape_half_height(shape: CollisionShape3D) -> float:
	if shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size.y * 0.5
	if shape.shape is ConvexPolygonShape3D:
		var high := -INF
		for point in (shape.shape as ConvexPolygonShape3D).points:
			high = maxf(high, point.y)
		return high
	return 0.0


func _collision_shapes(node: Node) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if node is CollisionShape3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_collision_shapes(child))
	return out


func _count_crossings(body: StaticBody3D) -> Dictionary:
	var boxes: Array[AABB] = []
	var names: PackedStringArray = PackedStringArray()
	for shape in _collision_shapes(body):
		if not (shape.shape is BoxShape3D):
			continue
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var centre := shape.global_transform.origin
		# Una caja girada 90 grados intercambia sus lados x y z.
		if absf(sin(shape.rotation.y)) > 0.5:
			size = Vector3(size.z, size.y, size.x)
		boxes.append(AABB(centre - size * 0.5, size))
		names.append(shape.name)
	var crossings := 0
	var worst_bite := 0.0
	var worst_pair := ""
	for a in boxes.size():
		for b in range(a + 1, boxes.size()):
			var overlap := _overlap(boxes[a], boxes[b])
			if overlap.x <= 0.0 or overlap.y <= 0.0 or overlap.z <= 0.0:
				continue
			var spans := 0
			for axis in [overlap.x, overlap.y, overlap.z]:
				if axis > CROSS_SPAN:
					spans += 1
			var bite := minf(overlap.x, minf(overlap.y, overlap.z))
			if bite > worst_bite:
				worst_bite = bite
				worst_pair = "%s x %s -> %.2f x %.2f x %.2f" % [
					names[a], names[b], overlap.x, overlap.y, overlap.z]
			if spans >= 2:
				crossings += 1
	return {"crossings": crossings, "worst_bite": worst_bite, "worst_pair": worst_pair}


func _overlap(a: AABB, b: AABB) -> Vector3:
	return Vector3(
		minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x),
		minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y),
		minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	)


func _measure(names) -> Dictionary:
	var metrics := {}
	for mesh_name in names:
		var scene := load(ROOT + mesh_name + ".gltf") as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate()
		var box := AABB()
		var first := true
		for mesh_instance in _mesh_instances(node):
			var stack := Transform3D.IDENTITY
			var walker: Node = mesh_instance
			while walker != null and walker != node.get_parent():
				if walker is Node3D:
					stack = (walker as Node3D).transform * stack
				walker = walker.get_parent()
			var world: AABB = stack * mesh_instance.get_aabb()
			box = world if first else box.merge(world)
			first = false
		node.queue_free()
		if not first:
			metrics[mesh_name] = box
	return metrics


func _mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_mesh_instances(child))
	return out


func _fail(message: String) -> void:
	push_error(message)
	printerr(message)
	quit(1)
