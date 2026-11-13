extends SceneTree

## El cielo mantiene su resolución y paleta; sólo deja de recibir soles que
## ya se representan con mallas y parámetros idénticos que ensucian el cubemap.
var mundo: Node3D

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 4: await process_frame
	paused = false
	mundo.process_mode = Node.PROCESS_MODE_DISABLED
	mundo.sun_cycle_enabled = true
	var entorno := (mundo.get_node("WorldEnvironment") as WorldEnvironment).environment
	var cielo := entorno.sky
	if not _exigir(cielo != null and cielo.radiance_size == Sky.RADIANCE_SIZE_512 and cielo.sky_material is ProceduralSkyMaterial, "La optimización cambia el cielo nativo o su cubemap de 512."): return
	var material := cielo.sky_material as ProceduralSkyMaterial
	if not _exigir(material.sun_angle_max == 0.0, "El cielo procedural conserva discos que necesitan recibir las luces."): return
	var sol := mundo.get_node("Sun") as DirectionalLight3D
	var luna := mundo.get_node("IslandEnvironment").get("moon_light") as DirectionalLight3D
	for luz in [sol, luna, mundo.get_node("SkyFill")]:
		if not _exigir(luz.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY and luz.light_angular_distance == 0.0, "Una luz direccional vuelve a invalidar el cielo con discos inactivos."): return
	# Valores canónicos del diseño previo: la paleta se conserva al pasar por
	# día y noche, no sólo en una captura que podría quedar congelada.
	for caso in [{"fase":PI * 0.5,"colores":[Color(0.16,0.50,0.88),Color(0.82,0.94,1.0),Color(0.20,0.31,0.18),Color(0.34,0.64,0.76)]},{"fase":PI * 1.5,"colores":[Color(0.012,0.025,0.10),Color(0.075,0.11,0.20),Color(0.018,0.025,0.045),Color(0.035,0.075,0.16)]}]:
		mundo.sun_cycle_radians = caso.fase
		mundo._update_sun_cycle(0.0)
		var actual := _paleta(material)
		for i in 4:
			if not _exigir(actual[i].is_equal_approx(caso.colores[i]), "La paleta diurna o nocturna cambia al conservar la radiancia."): return
		var subidas: int = mundo.actualizaciones_paleta_cielo
		for repeticion in 100:
			mundo._update_sun_cycle(0.0)
			if not _exigir(mundo.actualizaciones_paleta_cielo == subidas, "Repetir una paleta idéntica vuelve a subir uniformes e invalidar la radiancia."): return
			if not _exigir(_paleta(material) == actual, "Una fase fija no conserva exactamente sus colores."): return
		if caso.fase < PI:
			if not _exigir(is_equal_approx(sol.light_energy,1.35) and sol.shadow_enabled and is_equal_approx(entorno.ambient_light_energy,0.66), "La optimización debilita la luz o las sombras diurnas."): return
		else:
			if not _exigir(is_equal_approx(luna.light_energy,0.72) and luna.shadow_enabled and is_equal_approx(entorno.ambient_light_energy,0.22), "La optimización debilita la luz o las sombras nocturnas."): return
	var anterior: Array[Color] = []
	var maximo := 0.0
	var transiciones := 0
	for i in 12289:
		mundo.sun_cycle_radians = TAU * float(i) / 12288.0
		mundo._update_sun_cycle(0.0)
		var actual := _paleta(material)
		if not anterior.is_empty():
			for canal in 4:
				for componente in 4:
					var diferencia := absf(actual[canal][componente] - anterior[canal][componente])
					maximo = maxf(maximo,diferencia)
					if diferencia > 0.0: transiciones += 1
		anterior = actual
	if not _exigir(transiciones > 1000 and maximo < 0.015, "El ciclo pierde cambios de color o introduce un salto en el crepúsculo."): return
	print("SKY RADIANCE TEST OK: cubemap 512, tres luces sólo mundo, paletas, 200 repeticiones exactas y 12289 fases; salto máximo %.6f." % maximo)
	quit(0)

func _paleta(material: ProceduralSkyMaterial) -> Array[Color]:
	return [material.sky_top_color,material.sky_horizon_color,material.ground_bottom_color,material.ground_horizon_color]

func _exigir(condicion: bool, texto: String) -> bool:
	if condicion: return true
	push_error(texto)
	quit(1)
	return false
