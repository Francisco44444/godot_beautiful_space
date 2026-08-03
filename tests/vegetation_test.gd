extends SceneTree

## Comprueba que el bosque PBR sea determinista, esté dividido en celdas y no
## invada el sendero jugable. También valida el caballo visual animado.

const EXPECTED_TREE_COUNT := 340
const EXPECTED_ROCK_COUNT := 170
const EXPECTED_GRASS_COUNT := 7000
const EXPECTED_MEADOW_GRASS_COUNT := 32000
const EXPECTED_FERN_COUNT := 800
const EXPECTED_SHRUB_COUNT := 900
const MIN_EXPECTED_CELL_COUNT := 600


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := scene.instantiate()
	root.add_child(world)
	var scatter := world.get_node("VegetationScatter") as VegetationScatter
	var horse := world.get_node("Horse") as Horse

	for _frame in range(4):
		await process_frame

	var count_specs: Array[Array] = [
		["árboles", scatter.tree_count, scatter.generated_tree_count, EXPECTED_TREE_COUNT],
		["rocas", scatter.rock_count, scatter.generated_rock_count, EXPECTED_ROCK_COUNT],
		["matas", scatter.grass_count, scatter.generated_grass_count, EXPECTED_GRASS_COUNT],
		["hierba Bermuda", scatter.bermuda_grass_count, scatter.generated_bermuda_grass_count, EXPECTED_MEADOW_GRASS_COUNT],
		["helechos", scatter.fern_count, scatter.generated_fern_count, EXPECTED_FERN_COUNT],
		["arbustos", scatter.shrub_count, scatter.generated_shrub_count, EXPECTED_SHRUB_COUNT],
	]
	for spec in count_specs:
		var label: String = spec[0]
		var configured: int = spec[1]
		var generated: int = spec[2]
		var expected: int = spec[3]
		if configured != expected:
			_fail("El conteo exportado de %s debería ser %d, no %d." % [label, expected, configured])
			return
		if generated != configured:
			_fail("Se generaron %d elementos de %s; se esperaban %d." % [generated, label, configured])
			return

	var cell_specs: Array[Array] = [
		["TreeCells", scatter.generated_tree_count],
		["RockCells", scatter.generated_rock_count],
		["GrassCells", scatter.generated_grass_count],
		["MeadowGrassCells", scatter.generated_bermuda_grass_count],
		["FernCells", scatter.generated_fern_count],
		["ShrubCells", scatter.generated_shrub_count],
		["ForestDetailCells", scatter.forest_detail_count],
	]
	var counted_cells := 0
	for spec in cell_specs:
		var root_name: String = spec[0]
		var expected_instances: int = spec[1]
		var category := scatter.get_node_or_null(root_name) as Node3D
		if category == null:
			_fail("Falta la raíz de celdas %s." % root_name)
			return
		if category.get_child_count() == 0:
			_fail("La raíz %s no contiene ninguna celda." % root_name)
			return
		var instance_total := 0
		for child in category.get_children():
			var cell := child as MultiMeshInstance3D
			if cell == null or cell.multimesh == null or cell.multimesh.mesh == null:
				_fail("%s contiene una celda MultiMesh inválida." % root_name)
				return
			if cell.multimesh.instance_count <= 0:
				_fail("%s contiene una celda vacía." % root_name)
				return
			instance_total += cell.multimesh.instance_count
			counted_cells += 1
		if instance_total != expected_instances:
			_fail("%s contiene %d instancias; se esperaban %d." % [root_name, instance_total, expected_instances])
			return
	if scatter.generated_cell_count < MIN_EXPECTED_CELL_COUNT:
		_fail(
			"El bosque generó solo %d celdas; se esperaban al menos %d."
			% [scatter.generated_cell_count, MIN_EXPECTED_CELL_COUNT]
		)
		return
	if scatter.generated_cell_count != counted_cells:
		_fail("El contador de celdas no coincide con las %d celdas PBR instaladas." % counted_cells)
		return

	var tree_cells := scatter.get_node("TreeCells") as Node3D
	for child in tree_cells.get_children():
		var cell := child as MultiMeshInstance3D
		if cell.multimesh.mesh.get_surface_count() != 2:
			_fail("Cada pino adulto debe combinar corteza y follaje del LOD1.")
			return
		if cell.multimesh.mesh.get_aabb().size.z < 9.0:
			_fail("El bosque volvió a usar árboles jóvenes en lugar de variantes adultas.")
			return
		for index in cell.multimesh.instance_count:
			var position := cell.multimesh.get_instance_transform(index).origin
			if scatter.distance_to_route(Vector2(position.x, position.z)) < 7.35:
				_fail("Un árbol invadió el corredor despejado del sendero.")
				return

	var collision_body := scatter.get_node_or_null("DecorCollisions") as StaticBody3D
	var expected_collisions := scatter.generated_tree_count + scatter.generated_rock_count
	if collision_body == null or collision_body.get_child_count() != expected_collisions:
		_fail("Los %d árboles y rocas deben tener colisión." % expected_collisions)
		return

	var horse_model_root := horse.get_node_or_null("Visual/ModelRoot") as Node3D
	if horse_model_root == null or not horse_model_root.is_visible_in_tree():
		_fail("El GLB realista del caballo no está visible en el árbol.")
		return
	var horse_skeleton := _find_skeleton(horse_model_root)
	if horse_skeleton == null or horse_skeleton.get_bone_count() < 20:
		_fail("El caballo no conserva un esqueleto real válido.")
		return
	if not _has_visible_mesh(horse_model_root):
		_fail("El caballo no contiene ninguna malla visible y renderizable.")
		return
	var animator := horse_model_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animator == null:
		_fail("El caballo no contiene AnimationPlayer.")
		return
	for required_animation in ["Skeleton|1 Ilde", "Skeleton|Walk", "Skeleton|Gallop"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación del caballo: %s" % required_animation)
			return
	if animator.current_animation != "Skeleton|1 Ilde":
		_fail("El caballo no inicia con su animación realista Idle.")
		return

	var generated_cell_total := scatter.generated_cell_count
	world.queue_free()
	for _frame in range(8):
		await process_frame
	print(
		"VEGETATION TEST OK: %d celdas PBR, %d instancias y caballo animado."
		% [generated_cell_total, EXPECTED_TREE_COUNT + EXPECTED_ROCK_COUNT + EXPECTED_GRASS_COUNT + EXPECTED_MEADOW_GRASS_COUNT + EXPECTED_FERN_COUNT + EXPECTED_SHRUB_COUNT]
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _find_skeleton(parent: Node) -> Skeleton3D:
	for node in parent.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _has_visible_mesh(parent: Node) -> bool:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if (
			mesh_instance != null
			and mesh_instance.mesh != null
			and mesh_instance.mesh.get_surface_count() > 0
			and mesh_instance.is_visible_in_tree()
		):
			return true
	return false
