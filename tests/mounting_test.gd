extends SceneTree

## Prueba funcional de la máquina de estados a pie/montado y del galope.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := scene.instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as Player
	var horse := world.get_node("Horse") as Horse
	var spring_arm := world.get_node("CameraRig/SpringArm3D") as SpringArm3D
	var camera := world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D
	var mount_hint := world.get_node("HUD/MountHint") as Label

	for _frame in range(16):
		await physics_frame

	# Acercamos al jugador como si hubiera caminado hasta el caballo.
	player.global_position = horse.global_position + horse.visual.global_basis.x * 2.0
	await physics_frame
	if player.get_nearby_mount() != horse:
		_fail("El jugador no detecta a Brisa a distancia de montar.")
		return

	if not player.mount_horse(horse):
		_fail("La transición de ON_FOOT a MOUNTED fue rechazada.")
		return
	for _frame in range(24):
		await physics_frame

	if not player.is_mounted() or not horse.mounted:
		_fail("Jugador y caballo no comparten el estado montado.")
		return
	if player.visual.get_parent() != horse.rider_anchor:
		_fail("La representación del jugador no está colocada sobre la silla.")
		return
	if player.visual.global_position.y < horse.global_position.y + 1.25:
		_fail("El jinete sigue hundido bajo el caballo en vez de estar sobre la silla.")
		return
	if player.animation_player.current_animation != "SitDown":
		_fail("El jinete no conserva la pose sentada al montar.")
		return
	if not player.collision.disabled:
		_fail("La colisión a pie debe desactivarse al montar.")
		return
	if spring_arm.spring_length < 7.0 or camera.fov < 70.0:
		_fail("La cámara no se abrió para la vista de galope.")
		return
	if not mount_hint.visible or "Desmontar" not in mount_hint.text:
		_fail("El HUD no muestra la acción de desmontar.")
		return

	var horse_start := horse.global_position
	Input.action_press("move_forward")
	for _frame in range(55):
		await physics_frame
	var canter_velocity := Vector2(horse.velocity.x, horse.velocity.z).length()
	Input.action_release("move_forward")
	for _frame in range(35):
		await physics_frame

	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _frame in range(55):
		await physics_frame
	var gallop_velocity := Vector2(horse.velocity.x, horse.velocity.z).length()
	var sprint_was_requested := horse.sprint_requested
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if not sprint_was_requested or gallop_velocity < canter_velocity * 1.35:
		_fail("Mayús no diferencia el galope: trote %.2f m/s, galope %.2f m/s." % [canter_velocity, gallop_velocity])
		return

	var ridden_distance := Vector2(
		horse.global_position.x - horse_start.x,
		horse.global_position.z - horse_start.z
	).length()
	if ridden_distance < 7.0:
		_fail("El caballo no galopó lo esperado: %.2f m" % ridden_distance)
		return

	if not player.dismount():
		_fail("La transición de MOUNTED a ON_FOOT fue rechazada.")
		return
	for _frame in range(3):
		await physics_frame

	if player.is_mounted() or horse.mounted:
		_fail("El estado montado siguió activo después de desmontar.")
		return
	if player.visual.get_parent() != player or player.collision.disabled:
		_fail("El jugador no recuperó su visual o su colisión al desmontar.")
		return
	if not mount_hint.visible or "Montar" not in mount_hint.text:
		_fail("El HUD no recuperó la acción de montar.")
		return

	print("MOUNTING TEST OK: jinete sobre silla, trote %.2f m/s, galope %.2f m/s y desmontar." % [canter_velocity, gallop_velocity])
	quit(0)


func _fail(message: String) -> void:
	Input.action_release("move_forward")
	Input.action_release("sprint")
	push_error(message)
	quit(1)
