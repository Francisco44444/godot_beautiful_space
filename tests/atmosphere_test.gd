extends SceneTree

## Verifica que la Fase 3 conserve su cielo, luz y niebla al cargar la escena.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var failures: Array[String] = []
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail(["No se pudo cargar scenes/world.tscn"])
		return

	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var rendering_method := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	)
	if rendering_method != "forward_plus":
		failures.append("La niebla volumétrica requiere Forward+: %s" % rendering_method)

	var world_environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		failures.append("Falta el WorldEnvironment de la Fase 3")
	else:
		var environment := world_environment.environment
		if environment.background_mode != Environment.BG_SKY:
			failures.append("El fondo debe usar un cielo")
		if environment.sky == null:
			failures.append("Falta el recurso Sky")
		elif not environment.sky.sky_material is ProceduralSkyMaterial:
			failures.append("El cielo debe usar ProceduralSkyMaterial")
		else:
			var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
			if sky_material.sky_energy_multiplier <= 0.0:
				failures.append("El cielo procedural no aporta iluminación")
			if sky_material.sky_top_color.get_luminance() <= 0.0:
				failures.append("El cielo procedural no tiene color superior")
			if not environment.volumetric_fog_enabled:
				failures.append("La niebla volumétrica está desactivada")
			if environment.volumetric_fog_density <= 0.0 or environment.volumetric_fog_density > 0.0006:
				failures.append("La niebla global está desactivada o supera el presupuesto de densidad")
			if environment.volumetric_fog_length < 200.0 or environment.volumetric_fog_length > 1000.0:
				failures.append("La longitud de la niebla global queda fuera del presupuesto 200–1000 m")
		if not environment.glow_enabled:
			failures.append("El resplandor del atardecer está desactivado")

	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		failures.append("Falta el sol direccional")
	elif sun.rotation_degrees.x > -20.0 or sun.rotation_degrees.x < -145.0:
		failures.append("El sol no está dentro del arco diurno previsto")
	else:
		var sun_rotation_before := sun.rotation_degrees
		world.call("_update_sun_cycle", 1.0)
		if sun.rotation_degrees.distance_to(sun_rotation_before) < 0.1:
			failures.append("El sol no avanza durante el ciclo de luz")
		world.call("_update_sun_cycle", float(world.sun_cycle_seconds) * 0.5)
		if absf(float(world.day_duration_seconds) / float(world.night_duration_seconds) - 2.0) > 0.01:
			failures.append("El día no dura exactamente el doble que la noche")
		if float(world.daylight_factor) > 0.15 or str(world.time_of_day) != "Noche":
			failures.append("El ciclo no alcanza una noche real")
		world.call("_update_sun_cycle", float(world.sun_cycle_seconds) * 0.5)

	var animated_clouds := world.get_node_or_null("AnimatedClouds")
	if animated_clouds == null or not animated_clouds.has_method("_process"):
		failures.append("Falta el sistema de nubes animadas")
	elif animated_clouds.get_child_count() != 3 or animated_clouds.has_node("MovingCloudDome"):
		failures.append("Las nubes deben incluir una capa baja y dos altas sin bóveda con costura")

	var sky_fill := world.get_node_or_null("SkyFill") as DirectionalLight3D
	if sky_fill == null or sky_fill.light_energy <= 0.0:
		failures.append("Falta el relleno azul para conservar detalle a contraluz")

	var valley_mist := world.get_node_or_null("ValleyMist") as FogVolume
	if valley_mist == null or not valley_mist.material is FogMaterial:
		failures.append("Falta la bruma localizada del valle")
	elif (valley_mist.material as FogMaterial).density <= 0.0:
		failures.append("La bruma del valle no tiene densidad")
	var island_environment := world.get_node_or_null("IslandEnvironment")
	if island_environment == null or int(island_environment.get("fog_zone_count")) < 6:
		failures.append("Faltan los bancos de niebla regionales de los bosques")
	elif int(island_environment.get("active_fog_volume_count")) > int(island_environment.get_meta("fog_volume_budget", 0)) or int(island_environment.get_meta("fog_volume_budget", 0)) > 2:
		failures.append("La niebla regional mantiene demasiados volúmenes activos simultáneamente")
	elif island_environment.get("ocean") == null or not bool(island_environment.get("ocean").get_meta("low_poly_waves", false)):
		failures.append("Falta el mar low-poly animado")
	elif not bool(island_environment.get("ocean").get_meta("spherical_horizon", false)):
		failures.append("El mar no curva ni oculta el límite blanco del horizonte")
	elif not bool(island_environment.get("ocean").get_meta("animated_tides", false)):
		failures.append("El mar no tiene un ciclo de mareas capaz de llenar las rías")
	elif not (island_environment.get("ocean") as MeshInstance3D).mesh is PlaneMesh or ((island_environment.get("ocean") as MeshInstance3D).mesh as PlaneMesh).size.x < 50000.0:
		failures.append("El océano no alcanza el horizonte largo de la cámara")
	elif island_environment.get("stars") == null or int(island_environment.get("star_count")) < 200:
		failures.append("La noche necesita un campo de estrellas")
	else:
		island_environment.set("tide_phase", PI * 1.5)
		island_environment.call("_update_tide", 0.0)
		var low_tide := float(island_environment.get("tide_height"))
		island_environment.set("tide_phase", PI * 0.5)
		island_environment.call("_update_tide", 0.0)
		var high_tide := float(island_environment.get("tide_height"))
		if high_tide - low_tide < 4.5 or absf((island_environment.get("ocean") as MeshInstance3D).position.y - high_tide) > 0.01:
			failures.append("La marea no recorre suficiente altura para llenar y vaciar las rías")
		var tide_player := world.get_node("Player") as Player
		var terrain := world.get_node("Terrain3D") as Terrain3D
		var tidal_point := Vector2(-3990.0, 2200.0)
		var tidal_ground := terrain.data.get_height(Vector3(tidal_point.x, 0.0, tidal_point.y))
		tide_player.global_position = Vector3(tidal_point.x, tidal_ground + 0.12, tidal_point.y)
		var unsafe_last_dry := tide_player.global_position
		for _push_step in 180:
			unsafe_last_dry = world.call("_guard_actor_from_water", tide_player, unsafe_last_dry, high_tide, true, 0.10)
		var rescued_ground := terrain.data.get_height(Vector3(tide_player.global_position.x, 0.0, tide_player.global_position.z))
		print("TIDE RETREAT: %.2f m recorridos, suelo %.2f m, pleamar %.2f m, empujes %d." % [Vector2(tide_player.global_position.x, tide_player.global_position.z).distance_to(tidal_point), rescued_ground, high_tide, int(world.get("tide_push_event_count"))])
		if (
			Vector2(tide_player.global_position.x, tide_player.global_position.z).distance_to(tidal_point) < 8.0
			or rescued_ground <= high_tide + float(world.call("get_tide_dry_clearance"))
			or int(world.get("tide_push_event_count")) <= 0
		):
			failures.append("La pleamar no empuja al personaje desde la ría hasta terreno seco")
		var day_sun := island_environment.get("sun_visual") as MeshInstance3D
		var active_camera := get_root().get_camera_3d()
		if day_sun == null or not bool(day_sun.get_meta("low_poly_sun", false)) or float(island_environment.get("sun_radius")) < 40.0:
			failures.append("Falta el sol diurno low-poly visible y opaco")
		elif not bool(day_sun.get_meta("opaque_sun", false)):
			failures.append("El sol diurno no está protegido contra el punto negro de la niebla")
		elif (
			active_camera == null
			or float(day_sun.get_meta("celestial_distance", 0.0)) < 18000.0
			or not bool(day_sun.get_meta("behind_world_geometry", false))
			or absf(day_sun.global_position.distance_to(active_camera.global_position) - float(day_sun.get_meta("celestial_distance", 0.0))) > 12.0
		):
			failures.append("El sol sigue colocado entre la cámara y el escenario en vez de detrás de la isla")
		var moon := island_environment.get("moon_visual") as MeshInstance3D
		var moon_light := island_environment.get("moon_light") as DirectionalLight3D
		if moon == null or not bool(moon.get_meta("low_poly_moon", false)) or float(island_environment.get("moon_radius")) < 80.0:
			failures.append("Falta la gran luna facetada de al menos 80 metros de radio")
		elif str(moon.get_meta("crater_texture", "")) != "res://assets/textures/moon/moon_craters_lowpoly.png":
			failures.append("La luna no usa la textura propia de cráteres")
		elif moon_light == null:
			failures.append("La luna no dispone de luz direccional nocturna")
		else:
			world.sun_cycle_radians = 0.86
			world.call("_update_sun_cycle", 0.0)
			await process_frame
			if day_sun == null or not day_sun.visible:
				failures.append("El sol low-poly no aparece durante el día")
			if moon.visible:
				failures.append("La luna transparente sigue dejando un punto negro durante el día")
			world.sun_cycle_radians = PI + 0.055
			world.call("_update_sun_cycle", 0.0)
			await process_frame
			if day_sun == null or not day_sun.visible:
				failures.append("El sol desaparece antes de terminar de ocultarse bajo el horizonte")
			world.sun_cycle_radians = 4.72
			world.call("_update_sun_cycle", 0.0)
			await process_frame
			if day_sun != null and day_sun.visible:
				failures.append("El sol diurno permanece visible durante la noche")
			if not moon.visible or moon_light.light_energy < 0.55 or not moon_light.shadow_enabled:
				failures.append("La luna no alumbra ni proyecta sombras durante la noche")

	var ambient_audio := world.get_node("AmbientAudio") as AmbientAudio
	ambient_audio.music.stop()
	ambient_audio.snow_music.stop()
	ambient_audio.desert_music.stop()
	ambient_audio.wind.stop()
	ambient_audio.birds.stop()
	for _frame in range(8):
		await process_frame
	if not failures.is_empty():
		_fail(failures)
		return

	print("ATMOSPHERE TEST OK: ciclo completo, luna low-poly luminosa, estrellas, mar y niebla regional.")
	quit(0)


func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
