extends Node

## Un único aplicador por mundo; no recorre materiales ni vegetación por frame.
## La medición sólo vive durante la detección y usa tiempos GPU sin VSync.
const Calidad = preload("res://scripts/calidad_grafica.gd")
var mundo: Node3D
var _nivel := 2
var _espera_hasta := 0
var _inicio_muestras := 0
var _ultimo_tick := 0
var _gpu: Array[float] = []
var _cpu: Array[float] = []
var _pared: Array[float] = []
var _medidos: Dictionary = {}
var _aplicado: Dictionary = {}
var _midiendo := false

func _ready() -> void:
	mundo=get_parent()
	name="ConfiguracionVisual"
	process_mode=Node.PROCESS_MODE_ALWAYS
	GameSettings.graphics_changed.connect(_aplicar)
	GameSettings.auto_configuration_requested.connect(_empezar)
	get_window().size_changed.connect(_al_cambiar_ventana)
	_aplicar()
	set_process(false)
	# Las sondas fijan sus condiciones; el juego normal se mide al estrenarse,
	# cambiar de gráfica, versión, resolución o elegir «Detectar equipo».
	if _automatico_permitido() and GameSettings.quality_preset==0:
		if GameSettings.auto_fingerprint!=GameSettings.huella_equipo():_empezar()
		else:GameSettings._set_auto_status("Automática: "+Calidad.NOMBRES[GameSettings.auto_level])

func _automatico_permitido() -> bool:
	return DisplayServer.get_name()!="headless" and not Engine.is_editor_hint() and not "--script" in OS.get_cmdline_args()

func _aplicar() -> void:
	var opciones: Dictionary=GameSettings.visual_options
	if _aplicado==opciones:return
	_aplicado=opciones.duplicate()
	var entorno:Environment=mundo.get_node("WorldEnvironment").environment
	entorno.ssao_enabled=bool(opciones.ssao)
	entorno.glow_enabled=bool(opciones.glow)
	entorno.volumetric_fog_enabled=int(opciones.fog_quality)>0
	if DisplayServer.get_name()!="headless":
		RenderingServer.directional_shadow_atlas_set_size([1024,1024,2048,4096][int(opciones.shadow_quality)],bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits",true)))
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW if int(opciones.shadow_quality)<=1 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		var tamanos:Vector2i=Vector2i(64,64) if int(opciones.fog_quality)<2 else Vector2i(int(ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_size",64)),int(ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_depth",128)))
		RenderingServer.environment_set_volumetric_fog_volume_size(tamanos.x,tamanos.y)
	var cielo:=mundo.get_node("IslandEnvironment")
	cielo.sombras_habilitadas=int(opciones.shadow_quality)>0
	for luz:DirectionalLight3D in [mundo.get_node("Sun"),cielo.moon_light]:
		if luz==null:continue
		luz.directional_shadow_max_distance=float(opciones.shadow_distance)
		luz.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if int(opciones.shadow_quality)<=2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	cielo.sincronizar_luz_celeste(float(mundo.daylight_factor))
	var vista:=get_viewport()
	vista.msaa_3d=Viewport.MSAA_2X if int(opciones.antialiasing)==2 else (Viewport.MSAA_4X if int(opciones.antialiasing)==3 else Viewport.MSAA_DISABLED)
	vista.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA if int(opciones.antialiasing)==1 else Viewport.SCREEN_SPACE_AA_DISABLED
	mundo.get_node("VegetationScatter").configurar_pradera(float(opciones.grass_density),float(opciones.tree_distance))
	mundo.set_meta("opciones_graficas_aplicadas",opciones.duplicate())
	if _midiendo and GameSettings.quality_preset!=0:_detener()

func _al_cambiar_ventana() -> void:
	if not _automatico_permitido() or GameSettings.quality_preset!=0:return
	# Al arrastrar la ventana sólo se pospone la lectura; no se cambian niveles
	# ni se guarda la configuración decenas de veces mientras se redimensiona.
	if not _midiendo:
		_empezar()
	_espera_hasta=Time.get_ticks_msec()+2000
	_limpiar_muestras()

func _empezar() -> void:
	if DisplayServer.get_name()=="headless":return
	_midiendo=true;_nivel=2;_medidos.clear()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	GameSettings.aplicar_nivel_calidad(_nivel)
	_espera_hasta=Time.get_ticks_msec()+2500
	_ultimo_tick=Time.get_ticks_usec()
	_limpiar_muestras()
	GameSettings._set_auto_status("Reanuda el juego: midiendo el equipo…")
	set_process(true)

func _limpiar_muestras() -> void:
	_gpu.clear();_cpu.clear();_pared.clear();_inicio_muestras=0

func _process(_delta: float) -> void:
	if not _midiendo:return
	if GameSettings.quality_preset!=0:_detener();return
	var ahora:=Time.get_ticks_usec()
	var pared_ms:=float(ahora-_ultimo_tick)/1000.0
	_ultimo_tick=ahora
	if not _puede_medir() or pared_ms>500.0:
		_espera_hasta=Time.get_ticks_msec()+1200
		_limpiar_muestras()
		return
	if Time.get_ticks_msec()<_espera_hasta:return
	if _inicio_muestras==0:_inicio_muestras=Time.get_ticks_msec()
	var rid:=get_viewport().get_viewport_rid()
	var gpu_ms:=RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var cpu_ms:=maxf(RenderingServer.viewport_get_measured_render_time_cpu(rid)+RenderingServer.get_frame_setup_time_cpu(),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	if is_finite(gpu_ms) and gpu_ms>0:_gpu.append(gpu_ms)
	if is_finite(cpu_ms) and cpu_ms>0:_cpu.append(cpu_ms)
	_pared.append(pared_ms)
	var duracion:=Time.get_ticks_msec()-_inicio_muestras
	if (duracion>=1600 and _pared.size()>=72) or (duracion>=6000 and _pared.size()>=24):_resolver_medicion()

func _puede_medir() -> bool:
	if get_tree().paused or not get_window().has_focus() or Engine.time_scale<0.95:return false
	var hud:=mundo.get_node("HUD")
	if hud.settings_open or hud.map_open or hud.lobby_open or hud.inventory_open or hud.exploration_journal_open or hud.credits_open:return false
	return not hud.pause_menu.visible and not hud.story_dialogue_open

func _resolver_medicion() -> void:
	var gpu:=Calidad.percentil(_gpu)
	var cpu:=Calidad.percentil(_cpu)
	var pared:=Calidad.percentil(_pared)
	var tope:=float(GameSettings.fps_limit)
	if GameSettings.vsync_enabled:
		var hz:=DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
		if hz>0:tope=minf(tope,hz) if tope>0 else hz
	var limite:=1000.0/tope if tope>0 else 0.0
	_medidos[_nivel]={"gpu_ms":gpu,"cpu_ms":cpu,"frame_ms":pared}
	var recomendado:=Calidad.recomendar(_nivel,gpu,cpu,pared,GameSettings.auto_target_fps,limite)
	if recomendado!=_nivel and not _medidos.has(recomendado):
		_nivel=recomendado
		GameSettings.aplicar_nivel_calidad(_nivel)
		_espera_hasta=Time.get_ticks_msec()+1800
		_limpiar_muestras()
		return
	_nivel=recomendado
	GameSettings.aplicar_nivel_calidad(_nivel)
	var datos:Dictionary=_medidos.get(_nivel,{"gpu_ms":gpu,"cpu_ms":cpu,"frame_ms":pared})
	GameSettings.guardar_autoconfiguracion(_nivel,"Automática: %s · objetivo %d FPS"%[Calidad.NOMBRES[_nivel],GameSettings.auto_target_fps])
	mundo.set_meta("ultima_autodeteccion",{"nivel":_nivel,"mediciones":_medidos.duplicate(true),"equipo":GameSettings.huella_equipo(),"muestra_elegida":datos})
	_detener()

func _detener() -> void:
	_midiendo=false
	set_process(false)
	if DisplayServer.get_name()!="headless":RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)

func _exit_tree() -> void:
	if _midiendo and DisplayServer.get_name()!="headless":RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
