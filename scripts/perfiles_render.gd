extends RefCounted

## Resolución pura: la preferencia se conserva separada del resultado aplicado.
## No consulta dispositivos ni modifica Viewport, ajustes, LOD, MSAA o interfaz.
const MINIMO_INTERNO := Vector2i(1280,720)
const MODO_NATIVO := 0
const MODO_FSR1 := 1
const MODO_METAL_ESPACIAL := 3

static func resolver(perfil: int, salida: Vector2i, renderer: String, metal_spatial: bool) -> Dictionary:
	var solicitado := perfil if perfil >= 0 and perfil <= 2 else 0
	if salida.x <= 0 or salida.y <= 0:
		return _nativo(solicitado,Vector2i.ZERO)
	if solicitado == 0 or renderer != "forward_plus":
		return _nativo(solicitado,salida)
	var escala_base := 0.77 if solicitado == 1 else 2.0 / 3.0
	var escala := maxf(escala_base,maxf(float(MINIMO_INTERNO.x)/salida.x,float(MINIMO_INTERNO.y)/salida.y))
	if escala >= 1.0:
		return _nativo(solicitado,salida)
	var entrada := _entrada(salida,escala)
	# Godot almacena la escala como float32 y trunca el producto float32 a int.
	# Si el redondeo cae bajo el mínimo, subir un ULP conserva ese contrato.
	while entrada.x < MINIMO_INTERNO.x or entrada.y < MINIMO_INTERNO.y:
		escala = _siguiente_float32(escala)
		if escala >= 1.0: return _nativo(solicitado,salida)
		entrada = _entrada(salida,escala)
	var modo := MODO_METAL_ESPACIAL if metal_spatial else MODO_FSR1
	return {"profile":solicitado,"scale":escala,"mode":modo,"input_expected":entrada}

static func _nativo(perfil: int, salida: Vector2i) -> Dictionary:
	return {"profile":perfil,"scale":1.0,"mode":MODO_NATIVO,"input_expected":salida}

static func _float32(valor: float) -> float:
	return PackedFloat32Array([valor])[0]

static func _entrada(salida: Vector2i, escala: float) -> Vector2i:
	var escala_real := _float32(escala)
	return Vector2i(int(_float32(salida.x * escala_real)),int(_float32(salida.y * escala_real)))

static func _siguiente_float32(valor: float) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0,valor)
	bytes.encode_u32(0,bytes.decode_u32(0)+1)
	return bytes.decode_float(0)
