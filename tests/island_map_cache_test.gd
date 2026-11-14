extends SceneTree

## El marcador sigue cada frame mientras la cartografía conserva sus comandos.
## No depende de los FPS del equipo ni de que headless disponga de una GPU.
class MapaMedido:
	extends "res://scripts/island_map.gd"
	var marcadores_dibujados := 0
	var forzar_defecto := false
	func _draw() -> void:
		marcadores_dibujados += 1
		super._draw()
	func _process(delta: float) -> void:
		super._process(delta)
		if forzar_defecto: _invalidate_cartography()

class Marea:
	extends Node
	var tide_normalized := 0.5

class Heroe:
	extends Node3D
	var rumbo := Vector2.UP
	func get_facing_direction_xz() -> Vector2: return rumbo

class Gruta:
	extends Node3D
	var spec := {"name":"Gruta de prueba"}

var mapa: MapaMedido
var vista: SubViewport
var heroe: Heroe
var marea: Marea

func _init() -> void: call_deferred("_run_test")

func _run_test() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for singleton in ["InventoryManager","ExplorationManager"]:
		root.get_node(singleton).set("autosave_enabled",false)
	vista = SubViewport.new()
	vista.size = Vector2i(900,720)
	vista.disable_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	heroe = Heroe.new()
	root.add_child(heroe)
	marea = Marea.new()
	root.add_child(marea)
	mapa = MapaMedido.new()
	mapa.size = Vector2(320,320)
	vista.add_child(mapa)
	mapa.player = heroe
	mapa.island_environment = marea
	mapa.forzar_defecto = "--break-map-cache" in OS.get_cmdline_user_args()
	await _fotogramas(4)
	var fondo := mapa._static_redraw_count
	var marcadores := mapa.marcadores_dibujados
	for i in 30:
		heroe.position.x += 20
		heroe.rumbo = Vector2.UP.rotated(float(i)*0.1)
		await process_frame
	await _fotogramas(2)
	if mapa._static_redraw_count != fondo:
		_fail("Moverse y girar obliga a reconstruir costa, biomas y caminos."); return
	if mapa.marcadores_dibujados <= marcadores+20:
		_fail("El marcador dejó de actualizarse con el héroe."); return
	if mapa._player_map_direction().distance_to(heroe.rumbo)>0.001:
		_fail("El mapa no refleja el rumbo actual."); return
	var punto_heroe:=Vector2(heroe.position.x,heroe.position.z)
	var posicion:=mapa._world_to_map(punto_heroe)
	if posicion.distance_to(mapa._rectangulo_mapa().get_center())>0.01:
		_fail("El minimapa local no mantiene centrado al héroe.");return
	var punto_textura:Vector2=mapa._punto_atlas(punto_heroe)*mapa._imagen_atlas.scale+mapa._imagen_atlas.position+mapa._ventana.position
	if punto_textura.distance_to(posicion)>0.01:
		_fail("El atlas retenido se desplaza en dirección incorrecta respecto al héroe.");return
	if mapa._world_to_map(punto_heroe+Vector2(100,0)).x<=posicion.x:
		_fail("La proyección local pierde la orientación este.");return
	# La pequeña variación de marea es subpíxel; el cambio acumulado invalida.
	marea.tide_normalized += 0.007
	await _fotogramas(4)
	if mapa._static_redraw_count != fondo:
		_fail("La marea subpíxel reconstruye toda la cartografía."); return
	marea.tide_normalized += 0.07
	await _fotogramas(4)
	fondo += 1
	if mapa._static_redraw_count != fondo:
		_fail("El mapa no conserva la marea o redibuja más de una vez."); return
	mapa.full_map = true
	await _fotogramas(4)
	fondo += 1
	if mapa._static_redraw_count != fondo or not mapa._cached_full_map:
		_fail("Ampliar el mapa no renueva rótulos y relieve."); return
	mapa.size = Vector2(900,720)
	await _fotogramas(4)
	# Control puede redibujar también al aplicar sus anclas tras el resize.
	if mapa._static_redraw_count < fondo+1 or mapa._static_redraw_count > fondo+2 or mapa._cached_size != mapa.size:
		_fail("El mapa no renueva su escala al cambiar de tamaño."); return
	fondo = mapa._static_redraw_count
	await _fotogramas(10)
	if mapa._static_redraw_count != fondo:
		_fail("El mapa sigue reconstruyéndose una vez terminada la ampliación."); return
	var gruta := Gruta.new()
	gruta.position = Vector3(-2500,30,1100)
	root.add_child(gruta)
	gruta.add_to_group("explorable_cave")
	await _fotogramas(4)
	fondo += 1
	if mapa._static_redraw_count != fondo:
		_fail("Las grutas creadas tras el HUD no aparecen en el mapa."); return
	mapa.hide()
	marcadores = mapa.marcadores_dibujados
	marea.tide_normalized = 0.9
	await _fotogramas(10)
	if mapa._static_redraw_count != fondo or mapa.marcadores_dibujados != marcadores:
		_fail("El mapa oculto sigue consumiendo dibujos."); return
	mapa.show()
	await _fotogramas(4)
	if mapa._static_redraw_count < fondo+1 or mapa._static_redraw_count > fondo+2 or mapa._cached_tide != marea.tide_normalized or mapa.marcadores_dibujados <= marcadores:
		_fail("El mapa no se actualiza al volver a abrirlo."); return
	# La carta mantiene la misma escala en ambos ejes y cabe en una ventana
	# pequeña: el relieve no debe estirarse ni quedar cortado fuera de pantalla.
	var centro:=mapa._world_to_map(Vector2.ZERO)
	var este:=mapa._world_to_map(Vector2(1000,0)).distance_to(centro)
	var sur:=mapa._world_to_map(Vector2(0,1000)).distance_to(centro)
	if absf(este-sur)>0.001:
		_fail("La carta deforma distancias al cambiar la proporción de ventana.");return
	var gruta_vecina:=Gruta.new()
	gruta_vecina.position=gruta.position
	root.add_child(gruta_vecina)
	gruta_vecina.add_to_group("explorable_cave")
	await _fotogramas(4)
	for i in mapa._rotulos_ocupados.size():
		for j in i:
			if mapa._rotulos_ocupados[i].intersects(mapa._rotulos_ocupados[j]):
				_fail("Los rótulos de lugares y grutas se superponen.");return
	vista.size=Vector2i(640,480)
	mapa._ajustar_a_ventana()
	await _fotogramas(4)
	if not Rect2(Vector2.ZERO,Vector2(vista.size)).encloses(mapa.get_rect()):
		_fail("La carta completa queda fuera de una ventana pequeña.");return
	for i in mapa._rotulos_ocupados.size():
		for j in i:
			if mapa._rotulos_ocupados[i].intersects(mapa._rotulos_ocupados[j]):
				_fail("Los rótulos se superponen al reducir la ventana.");return
	print("ISLAND MAP CACHE PASS: minimapa local con atlas retenido, rumbo y escala uniforme; marea, escala, grutas y reapertura correctas.")
	quit(0)

func _fotogramas(cantidad: int) -> void:
	for i in cantidad: await process_frame

func _fail(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
