extends SceneTree

## Mantiene el juego vivo, atraviesa dos saltos de LOD y cierra el audio de forma
## ordenada. Comprueba que el paisaje fijo no acumula celdas al viajar y que la
## ventana GPU cercana se repuebla sobre las mismas posiciones del mundo.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var game_settings := root.get_node_or_null("GameSettings")
	if game_settings != null:
		game_settings.call("reset_defaults", false)
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		push_error("No se pudo cargar la escena principal.")
		quit(1)
		return

	var world := scene.instantiate()
	root.add_child(world)
	for _frame in range(4):
		await process_frame
	var scatter := world.get_node("VegetationScatter") as VegetationScatter
	var grass_full := scatter.get_node("GrassCells") as Node3D
	var grass_mid := scatter.get_node("GrassMidLODCells") as Node3D
	var grass_proxy := scatter.get_node("GrassLODCells") as Node3D
	var tree_full := scatter.get_node("TreeCells") as Node3D
	var tree_proxy := scatter.get_node("TreeLODCells") as Node3D
	var clouds := world.get_node("AnimatedClouds") as AnimatedClouds
	var procedural_veil := clouds.get_node_or_null("ProceduralCloudVeil") as MeshInstance3D
	if scatter.get_node_or_null("DenseGrassStream") != null:
		push_error("La alfombra móvil de hierba no fue eliminada.")
		quit(1)
		return
	if (
		bool(clouds.get_meta("illustrated_billboards", true))
		or not bool(clouds.get_meta("procedural_clouds_only", false))
		or not bool(clouds.get_meta("distributed_cloud_banks", false))
		or not bool(clouds.get_meta("clear_sky_gaps", false))
		or int(clouds.get_meta("depth_band_count", 0)) != 1
		or procedural_veil == null
		or not procedural_veil.mesh is SphereMesh
		or _has_legacy_cloud_nodes(clouds)
	):
		push_error("El cielo no conserva sus bancos procedurales con huecos despejados.")
		quit(1)
		return
	for removed_cloud_name in [
		"IllustratedCloudNear",
		"IllustratedCloudMid",
		"IllustratedCloudHorizon",
		"CloudShadowMasks",
	]:
		if clouds.get_node_or_null(removed_cloud_name) != null:
			push_error("Se reactivó una capa de nubes dibujadas: %s." % removed_cloud_name)
			quit(1)
			return
	if (
		int(scatter.get_meta("tree_wind_materials", 0)) <= 0
		or scatter.get_meta("tree_wind_gust_levels", PackedStringArray()).size() != 3
		or not _tree_wind_shader_present(tree_full)
	):
		push_error("Las ramas y copas no conservan el shader de viento con tres intensidades.")
		quit(1)
		return
	var initial_grass_full_cells := grass_full.get_child_count()
	var initial_grass_mid_cells := grass_mid.get_child_count()
	var initial_grass_proxy_cells := grass_proxy.get_child_count()
	var initial_tree_full_cells := tree_full.get_child_count()
	var initial_tree_proxy_cells := tree_proxy.get_child_count()
	var initial_grass_proxy_instances := _instance_count(grass_proxy)
	var initial_tree_full_instances := _instance_count(tree_full)
	var initial_tree_proxy_instances := _instance_count(tree_proxy)
	var vegetation_cache := load("res://generated/vegetation_layout_cache.res") as VegetationLayoutCache
	if vegetation_cache != null and vegetation_cache.grass_records.size() >= 3:
		var fixed_grass_focus := Vector2(
			vegetation_cache.grass_records[0],
			vegetation_cache.grass_records[2]
		)
		scatter.call("_update_grass_near_field", fixed_grass_focus, true)
		var fixed_count_before := _instance_count(grass_full)
		var fixed_mid_count_before := _instance_count(grass_mid)
		scatter.call("_update_grass_near_field", fixed_grass_focus + Vector2(900.0, 900.0), true)
		scatter.call("_update_grass_near_field", fixed_grass_focus, true)
		if (
			fixed_count_before <= 0
			or fixed_mid_count_before <= fixed_count_before
			or _instance_count(grass_full) != fixed_count_before
			or _instance_count(grass_mid) != fixed_mid_count_before
		):
			push_error("La hierba no recupera exactamente su ventana fija al regresar.")
			quit(1)
			return
	for slot in [4, 3]:
		if not world.fast_travel_to(slot):
			push_error("No se pudo ejecutar el viaje rápido %d durante la prueba LOD." % slot)
			quit(1)
			return
		for _frame in range(4):
			await process_frame
		scatter.call("_update_explicit_lod_visibility", true)
		if (
			grass_full.get_child_count() != initial_grass_full_cells
			or grass_mid.get_child_count() != initial_grass_mid_cells
			or grass_proxy.get_child_count() != initial_grass_proxy_cells
			or tree_full.get_child_count() != initial_tree_full_cells
			or tree_proxy.get_child_count() != initial_tree_proxy_cells
			or _instance_count(grass_proxy) != initial_grass_proxy_instances
			or _instance_count(tree_full) != initial_tree_full_instances
			or _instance_count(tree_proxy) != initial_tree_proxy_instances
		):
			push_error("El LOD vegetal creó o perdió celdas/instancias durante el viaje rápido.")
			quit(1)
			return
		if clouds.get_node_or_null("ProceduralCloudVeil") != procedural_veil:
			push_error("El domo procedural fue sustituido durante el viaje rápido.")
			quit(1)
			return
		if not _pair_is_exclusive(tree_full, tree_proxy):
			push_error("Una celda de árboles mantiene simultáneamente el modelo completo y su proxy.")
			quit(1)
			return
		if not bool(scatter.get_meta("grass_lod_crossfade", false)):
			push_error("La ventana cercana de hierba perdió el fundido tras el viaje.")
			quit(1)
			return
		if scatter.explicit_lod_visible_full_cells <= 0 or scatter.explicit_lod_visible_proxy_cells <= 0:
			push_error("El viaje no deja activos ambos niveles LOD en celdas diferentes.")
			quit(1)
			return

	var audio := world.get_node("AmbientAudio") as AmbientAudio
	var horse := world.get_node("Horse") as Horse
	audio.music.stop()
	audio.snow_music.stop()
	audio.desert_music.stop()
	audio.wind.stop()
	audio.birds.stop()
	horse.hoof_audio.stop()
	for _frame in range(8):
		await process_frame
	print("RUNTIME STABILITY TEST OK: dos viajes LOD, %d árboles y hierba fija con ventana GPU fundida, audio y paisaje activos." % initial_tree_full_instances)
	quit(0)


func _instance_count(category: Node3D) -> int:
	var total := 0
	for node in category.get_children():
		var instance := node as MultiMeshInstance3D
		if instance != null and instance.multimesh != null:
			total += instance.multimesh.instance_count
	return total


func _tree_wind_shader_present(category: Node3D) -> bool:
	for node in category.get_children():
		var instance := node as MultiMeshInstance3D
		if instance == null or instance.multimesh == null or instance.multimesh.mesh == null:
			continue
		var mesh := instance.multimesh.mesh
		for surface_index in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface_index) as ShaderMaterial
			if (
				material != null
				and material.shader != null
				and "strong_gust" in material.shader.code
				and "leaf_flutter" in material.shader.code
			):
				return true
	return false


func _has_legacy_cloud_nodes(clouds: Node) -> bool:
	for node_name in [
		"MovingCloudDome",
		"CloudLayer01",
		"CloudLayer02",
		"CloudLayer03",
		"ShadowCumulus",
		"DistantCumulus",
	]:
		if clouds.get_node_or_null(node_name) != null:
			return true
	return false


func _pair_is_exclusive(full_root: Node3D, proxy_root: Node3D) -> bool:
	var visible_full_cells: Dictionary = {}
	for node in full_root.get_children():
		var instance := node as MultiMeshInstance3D
		if instance != null and instance.visible:
			visible_full_cells[instance.get_meta("cell")] = true
	for node in proxy_root.get_children():
		var instance := node as MultiMeshInstance3D
		if instance != null and instance.visible and visible_full_cells.has(instance.get_meta("cell")):
			return false
	return true
