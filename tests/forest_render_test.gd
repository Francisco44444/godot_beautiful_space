extends SceneTree

const RenderBosque = preload("res://scripts/render_bosque.gd")

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = 190811
	var limitados := 0
	for muestra in 3000:
		var caja := AABB(Vector3(-170,-10,-170),Vector3(340,80,340))
		var centro := Vector3(azar.randf_range(-140,140),0,azar.randf_range(-140,140))
		var arbol := AABB(centro-Vector3(8,0,8),Vector3(16,35,16))
		var camara := Vector3(azar.randf_range(-650,650),azar.randf_range(1,100),azar.randf_range(-650,650))
		var movimiento := Vector3(azar.randf_range(-1,1),azar.randf_range(-1,1),azar.randf_range(-1,1)).normalized()*azar.randf_range(0,RenderBosque.MARGEN_CAMARA)
		var escala_celda := azar.randf_range(0.5,2.0)
		var escala_arbol := azar.randf_range(1,6)
		var bias := RenderBosque.compensar_lod(0.25,escala_celda,escala_arbol,RenderBosque.distancia_caja(camara,caja),RenderBosque.distancia_caja(camara,arbol))
		var referencia := RenderBosque.compensar_lod(0.25,escala_celda,escala_arbol,RenderBosque.distancia_caja(camara,caja),RenderBosque.distancia_caja(camara,arbol),false,false)
		if "--break-render-lod" in OS.get_cmdline_user_args(): bias = 0.25
		if bias>1.000001 or bias>referencia+0.0000001: fallar("Se impide el LOD individual o se aumenta el detalle que ya tenía el grupo."); return
		if bias<referencia: limitados += 1
		var distancia_celda := RenderBosque.distancia_caja(camara+movimiento,caja)
		var distancia_arbol := RenderBosque.distancia_caja(camara+movimiento,arbol)
		if distancia_celda<=0.0:
			if referencia!=RenderBosque.DETALLE_COMPLETO or bias!=1.0: fallar("La celda cercana no conserva el presupuesto de detalle individual."); return
		elif distancia_arbol>0.0:
			# El cociente escala*bias/distancia controla la selección del motor.
			# Se conserva la referencia del grupo hasta el presupuesto automático
			# individual; la cota sigue cumpliéndose al moverse entre revisiones.
			var anterior := escala_celda*0.25/distancia_celda
			var nuevo := escala_arbol*bias/distancia_arbol
			var presupuesto := escala_arbol/distancia_arbol
			if nuevo+0.0000001<minf(anterior,presupuesto): fallar("Se supera el error de pantalla individual y el del grupo."); return
		var ortogonal := RenderBosque.compensar_lod(0.25,escala_celda,escala_arbol,100,500,true)
		if absf(ortogonal*escala_arbol-0.25*escala_celda)>0.000001: fallar("La cámara ortogonal cambia la escala de LOD."); return
	if limitados==0: fallar("Las muestras no ejercitan ningún árbol con detalle limitado."); return
	if RenderBosque.compensar_lod(4.0,2.0,0.5,100,500,true)!=1.0: fallar("La proyección ortogonal ignora el límite de detalle individual."); return

	var mundo := Node3D.new()
	root.add_child(mundo)
	var gestor := RenderBosque.new()
	mundo.add_child(gestor)
	var celda := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = 2
	var poses: Array[Transform3D] = [Transform3D(Basis.IDENTITY,Vector3(-12,0,0)),Transform3D(Basis(Vector3.UP,0.8).scaled(Vector3.ONE*3),Vector3(30,0,-15))]
	multi.custom_aabb = AABB(Vector3(-20,-5,-30),Vector3(70,50,45))
	celda.multimesh = multi
	celda.layers = 5
	celda.position = Vector3(-340,10,680)
	mundo.add_child(celda)
	gestor.registrar(celda,poses)
	var sin_sombra := MultiMeshInstance3D.new()
	sin_sombra.multimesh = multi
	sin_sombra.layers = 8
	sin_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(sin_sombra)
	gestor.registrar(sin_sombra,poses)
	if gestor.estadisticas().celdas!=1 or sin_sombra.layers!=8 or sin_sombra.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: fallar("Se cambian capas o sombras que estaban desactivadas."); return
	gestor.iniciar()
	if gestor.estadisticas().instancias!=2 or celda.layers!=0 or celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: fallar("La fuente duplica las sombras de los árboles individuales."); return
	var creadas := int(gestor.estadisticas().creadas)
	gestor.establecer_sombras_individuales(false)
	if celda.layers!=5 or celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or gestor.estadisticas().instancias!=2: fallar("El control de sombras pierde el color o sus capas originales."); return
	gestor.establecer_sombras_individuales(true)
	if celda.layers!=0 or gestor.estadisticas().instancias!=2 or int(gestor.estadisticas().creadas)!=creadas: fallar("Cambiar las sombras reconstruye o duplica los árboles."); return
	for paso in 20:
		mundo.visible = false
		if gestor.estadisticas().instancias!=0: fallar("El bosque oculto sigue representando árboles individuales."); return
		mundo.visible = true
		if gestor.estadisticas().instancias!=2 or int(gestor.estadisticas().creadas)!=creadas: fallar("Cambiar de LOD acumula instancias en lugar de reutilizarlas."); return
	var nueva := Transform3D(Basis(Vector3.RIGHT,1.1).scaled(Vector3.ONE*3),Vector3(45,0,-15))
	gestor.actualizar(celda,1,nueva)
	var datos: Dictionary = gestor.get("_celdas")[celda.get_instance_id()]
	if int(datos.capas)!=5 or int(datos.sombra)!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: fallar("El árbol individual pierde las capas o las sombras originales."); return
	var caja_nueva: AABB = datos.cajas[1]
	var esperada := celda.global_transform*nueva
	if not caja_nueva.get_center().is_equal_approx(esperada.origin): fallar("La tala mueve otro ejemplar o pierde el ancla de la celda."); return
	if not (datos.cajas[0] as AABB).get_center().is_equal_approx(celda.to_global(poses[0].origin)): fallar("Mover un árbol desplaza a su vecino."); return
	gestor.establecer_activo(false)
	if gestor.estadisticas().instancias!=0 or celda.layers!=5 or celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: fallar("El control anterior deja color duplicado o pierde capas y sombras."); return
	gestor.establecer_activo(true)
	if celda.layers!=0: fallar("Reactivar el render deja las sombras dibujadas dos veces."); return
	if int(gestor.estadisticas().creadas)!=creadas: fallar("Reactivar el render pierde la reserva."); return
	var camara := Camera3D.new()
	camara.position = Vector3(-900,90,800)
	mundo.add_child(camara)
	camara.current = true
	camara.global_position = celda.to_global(Vector3(0,10,0))
	gestor.establecer_lod_individual(false)
	gestor.actualizar_detalle(camara)
	if float(datos.bias[1])!=RenderBosque.DETALLE_COMPLETO: fallar("El control anterior ya no permite comparar el detalle original."); return
	gestor.establecer_lod_individual(true)
	gestor.actualizar_detalle(camara)
	if float(datos.bias[1])!=1.0 or celda.layers!=0 or int(gestor.estadisticas().creadas)!=creadas: fallar("Cambiar detalle duplica árboles, reconstruye instancias o conserva el exceso anterior."); return
	var umbral_original := root.mesh_lod_threshold
	root.mesh_lod_threshold = 1.9
	gestor._process(1.0/60.0)
	if absf(float(datos.bias[1])-1.9)>0.000001: fallar("Cambiar calidad con cámara quieta conserva un límite de error antiguo."); return
	root.mesh_lod_threshold = 0.38
	gestor._process(1.0/60.0)
	if float(datos.bias[1])!=1.0: fallar("El nivel de calidad alto pierde su presupuesto individual."); return
	root.mesh_lod_threshold = umbral_original
	camara.global_position = Vector3(-900,90,800)
	gestor.actualizar_detalle(camara)
	gestor.actualizar(celda,1,Transform3D(nueva.basis,nueva.origin+Vector3.RIGHT))
	gestor._process(1.0/60.0)
	if bool(datos.sucio) or float(datos.bias[1])==RenderBosque.DETALLE_COMPLETO: fallar("La tala no actualiza el detalle con la cámara quieta."); return
	for indice in 25:
		var otra := MultiMeshInstance3D.new()
		otra.multimesh = MultiMesh.new()
		otra.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		otra.multimesh.mesh = multi.mesh
		otra.multimesh.instance_count = 1
		otra.multimesh.custom_aabb = multi.custom_aabb
		otra.position = Vector3(indice*30,0,0)
		mundo.add_child(otra)
		gestor.registrar(otra,[Transform3D.IDENTITY])
	gestor.actualizar_detalle(camara)
	camara.position += Vector3(25,0,0)
	gestor._process(1.0/60.0)
	for registro in (gestor.get("_visibles") as Dictionary).values():
		if registro.camara!=camara.global_position: fallar("Un salto de cámara espera al turno y deja LOD sin compensar."); return
	mundo.remove_child(celda)
	if celda.layers!=5 or celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON or (gestor.get("_celdas") as Dictionary).has(celda.get_instance_id()): fallar("Retirar una celda pierde sus capas o deja instancias registradas."); return
	var cantidad_creada := int(gestor.estadisticas().creadas)
	mundo.add_child(celda)
	gestor.registrar(celda,poses)
	if celda.layers!=0 or int(gestor.estadisticas().creadas)!=cantidad_creada: fallar("Registrar de nuevo la celda pierde la reserva o sus capas."); return
	mundo.remove_child(celda)
	celda.free()
	mundo.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless":
		if not await comprobar_lod_real(): return
	print("FOREST RENDER TEST OK: 3000 cotas de error, detalle individual, proyección ortogonal, sombras, capas, reserva y tala por índice.")
	quit()


func comprobar_lod_real() -> bool:
	var visor := SubViewport.new()
	visor.size = Vector2i(128,128)
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visor.mesh_lod_threshold = 1.0
	root.add_child(visor)
	var escena := Node3D.new()
	visor.add_child(escena)
	var camara := Camera3D.new()
	camara.far = 500
	escena.add_child(camara)
	camara.current = true
	var caja := BoxMesh.new()
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,caja.surface_get_arrays(0),[],{0.001:PackedInt32Array([0,1,2])})
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.surface_set_material(0,material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = malla
	multi.instance_count = 1
	multi.custom_aabb = AABB(Vector3(-200,-10,-200),Vector3(400,20,400))
	var celda := MultiMeshInstance3D.new()
	celda.multimesh = multi
	escena.add_child(celda)
	var gestor := RenderBosque.new()
	escena.add_child(gestor)
	gestor.registrar(celda,[Transform3D.IDENTITY])
	gestor.iniciar()
	for caso in [{"z":0.0,"individual":true,"triangulos":12},{"z":-100.0,"individual":true,"triangulos":1},{"z":-100.0,"individual":false,"triangulos":12},{"z":-100.0,"individual":true,"triangulos":1}]:
		var pose := Transform3D(Basis.IDENTITY,Vector3(0,0,caso.z))
		multi.set_instance_transform(0,pose)
		gestor.actualizar(celda,0,pose)
		gestor.establecer_lod_individual(caso.individual)
		gestor.actualizar_detalle(camara)
		for fotograma in 5:
			await process_frame
			RenderingServer.force_draw(false)
		var triangulos := visor.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		if triangulos!=caso.triangulos: fallar("La GPU no selecciona el LOD esperado: %d frente a %d."%[triangulos,caso.triangulos]); return false
	visor.queue_free()
	await process_frame
	print("FOREST GPU LOD OK: malla completa cercana, simplificación lejana y control original de doce triángulos.")
	return true

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
