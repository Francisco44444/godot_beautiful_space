extends RefCounted

## Adaptación del búfer de Vigo a héroes a pie y paquetes ENet a 15 Hz.
## El reloj del emisor permite separar el movimiento del retraso de llegada.
## Sólo afecta a la presentación; la autoridad conserva la última posición real.
const MIN_BUFFER := 0.10
const MAX_BUFFER := 0.45
const EXTRAPOLATE_SECONDS := 0.18
const BRAKE_SECONDS := 0.12
const MAX_SAMPLES := 40

var position := Vector3.ZERO
var yaw := 0.0
var velocity := Vector3.ZERO
var grounded := true
var generation := 0
var buffer_seconds := MIN_BUFFER

var _samples: Array[Dictionary] = []
var _offsets: Array[Dictionary] = []
var _clock_offset := 0.0
var _local_clock := 0.0
var _clock_error := 0.0
var _render_time := 0.0
var _playback_rate := 1.0
var _interval := 1.0/15.0
var _jitter := 0.0
var _last_arrival := 0.0


func push_sample(at: Vector3, facing: float, movement: Vector3, source_time: float, arrival_time: float, on_ground: bool = true) -> bool:
	if not at.is_finite() or not movement.is_finite() or not is_finite(facing) or not is_finite(source_time) or not is_finite(arrival_time):
		return false
	var reset := _samples.is_empty()
	if not reset:
		var last: Dictionary = _samples[-1]
		# Ni una retransmisión ni un paquete antiguo pueden rebobinar al héroe.
		if source_time <= float(last.t): return false
		var span := source_time-float(last.t)
		var reachable := 10.0 + maxf(movement.length(),(last.v as Vector3).length())*span*2.0
		reset = span>2.0 or arrival_time-_last_arrival>2.0 or at.distance_to(last.p)>reachable
		if not reset:
			_interval = lerpf(_interval,minf(span,2.0/15.0),0.08)
			_jitter *= exp(-span/2.0)
	if reset:
		_samples.clear()
		_offsets.clear()
		_interval = 1.0/15.0
		_jitter = 0.0
		position = at
		yaw = facing
		velocity = Vector3.ZERO
		grounded = on_ground
		_local_clock = arrival_time
		_clock_error = 0.0
		_playback_rate = 1.0
		generation += 1
	_offsets.append({"arrival":arrival_time,"offset":arrival_time-source_time})
	while _offsets.size()>1 and arrival_time-float(_offsets[0].arrival)>3.0: _offsets.pop_front()
	_clock_offset = float(_offsets[0].offset)
	for offset in _offsets: _clock_offset = minf(_clock_offset,float(offset.offset))
	_jitter = maxf(_jitter,arrival_time-source_time-_clock_offset)
	buffer_seconds = clampf(_interval*1.5+_jitter+0.02,MIN_BUFFER,MAX_BUFFER)
	if reset: _render_time = source_time-buffer_seconds
	_samples.append({"t":source_time,"p":at,"r":facing,"v":movement,"g":on_ground})
	if _samples.size()>MAX_SAMPLES: _samples.pop_front()
	_last_arrival = arrival_time
	return true


func advance(delta: float, now: float) -> void:
	if _samples.is_empty() or delta<=0.0: return
	# Un parón del cliente no se convierte en varios pasos con el mismo reloj.
	if absf(now-_local_clock)>0.6:
		_local_clock = now
		_clock_error = 0.0
		_render_time = now-_clock_offset-buffer_seconds-delta
	else:
		_clock_error = lerpf(_clock_error,now-_local_clock-delta,1.0-exp(-delta*2.0))
		_local_clock += delta*clampf(1.0+_clock_error/0.25,0.5,2.5)
	var desired := _local_clock-_clock_offset-buffer_seconds
	var desired_rate := clampf(1.0+(desired-_render_time)*0.8,0.8,1.08)
	_playback_rate = move_toward(_playback_rate,desired_rate,delta*0.3)
	_render_time += delta*_playback_rate
	var target := _sample(_render_time)
	var target_position: Vector3 = target.p
	velocity = (target.v as Vector3)*_playback_rate
	grounded = bool(target.g)
	# Predecir con velocidad y corregir el error evita el salto al recuperar
	# paquetes después de extrapolar, sin el retraso continuo del lerp anterior.
	position = (position+velocity*delta).lerp(target_position,1.0-exp(-delta*14.0))
	yaw = lerp_angle(yaw,float(target.r),1.0-exp(-delta*17.0))


func _sample(time: float) -> Dictionary:
	var index := _samples.size()-1
	while index>0 and float(_samples[index].t)>time: index -= 1
	var a: Dictionary = _samples[index]
	if time<float(a.t): return {"p":a.p,"r":a.r,"v":Vector3.ZERO,"g":a.g}
	if index==_samples.size()-1:
		var age := maxf(time-float(a.t),0.0)
		var brake := clampf((age-EXTRAPOLATE_SECONDS)/BRAKE_SECONDS,0.0,1.0)
		var travelled := minf(age,EXTRAPOLATE_SECONDS)+BRAKE_SECONDS*(brake-brake*brake*0.5)
		var movement: Vector3 = a.v
		# Menús y reposos pueden conservar una velocidad física anterior.
		if index>0 and (a.p as Vector3).distance_squared_to(_samples[index-1].p)<0.000001: movement = Vector3.ZERO
		return {"p":(a.p as Vector3)+movement*travelled,"r":a.r,"v":movement*(1.0-brake),"g":a.g}
	var b: Dictionary = _samples[index+1]
	var span := maxf(float(b.t)-float(a.t),0.001)
	var u := clampf((time-float(a.t))/span,0.0,1.0)
	var p0: Vector3 = a.p
	var p1: Vector3 = b.p
	# Tangentes monótonas por eje: un giro no dibuja un bucle a través de una
	# pared ni un reposo conserva la velocidad de antes de abrir un menú.
	var displacement := p1-p0
	var m0 := (a.v as Vector3)*span
	var m1 := (b.v as Vector3)*span
	for axis in 3:
		if absf(displacement[axis])<0.00001:
			m0[axis] = 0.0
			m1[axis] = 0.0
		else:
			var alpha := clampf(m0[axis]/displacement[axis],0.0,3.0)
			var beta := clampf(m1[axis]/displacement[axis],0.0,3.0)
			var length_squared := alpha*alpha+beta*beta
			var scale := minf(1.0,3.0/sqrt(maxf(length_squared,0.001)))
			m0[axis] = alpha*scale*displacement[axis]
			m1[axis] = beta*scale*displacement[axis]
	var u2 := u*u
	var u3 := u2*u
	# Restar antes de multiplicar conserva precisión en los extremos de la isla.
	var at := p0+displacement*(-2.0*u3+3.0*u2)+m0*(u3-2.0*u2+u)+m1*(u3-u2)
	var movement := (displacement*(-6.0*u2+6.0*u)+m0*(3.0*u2-4.0*u+1.0)+m1*(3.0*u2-2.0*u))/span
	# Varios pasos de física tras un tirón pueden enviar marcas de tiempo casi
	# iguales. Su derivada no debe lanzar la presentación cientos de m/s.
	movement = movement.limit_length(maxf((a.v as Vector3).length(),(b.v as Vector3).length())*1.5)
	return {"p":at,"r":lerp_angle(float(a.r),float(b.r),u),"v":movement,"g":a.g}
