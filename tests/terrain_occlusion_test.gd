extends SceneTree

const OclusionTerreno = preload("res://scripts/oclusion_terreno.gd")

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var matriz := []
	matriz.resize(Mesh.ARRAY_MAX)
	matriz[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3(32,0,0),Vector3(32,0,32)])
	matriz[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2])
	var muestras := PackedFloat32Array()
	muestras.resize(256*256)
	if not OclusionTerreno.caras_seguras(matriz,{Vector2i.ZERO:true},{Vector2i.ZERO:true},256,2.0,{Vector2i.ZERO:muestras}).is_empty(): fallar("Se admite una celda marcada por un agujero interior."); return
	if not OclusionTerreno.caras_seguras(matriz,{},{},256,2.0,{Vector2i.ZERO:muestras}).is_empty(): fallar("Se admite geometría fuera de las regiones conocidas."); return
	var terreno := Terrain3D.new()
	terreno.region_size = 256
	terreno.vertex_spacing = 2.0
	root.add_child(terreno)
	for ubicacion in [Vector2i.ZERO,Vector2i(-1,0)]:
		var region := terreno.data.add_region_blank(ubicacion)
		var altura := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
		altura.fill(Color(60,0,0))
		# Una depresión entre los vértices del LOD no debe convertirse en pared.
		altura.set_pixel(55,73,Color(-90,0,0))
		altura.set_pixel(56,74,Color(180,0,0))
		var agujero: Vector3 = Vector3(ubicacion.x*512+210,0,210)
		terreno.data.set_control_hole(agujero,true)
	terreno.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	terreno.data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	var orden_original := terreno.data.get_region_locations().duplicate()
	var recurso := OclusionTerreno.construir(terreno)
	if terreno.data.get_region_locations()!=orden_original: fallar("Calcular la firma modifica el orden nativo de las regiones."); return
	if recurso==null or recurso.get_indices().size()<150: fallar("No se hornea el terreno válido."); return
	var puntos := recurso.get_vertices()
	var indices := recurso.get_indices()
	var negativos := 0
	var depresiones := 0
	for indice in range(0,indices.size(),3):
		var a := puntos[indices[indice]]
		var b := puntos[indices[indice+1]]
		var c := puntos[indices[indice+2]]
		var plano := Plane(a,b,c)
		if a.y< -80: depresiones += 1
		if a.x<0: negativos += 1
		var minimo := a.min(b).min(c)
		var maximo := a.max(b).max(c)
		for z in range(roundi(minimo.z/2),roundi(maximo.z/2)+1):
			for x in range(roundi(minimo.x/2),roundi(maximo.x/2)+1):
				var muestra := Vector3(x*2,0,z*2)
				var poligono := PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
				if not Geometry2D.is_point_in_polygon(Vector2(muestra.x,muestra.z),poligono): continue
				if terreno.data.get_control_hole(muestra): fallar("Un triángulo tapa un agujero real."); return
				var altura := terreno.data.get_height(muestra)
				var cota := (plano.d-plano.normal.x*muestra.x-plano.normal.z*muestra.z)/plano.normal.y
				if is_nan(altura) or cota>altura-2.0+0.001: fallar("El oclusor sobresale del terreno o invade una región ausente: %s, altura %s, cara %s %s %s."%[muestra,altura,a,b,c]); return
	if negativos==0 or depresiones==0: fallar("Se pierde la región negativa o no se comprueba su depresión."); return
	var contenedor := Node3D.new()
	root.add_child(contenedor)
	contenedor.position = Vector3(20,8,-30)
	var gestor := OclusionTerreno.new()
	contenedor.add_child(gestor)
	if not gestor.iniciar(terreno,recurso) or gestor.occluder!=recurso: fallar("Se rechaza un recurso con firma válida."); return
	if gestor.global_transform!=Transform3D.IDENTITY: fallar("La pose del padre desplaza sólo la oclusión."); return
	if gestor.is_processing() or gestor.is_physics_processing(): fallar("El oclusor añade actividad continua."); return
	var firma_original := OclusionTerreno.firma(terreno)
	var imagen := terreno.data.get_region(Vector2i.ZERO).get_map(Terrain3DRegion.TYPE_HEIGHT)
	imagen.set_pixel(1,1,Color(30,0,0))
	terreno.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	if gestor.occluder!=null or bool(gestor.estadisticas().activo): fallar("Cambiar alturas deja el oclusor antiguo activo."); return
	if OclusionTerreno.firma(terreno)==firma_original or gestor.iniciar(terreno,recurso): fallar("La firma no detecta alturas desactualizadas."); return
	imagen.set_pixel(1,1,Color(60,0,0))
	terreno.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	if not gestor.iniciar(terreno,recurso): fallar("Restaurar el mapa no recupera el cache válido."); return
	terreno.data.set_control_hole(Vector3(20,0,20),true)
	terreno.data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	if gestor.occluder!=null or gestor.iniciar(terreno,recurso): fallar("Abrir una gruta no invalida el oclusor."); return
	terreno.data.set_control_hole(Vector3(20,0,20),false)
	terreno.data.update_maps(Terrain3DRegion.TYPE_CONTROL)
	if not gestor.iniciar(terreno,recurso): fallar("No se puede volver a enlazar el terreno."); return
	terreno.material.shader_override_enabled = true
	terreno.material_changed.emit()
	if gestor.occluder!=null or gestor.iniciar(terreno,recurso): fallar("Se admite desplazamiento desconocido por shader."); return
	terreno.material.shader_override_enabled = false
	if not gestor.iniciar(terreno,recurso): fallar("No se puede restaurar el material válido."); return
	terreno.hide()
	if gestor.occluder!=null or gestor.iniciar(terreno,recurso): fallar("El terreno invisible sigue ocultando objetos."); return
	terreno.show()
	if not gestor.iniciar(terreno,recurso): fallar("No se recupera el terreno visible."); return
	terreno.data.add_region_blank(Vector2i(1,0))
	if OclusionTerreno.firma(terreno)==firma_original or gestor.iniciar(terreno,recurso): fallar("Una región nueva reutiliza el oclusor antiguo."); return
	gestor.free()
	contenedor.free()
	terreno.free()
	for nombre in ["ExplorationManager","InventoryManager"]:
		root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").call("bind_world",null)
	await mundo.get_node("RPGStoryRuntime").terreno_preparado
	if DisplayServer.get_name()!="headless":
		var publicado := mundo.get_node("OclusionTerreno") as OccluderInstance3D
		if publicado==null or publicado.occluder==null: fallar("La ruta gráfica no activa el recurso tras construir las grutas."); return
	var real := OclusionTerreno.new()
	mundo.add_child(real)
	if not real.iniciar(mundo.get_node("Terrain3D")): fallar("El recurso publicado no corresponde al terreno con sus cuatro grutas."); return
	if real.occluder.get_indices().size()!=149568: fallar("Cambió la geometría horneada: regenerar y verificar el contrato."); return
	print("TERRAIN OCCLUSION TEST OK: depresiones, agujeros, bordes, coordenadas negativas, firma e invalidación sin callbacks continuos.")
	quit()

func fallar(mensaje: String) -> void:
	push_error("TERRAIN OCCLUSION TEST FAIL: "+mensaje)
	quit(1)
