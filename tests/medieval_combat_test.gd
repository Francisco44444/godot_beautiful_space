extends SceneTree

## Valida protagonista, cuchillo, animaciones y ataque con un blanco aislado.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 6:
		await physics_frame

	var player := world.get_node("Player") as Player
	var model_root := player.get_node_or_null("Visual/ModelRoot") as Node3D
	if model_root == null or not model_root.is_visible_in_tree():
		_fail("El protagonista Quaternius no está visible en el árbol.")
		return
	var skeleton := _find_skeleton(model_root)
	var animator := model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or skeleton.get_bone_count() < 20 or animator == null:
		_fail("Falta el rig animado completo del protagonista Quaternius.")
		return
	if not _has_visible_mesh(model_root):
		_fail("El protagonista Quaternius no contiene una malla visible.")
		return
	if not player.quaternius_hero_path.ends_with("/Cowboy_Male.gltf"):
		_fail("El protagonista no usa el Cowboy_Male elegido.")
		return
	if player.skin_surface_count < 1 or not _has_human_skin_override(model_root, player.hero_skin_color):
		_fail("La piel negra original del Cowboy_Male no se cambió a un tono humano naranja.")
		return
	for required_animation in ["Idle", "Walk", "Run", "SwordSlash"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación Quaternius: %s" % required_animation)
			return
	if animator.current_animation not in ["Idle", "Jump"]:
		_fail("El protagonista Quaternius no inicia con una animación de locomoción válida.")
		return

	var knife_grip := player.get_node_or_null("Visual/ModelRoot/KnifeGrip") as Node3D
	var knife := player.get_node_or_null("Visual/ModelRoot/KnifeGrip/EquippedKnife") as MeshInstance3D
	if knife_grip == null or knife == null or knife.mesh == null or not knife.is_visible_in_tree():
		_fail("El cuchillo del Survival Pack no está visible en el protagonista Quaternius.")
		return
	if knife.mesh.get_surface_count() < 3 or knife.mesh.get_aabb().size.length() <= 0.0:
		_fail("El cuchillo runtime no conserva su geometría y materiales Quaternius.")
		return

	var crate := BreakableProp.new()
	crate.name = "CombatTestTarget"
	crate.collision_layer = 5
	crate.collision_mask = 0
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(1.08, 1.06, 1.08)
	var crate_collision := CollisionShape3D.new()
	crate_collision.shape = crate_shape
	crate_collision.position.y = 0.53
	crate.add_child(crate_collision)
	world.add_child(crate)
	crate.global_position = player.global_position + Vector3(0.0, 0.0, -0.95)
	crate.rotation = Vector3.ZERO
	await physics_frame
	var knife_rotation_before := knife_grip.rotation
	if not player.start_attack():
		_fail("No se pudo iniciar el primer ataque.")
		return
	for _frame in 18:
		await physics_frame
	if knife_grip.rotation.distance_to(knife_rotation_before) < 0.05:
		_fail("El cuchillo visible no acompañó el arco del primer ataque.")
		return
	for _frame in 17:
		await physics_frame
	if crate.health != 1:
		_fail("El primer tajo no dañó exactamente una vez la caja.")
		return
	for _frame in 32:
		await physics_frame
	if not player.start_attack():
		_fail("No se pudo encadenar un segundo ataque tras la recuperación.")
		return
	for _frame in 35:
		await physics_frame
	if not crate.broken:
		_fail("El segundo tajo no rompió la caja.")
		return

	world.queue_free()
	for _frame in 8:
		await process_frame
	print("MEDIEVAL COMBAT TEST OK: héroe animado, cuchillo Quaternius e impactos operativos.")
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


func _has_human_skin_override(parent: Node, expected_color: Color) -> bool:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != "Skin":
				continue
			var override := mesh_instance.get_surface_override_material(surface) as BaseMaterial3D
			if override != null and override.albedo_color.is_equal_approx(expected_color) and bool(override.get_meta("human_skin_recolor", false)):
				return true
	return false
