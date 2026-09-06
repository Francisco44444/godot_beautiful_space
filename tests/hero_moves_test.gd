extends SceneTree

## Valida el porte del equipo y la esquiva: escudo a la espalda con guardia al
## botón derecho, arma que se guarda al correr y se desenvaina al atacar, y
## voltereta lateral con la tecla de esquiva más salto.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 10:
		await physics_frame
	var player := world.get_node("Player") as Player
	var skeleton := _find_skeleton(player.get_node("Visual/ModelRoot"))
	if skeleton == null:
		_fail("El protagonista no tiene esqueleto.")
		return

	# --- 1. Escudo de madera colgado a la espalda desde el inicio ---
	var back_socket := skeleton.get_node_or_null("BackSocket") as BoneAttachment3D
	if back_socket == null or back_socket.bone_name != "Torso":
		_fail("Falta el anclaje de espalda en el hueso Torso.")
		return
	var shield := player.get("_shield_mesh") as MeshInstance3D
	if shield == null:
		_fail("El héroe no arranca con el escudo de madera equipado.")
		return
	if shield.get_parent().name != "BackShieldGrip":
		_fail("El escudo no cuelga de la espalda al empezar (padre %s)." % shield.get_parent().name)
		return
	if player.is_guarding or player.get_damage_multiplier() < 0.99:
		_fail("El héroe no debe empezar en guardia.")
		return

	# --- 2. Botón derecho: el escudo pasa al brazo y absorbe daño ---
	Input.action_press("block")
	for _frame in 30:
		await physics_frame
		await process_frame
	if not player.is_guarding:
		_fail("El botón derecho no pone al héroe en guardia.")
		return
	if shield.get_parent().name != "ShieldGrip":
		_fail("El escudo no llega al antebrazo al ponerse en guardia.")
		return
	if player.get_damage_multiplier() >= 1.0:
		_fail("La guardia no reduce el daño recibido.")
		return
	# La cara del escudo mira al frente del héroe, no al puño.
	var forward := -player.visual.global_basis.z.normalized()
	if shield.global_basis.orthonormalized().z.dot(forward) < 0.6:
		_fail("El escudo en guardia no cubre hacia el frente.")
		return
	# La tabla va DELANTE de la mano: si el escudo quedara centrado en el puño,
	# la mano asomaría por su cara.
	var hand_socket := player.get("_shield_grip") as Node3D
	var ahead := (shield.global_position - hand_socket.global_position).dot(
		shield.global_basis.orthonormalized().z
	)
	if ahead < 0.12:
		_fail("El escudo no se adelanta a la mano: la atravesaría (%.3f m)." % ahead)
		return
	# La guardia usa la pose de escudo de la Universal Animation Library 2, que
	# el rig de Quaternius no tiene.
	if not player.has_library_animation("Idle_Shield_Loop"):
		_fail("No se cargó la pose de escudo de la biblioteca de animaciones.")
		return
	if not player.is_playing_library_animation():
		_fail("La guardia no está usando la animación de escudo de la biblioteca.")
		return
	if player.start_attack():
		_fail("No debe poderse atacar mientras se sostiene la guardia.")
		return
	Input.action_release("block")
	for _frame in 30:
		await physics_frame
		await process_frame
	if player.is_guarding or shield.get_parent().name != "BackShieldGrip":
		_fail("Al soltar el botón el escudo no vuelve a la espalda.")
		return

	# --- 3. Correr sin combatir guarda el arma; atacar la desenvaina ---
	if not player.equip_item(1):
		_fail("No se pudo equipar la espada.")
		return
	while player.is_drawing_equipment():
		await physics_frame
	var sword := player.get_equipped_mesh()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var frames := 0
	while not player.is_weapon_on_back() and frames < 900:
		frames += 1
		await physics_frame
		await process_frame
	Input.action_release("sprint")
	Input.action_release("move_forward")
	if not player.is_weapon_on_back():
		_fail("La espada no se guarda a la espalda al correr sin combatir.")
		return
	while player.is_drawing_equipment():
		await physics_frame
		await process_frame
	if sword.get_parent().name != "BackWeaponGrip":
		_fail("La espada guardada no descansa en el anclaje de espalda.")
		return
	if player.start_attack():
		_fail("No debe poderse golpear con el arma a la espalda.")
		return
	if not player.draw_weapon():
		_fail("No se pudo desenvainar el arma guardada.")
		return
	frames = 0
	while player.is_drawing_equipment() and frames < 200:
		frames += 1
		await physics_frame
		await process_frame
	if player.is_weapon_on_back() or sword.get_parent().name != "EquipmentGrip":
		_fail("El arma desenvainada no vuelve a la mano.")
		return

	# --- 4. Esquiva lateral: Ctrl + dirección + salto ---
	for _frame in 30:
		await physics_frame
	var origin := player.global_position
	var camera_right := player.call("_camera_right") as Vector3
	Input.action_press("dodge")
	Input.action_press("move_right")
	await physics_frame
	Input.action_press("jump")
	# `physics_frame` se emite antes de `_physics_process`: hay que sostener la
	# pulsación un fotograma más para que el jugador la vea.
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	if not player.is_rolling:
		_fail("Ctrl + dirección + salto no lanza la voltereta lateral.")
		return
	var animator := player.get_node("Visual/ModelRoot").find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator.current_animation != "Roll":
		_fail("La voltereta no usa la animación Roll (usa %s)." % animator.current_animation)
		return
	frames = 0
	while player.is_rolling and frames < 300:
		frames += 1
		await physics_frame
	var travel := player.global_position - origin
	travel.y = 0.0
	if travel.length() < 2.0:
		_fail("La voltereta apenas desplaza al héroe (%.2f m)." % travel.length())
		return
	if travel.normalized().dot(camera_right) < 0.85:
		_fail("La voltereta no va hacia el lado pulsado (%.2f)." % travel.normalized().dot(camera_right))
		return
	Input.action_release("dodge")
	Input.action_release("move_right")

	# --- 4. Los movimientos de la biblioteca salen en su momento ---
	# Las 43 animaciones de la Universal Animation Library 2 están disponibles
	# sobre el rig del héroe; estas son las que tienen un disparo natural.
	for _frame in 30:
		await physics_frame
	var catalogue := player.get_library_catalogue()
	if catalogue.size() < 43:
		_fail("La biblioteca solo ofrece %d movimientos de los 43." % catalogue.size())
		return
	var unresolved: Array[String] = []
	for gesture_name in Player.GESTURES:
		if not player.has_library_animation(gesture_name):
			unresolved.append(gesture_name)
	if not unresolved.is_empty():
		_fail("Estos movimientos del catálogo no resuelven sobre el héroe: %s" % unresolved)
		return

	# Con las manos libres el héroe da un gancho en vez de quedarse mirando.
	player.call("_clear_equipped_item")
	for _frame in 20:
		await physics_frame
	if not player.start_attack():
		_fail("A mano desnuda no sale ningún golpe.")
		return
	if not player.get_library_animation().begins_with("Melee_Hook"):
		_fail("El golpe sin arma usa «%s» en vez del gancho." % player.get_library_animation())
		return
	# Sin arma no hay fuerza especial que acumular.
	if player.start_charge():
		_fail("A mano desnuda no debería poder acumularse la fuerza especial.")
		return
	while player.is_attacking:
		await physics_frame
	for _frame in 20:
		await physics_frame

	# El tercer tajo de la biblioteca queda fuera de la cadena: al retargetearlo
	# el héroe giraba sobre sí mismo como si no tuviera tronco.
	player.equip_item(1)
	for _frame in 30:
		await physics_frame
	var chain_names: Array[String] = []
	for _hit in 4:
		if player.start_attack():
			chain_names.append(player.get_library_animation())
		while player.is_attacking:
			await physics_frame
		for _frame in 16:
			await physics_frame
	if chain_names.is_empty():
		_fail("La cadena de tajos no llegó a lanzar ninguno.")
		return
	for name in chain_names:
		if name.begins_with("Sword_Regular_C"):
			_fail("El tercer tajo sigue en la cadena de golpes.")
			return
	# La antorcha se lleva a plomo, quieto o andando. El gesto de la biblioteca no
	# puede apagar la corrección de muñeca —queda de canto y solo se ve su
	# sombra— y esa corrección tiene que ser completa: al 62%, como el resto de
	# las armas, se quedaba a medio camino de la vertical.
	if player.equip_item(4):
		for _frame in 60:
			await physics_frame
		var torch := player.get_equipped_mesh()
		if torch == null or not torch.is_visible_in_tree():
			_fail("La antorcha no está visible en el reposo con antorcha.")
			return
		var still_tilt := _torch_tilt(player, torch)
		if still_tilt > 12.0:
			_fail("La antorcha queda doblada estando quieto: %.1f° de la vertical." % still_tilt)
			return
		Input.action_press("move_forward")
		var walking_tilt := 0.0
		for _frame in 45:
			await physics_frame
			walking_tilt = maxf(walking_tilt, _torch_tilt(player, torch))
		Input.action_release("move_forward")
		for _frame in 20:
			await physics_frame
		if walking_tilt > 12.0:
			_fail("La antorcha se dobla al andar: %.1f° de la vertical." % walking_tilt)
			return

	# El hacha tala: su gesto es otro que el de la espada.
	if player.equip_item(2):
		for _frame in 30:
			await physics_frame
		if not player.start_attack():
			_fail("El hacha no llega a golpear.")
			return
		if not player.get_library_animation().begins_with("TreeChopping"):
			_fail("El hacha usa «%s» en vez del gesto de tala." % player.get_library_animation())
			return
		while player.is_attacking:
			await physics_frame

	# Un golpe recibido se acusa, y con el escudo en alto lo acusa el escudo.
	player.equip_item(1)
	for _frame in 30:
		await physics_frame
	if not player.react_to_hit():
		_fail("El héroe no reacciona al recibir un golpe.")
		return
	if not player.get_gesture().begins_with("Hit_Knockback"):
		_fail("El golpe recibido usa «%s»." % player.get_gesture())
		return
	player.cancel_gesture()
	for _frame in 8:
		await physics_frame

	# Los gestos de cuerpo entero dejan al héroe quieto; los de tronco, no.
	if not player.play_gesture("Chest_Open"):
		_fail("No se puede lanzar el gesto de abrir cofre.")
		return
	var library: Node = player.get("_library")
	if bool(library.get("upper_body_only")):
		_fail("Abrir un cofre debe mover el cuerpo entero, no solo el tronco.")
		return
	player.cancel_gesture()
	for _frame in 8:
		await physics_frame
	if not bool(library.get("upper_body_only")):
		_fail("Al terminar el gesto no se vuelve al modo de solo tronco.")
		return

	world.queue_free()
	for _frame in 8:
		await process_frame
	print("HERO MOVES TEST OK: escudo a la espalda con guardia, arma envainada al correr, voltereta lateral y %d movimientos de la biblioteca sobre el héroe." % catalogue.size())
	quit(0)


func _torch_tilt(player: Player, torch: MeshInstance3D) -> float:
	## Grados que el eje largo de la antorcha se aparta de la vertical.
	var axis := (
		player.visual.global_basis.orthonormalized().inverse()
		* (torch.global_basis * Vector3.UP).normalized()
	)
	return absf(90.0 - rad_to_deg(asin(clampf(axis.y, -1.0, 1.0))))


func _find_skeleton(parent: Node) -> Skeleton3D:
	for node in parent.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
