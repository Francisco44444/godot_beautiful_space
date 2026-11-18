extends Node3D
## La autoridad integra tres rivales a 10 Hz; los demás reciben su estado.
## Fuera del radio de colisión de Terrain3D siguen el relieve y una trayectoria
## continua, con aceleración, frenada y saltos balísticos, sin física lejana.
const FICHAS := [
	{"nombre":"Brina la Veloz","aspecto":5,"tope":35.5,"curva":18.0,"carril":-2.6},
	{"nombre":"Telmo del Pinar","aspecto":2,"tope":33.0,"curva":20.0,"carril":0.0},
	{"nombre":"Lúa de la Cornisa","aspecto":6,"tope":31.5,"curva":17.0,"carril":2.6},
]
var director: Node
var puntos: Array[Vector3] = []
var distancias: Array[float] = [0.0]
var bots: Array = []
var tiempo := -3.0
var activa := false
var _avatares: Array[Node3D] = []
var _reposo: Timer
func iniciar(d: Node) -> void:
	director = d;puntos = d.puertas;name = "MensajerosDeLaNieve"
	_reposo = Timer.new();_reposo.wait_time = 1.0;_reposo.process_mode = Node.PROCESS_MODE_PAUSABLE;_reposo.timeout.connect(presentar);add_child(_reposo)
	for i in range(1,puntos.size()):distancias.append(distancias[-1]+puntos[i-1].distance_to(puntos[i]))
func nueva() -> void:
	tiempo = -3.0;activa = true;bots.clear();_reposo.stop()
	for i in FICHAS.size():
		var p := _muestra(0.0,float(FICHAS[i].carril))
		var adelante := _muestra(1.0,float(FICHAS[i].carril))-p
		bots.append({"distancia":0.0,"rapidez":4.0,"meta":0.0,"posicion":[p.x,p.y,p.z],"velocidad":[0.0,0.0,0.0],"rumbo":atan2(-adelante.x,-adelante.z),"postura":[0.0,0.0,0.0],"aire":false,"vy":0.0,"y":p.y,"saltos":{}})
	presentar()
func cancelar() -> void:
	activa = false;bots.clear();_reposo.stop()
	for p in _avatares:
		director._mostrar_tabla(p,false);p.hide();p.process_mode = Node.PROCESS_MODE_DISABLED
func descansar() -> void:
	if not bots.is_empty() and _reposo.is_stopped():_reposo.start()
func _segmento(distancia: float) -> int:
	var i := 0
	while i<distancias.size()-2 and distancia>distancias[i+1]:i += 1
	return i
func _muestra(distancia: float, carril: float) -> Vector3:
	var i := _segmento(distancia);var t := clampf((distancia-distancias[i])/maxf(distancias[i+1]-distancias[i],0.01),0,1)
	var a := puntos[maxi(i-1,0)];var b := puntos[i];var c := puntos[i+1];var d := puntos[mini(i+2,puntos.size()-1)]
	var p := 0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
	var tangente := (c-b).normalized();p += Vector3(-tangente.z,0,tangente.x)*carril
	p.y = director.mundo.terrain.data.get_height(p)+0.07
	return p
func avanzar(delta: float) -> void:
	if not activa:return
	var anterior := tiempo;tiempo += delta
	if tiempo<0:return
	var paso := minf(delta,tiempo) if anterior<0 else delta
	var pendientes := false
	for i in bots.size():
		var e: Dictionary = bots[i]
		if float(e.meta)>0:continue
		var ficha: Dictionary = FICHAS[i];var distancia: float = e.distancia;var tramo := _segmento(distancia)
		var entrada := (puntos[tramo+1]-puntos[tramo]).normalized();var salida := (puntos[mini(tramo+2,puntos.size()-1)]-puntos[tramo+1]).normalized()
		var curva := acos(clampf(entrada.dot(salida),-1,1));var cerca := distancias[tramo+1]-distancia<34.0
		var objetivo: float = ficha.curva if curva>0.55 and cerca else ficha.tope
		var a := _muestra(distancia,float(ficha.carril));var b := _muestra(minf(distancia+2,distancias[-1]),float(ficha.carril))
		var pendiente := (b.y-a.y)/2.0
		var aceleracion := 4.2-maxf(pendiente,-0.65)*16.0
		e.rapidez = move_toward(float(e.rapidez),objetivo,(18.0 if float(e.rapidez)>objetivo else maxf(aceleracion,1.0))*paso)
		e.distancia = minf(distancias[-1],distancia+float(e.rapidez)*paso)
		var nuevo := _muestra(float(e.distancia),float(ficha.carril));var direccion := nuevo-a
		var rumbo := atan2(-direccion.x,-direccion.z) if Vector2(direccion.x,direccion.z).length_squared()>0.0001 else float(e.rumbo)
		for salto in [18,40,60]:
			var centro := lerpf(distancias[salto],distancias[salto+1],0.58);var margen: float = float(e.distancia)-centro
			if margen>=-4.5 and margen<=4.5 and not e.aire:nuevo.y += 1.8*clampf((margen+4.5)/9.0,0,1)
			if margen>4.5 and distancia<=centro+4.5 and not e.saltos.has(str(salto)):
				e.saltos[str(salto)] = true;e.aire = true;e.y = nuevo.y+1.8;e.vy = 7.8
		if e.aire:
			e.vy = float(e.vy)-17.0*paso;e.y = float(e.y)+float(e.vy)*paso
			if float(e.y)<=nuevo.y:e.aire = false;e.y = nuevo.y
			else:nuevo.y = float(e.y)
		var vieja: Array = e.posicion;var previo := Vector3(vieja[0],vieja[1],vieja[2]);var velocidad := (nuevo-previo)/maxf(paso,0.001)
		var inclinacion := clampf(angle_difference(float(e.rumbo),rumbo)/maxf(paso,0.001)*0.32,-0.6,0.6)
		e.postura = [0.2 if curva>0.55 and cerca else 1.0,inclinacion,clampf(atan2(velocidad.y,maxf(float(e.rapidez),1)),-0.7,0.7)]
		e.rumbo = rumbo;e.posicion = [nuevo.x,nuevo.y,nuevo.z];e.velocidad = [velocidad.x,velocidad.y,velocidad.z]
		if float(e.distancia)>=distancias[-1]:e.meta = tiempo;e.velocidad = [0.0,0.0,0.0]
		else:pendientes = true
	activa = pendientes
func resultado(penalizacion: float = 0.0) -> Dictionary:
	var original := bots;var reloj_original := tiempo;var actividad := activa
	if penalizacion>0 and activa:
		# La penalización se compara con el mismo movimiento determinista de
		# los rivales, sin adelantar sus posiciones visibles ni variar su ritmo.
		bots = bots.duplicate(true)
		var restante := penalizacion
		while restante>0 and activa:
			var paso := minf(restante,0.1);avanzar(paso);restante -= paso
	var delante := 0
	for e in bots:
		if float(e.meta)>0:delante += 1
	var salida := {"ganado":not bots.is_empty() and delante==0,"puesto":delante+1}
	bots = original;tiempo = reloj_original;activa = actividad
	return salida
func progreso_humano(puerta: int, posicion: Vector3) -> float:
	var i := clampi(puerta-1,0,puntos.size()-2);var v := puntos[i+1]-puntos[i]
	return distancias[i]+clampf((posicion-puntos[i]).dot(v)/maxf(v.length_squared(),0.01),0,1)*v.length()
func puesto(progreso: float) -> int:
	var n := 1
	for e in bots:
		if float(e.distancia)>progreso:n += 1
	return n
func presentar() -> void:
	if bots.is_empty():return
	while _avatares.size()<FICHAS.size():
		var i := _avatares.size();var p = preload("res://scenes/player.tscn").instantiate()
		p.name = "Mensajero%d"%i;p.configure_network_replica(FICHAS[i].nombre,FICHAS[i].aspecto);add_child(p);p.set_physics_process(false)
		for m in p.find_children("*","GeometryInstance3D",true,false):m.visibility_range_end = 200
		_avatares.append(p)
	for i in bots.size():
		var p := _avatares[i];var e: Dictionary = bots[i];var v: Array = e.posicion;var posicion := Vector3(v[0],v[1],v[2])
		var cerca: bool = director.mundo.player.global_position.distance_to(posicion)<200.0
		p.visible = cerca;p.process_mode = Node.PROCESS_MODE_ALWAYS if cerca else Node.PROCESS_MODE_DISABLED
		if not cerca:continue
		var velocidad: Array = e.velocidad;var postura: Array = e.postura
		p.apply_network_state(posicion,float(e.rumbo),Vector3(velocidad[0],velocidad[1],velocidad[2]),0,float(Time.get_ticks_usec())/1000000.0,not bool(e.aire))
		director._mostrar_tabla(p,float(e.meta)<=0);p.postura_nieve = Vector3(postura[0],postura[1],postura[2])
func guardar() -> Dictionary:return {"tiempo":tiempo,"activa":activa,"bots":bots.duplicate(true)}
func cargar(datos: Dictionary) -> void:
	tiempo = float(datos.get("tiempo",-3));activa = bool(datos.get("activa",false));bots = datos.get("bots",[]).duplicate(true)
	if bots.is_empty():cancelar()
	else:presentar()
