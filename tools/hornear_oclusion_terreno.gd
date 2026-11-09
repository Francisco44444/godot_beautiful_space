extends SceneTree

## Regenerar tras modificar alturas, agujeros, grutas o la malla de Terrain3D:
## Godot --headless --path . --script res://tools/hornear_oclusion_terreno.gd
const OclusionTerreno = preload("res://scripts/oclusion_terreno.gd")

func _init() -> void: call_deferred("hornear")

func hornear() -> void:
	for nombre in ["ExplorationManager","InventoryManager"]:
		root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").call("bind_world",null)
	await mundo.get_node("RPGStoryRuntime").terreno_preparado
	var recurso := OclusionTerreno.construir(mundo.get_node("Terrain3D"))
	if recurso==null:
		push_error("No se pudo hornear el terreno.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OclusionTerreno.RUTA_CACHE.get_base_dir())
	var resultado := ResourceSaver.save(recurso,OclusionTerreno.RUTA_CACHE,ResourceSaver.FLAG_COMPRESS)
	if resultado!=OK:
		push_error("No se pudo guardar el oclusor.")
		quit(1)
		return
	print("OCLUSION TERRENO HORNEADA ",recurso.get_meta("triangulos")," triángulos; ",recurso.get_meta("horneado_ms")," ms; firma ",recurso.get_meta("firma"))
	quit()
