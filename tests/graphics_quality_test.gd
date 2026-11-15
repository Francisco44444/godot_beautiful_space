extends SceneTree
const Calidad=preload("res://scripts/calidad_grafica.gd")
const Ajustes=preload("res://scripts/game_settings.gd")
const Perfiles=preload("res://scripts/perfiles_render.gd")
func _init()->void:call_deferred("_comprobar")
func _comprobar()->void:
	var casos:=[
		[2,6.0,4.0,16.67,60,16.67,1],
		[2,14.0,4.0,16.67,60,16.67,2],
		[2,30.0,4.0,33.3,60,16.67,3],
		[2,0.0,4.0,16.67,60,16.67,2],
		[2,0.0,4.0,33.33,60,33.33,2],
		[2,0.0,4.0,80.0,60,16.67,3],
		[2,4.0,26.0,26.0,60,0.0,3],
		[2,4.0,4.0,30.0,60,16.67,3],
		[3,40.0,5.0,50.0,60,0.0,3],
	]
	for c in casos:
		if Calidad.recomendar(c[0],c[1],c[2],c[3],c[4],c[5])!=c[6]:_fallar("La detección confunde espera de VSync, GPU o cuello de CPU: "+str(c));return
	if Calidad.percentil([4.0,40.0,7.0,8.0,6.0])!=8.0:_fallar("La detección no usa un percentil estable.");return
	for clave in Calidad.OPCIONES:
		for valor in [INF,-INF,NAN,"inválido",-900.0,90000.0]:
			var seguro:=Calidad.validar(clave,valor)
			if not is_finite(seguro) or seguro<float(Calidad.OPCIONES[clave][0]) or seguro>float(Calidad.OPCIONES[clave][1]):_fallar("Un ajuste corrupto llega al render: "+clave);return
	var alta:=Calidad.preset(1);var media:=Calidad.preset(2);var baja:=Calidad.preset(3)
	if not (alta.shadow_distance>media.shadow_distance and media.shadow_distance>baja.shadow_distance and alta.grass_density>media.grass_density and media.grass_density>baja.grass_density):_fallar("Los perfiles no escalonan los costes reales de geometría y sombras.");return
	for metal in [true,false]:
		var personalizado:=Perfiles.resolver(3,Vector2i(2560,1440),"forward_plus",metal,0.5)
		if personalizado.input_expected!=Vector2i(1280,720) or personalizado.scale!=0.5 or personalizado.mode!=(3 if metal else 1):_fallar("La escala personalizada no llega a 720p desde 1440p.");return
		var pequeno:=Perfiles.resolver(3,Vector2i(1280,720),"forward_plus",metal,0.5)
		if pequeno.input_expected!=Vector2i(960,540) or pequeno.scale!=0.75:_fallar("La escala personalizada pierde el mínimo de 960×540.");return
	if not _comprobar_migracion():return
	print("GRAPHICS QUALITY TEST OK: VSync, límite a 30 FPS, GPU ausente, CPU saturada, tiempos de presentación, validación y escala 3D personalizada.")
	quit(0)
func _fallar(texto:String)->void:push_error(texto);quit(1)

func _comprobar_migracion()->bool:
	var ruta:="user://prueba-calidad-%d.cfg"%OS.get_process_id()
	var config:=ConfigFile.new()
	config.set_value("general","schema_version",2)
	config.set_value("video","width",1280);config.set_value("video","height",720)
	config.save(ruta)
	var ajustes:=Ajustes.new();ajustes.settings_path=ruta;ajustes._load_settings()
	var respeta:=ajustes.resolution==Vector2i(1280,720)
	config.set_value("general","schema_version",1);config.save(ruta);ajustes._load_settings()
	var migra:=ajustes.resolution==Vector2i(1600,900)
	config.set_value("graphics","manual_render_scale",NAN)
	config.set_value("video","fps_limit",555)
	config.set_value("detail","grass_density",-8.0)
	config.set_value("detail","shadow_quality",99)
	config.save(ruta);ajustes._load_settings()
	var seguro:bool=ajustes.manual_render_scale==0.75 and ajustes.fps_limit==120 and ajustes.visual_options.grass_density==0.5 and ajustes.visual_options.shadow_quality==3.0
	ajustes.free();DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if not respeta or not migra or not seguro:_fallar("Migrar gráficos cambia una resolución elegida o admite ajustes corruptos.");return false
	return true
