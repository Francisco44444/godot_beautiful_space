extends SceneTree

## Valida la composición funcional del hito épico: pared rocosa, fortaleza,
## cascada, niebla, partículas, audio, poza y río.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return

	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 4:
		await process_frame

	var landmark := world.get_node_or_null("EpicLandmark") as EpicLandmark
	if landmark == null:
		_fail("Falta EpicLandmark en el mundo.")
		return
	if not world.has_node("MedievalSetDressing"):
		_fail("Falta el decorado medieval de Quaternius.")
		return
	if landmark.cliff_piece_count != 16:
		_fail("La pared rocosa Quaternius debería contener 16 piezas visuales.")
		return
	if landmark.fortress_piece_count != 8:
		_fail("La fortaleza Quaternius debería contener 8 módulos.")
		return
	if is_nan(landmark.landmark_ground_height):
		_fail("EpicLandmark no pudo leer la altura del terreno.")
		return

	for root_name in ["EpicCliffs", "Waterfall", "Pool", "Fortress"]:
		var category := landmark.get_node_or_null(root_name) as Node3D
		if category == null or category.get_child_count() == 0:
			_fail("La sección %s del hito está vacía." % root_name)
			return

	for collision_path in [
		"EpicCliffs/CliffCollisionCenter",
		"EpicCliffs/CliffCollisionWest",
		"EpicCliffs/CliffCollisionEast",
		"Fortress/FortressCollision",
	]:
		var body := landmark.get_node_or_null(collision_path) as StaticBody3D
		if body == null or body.get_child_count() != 1:
			_fail("Falta la colisión sólida %s." % collision_path)
			return
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or collision.shape == null:
			_fail("%s no tiene una forma de colisión válida." % collision_path)
			return

	var main_fall := landmark.get_node_or_null("Waterfall/WaterfallMain") as MeshInstance3D
	var veil := landmark.get_node_or_null("Waterfall/WaterfallVeil") as MeshInstance3D
	if not _has_shader_mesh(main_fall) or not _has_shader_mesh(veil):
		_fail("Las dos láminas de la cascada deben usar material shader.")
		return
	var main_fall_mesh := main_fall.mesh as PlaneMesh
	if main_fall_mesh == null or main_fall_mesh.size.y < 37.5:
		_fail("La cascada principal no conserva sus 38 m de altura.")
		return

	var waterfall_mist := landmark.get_node_or_null("Waterfall/WaterfallMist") as FogVolume
	if waterfall_mist == null or not waterfall_mist.material is FogMaterial:
		_fail("Falta la niebla localizada de la cascada.")
		return
	if (waterfall_mist.material as FogMaterial).density <= 0.0:
		_fail("La niebla de la cascada no tiene densidad.")
		return
	for particle_path in ["Waterfall/BaseSpray", "Waterfall/CrestSpray"]:
		var particles := landmark.get_node_or_null(particle_path) as GPUParticles3D
		if particles == null or particles.amount <= 0 or particles.draw_pass_1 == null:
			_fail("El sistema %s no está configurado." % particle_path)
			return

	var waterfall_audio := landmark.get_node_or_null("Waterfall/WaterfallAudio") as AudioStreamPlayer3D
	if waterfall_audio == null or waterfall_audio.stream == null:
		_fail("Falta el audio 3D de la cascada.")
		return
	if waterfall_audio.bus != &"Ambience" or waterfall_audio.max_distance < 250.0:
		_fail("El audio de la cascada no usa el bus o alcance previstos.")
		return

	for water_path in ["Pool/WaterfallPool", "Pool/River"]:
		var water := landmark.get_node_or_null(water_path) as MeshInstance3D
		if not _has_shader_mesh(water):
			_fail("%s no tiene agua renderizable con shader." % water_path)
			return

	waterfall_audio.stop()
	var ambient_audio := world.get_node("AmbientAudio") as AmbientAudio
	ambient_audio.music.stop()
	ambient_audio.wind.stop()
	ambient_audio.birds.stop()
	world.queue_free()
	for _frame in 8:
		await process_frame
	print("EPIC LANDMARK TEST OK: riscos, fortaleza, cascada de 38 m, poza y río operativos.")
	quit(0)


func _has_shader_mesh(instance: MeshInstance3D) -> bool:
	if instance == null or instance.mesh == null or instance.mesh.get_surface_count() == 0:
		return false
	return instance.mesh.surface_get_material(0) is ShaderMaterial


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
