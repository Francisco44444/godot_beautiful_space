extends Node

## El MultiMesh conserva la identidad de cada árbol. Color y sombras se
## descartan por ejemplar y aprovechan la agrupación nativa de Forward+.
## Compensar la distancia y escala evita degradar su LOD.
const MARGEN_CAMARA := 2.0
const CELDAS_POR_FRAME := 12
const DETALLE_COMPLETO := 1000000.0

var activo := true
var sombras_individuales := true
var _preparado := false
var _celdas: Dictionary = {}
var _visibles: Dictionary = {}
var _bancos: Dictionary = {}
var _mallas: Dictionary = {}
var _camara_anterior := Vector3(INF,INF,INF)
var _proyeccion_anterior := -1
var _camara_id := 0
var _pendiente := true
var _poses_pendientes := false
var _creadas := 0
var _turno := 0


func registrar(celda: MultiMeshInstance3D, poses: Array[Transform3D]) -> void:
	# Los otros modos mantienen su ruta para respetar el ajuste de sombras.
	if celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: return
	var id := celda.get_instance_id()
	var datos := {"nodo":celda,"poses":poses.duplicate(),"ids":[],"cajas":[],"escalas":[],"bias":[],
		"camara":Vector3(INF,INF,INF),"sucio":true,"completo":false,
		"sombra":celda.cast_shadow,"capas":celda.layers,"malla":celda.multimesh.mesh.get_instance_id()}
	_celdas[id] = datos
	_mallas[datos.malla] = celda.multimesh.mesh
	celda.visibility_changed.connect(_al_cambiar_visibilidad.bind(id))
	celda.tree_exiting.connect(_desregistrar.bind(id))
	_configurar_celda(datos,activo)
	if _preparado: _al_cambiar_visibilidad(id)


func iniciar() -> void:
	_preparado = true
	for id in _celdas: _al_cambiar_visibilidad(id)
	_pendiente = true


func establecer_activo(valor: bool) -> void:
	if activo==valor: return
	activo = valor
	for id in _celdas:
		var datos: Dictionary = _celdas[id]
		var celda := datos.nodo as MultiMeshInstance3D
		if not is_instance_valid(celda): continue
		_configurar_celda(datos,valor)
		_al_cambiar_visibilidad(id)
	_pendiente = true


func _configurar_celda(datos: Dictionary, individual: bool) -> void:
	var celda := datos.nodo as MultiMeshInstance3D
	# La celda de 340 m obligaba a dibujar en sombras árboles que no alcanzaban
	# la cascada. Las instancias individuales conservan sus mallas y sombras;
	# la fuente queda fuera de las capas de render para evitar duplicarlas.
	celda.layers = 0 if individual and sombras_individuales else int(datos.capas)
	celda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if individual else int(datos.sombra)


func establecer_sombras_individuales(valor: bool) -> void:
	# El control anterior permite medir el coste sin tocar vegetación ni luz,
	# y reutiliza las instancias de color ya activas en lugar de reconstruirlas.
	if sombras_individuales==valor: return
	sombras_individuales = valor
	for datos in _celdas.values():
		_configurar_celda(datos,activo)
		for instancia in datos.ids:
			RenderingServer.instance_geometry_set_cast_shadows_setting(instancia,int(datos.sombra) if valor else RenderingServer.SHADOW_CASTING_SETTING_OFF)


func _al_cambiar_visibilidad(id: int) -> void:
	if not _preparado or not _celdas.has(id): return
	var datos: Dictionary = _celdas[id]
	var celda := datos.nodo as MultiMeshInstance3D
	var mostrar: bool = activo and celda.is_visible_in_tree()
	if mostrar and not _visibles.has(id):
		var banco: Array = _bancos.get(datos.malla,[])
		var ids: Array = datos.ids
		for indice in datos.poses.size():
			var instancia: RID
			if banco.is_empty():
				instancia = RenderingServer.instance_create2(celda.multimesh.mesh.get_rid(),celda.get_world_3d().scenario)
				_creadas += 1
			else: instancia = banco.pop_back()
			RenderingServer.instance_geometry_set_cast_shadows_setting(instancia,int(datos.sombra) if sombras_individuales else RenderingServer.SHADOW_CASTING_SETTING_OFF)
			RenderingServer.instance_geometry_set_lod_bias(instancia,DETALLE_COMPLETO)
			RenderingServer.instance_set_layer_mask(instancia,int(datos.capas))
			RenderingServer.instance_attach_object_instance_id(instancia,id)
			ids.append(instancia)
			datos.cajas.append(AABB())
			datos.escalas.append(1.0)
			datos.bias.append(DETALLE_COMPLETO)
			_actualizar_pose(datos,indice)
		_bancos[datos.malla] = banco
		_visibles[id] = datos
		_pendiente = true
	elif not mostrar and _visibles.has(id):
		_retirar(datos)
		_visibles.erase(id)


func actualizar(celda: MultiMeshInstance3D, indice: int, pose: Transform3D) -> void:
	var id := celda.get_instance_id()
	if not _celdas.has(id): return
	var datos: Dictionary = _celdas[id]
	if indice<0 or indice>=datos.poses.size(): return
	datos.poses[indice] = pose
	if _visibles.has(id):
		_actualizar_pose(datos,indice)
		datos.sucio = true
		_poses_pendientes = true


func _actualizar_pose(datos: Dictionary, indice: int) -> void:
	var celda := datos.nodo as MultiMeshInstance3D
	var pose: Transform3D = celda.global_transform*(datos.poses[indice] as Transform3D)
	var escala := pose.basis.get_scale().abs()
	var mostrar := escala[escala.max_axis_index()]>0.01
	var instancia: RID = datos.ids[indice]
	RenderingServer.instance_set_visible(instancia,mostrar)
	RenderingServer.instance_set_transform(instancia,pose)
	RenderingServer.instance_geometry_set_lod_bias(instancia,DETALLE_COMPLETO)
	datos.bias[indice] = DETALLE_COMPLETO
	datos.completo = false
	# La ráfaga máxima desplaza menos de dos unidades locales. El margen evita
	# recortar copas que el viento saque del volumen del árbol sin deformar.
	RenderingServer.instance_set_extra_visibility_margin(instancia,escala[escala.max_axis_index()]*2.0)
	datos.cajas[indice] = pose*celda.multimesh.mesh.get_aabb()
	datos.escalas[indice] = maxf(escala[escala.min_axis_index()],0.000001)


func _process(_delta: float) -> void:
	var camara := get_viewport().get_camera_3d()
	if not activo or camara==null or _visibles.is_empty(): return
	var forzar := _pendiente or _camara_id!=camara.get_instance_id() or _proyeccion_anterior!=camara.projection
	if not forzar and not _poses_pendientes and _camara_anterior==camara.global_position: return
	var celdas := _visibles.values()
	var revisadas := {}
	for datos in celdas:
		if forzar or bool(datos.sucio) or (datos.camara as Vector3).distance_to(camara.global_position)>MARGEN_CAMARA:
			_actualizar_detalle_celda(datos,camara)
			revisadas[datos.nodo.get_instance_id()] = true
	# Repartir las revisiones mantiene el margen sin una ráfaga de miles de
	# comandos al mover la cámara. Un salto de posición fuerza la revisión.
	for paso in mini(CELDAS_POR_FRAME,celdas.size()):
		_turno = posmod(_turno,celdas.size())
		var datos: Dictionary = celdas[_turno]
		_turno += 1
		if not revisadas.has(datos.nodo.get_instance_id()): _actualizar_detalle_celda(datos,camara)
	_recordar_camara(camara)


func actualizar_detalle(camara: Camera3D) -> void:
	for datos in _visibles.values(): _actualizar_detalle_celda(datos,camara)
	_recordar_camara(camara)


func _recordar_camara(camara: Camera3D) -> void:
	_camara_anterior = camara.global_position
	_camara_id = camara.get_instance_id()
	_proyeccion_anterior = camara.projection
	_pendiente = false
	_poses_pendientes = false


func _actualizar_detalle_celda(datos: Dictionary, camara: Camera3D) -> void:
	var celda := datos.nodo as MultiMeshInstance3D
	var caja: AABB = celda.global_transform*celda.multimesh.custom_aabb
	var distancia := distancia_caja(camara.global_position,caja)
	var completo := distancia<=MARGEN_CAMARA and camara.projection!=Camera3D.PROJECTION_ORTHOGONAL
	datos.camara = camara.global_position
	datos.sucio = false
	if completo and bool(datos.completo): return
	datos.completo = completo
	var escala := celda.global_basis.get_scale().abs()
	var escala_celda := escala[escala.max_axis_index()]
	for indice in datos.ids.size():
		var distancia_individual := distancia_caja(camara.global_position,datos.cajas[indice])
		var bias := compensar_lod(celda.lod_bias,escala_celda,float(datos.escalas[indice]),distancia,distancia_individual,camara.projection==Camera3D.PROJECTION_ORTHOGONAL)
		if float(datos.bias[indice])!=bias:
			RenderingServer.instance_geometry_set_lod_bias(datos.ids[indice],bias)
			datos.bias[indice] = bias


static func distancia_caja(punto: Vector3, caja: AABB) -> float:
	return punto.distance_to(punto.clamp(caja.position,caja.end))


static func compensar_lod(bias: float, escala_celda: float, escala_arbol: float, distancia_celda: float, distancia_arbol: float, ortogonal: bool = false) -> float:
	var proporcion := escala_celda/maxf(escala_arbol,0.000001)
	if ortogonal: return bias*proporcion
	# La distancia a una caja varía como máximo lo que se desplaza la cámara.
	# Estas cotas conservan el detalle hasta la siguiente actualización.
	if distancia_celda<=MARGEN_CAMARA: return DETALLE_COMPLETO
	return maxf(bias*proporcion*(distancia_arbol+MARGEN_CAMARA)/(distancia_celda-MARGEN_CAMARA)*1.0001,0.000001)


func _retirar(datos: Dictionary) -> void:
	var banco: Array = _bancos.get(datos.malla,[])
	for instancia in datos.ids:
		RenderingServer.instance_set_visible(instancia,false)
		banco.append(instancia)
	_bancos[datos.malla] = banco
	datos.ids = []
	datos.cajas = []
	datos.escalas = []
	datos.bias = []
	datos.completo = false


func _desregistrar(id: int) -> void:
	if not _celdas.has(id): return
	var datos: Dictionary = _celdas[id]
	if _visibles.has(id): _retirar(datos)
	_visibles.erase(id)
	_celdas.erase(id)
	var celda := datos.nodo as MultiMeshInstance3D
	if is_instance_valid(celda):
		celda.visibility_changed.disconnect(_al_cambiar_visibilidad.bind(id))
		celda.tree_exiting.disconnect(_desregistrar.bind(id))
		_configurar_celda(datos,false)


func estadisticas() -> Dictionary:
	var dibujados := 0
	var reserva := 0
	for datos in _visibles.values(): dibujados += datos.ids.size()
	for banco in _bancos.values(): reserva += banco.size()
	return {"celdas":_celdas.size(),"activas":_visibles.size(),"instancias":dibujados,"reserva":reserva,"creadas":_creadas}


func _exit_tree() -> void:
	for datos in _visibles.values():
		for instancia in datos.ids: RenderingServer.free_rid(instancia)
	for banco in _bancos.values():
		for instancia in banco: RenderingServer.free_rid(instancia)
	for datos in _celdas.values():
		var celda := datos.nodo as MultiMeshInstance3D
		if is_instance_valid(celda): _configurar_celda(datos,false)
	_visibles.clear()
	_bancos.clear()
	_celdas.clear()
	_mallas.clear()
