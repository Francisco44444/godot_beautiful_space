extends Node3D

## Conserva el MultiMesh completo para sombras y compacta sólo su pase de color.
## La caja del grupo y su LOD permanecen iguales; los índices de tala no cambian.
const MARGEN := 0.05
var activo := true
var _datos: Dictionary = {}
var _sucio := true
var _configuracion_sucia := true
var _camara_id := 0
var _transformacion := Transform3D()
var _proyeccion := Projection()
var _subidas := 0
var _revisiones := 0
var _centros_grupos := AABB()
var _rango_maximo := INF

func _ready() -> void:
	process_priority = 100
	set_process(activo)
	var ajustes := get_node_or_null("/root/GameSettings")
	if ajustes!=null:
		ajustes.lod_distance_changed.connect(func(_valor): refrescar())
		ajustes.resolution_changed.connect(func(_valor): refrescar())

func registrar(fuente: MultiMeshInstance3D, poses: Array[Transform3D]) -> bool:
	var id := fuente.get_instance_id()
	if _datos.has(id): return true
	if not activo or not admite(fuente,poses.size()): return false
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = fuente.multimesh.mesh
	multi.instance_count = poses.size()
	multi.custom_aabb = fuente.multimesh.custom_aabb
	var color := MultiMeshInstance3D.new()
	color.name = "Color_"+String(fuente.name)
	color.multimesh = multi
	color.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	color.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(color)
	var datos := {"fuente":fuente,"color":color,"poses":poses.duplicate(),"matrices":[],"cajas":[],"indices":PackedInt32Array(),"sucio":true,"sombra":fuente.cast_shadow,"base":fuente.global_transform,"visible":fuente.is_visible_in_tree()}
	_datos[id] = datos
	_copiar_configuracion(datos)
	for indice in poses.size():
		multi.set_instance_transform(indice,poses[indice])
		datos.matrices.append(empaquetar(poses[indice]))
		datos.cajas.append(caja_arbol(fuente.global_transform,poses[indice],multi.mesh))
	fuente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	fuente.visibility_changed.connect(_visibilidad.bind(id))
	fuente.tree_exiting.connect(_retirar.bind(id))
	_visibilidad(id)
	refrescar()
	return true

static func admite(fuente: MultiMeshInstance3D, cantidad: int) -> bool:
	var multi := fuente.multimesh
	if multi==null or not multi.mesh is ArrayMesh or multi.instance_count!=cantidad: return false
	if multi.use_colors or multi.use_custom_data or multi.transform_format!=MultiMesh.TRANSFORM_3D: return false
	if multi.visible_instance_count!=-1 and multi.visible_instance_count!=cantidad: return false
	if fuente.material_override!=null or fuente.material_overlay!=null or fuente.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: return false
	for superficie in multi.mesh.get_surface_count():
		var material := multi.mesh.surface_get_material(superficie)
		if not material is BaseMaterial3D or material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.distance_fade_mode!=BaseMaterial3D.DISTANCE_FADE_DISABLED: return false
	return true

static func caja_arbol(base: Transform3D, pose: Transform3D, malla: Mesh) -> AABB:
	return (base*pose)*malla.get_aabb().grow(MARGEN)

static func empaquetar(pose: Transform3D) -> PackedFloat32Array:
	return PackedFloat32Array([pose.basis.x.x,pose.basis.y.x,pose.basis.z.x,pose.origin.x,pose.basis.x.y,pose.basis.y.y,pose.basis.z.y,pose.origin.y,pose.basis.x.z,pose.basis.y.z,pose.basis.z.z,pose.origin.z])

static func intersecta(caja: AABB, planos: Array[Plane]) -> bool:
	var centro := caja.get_center()
	var mitad := caja.size*0.5
	for plano in planos:
		if plano.distance_to(centro)-mitad.dot(plano.normal.abs())>0.02: return false
	return true

func actualizar(fuente: MultiMeshInstance3D, indice: int, pose: Transform3D) -> void:
	var datos: Dictionary = _datos.get(fuente.get_instance_id(),{})
	if datos.is_empty() or indice<0 or indice>=datos.poses.size(): return
	datos.poses[indice] = pose
	datos.matrices[indice] = empaquetar(pose)
	datos.cajas[indice] = caja_arbol(fuente.global_transform,pose,fuente.multimesh.mesh)
	datos.sucio = true
	if datos.base!=fuente.global_transform: _configuracion_sucia = true
	# Los tweens pueden mover el árbol después del _process del gestor. Volver
	# a la fuente ese fotograma evita que color y sombra difieran durante la tala.
	(datos.color as MultiMeshInstance3D).hide()
	fuente.cast_shadow = int(datos.sombra)
	datos.respaldo = true
	refrescar(false)

func refrescar(configuracion: bool = true) -> void:
	_sucio = true
	_configuracion_sucia = _configuracion_sucia or configuracion

func _process(_delta: float) -> void:
	if not activo or _datos.is_empty(): return
	actualizar_camara(get_viewport().get_camera_3d())

func actualizar_camara(camara: Camera3D) -> void:
	if not activo: return
	if _configuracion_sucia:
		var primero := true
		_rango_maximo = 0.0
		for datos in _datos.values():
			_copiar_configuracion(datos)
			var centro: Vector3 = (datos.caja_grupo as AABB).get_center()
			_centros_grupos = AABB(centro,Vector3.ZERO) if primero else _centros_grupos.expand(centro)
			primero = false
			_rango_maximo = INF if float(datos.rango_fin)<=0 else maxf(_rango_maximo,float(datos.rango_fin)+float(datos.margen_fin))
		_configuracion_sucia = false
	if camara!=null and _rango_maximo<INF and camara.global_position.distance_to(camara.global_position.clamp(_centros_grupos.position,_centros_grupos.end))>_rango_maximo+1.0:
		# Fuera de todos los rangos originales basta una prueba del conjunto;
		# no se recorren las 174 celdas tenebrosas al pasear por Puerto Alba.
		hide()
		return
	show()
	var planos: Array[Plane] = []
	if camara!=null:
		var transformacion := camara.get_camera_transform()
		var proyeccion := camara.get_camera_projection()
		if not _sucio and _camara_id==camara.get_instance_id() and _transformacion==transformacion and _proyeccion==proyeccion: return
		_camara_id = camara.get_instance_id()
		_transformacion = transformacion
		_proyeccion = proyeccion
		planos = camara.get_frustum()
		var dentro := camara.project_position(camara.get_viewport().get_visible_rect().size*0.5,maxf(camara.near*2,1.0))
		for indice in planos.size():
			if planos[indice].distance_to(dentro)>0: planos[indice] = Plane(-planos[indice].normal,-planos[indice].d)
	_revisiones += 1
	for datos in _datos.values():
		var fuente := datos.fuente as MultiMeshInstance3D
		var color := datos.color as MultiMeshInstance3D
		if _configuracion_sucia: _copiar_configuracion(datos)
		if not bool(datos.visible): color.hide(); continue
		var caja: AABB = datos.caja_grupo
		# El motor resuelve el rango con el centro de la caja del grupo. El clon
		# conserva esa misma caja; no se inventa un rango por árbol.
		if camara!=null and float(datos.rango_fin)>0 and float(datos.margen_fin)==0 and camara.global_position.distance_to(caja.get_center())>float(datos.rango_fin):
			color.hide()
			continue
		if not planos.is_empty() and not intersecta(caja,planos): color.hide(); continue
		var indices := PackedInt32Array()
		for indice in datos.poses.size():
			if (datos.poses[indice] as Transform3D).basis.get_scale().length()<0.01: continue
			if planos.is_empty() or intersecta(datos.cajas[indice],planos): indices.append(indice)
		if bool(datos.sucio) or indices!=datos.indices:
			var buffer := PackedFloat32Array()
			for indice in indices: buffer.append_array(datos.matrices[indice])
			buffer.resize(datos.poses.size()*12)
			color.multimesh.buffer = buffer
			_subidas += indices.size()
			color.multimesh.visible_instance_count = indices.size()
			datos.indices = indices
			datos.sucio = false
		color.visible = not indices.is_empty()
		if bool(datos.get("respaldo",false)):
			fuente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			datos.respaldo = false
	_sucio = false
	_configuracion_sucia = false

func _copiar_configuracion(datos: Dictionary) -> void:
	var fuente := datos.fuente as MultiMeshInstance3D
	var color := datos.color as MultiMeshInstance3D
	if datos.base!=fuente.global_transform:
		datos.base = fuente.global_transform
		for indice in datos.poses.size(): datos.cajas[indice] = caja_arbol(datos.base,datos.poses[indice],fuente.multimesh.mesh)
		datos.sucio = true
	color.global_transform = fuente.global_transform
	color.layers = fuente.layers
	color.lod_bias = fuente.lod_bias
	color.multimesh.custom_aabb = fuente.multimesh.custom_aabb
	color.extra_cull_margin = fuente.extra_cull_margin
	color.visibility_range_begin = fuente.visibility_range_begin
	color.visibility_range_end = fuente.visibility_range_end
	color.visibility_range_begin_margin = fuente.visibility_range_begin_margin
	color.visibility_range_end_margin = fuente.visibility_range_end_margin
	color.visibility_range_fade_mode = fuente.visibility_range_fade_mode
	datos.caja_grupo = fuente.global_transform*fuente.multimesh.custom_aabb
	datos.rango_fin = fuente.visibility_range_end
	datos.margen_fin = fuente.visibility_range_end_margin

func _visibilidad(id: int) -> void:
	if not _datos.has(id): return
	var datos: Dictionary = _datos[id]
	datos.visible = (datos.fuente as MultiMeshInstance3D).is_visible_in_tree()
	(datos.color as MultiMeshInstance3D).visible = activo and bool(datos.visible)
	refrescar(false)

func establecer_activo(valor: bool) -> void:
	if activo==valor: return
	activo = valor
	for datos in _datos.values():
		var fuente := datos.fuente as MultiMeshInstance3D
		var color := datos.color as MultiMeshInstance3D
		if not valor: color.hide(); fuente.cast_shadow = int(datos.sombra)
		else:
			for indice in datos.poses.size(): color.multimesh.set_instance_transform(indice,datos.poses[indice])
			color.multimesh.visible_instance_count = datos.poses.size()
			datos.sucio = true
			fuente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			color.visible = fuente.is_visible_in_tree()
	refrescar()
	set_process(valor)

func _retirar(id: int) -> void:
	if not _datos.has(id): return
	var datos: Dictionary = _datos[id]
	(datos.color as MultiMeshInstance3D).hide()
	(datos.color as MultiMeshInstance3D).queue_free()
	if is_instance_valid(datos.fuente): datos.fuente.cast_shadow = int(datos.sombra)
	_datos.erase(id)
	refrescar()

func _exit_tree() -> void:
	for id in _datos.keys(): _retirar(id)

func estadisticas() -> Dictionary:
	var arboles := 0
	var visibles := 0
	for datos in _datos.values():
		arboles += datos.poses.size()
		if (datos.color as MultiMeshInstance3D).is_visible_in_tree(): visibles += (datos.indices as PackedInt32Array).size()
	return {"celdas":_datos.size(),"arboles":arboles,"visibles":visibles,"subidas":_subidas,"revisiones":_revisiones}
