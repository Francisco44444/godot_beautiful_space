extends SceneTree

const RenderBosque = preload("res://scripts/render_bosque.gd")

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = 190811
	for muestra in 3000:
		var caja := AABB(Vector3(-170,-10,-170),Vector3(340,80,340))
		var centro := Vector3(azar.randf_range(-140,140),0,azar.randf_range(-140,140))
		var arbol := AABB(centro-Vector3(8,0,8),Vector3(16,35,16))
		var camara := Vector3(azar.randf_range(-650,650),azar.randf_range(1,100),azar.randf_range(-650,650))
		var movimiento := Vector3(azar.randf_range(-1,1),azar.randf_range(-1,1),azar.randf_range(-1,1)).normalized()*azar.randf_range(0,RenderBosque.MARGEN_CAMARA)
		var escala_celda := azar.randf_range(0.5,2.0)
		var escala_arbol := azar.randf_range(1,6)
		var bias := RenderBosque.compensar_lod(0.25,escala_celda,escala_arbol,RenderBosque.distancia_caja(camara,caja),RenderBosque.distancia_caja(camara,arbol))
		if "--break-render-lod" in OS.get_cmdline_user_args(): bias = 0.25
		var distancia_celda := RenderBosque.distancia_caja(camara+movimiento,caja)
		var distancia_arbol := RenderBosque.distancia_caja(camara+movimiento,arbol)
		if distancia_celda<=0.0:
			if bias!=RenderBosque.DETALLE_COMPLETO: fallar("Se reduce detalle cuando la cámara está dentro de la celda."); return
		elif distancia_arbol>0.0:
			# El cociente escala*bias/distancia controla la selección del motor.
			# El nuevo no puede permitir un error mayor, tampoco entre revisiones.
			var anterior := escala_celda*0.25/distancia_celda
			var nuevo := escala_arbol*bias/distancia_arbol
			if nuevo+0.0000001<anterior: fallar("La compensación permite menos detalle que el MultiMesh original."); return
		var ortogonal := RenderBosque.compensar_lod(0.25,escala_celda,escala_arbol,100,500,true)
		if absf(ortogonal*escala_arbol-0.25*escala_celda)>0.000001: fallar("La cámara ortogonal cambia la escala de LOD."); return

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
	celda.position = Vector3(-340,10,680)
	mundo.add_child(celda)
	gestor.registrar(celda,poses)
	var sin_sombra := MultiMeshInstance3D.new()
	sin_sombra.multimesh = multi
	sin_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(sin_sombra)
	gestor.registrar(sin_sombra,poses)
	if gestor.estadisticas().celdas!=1 or sin_sombra.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: fallar("Se habilitan sombras que estaban desactivadas."); return
	gestor.iniciar()
	if gestor.estadisticas().instancias!=2 or celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: fallar("No se separan color y sombras originales."); return
	var creadas := int(gestor.estadisticas().creadas)
	for paso in 20:
		mundo.visible = false
		if gestor.estadisticas().instancias!=0: fallar("El bosque oculto sigue representando árboles individuales."); return
		mundo.visible = true
		if gestor.estadisticas().instancias!=2 or int(gestor.estadisticas().creadas)!=creadas: fallar("Cambiar de LOD acumula instancias en lugar de reutilizarlas."); return
	var nueva := Transform3D(Basis(Vector3.RIGHT,1.1).scaled(Vector3.ONE*3),Vector3(45,0,-15))
	gestor.actualizar(celda,1,nueva)
	var datos: Dictionary = gestor.get("_celdas")[celda.get_instance_id()]
	var caja_nueva: AABB = datos.cajas[1]
	var esperada := celda.global_transform*nueva
	if not caja_nueva.get_center().is_equal_approx(esperada.origin): fallar("La tala mueve otro ejemplar o pierde el ancla de la celda."); return
	if not (datos.cajas[0] as AABB).get_center().is_equal_approx(celda.to_global(poses[0].origin)): fallar("Mover un árbol desplaza a su vecino."); return
	gestor.establecer_activo(false)
	if gestor.estadisticas().instancias!=0 or celda.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON: fallar("El control anterior deja color duplicado o sombras modificadas."); return
	gestor.establecer_activo(true)
	if int(gestor.estadisticas().creadas)!=creadas: fallar("Reactivar el render pierde la reserva."); return
	var camara := Camera3D.new()
	camara.position = Vector3(-900,90,800)
	mundo.add_child(camara)
	camara.current = true
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
	mundo.queue_free()
	await process_frame
	print("FOREST RENDER TEST OK: 3000 cotas de detalle, proyección ortogonal, sombras conservadas, reserva y tala por índice.")
	quit()

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
