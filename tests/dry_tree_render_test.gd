extends SceneTree

const Gestor = preload("res://scripts/render_arboles_secos.gd")
func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var gestor := Gestor.new()
	mundo.add_child(gestor)
	var caja := BoxMesh.new()
	caja.size = Vector3(2,2,2)
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,caja.surface_get_arrays(0))
	malla.surface_set_material(0,StandardMaterial3D.new())
	var fuente := MultiMeshInstance3D.new()
	fuente.position = Vector3(-1450,20,650)
	fuente.rotation.y = 0.42
	fuente.lod_bias = 0.25
	fuente.visibility_range_end = 760
	fuente.multimesh = MultiMesh.new()
	fuente.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	fuente.multimesh.mesh = malla
	var poses: Array[Transform3D] = []
	for posicion in [Vector3(0,0,0),Vector3(-100,0,0),Vector3(100,0,0),Vector3(0,0,50),Vector3(0,0,-20),Vector3(0,0,-6)]: poses.append(Transform3D(Basis.IDENTITY,posicion))
	fuente.multimesh.instance_count = poses.size()
	var limites := AABB(Vector3(-102,-2,-22),Vector3(204,4,74))
	fuente.multimesh.custom_aabb = limites
	for indice in poses.size(): fuente.multimesh.set_instance_transform(indice,poses[indice])
	mundo.add_child(fuente)
	var camara := Camera3D.new()
	mundo.add_child(camara)
	camara.global_position = fuente.to_global(Vector3(0,3,8))
	camara.look_at(fuente.to_global(Vector3(0,0,0)))
	camara.current = true
	if not gestor.registrar(fuente,poses): fallar("No se registra un grupo estático válido."); return
	gestor.actualizar_camara(camara)
	var datos: Dictionary = gestor.get("_datos")[fuente.get_instance_id()]
	var color := datos.color as MultiMeshInstance3D
	if datos.indices!=PackedInt32Array([0,4,5]): fallar("El descarte por cámara pierde árboles frontales o conserva los laterales y traseros."); return
	if fuente.multimesh.instance_count!=6 or fuente.multimesh.visible_instance_count!=-1 or fuente.multimesh.custom_aabb!=limites: fallar("El descarte altera la fuente que conserva las sombras y los índices de tala."); return
	if fuente.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or color.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: fallar("Se duplican o desaparecen las sombras originales."); return
	if color.multimesh.mesh!=malla or color.multimesh.custom_aabb!=limites or color.lod_bias!=fuente.lod_bias or color.visibility_range_end!=760: fallar("El clon modifica la malla, la caja, el LOD o la distancia del grupo."); return
	if color.global_transform!=fuente.global_transform or color.layers!=fuente.layers: fallar("El clon pierde el ancla, giro o capas de su grupo."); return
	if not matrices_correctas(color,datos,poses): return
	var otra := MultiMeshInstance3D.new()
	otra.multimesh = fuente.multimesh
	if not Gestor.admite(otra,poses.size()): fallar("El control de material válido falla antes de probar sus exclusiones."); return
	var original := malla.surface_get_material(0)
	malla.surface_set_material(0,ShaderMaterial.new())
	if Gestor.admite(otra,poses.size()): fallar("Se acepta un shader que puede desplazar geometría fuera de la caja."); return
	malla.surface_set_material(0,original)
	(original as BaseMaterial3D).grow = true
	if Gestor.admite(otra,poses.size()): fallar("Se acepta grow con una caja calculada antes de desplazar vértices."); return
	(original as BaseMaterial3D).grow = false
	otra.free()
	var subidas := int(gestor.estadisticas().subidas)
	var revisiones := int(gestor.estadisticas().revisiones)
	gestor.actualizar_camara(camara)
	if int(gestor.estadisticas().subidas)!=subidas or int(gestor.estadisticas().revisiones)!=revisiones: fallar("Una cámara quieta recorre y vuelve a subir el grupo."); return
	if not gestor.registrar(fuente,poses) or int(gestor.estadisticas().celdas)!=1: fallar("Registrar dos veces duplica el grupo."); return
	var nueva := Transform3D(Basis(Vector3.UP,0.6),Vector3(2,0,-4))
	fuente.multimesh.set_instance_transform(1,nueva)
	poses[1] = nueva
	gestor.actualizar(fuente,1,nueva)
	if color.is_visible_in_tree() or fuente.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: fallar("Una pose tardía deja color atrasado respecto a la sombra."); return
	gestor.actualizar_camara(camara)
	if datos.indices!=PackedInt32Array([0,1,4,5]): fallar("Mover un árbol no invalida el descarte con cámara quieta."); return
	if not matrices_correctas(color,datos,poses): return
	poses[0] = Transform3D(Basis.from_scale(Vector3.ONE*0.001),Vector3(0,-10000,0))
	fuente.multimesh.set_instance_transform(0,poses[0])
	gestor.actualizar(fuente,0,poses[0])
	gestor.actualizar_camara(camara)
	if datos.indices.has(0): fallar("Una tala conserva la imagen del árbol retirado."); return
	camara.look_at(fuente.to_global(Vector3(0,0,60)))
	gestor.actualizar_camara(camara)
	if not datos.indices.has(3) or datos.indices.has(4): fallar("Girar la cámara conserva el descarte anterior."); return
	var anterior := camara.global_transform
	var subidas_antes := int(gestor.estadisticas().subidas)
	camara.global_position += Vector3.UP*5000
	gestor.actualizar_camara(camara)
	if color.is_visible_in_tree() or int(gestor.estadisticas().subidas)!=subidas_antes: fallar("Fuera de toda la región se siguen preparando o dibujando árboles."); return
	camara.global_transform = anterior
	gestor.actualizar_camara(camara)
	if not color.is_visible_in_tree() or not datos.indices.has(3): fallar("Volver a la misma cámara deja oculta la región descartada."); return
	fuente.hide()
	if color.is_visible_in_tree(): fallar("Un grupo oculto mantiene su copia de color."); return
	fuente.show()
	gestor.actualizar_camara(camara)
	fuente.lod_bias = 0.6
	fuente.visibility_range_end = 680
	gestor.refrescar()
	gestor.actualizar_camara(camara)
	if not is_equal_approx(color.lod_bias,0.6) or color.visibility_range_end!=680: fallar("Los ajustes de detalle y distancia no llegan al clon."); return
	gestor.establecer_activo(false)
	if color.is_visible_in_tree() or fuente.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: fallar("Restaurar la ruta original deja color duplicado o pierde sombras."); return
	gestor.establecer_activo(true)
	gestor.actualizar_camara(camara)
	if fuente.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not color.is_visible_in_tree(): fallar("Reactivar el descarte pierde la fuente de sombras o el color."); return
	mundo.remove_child(fuente)
	if int(gestor.estadisticas().celdas)!=0 or fuente.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: fallar("Retirar el grupo deja un registro huérfano o una fuente modificada."); return
	fuente.free()
	mundo.queue_free()
	await process_frame
	print("DRY TREE RENDER TEST OK: frustum, índices de tala, matrices, sombras, LOD, caja original, caché quieta, visibilidad y restauración.")
	quit()

func matrices_correctas(color: MultiMeshInstance3D, datos: Dictionary, poses: Array[Transform3D]) -> bool:
	if color.multimesh.visible_instance_count!=(datos.indices as PackedInt32Array).size(): fallar("El número de instancias enviado no coincide con el prefijo compacto."); return false
	if DisplayServer.get_name()=="headless": return true
	for indice in datos.indices.size():
		if color.multimesh.get_instance_transform(indice)!=poses[datos.indices[indice]]: fallar("La GPU recibe otra pose o un índice de árbol equivocado."); return false
	return true

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
