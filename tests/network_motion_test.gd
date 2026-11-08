extends SceneTree

const MOTION: Script = preload("res://scripts/network_motion.gd")

# Inyección de la presentación anterior: debe perder la prueba de suavidad.
class MovimientoAnterior:
	extends "res://scripts/network_motion.gd"
	func advance(delta: float, _now: float) -> void:
		if _samples.is_empty(): return
		position = position.lerp(_samples[-1].p,1.0-exp(-11.0*delta))

func _init() -> void: call_deferred("_run_test")

func _run_test() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for singleton in ["InventoryManager","ExplorationManager"]:
		root.get_node(singleton).set("autosave_enabled",false)
	var motion = MOTION.new()
	motion.push_sample(Vector3.ZERO,deg_to_rad(179),Vector3(6,0,0),1000.0,10.0)
	motion.push_sample(Vector3(6,0,0),deg_to_rad(-179),Vector3(6,0,0),1001.0,11.0)
	var midpoint: Dictionary = motion._sample(1000.5)
	if (midpoint.p as Vector3).distance_to(Vector3(3,0,0))>0.001 or absf(absf(float(midpoint.r))-PI)>0.001:
		_fail("La curva o el giro cruzando ±PI no son continuos."); return
	if motion.push_sample(Vector3(99,0,0),0.0,Vector3.ZERO,1000.9,11.1):
		_fail("Una muestra antigua rebobina al compañero."); return
	var stopped: Dictionary = motion._sample(1002.0)
	if (stopped.v as Vector3).length()>0.001 or (stopped.p as Vector3).x>7.441:
		_fail("La pérdida de conexión deja al compañero caminando indefinidamente."); return
	var generation: int = motion.generation
	motion.push_sample(Vector3(700,2,-500),0.0,Vector3.ZERO,1001.1,11.2)
	if motion.generation!=generation+1 or motion.position.distance_to(Vector3(700,2,-500))>0.001:
		_fail("El teletransporte interpola un viaje a través de la isla."); return
	if motion.push_sample(Vector3(NAN,0,0),0.0,Vector3.ZERO,1001.2,11.3):
		_fail("El búfer admite una posición no finita."); return
	var corner = MOTION.new()
	corner.push_sample(Vector3(6,0,0),0.0,Vector3(6,0,0),0.0,10.0)
	corner.push_sample(Vector3(6,0,6),0.0,Vector3(0,0,6),1.0,11.0)
	for i in 101:
		var curve: Dictionary = corner._sample(float(i)/100.0)
		if absf((curve.p as Vector3).x-6.0)>0.001 or (curve.p as Vector3).z<0.0 or (curve.p as Vector3).z>6.0:
			_fail("El giro interpola fuera del corredor entre muestras."); return
	var burst = MOTION.new()
	burst.push_sample(Vector3.ZERO,0.0,Vector3(6,0,0),20.0,30.0)
	burst.push_sample(Vector3(0.4,0,0),0.0,Vector3(6,0,0),20.0001,30.0001)
	if (burst._sample(20.00005).v as Vector3).length()>9.001:
		_fail("Dos muestras de un mismo frame disparan la velocidad de presentación."); return
	var session := root.get_node("NetworkSession")
	if bool(session.call("_is_valid_state",Vector3.ZERO,0.0,Vector3(NAN,0,0),1)):
		_fail("La sesión permite una velocidad NaN que contamina al resto."); return
	if bool(session.call("_is_valid_save_snapshot",{"position":[NAN,0,0],"inventory":{"items":{}}})):
		_fail("Un guardado cooperativo admite una posición NaN."); return
	if bool(session.call("_is_valid_save_snapshot",{"position":[0,0,0],"yaw":INF,"inventory":{"items":{}}})):
		_fail("Un guardado cooperativo admite una orientación infinita."); return
	for fps in [30,60,144,240]:
		for bad in [false,true]:
			var result := _simulate(fps,bad)
			print("NETWORK MOTION TRACE ",JSON.stringify(result))
			if float(result.accel_p95)>float(result.old_accel_p95)*0.6:
				_fail("La presentación con jitter no reduce los tirones al menos un 40 %."); return
			if float(result.lag_mean)>0.65 or float(result.speed_mean)<5.6 or float(result.speed_mean)>6.4:
				_fail("El búfer suaviza a costa de perder distancia o acumular demasiado retraso."); return
			if int(result.samples)>40 or float(result.final_speed)>0.001:
				_fail("La historia crece sin límite o no se detiene al dejar de recibir."); return
	print("NETWORK MOTION PASS: 30/60/144/240 Hz, latencia, jitter, pérdidas, reloj ajeno, giros, parada y teletransportes.")
	quit(0)

func _simulate(fps: int, bad: bool) -> Dictionary:
	var motion = MovimientoAnterior.new() if "--break-network-motion" in OS.get_cmdline_user_args() else MOTION.new()
	var random := RandomNumberGenerator.new()
	random.seed = 481516
	var packets: Array[Dictionary] = []
	for i in 450:
		var sent := float(i)/15.0
		if bad and random.randf()<0.20: continue
		var delay := 0.06 + random.randf()*(0.12 if bad else 0.012)
		# Cortes breves y entregas desordenadas, sin inventar paquetes perdidos.
		if bad and i%90<3: delay += 0.22
		packets.append({"arrival":10.0+sent+delay,"source":1000.0+sent,"pos":Vector3(sent*6.0,0,0)})
	packets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.arrival)<float(b.arrival))
	var cursor := 0
	var old := Vector3.ZERO
	var old_target := Vector3.ZERO
	var previous := Vector3.ZERO
	var previous_old := Vector3.ZERO
	var previous_speed := 0.0
	var previous_old_speed := 0.0
	var acceleration := PackedFloat64Array()
	var old_acceleration := PackedFloat64Array()
	var speed_sum := 0.0
	var lag_sum := 0.0
	var dt := 1.0/float(fps)
	for frame in int(32.0*fps):
		var elapsed := frame*dt
		var now := 10.0+elapsed
		while cursor<packets.size() and float(packets[cursor].arrival)<=now:
			var packet: Dictionary = packets[cursor]
			motion.push_sample(packet.pos,0.0,Vector3(6,0,0),packet.source,packet.arrival)
			old_target = packet.pos
			cursor += 1
		motion.advance(dt,now)
		old = old.lerp(old_target,1.0-exp(-11.0*dt))
		var speed: float = (motion.position.x-previous.x)/dt
		var old_speed := (old.x-previous_old.x)/dt
		if elapsed>4.0 and elapsed<27.0:
			acceleration.append(absf(speed-previous_speed)/dt)
			old_acceleration.append(absf(old_speed-previous_old_speed)/dt)
			speed_sum += speed
			lag_sum += (elapsed*6.0-motion.position.x)/6.0
		previous = motion.position
		previous_old = old
		previous_speed = speed
		previous_old_speed = old_speed
	acceleration.sort()
	old_acceleration.sort()
	return {"fps":fps,"bad_network":bad,"accel_p95":acceleration[int(acceleration.size()*0.95)],"old_accel_p95":old_acceleration[int(old_acceleration.size()*0.95)],"speed_mean":speed_sum/acceleration.size(),"lag_mean":lag_sum/acceleration.size(),"samples":motion.get("_samples").size(),"final_speed":motion.velocity.length()}

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
