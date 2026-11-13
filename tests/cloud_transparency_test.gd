extends SceneTree

## Contratos numéricos y comparación real de color,
## glow y profundidad. La ruta gráfica NO se sustituye por una lectura dummy.
const NUBES = preload("res://scripts/animated_clouds.gd")
const CORTE_HORIZONTE := "\t// Con alfa exactamente cero no hay color, emisión ni profundidad que conservar.\n\tif (above_horizon <= 0.0 || opacity <= 0.0) { discard; }\n"
const CORTE_REGION := "\t// Ambas capas multiplican cloud_region: fuera de sus bancos son transparentes.\n\tif (cloud_region <= 0.0) { discard; }\n"
const LECTOR_PROFUNDIDAD := """
shader_type spatial;
render_mode unshaded, depth_draw_never, fog_disabled;
// La cámara es ortográfica: el rango0–1 ya ocupa niveles visibles. Multiplicar
// la profundidad saturaría el fondo y la pieza de calibración al mismo blanco.
uniform sampler2D profundidad : hint_depth_texture, filter_nearest, repeat_disable;
void fragment() {
	ALBEDO = vec3(texture(profundidad, SCREEN_UV).r);
	ALPHA = 1.0;
}
"""

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	var codigo: String = NUBES.PROCEDURAL_VEIL_SHADER
	for contrato in [CORTE_HORIZONTE, CORTE_REGION, "render_mode unshaded, cull_front, blend_mix;", "* bank_vertical_fade * cloud_region * mix(0.30, 1.0, cluster_shape)", "float cirrus_alpha = streak_mask * 0.15 * cloud_region;", "cloud_mask * above_horizon * opacity", "EMISSION = painted_color * mix(0.025, 0.115, daylight);", "ALPHA = final_alpha;", "\t\t0.94\n\t);\n"]:
		if not _exigir(codigo.count(contrato) == 1, "Ha cambiado el contrato del velo: " + String(contrato)): return
	if not _exigir(codigo.find(CORTE_HORIZONTE) < codigo.find("float region_noise = fbm3d("), "El horizonte se descarta después del ruido."): return
	if not _exigir(codigo.find(CORTE_REGION) < codigo.find("vec3 broad_domain ="), "Los huecos de bancos calculan ruido posterior."): return
	var creador := NUBES.new()
	var velo: MeshInstance3D = creador._make_procedural_veil()
	if not _exigir(velo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "El velo transparente empieza a proyectar sombras."): return
	creador.free()
	var casos: Array[Dictionary] = []
	for elevacion: float in PackedFloat64Array([-0.1, 0.0, 0.0079999, 0.008, 0.0080001, 0.0999999, 0.10, 0.1000001, 0.45, 0.8]):
		for region: float in PackedFloat64Array([0.0, 0.0000001, 0.25, 1.0]):
			for opacidad: float in PackedFloat64Array([0.0, 0.75]):
				var caso := {"elevacion":elevacion, "region":region, "opacidad":opacidad}
				casos.append(caso)
				var horizonte := smoothstep(0.008, 0.10, clampf(elevacion, 0, 1))
				for banco: float in PackedFloat64Array([0.0, 0.01, 0.5, 1.3]):
					for cirro: float in PackedFloat64Array([0.0, 0.0000001, 0.15]):
						var alfa := _alfa(banco, cirro, region, horizonte, opacidad)
						var retirado := horizonte <= 0.0 or opacidad <= 0.0 or region <= 0.0
						if not _exigir(not retirado or alfa == 0.0, "Se retira un fragmento con alfa positivo."): return
						if not _exigir(alfa <= 0.94 and alfa < 0.99, "El velo puede escribir la prepasada opaca de Forward+."): return
						# El destino HDR es idéntico con cualquier color y emisión cuando alfa=0.
						if retirado:
							var fondo := Vector3(0.04, 0.2, 0.8)
							var emision := Vector3(30, 20, 10)
							if not _exigir(fondo.lerp(Vector3.ONE + emision, alfa) == fondo, "La retirada modifica color o emisión HDR."): return
	if DisplayServer.get_name() != "headless":
		var original := codigo.replace(CORTE_HORIZONTE, "").replace(CORTE_REGION, "").replace("render_mode unshaded, cull_front, blend_mix;", "render_mode unshaded, cull_front, blend_mix, depth_prepass_alpha;")
		var vistas := [_crear_vista(original), _crear_vista(codigo)]
		# Calibrar evita comparar dos lectores de profundidad que siempre devuelvan cero.
		vistas[0].lector.visible = true
		await _asentar(12)
		var sin_calibracion: Image = vistas[0].viewport.get_texture().get_image()
		vistas[0].calibracion.visible = true
		await _asentar(4)
		var con_calibracion: Image = vistas[0].viewport.get_texture().get_image()
		var contraste_profundidad := _diferencia(sin_calibracion, con_calibracion)
		if not _exigir(contraste_profundidad > 2, "La prueba no está leyendo profundidad real: contraste %s." % contraste_profundidad): return
		vistas[0].calibracion.visible = false
		vistas[0].lector.visible = false
		vistas[0].velo.visible = false
		await _asentar(4)
		var fondo_sin_velo: Image = vistas[0].viewport.get_texture().get_image()
		vistas[0].velo.visible = true
		var nubes_visibles := false
		var diferencia_maxima := 0
		for caso in casos:
			var altura: float = caso.elevacion
			var direccion := Vector3(sqrt(maxf(0.0, 1.0 - altura * altura)), altura, 0)
			for vista in vistas:
				(vista.material as ShaderMaterial).set_shader_parameter("direccion_prueba", direccion)
				(vista.material as ShaderMaterial).set_shader_parameter("region_prueba", caso.region)
				(vista.material as ShaderMaterial).set_shader_parameter("opacity", caso.opacidad)
			for profundidad in [false, true]:
				for vista in vistas: vista.lector.visible = profundidad
				await _asentar(4)
				var anterior: Image = vistas[0].viewport.get_texture().get_image()
				var siguiente: Image = vistas[1].viewport.get_texture().get_image()
				if not profundidad and _diferencia(fondo_sin_velo, anterior) > 2: nubes_visibles = true
				var cambio := _diferencia(anterior, siguiente)
				diferencia_maxima = maxi(diferencia_maxima, cambio)
				if not _exigir(cambio <= 1, "Se modifica color/glow o profundidad en el borde de horizonte o región: %s, profundidad=%s, máximo=%s." % [caso, profundidad, cambio]): return
		if not _exigir(nubes_visibles, "Se comparan dos cielos sin nubes visibles; falta el testigo positivo."): return
		for vista in vistas: vista.viewport.queue_free()
		print("CLOUD TRANSPARENCY GPU PASS: 80 entradas a ambos lados de umbrales, color/glow y profundidad calibrada (%d); máximo %d." % [contraste_profundidad, diferencia_maxima])
	print("CLOUD TRANSPARENCY TEST OK: cortes exactos, valores pequeños positivos, emisión y reserva de profundidad.")
	quit(0)

func _alfa(banco: float, cirro: float, region: float, horizonte: float, opacidad: float) -> float:
	return clampf((1.0 - (1.0 - banco * region) * (1.0 - cirro * region)) * horizonte * opacidad, 0.0, 0.94)

func _crear_vista(fuente: String) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var escena := Node3D.new()
	viewport.add_child(escena)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 2.0
	camara.near = 0.05
	camara.far = 10.0
	escena.add_child(camara)
	camara.current = true
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color(0.04, 0.08, 0.15)
	ambiente.environment.glow_enabled = true
	ambiente.environment.glow_intensity = 0.8
	ambiente.environment.glow_bloom = 0.1
	escena.add_child(ambiente)
	var fondo := _plano(escena, -5.0, false)
	var material_fondo := StandardMaterial3D.new()
	material_fondo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_fondo.albedo_color = Color(0.2, 0.12, 0.06)
	fondo.material_override = material_fondo
	var velo := _plano(escena, -2.0, true)
	var programa := Shader.new()
	fuente = fuente.replace("shader_type spatial;", "shader_type spatial;\nuniform vec3 direccion_prueba = vec3(1.0, 0.0, 0.0);\nuniform float region_prueba = 1.0;")
	fuente = fuente.replace("vec3 direction = normalize(sky_direction);", "vec3 direction = normalize(direccion_prueba);")
	fuente = fuente.replace("\t\tregion_field\n\t);\n", "\t\tregion_field\n\t);\n\tcloud_region = region_prueba;\n")
	programa.code = fuente.replace("TIME", "17.25")
	var material := ShaderMaterial.new()
	material.shader = programa
	velo.material_override = material
	var lector := _plano(escena, -1.0, false)
	var material_lector := ShaderMaterial.new()
	material_lector.shader = Shader.new()
	material_lector.shader.code = LECTOR_PROFUNDIDAD
	material_lector.render_priority = 127
	lector.material_override = material_lector
	lector.visible = false
	var calibracion := _plano(escena, -2.5, false)
	calibracion.scale = Vector3.ONE * 0.25
	calibracion.material_override = material_fondo
	calibracion.visible = false
	return {"viewport":viewport, "material":material, "lector":lector, "calibracion":calibracion, "velo":velo}

func _plano(padre: Node3D, distancia: float, invertir: bool) -> MeshInstance3D:
	var plano := MeshInstance3D.new()
	var malla := QuadMesh.new()
	malla.size = Vector2(2, 2)
	malla.flip_faces = invertir
	plano.mesh = malla
	plano.position.z = distancia
	plano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(plano)
	return plano

func _asentar(cantidad: int) -> void:
	for i in cantidad: await process_frame
	RenderingServer.force_draw(false, 0.0)

func _diferencia(primera: Image, segunda: Image) -> int:
	if primera.get_size() != segunda.get_size(): return 255
	primera = primera.duplicate() as Image
	segunda = segunda.duplicate() as Image
	primera.convert(Image.FORMAT_RGBA8)
	segunda.convert(Image.FORMAT_RGBA8)
	var a := primera.get_data()
	var b := segunda.get_data()
	if a.size() != b.size(): return 255
	var maximo := 0
	for i in a.size(): maximo = maxi(maximo, absi(int(a[i]) - int(b[i])))
	return maximo

func _exigir(valor: bool, mensaje: String) -> bool:
	if valor: return true
	push_error(mensaje)
	quit(1)
	return false
