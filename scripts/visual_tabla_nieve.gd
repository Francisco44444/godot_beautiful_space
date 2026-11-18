extends Node3D
## Una puerta antigua con herrajes y correas; no hay geometría ni
## partículas actualizándose en los jugadores que están a pie.
class Pose:
	extends SkeletonModifier3D
	var jugador: Node3D
	var estado := Vector3.ZERO
	var huesos := {}
	var _derecha := Vector3.RIGHT
	var _arriba := Vector3.UP
	var _frente := Vector3.FORWARD
	func _ready() -> void:
		var s := get_skeleton()
		for n in ["Head","Hips","Torso","UpperLeg.L","UpperLeg.R","LowerLeg.L","LowerLeg.R","Foot.L","Foot.R","UpperArm.L","UpperArm.R","LowerArm.L","LowerArm.R","Fist.L","Fist.R"]:huesos[n] = s.find_bone(n)

	func _girar(s: Skeleton3D, n: String, angulo: float) -> void:
		var i: int = huesos[n]
		if i<0:return
		# En este rig los ejes locales de ambas piernas difieren. El giro en
		# espacio del esqueleto flexiona las dos rodillas hacia delante.
		var eje_local := (s.get_bone_global_pose(i).basis.orthonormalized().inverse()*_derecha).normalized()
		s.set_bone_pose_rotation(i,s.get_bone_pose_rotation(i)*Quaternion(eje_local,angulo))
	func _orientar(s: Skeleton3D, n: String, hijo: String, direccion: Vector3) -> void:
		var i: int = huesos[n];var j: int = huesos[hijo]
		if i<0 or j<0:return
		var t := s.get_bone_global_pose(i);var segmento := s.get_bone_global_pose(j).origin-t.origin
		if segmento.length_squared()<0.0001:return
		t.basis = Basis(Quaternion(segmento.normalized(),direccion.normalized()))*t.basis;s.set_bone_global_pose(i,t)
	func _pierna(s: Skeleton3D, lado: String, datos: Dictionary) -> void:
		var raiz: int = huesos["UpperLeg"+lado];var rodilla: int = huesos["LowerLeg"+lado];var pie: int = huesos["Foot"+lado]
		var origen := s.get_bone_global_pose(raiz)
		var objetivo: Transform3D = datos.pie;objetivo.origin += _arriba*0.11
		var v := objetivo.origin-origen.origin
		var largo_a: float = datos.largo_a;var largo_b: float = datos.largo_b
		var distancia := clampf(v.length(),absf(largo_a-largo_b)+0.001,largo_a+largo_b-0.001)
		var direccion := v.normalized();var coseno := clampf((largo_a*largo_a+distancia*distancia-largo_b*largo_b)/(2.0*largo_a*distancia),-1,1)
		var polo := (_frente-direccion*_frente.dot(direccion)).normalized()
		var codo := origen.origin+(direccion*coseno+polo*sqrt(maxf(0.0,1.0-coseno*coseno)))*largo_a
		var giro := Quaternion((datos.rodilla.origin-datos.raiz.origin).normalized(),(codo-origen.origin).normalized())
		origen.basis = Basis(giro)*origen.basis;s.set_bone_global_pose(raiz,origen)
		var tramo := s.get_bone_global_pose(rodilla)
		var eje_anterior: Vector3 = Basis(giro)*(datos.pie.origin-datos.rodilla.origin).normalized()
		tramo.basis = Basis(Quaternion(eje_anterior,(objetivo.origin-tramo.origin).normalized()))*tramo.basis
		s.set_bone_global_pose(rodilla,tramo);s.set_bone_global_pose(pie,objetivo)
	func _process_modification() -> void:
		var s := get_skeleton();var c: float = estado.x
		_derecha = (s.get_bone_global_pose(huesos["UpperLeg.R"]).origin-s.get_bone_global_pose(huesos["UpperLeg.L"]).origin).normalized()
		_arriba = (s.get_bone_global_pose(huesos["Head"]).origin-s.get_bone_global_pose(huesos["Hips"]).origin).normalized()
		_arriba = (_arriba-_derecha*_arriba.dot(_derecha)).normalized();_frente = _arriba.cross(_derecha).normalized()
		var piernas := {}
		for lado in [".L",".R"]:
			var r := s.get_bone_global_pose(huesos["UpperLeg"+lado]);var k := s.get_bone_global_pose(huesos["LowerLeg"+lado]);var p := s.get_bone_global_pose(huesos["Foot"+lado])
			piernas[lado] = {"raiz":r,"rodilla":k,"pie":p,"largo_a":r.origin.distance_to(k.origin),"largo_b":k.origin.distance_to(p.origin)}
		# Las botas son huesos hermanos del cuerpo, no hijos de las rodillas.
		# Bajamos la pelvis completa y resolvemos ambas cadenas hacia las botas.
		var pelvis := s.get_bone_parent(huesos["UpperLeg.L"]);var cuerpo := s.get_bone_global_pose(pelvis)
		cuerpo.origin -= _arriba*(0.12+c*0.35);s.set_bone_global_pose(pelvis,cuerpo)
		_girar(s,"Torso",-0.08-c*0.40)
		for lado in [".L",".R"]:
			_pierna(s,lado,piernas[lado])
			var signo := 1.0 if lado==".R" else -1.0
			_orientar(s,"UpperArm"+lado,"LowerArm"+lado,_derecha*signo*lerpf(0.8,0.35,c)-_arriba*0.35+_frente*lerpf(0.1,0.7,c))
			_orientar(s,"LowerArm"+lado,"Fist"+lado,_derecha*signo*lerpf(0.5,0.2,c)-_arriba*0.3+_frente*lerpf(0.35,0.9,c))

var jugador: Node3D
var pose: SkeletonModifier3D
var giro_anterior := 0.0
var nieve: CPUParticles3D
var viento: AudioStreamPlayer
var _mezcla := Vector3.ZERO
var estela: Node3D
func iniciar(p: Node3D) -> void:
	jugador = p; name = "TablaDeNieve"
	giro_anterior = p.model_root.rotation.y; p.model_root.rotation.y += PI/2
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var perfil := [Vector2(-0.18,-1.08),Vector2(0.18,-1.08),Vector2(0.27,-0.8),Vector2(0.27,0.75),Vector2(0.17,1.02),Vector2(-0.17,1.02),Vector2(-0.27,0.75),Vector2(-0.27,-0.8)]
	for i in 8:
		var j: int = (i+1)%8
		var a: Vector2 = perfil[i];var b: Vector2 = perfil[j]
		var ya := 0.07+maxf(absf(a.y)-0.7,0)*0.38;var yb := 0.07+maxf(absf(b.y)-0.7,0)*0.38
		for v in [Vector3(0,0.07,0),Vector3(b.x,yb,b.y),Vector3(a.x,ya,a.y),Vector3(a.x,ya,a.y),Vector3(b.x,yb,b.y),Vector3(b.x,yb-0.07,b.y),Vector3(a.x,ya,a.y),Vector3(b.x,yb-0.07,b.y),Vector3(a.x,ya-0.07,a.y)]:st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new();m.mesh = st.commit();m.material_override = preload("res://scripts/arte_aventura.gd").material(Color("765037")).duplicate();m.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED;add_child(m)
	for z in [-0.42,0.42]:
		preload("res://scripts/arte_aventura.gd").caja(self,Vector3(0,0.14,z),Vector3(0.52,0.10,0.16),Color("62422e"))
	# Una puerta recuperada: juntas de tablón, bisagras y herrajes antiguos.
	var arte = preload("res://scripts/arte_aventura.gd")
	for x in [-0.09,0.09]:arte.caja(self,Vector3(x,0.078,0),Vector3(0.015,0.012,1.60),Color("422c20"))
	for z in [-0.7,0.7]:
		arte.caja(self,Vector3(0,0.13,z),Vector3(0.47,0.045,0.13),Color("3f4c50"))
		for x in [-0.16,0.16]:arte.cilindro(self,Vector3(x,0.162,z),0.028,0.018,Color("b49861"))
	var aldaba := TorusMesh.new();aldaba.inner_radius = 0.06;aldaba.outer_radius = 0.085;aldaba.rings = 10;aldaba.ring_segments = 5;aldaba.material = arte.material(Color("aa8c53"),0.6)
	var aro := MeshInstance3D.new();aro.mesh = aldaba;aro.position = Vector3(0,0.13,-0.85);add_child(aro)
	var mundo := p.get_tree().current_scene
	var nombre_estela := "RastroTabla_%d" % p.get_instance_id()
	estela = mundo.get_node_or_null(nombre_estela)
	if estela==null:estela = preload("res://scripts/estela_tabla.gd").new();estela.name = nombre_estela;mundo.add_child(estela)
	estela.iniciar(p,mundo.terrain)
	_crear_pose()
	nieve = CPUParticles3D.new();nieve.name = "NieveDelCanto";nieve.amount = 32;nieve.lifetime = 0.42;nieve.local_coords = false;nieve.emitting = false
	nieve.direction = Vector3(0,0.6,1);nieve.spread = 42;nieve.initial_velocity_min = 0.8;nieve.initial_velocity_max = 3.5;nieve.gravity = Vector3(0,-3,0)
	nieve.scale_amount_min = 0.4;nieve.scale_amount_max = 1.0;nieve.color = Color("e3f2ff");nieve.position.y = 0.15
	var copo := SphereMesh.new();copo.radius = 0.055;copo.height = 0.11;copo.radial_segments = 4;copo.rings = 2;copo.material = preload("res://scripts/arte_aventura.gd").material(Color("e3f2ff"));nieve.mesh = copo;nieve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(nieve)
	if not p.network_remote:
		viento = AudioStreamPlayer.new();viento.name = "AireDelDescenso";viento.stream = preload("res://assets/audio/original/valley_wind.ogg").duplicate();viento.stream.loop = true;viento.bus = "SFX";viento.volume_db = -60;add_child(viento);viento.play()

func _crear_pose() -> void:
	pose = Pose.new();pose.jugador = jugador;pose.name = "PosturaTabla";jugador.skeleton.add_child(pose)

func _process(delta: float) -> void:
	if not is_instance_valid(jugador):return
	if is_instance_valid(estela) and not estela.is_physics_processing():estela.set_physics_process(true)
	if not is_instance_valid(pose):_crear_pose()
	if jugador.network_remote:
		_mezcla = _mezcla.lerp(jugador.postura_nieve,1.0-exp(-9.0*delta))
		jugador.visual.rotation.x = _mezcla.z;jugador.visual.rotation.z = _mezcla.y*0.25
		pose.estado = _mezcla
	else:pose.estado = jugador.postura_nieve
	if is_instance_valid(estela) and estela.terreno!=null:
		var normal: Vector3 = estela.terreno.data.get_normal(jugador.global_position)
		if normal.is_finite():
			var yaw: float = jugador.get_network_facing_yaw();var lateral := Vector3(cos(yaw),0,-sin(yaw))
			var canto := atan2(-normal.dot(lateral),maxf(normal.y,0.1))
			rotation.z = lerp_angle(rotation.z,canto-jugador.visual.rotation.z,1.0-exp(-12.0*delta))
	var rapidez: float = Vector2(jugador.velocity.x,jugador.velocity.z).length()
	var suelo: bool = jugador.get("_network_grounded") if jugador.network_remote else jugador.is_on_floor()
	nieve.emitting = suelo and rapidez>6.0 and is_instance_valid(estela) and estela.en_nieve
	nieve.direction.x = -jugador.postura_nieve.y*2.0
	nieve.initial_velocity_max = 1.8+absf(jugador.postura_nieve.y)*6.0
	if viento!=null:
		var intensidad := smoothstep(3.0,36.0,rapidez) if not jugador.entrada_interfaz_bloqueada and not get_tree().paused else 0.0
		viento.volume_db = lerpf(-45,-13,intensidad);viento.pitch_scale = lerpf(0.8,1.6,intensidad)
func retirar() -> void:
	if is_instance_valid(estela):estela.terminar()
	if is_instance_valid(jugador):
		jugador.en_tabla_nieve = false
		if is_instance_valid(jugador.model_root):jugador.model_root.rotation.y = giro_anterior
	if is_instance_valid(pose):pose.active = false;pose.queue_free()
	queue_free()
