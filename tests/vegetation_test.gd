extends SceneTree

## Comprueba que el valle Quaternius sea determinista, esté dividido en celdas
## y no invada el sendero jugable. También valida personajes y caballo.

const EXPECTED_TREE_COUNT := 760
const EXPECTED_ROCK_COUNT := 220
const EXPECTED_GRASS_COUNT := 14000
const EXPECTED_FERN_COUNT := 520
const EXPECTED_SHRUB_COUNT := 620
const EXPECTED_FLOWER_COUNT := 1500
const EXPECTED_MUSHROOM_COUNT := 190
const EXPECTED_PATH_PEBBLE_COUNT := 720
const EXPECTED_CHARACTER_COUNT := 50
const MIN_EXPECTED_CELL_COUNT := 1200


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
	var clouds := world.get_node_or_null("AnimatedClouds") as Node3D
	var wildlife := world.get_node_or_null("QuaterniusWildlife") as Node3D
	var medieval_set := world.get_node_or_null("MedievalSetDressing") as MedievalSetDressing

	for _frame in range(4):
		await process_frame

	if wildlife == null or int(wildlife.get("generated_animal_count")) < 6:
		_fail("El valle debe cargar fauna Quaternius desde el pack de animales.")
		return
	if int(wildlife.get("reactive_animal_count")) != int(wildlife.get("generated_animal_count")):
		_fail("Toda la fauna colocada debe reaccionar cuando detecta al jugador.")
		return
	if medieval_set == null or medieval_set.generated_village_count < 3 or medieval_set.generated_house_count < 8:
		_fail("El valle debe incluir tres pequeños pueblos y al menos ocho casas Quaternius.")
		return
	var character_directory := DirAccess.open("res://assets/quaternius/ultimate_animated_characters/glTF")
	if character_directory == null:
		_fail("Falta la biblioteca completa de personajes Quaternius.")
		return
	var character_count := 0
	for file_name in character_directory.get_files():
		if file_name.get_extension().to_lower() == "gltf":
			character_count += 1
	if character_count != EXPECTED_CHARACTER_COUNT:
		_fail("La biblioteca debería contener %d personajes glTF; contiene %d." % [EXPECTED_CHARACTER_COUNT, character_count])
		return

	if clouds == null or clouds.get_child_count() < 5:
		_fail("El cielo debe tener varias capas de nubes animadas.")
		return
	if clouds.get_node_or_null("MovingCloudDome") == null:
		_fail("El cielo debe tener una bóveda visible de nubes en movimiento.")
		return
	var horizon_cloud := clouds.get_node_or_null("HorizonCloud01") as MeshInstance3D
	if horizon_cloud == null or not bool(horizon_cloud.get_meta("shader_driven", false)):
		_fail("El horizonte debe usar bancos de nubes impulsados por shader.")
		return
	for child in clouds.get_children():
		var cloud_layer := child as MeshInstance3D
		if cloud_layer == null or cloud_layer.mesh == null or cloud_layer.material_override == null:
			_fail("Cada capa de nubes debe tener malla y shader material.")
			return
		var material := cloud_layer.material_override as ShaderMaterial
		if material == null or material.shader == null or not material.shader.code.contains("TIME"):
			_fail("Las nubes deben animarse con TIME en el shader.")
			return
	if not (horizon_cloud.material_override as ShaderMaterial).shader.code.contains("warp"):
		_fail("Las nubes deben deformarse con ruido multicapa, no deslizar una textura plana.")
		return

	if scatter.generated_green_tree_count + scatter.generated_autumn_tree_count != scatter.generated_tree_count:
		_fail("El reparto de árboles verdes y otoñales no coincide con el total.")
		return
	if scatter.generated_green_tree_count < roundi(scatter.generated_tree_count * 0.93):
		_fail("Al menos el 93%% de los árboles debe ser verde.")
		return
	if scatter.generated_autumn_tree_count > roundi(scatter.generated_tree_count * 0.01):
		_fail("Los árboles rojos deben ser una excepción de como máximo el 1%.")
		return
	var minimum_tree_x := INF
	var maximum_tree_x := -INF
	var minimum_tree_z := INF
	var maximum_tree_z := -INF
	for tree_position in scatter.tree_positions:
		minimum_tree_x = minf(minimum_tree_x, tree_position.x)
		maximum_tree_x = maxf(maximum_tree_x, tree_position.x)
		minimum_tree_z = minf(minimum_tree_z, tree_position.z)
		maximum_tree_z = maxf(maximum_tree_z, tree_position.z)
	if maximum_tree_x - minimum_tree_x < 430.0 or maximum_tree_z - minimum_tree_z < 430.0:
		_fail("El decorado no ocupa todavía la extensión completa del escenario ampliado.")
		return

	var count_specs: Array[Array] = [
		["árboles", scatter.tree_count, scatter.generated_tree_count, EXPECTED_TREE_COUNT],
		["rocas", scatter.rock_count, scatter.generated_rock_count, EXPECTED_ROCK_COUNT],
		["hierba", scatter.grass_count, scatter.generated_grass_count, EXPECTED_GRASS_COUNT],
		["helechos", scatter.fern_count, scatter.generated_fern_count, EXPECTED_FERN_COUNT],
		["arbustos", scatter.shrub_count, scatter.generated_shrub_count, EXPECTED_SHRUB_COUNT],
		["flores", scatter.flower_count, scatter.generated_flower_count, EXPECTED_FLOWER_COUNT],
		["setas", scatter.mushroom_count, scatter.generated_mushroom_count, EXPECTED_MUSHROOM_COUNT],
		["guijarros", scatter.path_pebble_count, scatter.generated_path_pebble_count, EXPECTED_PATH_PEBBLE_COUNT],
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
		["FernCells", scatter.generated_fern_count],
		["ShrubCells", scatter.generated_shrub_count],
		["FlowerCells", scatter.generated_flower_count],
		["MushroomCells", scatter.generated_mushroom_count],
		["PathDetailCells", scatter.generated_path_pebble_count],
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
		_fail("El contador de celdas no coincide con las %d celdas Quaternius instaladas." % counted_cells)
		return

	var tree_cells := scatter.get_node("TreeCells") as Node3D
	for child in tree_cells.get_children():
		var cell := child as MultiMeshInstance3D
		if cell.multimesh.mesh.get_aabb().size.y < 6.0:
			_fail("El bosque debe utilizar árboles adultos Quaternius de al menos seis metros.")
			return
		for index in cell.multimesh.instance_count:
			var position := cell.multimesh.get_instance_transform(index).origin
			if scatter.distance_to_route(Vector2(position.x, position.z)) < 11.2:
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
	var animator := horse_model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null:
		_fail("El caballo no contiene AnimationPlayer.")
		return
	for required_animation in ["Idle", "Walk", "Gallop"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación del caballo: %s" % required_animation)
			return
	if animator.current_animation != "Idle":
		_fail("El caballo no inicia con su animación Quaternius Idle.")
		return

	var player_model_root := world.get_node("Player/Visual/ModelRoot") as Node3D
	var player_animator := player_model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player_model_root.get_child_count() == 0:
		_fail("El protagonista debe cargar el caballero dorado Quaternius.")
		return
	for required_animation in ["Idle", "Walk", "Run", "SwordSlash"]:
		if player_animator == null or not player_animator.has_animation(required_animation):
			_fail("Falta la animación del protagonista Quaternius: %s" % required_animation)
			return

	var first_animal := wildlife.get_child(0) as Node3D
	var animal_start := first_animal.global_position
	world.get_node("Player").global_position = animal_start + Vector3(0.0, 0.0, 3.0)
	for _frame in range(24):
		await physics_frame
	if first_animal.global_position.distance_to(animal_start) < 0.75:
		_fail("La fauna no se apartó al detectar al protagonista.")
		return
	if int(wildlife.get("reaction_count")) <= 0:
		_fail("La fauna no registró ninguna reacción visual al jugador.")
		return

	var generated_cell_total := scatter.generated_cell_count
	world.queue_free()
	for _frame in range(8):
		await process_frame
	print(
		"QUATERNIUS TEST OK: %d celdas, %d elementos, %d personajes, fauna reactiva y caballo animado."
		% [generated_cell_total, EXPECTED_TREE_COUNT + EXPECTED_ROCK_COUNT + EXPECTED_GRASS_COUNT + EXPECTED_FERN_COUNT + EXPECTED_SHRUB_COUNT + EXPECTED_FLOWER_COUNT + EXPECTED_MUSHROOM_COUNT + EXPECTED_PATH_PEBBLE_COUNT, EXPECTED_CHARACTER_COUNT]
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
