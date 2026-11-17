extends RefCounted
## Decoración estática compartida: sin luces por puzle ni bucles de animación.
static var _materiales := {}
static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var clave := str(color)+str(metal)
	if not _materiales.has(clave):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metal
		m.roughness = 0.28 if metal > 0 else 0.88
		_materiales[clave] = m
	return _materiales[clave]
static func caja(padre: Node3D, posicion: Vector3, tamano: Vector3, color: Color, nombre: String = "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var forma := BoxMesh.new(); forma.size = tamano; forma.material = material(color)
	m.mesh = forma; m.position = posicion; m.visibility_range_end = 180
	if not nombre.is_empty(): m.name = nombre
	padre.add_child(m)
	return m
static func cilindro(padre: Node3D, posicion: Vector3, radio: float, alto: float, color: Color, nombre: String = "") -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var forma := CylinderMesh.new(); forma.top_radius = radio; forma.bottom_radius = radio*1.06; forma.height = alto; forma.radial_segments = 8; forma.material = material(color)
	m.mesh = forma; m.position = posicion; m.visibility_range_end = 180
	if not nombre.is_empty(): m.name = nombre
	padre.add_child(m)
	return m
static func decorar(nodo: Node3D, id: String) -> void:
	var piedra := Color("77786b")
	var bronce := Color("a48646")
	var madera := Color("63472f")
	if not id.begins_with("acto:"):
		var original := nodo.get_child(0) as MeshInstance3D
		original.visible = false
		caja(nodo,Vector3(0,0.25,0),Vector3(1.15,0.5,0.7),madera)
		caja(nodo,Vector3(0,0.54,0),Vector3(1.22,0.13,0.77),madera.lightened(0.12))
		for x in [-0.38,0.38]: caja(nodo,Vector3(x,0.30,0),Vector3(0.08,0.6,0.8),bronce)
		caja(nodo,Vector3(0,0.36,0.38),Vector3(0.12,0.2,0.08),bronce)
		return
	var acto := int(id.split(":")[1])
	cilindro(nodo,Vector3(0,0.10,0),1.05,0.2,piedra.darkened(0.15))
	cilindro(nodo,Vector3(0,1.15,0),0.62,0.12,bronce)
	if acto == 1:
		for x in [-0.85,0.85]: caja(nodo,Vector3(x,1.3,0),Vector3(0.14,2.6,0.18),madera)
		caja(nodo,Vector3(0,2.55,0),Vector3(1.9,0.18,0.22),madera)
		caja(nodo,Vector3(0,1.75,0),Vector3(0.07,1.6,0.07),bronce)
	elif acto == 2:
		var giro := Node3D.new(); giro.name = "Espejo"; nodo.add_child(giro)
		caja(giro,Vector3(0,1.85,0),Vector3(1.2,1.25,0.16),bronce)
		var cristal := caja(giro,Vector3(0,1.85,0.10),Vector3(0.98,1.02,0.04),Color("6b99ac"))
		cristal.material_override = material(Color("84b2c1"),0.75)
		caja(giro,Vector3(0,2.63,0.18),Vector3(0.08,0.2,0.3),bronce)
	elif acto == 3:
		var rueda := Node3D.new(); rueda.name = "Valvula"; nodo.add_child(rueda)
		for angulo in 3:
			var aspa := caja(rueda,Vector3(0,1.55,0),Vector3(1.05,0.09,0.14),bronce)
			aspa.rotation.z = angulo*PI/3
		caja(nodo,Vector3(0,0.18,2),Vector3(1.6,0.35,3.4),piedra.darkened(0.2))
		caja(nodo,Vector3(0,0.37,2),Vector3(1.25,0.04,3.05),Color("337c8d"),"Agua")
		for x in [-0.77,0.77]: caja(nodo,Vector3(x,0.45,2),Vector3(0.17,0.35,3.4),piedra)
	elif acto == 4:
		cilindro(nodo,Vector3(0,1.7,0),0.48,0.7,bronce)
		cilindro(nodo,Vector3(0,1.36,0),0.62,0.12,bronce)
		caja(nodo,Vector3(0,2.25,0),Vector3(0.14,0.4,0.14),madera)
	elif acto == 0:
		var esfera := SphereMesh.new(); esfera.radius = 0.22; esfera.height = 0.44; esfera.radial_segments = 8; esfera.rings = 4; esfera.material = material(Color("b2b864"))
		var semilla := MeshInstance3D.new(); semilla.mesh = esfera; semilla.position.y = 1.45; nodo.add_child(semilla)
