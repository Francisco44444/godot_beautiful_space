extends SceneTree

## Valida protagonista, espada, animaciones y ataque con un blanco aislado.


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
	var legacy_root := player.get_node_or_null("Visual/ModelRoot") as Node3D
	if legacy_root == null or legacy_root.visible or legacy_root.is_visible_in_tree():
		_fail("El rig jugable anterior debe existir, pero permanecer oculto.")
		return
	var skeleton := legacy_root.get_node_or_null("HumanArmature/Skeleton3D") as Skeleton3D
	var animator := legacy_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if skeleton == null or animator == null:
		_fail("Falta el rig oculto que conserva las animaciones de gameplay.")
		return
	if skeleton.find_bone("Palm.R") < 0:
		_fail("El esqueleto no contiene el hueso Palm.R.")
		return
	for required_animation in ["HumanArmature|Idle_swordRight", "HumanArmature|Walking", "HumanArmature|Run_swordRight", "HumanArmature|swordAttackJump"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación medieval: %s" % required_animation)
			return

	var realistic_hero := player.get_node_or_null("Visual/RealisticPose/RealisticHero") as Node3D
	if realistic_hero == null or not realistic_hero.is_visible_in_tree():
		_fail("El héroe realista no está visible en el árbol.")
		return
	var realistic_skeleton := _find_skeleton(realistic_hero)
	if realistic_skeleton == null or realistic_skeleton.get_bone_count() < 20:
		_fail("El héroe realista no conserva un esqueleto válido.")
		return
	if not _has_visible_mesh(realistic_hero):
		_fail("El héroe realista no contiene ninguna malla visible y renderizable.")
		return
	var realistic_animator := realistic_hero.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if realistic_animator == null or not realistic_animator.has_animation("mixamo_com"):
		_fail("El héroe realista no conserva su animación importada.")
		return
	if realistic_animator.current_animation != "mixamo_com":
		_fail("El héroe realista no inicia su animación visible.")
		return

	var sword_grip := player.get_node_or_null("Visual/RealisticPose/RealisticSwordGrip") as Node3D
	var sword := player.get_node_or_null("Visual/RealisticPose/RealisticSwordGrip/EquippedSword") as MeshInstance3D
	if sword_grip == null or sword == null or sword.mesh == null or not sword.is_visible_in_tree():
		_fail("La espada runtime no está visible en la pose realista.")
		return
	if sword.mesh.get_surface_count() == 0 or sword.mesh.get_aabb().size.length() <= 0.0:
		_fail("La espada runtime no contiene geometría renderizable.")
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
	var sword_rotation_before := sword_grip.rotation
	if not player.start_attack():
		_fail("No se pudo iniciar el primer ataque.")
		return
	for _frame in 18:
		await physics_frame
	if sword_grip.rotation.distance_to(sword_rotation_before) < 0.05:
		_fail("La espada visible no acompañó el arco del primer ataque.")
		return
	for _frame in 17:
		await physics_frame
	if crate.health != 1:
		_fail("El primer espadazo no dañó exactamente una vez la caja.")
		return
	for _frame in 32:
		await physics_frame
	if not player.start_attack():
		_fail("No se pudo encadenar un segundo ataque tras la recuperación.")
		return
	for _frame in 35:
		await physics_frame
	if not crate.broken:
		_fail("El segundo espadazo no rompió la caja.")
		return

	world.queue_free()
	for _frame in 8:
		await process_frame
	print("MEDIEVAL COMBAT TEST OK: héroe animado, espada e impactos operativos.")
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
