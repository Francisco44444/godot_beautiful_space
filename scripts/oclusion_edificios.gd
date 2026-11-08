extends RefCounted

## Sólo copia triángulos grandes de la estructura opaca estática. Los huecos
## siguen siendo huecos: no se reemplaza la casa por una caja envolvente.
const AREA_DOBLE_MINIMA := 0.8
var _cache: Dictionary = {}


func construir(raiz: Node3D) -> Dictionary:
	var inicio := Time.get_ticks_usec()
	var casas := 0
	var triangulos := 0
	var piezas := 0
	for casa in raiz.get_children():
		if not casa is Node3D or not casa.has_meta("recipe") or casa.get_script()!=null: continue
		if casa.has_node("OclusionEstructura"): continue
		var puntos := PackedVector3Array()
		for nodo in casa.find_children("*","GeometryInstance3D",true,false):
			if not es_estructura_estatica(nodo,casa): continue
			var pose := pose_relativa(nodo,casa)
			if nodo is MeshInstance3D:
				if nodo.mesh==null or nodo.skin!=null: continue
				var modificada := false
				for superficie in nodo.mesh.get_surface_count():
					if nodo.get_surface_override_material(superficie)!=null: modificada = true; break
				if modificada: continue
				var caras := caras_opacas(nodo.mesh)
				if caras.is_empty(): continue
				for punto in caras: puntos.append(pose*punto)
				piezas += 1
			elif nodo is MultiMeshInstance3D and nodo.multimesh!=null and nodo.has_meta("poses_oclusion"):
				var multimesh := nodo.multimesh as MultiMesh
				if multimesh.mesh==null or multimesh.use_colors or multimesh.use_custom_data: continue
				var poses: Array = nodo.get_meta("poses_oclusion")
				var visibles := multimesh.instance_count if multimesh.visible_instance_count<0 else multimesh.visible_instance_count
				if poses.size()!=visibles: continue
				var caras := caras_opacas(multimesh.mesh)
				for local in poses:
					var posicion: Transform3D = pose*(local as Transform3D)
					for punto in caras: puntos.append(posicion*punto)
				piezas += poses.size()
		if puntos.is_empty(): continue
		var indices := PackedInt32Array()
		indices.resize(puntos.size())
		for indice in puntos.size(): indices[indice] = indice
		var recurso := ArrayOccluder3D.new()
		recurso.set_arrays(puntos,indices)
		var oclusor := OccluderInstance3D.new()
		oclusor.name = "OclusionEstructura"
		oclusor.occluder = recurso
		casa.add_child(oclusor)
		casas += 1
		triangulos += puntos.size()/3
	return {"casas":casas,"triangulos":triangulos,"piezas":piezas,"mallas_cache":_cache.size(),"construccion_cpu_ms":float(Time.get_ticks_usec()-inicio)/1000.0}


static func es_estructura_estatica(nodo: GeometryInstance3D, casa: Node3D) -> bool:
	if not nodo.is_visible_in_tree() or nodo.layers!=1 or nodo.material_override!=null or nodo.material_overlay!=null: return false
	if nodo.visibility_range_begin!=0.0 or nodo.visibility_range_end!=0.0: return false
	var marcada := false
	var actual: Node = nodo
	while actual!=null and actual!=casa:
		if actual.get_script()!=null: return false
		if actual is Node3D and (not actual.visible or actual.top_level): return false
		if actual.has_meta("oclusion_estructura"): marcada = true
		actual = actual.get_parent()
	return marcada and actual==casa


static func pose_relativa(nodo: Node3D, casa: Node3D) -> Transform3D:
	# Componer las poses locales evita restar coordenadas kilométricas para
	# volver al espacio de la casa y conserva los bordes de ventanas y escaleras.
	var pose := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual!=casa and actual!=null:
		if actual is Node3D: pose = actual.transform*pose
		actual = actual.get_parent()
	return pose


func caras_opacas(malla: Mesh) -> PackedVector3Array:
	if not malla is ArrayMesh: return PackedVector3Array()
	var mascara := ""
	for superficie in malla.get_surface_count():
		mascara += "1" if material_opaco(malla.surface_get_material(superficie)) and malla.surface_get_primitive_type(superficie)==Mesh.PRIMITIVE_TRIANGLES else "0"
	var clave := "%s:%s" % [malla.get_instance_id(),mascara]
	if _cache.has(clave): return _cache[clave]
	var puntos := PackedVector3Array()
	for superficie in malla.get_surface_count():
		if mascara[superficie]!="1": continue
		var arrays := malla.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for indice in vertices.size(): indices[indice] = indice
		for indice in range(0,indices.size(),3):
			var a := vertices[indices[indice]]
			var b := vertices[indices[indice+1]]
			var c := vertices[indices[indice+2]]
			if (b-a).cross(c-a).length()<AREA_DOBLE_MINIMA: continue
			puntos.append_array(PackedVector3Array([a,b,c]))
	_cache[clave] = puntos
	return puntos


static func material_opaco(material: Material) -> bool:
	if not material is BaseMaterial3D: return false
	return material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.cull_mode==BaseMaterial3D.CULL_DISABLED and material.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and material.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED and not material.proximity_fade_enabled and not material.grow
