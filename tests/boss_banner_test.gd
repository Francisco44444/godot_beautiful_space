extends SceneTree

## Entrar a una arena sin saber en qué fase va el jefe, qué mecánica exige ni
## que el sitio pelea contigo es enterarse a base de golpes. El estandarte dice
## las tres cosas — y desaparece cuando no hay jefe despierto cerca, para no
## tapar la pantalla el resto de la partida.


const FAR := 400.0


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

	var hud := world.get_node_or_null("HUD")
	var runtime := world.get_node_or_null("RPGStoryRuntime")
	var player := root.get_tree().get_first_node_in_group("local_player") as Node3D
	if hud == null or runtime == null or player == null:
		_fail("Falta el HUD, el runtime o el héroe.")
		return
	var banner: PanelContainer = hud.get("boss_banner")
	if banner == null:
		_fail("El HUD no monta el estandarte de jefe.")
		return

	# Lejos de todo: callado.
	player.global_position = Vector3(FAR, player.global_position.y, FAR)
	hud.call("refresh_boss_banner")
	if banner.visible:
		_fail("El estandarte se ve sin ningún jefe cerca.")
		return

	var boss: RPGBoss = null
	for node in root.get_tree().get_nodes_in_group("rpg_boss"):
		var candidate := node as RPGBoss
		if candidate != null and candidate.demand == RPGBoss.Demand.BOW:
			boss = candidate
			break
	if boss == null:
		_fail("No hay jefe con coraza de flechas.")
		return

	# Junto a un jefe SELLADO tampoco: todavía no es tu problema.
	player.global_position = boss.global_position + Vector3(6.0, 0.0, 0.0)
	hud.call("refresh_boss_banner")
	if banner.visible:
		_fail("El estandarte se enciende con el jefe todavía sellado.")
		return

	boss.set_sealed(false)
	hud.call("refresh_boss_banner")
	if not banner.visible:
		_fail("Junto a un jefe despierto el estandarte sigue apagado.")
		return
	var title := String((hud.get("boss_banner_name") as Label).text)
	if not title.contains(String(boss.display_name).to_upper()) or not title.contains("fase"):
		_fail("El estandarte no dice quién es ni en qué fase va: '%s'" % title)
		return
	var demand := String((hud.get("boss_banner_demand") as Label).text)
	if not demand.contains("arco"):
		_fail("No dice qué mecánica exige: '%s'" % demand)
		return
	if not demand.contains("◆"):
		_fail("No enseña la coraza que le queda: '%s'" % demand)
		return
	# El nombre flotando encima del jefe se calla: el estandarte ya lo dice y
	# tenerlos los dos sólo tapa la arena.
	if not boss.banner_shown:
		_fail("El jefe sigue anunciándose por su cuenta con el estandarte puesto.")
		return
	for plate_name in ["BossHealth", "EnemyName"]:
		var plate := boss.get_node_or_null(plate_name) as Label3D
		if plate != null and plate.visible:
			_fail("La chapa '%s' sigue flotando encima con el estandarte puesto." % plate_name)
			return
	var site := String((hud.get("boss_banner_site") as Label).text)
	if site.length() < 20:
		_fail("No avisa de lo que hace el sitio: '%s'" % site)
		return

	# La coraza baja y se nota; abierto, lo dice.
	boss.receive_projectile_hit(boss.global_position, player)
	hud.call("refresh_boss_banner")
	var after := String((hud.get("boss_banner_demand") as Label).text)
	if after == demand:
		_fail("Romper una carga de coraza no cambia el estandarte.")
		return

	# Muerto: se apaga.
	boss.set("dead", true)
	hud.call("refresh_boss_banner")
	if banner.visible:
		_fail("El estandarte sigue encendido con el jefe muerto.")
		return
	if boss.banner_shown:
		_fail("El jefe muerto se quedó sin su etiqueta y sin estandarte.")
		return

	print("OK · estandarte con fase, mecánica exigida, coraza y regla del sitio; callado sin jefe despierto")
	quit(0)


func _fail(message: String) -> void:
	push_error("FALLO: %s" % message)
	print("FALLO: %s" % message)
	quit(1)
