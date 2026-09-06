extends SceneTree

## Blinda la geometría de los edificios ANTES de instanciar nada: es una prueba
## pura sobre el plan, sin escena y sin física, así que corre en milisegundos.
##
## Cada aserto corresponde a un defecto medido en las casas del taller, que eran
## bonitas por fuera y un desastre por dentro:
##   - los cuerpos se solapaban medio módulo, y cada uno pintaba su pared en la
##     cara compartida: 11, 16, 16 y 33 parejas de muros cruzados por casa, con
##     la firma exacta de 0.41 x 3.12 x 2.00 m, que son dos módulos idénticos
##     metidos en la misma ranura;
##   - el tejado del cuerpo bajo se metía dentro del alto: 8/16, 9/18, 11/19 y
##     10/23 faldones hundidos, el peor 3.77 m, más de una planta entera;
##   - y sólo había una escalera por planta, en el otro extremo cada vez.

const ROOT := "res://assets/quaternius/store_bundle/glTF/"
const Recipes := preload("res://scripts/building_recipes.gd")
const Solver := preload("res://scripts/building_solver.gd")

const EXPECTED_RECIPES := 4
const MIN_PITCH := 20.0
const MAX_PITCH := 32.0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var metrics := _measure_roofs()
	if metrics.size() != Recipes.ROOF_MESHES.size():
		_fail("Faltan cubiertas del kit: medidas %d de %d." % [
			metrics.size(), Recipes.ROOF_MESHES.size()])
		return

	var recipes: Array[Dictionary] = Recipes.all()
	if recipes.size() != EXPECTED_RECIPES:
		_fail("Se esperaban %d recetas y hay %d." % [EXPECTED_RECIPES, recipes.size()])
		return

	for recipe in recipes:
		var name: String = recipe["display_name"]
		var solver = Solver.new()
		var ok: bool = solver.solve(recipe, metrics)
		if not ok:
			_fail("La receta '%s' no resuelve limpia: %s" % [name, solver.errors])
			return
		var report: Dictionary = solver.report

		# Ninguna celda con dos dueños: el solape de medio módulo del taller
		# deja de ser representable cuando la clave es entera.
		if int(report["cell_conflicts"]) != 0:
			_fail("'%s' tiene %d celdas reclamadas dos veces." % [name, report["cell_conflicts"]])
			return

		# Una arista, un muro. Aquí muere el muro doblado.
		if int(report["duplicate_edges"]) != 0:
			_fail("'%s' intentó levantar %d muros sobre aristas ya ocupadas." % [
				name, report["duplicate_edges"]])
			return
		var seen := {}
		for wall in solver.walls:
			var key: Vector4i = wall["edge"]
			if seen.has(key):
				_fail("'%s' repite muro en la arista %s." % [name, key])
				return
			seen[key] = true

		# Ningún cuerpo elevado flotando.
		if int(report["unsupported_cells"]) != 0:
			_fail("'%s' tiene %d celdas sin apoyo debajo." % [name, report["unsupported_cells"]])
			return

		# Ningún tejado metido dentro de un vecino más alto.
		if int(report["roof_below_eave_count"]) != 0:
			_fail("'%s' mete %d faldones dentro de otro cuerpo (el peor, %.2f m)." % [
				name, report["roof_below_eave_count"], report["worst_roof_dip"]])
			return

		# Dos escaleras por transición de planta, no una. Las torres suben en
		# caracol y aportan un tramo por cuarto de vuelta, no dos.
		var per_transition := {}
		var spiral_transitions := {}
		for stair in solver.stairs:
			var key := Vector2i(int(stair["volume"]), int(stair["level"]))
			if String(stair.get("kind", "straight")) == "spiral":
				spiral_transitions[key] = int(spiral_transitions.get(key, 0)) + 1
				continue
			per_transition[key] = int(per_transition.get(key, 0)) + 1
			var pitch: float = stair["pitch_degrees"]
			if pitch < MIN_PITCH or pitch > MAX_PITCH:
				_fail("'%s' tiene una escalera de %.1f grados, fuera de %.0f-%.0f." % [
					name, pitch, MIN_PITCH, MAX_PITCH])
				return
		if per_transition.is_empty():
			_fail("'%s' no tiene ninguna escalera." % name)
			return
		for key in spiral_transitions:
			if int(spiral_transitions[key]) != Solver.SPIRAL_STEPS:
				_fail("'%s' tiene un caracol de %d tramos en %s; deben ser %d." % [
					name, spiral_transitions[key], key, Solver.SPIRAL_STEPS])
				return
		for key in per_transition:
			if int(per_transition[key]) != 2:
				_fail("'%s' tiene %d escaleras en la transición %s; deben ser dos." % [
					name, per_transition[key], key])
				return

		# Los dos tramos de una misma transición van a lados opuestos del cuerpo,
		# para que no haya que cruzar la planta entera como en la casa vieja. Se
		# compara contra el centro del cuerpo, porque la x de una escalera es su
		# coordenada en la receta y no un desplazamiento respecto a ese centro.
		var volumes: Array = recipe["volumes"]
		for key in per_transition:
			var volume: Dictionary = volumes[key.x]
			var origin: Vector2i = volume["origin"]
			var size: Vector2i = volume["size"]
			var middle := (float(origin.x) + float(size.x) * 0.5) * Solver.CELL
			var sides: Array[float] = []
			for stair in solver.stairs:
				if String(stair.get("kind", "straight")) == "spiral":
					continue
				if Vector2i(int(stair["volume"]), int(stair["level"])) == key:
					sides.append(float(stair["x"]) - middle)
			if sides.size() == 2 and signf(sides[0]) == signf(sides[1]):
				_fail("'%s' pone las dos escaleras del mismo lado en %s (%s)." % [
					name, key, sides])
				return

		print("[ok] %s: %d muros, %d forjados, %d escaleras, %d cubiertas." % [
			name, report["wall_count"], report["floor_count"],
			report["stair_count"], report["roof_count"]])

	print("Geometría de edificios verificada.")
	quit()


func _measure_roofs() -> Dictionary:
	var metrics := {}
	for mesh_name in Recipes.ROOF_MESHES:
		var scene := load(ROOT + mesh_name + ".gltf") as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate()
		var box := AABB()
		var first := true
		for mesh_instance in _mesh_instances(node):
			var basis_transform := Transform3D.IDENTITY
			var walker: Node = mesh_instance
			while walker != null and walker != node.get_parent():
				if walker is Node3D:
					basis_transform = (walker as Node3D).transform * basis_transform
				walker = walker.get_parent()
			var world: AABB = basis_transform * mesh_instance.get_aabb()
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
