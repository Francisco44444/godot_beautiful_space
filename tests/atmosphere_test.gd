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
		if environment.volumetric_fog_density <= 0.0:
			failures.append("La niebla global no tiene densidad")
		if environment.volumetric_fog_length < 200.0:
			failures.append("La niebla no cubre la vista larga del valle")
		if not environment.glow_enabled:
			failures.append("El resplandor del atardecer está desactivado")

	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		failures.append("Falta el sol direccional")
	elif sun.rotation_degrees.x > -20.0 or sun.rotation_degrees.x < -42.0:
		failures.append("El sol no tiene la inclinación cálida prevista")

	var animated_clouds := world.get_node_or_null("AnimatedClouds")
	if animated_clouds == null or not animated_clouds.has_method("_process"):
		failures.append("Falta el sistema de nubes animadas")

	var sky_fill := world.get_node_or_null("SkyFill") as DirectionalLight3D
	if sky_fill == null or sky_fill.light_energy <= 0.0:
		failures.append("Falta el relleno azul para conservar detalle a contraluz")

	var valley_mist := world.get_node_or_null("ValleyMist") as FogVolume
	if valley_mist == null or not valley_mist.material is FogMaterial:
		failures.append("Falta la bruma localizada del valle")
	elif (valley_mist.material as FogMaterial).density <= 0.0:
		failures.append("La bruma del valle no tiene densidad")

	var ambient_audio := world.get_node("AmbientAudio") as AmbientAudio
	ambient_audio.music.stop()
	ambient_audio.wind.stop()
	ambient_audio.birds.stop()
	for _frame in range(8):
		await process_frame
	if not failures.is_empty():
		_fail(failures)
		return

	print("ATMOSPHERE TEST OK: Forward+, cielo procedural, nubes animadas y bruma volumétrica.")
	quit(0)


func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
