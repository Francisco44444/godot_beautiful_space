extends RefCounted

## El recorte de los tejados producía mallas sin LOD. Sólo se hornean índices:
## vértices, normales, UV, materiales y colisiones siguen siendo los del juego.
## Un cambio de forma o un caché inválido recupera la malla completa.
const RUTA := "res://generated/arquitectura/lod_tejados.res"
const ESQUEMA := 1
static var _registros: Dictionary = {}
static var _cargado := false
static var habilitado := true
static var _aciertos := 0
static var _solicitudes := 0
static var _reservas := 0

static func aplicar(original: ArrayMesh) -> ArrayMesh:
	_solicitudes += 1
	if not habilitado or original==null or original.get_surface_count()==0: return original
	for s in original.get_surface_count():
		var material := original.surface_get_material(s) as BaseMaterial3D
		if material==null or material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or material.grow: return original
	var clave := firma(original)
	_cargar()
	var datos: Variant = _registros.get(clave)
	if not valido(original,datos):
		_reservas += 1
		return original
	var superficies: Variant=original.get("_surfaces")
	if not superficies is Array or superficies.size()!=original.get_surface_count(): return original
	var nuevas: Array=superficies.duplicate(false)
	for s in nuevas.size():
		var entrada: Dictionary=superficies[s].duplicate(false)
		if not entrada.has("format") or not entrada.has("vertex_data") or not entrada.has("vertex_count"): return original
		var cantidad: int=entrada.vertex_count
		if int(entrada.get("index_count",0))==0:
			var indices:=PackedInt32Array()
			indices.resize(cantidad)
			for i in cantidad: indices[i]=i
			entrada.index_data=_codificar_indices(indices,cantidad)
			entrada.index_count=cantidad
			entrada.format=int(entrada.format)|Mesh.ARRAY_FORMAT_INDEX
		var niveles:=[]
		var errores: Array=datos[s].keys()
		errores.sort()
		for error in errores:
			niveles.append(float(error))
			niveles.append(_codificar_indices(datos[s][error],cantidad))
		entrada.lods=niveles
		nuevas[s]=entrada
	var resultado:=ArrayMesh.new()
	# La serialización nativa conserva los buffers completos byte por byte.
	# Leer atributos y volver a empaquetarlos alteraba normales octaédricas;
	# aquí únicamente se añaden los índices, incluidos los de cada LOD.
	resultado.set("_surfaces",nuevas)
	if resultado.get_surface_count()!=original.get_surface_count(): return original
	resultado.shadow_mesh=original.shadow_mesh
	_aciertos += 1
	return resultado

static func _codificar_indices(indices: PackedInt32Array, vertices: int) -> PackedByteArray:
	var bytes:=PackedByteArray()
	var paso:=2 if vertices<=65536 else 4
	bytes.resize(indices.size()*paso)
	for i in indices.size():
		if paso==2: bytes.encode_u16(i*2,indices[i])
		else: bytes.encode_u32(i*4,indices[i])
	return bytes

static func firma(malla: ArrayMesh) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([ESQUEMA,malla.get_surface_count()]))
	for s in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(s)
		hash.update(var_to_bytes(malla.surface_get_primitive_type(s)))
		for canal in Mesh.ARRAY_MAX:
			var valor: Variant = arrays[canal]
			if canal==Mesh.ARRAY_INDEX:
				var identidad: bool = valor==null or valor.size()==arrays[Mesh.ARRAY_VERTEX].size()
				if valor!=null:
					for i in valor.size():
						if valor[i]!=i: identidad=false; break
				if identidad: valor=null
			# Redondear sólo la firma tolera el redondeo de importación entre
			# plataformas. La malla publicada conserva los atributos originales.
			if valor is PackedVector3Array or valor is PackedVector2Array:
				var redondeado:=PackedInt32Array()
				for punto in valor:
					redondeado.append(roundi(punto.x*10000.0))
					redondeado.append(roundi(punto.y*10000.0))
					if valor is PackedVector3Array: redondeado.append(roundi(punto.z*10000.0))
				valor=redondeado
			elif valor is PackedFloat32Array:
				var redondeado:=PackedInt32Array()
				for numero in valor: redondeado.append(roundi(numero*10000.0))
				valor=redondeado
			hash.update(var_to_bytes(valor))
	return hash.finish().hex_encode()

static func valido(malla: ArrayMesh, datos: Variant) -> bool:
	if not datos is Array or datos.size()!=malla.get_surface_count(): return false
	var niveles := 0
	for s in datos.size():
		if not datos[s] is Dictionary: return false
		var arrays := malla.surface_get_arrays(s)
		var cantidad: int = arrays[Mesh.ARRAY_VERTEX].size()
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var base: int = indices.size() if indices!=null and not indices.is_empty() else cantidad
		if malla.surface_get_primitive_type(s)!=Mesh.PRIMITIVE_TRIANGLES: return false
		for distancia in datos[s]:
			if not (distancia is float or distancia is int) or not is_finite(float(distancia)) or float(distancia)<=0.0: return false
			var lod: Variant = datos[s][distancia]
			if not lod is PackedInt32Array or lod.size()<3 or lod.size()%3!=0 or lod.size()>=base: return false
			for i in lod:
				if i<0 or i>=cantidad: return false
			niveles += 1
	return niveles>0


static func _cargar() -> void:
	if _cargado: return
	_cargado=true
	if not ResourceLoader.exists(RUTA): return
	var recurso := load(RUTA)
	if recurso!=null and int(recurso.get_meta("esquema",0))==ESQUEMA:
		var datos: Variant=recurso.get_meta("mallas",{})
		if datos is Dictionary: _registros=datos

static func guardar() -> Error:
	var recurso:=Resource.new()
	recurso.set_meta("esquema",ESQUEMA)
	recurso.set_meta("mallas",_registros)
	DirAccess.make_dir_recursive_absolute(RUTA.get_base_dir())
	return ResourceSaver.save(recurso,RUTA,ResourceSaver.FLAG_COMPRESS)

static func estadisticas() -> Dictionary:
	return {"mallas":_registros.size(),"aciertos":_aciertos,"reservas":_reservas,"solicitudes":_solicitudes}
