extends SceneTree

const RenderHierba = preload("res://scripts/render_hierba.gd")

class DispersorPrueba extends VegetationScatter:
	var fuentes_sincronizadas: Dictionary = {}
	func _ready() -> void: set_process(false)
	func _actualizar_fuente_hierba(campo: MultiMeshInstance3D, poses: Array[Transform3D]) -> void:
		fuentes_sincronizadas[campo.get_instance_id()] = poses.duplicate()
		super._actualizar_fuente_hierba(campo,poses)

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var terreno := Terrain3D.new()
	terreno.region_size = 256
	terreno.vertex_spacing = 2.0
	root.add_child(terreno)
	var region := terreno.data.add_region_blank(Vector2i.ZERO)
	var negativa := terreno.data.add_region_blank(Vector2i(-1,0))
	var imagen := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
	var imagen_negativa := negativa.get_map(Terrain3DRegion.TYPE_HEIGHT)
	imagen.fill(Color(20,0,0))
	imagen_negativa.fill(Color(-25,0,0))
	imagen.set_pixel(32,32,Color(140,0,0))
	imagen.set_pixel(30,32,Color(-65,0,0))
	imagen.set_pixel(200,200,Color(900,0,0))
	imagen_negativa.set_pixel(255,32,Color(210,0,0))
	terreno.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	var gestor := RenderHierba.new()
	root.add_child(gestor)
	gestor.iniciar(terreno)
	var generador := VegetationScatter.new()
	var malla := generador._make_meadow_blades(128,Vector2(0.035,0.065),Vector2(0.9,1.34))
	generador.free()
	var pose := Transform3D(Basis.IDENTITY,Vector3(64,20,64))
	var caja := pose * gestor.calcular_caja(malla,pose)
	if caja.position.y > -65 or caja.end.y < 140 or caja.end.y > 400: fallar("No se conservan los extremos interiores locales del mapa de altura."); return
	var consultas := int(gestor.estadisticas().consultas_alturas)
	gestor.calcular_caja(malla,pose)
	if int(gestor.estadisticas().consultas_alturas) != consultas or int(gestor.estadisticas().aciertos_alturas) < 1: fallar("La misma huella vuelve a leer el mapa de altura."); return
	var borde := Transform3D(Basis.IDENTITY,Vector3(0,20,64))
	var caja_borde := borde * gestor.calcular_caja(malla,borde)
	if caja_borde.position.y > -25 or caja_borde.end.y < 210: fallar("La huella pierde la región negativa al cruzar el borde."); return
	var fuera := Transform3D(Basis.IDENTITY,Vector3(900,300,900))
	var caja_fuera := fuera * gestor.calcular_caja(malla,fuera)
	if not caja_fuera.grow(0.001).has_point(fuera.origin): fallar("Una región ausente pierde las raíces sin adaptar."); return

	var viento_maximo := VegetationScatter.GRASS_STORM_BREEZE + VegetationScatter.GRASS_STORM_GUST*1.46 + VegetationScatter.GRASS_STORM_BEND + 0.52 + 1.15
	if RenderHierba.MARGEN_VIENTO < viento_maximo: fallar("El margen no cubre viento, tormenta, pisada y onda simultáneos."); return
	var azar := RandomNumberGenerator.new()
	azar.seed = 20261108
	var arrays := malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var raices: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for muestra in 90:
		var escala := Vector3(azar.randf_range(0.5,2),azar.randf_range(0.5,2),azar.randf_range(0.5,2))
		if muestra%3 == 0: escala.x = -escala.x
		var base := Basis.from_euler(Vector3(azar.randf_range(-0.7,0.7),azar.randf_range(-PI,PI),azar.randf_range(-0.4,0.4))).scaled(escala)
		var transformacion := Transform3D(base,Vector3(azar.randf_range(-10,85),20,azar.randf_range(30,95)))
		var limites := (transformacion * gestor.calcular_caja(malla,transformacion)).grow(0.002)
		for indice in vertices.size():
			var raiz_local := Vector3(raices[indice].x,-0.08,raices[indice].y)
			var raiz := transformacion * raiz_local
			raiz.y = altura_shader(terreno,raiz)-0.025
			var offset := vertices[indice]-raiz_local
			offset.x *= 1.8
			offset.z *= 1.8
			offset.y -= RenderHierba.DESCENSO_MAXIMO*uvs[indice].y
			var direccion := Vector3(cos(indice),0,sin(indice))
			var punto := raiz + base*offset + direccion*viento_maximo*uvs[indice].y
			if not limites.has_point(punto): fallar("Una brizna inclinada, con escala o viento queda fuera de su volumen."); return

	var padre := Node3D.new()
	root.add_child(padre)
	var campo := MultiMeshInstance3D.new()
	campo.multimesh = MultiMesh.new()
	campo.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	campo.multimesh.mesh = malla
	campo.multimesh.instance_count = 3
	campo.layers = 5
	campo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(campo)
	gestor.registrar(campo)
	gestor.actualizar(campo,[pose,pose,Transform3D(Basis.IDENTITY,Vector3(80,20,64))])
	if campo.layers != 0 or int(gestor.estadisticas().instancias) != 3: fallar("Se duplica el campo original o se pierden poses repetidas."); return
	var cantidad := int(gestor.estadisticas().creadas)
	for paso in 50:
		var desplazamiento := Vector3(paso*50,0,paso*30)
		gestor.actualizar(campo,[Transform3D(Basis.IDENTITY,pose.origin+desplazamiento),Transform3D(Basis.IDENTITY,pose.origin+desplazamiento+Vector3.RIGHT*10),Transform3D(Basis.IDENTITY,pose.origin+desplazamiento+Vector3.BACK*10)])
		if int(gestor.estadisticas().creadas) != cantidad: fallar("Un salto de cámara crea otra ventana antes de reutilizar la reserva."); return
	gestor.actualizar(campo,[pose])
	imagen.set_pixel(32,32,Color(320,0,0))
	terreno.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	var datos: Dictionary = gestor.get("_campos")[campo.get_instance_id()]
	var entrada: Dictionary = datos.instancias[pose][0]
	if (pose * (entrada.caja as AABB)).end.y < 320: fallar("Cambiar el terreno conserva la caja de altura antigua."); return
	padre.hide()
	if int(gestor.estadisticas().instancias) != 0: fallar("Un padre oculto sigue representando los parches individuales."); return
	padre.show()
	if int(gestor.estadisticas().instancias) != 1 or int(gestor.estadisticas().creadas) != cantidad: fallar("Mostrar el padre pierde los parches o su reserva."); return
	gestor.establecer_activo(false)
	if campo.layers != 5 or int(gestor.estadisticas().instancias) != 0: fallar("El control anterior no restaura las capas del MultiMesh."); return
	gestor.establecer_activo(true)
	if campo.layers != 0 or int(gestor.estadisticas().instancias) != 1: fallar("Reactivar duplica la hierba o pierde el parche."); return
	gestor.actualizar(campo,[pose,borde],PackedInt64Array([1001,1002]))
	var preparaciones := int(gestor.estadisticas().preparaciones_parches)
	var primera: Dictionary = datos.instancias[1001][0]
	gestor.actualizar(campo,[borde,pose],PackedInt64Array([1002,1001]))
	if int(gestor.estadisticas().preparaciones_parches) != preparaciones or datos.instancias[1001][0].rid != primera.rid: fallar("Reordenar identidades estables vuelve a preparar parches que no cambiaron."); return
	padre.position = Vector3(10,3,0)
	gestor.actualizar(campo,[borde,pose],PackedInt64Array([1002,1001]))
	if datos.instancias[1001][0].pose != campo.global_transform*pose: fallar("Mover el padre conserva la transformación global anterior."); return
	for indice in RenderHierba.LIMITE_CACHE+20:
		gestor.calcular_caja(malla,Transform3D(Basis.IDENTITY,Vector3(indice*40,20,7000)))
	if int(gestor.estadisticas().cache_alturas) != RenderHierba.LIMITE_CACHE: fallar("El cache de alturas no está acotado."); return
	padre.remove_child(campo)
	if campo.layers != 5 or int(gestor.estadisticas().campos) != 0: fallar("Retirar el campo deja capas modificadas o un registro vivo."); return
	campo.free()
	padre.queue_free()
	var dispersor := DispersorPrueba.new()
	dispersor.terrain_path = NodePath(".")
	root.add_child(dispersor)
	var biblioteca: Array[Mesh] = [malla]
	dispersor.set("_grass_meshes",biblioteca)
	dispersor.set("_grass_mid_lod_meshes",biblioteca)
	dispersor.set("_dense_grass_offset",0)
	dispersor.set("_render_hierba",gestor)
	for punto in [Vector2(-3,-3),Vector2(-3,3),Vector2(3,-3),Vector2(3,3),Vector2(3,3),Vector2(45,2)]:
		dispersor._index_near_grass_transform(punto,Transform3D(Basis.IDENTITY,Vector3(punto.x,20,punto.y)))
	dispersor._install_grass_near_field()
	dispersor._update_grass_near_field(Vector2.ZERO,true)
	var cercano: Dictionary = gestor.get("_campos")[dispersor.get("_grass_near_instance").get_instance_id()]
	var unicas := {}
	for id in cercano.identidades: unicas[id] = true
	if cercano.identidades.size() != 5 or unicas.size() != 5 or cercano.instancias.size() != 5: fallar("Las identidades de celdas negativas o de poses repetidas colisionan."); return
	preparaciones = int(gestor.estadisticas().preparaciones_parches)
	dispersor._update_grass_near_field(Vector2(4,0),true)
	if cercano.instancias.size() != 6 or int(gestor.estadisticas().preparaciones_parches) != preparaciones+1: fallar("Mover el foco vuelve a preparar parches retenidos o pierde el parche nuevo."); return
	if not dispersor.fuentes_sincronizadas.is_empty(): fallar("La fuente invisible sigue subiendo matrices al caminar."); return
	gestor.establecer_activo(false)
	var fuente := dispersor.get("_grass_near_instance") as MultiMeshInstance3D
	if fuente.multimesh.visible_instance_count != 6: fallar("Restaurar la fuente pierde el último número de parches."); return
	if dispersor.fuentes_sincronizadas.get(fuente.get_instance_id(),[]) != cercano.poses: fallar("Restaurar la fuente no recibe la última distribución."); return
	for indice in 6:
		# El backend dummy devuelve identidad: la lectura real se comprueba al
		# ejecutar esta misma prueba con Metal/Vulkan, además de las capturas.
		if DisplayServer.get_name() != "headless" and fuente.multimesh.get_instance_transform(indice) != cercano.poses[indice]: fallar("Restaurar la fuente conserva matrices de una ventana anterior."); return
		for extremo in 8:
			var punto: Vector3 = cercano.poses[indice]*malla.get_aabb().get_endpoint(extremo)
			if not fuente.multimesh.custom_aabb.has_point(punto): fallar("La caja restaurada pierde parte del último campo visible."); return
	dispersor.free()
	if int(gestor.estadisticas().campos) != 0: fallar("Liberar el dispersor deja campos registrados."); return
	gestor.queue_free()
	terreno.queue_free()
	await process_frame
	print("GRASS RENDER TEST OK: extremos interiores, bordes negativos, regiones ausentes, 34560 vértices con viento y escala, cache acotado, duplicados, reserva, identidades, visibilidad y cambios de altura.")
	quit()

func altura_shader(terreno: Terrain3D, punto: Vector3) -> float:
	var grid := Vector2(punto.x,punto.z)/terreno.vertex_spacing
	var localizacion := Vector2i(floori(grid.x/terreno.region_size),floori(grid.y/terreno.region_size))
	var region := terreno.data.get_region(localizacion)
	if region == null: return punto.y+0.025
	var imagen := region.get_map(Terrain3DRegion.TYPE_HEIGHT)
	var uv := grid-Vector2(localizacion*terreno.region_size)
	var texel := Vector2i(uv.floor())
	var siguiente := (texel+Vector2i.ONE).min(Vector2i.ONE*(terreno.region_size-1))
	return lerpf(lerpf(imagen.get_pixel(texel.x,texel.y).r,imagen.get_pixel(siguiente.x,texel.y).r,uv.x-floorf(uv.x)),lerpf(imagen.get_pixel(texel.x,siguiente.y).r,imagen.get_pixel(siguiente.x,siguiente.y).r,uv.x-floorf(uv.x)),uv.y-floorf(uv.y))

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
