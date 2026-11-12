extends SceneTree

const OPTIMIZADOR = preload("res://scripts/normales_constantes_terreno.gd")
const OCLUSION = preload("res://scripts/oclusion_terreno.gd")
var mundo: Node3D
var activo: Terrain3DTextureAsset
var normal_anterior: Texture2D
var profundidad_anterior := 0.0

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	var imagen := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var color := Color(127.0 / 255.0, 127.0 / 255.0, 1, 1)
	imagen.fill(color)
	var bytes_originales := imagen.get_data().duplicate()
	var cache := {}
	if not _exigir(OPTIMIZADOR.imagen_constante(imagen, cache), "Se rechaza la normal plana exacta."): return
	if not _exigir(OPTIMIZADOR.imagen_constante(imagen.duplicate(), cache) and cache.size() == 1, "Se duplica la referencia de una imagen equivalente."): return
	for canal in 4:
		var alterada := imagen.duplicate() as Image
		var pixel := color
		pixel[canal] -= 1.0 / 255.0
		alterada.set_pixel(7, 7, pixel)
		if not _exigir(not OPTIMIZADOR.imagen_constante(alterada, cache), "Se ignora un píxel distinto en el canal %d." % canal): return
	var con_mip := imagen.duplicate() as Image
	con_mip.generate_mipmaps()
	if not _exigir(OPTIMIZADOR.imagen_constante(con_mip, cache), "Se rechazan los mipmaps planos."): return
	var datos := con_mip.get_data()
	datos[con_mip.get_mipmap_offset(con_mip.get_mipmap_count())] = 126
	var mip_alterado := Image.create_from_data(8, 8, true, Image.FORMAT_RGBA8, datos)
	if not _exigir(not OPTIMIZADOR.imagen_constante(mip_alterado, cache), "Se ignora un mipmap modificado."): return
	var formato := Image.create(8, 8, false, Image.FORMAT_RGB8)
	formato.fill(color)
	if not _exigir(not OPTIMIZADOR.imagen_constante(formato, cache), "Un formato no verificado elimina las lecturas normales."): return
	if not _exigir(not OPTIMIZADOR.imagen_constante(null, cache) and not OPTIMIZADOR.imagen_constante(Image.new(), cache), "Una imagen ausente permite especializar."): return
	if not _exigir(imagen.get_data() == bytes_originales, "La comprobación modifica los píxeles originales."): return
	for caso in [{"valores":PackedFloat32Array([0, 0]),"cantidad":2,"valido":true}, {"valores":PackedFloat32Array([0, 0.0000001]),"cantidad":2,"valido":false}, {"valores":PackedFloat32Array([0, -0.1]),"cantidad":2,"valido":false}, {"valores":PackedFloat32Array([NAN]),"cantidad":1,"valido":false}, {"valores":PackedFloat32Array([INF]),"cantidad":1,"valido":false}, {"valores":PackedFloat32Array([0]),"cantidad":2,"valido":false}, {"valores":PackedFloat32Array(),"cantidad":0,"valido":false}]:
		if not _exigir(OPTIMIZADOR.profundidades_nulas(caso.valores, caso.cantidad) == caso.valido, "Se elimina un mapeo normal activo o incompleto."): return
	var fuente: String = OPTIMIZADOR.LECTURA + "\n" + OPTIMIZADOR.LECTURA + "\n" + OPTIMIZADOR.MAPEO + "\n" + OPTIMIZADOR.PROFUNDIDAD
	var codigo: String = OPTIMIZADOR.crear_codigo(fuente)
	# Los texeles reales son 127/255: usar 0,5 también cambia la mezcla y el AO.
	if not _exigir(codigo.count("vec4(0.4980392156862745, 0.4980392156862745, 1.0, 1.0)") == 2, "La constante cambia los texeles RGBA del terreno."): return
	if not _exigir(codigo.count(OPTIMIZADOR.VALOR) == 2 and "NORMAL = normalize(NORMAL);" in codigo and "NORMAL_MAP" not in codigo, "La especialización pierde muestras o mantiene el mapeo innecesario."): return
	for desconocido in ["", fuente.replace(OPTIMIZADOR.MAPEO, ""), fuente.replace(OPTIMIZADOR.PROFUNDIDAD, ""), fuente + OPTIMIZADOR.LECTURA, fuente.replace(OPTIMIZADOR.LECTURA, "otra_lectura")]:
		if not _exigir(OPTIMIZADOR.crear_codigo(desconocido).is_empty(), "Se modifica un shader cuya estructura no está verificada."): return
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 30: await process_frame
	paused = false
	var optimizador := mundo.get_node("NormalesConstantesTerreno")
	if DisplayServer.get_name() == "headless":
		optimizador.establecer_habilitado(false)
		optimizador.establecer_habilitado(true)
		if not _exigir(not optimizador.esta_activo() and optimizador.revisiones == 0 and not optimizador._pendiente, "El modo headless usa una lectura ficticia de texturas GPU."): return
	else:
		if not _exigir(optimizador.esta_activo() and optimizador.capas_comprobadas == 7, "El terreno real no activa las siete normales verificadas: revisiones=%s, capas=%s, motivo=%s, profundidades=%s." % [optimizador.revisiones, optimizador.capas_comprobadas, optimizador.motivo, (mundo.get_node("Terrain3D") as Terrain3D).assets.get_texture_normal_depths()]): return
		var terreno := mundo.get_node("Terrain3D") as Terrain3D
		var oclusion := mundo.get_node("OclusionTerreno") as OccluderInstance3D
		if not _exigir(OCLUSION.compatible(terreno) and oclusion.occluder != null and oclusion.occluder.get_indices().size() == 149568, "La especialización desactiva la oclusión del relieve."): return
		var shader_verificado := terreno.material.get_shader_override()
		var codigo_verificado := shader_verificado.code
		shader_verificado.code += "\n// Cambio posterior a la verificación.\n"
		if not _exigir(not OCLUSION.compatible(terreno), "Un shader editado hereda la confianza de la oclusión."): return
		shader_verificado.code = codigo_verificado
		if not _exigir(OCLUSION.compatible(terreno), "Restaurar el código verificado no recupera la compatibilidad."): return
		var revisiones: int = optimizador.revisiones
		var rig := mundo.get_node("CameraRig")
		rig.set_process(false)
		rig.set_physics_process(false)
		var camara := rig.get_node("SpringArm3D/Camera3D") as Camera3D
		var origen := camara.global_position
		for i in 100:
			camara.global_position = origen + Vector3(sin(float(i) * 0.1) * 5.0, 0, 0)
			mundo.sincronizar_camara_terreno()
			await process_frame
		if not _exigir(optimizador.revisiones == revisiones, "Las normales se releen continuamente sin cambiar los recursos."): return
		optimizador.establecer_habilitado(false)
		for i in 3: await process_frame
		var codigo_original := RenderingServer.shader_get_code(terreno.material.get_shader_rid())
		if not _exigir(not optimizador.esta_activo() and not terreno.material.is_shader_override_enabled(), "Desactivar el optimizador no recupera el material original."): return
		optimizador.establecer_habilitado(true)
		for i in 12: await process_frame
		if not _exigir(optimizador.esta_activo(), "Reactivar el optimizador no recupera su shader."): return
		var piezas: Array[Terrain3DTextureAsset] = []
		var normal_plana := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		normal_plana.fill(color)
		normal_plana.generate_mipmaps()
		var textura_plana := ImageTexture.create_from_image(normal_plana)
		for i in 7:
			var pieza := Terrain3DTextureAsset.new()
			pieza.id = i
			pieza.albedo_texture = load("res://assets/textures/stylized_terrain/quaternius_grass_albedo_seamless.png")
			pieza.normal_depth = 0.0
			pieza.normal_texture = textura_plana
			piezas.append(pieza)
		terreno.assets.set_texture_list(piezas)
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		activo = piezas[0]
		normal_anterior = activo.normal_texture
		profundidad_anterior = activo.normal_depth
		activo.normal_depth = 0.1
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		if not _exigir(not optimizador.esta_activo() and not terreno.material.is_shader_override_enabled(), "Cambiar la profundidad conserva una optimización inválida."): return
		activo.normal_depth = 0.0
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		if not _exigir(optimizador.esta_activo(), "Restaurar la profundidad no recupera la especialización."): return
		var otra := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
		otra.fill(color)
		otra.set_pixel(1023, 1023, Color(0.3, 0.5, 1, 1))
		otra.generate_mipmaps()
		activo.normal_texture = ImageTexture.create_from_image(otra)
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		if not _exigir(not optimizador.esta_activo(), "Una textura normal modificada conserva valores constantes."): return
		_restaurar_activo()
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		if not _exigir(optimizador.esta_activo(), "Restaurar la textura no recupera la especialización."): return
		var ajeno := Shader.new()
		ajeno.code = codigo_original + "\n// Shader personalizado del control.\n"
		terreno.material.set_shader_override(ajeno)
		terreno.material.enable_shader_override(true)
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		if not _exigir(not optimizador.esta_activo() and terreno.material.get_shader_override() == ajeno, "La revisión sustituye un shader personalizado ajeno."): return
		terreno.material.enable_shader_override(false)
		# Terrain3D no emite changed al cambiar este interruptor. La próxima
		# revisión de recursos debe conservar también un shader ajeno inactivo.
		terreno.assets.update_texture_list()
		for i in 12: await process_frame
		if not _exigir(optimizador.esta_activo(), "Un shader ajeno inactivo bloquea la especialización."): return
		optimizador.establecer_habilitado(false)
		for i in 3: await process_frame
		if not _exigir(terreno.material.get_shader_override() == ajeno and not terreno.material.is_shader_override_enabled(), "La restauración pierde un shader ajeno que estaba inactivo."): return
		print("TERRAIN NORMALS GPU PASS: siete capas, revisiones retenidas, profundidad, textura y shader ajeno; preparación %.3f ms." % optimizador.preparacion_ms)
	mundo.queue_free()
	for i in 4: await process_frame
	print("TERRAIN NORMALS TEST OK: bytes, cuatro canales, mipmaps, formatos, profundidades, estructura y reserva.")
	quit(0)

func _restaurar_activo() -> void:
	if activo != null:
		activo.normal_texture = normal_anterior
		activo.normal_depth = profundidad_anterior
		activo = null

func _exigir(condicion: bool, texto: String) -> bool:
	if condicion: return true
	_restaurar_activo()
	push_error(texto)
	quit(1)
	return false
