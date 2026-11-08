extends RefCounted

## Estados completos comprimidos, con datagramas pequeños y reordenación propia.
## Sólo se aplica una instantánea al recibir todas sus partes: fauna, recursos
## y enemigos conservan exactamente sus valores e índices originales.
const MAX_PAQUETE := 1000
const CABECERA := 28
const CARGA := MAX_PAQUETE-CABECERA
const FIRMA := 0x53484431
const MAX_CRUDO := 8*1024*1024
const MAX_COMPRIMIDO := 2*1024*1024
const MAX_PENDIENTES := 4
const CADUCIDAD_MS := 2000

var _secuencia := 0
var _ultimo_aplicado := 0
var _pendientes: Dictionary = {}
var _crudos := 0
var _comprimidos := 0
var _paquetes := 0
var _max_paquete := 0
var _completados := 0
var _rechazados := 0


func preparar(estado: Variant) -> Array[PackedByteArray]:
	var resultado: Array[PackedByteArray] = []
	var crudo := var_to_bytes(estado)
	if crudo.size()>MAX_CRUDO: return resultado
	var comprimido := crudo.compress(FileAccess.COMPRESSION_ZSTD)
	if comprimido.is_empty() or comprimido.size()>MAX_COMPRIMIDO: return resultado
	_secuencia += 1
	var cantidad := ceili(float(comprimido.size())/CARGA)
	for indice in cantidad:
		var inicio := indice*CARGA
		var longitud := mini(CARGA,comprimido.size()-inicio)
		var paquete := PackedByteArray()
		paquete.resize(CABECERA)
		paquete.encode_u32(0,FIRMA)
		paquete.encode_u64(4,_secuencia)
		paquete.encode_u32(12,indice)
		paquete.encode_u32(16,cantidad)
		paquete.encode_u32(20,crudo.size())
		paquete.encode_u32(24,comprimido.size())
		paquete.append_array(comprimido.slice(inicio,inicio+longitud))
		resultado.append(paquete)
		_max_paquete = maxi(_max_paquete,paquete.size())
	_crudos = crudo.size()
	_comprimidos = comprimido.size()
	_paquetes = cantidad
	return resultado


func recibir(paquete: PackedByteArray, ahora_ms: int = -1) -> Variant:
	if ahora_ms<0: ahora_ms = Time.get_ticks_msec()
	_caducar(ahora_ms)
	if paquete.size()<=CABECERA or paquete.size()>MAX_PAQUETE or paquete.decode_u32(0)!=FIRMA:
		_rechazados += 1
		return null
	var secuencia := paquete.decode_u64(4)
	var indice := paquete.decode_u32(12)
	var cantidad := paquete.decode_u32(16)
	var crudo := paquete.decode_u32(20)
	var comprimido := paquete.decode_u32(24)
	if secuencia<=_ultimo_aplicado or secuencia<=0: return null
	if (crudo<=0 or crudo>MAX_CRUDO or comprimido<=0 or comprimido>MAX_COMPRIMIDO
		or cantidad!=ceili(float(comprimido)/CARGA) or indice>=cantidad
		or paquete.size()!=CABECERA+mini(CARGA,comprimido-indice*CARGA)):
		_rechazados += 1
		return null
	if not _pendientes.has(secuencia):
		if _pendientes.size()>=MAX_PENDIENTES:
			var antigua: int = _pendientes.keys().min()
			if secuencia<antigua: return null
			_pendientes.erase(antigua)
		_pendientes[secuencia] = {"crudo":crudo,"comprimido":comprimido,"cantidad":cantidad,"partes":{},"inicio":ahora_ms}
	var estado: Dictionary = _pendientes[secuencia]
	if estado.crudo!=crudo or estado.comprimido!=comprimido or estado.cantidad!=cantidad:
		_rechazados += 1
		return null
	if estado.partes.has(indice): return null
	estado.partes[indice] = paquete.slice(CABECERA)
	if estado.partes.size()!=cantidad: return null
	var datos := PackedByteArray()
	for parte in cantidad: datos.append_array(estado.partes[parte])
	_pendientes.erase(secuencia)
	var descomprimido := datos.decompress(crudo,FileAccess.COMPRESSION_ZSTD)
	if descomprimido.size()!=crudo:
		_rechazados += 1
		return null
	var valor: Variant = bytes_to_var(descomprimido)
	if not valor is Dictionary and not valor is Array:
		_rechazados += 1
		return null
	_ultimo_aplicado = secuencia
	for anterior in _pendientes.keys():
		if anterior<=secuencia: _pendientes.erase(anterior)
	_completados += 1
	return valor


func _caducar(ahora_ms: int) -> void:
	for secuencia in _pendientes.keys():
		if ahora_ms-int(_pendientes[secuencia].inicio)>CADUCIDAD_MS:
			_pendientes.erase(secuencia)


func reiniciar() -> void:
	_secuencia = 0
	_ultimo_aplicado = 0
	_pendientes.clear()
	_crudos = 0
	_comprimidos = 0
	_paquetes = 0
	_max_paquete = 0
	_completados = 0
	_rechazados = 0


func estadisticas() -> Dictionary:
	return {"crudos":_crudos,"comprimidos":_comprimidos,"paquetes":_paquetes,"max_paquete":_max_paquete,
		"completados":_completados,"rechazados":_rechazados,"pendientes":_pendientes.size()}
