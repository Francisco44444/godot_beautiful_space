extends SceneTree

const Transporte = preload("res://scripts/estado_fragmentado.gd")

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	var estado := {"enemies":[],"wildlife":[],"vegetation_resources":{"destroyed_resource_ids":[]},"sun_cycle_radians":1.123456789}
	var azar := RandomNumberGenerator.new()
	azar.seed = 88117
	for indice in 265:
		estado.enemies.append({"id":"enemigo_%d" % indice,"position":Vector3(azar.randf_range(-5000,5000),azar.randf()*800,azar.randf_range(-5000,5000)),"yaw":azar.randf()*TAU,"health":indice+1,"dead":indice%7==0,"anim":"Walk"})
	for indice in 50000: estado.vegetation_resources.destroyed_resource_ids.append("forest_tree_%d_%d" % [indice,azar.randi()])
	var emisor := Transporte.new()
	var receptor := Transporte.new()
	var paquetes: Array[PackedByteArray] = emisor.preparar(estado)
	if paquetes.size()<3: fallar("El caso grande no ejercita varias partes."); return
	for paquete in paquetes:
		if paquete.size()>1000: fallar("Un estado vuelve a superar el presupuesto de 1000 bytes por RPC."); return
	var recibido: Variant = null
	for indice in range(paquetes.size()-1,-1,-1):
		var valor: Variant = receptor.recibir(paquetes[indice],100)
		if indice>0 and valor!=null: fallar("Se aplica una instantánea incompleta."); return
		if valor!=null: recibido = valor
		receptor.recibir(paquetes[indice],101)
	if var_to_bytes(recibido)!=var_to_bytes(estado): fallar("La compresión o el reordenado cambia valores, ids o precisión."); return
	if receptor.estadisticas().completados!=1: fallar("Los duplicados completan el mismo estado dos veces."); return

	# Una instantánea nueva incompleta no bloquea la anterior que sí llega.
	emisor.reiniciar()
	receptor.reiniciar()
	var antiguos := emisor.preparar(estado)
	estado.sun_cycle_radians = 4.0
	var nuevos := emisor.preparar(estado)
	receptor.recibir(nuevos[0],200)
	var anterior: Variant = entregar(receptor,antiguos,201)
	if not anterior is Dictionary or anterior.sun_cycle_radians!=1.123456789: fallar("El primer fragmento nuevo descarta un estado anterior que aún puede completarse."); return
	var actual: Variant = entregar(receptor,nuevos,202)
	if not actual is Dictionary or actual.sun_cycle_radians!=4.0: fallar("No se completa el estado más reciente."); return
	if entregar(receptor,antiguos,203)!=null: fallar("Un estado antiguo completo hace retroceder el mundo."); return

	# Perder una parte no modifica recursos. El siguiente estado recupera todo.
	receptor.reiniciar()
	for indice in antiguos.size()-1:
		if receptor.recibir(antiguos[indice],300)!=null: fallar("Una pérdida parcial aplica recursos mutilados."); return
	if entregar(receptor,nuevos,301)==null: fallar("No se recupera tras perder una parte."); return
	if receptor.recibir(antiguos.back(),302)!=null: fallar("La parte atrasada restaura un estado viejo."); return

	# Validar límites antes de reservar memoria o descomprimir.
	receptor.reiniciar()
	for campo in [0,16,20,24]:
		var roto := paquetes[0].duplicate()
		roto.encode_u32(campo,0xffffffff)
		if receptor.recibir(roto,400)!=null or receptor.estadisticas().pendientes!=0: fallar("Una cabecera inválida reserva o aplica datos."); return
	if receptor.recibir(PackedByteArray([0,1,2]),400)!=null: fallar("Se acepta una cabecera truncada."); return
	var truncado := paquetes[0].slice(0,paquetes[0].size()-1)
	if receptor.recibir(truncado,400)!=null or receptor.estadisticas().pendientes!=0: fallar("Se acepta una parte de tamaño incorrecto."); return
	for indice in 20:
		var lote := emisor.preparar(estado)
		receptor.recibir(lote[0],500+indice)
		if receptor.estadisticas().pendientes>4: fallar("Las pérdidas acumulan instantáneas sin límite."); return
	receptor.recibir(PackedByteArray(),3000)
	if receptor.estadisticas().pendientes!=0: fallar("No caducan los estados incompletos."); return
	receptor.reiniciar()
	emisor.reiniciar()
	if entregar(receptor,emisor.preparar({"sesion":"otra"}),4000)!={"sesion":"otra"}: fallar("Una sesión nueva hereda secuencias anteriores."); return
	print("STATE TRANSPORT TEST OK: estados exactos, 1000 bytes, desorden, duplicados, pérdidas, antigüedad, límites y reinicio.")
	quit()

func entregar(receptor: RefCounted, paquetes: Array[PackedByteArray], hora: int) -> Variant:
	var resultado: Variant = null
	for paquete in paquetes:
		var valor: Variant = receptor.recibir(paquete,hora)
		if valor!=null: resultado = valor
	return resultado

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
