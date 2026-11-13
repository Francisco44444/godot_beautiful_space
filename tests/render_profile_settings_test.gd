extends SceneTree

## El perfil es una preferencia local: persiste, funciona en ambos menús y se
## reaplica al estirar la ventana, sin cambiar LOD, MSAA ni añadir un proceso.
const Ajustes = preload("res://scripts/game_settings.gd")
var ajustes: Node
var mundo: Node
var anteriores := {}
var ruta := ""

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	ruta = "res://generated/reviews/perfiles-%d.cfg" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute("res://generated/reviews")
	var nuevos := Ajustes.new()
	nuevos.settings_path = ruta
	if not exigir(nuevos.render_profile == 0,"Una instalación nueva pierde la imagen nativa."): return
	nuevos.set_render_profile(2)
	var recargados := Ajustes.new()
	recargados.settings_path = ruta
	recargados._load_settings()
	if not exigir(recargados.render_profile == 2,"No persiste la elección de fluidez."): return
	var config := ConfigFile.new()
	config.load(ruta)
	config.erase_section_key("graphics","render_profile")
	config.save(ruta)
	recargados._load_settings()
	if not exigir(recargados.render_profile == 0,"Una instalación anterior deja de usar resolución nativa."): return
	config.set_value("graphics","render_profile",87)
	config.save(ruta)
	recargados._load_settings()
	if not exigir(recargados.render_profile == 0,"Un perfil guardado inválido no vuelve a nativo."): return
	nuevos.free()
	recargados.free()
	ajustes = root.get_node("GameSettings")
	anteriores = {"ruta":ajustes.settings_path,"perfil":ajustes.render_profile,"resolucion":ajustes.resolution,"vsync":ajustes.vsync_enabled,"lod":ajustes.lod_distance_metres}
	ajustes.settings_path = ruta
	ajustes.set_render_profile(0,false)
	ajustes.set_vsync_enabled(false,false)
	for nombre in ["InventoryManager","ExplorationManager"]: root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 8: await process_frame
	paused = false
	var umbral := root.mesh_lod_threshold
	var msaa := root.msaa_3d
	var hud := mundo.get_node("HUD")
	hud._set_settings_open(true)
	var z := hud.get_node("SettingsOverlay").find_child("RenderProfileSelector",true,false) as OptionButton
	if not exigir(z != null and z.item_count == 3 and z.selected == 0,"El panel Z no refleja los tres perfiles y el valor nativo."): return
	z.select(1)
	z.item_selected.emit(1)
	if not exigir(ajustes.render_profile == 1,"El selector Z no aplica la elección."): return
	hud._set_settings_open(false)
	var pausa: Node = hud.pause_menu
	pausa.set_open(true)
	pausa._show_graphics()
	var esc := pausa.find_child("RenderProfileSelector",true,false) as OptionButton
	if not exigir(esc != null and esc.selected == 1,"Gráficos no refleja el perfil del panel Z."): return
	esc.select(2)
	esc.item_selected.emit(2)
	if not exigir(ajustes.render_profile == 2 and z.selected == 2,"Los menús no comparten la elección de fluidez."): return
	config.load(ruta)
	if not exigir(int(config.get_value("graphics","render_profile",-1)) == 2,"El menú no persiste el perfil."): return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(2560,1440))
		for i in 5: await process_frame
		if not exigir(is_equal_approx(root.scaling_3d_scale,2.0/3.0) and root.scaling_3d_mode in [1,3],"El perfil no llega al Viewport real a 2560×1440."): return
		DisplayServer.window_set_size(Vector2i(1280,720))
		for i in 5: await process_frame
		if not exigir(root.scaling_3d_scale == 1.0 and root.scaling_3d_mode == 0 and ajustes.render_profile == 2,"Estirar la ventana ignora el mínimo interno o borra la preferencia."): return
		DisplayServer.window_set_size(Vector2i(1920,1080))
		for i in 5: await process_frame
		if not exigir(is_equal_approx(root.scaling_3d_scale,2.0/3.0) and root.scaling_3d_mode in [1,3],"La reconstrucción no se recupera al volver a ampliar."): return
	else:
		if not exigir(root.scaling_3d_scale == 1.0 and root.scaling_3d_mode == 0,"Un proceso sin GPU intenta reconstruir la imagen."): return
	if not exigir(root.mesh_lod_threshold == umbral and root.msaa_3d == msaa and not ajustes.is_processing(),"El perfil cambia detalle/antialiasing o añade un proceso por fotograma."): return
	pausa._show_sound()
	for i in 2: await process_frame
	ajustes.set_render_profile(0,false)
	if not exigir(z.selected == 0 and root.scaling_3d_scale == 1.0 and root.scaling_3d_mode == 0,"No se recupera nativo o queda una conexión de interfaz liberada."): return
	ajustes.set_render_profile(2,false)
	ajustes.reset_defaults(false)
	if not exigir(ajustes.render_profile == 0 and z.selected == 0,"Restaurar valores no recupera nativo."): return
	pausa.set_open(false)
	hud._set_settings_open(false)
	mundo.queue_free()
	for i in 3: await process_frame
	restaurar()
	print("RENDER PROFILE SETTINGS TEST OK: persistencia, instalaciones anteriores, Z/Gráficos, tamaño real, mínimo interno y retorno nativo; LOD/MSAA intactos.")
	quit(0)

func restaurar() -> void:
	paused = false
	if not anteriores.is_empty():
		ajustes.settings_path = anteriores.ruta
		ajustes.set_resolution(anteriores.resolucion,false)
		ajustes.set_vsync_enabled(anteriores.vsync,false)
		ajustes.set_lod_distance(anteriores.lod,false)
		ajustes.set_render_profile(anteriores.perfil,false)
	if not ruta.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))

func exigir(condicion: bool,mensaje: String) -> bool:
	if condicion: return true
	restaurar()
	push_error("RENDER PROFILE SETTINGS TEST FAIL: "+mensaje)
	quit(1)
	return false
