extends VBoxContainer

## Controles compartidos por Esc y Z. Se sincronizan por señales y cada ajuste
## corresponde a una opción aplicada, nunca a un efecto que el juego no usa.
var _controles: Dictionary = {}
var _etiquetas: Dictionary = {}
var _estado: Label
var _equipo: Label

func _ready() -> void:
	name="OpcionesGraficasAvanzadas"
	add_theme_constant_override("separation",9)
	_selector("quality_preset","Calidad general",GameSettings.Calidad.NOMBRES,GameSettings.set_quality_preset,"QualityPresetSelector")
	var detectar:=Button.new();detectar.name="AutoDetectButton";detectar.text="Detectar configuración del equipo";detectar.custom_minimum_size.y=36
	detectar.pressed.connect(GameSettings.solicitar_autoconfiguracion);add_child(detectar)
	_estado=Label.new();_estado.name="AutoGraphicsStatus";_estado.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(_estado)
	var ayuda_auto:=Label.new();ayuda_auto.text="Automática vigila los FPS al jugar y reduce la calidad si la lentitud persiste. Los ajustes manuales desactivan esa vigilancia.";ayuda_auto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;ayuda_auto.add_theme_font_size_override("font_size",13);add_child(ayuda_auto)
	_equipo=Label.new();_equipo.name="GraphicsDevice";_equipo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_equipo.add_theme_font_size_override("font_size",13)
	_equipo.text="GPU: "+RenderingServer.get_video_adapter_name() if DisplayServer.get_name()!="headless" else "Sin dispositivo gráfico en esta prueba"
	add_child(_equipo)
	_selector("auto_target_fps","Objetivo del ajuste automático",["60 FPS","90 FPS","120 FPS"],func(i:int)->void:GameSettings.set_auto_target_fps([60,90,120][i]),"AutoTargetSelector")
	_selector("window_mode","Modo de pantalla",["Ventana","Pantalla completa"],GameSettings.set_window_mode,"WindowModeSelector")
	_selector("fps_limit","Límite de fotogramas",["Sin límite","30 FPS","60 FPS","90 FPS","120 FPS","144 FPS","200 FPS","240 FPS"],func(i:int)->void:GameSettings.set_fps_limit([0,30,60,90,120,144,200,240][i]),"FrameLimitSelector")
	_deslizador("manual_render_scale","Escala de imagen 3D actual",0.35,1.0,0.01,GameSettings.set_manual_render_scale,"RenderScaleSlider")
	var nitidez:=Label.new();nitidez.text="Menor escala gana fluidez y pierde nitidez. La interfaz conserva su resolución. Al moverla se activa Personalizado.";nitidez.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;nitidez.add_theme_font_size_override("font_size",13);add_child(nitidez)
	_selector("shadow_quality","Calidad de sombras",["Desactivadas","Rápidas · 1024","Medias · 2048","Nítidas · 4096"],func(i:int)->void:GameSettings.set_visual_option("shadow_quality",i),"ShadowQualitySelector")
	_deslizador("shadow_distance","Distancia de sombras",50,480,10,func(v:float)->void:GameSettings.set_visual_option("shadow_distance",v),"ShadowDistanceSlider")
	_selector("grass_density","Densidad de hierba",["50 %","75 %","100 %"],func(i:int)->void:GameSettings.set_visual_option("grass_density",[0.5,0.75,1.0][i]),"GrassDensitySelector")
	_deslizador("tree_distance","Árboles del horizonte",2000,5200,100,func(v:float)->void:GameSettings.set_visual_option("tree_distance",v),"TreeDistanceSlider")
	_selector("fog_quality","Niebla volumétrica",["Desactivada","Ligera","Completa"],func(i:int)->void:GameSettings.set_visual_option("fog_quality",i),"FogQualitySelector")
	_selector("antialiasing","Suavizado de bordes",["Desactivado","FXAA · rápido","MSAA 2×","MSAA 4×"],func(i:int)->void:GameSettings.set_visual_option("antialiasing",i),"AntialiasingSelector")
	_interruptor("ssao","Sombras de contacto (SSAO)","SsaoToggle")
	_interruptor("glow","Resplandor de luces y magia","GlowToggle")
	var copiar:=Button.new();copiar.name="CopyGraphicsDiagnostics";copiar.text="Copiar diagnóstico de rendimiento";copiar.custom_minimum_size.y=34
	copiar.pressed.connect(func()->void:DisplayServer.clipboard_set(GameSettings.diagnostico_grafico()))
	add_child(copiar)
	get_window().size_changed.connect(func()->void:_sincronizar.call_deferred())
	GameSettings.graphics_changed.connect(_sincronizar)
	GameSettings.auto_status_changed.connect(func(_mensaje:String)->void:_sincronizar())
	GameSettings.render_profile_changed.connect(func(_perfil:int)->void:_sincronizar())
	_sincronizar()

func _fila(texto: String) -> HBoxContainer:
	var fila:=HBoxContainer.new();fila.add_theme_constant_override("separation",12);add_child(fila)
	var label:=Label.new();label.text=texto;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",15);fila.add_child(label)
	return fila

func _selector(clave: String,texto: String,opciones: Array,accion: Callable,nombre: String) -> void:
	var fila:=_fila(texto)
	var control:=OptionButton.new();control.name=nombre;control.custom_minimum_size=Vector2(220,34)
	for opcion in opciones:control.add_item(opcion)
	control.item_selected.connect(accion);fila.add_child(control);_controles[clave]=control

func _deslizador(clave: String,texto: String,minimo: float,maximo: float,paso: float,accion: Callable,nombre: String) -> void:
	var fila:=_fila(texto)
	var valor:=Label.new();valor.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;valor.custom_minimum_size.x=70;fila.add_child(valor);_etiquetas[clave]=valor
	var control:=HSlider.new();control.name=nombre;control.custom_minimum_size=Vector2(220,28);control.min_value=minimo;control.max_value=maximo;control.step=paso
	control.value_changed.connect(accion);add_child(control);_controles[clave]=control

func _interruptor(clave: String,texto: String,nombre: String) -> void:
	var control:=CheckButton.new();control.name=nombre;control.text=texto;control.toggled.connect(func(v:bool)->void:GameSettings.set_visual_option(clave,v));add_child(control);_controles[clave]=control

func _sincronizar() -> void:
	if _estado==null or not is_inside_tree() or is_queued_for_deletion():return
	_estado.text=GameSettings.auto_status
	var resolucion:=get_parent().find_child("ResolutionSelector",true,false) as OptionButton
	if resolucion!=null:
		resolucion.disabled=GameSettings.window_mode==1
		resolucion.tooltip_text="En pantalla completa se usa la resolución del monitor. Puedes reducir la escala de imagen 3D."

	for clave in _controles:
		var control:Control=_controles[clave]
		var valor:Variant=GameSettings.visual_options.get(clave)
		if clave=="quality_preset":valor=GameSettings.quality_preset
		elif clave=="window_mode":valor=GameSettings.window_mode
		elif clave=="fps_limit":valor=[0,30,60,90,120,144,200,240].find(GameSettings.fps_limit)
		elif clave=="auto_target_fps":valor=[60,90,120].find(GameSettings.auto_target_fps)
		elif clave=="manual_render_scale":valor=get_window().scaling_3d_scale
		elif clave=="grass_density":valor=[0.5,0.75,1.0].find(float(valor))
		if control is OptionButton:control.select(int(valor))
		elif control is HSlider:control.set_value_no_signal(float(valor))
		elif control is CheckButton:control.set_pressed_no_signal(bool(valor))
		if _etiquetas.has(clave):_etiquetas[clave].text=("%.0f %%"%(float(valor)*100.0)) if clave=="manual_render_scale" else "%.0f m"%float(valor)
