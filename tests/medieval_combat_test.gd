extends SceneTree

## Valida inventario 1–4, socket de mano y golpes físicos con armas RPG.


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
	if not player.quaternius_hero_path.begins_with("res://assets/quaternius/ultimate_animated_characters/glTF/"):
		_fail("El protagonista elegido no pertenece al pack animado de Quaternius.")
		return
	if player.skin_surface_count < 1 or not _has_human_skin_override(model_root, player.hero_skin_color):
		_fail("El personaje elegido no conserva el tono de piel humano configurado.")
		return
	for required_animation in ["Idle", "Walk", "Run", "Punch", "SwordSlash"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación Quaternius: %s" % required_animation)
			return
	if animator.current_animation not in ["Idle", "Jump"]:
		_fail("El protagonista Quaternius no inicia con una animación de locomoción válida.")
		return

	var hand_socket := model_root.find_child("RightHandSocket", true, false) as BoneAttachment3D
	var equipment_grip := model_root.find_child("EquipmentGrip", true, false) as Node3D
	if hand_socket == null or hand_socket.bone_name != "Fist.R" or equipment_grip == null:
		_fail("Los objetos no están unidos al hueso Fist.R de la mano.")
		return
	if player.equipped_slot != 0 or player.get_equipped_mesh() != null or equipment_grip.get_child_count() != 0:
		_fail("El protagonista debe comenzar con las manos vacías y sin objetos enfundados.")
		return
	if player.start_attack():
		_fail("No debe iniciarse un golpe de arma mientras las manos están vacías.")
		return

	var expected_nodes := ["EquippedSword", "EquippedAxe", "EquippedBow", "EquippedTorch"]
	var equip_key := InputEventKey.new()
	equip_key.physical_keycode = KEY_1
	equip_key.pressed = true
	player.call("_unhandled_input", equip_key)
	if player.equipped_slot != 1 or player.get_equipped_mesh() == null:
		_fail("La tecla 1 no equipa la espada.")
		return
	for slot in range(1, 5):
		if not player.equip_item(slot):
			_fail("No se pudo equipar el objeto de aventura del hueco %d." % slot)
			return
		var equipped := player.get_equipped_mesh()
		if equipped == null or equipped.name != expected_nodes[slot - 1] or equipped.mesh == null:
			_fail("El hueco %d no muestra el objeto correcto en la mano." % slot)
			return
		if equipped.mesh.get_surface_count() < 1 or equipped.mesh.get_aabb().size.length() <= 0.0:
			_fail("El objeto %d no conserva su geometría y materiales Quaternius." % slot)
			return
		if not bool(equipped.get_meta("held_in_right_hand", false)) or equipment_grip.get_child_count() != 1:
			_fail("El objeto %d no sustituyó limpiamente al anterior en la mano." % slot)
			return
		if equipped.get_parent() != equipment_grip or equipped.top_level:
			_fail("El objeto %d no hereda directamente el movimiento de Fist.R." % slot)
			return
		if equipment_grip.position.length() > 0.27:
			_fail("El agarre del objeto %d queda demasiado lejos del centro del puño." % slot)
			return
		if not equipment_grip.position.is_equal_approx(equipped.get_meta("grip_position", Vector3.INF)):
			_fail("El objeto %d perdió su punto de empuñadura calibrado." % slot)
			return
		if _brightest_surface_luminance(equipped) < 0.32:
			_fail("El objeto %d vuelve a quedar ilegible por materiales demasiado oscuros." % slot)
			return
		var authored_up := (equipment_grip.basis * Vector3.UP).normalized()
		if slot in [2, 4]:
			var arm_parallelism := authored_up.dot(Vector3.DOWN)
			if (
				arm_parallelism < 0.52 or arm_parallelism > 0.82
				or absf(authored_up.x) < 0.38
				or absf(authored_up.z) < 0.34
			):
				_fail("El hacha/antorcha %d vuelve a quedar paralela al antebrazo." % slot)
				return
		if slot == 4 and equipped.get_node_or_null("TorchLight") == null:
			_fail("La antorcha equipada no emite luz.")
			return
	player.equip_item(1)
	var sword := player.get_equipped_mesh()

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
	var attack_forward := -player.visual.global_basis.z.normalized()
	crate.global_position = player.global_position + attack_forward * 1.30
	crate.rotation = Vector3.ZERO
	await physics_frame
	var sword_position_before := sword.global_position
	var mouse_attack_bound := false
	for input_event in InputMap.action_get_events("attack"):
		if input_event is InputEventMouseButton and input_event.button_index == MOUSE_BUTTON_LEFT:
			mouse_attack_bound = true
	if not mouse_attack_bound:
		_fail("El clic izquierdo no está asociado a la acción de ataque.")
		return
	if not player.start_attack():
		_fail("La acción de ataque no inició el golpe con la espada equipada.")
		return
	for _frame in 18:
		await physics_frame
	if sword.global_position.distance_to(sword_position_before) < 0.08:
		_fail("La espada sujeta a la mano no acompañó el arco del ataque.")
		return
	for _frame in 17:
		await physics_frame
	if crate.health != 1:
		_fail("El primer tajo no dañó exactamente una vez la caja.")
		return
	for _frame in 32:
		await physics_frame
	player.equip_item(2)
	if not player.start_attack():
		_fail("No se pudo atacar con el hacha tras cambiar de objeto.")
		return
	for _frame in 35:
		await physics_frame
	if not crate.broken:
		_fail("El segundo tajo no rompió la caja.")
		return

	world.queue_free()
	for _frame in 8:
		await process_frame
	print("MEDIEVAL COMBAT TEST OK: espada, hacha, arco y antorcha en Fist.R; ataques físicos operativos.")
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


func _brightest_surface_luminance(equipment: MeshInstance3D) -> float:
	var brightest := 0.0
	for surface in equipment.mesh.get_surface_count():
		var material := equipment.mesh.surface_get_material(surface) as BaseMaterial3D
		if material == null:
			continue
		brightest = maxf(brightest, material.albedo_color.get_luminance())
	return brightest
