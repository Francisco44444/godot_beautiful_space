extends SceneTree
const LOD = preload("res://scripts/lod_tejados.gd")
func _init() -> void: call_deferred("_hornear")
func _hornear() -> void:
	if not "--hornear-lod-tejados" in OS.get_cmdline_user_args():
		push_error("Ejecutar con -- --hornear-lod-tejados"); quit(1); return
	if not OS.has_feature("editor"):
		push_error("Hornear requiere el ejecutable del editor de Godot");quit(1);return
	LOD.habilitado=false
	for nombre in ["InventoryManager","ExplorationManager"]: root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo:Node3D=load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 8: await process_frame
	for malla:ArrayMesh in BuildingAssembler._trimmed_roofs.values():
		var datos:Array=_generar(malla)
		if not LOD.valido(malla,datos):
			push_error("El horneado no produce índices válidos");quit(1);return
		LOD._registros[LOD.firma(malla)]=datos
	if LOD.estadisticas().mallas!=15 or LOD.guardar()!=OK:
		push_error("No se hornean los quince recortes de tejado");quit(1);return
	print("ROOF LOD BAKE OK: ",JSON.stringify(LOD.estadisticas()))
	mundo.queue_free()
	for i in 3: await process_frame
	quit(0)

func _generar(malla: ArrayMesh) -> Array:
	var importador := ImporterMesh.new()
	for s in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
			var indices := PackedInt32Array()
			indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
			for i in indices.size(): indices[i]=i
			arrays[Mesh.ARRAY_INDEX]=indices
		importador.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	importador.generate_lods(25.0,60.0,[])
	var salida := []
	for s in malla.get_surface_count():
		var niveles := {}
		for i in importador.get_surface_lod_count(s):
			niveles[importador.get_surface_lod_size(s,i)]=importador.get_surface_lod_indices(s,i)
		salida.append(niveles)
	return salida
