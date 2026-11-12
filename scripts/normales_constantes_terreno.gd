extends Node

## Terrain3D conserva su shader completo. Sólo se especializa cuando sus mapas
## normales, incluidos los mipmaps, son exactamente el mismo color constante.
const LECTURA := "textureGrad(_texture_array_normal, vec3(id_uv, float(id)), id_dd.xy, id_dd.zw)"
const MAPEO := "NORMAL_MAP = fma(normalize(mat.normal_rough.xzy), vec3(0.5), vec3(0.5));"
const PROFUNDIDAD := "NORMAL_MAP_DEPTH = mat.normal_map_depth;"
const VALOR := "vec4(0.4980392156862745, 0.4980392156862745, 1.0, 1.0)"

var _terreno: Terrain3D
var _material: Terrain3DMaterial
var _activos: Terrain3DAssets
var _anterior: Shader
var _especializado: Shader
var _codigo_verificado := ""
var _pendiente := false
var _cambiando := false
var _aplicado := false
var revisiones := 0
var capas_comprobadas := 0
var motivo := "sin iniciar"
var preparacion_ms := 0.0
var _habilitado := true
var _configurado := false


func iniciar(terreno: Terrain3D) -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus": return
	if terreno == null or terreno.material == null or terreno.assets == null: return
	_terreno = terreno
	_material = terreno.material
	_activos = terreno.assets
	# Un shader personalizado pertenece a quien lo instaló; no se sustituye.
	if _material.is_shader_override_enabled(): return
	_anterior = _material.get_shader_override()
	_configurado = true
	_activos.textures_changed.connect(_solicitar_revision)
	_material.changed.connect(_solicitar_revision)
	_solicitar_revision()


func _solicitar_revision() -> void:
	if _cambiando or not _configurado: return
	_cambiando = true
	_restaurar()
	_cambiando = false
	if not _habilitado: return
	if _pendiente: return
	_pendiente = true
	# Las matrices y las texturas privadas de Terrain3D se suben al dibujar.
	# Antes del primer dibujo el recurso existe pero sus uniformes aún no están.
	RenderingServer.frame_post_draw.connect(_revisar, CONNECT_ONE_SHOT)


func _revisar() -> void:
	_pendiente = false
	if not is_inside_tree() or not _habilitado or _material == null or _activos == null: return
	if _material.is_shader_override_enabled(): return
	var inicio := Time.get_ticks_usec()
	revisiones += 1
	capas_comprobadas = 0
	var fuente := RenderingServer.shader_get_code(_material.get_shader_rid())
	var codigo := crear_codigo(fuente)
	motivo = "estructura %s/%s/%s" % [fuente.count(LECTURA), fuente.count(MAPEO), fuente.count(PROFUNDIDAD)]
	if codigo.is_empty(): return
	motivo = "textura GPU"
	var textura: Variant = RenderingServer.material_get_param(_material.get_material_rid(), "_texture_array_normal")
	if not textura is RID or not (textura as RID).is_valid(): return
	var dispositivo := RenderingServer.get_rendering_device()
	var textura_rd := RenderingServer.texture_get_rd_texture(textura)
	if dispositivo == null or not dispositivo.texture_is_valid(textura_rd): return
	var formato := dispositivo.texture_get_format(textura_rd)
	if formato.texture_type != RenderingDevice.TEXTURE_TYPE_2D_ARRAY: return
	var cantidad := formato.array_layers
	var profundidades: Variant = RenderingServer.material_get_param(_material.get_material_rid(), "_texture_normal_depth_array")
	motivo = "profundidades GPU"
	if not profundidades is PackedFloat32Array or not profundidades_nulas(profundidades, cantidad): return
	var referencias := {}
	for capa in cantidad:
		var imagen := RenderingServer.texture_2d_layer_get(textura, capa)
		motivo = "imagen %s formato %s mipmaps %s" % [capa, imagen.get_format() if imagen != null else -1, imagen.get_mipmap_count() if imagen != null else -1]
		if not imagen_constante(imagen, referencias): return
		capas_comprobadas += 1
	_anterior = _material.get_shader_override()
	_especializado = Shader.new()
	_codigo_verificado = codigo
	_especializado.code = codigo
	_cambiando = true
	_material.set_shader_override(_especializado)
	_material.enable_shader_override(true)
	_aplicado = true
	preparacion_ms = float(Time.get_ticks_usec() - inicio) / 1000.0
	motivo = "activo"
	_cambiando = false


func esta_activo() -> bool:
	return _aplicado and _material != null and _material.is_shader_override_enabled() and _material.get_shader_override() == _especializado


func conserva_geometria(terreno: Terrain3D) -> bool:
	# La oclusión puede compartir este shader: sólo cambia fragment(), nunca
	# alturas, agujeros ni vertex(). Una edición posterior deja de ser válida.
	return terreno == _terreno and terreno.material == _material and esta_activo() and _especializado.code == _codigo_verificado


func establecer_habilitado(valor: bool) -> void:
	if _habilitado == valor: return
	_habilitado = valor
	_solicitar_revision()


func _restaurar() -> void:
	if _aplicado and _material != null and _material.get_shader_override() == _especializado:
		_material.enable_shader_override(false)
		_material.set_shader_override(_anterior)
	_aplicado = false
	_especializado = null
	_codigo_verificado = ""


func _exit_tree() -> void:
	_cambiando = true
	if RenderingServer.frame_post_draw.is_connected(_revisar): RenderingServer.frame_post_draw.disconnect(_revisar)
	if _activos != null and _activos.textures_changed.is_connected(_solicitar_revision): _activos.textures_changed.disconnect(_solicitar_revision)
	if _material != null and _material.changed.is_connected(_solicitar_revision): _material.changed.disconnect(_solicitar_revision)
	_restaurar()


static func profundidades_nulas(valores: PackedFloat32Array, cantidad: int) -> bool:
	if cantidad <= 0 or cantidad > 32 or valores.size() != cantidad: return false
	for valor in valores:
		if valor != 0.0: return false
	return true


static func imagen_constante(imagen: Image, referencias: Dictionary) -> bool:
	if imagen == null or imagen.is_empty(): return false
	if imagen.is_compressed():
		imagen = imagen.duplicate() as Image
		if imagen.decompress() != OK: return false
	if imagen.get_format() != Image.FORMAT_RGBA8: return false
	var clave := Vector3i(imagen.get_width(), imagen.get_height(), int(imagen.has_mipmaps()))
	if not referencias.has(clave):
		var referencia := Image.create(clave.x, clave.y, clave.z == 1, Image.FORMAT_RGBA8)
		referencia.fill(Color(127.0 / 255.0, 127.0 / 255.0, 1.0, 1.0))
		referencias[clave] = referencia.get_data()
	# Se comparan todos los bytes: un píxel distinto o un mipmap modificado
	# recuperan el shader original, aunque la profundidad normal siga a cero.
	return imagen.get_data() == referencias[clave]


static func crear_codigo(codigo: String) -> String:
	# Las coincidencias exactas evitan aplicar esta transformación a otra
	# versión del shader o a una personalización del usuario.
	if codigo.count(LECTURA) != 2 or codigo.count(MAPEO) != 1 or codigo.count(PROFUNDIDAD) != 1: return ""
	return codigo.replace(LECTURA, VALOR).replace(MAPEO, "NORMAL = normalize(NORMAL);").replace(PROFUNDIDAD, "")
