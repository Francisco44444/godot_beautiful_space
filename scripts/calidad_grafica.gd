extends RefCounted

## Costes reales y reversibles del render. No cambia recursos de aventura,
## físicas, identidades del bosque ni el reloj compartido de la expedición.
const NOMBRES: Array[String] = ["Automática", "Alta", "Equilibrada", "Rendimiento", "Personalizada"]
const NIVEL_MINIMO := 4
const OPCIONES := {
	"shadow_quality": [0.0,3.0,3.0], "shadow_distance": [50.0,480.0,480.0],
	"ssao": [0.0,1.0,1.0], "fog_quality": [0.0,2.0,2.0],
	"glow": [0.0,1.0,1.0], "grass_density": [0.5,1.0,1.0],
	"tree_distance": [2000.0,5200.0,5200.0], "antialiasing": [0.0,3.0,0.0],
}

static func valores_iniciales() -> Dictionary:
	var salida: Dictionary = {}
	for clave in OPCIONES: salida[clave]=float(OPCIONES[clave][2])
	return salida

static func validar(clave: String, valor: Variant) -> float:
	var limites: Array=OPCIONES[clave]
	var numero:=float(valor) if valor is int or valor is float or valor is bool else float(limites[2])
	if not is_finite(numero):numero=float(limites[2])
	numero=clampf(numero,float(limites[0]),float(limites[1]))
	if clave in ["shadow_quality","ssao","fog_quality","glow","antialiasing"]:numero=roundf(numero)
	if clave=="shadow_distance" or clave=="tree_distance":numero=snappedf(numero,10.0)
	if clave=="grass_density":numero=snappedf(numero,0.25)
	return numero

static func preset(nivel: int) -> Dictionary:
	var salida:=valores_iniciales()
	salida.merge({"render_profile":0,"manual_scale":0.75,"lod":340.0})
	if nivel==2:
		salida.merge({"shadow_quality":2.0,"shadow_distance":180.0,"fog_quality":1.0,"grass_density":0.75,"render_profile":1,"lod":260.0},true)
	elif nivel>=3:
		salida.merge({"shadow_quality":1.0,"shadow_distance":100.0,"fog_quality":0.0,"ssao":0.0,"glow":0.0,"grass_density":0.5,"tree_distance":3200.0,"render_profile":3,"manual_scale":0.5,"lod":180.0},true)
	if nivel>=NIVEL_MINIMO:
		salida.merge({"shadow_quality":0.0,"shadow_distance":50.0,"tree_distance":2000.0,"manual_scale":0.35},true)
	return salida

static func nombre_nivel(nivel: int) -> String:
	return "Mínima" if nivel==NIVEL_MINIMO else NOMBRES[clampi(nivel,1,3)]

static func percentil(muestras: Array[float], fraccion: float=0.75) -> float:
	if muestras.is_empty():return 0.0
	var ordenadas:=muestras.duplicate();ordenadas.sort()
	return ordenadas[clampi(int(ceil((ordenadas.size()-1)*fraccion)),0,ordenadas.size()-1)]

static func recomendar(
	nivel: int, gpu_ms: float, cpu_ms: float, pared_ms: float,
	objetivo: int, limite_ms: float, fraccion_presupuesto: float = 0.95
) -> int:
	var presupuesto:=1000.0/clampi(objetivo,30,144)
	# GPU/CPU excluyen la espera de VSync. Sin temporizadores de GPU, una
	# muestra pegada al límite de pantalla no demuestra falta de potencia.
	var coste:=maxf(gpu_ms,cpu_ms)
	if limite_ms<=0.0 or pared_ms>limite_ms*1.15:coste=maxf(coste,pared_ms)
	if coste>presupuesto * fraccion_presupuesto:return mini(nivel+1,NIVEL_MINIMO)
	if nivel==2 and gpu_ms>0.0 and coste<presupuesto*0.70:return 1
	return nivel
