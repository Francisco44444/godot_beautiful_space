extends SceneTree

const Ajustes = preload("res://scripts/game_settings.gd")
var _anteriores := {}
var _ruta := ""

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	_ruta = "res://generated/reviews/prueba-vsync-%d.cfg"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute("res://generated/reviews")
	var ajustes := Ajustes.new()
	ajustes.settings_path = _ruta
	if not ajustes.vsync_enabled: fallar("Una instalación nueva no activa VSync por defecto."); return
	ajustes.set_vsync_enabled(false)
	var recargados := Ajustes.new()
	recargados.settings_path = _ruta
	recargados._load_settings()
	if recargados.vsync_enabled: fallar("Desactivar VSync no persiste al cargar los ajustes."); return
	var archivo := ConfigFile.new()
	if archivo.load(_ruta)!=OK or bool(archivo.get_value("video","vsync_enabled",true)): fallar("El archivo no conserva la elección de VSync."); return
	archivo.erase_section_key("video","vsync_enabled")
	archivo.save(_ruta)
	recargados._load_settings()
	if not recargados.vsync_enabled: fallar("Una instalación antigua pierde la sincronización predeterminada."); return
	recargados.set_vsync_enabled(false,false)
	recargados.reset_defaults(false)
	if not recargados.vsync_enabled: fallar("Restaurar valores no recupera VSync."); return
	ajustes.free()
	recargados.free()
	var globales := root.get_node("GameSettings")
	_anteriores = {"ruta":globales.settings_path,"vsync":globales.vsync_enabled,"resolucion":globales.resolution,"lod":globales.lod_distance_metres,"nombre":globales.player_name,"personaje":globales.character_index}
	globales.settings_path = _ruta
	globales.reset_defaults(false)
	for nombre in ["InventoryManager","ExplorationManager"]: root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").call("bind_world",null)
	for fotograma in 8: await process_frame
	paused = false
	var hud := mundo.get_node("HUD")
	hud.call("_set_settings_open",true)
	var z := hud.get_node("SettingsOverlay").find_child("VSyncToggle",true,false) as CheckButton
	if z==null or not z.button_pressed: fallar("El panel Z no refleja VSync activada."); return
	z.button_pressed = false
	if globales.vsync_enabled: fallar("El control Z no desactiva VSync."); return
	if not comprobar_modo(false): return
	hud.call("_set_settings_open",false)
	var pausa: Node = hud.get("pause_menu")
	pausa.set_open(true)
	pausa.call("_show_graphics")
	var esc := pausa.find_child("VSyncToggle",true,false) as CheckButton
	if esc==null or esc.button_pressed: fallar("Gráficos no refleja la elección del panel Z."); return
	esc.button_pressed = true
	if not globales.vsync_enabled or not z.button_pressed: fallar("Los dos menús no comparten el mismo ajuste."); return
	var estado := hud.get_node("SettingsOverlay").find_child("SettingsStatus",true,false) as Label
	if estado==null or estado.text!="VSync activada": fallar("El panel Z conserva un mensaje de VSync antiguo tras cambiarla desde Gráficos."); return
	if not comprobar_modo(true): return
	archivo.load(_ruta)
	if not bool(archivo.get_value("video","vsync_enabled",false)): fallar("El menú no guarda la elección."); return
	# Cambiar de página libera el control: su conexión no debe sobrevivirlo.
	pausa.call("_show_sound")
	for fotograma in 2: await process_frame
	globales.set_vsync_enabled(false,false)
	if z.button_pressed: fallar("La actualización externa deja el control Z desincronizado."); return
	pausa.set_open(false)
	mundo.queue_free()
	for fotograma in 3: await process_frame
	restaurar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_ruta))
	print("VSYNC SETTINGS TEST OK: persistencia, instalaciones antiguas, valores iniciales, panel Z, Gráficos y modo de ventana.")
	quit()

func comprobar_modo(activado: bool) -> bool:
	if DisplayServer.get_name()=="headless": return true
	var esperado := DisplayServer.VSYNC_ENABLED if activado else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode()!=esperado: fallar("El ajuste no llega a la ventana real."); return false
	return true

func restaurar() -> void:
	if _anteriores.is_empty(): return
	var ajustes := root.get_node("GameSettings")
	ajustes.settings_path = _anteriores.ruta
	ajustes.set_vsync_enabled(_anteriores.vsync,false)
	ajustes.set_resolution(_anteriores.resolucion,false)
	ajustes.set_lod_distance(_anteriores.lod,false)
	ajustes.set_player_identity(_anteriores.nombre,_anteriores.personaje,false)

func fallar(mensaje: String) -> void:
	paused = false
	restaurar()
	if not _ruta.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(_ruta))
	push_error("VSYNC SETTINGS TEST FAIL: "+mensaje)
	quit(1)
