extends RefCounted

## Una muestra por segundo basta para detectar una zona lenta. Exigir que al
## menos el 80 % de seis segundos sea lento evita degradar por un tirón aislado.
const VENTANA_MS := 6000.0
const FRACCION_LENTA := 0.80
const TOLERANCIA := 0.98
var _ultimo_usec := 0
var _ultimos_fotogramas := 0
var _valida_anterior := false
var _objetivo := 0.0
var _duracion := 0.0
var _fotogramas := 0
var _tiempo_lento := 0.0
var _muestras: Array[Dictionary] = []

func reiniciar(ahora_usec: int, fotogramas: int) -> void:
	_ultimo_usec=ahora_usec;_ultimos_fotogramas=fotogramas
	_valida_anterior=false
	_limpiar_ventana()

func _limpiar_ventana() -> void:
	_duracion=0.0;_fotogramas=0;_tiempo_lento=0.0;_muestras.clear()

func observar(ahora_usec: int, fotogramas: int, habilitada: bool, objetivo: float) -> Dictionary:
	var ms:=float(ahora_usec-_ultimo_usec)/1000.0
	var nuevos:=fotogramas-_ultimos_fotogramas
	_ultimo_usec=ahora_usec;_ultimos_fotogramas=fotogramas
	if not habilitada or ms<=0.0 or ms>2500.0 or nuevos<0 or not is_finite(objetivo) or objetivo<1:
		reiniciar(ahora_usec,fotogramas)
		return {}
	if not _valida_anterior or not is_equal_approx(objetivo,_objetivo):
		_valida_anterior=true;_objetivo=objetivo;_limpiar_ventana()
		return {}
	_duracion+=ms;_fotogramas+=nuevos
	var fps:=float(nuevos)*1000.0/ms
	var lento:=ms if fps<objetivo*TOLERANCIA else 0.0
	_tiempo_lento+=lento
	_muestras.append({"ms":ms,"fotogramas":nuevos,"lento":lento})
	# Ventana móvil: seis segundos lentos deben detectarse aunque empiecen
	# a mitad de una ventana anterior, sin esperar otros seis segundos.
	while not _muestras.is_empty() and _duracion-float(_muestras[0].ms)>=VENTANA_MS:
		var primera:Dictionary=_muestras.pop_front()
		_duracion-=float(primera.ms);_fotogramas-=int(primera.fotogramas);_tiempo_lento-=float(primera.lento)
	if _duracion<VENTANA_MS:return {}
	var media:=float(_fotogramas)*1000.0/_duracion
	var resultado:={"fps":media,"degradar":media<objetivo*TOLERANCIA and _tiempo_lento>=_duracion*FRACCION_LENTA,"duracion_ms":_duracion}
	return resultado
