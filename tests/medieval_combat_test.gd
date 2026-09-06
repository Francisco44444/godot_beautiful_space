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
	# El inventario es persistente: sin reponer flechas la prueba mediría un arco
	# que ni siquiera puede tensarse.
	var inventory := root.get_node_or_null("/root/InventoryManager")
	if inventory != null:
		inventory.call("add_item", "Arrow", 30, false)
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
	var left_hand_socket := model_root.find_child("LeftHandWeaponSocket", true, false) as BoneAttachment3D
	var equipment_grip := model_root.find_child("EquipmentGrip", true, false) as Node3D
	if hand_socket == null or hand_socket.bone_name != "Fist.R" or left_hand_socket == null or left_hand_socket.bone_name != "Fist.L" or equipment_grip == null:
		_fail("Faltan los sockets calibrados de ambas manos.")
		return
	if player.equipped_slot != 0 or player.get_equipped_mesh() != null or equipment_grip.get_child_count() != 0:
		_fail("El protagonista debe comenzar con las manos vacías y sin objetos enfundados.")
		return
	# Con las manos vacías sí se golpea —es el gancho de la biblioteca—, pero no
	# hay filo en el que acumular la fuerza especial.
	if not player.start_attack():
		_fail("A mano desnuda debería salir el gancho.")
		return
	if player.start_charge() or player.start_spin_attack():
		_fail("Sin arma no debe poder acumularse ni soltarse la fuerza especial.")
		return
	while player.is_attacking:
		await physics_frame
	for _frame in 20:
		await physics_frame

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
		var expected_hand := "left" if slot == 3 else "right"
		var expected_socket := left_hand_socket if slot == 3 else hand_socket
		if String(equipped.get_meta("held_in_hand", "")) != expected_hand or equipment_grip.get_child_count() != 1:
			_fail("El objeto %d no sustituyó limpiamente al anterior en la mano." % slot)
			return
		if equipment_grip.get_parent() != expected_socket or equipped.get_parent() != equipment_grip or equipped.top_level:
			_fail("El objeto %d no hereda el movimiento de la mano %s." % [slot, expected_hand])
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
		# El puño debe cerrarse sobre el punto de empuñadura de la malla, no sobre
		# su origen de exportación: es lo que evita que el hacha se sujete por
		# media caña o la espada por debajo del pomo.
		var grip_point := equipped.get_meta("grip_point", Vector3.ZERO) as Vector3
		var grip_error := equipped.to_global(grip_point).distance_to(equipment_grip.global_position)
		if grip_error > 0.02:
			_fail("El objeto %d no se sujeta por su empuñadura (%.3f m de desvío)." % [slot, grip_error])
			return
		var reach_from_hand := 0.0
		for corner in 8:
			var aabb := equipped.mesh.get_aabb()
			var point := aabb.position + aabb.size * Vector3(
				float(corner & 1), float((corner >> 1) & 1), float((corner >> 2) & 1)
			)
			reach_from_hand = maxf(reach_from_hand, equipped.to_global(point).distance_to(equipment_grip.global_position))
		# La espada mandoble es deliberadamente aparatosa, así que el tope solo
		# vigila que ningún objeto crezca hasta lo absurdo.
		if reach_from_hand > 2.1:
			_fail("El objeto %d alcanza un tamaño absurdo (%.2f m desde la mano)." % [slot, reach_from_hand])
			return
		if slot == 3:
			# Ejes de Bow_Wooden: +Y recorre las palas y la cuerda vive en +X, que
			# debe mirar al arquero para que la flecha salga por el centro.
			var bow_basis := equipped.global_basis.orthonormalized()
			var aim := player.get_aim_direction()
			# En reposo el arco se lleva ladeado para no rozar el suelo; la
			# verticalidad exacta solo hace falta al apuntar.
			var upright := bow_basis.y.dot(Vector3.UP)
			var rest_limit := cos(deg_to_rad(player.bow_rest_tilt_degrees + 12.0))
			if upright < rest_limit:
				_fail("El arco en reposo queda demasiado tumbado (%.3f)." % upright)
				return
			if (-bow_basis.x).dot(aim) < 0.6:
				_fail("El arco no orienta la cuerda hacia el arquero: la flecha no saldría por su centro.")
				return
			# El ladeo de legibilidad: con el plano del arco alineado al milímetro
			# con la puntería, en tercera persona solo se veía su canto.
			var cant := absf(bow_basis.z.dot(aim))
			if cant < 0.25:
				_fail("El arco queda de canto a la cámara y resulta invisible (%.3f)." % cant)
				return
		else:
			# El agarre vive en el sistema del hueso: si coincide con el calibrado
			# es que el arma hereda la rotación de la mano en vez de recalcularse
			# contra los ejes del mundo.
			var calibrated := Basis.from_euler(equipped.get_meta("grip_euler", Vector3.ZERO) as Vector3)
			if not equipment_grip.basis.orthonormalized().is_equal_approx(calibrated.orthonormalized()):
				_fail("El objeto %d no conserva su agarre calibrado dentro del hueso de la mano." % slot)
				return
		if slot == 4 and equipped.get_node_or_null("TorchLight") == null:
			_fail("La antorcha equipada no emite luz.")
			return
	player.equip_item(1)
	var sword := player.get_equipped_mesh()

	# La prueba de que el arma va en la mano y no atada al mundo: al cambiar de
	# fotograma de animación el arma se mueve con el puño, pero su agarre dentro
	# del hueso no varía ni un grado.
	var grip_before := equipment_grip.basis.orthonormalized()
	var sword_axis_before := (sword.global_basis.orthonormalized().y)
	animator.play("SwordSlash", 0.0)
	animator.seek(0.35, true)
	await process_frame
	await process_frame
	var sword_axis_after := (sword.global_basis.orthonormalized().y)
	if sword_axis_before.dot(sword_axis_after) > 0.9:
		_fail("La espada no acompaña la rotación de la mano entre fotogramas.")
		return
	if not equipment_grip.basis.orthonormalized().is_equal_approx(grip_before):
		_fail("El agarre de la espada se recalcula contra el mundo en vez de vivir en el hueso.")
		return
	animator.play("Idle", 0.0)
	await process_frame

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
	# Cambiar de arma ya no es instantáneo: la que estaba en la mano viaja a la
	# espalda y la nueva se desenvaina desde allí. Hay que esperar la maniobra.
	var draw_frames := 0
	while player.is_drawing_equipment() and draw_frames < 90:
		draw_frames += 1
		await physics_frame
	if draw_frames == 0:
		_fail("El cambio de arma no pasa por la espalda: no hubo maniobra de desenvainado.")
		return
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
	print("MEDIEVAL COMBAT TEST OK: empuñaduras sujetas al hueso de la mano, arco orientado a la puntería y ataques físicos operativos.")
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
