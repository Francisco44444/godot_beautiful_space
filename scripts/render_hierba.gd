extends Node

## Los dos campos de hierba conservan su distribución y sus materiales. Sólo
## cambia el volumen que el motor puede descartar antes de ejecutar el shader.
const MARGEN_VIENTO := 5.0
const DESCENSO_MAXIMO := 0.52 * 0.34 + 0.13 + 0.62
const LIMITE_CACHE := 2048

var activo := true
var _terreno: Terrain3D
var _campos: Dictionary = {}
var _bancos: Dictionary = {}
var _mallas: Dictionary = {}
var _alturas: Dictionary = {}
var _claves_alturas: Array[Rect2i] = []
var _turno_alturas := 0
var _creadas := 0
var _preparaciones_parches := 0
var _consultas_alturas := 0
var _aciertos_alturas := 0


func iniciar(terreno: Terrain3D) -> void:
	_terreno = terreno
	if terreno != null and terreno.data != null:
		terreno.data.height_maps_changed.connect(_invalidar_alturas)
		terreno.data.region_map_changed.connect(_invalidar_alturas)


func registrar(campo: MultiMeshInstance3D, sincronizar_fuente: Callable = Callable()) -> void:
	if campo.multimesh == null or campo.multimesh.mesh == null: return
	var malla := campo.multimesh.mesh
	# Este contrato corresponde a las briznas opacas generadas por el juego.
	# Otras mallas o materiales conservan íntegra su representación original.
	if not malla.has_meta("limites_hierba") or campo.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return
	if campo.material_override != null or campo.material_overlay != null or campo.multimesh.use_colors or campo.multimesh.use_custom_data: return
	var id := campo.get_instance_id()
	if _campos.has(id): return
	_campos[id] = {"nodo":campo,"malla":malla,"capas":campo.layers,"poses":[],"identidades":PackedInt64Array(),"instancias":{},"base":campo.global_transform,"sincronizar_fuente":sincronizar_fuente}
	_mallas[malla.get_instance_id()] = malla
	campo.visibility_changed.connect(_sincronizar_visibilidad.bind(id))
	campo.tree_exiting.connect(_desregistrar.bind(id))
	campo.layers = 0 if activo else campo.layers


func actualizar(campo: MultiMeshInstance3D, poses: Array[Transform3D], identidades: PackedInt64Array = PackedInt64Array()) -> void:
	var id := campo.get_instance_id()
	if not _campos.has(id): return
	var datos: Dictionary = _campos[id]
	datos.poses = poses.duplicate()
	# La distribución del juego es inmutable: cada identidad conserva su pose.
	# Buscar enteros evita multiplicar y hashear mil matrices al renovar ventana.
	datos.identidades = identidades if identidades.size()==poses.size() else PackedInt64Array()
	_sincronizar_visibilidad(id)


func establecer_activo(valor: bool) -> void:
	if activo == valor: return
	activo = valor
	for id in _campos:
		var datos: Dictionary = _campos[id]
		var campo := datos.nodo as MultiMeshInstance3D
		if not valor and (datos.sincronizar_fuente as Callable).is_valid(): datos.sincronizar_fuente.call(campo,datos.poses)
		campo.layers = 0 if valor else int(datos.capas)
		_sincronizar_visibilidad(id)


func difiere_fuente(campo: MultiMeshInstance3D) -> bool:
	var id := campo.get_instance_id()
	return activo and _campos.has(id) and (_campos[id].sincronizar_fuente as Callable).is_valid()


func _sincronizar_visibilidad(id: int) -> void:
	if not _campos.has(id): return
	var datos: Dictionary = _campos[id]
	var campo := datos.nodo as MultiMeshInstance3D
	if not activo or not campo.is_visible_in_tree():
		_retirar(datos)
		return
	if not (datos.identidades as PackedInt64Array).is_empty():
		_actualizar_identidades(datos)
		return
	var cantidades := {}
	for pose_local in datos.poses:
		var pose: Transform3D = campo.global_transform * (pose_local as Transform3D)
		cantidades[pose] = int(cantidades.get(pose,0)) + 1
	var anteriores: Dictionary = datos.instancias
	# Se devuelven primero los parches que salieron. Un salto de cámara reutiliza
	# la reserva en vez de crear otra ventana completa antes de liberar la vieja.
	for pose in anteriores:
		var entradas: Array = anteriores[pose]
		var conservar := int(cantidades.get(pose,0))
		while entradas.size() > conservar: _devolver(datos.malla,entradas.pop_back())
	var nuevas := {}
	for pose in cantidades:
		var entradas: Array = anteriores.get(pose,[])
		var resultado: Array = []
		for indice in int(cantidades[pose]):
			if not entradas.is_empty(): resultado.append(entradas.pop_back())
			else: resultado.append(_crear_parche(datos,pose))
		nuevas[pose] = resultado
	datos.instancias = nuevas


func _actualizar_identidades(datos: Dictionary) -> void:
	var campo := datos.nodo as MultiMeshInstance3D
	if datos.base != campo.global_transform:
		_retirar(datos)
		datos.base = campo.global_transform
	var anteriores: Dictionary = datos.instancias
	var identidades: PackedInt64Array = datos.identidades
	var nuevas := {}
	var pendientes := PackedInt32Array()
	for indice in identidades.size():
		var id := identidades[indice]
		if anteriores.has(id):
			nuevas[id] = anteriores[id]
			anteriores.erase(id)
		else: pendientes.append(indice)
	for entradas in anteriores.values():
		for entrada in entradas: _devolver(datos.malla,entrada)
	for indice in pendientes:
		var pose: Transform3D = campo.global_transform * (datos.poses[indice] as Transform3D)
		nuevas[identidades[indice]] = [_crear_parche(datos,pose)]
	datos.instancias = nuevas


func _crear_parche(datos: Dictionary, pose: Transform3D) -> Dictionary:
	_preparaciones_parches += 1
	var campo := datos.nodo as MultiMeshInstance3D
	var malla := datos.malla as Mesh
	var clave := malla.get_instance_id()
	var banco: Array = _bancos.get(clave,[])
	var instancia: RID
	if banco.is_empty():
		instancia = RenderingServer.instance_create2(malla.get_rid(),campo.get_world_3d().scenario)
		_creadas += 1
	else: instancia = banco.pop_back()
	_bancos[clave] = banco
	var caja := calcular_caja(malla,pose)
	RenderingServer.instance_set_transform(instancia,pose)
	RenderingServer.instance_set_custom_aabb(instancia,caja)
	RenderingServer.instance_set_layer_mask(instancia,int(datos.capas))
	RenderingServer.instance_attach_object_instance_id(instancia,campo.get_instance_id())
	RenderingServer.instance_geometry_set_cast_shadows_setting(instancia,RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_geometry_set_lod_bias(instancia,campo.lod_bias)
	RenderingServer.instance_set_visible(instancia,true)
	return {"rid":instancia,"caja":caja,"pose":pose}


func calcular_caja(malla: Mesh, pose: Transform3D) -> AABB:
	var limites: Dictionary = malla.get_meta("limites_hierba")
	var radio := float(limites.radio)
	var raices := pose * AABB(Vector3(-radio,-0.08,-radio),Vector3(radio*2,0,radio*2))
	var rango := _rango_alturas(Rect2(raices.position.x,raices.position.z,raices.size.x,raices.size.z))
	# Incluir también las raíces sin adaptar cubre regiones ausentes y los
	# triángulos colapsados por el fundido. Los picos interiores no se promedian.
	var minima := minf(rango.x-0.025,raices.position.y)
	var maxima := maxf(rango.y-0.025,raices.end.y)
	var lateral := maxf(float(limites.anchura)*0.5,float(limites.altura)*0.34)*float(limites.ancho_maximo)
	var desplazamientos := Transform3D(pose.basis,Vector3.ZERO) * AABB(Vector3(-lateral,-DESCENSO_MAXIMO,-lateral),Vector3(lateral*2,float(limites.altura)+DESCENSO_MAXIMO,lateral*2))
	# 0,24 + 1,25·1,46 + 0,52 + 0,52 + 1,15 = 4,255 m: brisa, racha,
	# tormenta, pisada y onda simultáneas. Cinco metros conservan un margen.
	var caja_mundo := AABB(
		Vector3(raices.position.x,minima,raices.position.z)+desplazamientos.position-Vector3(MARGEN_VIENTO,0.05,MARGEN_VIENTO),
		Vector3(raices.size.x,maxima-minima,raices.size.z)+desplazamientos.size+Vector3(MARGEN_VIENTO*2,0.1,MARGEN_VIENTO*2)
	)
	return pose.affine_inverse() * caja_mundo


func _rango_alturas(rectangulo: Rect2) -> Vector2:
	if _terreno == null or _terreno.data == null: return Vector2(INF,-INF)
	var paso := _terreno.vertex_spacing
	var inicio := Vector2i(floori(rectangulo.position.x/paso)-1,floori(rectangulo.position.y/paso)-1)
	var fin := Vector2i(ceili(rectangulo.end.x/paso)+1,ceili(rectangulo.end.y/paso)+1)
	var pixeles := Rect2i(inicio,fin-inicio+Vector2i.ONE)
	if _alturas.has(pixeles):
		_aciertos_alturas += 1
		return _alturas[pixeles]
	var tamano := _terreno.region_size
	var primera := Vector2i(floori(float(inicio.x)/tamano),floori(float(inicio.y)/tamano))
	var ultima := Vector2i(floori(float(fin.x)/tamano),floori(float(fin.y)/tamano))
	var resultado := Vector2(INF,-INF)
	for z in range(primera.y,ultima.y+1):
		for x in range(primera.x,ultima.x+1):
			var region := _terreno.data.get_region(Vector2i(x,z))
			if region == null or region.deleted: continue
			var imagen := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
			if imagen == null or imagen.is_empty(): continue
			var origen := Vector2i(x,z)*tamano
			var corte := pixeles.intersection(Rect2i(origen,Vector2i.ONE*tamano))
			corte.position -= origen
			var muestra := imagen.get_region(corte)
			if muestra.get_format() != Image.FORMAT_RF: muestra.convert(Image.FORMAT_RF)
			var alturas := Array(muestra.get_data().to_float32_array())
			resultado.x = minf(resultado.x,alturas.min())
			resultado.y = maxf(resultado.y,alturas.max())
	_consultas_alturas += 1
	if _alturas.size() == LIMITE_CACHE:
		_alturas.erase(_claves_alturas[_turno_alturas])
		_claves_alturas[_turno_alturas] = pixeles
		_turno_alturas = (_turno_alturas+1)%LIMITE_CACHE
	else: _claves_alturas.append(pixeles)
	_alturas[pixeles] = resultado
	return resultado


func _invalidar_alturas() -> void:
	_alturas.clear()
	_claves_alturas.clear()
	_turno_alturas = 0
	for datos in _campos.values():
		var malla := datos.malla as Mesh
		for entradas in datos.instancias.values():
			for entrada in entradas:
				var caja := calcular_caja(malla,entrada.pose)
				entrada.caja = caja
				RenderingServer.instance_set_custom_aabb(entrada.rid,caja)


func _devolver(malla: Mesh, entrada: Dictionary) -> void:
	RenderingServer.instance_set_visible(entrada.rid,false)
	var clave := malla.get_instance_id()
	var banco: Array = _bancos.get(clave,[])
	banco.append(entrada.rid)
	_bancos[clave] = banco


func _retirar(datos: Dictionary) -> void:
	for entradas in datos.instancias.values():
		for entrada in entradas: _devolver(datos.malla,entrada)
	datos.instancias = {}


func _desregistrar(id: int) -> void:
	if not _campos.has(id): return
	var datos: Dictionary = _campos[id]
	_retirar(datos)
	var campo := datos.nodo as MultiMeshInstance3D
	if is_instance_valid(campo):
		if (datos.sincronizar_fuente as Callable).is_valid(): datos.sincronizar_fuente.call(campo,datos.poses)
		campo.layers = int(datos.capas)
		campo.visibility_changed.disconnect(_sincronizar_visibilidad.bind(id))
		campo.tree_exiting.disconnect(_desregistrar.bind(id))
	_campos.erase(id)


func estadisticas() -> Dictionary:
	var instancias := 0
	var reserva := 0
	for datos in _campos.values():
		for entradas in datos.instancias.values(): instancias += entradas.size()
	for banco in _bancos.values(): reserva += banco.size()
	return {"campos":_campos.size(),"instancias":instancias,"reserva":reserva,"creadas":_creadas,"preparaciones_parches":_preparaciones_parches,"cache_alturas":_alturas.size(),"consultas_alturas":_consultas_alturas,"aciertos_alturas":_aciertos_alturas}


func _exit_tree() -> void:
	for id in _campos.keys(): _desregistrar(id)
	for banco in _bancos.values():
		for instancia in banco: RenderingServer.free_rid(instancia)
	_bancos.clear()
	_mallas.clear()
	if is_instance_valid(_terreno) and _terreno.data != null:
		_terreno.data.height_maps_changed.disconnect(_invalidar_alturas)
		_terreno.data.region_map_changed.disconnect(_invalidar_alturas)
