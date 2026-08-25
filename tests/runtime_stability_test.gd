extends SceneTree

## Mantiene el juego vivo, atraviesa dos saltos de LOD y cierra el audio de forma
## ordenada. Comprueba que el paisaje es estático y que cada celda muestra una
## sola representación, sin acumular proxies al viajar.


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
	var grass_proxy := scatter.get_node("GrassLODCells") as Node3D
	var tree_full := scatter.get_node("TreeCells") as Node3D
	var tree_proxy := scatter.get_node("TreeLODCells") as Node3D
	if scatter.get_node_or_null("DenseGrassStream") != null:
		push_error("La alfombra móvil de hierba no fue eliminada.")
		quit(1)
		return
	var initial_grass_full_cells := grass_full.get_child_count()
	var initial_grass_proxy_cells := grass_proxy.get_child_count()
	var initial_tree_full_cells := tree_full.get_child_count()
	var initial_tree_proxy_cells := tree_proxy.get_child_count()
	var initial_grass_full_instances := _instance_count(grass_full)
	var initial_grass_proxy_instances := _instance_count(grass_proxy)
	var initial_tree_full_instances := _instance_count(tree_full)
	var initial_tree_proxy_instances := _instance_count(tree_proxy)
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
			or grass_proxy.get_child_count() != initial_grass_proxy_cells
			or tree_full.get_child_count() != initial_tree_full_cells
			or tree_proxy.get_child_count() != initial_tree_proxy_cells
			or _instance_count(grass_full) != initial_grass_full_instances
			or _instance_count(grass_proxy) != initial_grass_proxy_instances
			or _instance_count(tree_full) != initial_tree_full_instances
			or _instance_count(tree_proxy) != initial_tree_proxy_instances
		):
			push_error("El LOD vegetal creó o perdió celdas/instancias durante el viaje rápido.")
			quit(1)
			return
		if not _pair_is_exclusive(grass_full, grass_proxy) or not _pair_is_exclusive(tree_full, tree_proxy):
			push_error("Una celda mantiene simultáneamente el modelo completo y su proxy tras viajar.")
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
	print("RUNTIME STABILITY TEST OK: dos viajes LOD, %d árboles y %d hierbas con reemplazo exclusivo, audio y paisaje activos." % [initial_tree_full_instances, initial_grass_full_instances])
	quit(0)


func _instance_count(category: Node3D) -> int:
	var total := 0
	for node in category.get_children():
		var instance := node as MultiMeshInstance3D
		if instance != null and instance.multimesh != null:
			total += instance.multimesh.instance_count
	return total


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
