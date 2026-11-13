extends SceneTree

const PERFILES = preload("res://scripts/perfiles_render.gd")

func _init() -> void: call_deferred("_probar")

func _probar() -> void:
	var lod_anterior := root.mesh_lod_threshold
	var msaa_anterior := root.msaa_3d
	var escala_anterior := root.scaling_3d_scale
	var modo_anterior := root.scaling_3d_mode
	for metal in [true,false]:
		if not _exigir(_es_nativo(PERFILES.resolver(0,Vector2i(2560,1440),"forward_plus",metal),0,Vector2i(2560,1440)), "El perfil nativo modifica la resolución o activa reconstrucción."): return
	var equilibrado := PERFILES.resolver(1,Vector2i(2560,1440),"forward_plus",true)
	if not _exigir(equilibrado.profile == 1 and equilibrado.scale == 0.77 and equilibrado.mode == 3 and equilibrado.input_expected == Vector2i(1971,1108), "Equilibrado no resuelve 0,77 con Metal espacial y tamaño interno esperado."): return
	var fluido := PERFILES.resolver(2,Vector2i(2560,1440),"forward_plus",true)
	if not _exigir(fluido.profile == 2 and fluido.scale == 2.0/3.0 and fluido.mode == 3 and fluido.input_expected == Vector2i(1706,960), "Más fluido no conserva dos tercios y su entrada esperada."): return
	for perfil in [1,2]:
		var reserva := PERFILES.resolver(perfil,Vector2i(2560,1440),"forward_plus",false)
		if not _exigir(reserva.mode == 1 and reserva.scale < 1.0, "Sin Metal espacial no se elige FSR1."): return
		for renderer in ["mobile","gl_compatibility","headless","", "desconocido"]:
			if not _exigir(_es_nativo(PERFILES.resolver(perfil,Vector2i(2560,1440),renderer,true),perfil,Vector2i(2560,1440)), "Un renderizador no admitido recibe reconstrucción."): return
		for salida in [Vector2i(1280,720),Vector2i(800,600),Vector2i(1920,720),Vector2i(1280,1080)]:
			if not _exigir(_es_nativo(PERFILES.resolver(perfil,salida,"forward_plus",true),perfil,salida), "El mínimo fuerza sobremuestreo o pierde la preferencia guardada."): return
		var limitado := PERFILES.resolver(perfil,Vector2i(1600,900),"forward_plus",true)
		if not _exigir(limitado.profile == perfil and limitado.scale == 0.8 and limitado.input_expected == Vector2i(1280,720) and limitado.mode == 3, "El mínimo permite una entrada menor de 1280 por 720."): return
	for salida in [Vector2i.ZERO,Vector2i(1920,0),Vector2i(-1,1080),Vector2i(1920,-5)]:
		if not _exigir(_es_nativo(PERFILES.resolver(2,salida,"forward_plus",true),2,Vector2i.ZERO), "Una salida inválida activa reconstrucción o un tamaño interno inválido."): return
	for id in [-123,-1,3,999999]:
		if not _exigir(_es_nativo(PERFILES.resolver(id,Vector2i(2560,1440),"forward_plus",true),0,Vector2i(2560,1440)), "Un identificador inválido no recupera Nativo."): return
	# La misma preferencia vuelve a reconstruir después de reducir y ampliar
	# la ventana; el caso pequeño no debe reescribirla como Nativo.
	for salida in [Vector2i(2560,1440),Vector2i(1280,720),Vector2i(3840,2160)]:
		var resultado := PERFILES.resolver(2,salida,"forward_plus",true)
		if not _exigir(resultado.profile == 2 and (resultado.mode == 0) == (salida == Vector2i(1280,720)), "Redimensionar pierde el perfil elegido o deja un modo improcedente."): return
	var casos := 0
	for ancho in range(1279,1760,7):
		for alto in range(719,1000,11):
			for perfil in [1,2]:
				var salida := Vector2i(ancho,alto)
				var resultado := PERFILES.resolver(perfil,salida,"forward_plus",true)
				if resultado.mode != 0:
					if not _exigir(resultado.input_expected.x >= 1280 and resultado.input_expected.y >= 720 and resultado.input_expected.x <= ancho and resultado.input_expected.y <= alto and resultado.scale < 1.0, "El redondeo de una salida impar incumple el mínimo o sobremuestrea."): return
				casos += 1
	var copia := PERFILES.resolver(1,Vector2i(2560,1440),"forward_plus",true)
	copia.scale = 0.1
	copia.input_expected = Vector2i.ONE
	if not _exigir(PERFILES.resolver(1,Vector2i(2560,1440),"forward_plus",true) == equilibrado, "El resultado comparte estado mutable entre llamadas."): return
	if not _exigir(root.mesh_lod_threshold == lod_anterior and root.msaa_3d == msaa_anterior and root.scaling_3d_scale == escala_anterior and root.scaling_3d_mode == modo_anterior, "Resolver modifica LOD, MSAA o Viewport en lugar de devolver datos."): return
	for clave in equilibrado:
		if not _exigir(clave in ["profile","scale","mode","input_expected"], "El perfil mezcla ajustes ajenos a la reconstrucción."): return
	print("RENDER PROFILES TEST OK: nativo, 0.77, dos tercios, Metal/FSR1, reservas, ids, salidas inválidas, redimensionado y %d límites impares; sin cambios en LOD, MSAA o Viewport." % casos)
	quit(0)

func _es_nativo(resultado: Dictionary, perfil: int, salida: Vector2i) -> bool:
	return resultado.profile == perfil and resultado.scale == 1.0 and resultado.mode == 0 and resultado.input_expected == salida

func _exigir(condicion: bool, texto: String) -> bool:
	if condicion: return true
	push_error(texto)
	quit(1)
	return false
