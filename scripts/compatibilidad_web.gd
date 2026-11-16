extends RefCounted

## std140 reserva 16 bytes por escalar de un array: 1024 enteros ya ocupan
## todo el bloque de 16 KiB que garantiza WebGL2. Agruparlos de cuatro en
## cuatro conserva cada índice y reduce esa tabla a 4 KiB sin perder relieve.
const MAPA := "uniform int _region_map[1024];"
const MAPA_COMPACTO := "uniform ivec4 _region_map[256];"
const UBICACIONES := "uniform vec2 _region_locations[1024];"
const MAX_REGIONES := 128

static func compactar_mapa(codigo: String) -> String:
	if codigo.count(MAPA) != 1: return ""
	var resultado := codigo.replace(MAPA, MAPA_COMPACTO)
	var lectura := RegEx.new()
	lectura.compile("_region_map\\[([^\\[\\]]+)\\]")
	# La declaración nueva no coincide con una lectura: se transforma antes
	# de insertar el helper para no reescribirlo de manera recursiva.
	resultado = resultado.replace(MAPA_COMPACTO, "// TABLA_WEB_COMPACTA")
	resultado = lectura.sub(resultado, "leer_region_web($1)", true)
	var helper := MAPA_COMPACTO + "\nint leer_region_web(int indice) { return _region_map[indice / 4][indice % 4]; }"
	return resultado.replace("// TABLA_WEB_COMPACTA", helper)

static func codigo_terreno(codigo: String, regiones: int) -> String:
	if regiones < 1 or regiones > MAX_REGIONES or codigo.count(UBICACIONES) != 1: return ""
	return compactar_mapa(codigo).replace(UBICACIONES, "uniform vec2 _region_locations[128];")

static func instalar(terreno: Terrain3D) -> bool:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility": return false
	var material := terreno.material
	if material.is_shader_override_enabled(): return false
	var fuente := RenderingServer.shader_get_code(material.get_shader_rid())
	var regiones: int = terreno.data.get_region_locations().size()
	var codigo := codigo_terreno(fuente, regiones)
	if codigo.is_empty():
		push_error("No se pudo adaptar el terreno a WebGL: regiones=%s, fuente=%s" % [regiones, fuente.length()])
		return false
	var shader := Shader.new()
	shader.code = codigo
	material.set_shader_override(shader)
	material.enable_shader_override(true)
	print("TERRENO WEB: %s regiones, tabla compacta de 4 KiB." % regiones)
	return true
