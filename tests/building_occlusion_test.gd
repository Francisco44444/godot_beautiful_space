extends SceneTree

const Oclusion = preload("res://scripts/oclusion_edificios.gd")

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var opaco := StandardMaterial3D.new()
	opaco.cull_mode = BaseMaterial3D.CULL_DISABLED
	var malla := ArrayMesh.new()
	var vertices := PackedVector3Array()
	for rectangulo in [Rect2(-2,0,1.4,3),Rect2(0.6,0,1.4,3),Rect2(-0.6,2.2,1.2,0.8)]:
		var a := Vector3(rectangulo.position.x,rectangulo.position.y,0)
		var b := Vector3(rectangulo.end.x,rectangulo.position.y,0)
		var c := Vector3(rectangulo.end.x,rectangulo.end.y,0)
		var d := Vector3(rectangulo.position.x,rectangulo.end.y,0)
		vertices.append_array(PackedVector3Array([a,b,c,a,c,d]))
	agregar_superficie(malla,vertices,opaco)
	var gestor := Oclusion.new()
	var caras: PackedVector3Array = gestor.caras_opacas(malla)
	if caras.size()!=18: fallar("La puerta no conserva las seis caras reales del marco."); return
	if corta(caras,Vector3(0,1,5),Vector3.FORWARD) or not corta(caras,Vector3(-1.5,1,5),Vector3.FORWARD) or not corta(caras,Vector3(0,2.6,5),Vector3.FORWARD): fallar("La geometría de oclusión cierra el hueco o pierde jambas y dintel."); return
	opaco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not gestor.caras_opacas(malla).is_empty(): fallar("El cache conserva caras después de cambiar a transparencia."); return
	opaco.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	opaco.cull_mode = BaseMaterial3D.CULL_BACK
	if not gestor.caras_opacas(malla).is_empty(): fallar("Se acepta como doble cara un material de una sola cara."); return
	opaco.cull_mode = BaseMaterial3D.CULL_DISABLED
	opaco.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	if not gestor.caras_opacas(malla).is_empty(): fallar("Un material que desaparece con distancia sigue ocluyendo."); return
	opaco.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	opaco.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if not gestor.caras_opacas(malla).is_empty(): fallar("Se acepta geometría que gira hacia la cámara."); return
	opaco.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	opaco.grow = true
	if not gestor.caras_opacas(malla).is_empty(): fallar("Una malla desplazada por grow sigue ocluyendo con sus vértices originales."); return
	opaco.grow = false
	opaco.proximity_fade_enabled = true
	if not gestor.caras_opacas(malla).is_empty(): fallar("Un material que se desvanece cerca de la cámara sigue ocluyendo."); return
	opaco.proximity_fade_enabled = false
	if Oclusion.material_opaco(ShaderMaterial.new()): fallar("Se supone opaco un shader sin verificar."); return

	var raiz := Node3D.new()
	root.add_child(raiz)
	var casa := Node3D.new()
	casa.set_meta("recipe","Prueba con huecos")
	casa.position = Vector3(-1450,23,650)
	casa.rotation.y = 0.7
	casa.scale = Vector3.ONE*2.4
	raiz.add_child(casa)
	var pieza := Node3D.new()
	pieza.transform = Transform3D(Basis(Vector3.UP,0.3),Vector3(3,0,-7))
	pieza.set_meta("oclusion_estructura",true)
	casa.add_child(pieza)
	var visual := MeshInstance3D.new()
	visual.mesh = malla
	pieza.add_child(visual)
	if not Oclusion.es_estructura_estatica(visual,casa): fallar("Se descarta una estructura estática marcada."); return
	pieza.remove_meta("oclusion_estructura")
	if Oclusion.es_estructura_estatica(visual,casa): fallar("Se acepta decoración sin marcar como estructura estática."); return
	pieza.set_meta("oclusion_estructura",true)
	visual.layers = 2
	if Oclusion.es_estructura_estatica(visual,casa): fallar("Otra capa visual sigue ocluyendo la capa principal."); return
	visual.layers = 1
	visual.visibility_range_end = 30
	if Oclusion.es_estructura_estatica(visual,casa): fallar("Una pieza con distancia de desaparición sigue ocluyendo."); return
	visual.visibility_range_end = 0
	var transparente := StandardMaterial3D.new()
	transparente.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.set_surface_override_material(0,transparente)
	if int(gestor.construir(raiz).casas)!=0: fallar("Una sobrescritura transparente reutiliza el cache opaco."); return
	visual.set_surface_override_material(0,null)
	pieza.hide()
	if int(gestor.construir(raiz).casas)!=0: fallar("Una estructura oculta se hornea como si fuese visible."); return
	pieza.show()
	var suelo := ArrayMesh.new()
	agregar_superficie(suelo,PackedVector3Array([Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)]),opaco)
	var baldosas := MultiMeshInstance3D.new()
	baldosas.multimesh = MultiMesh.new()
	baldosas.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	baldosas.multimesh.mesh = suelo
	baldosas.multimesh.instance_count = 2
	var poses: Array[Transform3D] = [Transform3D(Basis.IDENTITY,Vector3(-2,0,0)),Transform3D(Basis.IDENTITY,Vector3(2,0,0))]
	for indice in poses.size(): baldosas.multimesh.set_instance_transform(indice,poses[indice])
	baldosas.set_meta("oclusion_estructura",true)
	baldosas.set_meta("poses_oclusion",poses)
	casa.add_child(baldosas)
	var informe: Dictionary = gestor.construir(raiz)
	if int(informe.casas)!=1 or int(informe.triangulos)!=10: fallar("La casa no contiene exactamente el marco y sus dos baldosas."); return
	var oclusor := casa.get_node("OclusionEstructura") as OccluderInstance3D
	var puntos: PackedVector3Array = oclusor.occluder.vertices
	var esperada := pieza.transform
	for indice in 18:
		if not puntos[indice].is_equal_approx(esperada*vertices[indice]): fallar("La composición local altera una pieza girada o duplica la escala de la casa."); return
	if corta(puntos,esperada*Vector3(0,1,5),esperada.basis*Vector3.FORWARD): fallar("La composición de la casa cierra el hueco de la puerta."); return
	if corta(puntos,Vector3(0,4,0),Vector3.DOWN) or not corta(puntos,Vector3(-2,4,0),Vector3.DOWN): fallar("La oclusión del suelo rellena un hueco de escalera."); return
	if int(gestor.construir(raiz).casas)!=0 or casa.find_children("OclusionEstructura","OccluderInstance3D",false,false).size()!=1: fallar("Repetir la construcción duplica oclusores."); return
	casa.hide()
	if oclusor.is_visible_in_tree(): fallar("Ocultar la casa deja su oclusor visible."); return
	casa.show()

	var receta: Dictionary = BuildingRecipes.all()[0]
	var plan := BuildingSolver.new()
	if not plan.solve(receta,BuildingCatalog.roof_metrics()): fallar("No se pudo montar la receta real para verificar sus suelos."); return
	var ensamblador := BuildingAssembler.new()
	var real := ensamblador.assemble(plan,receta,BuildingCatalog.families())
	raiz.add_child(real)
	var reales := real.find_children("Solado","MultiMeshInstance3D",true,false)
	if reales.size()!=1: fallar("La receta real pierde el MultiMesh del suelo."); return
	var actual := reales[0] as MultiMeshInstance3D
	var guardadas: Array = actual.get_meta("poses_oclusion",[])
	if guardadas.size()!=actual.multimesh.instance_count or guardadas.is_empty(): fallar("Las poses de suelo no corresponden a las baldosas reales."); return
	if DisplayServer.get_name()!="headless":
		for indice in guardadas.size():
			if actual.multimesh.get_instance_transform(indice)!=guardadas[indice]: fallar("La oclusión usa una pose distinta del suelo dibujado."); return
	raiz.queue_free()
	await process_frame
	print("BUILDING OCCLUSION TEST OK: huecos, suelos, transformaciones, materiales, capas, visibilidad, cache e idempotencia; receta real verificada.")
	quit()

func agregar_superficie(malla: ArrayMesh, puntos: PackedVector3Array, material: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = puntos
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	malla.surface_set_material(malla.get_surface_count()-1,material)

func corta(puntos: PackedVector3Array, desde: Vector3, direccion: Vector3) -> bool:
	for indice in range(0,puntos.size(),3):
		if Geometry3D.ray_intersects_triangle(desde,direccion,puntos[indice],puntos[indice+1],puntos[indice+2])!=null: return true
	return false

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
