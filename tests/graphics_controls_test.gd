extends SceneTree
const Ajustes=preload("res://scripts/game_settings.gd")
var mundo:Node3D
var ajustes:Node
var guardados:Dictionary={}
var ruta:=""
func _init()->void:call_deferred("_comprobar")
func _comprobar()->void:
	ajustes=root.get_node("GameSettings")
	ruta="res://generated/reviews/prueba-graficos-%d.cfg"%OS.get_process_id()
	guardados={"ruta":ajustes.settings_path,"calidad":ajustes.quality_preset,"opciones":ajustes.visual_options.duplicate(),"perfil":ajustes.render_profile,"escala":ajustes.manual_render_scale,"fps":ajustes.fps_limit,"modo":ajustes.window_mode,"lod":ajustes.lod_distance_metres}
	ajustes.settings_path=ruta
	ajustes.set_quality_preset(1,false)
	for n in ["InventoryManager","ExplorationManager"]:root.get_node(n).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	mundo=load("res://scenes/world.tscn").instantiate();mundo.modo_aventura=false;root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 8:await process_frame
	paused=false
	var scatter:=mundo.get_node("VegetationScatter")
	var malla:ArrayMesh=scatter.get("_grass_meshes")[0]
	var rid:=malla.get_rid();var buffers:Array=malla.get("_surfaces")
	var arboles:int=scatter.generated_tree_count;var parches:int=scatter.generated_grass_count
	var hud:=mundo.get_node("HUD")
	hud._set_settings_open(true)
	var z:=hud.get_node("SettingsOverlay")
	var densidad:=z.find_child("GrassDensitySelector",true,false) as OptionButton
	if densidad==null:_fallar("Faltan los controles gráficos nuevos en Z.");return
	densidad.select(0);densidad.item_selected.emit(0)
	if malla.surface_get_array_index_len(0)!=malla.surface_get_array_len(0)/2:_fallar("Reducir hierba no reduce los triángulos reales.");return
	if malla.get_rid()!=rid or malla.get("_surfaces")[0].vertex_data!=buffers[0].vertex_data:_fallar("La densidad cambia posiciones, altura o identidad del parche.");return
	if scatter.generated_tree_count!=arboles or scatter.generated_grass_count!=parches:_fallar("La densidad modifica el reparto o identidades persistentes.");return
	hud._set_settings_open(false)
	var pausa:Node=hud.pause_menu;pausa.set_open(true);pausa._show_graphics()
	var esc:=pausa.find_child("GrassDensitySelector",true,false) as OptionButton
	if esc==null or esc.selected!=0:_fallar("Esc y Z no comparten densidad de hierba.");return
	var horizonte_alto:=_proxies_visibles(scatter)
	var preset:=pausa.find_child("QualityPresetSelector",true,false) as OptionButton
	preset.select(3);preset.item_selected.emit(3)
	if pausa.find_child("DetailDistanceSlider",true,false).value!=180.0:_fallar("El perfil cambia LOD pero deja obsoleto su control en Esc.");return
	if _proxies_visibles(scatter)>=horizonte_alto:_fallar("El horizonte reducido no retira árboles lejanos del render.");return
	var entorno:Environment=mundo.get_node("WorldEnvironment").environment
	if entorno.ssao_enabled or entorno.volumetric_fog_enabled or entorno.glow_enabled:_fallar("El perfil Rendimiento deja activos sus efectos desactivados.");return
	if mundo.get_node("Sun").directional_shadow_max_distance!=100 or mundo.get_node("IslandEnvironment").moon_light.directional_shadow_max_distance!=100:_fallar("Las sombras no respetan el límite tanto de día como de noche.");return
	ajustes.set_visual_option("shadow_quality",0)
	for fase in [1.08,3.20,4.72]:
		mundo.sun_cycle_radians=fase;mundo._update_sun_cycle(0)
		if mundo.get_node("Sun").shadow_enabled or mundo.get_node("IslandEnvironment").moon_light.shadow_enabled:_fallar("El relevo sol/luna reactiva las sombras desactivadas.");return
	ajustes.set_visual_option("antialiasing",3)
	if root.msaa_3d!=Viewport.MSAA_4X:_fallar("El control MSAA no se aplica al Viewport.");return
	ajustes.set_fps_limit(90)
	if Engine.max_fps!=90:_fallar("El límite de FPS no llega al motor.");return
	ajustes.set_window_mode(1)
	if not z.find_child("ResolutionSelector",true,false).disabled or not pausa.find_child("ResolutionSelector",true,false).disabled:_fallar("Pantalla completa mantiene editables las resoluciones de ventana.");return
	if DisplayServer.get_name()!="headless":
		for i in 8:await process_frame
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN:_fallar("Pantalla completa no se aplica a la ventana real.");return
	ajustes.set_manual_render_scale(0.5)
	var recargados:=Ajustes.new();recargados.settings_path=ruta;recargados._load_settings()
	if recargados.window_mode!=1 or recargados.fps_limit!=90 or recargados.render_profile!=3 or recargados.manual_render_scale!=0.5 or recargados.visual_options.shadow_quality!=0 or recargados.visual_options.antialiasing!=3:_fallar("No persisten los ajustes de rendimiento.");return
	recargados.free()
	ajustes.set_window_mode(0,false)
	ajustes.set_quality_preset(1,false)
	if malla.surface_get_array_index_len(0)!=0 or malla.get("_surfaces")[0].vertex_data!=buffers[0].vertex_data:_fallar("Restaurar Alta no recupera toda la hierba original.");return
	if not entorno.ssao_enabled or not entorno.glow_enabled or not entorno.volumetric_fog_enabled:_fallar("Restaurar Alta no recupera el aspecto completo.");return
	for fase in [1.08,4.72]:
		mundo.sun_cycle_radians=fase;mundo._update_sun_cycle(0)
		if mundo.get_node("Sun").shadow_enabled==mundo.get_node("IslandEnvironment").moon_light.shadow_enabled:_fallar("Restaurar sombras rompe el relevo de un solo mapa.");return
	if esc.selected!=2 or densidad.selected!=2:_fallar("Los menús quedan desincronizados al restaurar Alta.");return
	pausa.set_open(false);mundo.queue_free()
	for i in 4:await process_frame
	_restaurar()
	print("GRAPHICS CONTROLS TEST OK: Esc/Z, persistencia, triángulos y RID de hierba, sombra día/noche, efectos, MSAA, FPS y restauración de calidad.")
	quit(0)
func _restaurar()->void:
	paused=false
	if guardados.is_empty():return
	ajustes.settings_path=guardados.ruta
	ajustes.visual_options=guardados.opciones
	ajustes.manual_render_scale=guardados.escala
	ajustes.set_render_profile(guardados.perfil,false)
	ajustes.set_lod_distance(guardados.lod,false)
	ajustes.set_fps_limit(guardados.fps,false)
	ajustes.set_window_mode(guardados.modo,false)
	ajustes.quality_preset=guardados.calidad
	ajustes.graphics_changed.emit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
func _fallar(texto:String)->void:_restaurar();push_error(texto);quit(1)

func _proxies_visibles(scatter:Node)->int:
	var cantidad:=0
	for celda in scatter.get("_tree_proxy_cells").values():
		for instancia in celda:
			if instancia.visible:cantidad+=1
	return cantidad
