extends SceneTree
func _init() -> void:call_deferred("_probar")
func exigir(valor: bool, mensaje: String) -> bool:
	if valor:return true
	push_error(mensaje);quit(1);return false
func hueso(p: Node3D, nombre: String) -> BoneAttachment3D:
	var nodo := BoneAttachment3D.new();nodo.bone_name = nombre;p.skeleton.add_child(nodo);return nodo
func _probar() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for n in ["InventoryManager","ExplorationManager"]:root.get_node(n).set("autosave_enabled",false)
	var m = load("res://scenes/world.tscn").instantiate();root.add_child(m);current_scene = m;root.get_node("SaveGameManager").bind_world(null)
	for i in 15:await process_frame
	paused = false
	var c = m.get_node("RPGStoryRuntime").aventura_pacifica.descenso;var p = m.player;var cam = m.get_node("CameraRig")
	p.global_position = c.puertas[0];p.velocity = Vector3.ZERO
	for i in 25:await physics_frame
	c.interactuar("salida",p);p.set_physics_process(false)
	var cadera := hueso(p,"Hips");var rodilla := hueso(p,"LowerLeg.L");var cabeza := hueso(p,"Head");var pie_i := hueso(p,"Foot.L");var pie_d := hueso(p,"Foot.R")
	p.postura_nieve = Vector3.ZERO
	for i in 40:await process_frame
	print("NIEVE_HUESOS_REPOSO ",cadera.global_position-p.global_position," rodilla=",rodilla.global_position-p.global_position," pie=",pie_i.global_position-p.global_position)
	var altura_cabeza: float = cabeza.global_position.y
	var altura_pies: float = (pie_i.global_position.y+pie_d.global_position.y)*0.5
	p.postura_nieve.x = 1.0
	for i in 40:await process_frame
	print("NIEVE_HUESOS_CUCLILLAS ",cadera.global_position-p.global_position," rodilla=",rodilla.global_position-p.global_position," pie=",pie_i.global_position-p.global_position)
	var bajada: float = altura_cabeza-cabeza.global_position.y
	var diferencia_pies: float = absf(altura_pies-(pie_i.global_position.y+pie_d.global_position.y)*0.5)
	print("NIEVE_POSTURA_MEDIDA cabeza=",altura_cabeza," nueva=",cabeza.global_position.y," bajada=",bajada," pies=",diferencia_pies)
	if not exigir(bajada>0.25,"La pose visible no agacha realmente la cabeza"):return
	if not exigir(diferencia_pies<0.04,"Los pies visibles se separan de la tabla al agacharse"):return
	print("NIEVE_POSE bajada=",bajada," deriva_pies=",diferencia_pies)
	c.abandonar();p.set_physics_process(true)
	for control in [4,28]:
		p.global_position = c.puertas[control-1];p.velocity = Vector3.ZERO
		for i in 25:await physics_frame
		c._empezar(1,p);c._physics_process(3.1);p.global_position=c.puertas[control-1];c.carreras["1"].puerta = control;c.carreras["1"].anterior = p.global_position
		var t: Vector3 = c.puertas[control]-p.global_position
		c.movimiento.rumbo = atan2(-t.x,-t.z);cam.yaw = c.movimiento.rumbo;cam.pitch = -0.4;cam.snap_to_target()
		Input.action_press("move_forward");Input.action_press("sprint")
		for i in 120:await physics_frame
		if not exigir(cam.spring_arm.get_hit_length()>3.5,"La cámara entra en el cuerpo al bajar por una pendiente"):return
		print("NIEVE_CAMARA brazo=",cam.spring_arm.get_hit_length())
		Input.action_release("move_forward");Input.action_release("sprint");c.abandonar()
	print("SNOW POSE CAMERA PASS");quit(0)
