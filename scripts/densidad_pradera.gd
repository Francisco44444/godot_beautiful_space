extends RefCounted

## Cambiar sólo índices reduce triángulos y trabajo de vértices. El RID sigue
## siendo el mismo para los parches individuales del renderizador del bosque.
var _originales: Dictionary = {}
var _fraccion := 1.0

func aplicar(mallas: Array, fraccion: float) -> void:
	fraccion=clampf(fraccion,0.5,1.0)
	if is_equal_approx(fraccion,_fraccion):return
	for malla: ArrayMesh in mallas:
		if malla==null or not malla.has_meta("limites_hierba"):continue
		var id:=malla.get_instance_id()
		if not _originales.has(id):_originales[id]={"superficies":malla.get("_surfaces"),"caja":malla.get_aabb()}
		var original: Dictionary=_originales[id]
		var superficies: Array=original.superficies.duplicate(true)
		if fraccion<1.0:
			for superficie: Dictionary in superficies:
				var vertices:int=superficie.vertex_count
				var cantidad:=int(vertices/3.0*fraccion)*3
				var paso:=2 if vertices<=65536 else 4
				var indices:=PackedByteArray();indices.resize(cantidad*paso)
				for i in cantidad:
					if paso==2:indices.encode_u16(i*2,i)
					else:indices.encode_u32(i*4,i)
				superficie.index_data=indices;superficie.index_count=cantidad
				superficie.format=int(superficie.format)|Mesh.ARRAY_FORMAT_INDEX
		malla.clear_surfaces()
		malla.set("_surfaces",superficies)
		malla.custom_aabb=original.caja
	_fraccion=fraccion
