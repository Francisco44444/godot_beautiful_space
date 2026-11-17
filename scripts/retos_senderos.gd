extends Node3D

class Diana:
	extends StaticBody3D
	var reto: Node
	var indice := 0
	func receive_projectile_hit(_punto: Vector3, actor: Node) -> void:
		if actor != null and reto.director.historia.is_world_authority(): reto.acertar(indice,actor)

var director: Node
var dianas := {}
var inicio_lava := Vector3.ZERO
var fin_lava := Vector3.ZERO

func iniciar(d: Node) -> void:
	director = d
	name = "RetosSenderos"
	for i in 3:
		var objetivo := Diana.new(); objetivo.reto = self; objetivo.indice = i
		objetivo.set_meta("diana_aventura",true)
		objetivo.collision_layer = 1; objetivo.collision_mask = 0
		add_child(objetivo); objetivo.position = director.historia._grounded_position(Vector2(35+i*5,235),1.7)
		var col := CollisionShape3D.new(); var caja := BoxShape3D.new(); caja.size = Vector3(1.6,1.6,0.3); col.shape = caja; objetivo.add_child(col)
		for aro in 3:
			var m := MeshInstance3D.new(); var disco := CylinderMesh.new(); disco.height = 0.12; disco.top_radius = 0.8-aro*0.24; disco.bottom_radius = disco.top_radius; disco.radial_segments = 16
			var mat := StandardMaterial3D.new(); mat.albedo_color = [Color(0.65,0.20,0.12),Color(0.86,0.75,0.48),Color(0.25,0.35,0.29)][aro]; disco.material = mat
			m.mesh = disco; m.rotation.x = PI/2; m.position.z = 0.08+aro*0.08; objetivo.add_child(m)
		var arte = preload("res://scripts/arte_aventura.gd")
		for lado in [-1.0,1.0]:
			var pata = arte.caja(objetivo,Vector3(lado*0.48,-0.85,-0.18),Vector3(0.12,1.9,0.14),Color("63472f"))
			pata.rotation.z = lado*0.16
		arte.caja(objetivo,Vector3(0,-0.6,-0.18),Vector3(1.35,0.14,0.18),Color("63472f"))
		dianas[str(i)] = objetivo
	director._rotulo(Vector2(40,228),"Las tres hojas del arquero\nAcierta desde al menos seis pasos. Cada diana abre un recuerdo.")
	var centro := Vector2(2670,1760)
	var altura := 0.0
	for i in 9: altura = maxf(altura,director.historia._grounded_position(centro+Vector2(i*2.7,0),0).y)
	altura += 0.35
	inicio_lava = Vector3(centro.x-3,altura+1.3,centro.y)
	fin_lava = Vector3(centro.x+24,altura+1.3,centro.y)
	for i in 10:
		var ancho := 4.0 if i in [0,9] else 1.7
		var punto := Vector3(centro.x-3+i*3,altura+0.6,centro.y+(0.65 if i%2 else -0.65))
		var suelo: float = director.historia._grounded_position(Vector2(punto.x,punto.z),0).y
		var cima := punto.y+0.6
		var cuerpo := StaticBody3D.new(); add_child(cuerpo); cuerpo.position = Vector3(punto.x,(cima+suelo)/2,punto.z)
		var m := MeshInstance3D.new(); var basalto := CylinderMesh.new()
		basalto.top_radius = ancho*0.62; basalto.bottom_radius = ancho*0.72; basalto.height = cima-suelo; basalto.radial_segments = 6
		basalto.material = preload("res://scripts/arte_aventura.gd").material(Color("373936"))
		m.mesh = basalto; cuerpo.add_child(m)
		var col := CollisionShape3D.new(); var forma := CylinderShape3D.new(); forma.radius = basalto.top_radius; forma.height = basalto.height; col.shape = forma; cuerpo.add_child(col)
	_crater(centro,altura)
	var zona := Area3D.new(); zona.collision_layer = 0; zona.collision_mask = 2
	add_child(zona); zona.position = Vector3(centro.x+10.5,altura+0.1,centro.y)
	var forma := CollisionShape3D.new(); var caja := BoxShape3D.new(); caja.size = Vector3(31,0.5,8); forma.shape = caja; zona.add_child(forma)
	zona.body_entered.connect(func(actor: Node3D):
		if actor is Player and not actor.network_remote:
			actor.global_position = inicio_lava; actor.velocity = Vector3.ZERO
			actor.action_feedback.emit("El calor te devuelve al último saliente. Respira y prueba otra ruta.")
	)
	director._rotulo(Vector2(centro.x-3,centro.y),"Paso de la Caldera\nSalta entre los salientes de basalto. Caer te devuelve al inicio.")
	director._crear("lava:0","Recuperar el cristal del otro lado",Vector2(fin_lava.x,fin_lava.z),Color(0.92,0.48,0.10),false)
	director.objetos["lava:0"].position = fin_lava

func _crater(centro: Vector2, altura: float) -> void:
	# La falda termina bajo el terreno real: no hay láminas suspendidas ni
	# cajas naranjas con la cara lateral expuesta al recorrer la caldera.
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fuego := SurfaceTool.new(); fuego.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origen := Vector3(centro.x+10.5,altura-0.2,centro.y)
	for i in 32:
		var puntos: Array[Vector3] = []
		for j in [i,i+1]:
			var angulo: float = float(j)*TAU/32
			var irregular := 1.0+sin(angulo*7.0)*0.035
			var borde := origen + Vector3(cos(angulo)*17*irregular,0,sin(angulo)*4.6*irregular)
			var cresta := origen + Vector3(cos(angulo)*18*irregular,0.5+0.35*sin(angulo*5),sin(angulo)*5.4*irregular)
			var pie := origen + Vector3(cos(angulo)*22.5,0,sin(angulo)*10.5)
			pie.y = director.historia._grounded_position(Vector2(pie.x,pie.z),-0.25).y
			puntos.append_array([borde,cresta,pie])
		for indice in [0,1,3,1,4,3,1,2,4,2,5,4]:
			st.set_color(Color("655649").lightened(0.1+0.12*sin(i*2.3)))
			st.add_vertex(puntos[indice])
		for punto in [origen,puntos[3],puntos[0]]: fuego.add_vertex(punto)
	st.generate_normals(); var malla := st.commit()
	var roca := StandardMaterial3D.new(); roca.albedo_color = Color("4d4940"); roca.vertex_color_use_as_albedo = true; roca.roughness = 0.96
	malla.surface_set_material(0,roca)
	var cuerpo := StaticBody3D.new(); add_child(cuerpo)
	var ladera := MeshInstance3D.new(); ladera.mesh = malla; cuerpo.add_child(ladera)
	var col := CollisionShape3D.new(); col.shape = malla.create_trimesh_shape(); cuerpo.add_child(col)
	fuego.generate_normals()
	var lava := MeshInstance3D.new(); lava.mesh = fuego.commit(); lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new(); var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; varying vec3 sitio; void vertex(){sitio=VERTEX;} void fragment(){float veta=abs(sin(sitio.x*1.4+sin(sitio.z*2.7+sin(sitio.x*0.9)))*sin(sitio.z*2.2+sin(sitio.x*0.8)-TIME*0.08)); float grieta=1.0-smoothstep(0.02,0.09,veta); vec3 calor=mix(vec3(0.16,0.035,0.018),vec3(1.0,0.27,0.015),grieta); ALBEDO=calor; EMISSION=calor*grieta; ROUGHNESS=0.85;}"
	material.shader = shader; lava.material_override = material; add_child(lava)

func acertar(i: int, actor: Node) -> void:
	var punto: Vector3 = actor.get_network_authoritative_position() if actor.network_remote else actor.global_position
	if punto.distance_to(dianas[str(i)].global_position) < 6 or punto.distance_to(dianas[str(i)].global_position)>60: return
	var id := "diana:%d" % i
	if director.hechos.has(id): return
	director.hechos[id] = true
	director._dar(actor,"Arrow",5)
	actor.action_feedback.emit("Diana acertada · un recuerdo del arquero recuperado")
	if director.hechos.has("diana:0") and director.hechos.has("diana:1") and director.hechos.has("diana:2"):
		director._dar(actor,"Crystal3",4)
		actor.action_feedback.emit("Las tres hojas del arquero · secreto descubierto")
	NetworkSession.broadcast_world_state_now()
