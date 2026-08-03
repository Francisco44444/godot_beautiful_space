extends SceneTree

## Valida protagonista, espada, animaciones, ataque, blancos rompibles y aldea.


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
	var set_dressing := world.get_node("MedievalSetDressing") as MedievalSetDressing
	var skeleton := player.get_node("Visual/ModelRoot/HumanArmature/Skeleton3D") as Skeleton3D
	var animator := player.get_node("Visual/ModelRoot/AnimationPlayer") as AnimationPlayer
	var sword := skeleton.get_node_or_null("SwordHandAttachment/EquippedSword") as MeshInstance3D
	if sword == null or sword.mesh == null:
		_fail("La espada no está enlazada a la mano derecha.")
		return
	if skeleton.find_bone("Palm.R") < 0:
		_fail("El esqueleto no contiene el hueso Palm.R.")
		return
	for required_animation in ["HumanArmature|Idle_swordRight", "HumanArmature|Walking", "HumanArmature|Run_swordRight", "HumanArmature|swordAttackJump"]:
		if not animator.has_animation(required_animation):
			_fail("Falta la animación medieval: %s" % required_animation)
			return
	if set_dressing.generated_prop_count < 35 or set_dressing.generated_collision_count < 33:
		_fail("El decorado medieval no generó suficientes piezas sólidas.")
		return
	if set_dressing.breakable_count != 5:
		_fail("Deben existir cinco cajas rompibles.")
		return

	var crate := world.get_node("MedievalSetDressing/BreakableCrate00") as BreakableProp
	crate.global_position = player.global_position + Vector3(0.0, 0.0, -0.95)
	crate.rotation = Vector3.ZERO
	if not player.start_attack():
		_fail("No se pudo iniciar el primer ataque.")
		return
	for _frame in 35:
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
	print("MEDIEVAL COMBAT TEST OK: héroe animado, espada, impactos, cajas y aldea operativos.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
