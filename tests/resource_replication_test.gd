extends SceneTree

var mundo: Node3D
var vegetacion: Node
var aventura: Node
var sesion: Node
var cambios_colision := [0]
var estado: Dictionary

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for singleton in ["InventoryManager","ExplorationManager"]: root.get_node(singleton).set("autosave_enabled",false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for fotograma in 8: await process_frame
	paused = false
	sesion = root.get_node("NetworkSession")
	sesion.set_physics_process(false)
	mundo.get_node("Player").set_physics_process(false)
	vegetacion = mundo.get_node("VegetationScatter")
	aventura = mundo.get_node("AdventureSystem")
	estado = mundo.get_network_world_state()
	sesion.session_mode = sesion.SessionMode.CLIENT
	var indices: Array[int] = []
	for indice in vegetacion.get("_harvest_tree_ids").size():
		if not vegetacion.get("_story_tree_exclusions").has(vegetacion.get("_harvest_tree_ids")[indice]): indices.append(indice)
		if indices.size()==3: break
	if indices.size()!=3: fallar("No hay árboles reales para comprobar daño y dos cambios independientes."); return
	var intacto := indices[0]
	var arbol := -1
	for id in vegetacion.get("_tree_collision_resource_ids"):
		if vegetacion.get("_harvest_tree_index_by_id").has(id) and not vegetacion.get("_story_tree_exclusions").has(id):
			var candidato := int(vegetacion.get("_harvest_tree_index_by_id")[id])
			if candidato!=intacto: arbol = candidato; break
	if arbol<0: fallar("No se ejercita ningún tronco de la colisión unificada."); return
	var id_arbol: String = vegetacion.get("_harvest_tree_ids")[arbol]
	var id_scatter: String = vegetacion.get("_breakable_resources").keys()[0]
	var scatter: AdventureResource = vegetacion.get("_breakable_resources")[id_scatter]
	var arbol_mision: AdventureResource
	var otro_recurso: AdventureResource
	for recurso in aventura.get("_resources_by_id").values():
		if recurso.kind=="tree" and arbol_mision==null: arbol_mision = recurso
		elif recurso.kind=="rock" and otro_recurso==null: otro_recurso = recurso
	if arbol_mision==null or otro_recurso==null: fallar("Faltan recursos de misión reales."); return
	var forma: ConcavePolygonShape3D = vegetacion.get("_forest_collision_shape")
	if forma==null: fallar("No existe la colisión del bosque que se reconstruía por recepción."); return
	var calibracion := [0]
	var referencia := ConcavePolygonShape3D.new()
	referencia.changed.connect(func(): calibracion[0]+=1)
	referencia.set_faces(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]))
	if calibracion[0]<=0: fallar("La API nativa no notifica cambios de colisión."); return
	var caras_antes := forma.get_faces().size()
	var caras_retiradas := 0
	for id in vegetacion.get("_tree_collision_resource_ids"):
		if id in [id_arbol,id_scatter]: caras_retiradas += 36
	forma.changed.connect(func(): cambios_colision[0]+=1)
	vegetacion.get("_harvest_tree_health")[intacto] = 2
	vegetacion.call("_animate_harvest_tree_hit",intacto,false)
	var golpe: Tween = vegetacion.get("_tree_hit_tweens")[intacto]
	scatter.health = 2
	arbol_mision.health = 2
	var pose_mision := arbol_mision.transform.rotated(Vector3.FORWARD,0.04)
	arbol_mision.transform = pose_mision
	for repeticion in 20: recibir()
	if not vegetacion.get("_harvest_tree_health").has(intacto) or not golpe.is_valid(): fallar("Repetir un estado borra el daño parcial o cancela su animación."); return
	if scatter.health!=2 or arbol_mision.health!=2 or arbol_mision.transform!=pose_mision: fallar("Una repetición restaura recursos sin cambios."); return
	if cambios_colision[0]!=0: fallar("Un estado sin cambios vuelve a construir la colisión del bosque."); return
	# Se reutiliza y modifica la misma estructura: guardar referencias al paquete
	# como si fueran una copia no debe ocultar los cambios siguientes.
	estado.vegetation_resources.destroyed_resource_ids = [id_arbol,id_scatter]
	estado.adventure_resources.destroyed_resource_ids = [otro_recurso.zone_id]
	recibir()
	if not vegetacion.get("_harvest_stumps").has(id_arbol) or not scatter.broken or not otro_recurso.broken: fallar("El cambio no alcanza los tres recursos destinatarios."); return
	if cambios_colision[0]!=calibracion[0] or forma.get_faces().size()!=caras_antes-caras_retiradas: fallar("El lote no retira las caras de los troncos ni actualiza una sola vez la colisión."); return
	if vegetacion.get("_harvest_tree_health").get(intacto)!=2 or arbol_mision.health!=2: fallar("Cambiar otros recursos borra el daño del que sigue intacto."); return
	var pose_oculta := pose_arbol(arbol)
	var scatter_oculto := pose_scatter(scatter)
	var tocon: Node = vegetacion.get("_harvest_stumps")[id_arbol]
	for repeticion in 20:
		estado.vegetation_resources.destroyed_resource_ids = [id_scatter,id_arbol,id_arbol,"id_desconocido"]
		recibir()
	if cambios_colision[0]!=calibracion[0] or vegetacion.get("_harvest_stumps")[id_arbol]!=tocon: fallar("Duplicados, otro orden o un id desconocido repiten colisiones o tocones."); return
	if DisplayServer.get_name()!="headless" and (pose_arbol(arbol)!=pose_oculta or pose_scatter(scatter)!=scatter_oculto): fallar("Repetir un recurso hunde otra vez su malla o cambia su pose."); return
	estado.vegetation_resources.destroyed_resource_ids = []
	estado.adventure_resources.destroyed_resource_ids = []
	recibir()
	for fotograma in 2: await process_frame
	if cambios_colision[0]!=2*calibracion[0] or forma.get_faces().size()!=caras_antes or vegetacion.get("_harvest_stumps").has(id_arbol) or scatter.broken or otro_recurso.broken: fallar("Restaurar no recupera recursos, tocón y colisión."); return
	if scatter.health!=3 or otro_recurso.health!=3: fallar("Un recurso restaurado conserva salud de una rotura anterior."); return
	if DisplayServer.get_name()!="headless":
		var original: Transform3D = vegetacion.get("_harvest_tree_full_originals")[arbol]
		if pose_arbol(arbol)!=original or pose_scatter(scatter)!=scatter.get_meta("multimesh_original_transform"): fallar("La restauración no sube las matrices originales a la GPU."); return
	# Una confirmación idéntica a la predicción local mantiene la caída que ya
	# está en curso. La otra tala del lote no puede cancelarla tampoco.
	vegetacion.get("_destroyed_resource_ids")[id_arbol] = true
	var caida := vegetacion.create_tween()
	caida.tween_interval(10.0)
	vegetacion.get("_tree_hit_tweens")[arbol] = caida
	estado.vegetation_resources.destroyed_resource_ids = [id_arbol,id_scatter]
	recibir()
	if not caida.is_valid(): fallar("Confirmar una tala corta su animación ya iniciada."); return
	# Una corrección autoritativa cancela sólo esa caída, antes de su callback.
	estado.vegetation_resources.destroyed_resource_ids = []
	recibir()
	if caida.is_valid(): fallar("Restaurar un árbol deja una caída pendiente."); return
	sesion.session_mode = sesion.SessionMode.OFFLINE
	arbol_mision.broken = true
	arbol_mision.health = 0
	aventura.break_resource(arbol_mision,mundo.get_node("Player"))
	var rotura: Tween = aventura.get("_roturas_recursos")[arbol_mision.zone_id]
	var botin := int(aventura.get("generated_pickup_count"))
	sesion.session_mode = sesion.SessionMode.CLIENT
	recibir()
	await create_timer(0.85).timeout
	if rotura.is_valid() or arbol_mision.broken or not arbol_mision.visible or arbol_mision.health!=3 or int(aventura.get("generated_pickup_count"))!=botin: fallar("Una rotura corregida termina después y oculta el árbol o crea botín."); return
	# Cargar una partida sigue siendo una restauración completa, incluso cuando
	# sus ids son iguales: debe borrar el daño parcial y las animaciones locales.
	vegetacion.get("_harvest_tree_health")[intacto] = 1
	vegetacion.call("_animate_harvest_tree_hit",intacto,false)
	golpe = vegetacion.get("_tree_hit_tweens")[intacto]
	arbol_mision.health = 1
	mundo.apply_shared_world_save_state(mundo.get_shared_world_save_state())
	if not vegetacion.get("_harvest_tree_health").is_empty() or golpe.is_valid() or arbol_mision.health!=3: fallar("Cargar partida ha perdido la restauración completa."); return
	sesion.session_mode = sesion.SessionMode.OFFLINE
	estado.vegetation_resources.destroyed_resource_ids = [id_arbol]
	recibir()
	if vegetacion.get("_destroyed_resource_ids").has(id_arbol): fallar("Una recepción de red altera el mundo del anfitrión o la partida individual."); return
	print("RESOURCE REPLICATION TEST OK: recepción real del mundo, golpes parciales, cambios por id, repetición, duplicados, matrices GPU, tocones, dos lotes de colisión, caída confirmada, corrección sin botín y carga completa.")
	quit()

func recibir() -> void: sesion.world_state_received.emit(estado)

func pose_arbol(indice: int) -> Transform3D:
	var clave: String = vegetacion.get("_harvest_tree_full_keys")[indice]
	var campo: MultiMeshInstance3D = vegetacion.get("_installed_multimeshes")[clave]
	return campo.multimesh.get_instance_transform(vegetacion.get("_harvest_tree_full_indices")[indice])

func pose_scatter(recurso: AdventureResource) -> Transform3D:
	var campo: MultiMeshInstance3D = vegetacion.get("_installed_multimeshes")[recurso.get_meta("multimesh_key")]
	return campo.multimesh.get_instance_transform(recurso.get_meta("multimesh_instance_index"))

func fallar(mensaje: String) -> void:
	root.get_node("NetworkSession").session_mode = 0
	push_error("RESOURCE REPLICATION TEST FAIL: "+mensaje)
	quit(1)
