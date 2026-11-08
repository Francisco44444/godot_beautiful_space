extends SceneTree

class DispersorMedido extends VegetationScatter:
	var escrituras := 0
	func _ready() -> void: set_process(false)
	func _set_lod_instances_visible(instances: Array, mostrar: bool) -> void:
		escrituras += 1
		super._set_lod_instances_visible(instances,mostrar)

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var dispersor := DispersorMedido.new()
	dispersor.terrain_path=NodePath(".")
	root.add_child(dispersor)
	var camara := Camera3D.new()
	dispersor.add_child(camara)
	camara.current=true
	camara.position=Vector3(10,5,100)
	var completo := celda(dispersor)
	var lejano := celda(dispersor)
	var hierba := celda(dispersor)
	dispersor._register_lod_instance(dispersor._tree_full_cells,Vector2i.ZERO,completo)
	dispersor._register_lod_instance(dispersor._tree_proxy_cells,Vector2i.ZERO,lejano)
	dispersor._register_lod_instance(dispersor._grass_proxy_cells,Vector2i.ZERO,hierba)
	dispersor._update_explicit_lod_visibility(false)
	if not completo.visible or lejano.visible or not hierba.visible: fallar("La primera actualización no presenta el árbol completo y la hierba."); return
	var escrituras := dispersor.escrituras
	var cuenta_completos := dispersor.explicit_lod_visible_full_cells
	var cuenta_proxies := dispersor.explicit_lod_visible_proxy_cells
	for intento in 100: dispersor._update_explicit_lod_visibility(false)
	if dispersor.escrituras!=escrituras or dispersor.explicit_lod_visible_full_cells!=cuenta_completos or dispersor.explicit_lod_visible_proxy_cells!=cuenta_proxies: fallar("La cámara quieta repite el recorrido o pierde los contadores visibles."); return
	camara.position.y+=80.0
	dispersor._update_explicit_lod_visibility(false)
	if dispersor.escrituras!=escrituras: fallar("La altura de cámara repite un corte que depende sólo de XZ."); return
	dispersor._update_explicit_lod_visibility(true)
	if dispersor.escrituras<=escrituras: fallar("La actualización forzada no renueva las celdas con la cámara quieta."); return
	escrituras=dispersor.escrituras
	camara.position=Vector3(550,5,0)
	dispersor._update_explicit_lod_visibility(false)
	if dispersor.escrituras<=escrituras or not completo.visible or lejano.visible: fallar("Mover la cámara no renueva el corte conservando su histéresis."); return
	dispersor.set_lod_switch_distance(180)
	if completo.visible or not lejano.visible: fallar("Cambiar el ajuste LOD no se aplica con la cámara quieta."); return
	dispersor.lod_switch_distance=400
	dispersor._update_explicit_lod_visibility(false)
	if not completo.visible or lejano.visible: fallar("Editar la distancia exportada no invalida la revisión anterior."); return
	var nueva := celda(dispersor)
	dispersor._register_lod_instance(dispersor._grass_proxy_cells,Vector2i(20,20),nueva)
	dispersor._update_explicit_lod_visibility(false)
	if nueva.visible: fallar("Una celda registrada tarde no invalida el foco anterior."); return
	var objetivo := Node3D.new()
	dispersor.add_child(objetivo)
	objetivo.position=Vector3(10,0,100)
	dispersor._grass_interaction_target=objetivo
	camara.free()
	dispersor._update_explicit_lod_visibility(false)
	if not completo.visible or lejano.visible: fallar("Sin cámara no se utiliza el objetivo de interacción."); return
	dispersor.queue_free()
	await process_frame
	print("LOD ACTIVITY TEST OK: 100 revisiones quietas sin recorridos, altura, movimiento, forzado, ajuste, alta tardía y foco sin cámara.")
	quit()

func celda(padre: Node) -> MultiMeshInstance3D:
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh=MultiMesh.new()
	nodo.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	nodo.multimesh.mesh=BoxMesh.new()
	nodo.multimesh.instance_count=1
	padre.add_child(nodo)
	return nodo

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
