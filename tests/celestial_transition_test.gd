extends SceneTree

## Un ciclo denso detecta el salto de sombras que no veían las fotos de día/noche.
func _init() -> void: call_deferred("_run_test")

func _run_test() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for singleton in ["InventoryManager","ExplorationManager"]: root.get_node(singleton).set("autosave_enabled",false)
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.modo_aventura = false # Contrato de la campaña clásica.
	root.add_child(world)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 4: await process_frame
	paused = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var sun: DirectionalLight3D = world.get_node("Sun")
	var island = world.get_node("IslandEnvironment")
	var moon: DirectionalLight3D = island.moon_light
	world.sun_cycle_radians = 4.72
	world._update_sun_cycle(0.0)
	var claridad_noche := _claridad_horizontal(world)
	var claridad_minima := INF
	var previous := Vector3.ZERO
	var previous_moon_owner := false
	var changes := 0
	var maximum_step := 0.0
	var maximum_handoff := 0.0
	for i in 12289:
		world.sun_cycle_radians = TAU*float(i)/12288.0
		world._update_sun_cycle(0.0)
		if "--break-shadow-fade" in OS.get_cmdline_user_args():
			sun.shadow_opacity = 1.0
			moon.shadow_opacity = 1.0
		if sin(world.sun_cycle_radians)<=0.28:
			claridad_minima=minf(claridad_minima,_claridad_horizontal(world))
		# Sin await: la luna y la propiedad de sombras deben ser atómicas con World.
		if sun.shadow_enabled==moon.shadow_enabled:
			_fail("El relevo usa cero o dos mapas direccionales."); return
		var shadow := Vector3.ZERO
		if sun.shadow_enabled: shadow += sun.global_basis.z*sun.light_energy*sun.shadow_opacity
		if moon.shadow_enabled: shadow += moon.global_basis.z*moon.light_energy*moon.shadow_opacity
		if i>0:
			var step := shadow.distance_to(previous)
			maximum_step = maxf(maximum_step,step)
			if moon.shadow_enabled!=previous_moon_owner:
				changes += 1
				maximum_handoff = maxf(maximum_handoff,step)
				if sun.shadow_opacity>0.001 or moon.shadow_opacity>0.001:
					_fail("La dirección de la sombra cambia mientras todavía es visible."); return
		previous = shadow
		previous_moon_owner = moon.shadow_enabled
	if changes!=2 or maximum_step>0.035 or maximum_handoff>0.001:
		_fail("El amanecer o el anochecer conservan un salto de sombra: %.5f / %.5f (%d relevos)."%[maximum_step,maximum_handoff,changes]); return
	if claridad_noche<=0.0 or claridad_minima<claridad_noche*0.995:
		_fail("El crepúsculo cae por debajo de la claridad de la noche completa: %.6f / %.6f."%[claridad_minima,claridad_noche]); return
	for phase in [0.86,4.72]:
		world.sun_cycle_radians = phase
		world._update_sun_cycle(0.0)
		var owner := sun if phase<PI else moon
		if absf(owner.shadow_opacity-1.0)>0.0001:
			_fail("La transición debilita las sombras de pleno día o noche."); return
		if phase>PI and absf(moon.light_energy-0.72)>0.0001:
			_fail("La transición cambia la intensidad de la noche."); return
	print("CELESTIAL TRANSITION PASS ",JSON.stringify({"samples":12289,"handoffs":changes,"max_step":maximum_step,"max_handoff":maximum_handoff,"claridad_minima_relativa":claridad_minima/claridad_noche,"claridad_noche":claridad_noche}))
	quit(0)

func _claridad_horizontal(world: Node3D) -> float:
	# Una superficie blanca horizontal debe conservar al menos la iluminación
	# nocturna final. Comprobar sólo continuidad no detectaba el valle oscuro:
	# la curva antigua era continua, pero perdía luz antes de encender la luna.
	var entorno: Environment = world.get_node("WorldEnvironment").environment
	var claridad := entorno.ambient_light_color.srgb_to_linear().get_luminance()*entorno.ambient_light_energy
	var luna: DirectionalLight3D = world.get_node("IslandEnvironment").moon_light
	for luz: DirectionalLight3D in [world.get_node("Sun"),world.get_node("SkyFill"),luna]:
		claridad += luz.light_color.srgb_to_linear().get_luminance()*luz.light_energy*maxf(luz.global_basis.z.dot(Vector3.UP),0.0)
	return claridad*entorno.tonemap_exposure


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
