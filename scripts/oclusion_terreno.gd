extends OccluderInstance3D

## Las laderas ocultan geometría con un recurso horneado, sin simular el suelo
## cada fotograma. Una edición del terreno retira inmediatamente el oclusor.
const RUTA_CACHE := "res://generated/oclusion/terreno.res"
const ESQUEMA := 2
const LOD := 4
const PASO := 1 << LOD
const MARGEN := 2.0

var _terreno: Terrain3D
var _estado := {"activo":false,"motivo":"sin iniciar","validacion_ms":0.0}


func iniciar(terreno: Terrain3D, recurso: ArrayOccluder3D = null) -> bool:
	_desconectar()
	occluder = null
	_terreno = terreno
	_estado = {"activo":false,"motivo":"terreno no compatible","validacion_ms":0.0}
	if not compatible(terreno): return false
	if recurso == null and ResourceLoader.exists(RUTA_CACHE): recurso = load(RUTA_CACHE) as ArrayOccluder3D
	if recurso == null: return false
	var inicio := Time.get_ticks_usec()
	var coincide := int(recurso.get_meta("esquema",0))==ESQUEMA and str(recurso.get_meta("firma",""))==firma(terreno)
	_estado.validacion_ms = float(Time.get_ticks_usec()-inicio)/1000.0
	_estado.motivo = "cache desactualizado"
	if not coincide: return false
	# Terrain3D usa coordenadas mundiales; heredar la pose del mundo movería sólo
	# el oclusor. También permite que el recurso se comparta entre varias escenas.
	top_level = true
	global_transform = Transform3D.IDENTITY
	occluder = recurso
	_estado.activo = true
	_estado.motivo = "cache verificado"
	_estado.triangulos = recurso.get_indices().size()/3
	terreno.data.maps_changed.connect(_invalidar)
	terreno.data.region_map_changed.connect(_invalidar)
	terreno.material_changed.connect(_invalidar)
	terreno.visibility_changed.connect(_invalidar)
	return true


func _invalidar() -> void:
	# No conservar ni un fotograma la cubierta antigua sobre una gruta nueva.
	occluder = null
	_estado.activo = false
	_estado.motivo = "terreno modificado"


func _desconectar() -> void:
	if not is_instance_valid(_terreno): return
	for senal in [_terreno.data.maps_changed,_terreno.data.region_map_changed,_terreno.material_changed,_terreno.visibility_changed]:
		if senal.is_connected(_invalidar): senal.disconnect(_invalidar)


func estadisticas() -> Dictionary:
	return _estado.duplicate()


static func compatible(terreno: Terrain3D) -> bool:
	if terreno==null or terreno.data==null or terreno.material==null or not terreno.is_visible_in_tree() or terreno.global_transform!=Transform3D.IDENTITY: return false
	if terreno.has_method("get_tessellation_level") and int(terreno.call("get_tessellation_level"))!=0: return false
	return not terreno.material.shader_override_enabled


static func firma(terreno: Terrain3D) -> String:
	var resumen := HashingContext.new()
	resumen.start(HashingContext.HASH_SHA256)
	resumen.update(var_to_bytes([ESQUEMA,LOD,MARGEN,terreno.version,terreno.vertex_spacing,terreno.region_size,terreno.mesh_size,terreno.mesh_lods]))
	# El Array nativo se comparte con Terrain3D: ordenar una copia evita cambiar
	# su correspondencia interna entre regiones y capas de textura.
	var ubicaciones := terreno.data.get_region_locations().duplicate()
	ubicaciones.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x<b.x or (a.x==b.x and a.y<b.y))
	for ubicacion in ubicaciones:
		resumen.update(var_to_bytes(ubicacion))
		var region := terreno.data.get_region(ubicacion)
		for tipo in [Terrain3DRegion.TYPE_HEIGHT,Terrain3DRegion.TYPE_CONTROL]:
			resumen.update(region.get_map(tipo).get_data())
	return resumen.finish().hex_encode()


static func construir(terreno: Terrain3D) -> ArrayOccluder3D:
	if not compatible(terreno): return null
	var inicio := Time.get_ticks_usec()
	var malla := terreno.bake_mesh(LOD,Terrain3DData.HEIGHT_FILTER_MINIMUM) as ArrayMesh
	if malla==null or malla.get_surface_count()!=1: return null
	var regiones := {}
	var alturas := {}
	var prohibidas := {}
	for ubicacion in terreno.data.get_region_locations():
		regiones[ubicacion] = true
		var region := terreno.data.get_region(ubicacion)
		alturas[ubicacion] = region.get_map(Terrain3DRegion.TYPE_HEIGHT).get_data().to_float32_array()
		var controles := region.get_map(Terrain3DRegion.TYPE_CONTROL).get_data().to_int32_array()
		for indice in controles.size():
			if (controles[indice]&4)==0: continue
			var pixel: Vector2i = ubicacion*terreno.region_size+Vector2i(indice%terreno.region_size,indice/terreno.region_size)
			var celda := Vector2i(floori(float(pixel.x)/PASO),floori(float(pixel.y)/PASO))
			# El baker nativo puede rellenar una esquina NaN junto a un agujero.
			# Excluir también sus vecinos preserva el vestíbulo y la bóveda reales.
			for z in range(-1,2):
				for x in range(-1,2): prohibidas[celda+Vector2i(x,z)] = true
	var puntos := caras_seguras(malla.surface_get_arrays(0),prohibidas,regiones,terreno.region_size,terreno.vertex_spacing,alturas)
	var indices := PackedInt32Array()
	indices.resize(puntos.size())
	for indice in indices.size(): indices[indice] = indice
	var recurso := ArrayOccluder3D.new()
	recurso.set_arrays(puntos,indices)
	recurso.set_meta("esquema",ESQUEMA)
	recurso.set_meta("firma",firma(terreno))
	recurso.set_meta("triangulos",indices.size()/3)
	recurso.set_meta("celdas_excluidas",prohibidas.size())
	recurso.set_meta("horneado_ms",float(Time.get_ticks_usec()-inicio)/1000.0)
	return recurso


static func caras_seguras(matriz: Array, prohibidas: Dictionary, regiones: Dictionary, tamano: int, espaciado: float, alturas: Dictionary) -> PackedVector3Array:
	var vertices: PackedVector3Array = matriz[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = matriz[Mesh.ARRAY_INDEX]
	var puntos := PackedVector3Array()
	for indice in range(0,indices.size(),3):
		var a := vertices[indices[indice]]
		var b := vertices[indices[indice+1]]
		var c := vertices[indices[indice+2]]
		if not a.is_finite() or not b.is_finite() or not c.is_finite(): continue
		var minimo := a.min(b).min(c)
		var maximo := a.max(b).max(c)
		var celda := Vector2i(roundi(minimo.x/(PASO*espaciado)),roundi(minimo.z/(PASO*espaciado)))
		if prohibidas.has(celda): continue
		var presentes := true
		for punto in [a,b,c]:
			var region := Vector2i(floori(punto.x/(tamano*espaciado)),floori(punto.z/(tamano*espaciado)))
			if not regiones.has(region): presentes = false; break
		if not presentes or maximo.x-minimo.x>PASO*espaciado*1.001 or maximo.z-minimo.z>PASO*espaciado*1.001: continue
		# Comprobar la huella completa conserva las laderas del baker mínimo y
		# baja únicamente los planos que todavía cruzan una depresión interior.
		var plano := Plane(a,b,c)
		if absf(plano.normal.y)<0.000001: continue
		var descenso := 0.0
		var poligono := PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
		for z in range(roundi(minimo.z/espaciado),roundi(maximo.z/espaciado)+1):
			for x in range(roundi(minimo.x/espaciado),roundi(maximo.x/espaciado)+1):
				var muestra := Vector2(x*espaciado,z*espaciado)
				if not Geometry2D.is_point_in_polygon(muestra,poligono): continue
				var region := Vector2i(floori(float(x)/tamano),floori(float(z)/tamano))
				var mapa: PackedFloat32Array = alturas[region]
				var altura := mapa[posmod(z,tamano)*tamano+posmod(x,tamano)]
				if not is_finite(altura): presentes = false; break
				var cota := (plano.d-plano.normal.x*muestra.x-plano.normal.z*muestra.y)/plano.normal.y
				descenso = maxf(descenso,cota-altura)
			if not presentes: break
		if not presentes: continue
		a.y -= descenso+MARGEN
		b.y -= descenso+MARGEN
		c.y -= descenso+MARGEN
		puntos.append_array(PackedVector3Array([a,b,c]))
	return puntos
