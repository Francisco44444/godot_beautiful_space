extends Node3D

## Cada celda conserva los prismas originales. Una tala sólo rehace el BVH
## local: actualizar los 64.116 triángulos juntos costaba unos 30 ms nativos.
const LADO := 256.0
const VERTICES_TRONCO := 36
var _celdas: Dictionary = {}
var _por_recurso: Dictionary = {}
var _ocultos: Dictionary = {}
var _pendiente_completo := true
var _reconstrucciones := 0
var _triangulos := 0
var _troncos := 0
var _ultima_actualizacion := 0


func preparar(registros: PackedFloat32Array, ids: PackedStringArray) -> void:
	var grupos := {}
	_por_recurso.clear()
	_troncos = registros.size()/5
	for indice in _troncos:
		var inicio := indice*5
		var clave := Vector2i(floori(registros[inicio]/LADO),floori(registros[inicio+2]/LADO))
		if not grupos.has(clave): grupos[clave] = []
		grupos[clave].append(indice)
	for clave in _celdas.keys():
		if grupos.has(clave): continue
		# Desactivar antes de liberar evita conservar un cuerpo antiguo hasta el
		# final del fotograma si se cambia la distribución desde una herramienta.
		var cuerpo: StaticBody3D = _celdas[clave].cuerpo
		_triangulos -= int(_celdas[clave].triangulos)
		cuerpo.collision_layer = 0
		cuerpo.queue_free()
		_celdas.erase(clave)
	for clave in grupos:
		var datos: Dictionary = _celdas.get(clave,{})
		if datos.is_empty():
			var cuerpo := StaticBody3D.new()
			cuerpo.name = "Troncos_%d_%d"%[clave.x,clave.y]
			cuerpo.collision_layer = 1
			cuerpo.collision_mask = 0
			var forma := CollisionShape3D.new()
			forma.name = "Colision"
			forma.disabled = true
			var malla := ConcavePolygonShape3D.new()
			malla.backface_collision = true
			forma.shape = malla
			cuerpo.add_child(forma)
			add_child(cuerpo)
			datos = {"cuerpo":cuerpo,"nodo":forma,"forma":malla,"triangulos":0}
		var caras := PackedVector3Array()
		var recursos := PackedStringArray()
		for indice in grupos[clave]:
			var inicio: int = indice*5
			var base := Vector3(registros[inicio],registros[inicio+1],registros[inicio+2])
			var radio := registros[inicio+3]
			var altura := registros[inicio+4]
			for lado in 6:
				var angulo_a := TAU*float(lado)/6.0
				var angulo_b := TAU*float(lado+1)/6.0
				var bajo_a := base+Vector3(cos(angulo_a)*radio,0,sin(angulo_a)*radio)
				var bajo_b := base+Vector3(cos(angulo_b)*radio,0,sin(angulo_b)*radio)
				var alto_a := bajo_a+Vector3.UP*altura
				var alto_b := bajo_b+Vector3.UP*altura
				caras.append(bajo_a)
				caras.append(bajo_b)
				caras.append(alto_b)
				caras.append(bajo_a)
				caras.append(alto_b)
				caras.append(alto_a)
			var id := String(ids[indice]) if indice<ids.size() else ""
			recursos.append(id)
			if not id.is_empty():
				if not _por_recurso.has(id): _por_recurso[id] = {}
				_por_recurso[id][clave] = true
		datos.caras = caras
		datos.ids = recursos
		_celdas[clave] = datos
	_pendiente_completo = true


func actualizar(destruidos: Dictionary, reservados: Dictionary) -> void:
	var nuevos := {}
	# Las partidas largas pueden acumular más ids que troncos de esta colisión.
	# Se recorre el conjunto pequeño, conservando exactamente la misma unión.
	if destruidos.size()+reservados.size()<_por_recurso.size():
		for conjunto in [destruidos,reservados]:
			for id in conjunto:
				if _por_recurso.has(id): nuevos[id] = true
	else:
		for id in _por_recurso:
			if destruidos.has(id) or reservados.has(id): nuevos[id] = true
	var pendientes := {}
	if _pendiente_completo:
		for clave in _celdas: pendientes[clave] = true
	else:
		for id in _ocultos:
			if not nuevos.has(id): pendientes.merge(_por_recurso[id])
		for id in nuevos:
			if not _ocultos.has(id): pendientes.merge(_por_recurso[id])
	_ocultos = nuevos
	_ultima_actualizacion = pendientes.size()
	for clave in pendientes: _actualizar_celda(_celdas[clave])
	_pendiente_completo = false


func _actualizar_celda(datos: Dictionary) -> void:
	var caras := PackedVector3Array()
	var base: PackedVector3Array = datos.caras
	var ids: PackedStringArray = datos.ids
	var desde := 0
	for indice in ids.size():
		if not _ocultos.has(ids[indice]): continue
		if indice*VERTICES_TRONCO>desde: caras.append_array(base.slice(desde,indice*VERTICES_TRONCO))
		desde = (indice+1)*VERTICES_TRONCO
	if desde<base.size(): caras.append_array(base.slice(desde))
	var nodo: CollisionShape3D = datos.nodo
	# Una celda vacía se desactiva; no conserva colisión fantasma ni obliga al
	# servidor físico a construir un recurso cóncavo vacío.
	if caras.is_empty(): nodo.disabled = true
	else:
		(datos.forma as ConcavePolygonShape3D).set_faces(caras)
		nodo.disabled = false
	_triangulos += caras.size()/3-int(datos.triangulos)
	datos.triangulos = caras.size()/3
	_reconstrucciones += 1


func estadisticas() -> Dictionary:
	return {"celdas":_celdas.size(),"troncos":_troncos,"triangulos":_triangulos,
		"reconstrucciones":_reconstrucciones,"ultima_actualizacion":_ultima_actualizacion}


func caras_activas() -> PackedVector3Array:
	var resultado := PackedVector3Array()
	for datos in _celdas.values():
		if not (datos.nodo as CollisionShape3D).disabled:
			resultado.append_array((datos.forma as ConcavePolygonShape3D).get_faces())
	return resultado
