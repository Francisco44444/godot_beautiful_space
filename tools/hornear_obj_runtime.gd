extends SceneTree
const Cargador=preload("res://scripts/quaternius_obj_loader.gd")
const Biblioteca=preload("res://scripts/biblioteca_obj.gd")
const RAICES: Array[String]=[
	"res://assets/quaternius/Survival Pack - Sept 2020/OBJ",
	"res://assets/quaternius/Ultimate RPG Items Pack - Aug 2019/OBJ",
	"res://assets/quaternius/Medieval Weapons Pack by @Quaternius/OBJ",
	"res://assets/quaternius/Nature Pack - Jun 2019/OBJ",
]
func _init()->void:call_deferred("_hornear")
func _hornear()->void:
	for nombre in ["InventoryManager","ExplorationManager"]:root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var biblioteca:=Biblioteca.new()
	var vertices:=0
	for raiz in RAICES:
		var archivos:=DirAccess.get_files_at(raiz);archivos.sort()
		for nombre in archivos:
			if nombre.get_extension().to_lower()!="obj":continue
			var ruta:=raiz.path_join(nombre)
			var malla:ArrayMesh=Cargador.load_mesh(ruta)
			assert(malla!=null and malla.get_surface_count()>0,"Modelo OBJ vacío: "+ruta)
			for i in malla.get_surface_count():vertices+=malla.surface_get_array_len(i)
			biblioteca.mallas[ruta]=malla
	DirAccess.make_dir_recursive_absolute("res://generated")
	var error:=ResourceSaver.save(biblioteca,"res://generated/modelos_obj_runtime.res",ResourceSaver.FLAG_COMPRESS)
	assert(error==OK,"No se ha podido hornear la biblioteca OBJ")
	print("OBJ RUNTIME BAKE OK: ",biblioteca.mallas.size()," modelos; ",vertices," vértices con materiales originales.")
	quit(0)
