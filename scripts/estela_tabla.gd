extends Node3D
## Dos cantos sobre el relieve real, con memoria limitada a diez segundos.
## No añade colisiones ni mensajes de red: cada cliente ve la trazada de las
## posiciones ya interpoladas. Al bajarse, el último surco se desvanece y cesa.
var jugador: Node3D
var terreno: Node
var muestras: Array = []
var reloj := 0.0
var _acumulado := 0.0
var _malla: ImmediateMesh
var _dibujo: MeshInstance3D
var _unir := false
var en_nieve := false

func iniciar(p: Node3D, t: Node) -> void:
	jugador = p;terreno = t
	if _malla!=null:return
	_malla = ImmediateMesh.new();_dibujo = MeshInstance3D.new();_dibujo.mesh = _malla
	var material := StandardMaterial3D.new();material.vertex_color_use_as_albedo = true;material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode = BaseMaterial3D.CULL_DISABLED;material.roughness = 1
	_dibujo.material_override = material;_dibujo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_dibujo.visibility_range_end = 240;add_child(_dibujo)
func terminar() -> void:jugador = null;_unir = false
func _physics_process(delta: float) -> void:
	reloj += delta;_acumulado += delta
	if _acumulado<0.05:return
	_acumulado = 0
	while not muestras.is_empty() and reloj-float(muestras[0].tiempo)>10.0:muestras.pop_front()
	if is_instance_valid(jugador) and jugador.en_tabla_nieve:
		var suelo: bool = jugador.get("_network_grounded") if jugador.network_remote else jugador.is_on_floor()
		var textura: Vector3 = terreno.data.get_texture_id(jugador.global_position)
		en_nieve = (int(textura.x)==4 and textura.z<0.70) or (int(textura.y)==4 and textura.z>0.30)
		if jugador.is_visible_in_tree() and suelo and en_nieve and Vector2(jugador.velocity.x,jugador.velocity.z).length()>2:
			var yaw: float = jugador.get_network_facing_yaw();var lateral := Vector3(cos(yaw),0,-sin(yaw))
			var punto: Vector3 = jugador.global_position
			var izquierda := punto-lateral*0.28;var derecha := punto+lateral*0.28
			izquierda.y = terreno.data.get_height(izquierda)+0.025;derecha.y = terreno.data.get_height(derecha)+0.025
			if izquierda.is_finite() and derecha.is_finite():
				var continuar: bool = _unir and not muestras.is_empty() and punto.distance_to(muestras[-1].punto)<5.0
				muestras.append({"izquierda":izquierda,"derecha":derecha,"punto":punto,"tiempo":reloj,"unir":continuar});_unir = true
				if muestras.size()>192:muestras.pop_front()
		else:_unir = false
	else:jugador = null
	if muestras.is_empty() and jugador==null:queue_free();return
	if muestras.is_empty() and is_instance_valid(jugador) and not jugador.is_visible_in_tree():set_physics_process(false);return
	_dibujar()
func _dibujar() -> void:
	_malla.clear_surfaces()
	if muestras.size()<2:return
	var tramos: Array[int] = []
	for i in range(1,muestras.size()):
		if muestras[i].unir:tramos.append(i)
	if tramos.is_empty():return
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLES);_malla.surface_set_normal(Vector3.UP)
	for i in tramos:
		var a: Dictionary = muestras[i-1];var b: Dictionary = muestras[i]
		if not b.unir:continue
		var ancho_a: Vector3 = (a.derecha-a.izquierda).normalized()*0.065
		var ancho_b: Vector3 = (b.derecha-b.izquierda).normalized()*0.065
		var alfa := 0.65*(1.0-smoothstep(5.0,10.0,reloj-float(a.tiempo)))
		_malla.surface_set_color(Color(0.47,0.63,0.74,alfa))
		for lado in ["izquierda","derecha"]:
			for v in [a[lado]-ancho_a,a[lado]+ancho_a,b[lado]+ancho_b,a[lado]-ancho_a,b[lado]+ancho_b,b[lado]-ancho_b]:_malla.surface_add_vertex(v)
	_malla.surface_end()
