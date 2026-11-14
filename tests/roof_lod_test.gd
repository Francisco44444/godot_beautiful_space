extends SceneTree
const LOD = preload("res://scripts/lod_tejados.gd")
func _init() -> void: call_deferred("_comprobar")
func _comprobar() -> void:
	if not _exigir(LOD.habilitado,"Los LOD están desactivados por defecto."):return
	LOD.habilitado=false
	for nombre in ["InventoryManager","ExplorationManager"]: root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo:Node3D=load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused=false
	var estado:Dictionary=LOD.estadisticas()
	if not _exigir(estado.solicitudes==15,"La construcción no solicita LOD para los quince recortes: "+str(estado)):return
	LOD.habilitado=true
	var recortes:Dictionary=BuildingAssembler._trimmed_roofs
	if not _exigir(recortes.size()==15,"Cambió el repertorio de tejados: rehornear su LOD."):return
	var niveles_gpu:=0
	for original:ArrayMesh in recortes.values():
		LOD._cargar()
		var clave:=LOD.firma(original)
		if not _exigir(LOD._registros.has(clave),"La firma no es estable al leer los atributos del tejado."):return
		var nuevo:ArrayMesh=LOD.aplicar(original)
		if not _exigir(nuevo!=original,"No se recuperan los índices simplificados del tejado."):return
		for s in original.get_surface_count():
			for buffer in ["vertex_data","attribute_data","skin_data"]:
				if not _exigir(original.get("_surfaces")[s].get(buffer)==nuevo.get("_surfaces")[s].get(buffer),"El LOD recodifica buffers del detalle original."):return
			var antes:=original.surface_get_arrays(s)
			var despues:=nuevo.surface_get_arrays(s)
			if not _exigir(antes[Mesh.ARRAY_VERTEX]==despues[Mesh.ARRAY_VERTEX] and antes[Mesh.ARRAY_TEX_UV]==despues[Mesh.ARRAY_TEX_UV],"El LOD cambia posiciones o UV del detalle completo."):return
			if not _exigir(nuevo.surface_get_material(s)==original.surface_get_material(s),"El LOD sustituye materiales del tejado."):return
			for canal in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]:
				if not _exigir(antes[canal].size()==despues[canal].size(),"El LOD pierde atributos del detalle completo."):return
				for i in antes[canal].size():
					var error:float=antes[canal][i].distance_to(despues[canal][i]) if canal==Mesh.ARRAY_NORMAL else absf(antes[canal][i]-despues[canal][i])
					if not _exigir(error<0.0001,"El LOD altera normales o tangentes del detalle completo."):return
			var indices:PackedInt32Array=despues[Mesh.ARRAY_INDEX]
			if not _exigir(indices.size()==antes[Mesh.ARRAY_VERTEX].size(),"Se pierden triángulos del detalle completo."):return
			for i in indices.size():
				if not _exigir(indices[i]==i,"El LOD reordena los triángulos del detalle completo."):return
			if DisplayServer.get_name()!="headless":
				var datos:Dictionary=RenderingServer.mesh_get_surface(nuevo.get_rid(),s)
				niveles_gpu+=datos.get("lods",[]).size()
		# Una edición real o un material con desplazamiento no puede reutilizar
		# índices calculados para otra geometría.
		var editada:=ArrayMesh.new()
		var atributos:=original.surface_get_arrays(0)
		var vertices:PackedVector3Array=atributos[Mesh.ARRAY_VERTEX].duplicate()
		vertices[0]+=Vector3(0.5,0.0,0.0)
		atributos[Mesh.ARRAY_VERTEX]=vertices
		editada.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,atributos)
		editada.surface_set_material(0,original.surface_get_material(0))
		if not _exigir(LOD.aplicar(editada)==editada,"Una geometría editada reutiliza índices de otra forma."):return
		var material_original:=original.surface_get_material(0)
		original.surface_set_material(0,ShaderMaterial.new())
		var reserva_shader:bool=LOD.aplicar(original)==original
		original.surface_set_material(0,material_original)
		if not _exigir(reserva_shader,"Un shader desconocido reutiliza índices horneados."):return
		# La reserva debe funcionar tanto sin registro como con índices corruptos.
		var registro:Variant=LOD._registros[clave]
		LOD._registros.erase(clave)
		if not _exigir(LOD.aplicar(original)==original,"Un caché ausente no recupera la malla completa."):return
		LOD._registros[clave]=registro
		var corrupto:Array=registro.duplicate(true)
		for superficie:Dictionary in corrupto:
			if superficie.is_empty():continue
			var nivel:Variant=superficie.keys()[0]
			var indices:PackedInt32Array=superficie[nivel].duplicate()
			indices[0]=2147483647
			superficie[nivel]=indices
			break
		LOD._registros[clave]=corrupto
		var reserva:bool=LOD.aplicar(original)==original
		LOD._registros[clave]=registro
		if not _exigir(reserva,"Un índice corrupto llega al render del tejado."):return
	if DisplayServer.get_name()!="headless" and not _exigir(niveles_gpu>=41,"No se suben a la GPU los LOD horneados."):return
	print("ROOF LOD TEST OK: quince mallas, atributos completos, materiales, índices horneados y reserva ante caché ausente/corrupto; niveles GPU ",niveles_gpu)
	mundo.queue_free()
	for i in 3:await process_frame
	quit(0)
func _exigir(condicion:bool,mensaje:String)->bool:
	if condicion:return true
	push_error("ROOF LOD TEST FAIL: "+mensaje)
	quit(1)
	return false
