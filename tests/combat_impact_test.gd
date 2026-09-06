extends SceneTree

## Un golpe que no se ve ni se siente no enseña nada. Aquí se fija que la
## cámara acuse los impactos, que la coraza que aguanta se distinga de la que
## cede, y que la sacudida mida en segundos REALES: a escala 0,16 del golpe
## final, con `delta` a secas duraría seis veces más y la escena se quedaría
## temblando después de la cinemática.


const WARDED_SPARKS := 1
const FADE_SECONDS := 1.35


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 7:
		await process_frame

	var runtime := world.get_node_or_null("RPGStoryRuntime")
	var rig := root.get_tree().get_first_node_in_group("camera_rig")
	var player := root.get_tree().get_first_node_in_group("local_player") as Node3D
	if runtime == null or rig == null or player == null:
		_fail("Falta el runtime, la cámara o el héroe.")
		return

	# 1. Recibir daño sacude, y más cuanto más te quitan.
	var before := int(rig.get("shake_count"))
	runtime.call("damage_player", 4, player.global_position + Vector3(2, 0, 0), "prueba")
	if int(rig.get("shake_count")) != before + 1:
		_fail("Recibir un golpe no sacude la cámara.")
		return
	var light: float = float(rig.get("_trauma"))
	rig.set("_trauma", 0.0)
	runtime.set("_damage_cooldown", 0.0)
	runtime.call("damage_player", 18, player.global_position + Vector3(2, 0, 0), "prueba")
	var heavy: float = float(rig.get("_trauma"))
	if heavy <= light:
		_fail("Un mazazo (%.2f) sacude igual o menos que un arañazo (%.2f)." % [heavy, light])
		return

	# 2. La sacudida se apaga en segundos reales, no de reloj de juego.
	rig.set("_trauma", 1.0)
	Engine.time_scale = 0.16
	var slow_start := float(rig.get("_trauma"))
	for _frame in 20:
		await process_frame
	var slow_left := float(rig.get("_trauma"))
	Engine.time_scale = 1.0
	if slow_left >= slow_start:
		_fail("En cámara lenta la sacudida no se apaga: se quedaría temblando.")
		return

	# 3. La coraza que aguanta chispea; romperla estalla mucho más.
	var boss: RPGBoss = null
	for node in root.get_tree().get_nodes_in_group("rpg_boss"):
		var candidate := node as RPGBoss
		if candidate != null and candidate.demand == RPGBoss.Demand.BOW:
			boss = candidate
			break
	if boss == null:
		_fail("No se encontró un jefe con coraza de flechas.")
		return
	boss.set_sealed(false)
	var sparks_before := int(runtime.get("spark_burst_count"))
	var health_before := boss.health
	boss.receive_tool_hit("sword", "Sword", boss.global_position, player)
	if int(runtime.get("spark_burst_count")) != sparks_before + WARDED_SPARKS:
		_fail("Un golpe rechazado por la coraza no deja chispas.")
		return
	if health_before - boss.health != RPGBoss.WARDED_DAMAGE:
		_fail("La coraza dejó pasar %d de daño en vez de %d." % [
			health_before - boss.health, RPGBoss.WARDED_DAMAGE])
		return

	var open_before := int(runtime.get("spark_burst_count"))
	while boss.stance != RPGBoss.Stance.OPEN and boss._ward > 0:
		boss.receive_projectile_hit(boss.global_position, player)
	if boss.stance != RPGBoss.Stance.OPEN:
		_fail("La flecha no abrió la guardia.")
		return
	if int(runtime.get("spark_burst_count")) <= open_before:
		_fail("Romper la guardia no estalla.")
		return

	# 4. Caer un enemigo también se ve.
	var foe: Node3D = null
	for node in root.get_tree().get_nodes_in_group("rpg_enemy"):
		if not bool(node.get("dead")):
			foe = node as Node3D
			break
	if foe == null:
		_fail("No hay enemigos a los que tumbar.")
		return
	var death_before := int(runtime.get("spark_burst_count"))
	foe.call("_die")
	if int(runtime.get("spark_burst_count")) <= death_before:
		_fail("Un enemigo cae sin que se vea nada.")
		return

	print("OK · sacudida por daño (%.2f leve / %.2f fuerte), se apaga en cámara lenta, %d estallidos" % [
		light, heavy, int(runtime.get("spark_burst_count"))])
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
