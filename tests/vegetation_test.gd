extends SceneTree

## Comprueba que el decorado de la Fase 5 sea determinista, eficiente y no
## invada el sendero jugable. También valida el caballo visual animado.


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

	if scatter.generated_tree_count != 420:
		_fail("El bosque no generó los 420 árboles previstos.")
		return
	if scatter.generated_rock_count != 190:
		_fail("El decorado no generó las 190 rocas previstas.")
		return
	if scatter.generated_grass_count != 6200:
		_fail("La pradera no generó las 6200 matas previstas.")
		return

	var trunks := scatter.get_node("TreeTrunks") as MultiMeshInstance3D
	var crowns := scatter.get_node("TreeCrowns") as MultiMeshInstance3D
	var rocks := scatter.get_node("Rocks") as MultiMeshInstance3D
	var grass := scatter.get_node("Grass") as MultiMeshInstance3D
	if trunks.multimesh.instance_count != 420 or crowns.multimesh.instance_count != 2520:
		_fail("Los árboles no se agruparon correctamente en MultiMesh.")
		return
	if rocks.multimesh.instance_count != 190 or grass.multimesh.instance_count != 6200:
		_fail("Rocas o hierba no se agruparon correctamente en MultiMesh.")
		return

	for index in trunks.multimesh.instance_count:
		var position := trunks.multimesh.get_instance_transform(index).origin
		if scatter.distance_to_route(Vector2(position.x, position.z)) < 12.95:
			_fail("Un árbol invadió el corredor despejado del sendero.")
			return

	var collision_body := scatter.get_node("DecorCollisions") as StaticBody3D
	if collision_body.get_child_count() != 610:
		_fail("Todos los 420 árboles y las 190 rocas deben tener colisión.")
		return

	var model := horse.get_node("Visual/ModelRoot/Armature/Skeleton3D/Horse") as MeshInstance3D
	var animator := horse.get_node("Visual/ModelRoot/AnimationPlayer") as AnimationPlayer
	if model == null or model.mesh == null:
		_fail("El caballo CC0 importado no está disponible.")
		return
	for required_animation in ["Armature|Idle", "Armature|Walk", "Armature|Run"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación del caballo: %s" % required_animation)
			return
	if animator.current_animation != "Armature|Idle":
		_fail("El caballo no inicia con su animación Idle.")
		return

	world.queue_free()
	for _frame in range(8):
		await process_frame
	print("VEGETATION TEST OK: bosque completo sólido, 6200 hierbas y caballo animado.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
