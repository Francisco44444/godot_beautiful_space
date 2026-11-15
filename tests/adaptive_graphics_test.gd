extends SceneTree
const Vigilancia=preload("res://scripts/vigilancia_fps.gd")
const Calidad=preload("res://scripts/calidad_grafica.gd")
const Ajustes=preload("res://scripts/game_settings.gd")
func _init()->void:call_deferred("_comprobar")
func _serie(fps:Array,objetivo:float=60.0,pausa:int=-1)->Dictionary:
	var vigilancia:=Vigilancia.new()
	vigilancia.reiniciar(0,0)
	var tiempo:=0;var fotogramas:=0;var resultado:={}
	for i in fps.size():
		tiempo+=1000000;fotogramas+=int(fps[i])
		var lectura:=vigilancia.observar(tiempo,fotogramas,i!=pausa,objetivo)
		if not lectura.is_empty():resultado=lectura
	return resultado
func _exigir(condicion:bool,mensaje:String)->bool:
	if condicion:return true
	push_error(mensaje);quit(1);return false
func _comprobar()->void:
	if not _exigir(_serie([10,10,10,10,10,10]).is_empty(),"La calidad baja antes de completar seis segundos de muestra."):return
	if not _exigir(_serie([60,60,60,60,10,10,10,10,10,10]).get("degradar",false),"Pierde seis segundos lentos que cruzan la ventana anterior."):return
	var lenta:=_serie([10,10,10,10,10,10,10])
	if not _exigir(lenta.get("degradar",false) and is_equal_approx(float(lenta.fps),10.0),"No detecta diez FPS sostenidos durante seis segundos."):return
	if not _exigir(_serie([58,58,58,58,58,58,58]).get("degradar",false),"Ignora una caída sostenida cerca de sesenta FPS."):return
	for serie in [[60,60,60,60,60,60,60],[90,90,90,90,90,90,90],[60,60,10,60,60,60,60]]:
		if not _exigir(not _serie(serie).get("degradar",false),"Degrada por FPS suficientes o por un tirón aislado."):return
	if not _exigir(not _serie([30,30,30,30,30,30,30],30).get("degradar",false),"Degrada por un límite deliberado a treinta FPS."):return
	if not _exigir(_serie([10,10,10,10,10,10,10,10],60,4).is_empty(),"Conserva muestras de antes de una pausa."):return
	var v:=Vigilancia.new();v.reiniciar(0,0)
	v.observar(1000000,10,true,60);v.observar(2000000,20,true,60)
	if not _exigir(v.observar(6000000,30,true,60).is_empty() and v.observar(7000000,40,true,60).is_empty(),"Un bloqueo de carga contamina la vigilancia."):return
	var minimos:=Calidad.preset(Calidad.NIVEL_MINIMO)
	if not _exigir(minimos.shadow_quality==0 and minimos.manual_scale==0.35 and Calidad.nombre_nivel(4)=="Mínima","El nivel mínimo no reduce el coste después de Rendimiento."):return
	var ajustes:=Ajustes.new()
	if not _exigir(ajustes.quality_preset==0,"Automática no está activa por defecto para Windows y Mac."):return
	var ruta:="user://prueba-adaptativa-%d.cfg"%OS.get_process_id()
	ajustes.settings_path=ruta;ajustes.auto_level=4;ajustes.manual_render_scale=0.35;ajustes._save_settings()
	var cargados:=Ajustes.new();cargados.settings_path=ruta;cargados._load_settings()
	var persiste:bool=cargados.quality_preset==0 and cargados.auto_level==4 and cargados.manual_render_scale==0.35
	ajustes.free();cargados.free();DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if not _exigir(persiste,"La vigilancia pierde el nivel mínimo al reiniciar."):return
	var inicio:=Time.get_ticks_usec()
	for i in 100000:v.observar((i+8)*1000000,(i+8)*60,true,60)
	print("ADAPTIVE GRAPHICS TEST OK: lentitud sostenida, 60 FPS, tirón, pausa, carga, límite, predeterminado y persistencia; %.3f us por muestra CPU."%(float(Time.get_ticks_usec()-inicio)/100000.0))
	quit(0)
