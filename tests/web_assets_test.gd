extends SceneTree
const Web = preload("res://scripts/compatibilidad_web.gd")
const Obj = preload("res://scripts/quaternius_obj_loader.gd")
func _init() -> void: call_deferred("_comprobar")
func _exigir(valor: bool, mensaje: String) -> bool:
	if valor: return true
	push_error(mensaje)
	quit(1)
	return false
func _comprobar() -> void:
	var shader := load("res://shaders/terreno_web.gdshader") as Shader
	if not _exigir(shader != null and "uniform ivec4 _region_map[256];" in shader.code and "uniform vec2 _region_locations[128];" in shader.code, "El terreno vuelve a superar el bloque WebGL de 16 KiB"): return
	var fuente := shader.code.replace(Web.MAPA_COMPACTO + "\nint leer_region_web(int indice) { return _region_map[indice / 4][indice % 4]; }", Web.MAPA).replace("uniform vec2 _region_locations[128];", Web.UBICACIONES)
	fuente = fuente.replace("leer_region_web( pos.y * _region_map_size + pos.x )", "_region_map[ pos.y * _region_map_size + pos.x ]")
	if not _exigir(Web.codigo_terreno(fuente, 100) == shader.code, "La especialización cambia el relieve o las mezclas del shader real"): return
	if not _exigir(Web.codigo_terreno(fuente,129).is_empty() and Web.codigo_terreno(fuente,0).is_empty() and Web.codigo_terreno("otra versión",100).is_empty(), "Se acepta un terreno fuera de los límites verificados"): return
	var biblioteca := load("res://generated/modelos_obj_runtime.res")
	if not _exigir(biblioteca != null and biblioteca.mallas.size() >= 300, "La exportación pierde la biblioteca de accesorios"): return
	# El PCK conserva la malla importada, pero no el OBJ de texto. Este alias
	# ausente fuerza exactamente la misma ruta que se usa tras exportar.
	var ruta := "res://__modelo_exportado_sin_obj__.obj"
	var original: ArrayMesh = biblioteca.mallas.values()[0]
	var duplicada := biblioteca.duplicate(true)
	duplicada.mallas[ruta] = original
	Obj._biblioteca = duplicada
	Obj._biblioteca_consultada = true
	var a := Obj.load_mesh(ruta)
	var b := Obj.load_mesh(ruta)
	if not _exigir(a != null and b != null and a != b and a.get_surface_count() == original.get_surface_count(), "Falta el modelo cuando su OBJ no viaja en el PCK"): return
	for i in original.get_surface_count():
		if not _exigir(a.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] == original.surface_get_arrays(i)[Mesh.ARRAY_VERTEX], "La biblioteca cambia la geometría original"): return
		var material_a := a.surface_get_material(i) as StandardMaterial3D
		var material_b := b.surface_get_material(i) as StandardMaterial3D
		if not _exigir(material_a != material_b and material_a.albedo_color == material_b.albedo_color, "Dos accesorios comparten un material editable"): return
	Obj._biblioteca = null
	Obj._biblioteca_consultada = false
	print("WEB ASSETS OK: shader real compacto y accesorios exportados con geometría y materiales independientes.")
	quit(0)
