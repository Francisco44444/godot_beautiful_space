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
	else:
		if (
			bool(animated_clouds.get_meta("illustrated_billboards", true))
			or not bool(animated_clouds.get_meta("drawn_clouds_disabled", false))
			or not bool(animated_clouds.get_meta("procedural_clouds_only", false))
			or not bool(animated_clouds.get_meta("distributed_cloud_banks", false))
			or not bool(animated_clouds.get_meta("clear_sky_gaps", false))
			or int(animated_clouds.get_meta("depth_band_count", 0)) != 1
			or bool(animated_clouds.get_meta("sun_occlusion", true))
			or bool(animated_clouds.get_meta("separate_shadow_masks", true))
			or not bool(animated_clouds.get_meta("procedural_diffuse_veil", false))
			or bool(animated_clouds.get_meta("hybrid_cloud_system", true))
		):
			failures.append("El cielo debe usar sólo la franja procedural, sin tarjetas que giren con la cámara")
		for node_name in [
			"IllustratedCloudNear",
			"IllustratedCloudMid",
			"IllustratedCloudHorizon",
			"CloudShadowMasks",
		]:
			if animated_clouds.get_node_or_null(node_name) != null:
				failures.append("El cielo conserva la capa ilustrada desactivada %s" % node_name)
		var procedural_veil := animated_clouds.get_node_or_null("ProceduralCloudVeil") as MeshInstance3D
		var procedural_dome_count := 0
		for cloud_child in animated_clouds.get_children():
			var cloud_mesh_instance := cloud_child as MeshInstance3D
			if cloud_mesh_instance != null and cloud_mesh_instance.mesh is SphereMesh:
				procedural_dome_count += 1
		if procedural_veil == null or not procedural_veil.mesh is SphereMesh:
			failures.append("Falta la SphereMesh interior de ProceduralCloudVeil")
		elif procedural_dome_count != 1:
			failures.append("El cielo debe usar un único domo procedural")
		else:
			var veil_material := procedural_veil.material_override as ShaderMaterial
			if veil_material == null and procedural_veil.mesh.get_surface_count() > 0:
				veil_material = procedural_veil.mesh.surface_get_material(0) as ShaderMaterial
			var veil_shader_code := "" if veil_material == null or veil_material.shader == null else veil_material.shader.code
			var veil_shader_lower := veil_shader_code.to_lower()
			if (
				veil_shader_code.is_empty()
				or not veil_shader_code.contains("TIME")
				or veil_shader_code.contains("UV")
				or (not veil_shader_lower.contains("fbm") and not veil_shader_lower.contains("noise"))
				or (not veil_shader_lower.contains("sky_direction") and not veil_shader_lower.contains("dome_direction"))
				or not veil_shader_lower.contains("horizon_blend")
				or not veil_shader_lower.contains("cloud_region")
				or not veil_shader_lower.contains("region_field")
			):
				failures.append("ProceduralCloudVeil debe distribuir bancos separados, animados y sin UV")
		for legacy_name in [
			"MovingCloudDome",
			"CloudLayer01",
			"CloudLayer02",
			"CloudLayer03",
			"ShadowCumulus",
			"DistantCumulus",
		]:
			if animated_clouds.get_node_or_null(legacy_name) != null:
				failures.append("El cielo conserva el nodo de nubes antiguo %s" % legacy_name)

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
	elif not bool(island_environment.get("ocean").get_meta("multiscale_nonrepeating_waves", false)):
		failures.append("El mar lejano sigue dependiendo de un patrón uniforme en vez de ondas multiescala")
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
		if int(island_environment.get("scenic_cascade_count")) < 1 or int(island_environment.get("scenic_cascade_mist_count")) < 1:
			failures.append("No se generó ninguna cascada low-poly anclada al terreno con bruma de impacto")
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
			if not sun.shadow_enabled or moon_light.shadow_enabled:
				failures.append("Durante el día la luna intenta compartir las sombras del sol")
			world.sun_cycle_radians = PI + 0.055
			world.call("_update_sun_cycle", 0.0)
			await process_frame
			if day_sun == null or not day_sun.visible:
				failures.append("El sol desaparece antes de terminar de ocultarse bajo el horizonte")
			if moon.visible or moon_light.shadow_enabled:
				failures.append("La luna sale demasiado pronto durante el crepúsculo")
			if not sun.shadow_enabled:
				failures.append("El sol entrega sus sombras antes de que salga la luna")
			world.sun_cycle_radians = 4.72
			world.call("_update_sun_cycle", 0.0)
			await process_frame
			if day_sun != null and day_sun.visible:
				failures.append("El sol diurno permanece visible durante la noche")
			if not moon.visible or moon_light.light_energy < 0.55 or not moon_light.shadow_enabled:
				failures.append("La luna no alumbra ni proyecta sombras durante la noche")
			if sun.shadow_enabled:
				failures.append("El sol sigue proyectando sombras cuando la luna ya las genera")
			if absf(moon_light.directional_shadow_max_distance - sun.directional_shadow_max_distance) > 0.01:
				failures.append("La distancia de sombras de la luna no coincide con la del sol")
			if absf(moon_light.directional_shadow_fade_start - sun.directional_shadow_fade_start) > 0.001:
				failures.append("El fundido de sombras de la luna no coincide con el del sol")
			if not bool(island_environment.get_meta("exclusive_celestial_shadows", false)):
				failures.append("El relevo de sombras entre sol y luna no está marcado como exclusivo")
			island_environment.call("sync_celestial_sources", active_camera)
			var moon_source := (moon.global_position - active_camera.global_position).normalized() if active_camera != null else Vector3.ZERO
			var moon_light_source := moon_light.global_basis.z.normalized()
			print("MOON ALIGNMENT: visual=%s light=%s tracked=%s dot=%.6f error=%.4f°" % [
				moon_source, moon_light_source, island_environment.get("moon_source_direction"),
				moon_source.dot(moon_light_source), float(island_environment.call("get_moon_alignment_error_degrees")),
			])
			if (
				active_camera == null
				or moon_source.dot(moon_light_source) < 0.9998
				or float(island_environment.call("get_moon_alignment_error_degrees")) > 0.25
				or not bool(moon_light.get_meta("aligned_with_visible_moon", false))
			):
				failures.append("La luz nocturna no procede visualmente del disco lunar; las sombras quedan desalineadas")
			var fixed_moon_source := moon_source
			world.sun_cycle_radians = 5.35
			world.call("_update_sun_cycle", 0.0)
			island_environment.call("sync_celestial_sources", active_camera)
			var later_moon_source := (moon.global_position - active_camera.global_position).normalized() if active_camera != null else Vector3.ZERO
			if fixed_moon_source.dot(later_moon_source) < 0.99999 or not bool(moon.get_meta("fixed_sky_direction", false)):
				failures.append("La luna cambia de lugar durante la noche en vez de permanecer fija en el cielo")
			if later_moon_source.dot(moon_light.global_basis.z.normalized()) < 0.9998:
				failures.append("La luz lunar deja de coincidir con la luna fija al avanzar la noche")
			# Recorremos el ciclo completo porque el fallo original solo aparecía en
			# unos segundos del crepúsculo: ambas luces enviaban árboles al mapa de
			# sombras aunque las capturas de pleno día y plena noche fueran correctas.
			for cycle_step in 72:
				world.sun_cycle_radians = TAU * float(cycle_step) / 72.0
				world.call("_update_sun_cycle", 0.0)
				await process_frame
				if sun.shadow_enabled == moon_light.shadow_enabled:
					failures.append(
						"El relevo celestial deja %d luces con sombras en el paso %d."
						% [int(sun.shadow_enabled) + int(moon_light.shadow_enabled), cycle_step]
					)
					break

	var ambient_audio := world.get_node("AmbientAudio") as AmbientAudio
	ambient_audio.music.stop()
	ambient_audio.snow_music.stop()
	ambient_audio.desert_music.stop()
	ambient_audio.wind.stop()
	ambient_audio.birds.stop()
	for _frame in range(8):
		await process_frame
	# --- Brisa de polvo del desierto ---
	# Solo pasa en el desierto y solo de vez en cuando: una nube permanente se
	# leería como niebla, no como viento.
	var breeze := world.get_node_or_null("DesertBreeze")
	var player := world.get_node_or_null("Player") as Node3D
	var terrain := world.get_node_or_null("Terrain3D")
	if breeze == null:
		failures.append("Falta el nodo de brisa del desierto.")
	elif player != null and terrain != null:
		var dust := breeze.get_node_or_null("DesertDust") as GPUParticles3D
		if dust == null:
			failures.append("La brisa del desierto no trae partículas de polvo.")
		else:
			# Al valle primero: bloques anteriores de esta prueba han movido al
			# héroe, así que no se puede dar por hecho dónde está.
			var valley := Vector3(0.0, 0.0, 190.0)
			valley.y = float(terrain.data.get_height(valley)) + 1.0
			player.global_position = valley
			for _frame in 30:
				await physics_frame
			if String(breeze.call("get_biome")) == "desert":
				failures.append("El valle se lee como desierto.")
			if dust.emitting:
				failures.append("Hay polvo del desierto fuera del desierto.")
			# Al desierto: la racha tiene que llegar sola.
			var dunes := Vector3(2400.0, 0.0, 2050.0)
			dunes.y = float(terrain.data.get_height(dunes)) + 1.0
			player.global_position = dunes
			for _frame in 30:
				await physics_frame
			if String(breeze.call("get_biome")) != "desert":
				failures.append("La brisa no reconoce las dunas como desierto.")
			var gusts_before := int(breeze.call("get_gust_count"))
			var dusty_frames := 0
			var quiet_frames := 0
			for _frame in 1500:
				await physics_frame
				if dust.emitting:
					dusty_frames += 1
				else:
					quiet_frames += 1
			if int(breeze.call("get_gust_count")) <= gusts_before:
				failures.append("En el desierto no pasa ninguna racha de polvo.")
			if quiet_frames == 0:
				failures.append("El polvo del desierto no descansa entre rachas.")
			if dusty_frames == 0:
				failures.append("La racha del desierto no llega a levantar polvo.")
			# Y al salir del desierto se corta.
			# --- Remolinos de arena ---
			# Geometría propia y facetada, no un billboard, y solo sobre terreno
			# de desierto: son lo que da inquietud a las dunas.
			var devils := world.get_node_or_null("DustDevils")
			if devils == null:
				failures.append("Falta el nodo de remolinos de arena.")
			else:
				player.global_position = dunes
				for _frame in 20:
					await physics_frame
				if not bool(devils.call("spawn_devil")):
					failures.append("No se pudo plantar un remolino en las dunas.")
				else:
					for _frame in 40:
						await physics_frame
					if int(devils.call("get_active_count")) < 1:
						failures.append("El remolino no queda activo tras nacer.")
					var devil := devils.get_child(devils.get_child_count() - 1) as Node3D
					var funnel := devil.get_node_or_null("Funnel") as MeshInstance3D
					if funnel == null or funnel.mesh == null:
						failures.append("El remolino no trae embudo de geometría.")
					else:
						var vertices := (
							(funnel.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
							as PackedVector3Array
						).size()
						# Low poly de verdad: unas decenas de caras, no cientos.
						if vertices > 900:
							failures.append("El embudo del remolino no es low poly: %d vértices." % vertices)
						if funnel.mesh.get_aabb().size.y < 10.0:
							failures.append("El remolino es demasiado bajo: %.1f m." % funnel.mesh.get_aabb().size.y)
					if String(breeze.call("get_biome")) != "desert":
						failures.append("El remolino no nació sobre desierto.")
					var spun_before := devil.rotation.y
					for _frame in 30:
						await physics_frame
					if absf(devil.rotation.y - spun_before) < 0.2:
						failures.append("El remolino no gira.")
					# Al alejarse, se retiran.
					player.global_position = valley
					for _frame in 40:
						await physics_frame
					if int(devils.call("get_active_count")) > 0:
						failures.append("Los remolinos siguen activos lejos del desierto.")

			player.global_position = valley
			for _frame in 30:
				await physics_frame
			if dust.emitting:
				failures.append("El polvo del desierto sigue al salir de las dunas.")

	if not failures.is_empty():
		_fail(failures)
		return

	print("ATMOSPHERE TEST OK: luna y sombras alineadas, mar multiescala, cascadas, estrellas, niebla regional, rachas de polvo y remolinos de arena low poly solo en el desierto.")
	quit(0)


func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
