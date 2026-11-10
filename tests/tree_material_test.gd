extends SceneTree

## Sólo una imagen demostrablemente opaca puede prescindir del recorte de hojas.
var vegetacion: VegetationScatter

class TexturaConImagen:
	extends Texture2D
	var imagen: Image
	var soporte: ImageTexture
	var lecturas := 0
	func _init(datos: Image) -> void:
		imagen = datos
		soporte = ImageTexture.create_from_image(datos)
	func _get_image() -> Image:
		lecturas += 1
		return imagen
	func _get_width() -> int: return imagen.get_width()
	func _get_height() -> int: return imagen.get_height()
	func _get_rid() -> RID: return soporte.get_rid()

func _init() -> void: call_deferred("_comprobar")
func _comprobar() -> void:
	vegetacion = VegetationScatter.new()
	var opaca := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	opaca.fill(Color(0.4, 0.2, 0.1, 1))
	var hueco := opaca.duplicate() as Image
	hueco.set_pixel(15, 15, Color(0.4, 0.2, 0.1, 0))
	var semitransparente := opaca.duplicate() as Image
	semitransparente.set_pixel(0, 0, Color(0.4, 0.2, 0.1, 0.5))
	var rgb := Image.create(4, 4, false, Image.FORMAT_RGB8)
	rgb.fill(Color(0.3, 0.5, 0.1))
	var textura_opaca := TexturaConImagen.new(opaca)
	var textura_hueco := TexturaConImagen.new(hueco)
	var textura_semi := ImageTexture.create_from_image(semitransparente)
	var desconocida := PlaceholderTexture2D.new()
	var cache := {}
	if not vegetacion._textura_totalmente_opaca(textura_opaca, cache): _fallar("Se pierde la ruta opaca de una imagen RGBA completamente sólida."); return
	if not vegetacion._textura_totalmente_opaca(textura_opaca, cache) or textura_opaca.lecturas != 1: _fallar("La caché vuelve a leer la misma textura opaca."); return
	if vegetacion._textura_totalmente_opaca(textura_hueco, cache): _fallar("Se ignora un hueco de un solo píxel al final de la textura."); return
	if vegetacion._textura_totalmente_opaca(textura_hueco, cache) or textura_hueco.lecturas != 1: _fallar("La caché vuelve a leer una textura recortada."); return
	if vegetacion._textura_totalmente_opaca(textura_semi, cache): _fallar("Una textura con alfa parcial se trata como opaca."); return
	if not vegetacion._textura_totalmente_opaca(ImageTexture.create_from_image(rgb), cache): _fallar("Una textura RGB sin alfa pierde la ruta opaca."); return
	if vegetacion._textura_totalmente_opaca(desconocida, cache) or vegetacion._textura_totalmente_opaca(null, cache): _fallar("Una textura desconocida elimina el recorte por defecto."); return
	if textura_opaca.get_image().get_data() != opaca.get_data() or textura_hueco.get_image().get_data() != hueco.get_data(): _fallar("Detectar opacidad modifica los píxeles."); return
	for caso in [{"ruta":"Bark_NormalTree.png", "opaca":true}, {"ruta":"Bark_TwistedTree.png", "opaca":true}, {"ruta":"Leaves_NormalTree_C.png", "opaca":false}, {"ruta":"Leaf_Pine_C.png", "opaca":false}, {"ruta":"Leaves_TwistedTree_C.png", "opaca":false}]:
		var textura: Texture2D = load("res://assets/quaternius/store_bundle/glTF/" + String(caso.ruta))
		var datos := textura.get_image().get_data()
		if vegetacion._textura_totalmente_opaca(textura, cache) != bool(caso.opaca): _fallar("Clasificación incorrecta del albedo importado " + String(caso.ruta)); return
		if textura.get_image().get_data() != datos: _fallar("La detección altera el albedo importado."); return
	vegetacion.set("_snow_tree_offset", 1)
	vegetacion.set("_mystery_tree_offset", 2)
	var mallas: Array[Mesh] = []
	for bioma in 3:
		var malla := ArrayMesh.new()
		for superficie in 2:
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().surface_get_arrays(0))
			var material := StandardMaterial3D.new()
			material.resource_name = "Bark" if superficie == 0 else "Leaves"
			material.albedo_texture = textura_opaca if superficie == 0 else textura_hueco
			malla.surface_set_material(superficie, material)
		mallas.append(malla)
	vegetacion.set("_tree_meshes", mallas)
	vegetacion._apply_tree_wind_materials()
	if not _materiales(mallas, textura_opaca, textura_hueco, true): return
	vegetacion.set_storm_strength(0.75)
	for material: ShaderMaterial in vegetacion.get("_tree_wind_materials"):
		if not is_equal_approx(float(material.get_shader_parameter("storm_strength")), 0.75) or not is_equal_approx(float(material.get_shader_parameter("storm_bend")), vegetacion.get_tree_storm_bend()):
			_fallar("Una variante de material pierde el viento de tormenta."); return
	# La caché pertenece a una reconstrucción: una recarga de textura no puede
	# conservar para siempre la clasificación de la versión anterior del recurso.
	textura_opaca.imagen = hueco
	await process_frame
	if textura_opaca.get_image().get_data() != hueco.get_data(): _fallar("El control de recarga no ha cambiado realmente la textura."); return
	vegetacion._apply_tree_wind_materials()
	if not _materiales(mallas, textura_opaca, textura_hueco, false): return
	textura_opaca.imagen = opaca
	await process_frame
	if textura_opaca.get_image().get_data() != opaca.get_data(): _fallar("El control de restauración no ha repuesto realmente la textura."); return
	vegetacion._apply_tree_wind_materials()
	if not _materiales(mallas, textura_opaca, textura_hueco, true): return
	vegetacion.free()
	print("TREE MATERIAL TEST OK: alfa completo, hueco de un píxel, RGB, textura desconocida, cinco albedos importados, tres biomas, tormenta y recarga.")
	quit(0)

func _materiales(mallas: Array[Mesh], corteza: Texture2D, hojas: Texture2D, corteza_opaca: bool) -> bool:
	if int(vegetacion.get("_tree_wind_material_count")) != 6 or vegetacion.get("_tree_wind_materials").size() != 6:
		_fallar("Reconstruir materiales pierde superficies o acumula materiales viejos."); return false
	var shader_hojas: Shader = (mallas[0].surface_get_material(1) as ShaderMaterial).shader
	var shader_corteza: Shader = (mallas[0].surface_get_material(0) as ShaderMaterial).shader
	if (shader_hojas != shader_corteza) != corteza_opaca:
		_fallar("La selección de variantes no distingue corteza opaca y hojas con huecos."); return false
	if corteza_opaca and shader_corteza.code == shader_hojas.code:
		_fallar("Se crean dos shaders distintos con el mismo programa de recorte."); return false
	for bioma in mallas.size():
		for superficie in 2:
			var material := mallas[bioma].surface_get_material(superficie) as ShaderMaterial
			if material == null or material.shader != (shader_corteza if superficie == 0 else shader_hojas):
				_fallar("Las variantes no se comparten entre biomas y superficies equivalentes."); return false
			if material.get_shader_parameter("albedo_texture") != (corteza if superficie == 0 else hojas):
				_fallar("Cambiar la variante cambia el albedo."); return false
			if float(material.get_shader_parameter("tint_mode")) != float(bioma) or float(material.get_shader_parameter("leaf_factor")) != float(superficie):
				_fallar("Se pierde el tinte del bioma o el movimiento de hojas y corteza."); return false
	return true

func _fallar(mensaje: String) -> void:
	if is_instance_valid(vegetacion): vegetacion.free()
	push_error(mensaje)
	quit(1)
