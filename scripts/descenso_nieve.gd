extends Node3D
## Sólo se vigilan carreras activas, diez veces por segundo. La posición ya
## viaja por el transporte de movimiento del juego; no se duplica por tabla.
const RUTA = preload("res://scripts/ruta_nieve.gd").PUNTOS
var rivales: Node3D
var director: Node
var mundo: Node3D
var puertas: Array[Vector3] = []
var carreras := {}
var records := {}
var premiados := {}
var secretos := {}
var cristal: Vector3
var movimiento: RefCounted
var _reloj := 0.0
var _slot_anterior := 1
var _snap_anterior := 0.5
var _angulo_suelo_anterior := PI/4
var _etiqueta: Label
var _titulo: Label
var _capa: CanvasLayer
var _visuales := {}
var _peticion_pendiente := false
var _ultima_postura := {}
var _efecto_velocidad: ColorRect
var _material_velocidad: ShaderMaterial
var _intensidad_velocidad := 0.0
var _regreso_sostenido := false
var _historia_visible := true

func iniciar(d: Node) -> void:
	director = d;mundo = d.mundo;name = "DescensoNieve";process_mode = Node.PROCESS_MODE_ALWAYS
	for p in RUTA: puertas.append(d.historia._grounded_position(p,0.12))
	_construir_recorrido()
	rivales = preload("res://scripts/rivales_descenso.gd").new();add_child(rivales);rivales.iniciar(self)
	_capa = CanvasLayer.new();_capa.layer = 4;add_child(_capa)
	var panel := PanelContainer.new();panel.position = Vector2(440,16);panel.custom_minimum_size = Vector2(720,0);_capa.add_child(panel)
	var marco := StyleBoxFlat.new();marco.bg_color = Color(0.025,0.055,0.075,0.82);marco.border_color = Color("9a8050");marco.set_border_width_all(1);marco.set_corner_radius_all(8);marco.content_margin_left = 14;marco.content_margin_right = 14;marco.content_margin_top = 8;marco.content_margin_bottom = 8;panel.add_theme_stylebox_override("panel",marco)
	var filas := VBoxContainer.new();filas.add_theme_constant_override("separation",2);panel.add_child(filas)
	_titulo = Label.new();_titulo.text = "LAS CAMPANAS BLANCAS";_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;_titulo.add_theme_font_override("font",preload("res://assets/fonts/cartografia/Cinzel.ttf"));_titulo.add_theme_font_size_override("font_size",17);_titulo.add_theme_color_override("font_color",Color("e6cc91"));filas.add_child(_titulo)
	_etiqueta = Label.new();_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;_etiqueta.add_theme_font_override("font",preload("res://assets/fonts/cartografia/CrimsonPro.ttf"));_etiqueta.add_theme_font_size_override("font_size",24);filas.add_child(_etiqueta)
	var mandos := Label.new();mandos.text = "A/D cantear · Mayús agacharse · S frenar · Espacio saltar · R volver · E bajarse";mandos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;mandos.add_theme_font_size_override("font_size",12);mandos.add_theme_color_override("font_color",Color("c1c2b9"));filas.add_child(mandos);_capa.hide()

	var capa_velocidad := CanvasLayer.new();capa_velocidad.layer = 0;add_child(capa_velocidad)
	_efecto_velocidad = ColorRect.new();_efecto_velocidad.name = "VelocidadLateral";_efecto_velocidad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_efecto_velocidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material_velocidad = ShaderMaterial.new();_material_velocidad.shader = preload("res://shaders/velocidad_descenso.gdshader");_efecto_velocidad.material = _material_velocidad;capa_velocidad.add_child(_efecto_velocidad);_efecto_velocidad.hide();set_process(false)
	NetworkSession.session_ended.connect(_cerrar_sesion)
	set_physics_process(false)

func _construir_recorrido() -> void:
	var arte = preload("res://scripts/arte_aventura.gd")
	var paño := QuadMesh.new();paño.size = Vector2(1.35,0.65);paño.subdivide_width = 4;paño.subdivide_depth = 2
	var tejido := ShaderMaterial.new();tejido.shader = preload("res://shaders/estandarte_nieve.gdshader")
	var tejido_meta := tejido.duplicate();tejido_meta.set_shader_parameter("tela",Color("80512d"))
	for i in puertas.size():
		var tangente := puertas[mini(i+1,puertas.size()-1)]-puertas[maxi(i-1,0)];tangente.y = 0;tangente = tangente.normalized()
		var lateral := Vector3(-tangente.z,0,tangente.x)
		var grupo := Node3D.new();grupo.name = "Puerta%d" % i;add_child(grupo);grupo.position = puertas[i]
		for lado in [-1.0,1.0]:
			var punto: Vector3 = puertas[i]+lateral*6.0*lado;punto.y = mundo.terrain.data.get_height(punto)
			arte.cilindro(grupo,punto-puertas[i]+Vector3.UP*1.7,0.09,3.4,Color("705039"))
			var bandera := MeshInstance3D.new();bandera.mesh = paño;bandera.material_override = tejido_meta if i==0 or i==puertas.size()-1 else tejido
			bandera.position = punto-puertas[i]+Vector3.UP*2.9-lateral*lado*0.65;bandera.visibility_range_end = 180;bandera.custom_aabb = AABB(Vector3(-0.8,-0.4,-0.3),Vector3(1.6,0.8,0.6));grupo.add_child(bandera)
			bandera.rotation.y = atan2(-tangente.x,-tangente.z)
			var poste_local := bandera.transform.affine_inverse()*(punto-puertas[i]+Vector3.UP*2.9)
			if poste_local.x>0:bandera.scale.x = -1.0
		var cartel := Label3D.new();cartel.text = "SALIDA · LAS CAMPANAS BLANCAS" if i==0 else ("META · EL CLARO DEL VIENTO" if i==puertas.size()-1 else str(i));cartel.position.y = 3.7;cartel.font_size = 40;cartel.outline_size = 5;cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED;cartel.visibility_range_end = 95;grupo.add_child(cartel)
	# Un eco al margen de la línea rápida recompensa explorar entre los pinos.
	var t_secreto := (puertas[6]-puertas[4]).normalized()
	cristal = puertas[5]+Vector3(-t_secreto.z,0,t_secreto.x)*12.0
	cristal.y = mundo.terrain.data.get_height(cristal)+1.1
	var gema := MeshInstance3D.new();var forma := SphereMesh.new();forma.radius = 0.32;forma.height = 1.0;forma.radial_segments = 5;forma.rings = 3;gema.mesh = forma;gema.position = cristal
	var mat := StandardMaterial3D.new();mat.albedo_color = Color("61b4c3");mat.emission_enabled = true;mat.emission = Color("286e88");gema.material_override = mat;gema.visibility_range_end = 70;add_child(gema)
	# Los labios se pueden rodear o usar para enlazar un salto largo.
	for i in [18,40,60]:_construir_rampa(i)
	var salida = preload("res://scripts/objeto_aventura.gd").new();salida.director = self;salida.identificador = "salida";salida.titulo = "Deslizarte en la vieja puerta · A/D girar, Mayús agacharte y acelerar, S frenar, Espacio saltar";add_child(salida);salida.position = puertas[0]-Vector3(2,0,0)
	arte.caja(salida,Vector3(0,0.8,0),Vector3(2.7,0.12,1.1),Color("705039"))
	for x in [-0.95,0.95]:arte.caja(salida,Vector3(x,0.4,0),Vector3(0.15,0.8,0.8),Color("705039"))
	for x in [-0.65,0.0,0.65]:
		arte.caja(salida,Vector3(x,0.92,0),Vector3(0.48,0.08,1.8),Color("765037"))
		for z in [-0.65,0.65]:arte.caja(salida,Vector3(x,0.98,z),Vector3(0.48,0.04,0.10),Color("3f4c50"))
	var inscripcion := Label3D.new();inscripcion.text = "Las Campanas Blancas\nLa puerta de un viejo granero, ahora sobre la nieve.\nGana a Brina, Telmo y Lúa cruzando las 76 puertas. E para bajarte.\nVuelve a la última bandera si te sales.\nTu primera victoria recupera tres cristales de escarcha.\nBusca el eco azul fuera de la línea rápida.";inscripcion.position.y = 2.2;inscripcion.font_size = 32;inscripcion.outline_size = 5;inscripcion.billboard = BaseMaterial3D.BILLBOARD_ENABLED;inscripcion.visibility_range_end = 24;salida.add_child(inscripcion)

func _construir_rampa(i: int) -> void:
	var arte = preload("res://scripts/arte_aventura.gd")
	var eje := (puertas[i+1]-puertas[i]).normalized();eje.y = 0;eje = eje.normalized()
	var lado := Vector3(-eje.z,0,eje.x)
	var centro_rampa := puertas[i].lerp(puertas[i+1],0.58)
	var vertices: Array[Vector3] = []
	for par in [Vector2(-3,-4.5),Vector2(3,-4.5),Vector2(-3,4.5),Vector2(3,4.5)]:
		var punto: Vector3 = centro_rampa+lado*par.x+eje*par.y;punto.y = mundo.terrain.data.get_height(punto)+(1.8 if par.y>0 else 0.03);vertices.append(punto)
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indice in [0,2,1,1,2,3]:st.add_vertex(vertices[indice])
	for borde in [Vector2i(0,1),Vector2i(1,3),Vector2i(3,2),Vector2i(2,0)]:
		var a: Vector3 = vertices[borde.x];var b: Vector3 = vertices[borde.y]
		var base_a := Vector3(a.x,mundo.terrain.data.get_height(a),a.z);var base_b := Vector3(b.x,mundo.terrain.data.get_height(b),b.z)
		for v in [a,base_a,b,b,base_a,base_b]:st.add_vertex(v)
	st.generate_normals();var rampa := MeshInstance3D.new();rampa.mesh = st.commit();rampa.material_override = arte.material(Color("dcebf1")).duplicate();rampa.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cuerpo := StaticBody3D.new();cuerpo.name = "RampaNieve_%d" % i;cuerpo.set_meta("centro",centro_rampa);var col := CollisionShape3D.new();col.shape = rampa.mesh.create_trimesh_shape();col.shape.backface_collision = true;cuerpo.add_child(rampa);cuerpo.add_child(col);add_child(cuerpo)

func interactuar(_id: String, actor: Node) -> bool:
	if actor!=mundo.player:return false
	if actor.global_position.distance_to(puertas[0])>6:return false
	if _peticion_pendiente:return true
	if NetworkSession.session_mode==NetworkSession.SessionMode.CLIENT:
		_peticion_pendiente = true;_pedir_inicio.rpc_id(1)
	else: _empezar(1,actor)
	return true

@rpc("any_peer","call_remote","reliable",6)
func _pedir_inicio() -> void:
	if not NetworkSession.is_host():return
	var peer := multiplayer.get_remote_sender_id();var actor = mundo.network_players.get_node_or_null("Peer_%d" % peer)
	if actor!=null and actor.get_network_authoritative_position().distance_to(puertas[0])<7:_empezar(peer,actor)
	else:_confirmar_inicio.rpc_id(peer,false)

func _empezar(peer: int, actor: Node3D) -> void:
	if carreras.has(str(peer)):return
	if not carreras.is_empty() and rivales.tiempo>5:
		if peer==1:actor.action_feedback.emit("La carrera ya está en marcha. Espera a que termine el grupo.")
		else:_confirmar_inicio.rpc_id(peer,false,"La carrera ya está en marcha. Espera a que termine el grupo.")
		return
	if carreras.is_empty():rivales.nueva()
	var fila := 0
	while carreras.values().any(func(e):return int(e.get("fila",0))==fila):fila += 1
	carreras[str(peer)] = {"fila":fila,"ranura":actor.equipped_slot,"puerta":1,"tiempo":0.0,"penalizacion":0.0,"anterior":puertas[0],"ultimo_paso":0.0,"rearme":0.0,"secreto":false}
	if actor==mundo.player:_montar(fila)
	else:
		_actualizar_visuales()
		_confirmar_inicio.rpc_id(peer,true,"",fila)
	set_physics_process(true);NetworkSession.broadcast_world_state_now()

@rpc("authority","call_remote","reliable",6)
func _confirmar_inicio(aceptado: bool, motivo: String = "Acércate a las tablas de la salida para empezar.", fila: int = 0) -> void:
	_peticion_pendiente = false
	if aceptado:_montar(fila)
	else:mundo.player.action_feedback.emit(motivo)

func _montar(fila: int = 0) -> void:
	var p = mundo.player
	if p.is_mounted():p.dismount()
	_slot_anterior = p.equipped_slot;_snap_anterior = p.floor_snap_length;_angulo_suelo_anterior = p.floor_max_angle;p.floor_max_angle = deg_to_rad(72);p._clear_equipped_item()
	movimiento = preload("res://scripts/movimiento_tabla.gd").new()
	var t := puertas[1]-puertas[0];t.y = 0;t = t.normalized();movimiento.rumbo = atan2(-t.x,-t.z)
	var carriles := PackedFloat32Array([1.3,-1.3,4.0,-4.0]);var lateral := Vector3(-t.z,0,t.x)
	p.global_position = puertas[0]+lateral*carriles[fila%4]-t*float(fila/4)*3.0
	p.global_position.y = mundo.terrain.data.get_height(p.global_position)+0.18;p.velocity = Vector3.ZERO
	p.tabla_nieve = self;p.en_tabla_nieve = true;p.visual.rotation.y = movimiento.rumbo
	_mostrar_tabla(p,true)
	_historia_visible = mundo.get_node("HUD").quest_tracker_panel.visible
	mundo.get_node("HUD").quest_tracker_panel.hide()
	_capa.show();set_physics_process(true);set_process(true)
	mundo.get_node("CameraRig").yaw = movimiento.rumbo
	p.action_feedback.emit("Las Campanas Blancas · A/D inclina · Mayús agáchate · S frena · Espacio salta · E abandona")

func mover_jugador(delta: float) -> void:
	var p = mundo.player
	if p.entrada_interfaz_bloqueada or p._descartar_input_interfaz:
		p._descartar_input_interfaz = false
		movimiento.avanzar(p,mundo.terrain,delta,Vector2(0,1),false,false)
		return
	var regreso := Input.is_physical_key_pressed(KEY_R)
	if regreso and not _regreso_sostenido and rivales.tiempo>=0:
		if NetworkSession.session_mode==NetworkSession.SessionMode.CLIENT:_pedir_regreso.rpc_id(1)
		else:_recuperar(1)
	_regreso_sostenido = regreso
	if Input.is_action_just_pressed("interact"):
		abandonar();return
	if rivales.tiempo<0:
		movimiento.rapidez = 0;movimiento.avanzar(p,mundo.terrain,delta,Vector2(0,1),false,false)
		return
	var en_aire: bool = movimiento.en_salto
	movimiento.avanzar(p,mundo.terrain,delta,Input.get_vector("move_left","move_right","move_forward","move_back"),Input.is_action_just_pressed("jump"),Input.is_action_pressed("sprint"))
	if en_aire and not movimiento.en_salto:mundo.get_node("CameraRig").add_shake(0.07+movimiento.compresion*0.06)
	p._play_animation("Idle",0.12)

func abandonar() -> void:
	_desmontar()
	if NetworkSession.session_mode==NetworkSession.SessionMode.CLIENT:_pedir_abandono.rpc_id(1)
	else:_quitar(1,true)

@rpc("any_peer","call_remote","reliable",6)
func _pedir_abandono() -> void:
	if NetworkSession.is_host():_quitar(multiplayer.get_remote_sender_id(),true)
func _quitar(peer: int, abandono: bool = false) -> void:
	carreras.erase(str(peer));_ultima_postura.erase(peer);_actualizar_visuales();NetworkSession.broadcast_world_state_now()
	if carreras.is_empty() and abandono:rivales.cancelar()
	if carreras.is_empty() and movimiento==null and not rivales.activa:
		rivales.descansar();set_physics_process(false)
func _desmontar(reponer_equipo: bool = true) -> void:
	if mundo.player.tabla_nieve!=self:return
	var p = mundo.player;p.tabla_nieve = null;p.en_tabla_nieve = false;p.postura_nieve = Vector3.ZERO;p.visual.rotation.x = 0;p.visual.rotation.z = 0;p.floor_snap_length = _snap_anterior;p.floor_max_angle = _angulo_suelo_anterior;p.velocity *= 0.35
	_mostrar_tabla(p,false)
	if reponer_equipo:
		if _slot_anterior>0:p.equip_item(_slot_anterior)
		else:p._clear_equipped_item()
	var hud = mundo.get_node_or_null("HUD")
	if hud!=null and is_instance_valid(hud.quest_tracker_panel):hud.quest_tracker_panel.visible = _historia_visible
	movimiento = null;_capa.hide();_efecto_velocidad.hide();_intensidad_velocidad = 0;set_process(false)

func _process(delta: float) -> void:
	if movimiento==null:return
	var p = mundo.player
	var objetivo := smoothstep(12.0,36.0,Vector2(p.velocity.x,p.velocity.z).length())
	_intensidad_velocidad = lerpf(_intensidad_velocidad,objetivo,1.0-exp(-5.0*delta))
	_capa.visible = not p.entrada_interfaz_bloqueada and not get_tree().paused
	_efecto_velocidad.visible = _intensidad_velocidad>0.005 and not p.entrada_interfaz_bloqueada and not get_tree().paused
	_material_velocidad.set_shader_parameter("intensidad",_intensidad_velocidad)

func _physics_process(delta: float) -> void:
	_reloj += delta
	if _reloj<0.1:return
	var paso := _reloj;_reloj = 0.0
	if movimiento!=null:
		if NetworkSession.session_mode==NetworkSession.SessionMode.CLIENT:_pedir_postura.rpc_id(1,mundo.player.postura_nieve)
		elif carreras.has("1"):carreras["1"]["postura"] = mundo.player.postura_nieve
	if NetworkSession.is_world_authority():
		var solo_pausado := get_tree().paused
		for clave in carreras:
			if int(clave)!=1:solo_pausado = false
		if not solo_pausado:
			if rivales.activa:rivales.avanzar(paso)
			elif not carreras.is_empty():rivales.tiempo += paso
		for clave in carreras.keys():
			var peer := int(clave)
			var actor = mundo.player if peer==1 else mundo.network_players.get_node_or_null("Peer_%d" % peer)
			if actor==null:_quitar(peer,true);continue
			if solo_pausado:continue
			var estado: Dictionary = carreras[clave];estado.tiempo = maxf(0,rivales.tiempo)
			if rivales.tiempo<0:continue
			var p: Vector3 = actor.get_network_authoritative_position() if actor.network_remote else actor.global_position
			if float(estado.get("rearme",0))>0:
				estado.rearme = float(estado.rearme)-paso;continue
			if not bool(estado.get("secreto",false)) and p.distance_to(cristal)<3.0:
				estado.secreto = true
				if peer==1:_encontrar_secreto()
				else:_encontrar_secreto.rpc_id(peer)
			var i: int = estado.puerta
			var anterior: Vector3 = estado.anterior
			var centro := puertas[i]
			var plano := Vector2(centro.x,centro.z)
			var segmento := Geometry2D.get_closest_point_to_segment(plano,Vector2(anterior.x,anterior.z),Vector2(p.x,p.z))
			var suficiente: bool = float(estado.tiempo)-float(estado.ultimo_paso) > puertas[i-1].distance_to(centro)/52.0
			if segmento.distance_to(plano)<9 and absf(p.y-centro.y)<22 and suficiente:
				estado.puerta += 1;estado.ultimo_paso = estado.tiempo
				if int(estado.puerta)>=puertas.size():_terminar(peer,actor,estado);continue
				estado.anterior = p;NetworkSession.broadcast_world_state_now()
			else:estado.anterior = p
			var h: float = mundo.terrain.data.get_height(p)
			if not p.is_finite() or p.y<h-4 or p.distance_to(puertas[maxi(int(estado.puerta)-1,0)])>110:
				_recuperar(peer)
	rivales.presentar()
	_actualizar_visuales()
	_actualizar_rotulo()
	if carreras.is_empty() and movimiento==null and not rivales.activa:
		rivales.descansar();set_physics_process(false)

@rpc("any_peer","call_remote","reliable",6)
func _pedir_regreso() -> void:
	if NetworkSession.is_host():_recuperar(multiplayer.get_remote_sender_id())

func _recuperar(peer: int) -> void:
	if not carreras.has(str(peer)):return
	var estado: Dictionary = carreras[str(peer)]
	if float(estado.get("rearme",0))>0:return
	estado.penalizacion += 5.0;estado.rearme = 0.8
	var regreso := puertas[maxi(int(estado.puerta)-1,0)]
	estado.anterior = regreso
	if peer==1:_volver(regreso,int(estado.puerta))
	else:_volver.rpc_id(peer,regreso,int(estado.puerta))
	NetworkSession.broadcast_world_state_now()

@rpc("authority","call_remote","reliable",6)
func _volver(punto: Vector3, siguiente: int = -1) -> void:
	mundo.player.global_position = punto;mundo.player.velocity = Vector3.ZERO
	if movimiento!=null:
		var id := str(multiplayer.get_unique_id()) if NetworkSession.is_networked() else "1"
		var i: int = int(carreras.get(id,{}).get("puerta",1)) if siguiente<0 else siguiente
		var t := puertas[mini(i,puertas.size()-1)]-punto;movimiento.rumbo = atan2(-t.x,-t.z);movimiento.rapidez = 5.0
	mundo.player.action_feedback.emit("Vuelves a la última bandera · cinco segundos de penalización")

@rpc("authority","call_remote","reliable",6)
func _encontrar_secreto() -> void:
	mundo.player.action_feedback.emit("¡Eco de escarcha encontrado! Cruza la meta para recuperar dos cristales más.")

func _terminar(peer: int, actor: Node, estado: Dictionary) -> void:
	var nombre: String = GameSettings.player_name if peer==1 else NetworkSession.get_identity(peer).get("name","Invitado")
	var tiempo: float = estado.tiempo+estado.penalizacion
	if not records.has(nombre) or tiempo<float(records[nombre]):records[nombre] = tiempo
	var resultado: Dictionary = rivales.resultado(float(estado.penalizacion))
	var ganado: bool = resultado.ganado
	if ganado and not premiados.has(nombre):
		premiados[nombre] = true;director._dar(actor,"Crystal3",3)
	if bool(estado.get("secreto",false)) and not secretos.has(nombre):
		secretos[nombre] = true;director._dar(actor,"Crystal3",2)
	var puesto: int = resultado.puesto
	if peer==1:_llegada(tiempo,ganado,puesto)
	else:_llegada.rpc_id(peer,tiempo,ganado,puesto)
	_quitar(peer)

@rpc("authority","call_remote","reliable",6)
func _llegada(tiempo: float, ganado: bool = true, puesto: int = 1) -> void:
	_desmontar()
	mundo.player.action_feedback.emit(("¡Reto superado! Llegas antes que los tres mensajeros" if ganado else "Esta vez ganan los mensajeros. Agáchate en las rectas y frena antes de las curvas")+" · %.1f s · puesto %d de 4" % [tiempo,puesto])


func _mostrar_tabla(p: Node3D, mostrar: bool) -> void:
	var id := p.get_instance_id()
	p.en_tabla_nieve = mostrar
	if mostrar and not _visuales.has(id):
		var v = preload("res://scripts/visual_tabla_nieve.gd").new();p.visual.add_child(v);v.iniciar(p);_visuales[id] = v
	elif not mostrar and _visuales.has(id):
		var v = _visuales[id];_visuales.erase(id)
		if is_instance_valid(v):v.retirar()
@rpc("any_peer","call_remote","unreliable_ordered",6)
func _pedir_postura(postura: Vector3) -> void:
	if not NetworkSession.is_host():return
	var peer := multiplayer.get_remote_sender_id()
	if not carreras.has(str(peer)) or not postura.is_finite():return
	if postura.x<0 or postura.x>1 or absf(postura.y)>0.7 or absf(postura.z)>0.8:return
	var ahora := Time.get_ticks_msec()
	if ahora-int(_ultima_postura.get(peer,0))<65:return
	_ultima_postura[peer] = ahora;carreras[str(peer)]["postura"] = postura

func _actualizar_visuales() -> void:
	for id in _visuales.keys():
		if not is_instance_valid(_visuales[id]):_visuales.erase(id)
	for p in mundo.network_players.get_children():
		var peer: int = p.get_meta("network_peer_id",0);_mostrar_tabla(p,carreras.has(str(peer)))
		if p.en_tabla_nieve:p.postura_nieve = carreras[str(peer)].get("postura",Vector3.ZERO)
	if not carreras.is_empty() or movimiento!=null:set_physics_process(true)
func _actualizar_rotulo() -> void:
	if movimiento==null:return
	var id := str(multiplayer.get_unique_id()) if NetworkSession.is_networked() else "1"
	var e: Dictionary = carreras.get(id,{})
	var tiempo: float = float(e.get("tiempo",0))+float(e.get("penalizacion",0))
	var puerta := mini(int(e.get("puerta",1)),puertas.size()-1)
	var tramo := "LA CORNISA" if puerta<24 else ("BOSQUE DE ESCARCHA" if puerta<54 else ("LA GARGANTA" if puerta<67 else "EL CLARO DEL VIENTO"))
	var progreso: float = rivales.progreso_humano(puerta,mundo.player.global_position)
	var puesto: int = rivales.puesto(progreso)
	_titulo.text = "SALIDA EN %d" % ceili(-rivales.tiempo) if rivales.tiempo<0 else ("LAS CAMPANAS BLANCAS · "+tramo+" · %d.º / 4" % puesto)
	_etiqueta.text = "%d:%04.1f  ·  %.0f km/h  ·  Puerta %d / %d" % [int(tiempo/60),fmod(tiempo,60.0),Vector2(mundo.player.velocity.x,mundo.player.velocity.z).length()*3.6,puerta,puertas.size()-1]

func preparar_jugador_guardado(estado: Dictionary) -> void:
	for clave in carreras:
		var peer := int(clave)
		var nombre: String = GameSettings.player_name if peer==1 else NetworkSession.get_identity(peer).get("name","")
		if nombre==str(estado.get("name","")):
			# Guardar no interrumpe el descenso en curso. Al cargar se vuelve a
			# la salida a pie: nunca a mitad de un salto ni sobre una pared.
			estado["position"] = [puertas[0].x,puertas[0].y,puertas[0].z]
			estado["equipped_slot"] = carreras[clave].get("ranura",1)
func guardar() -> Dictionary:
	var copia := carreras.duplicate(true)
	for estado in copia.values():
		for campo in ["anterior","postura"]:
			if estado.get(campo) is Vector3:
				var v: Vector3 = estado[campo];estado[campo] = [v.x,v.y,v.z]
	return {"records":records.duplicate(),"premiados":premiados.duplicate(),"secretos":secretos.duplicate(),"carreras":copia,"rivales":rivales.guardar()}
func cargar(datos: Dictionary) -> void:
	if NetworkSession.is_world_authority() and not carreras.is_empty():
		for clave in carreras.keys():
			if int(clave)==1:_cancelar_carga()
			elif NetworkSession.is_networked():_cancelar_carga.rpc_id(int(clave))
		carreras.clear();rivales.cancelar();set_physics_process(false)
	records = datos.get("records",{}).duplicate();premiados = datos.get("premiados",{}).duplicate();secretos = datos.get("secretos",{}).duplicate()
	if NetworkSession.is_world_authority():rivales.cancelar()
	if not NetworkSession.is_world_authority():
		rivales.cargar(datos.get("rivales",{}))
		carreras = datos.get("carreras",{}).duplicate(true)
		for estado in carreras.values():
			for campo in ["anterior","postura"]:
				var v = estado.get(campo)
				if v is Array and v.size()==3:estado[campo] = Vector3(float(v[0]),float(v[1]),float(v[2]))
		_actualizar_visuales();set_physics_process(not carreras.is_empty() or movimiento!=null or rivales.activa)
@rpc("authority","call_remote","reliable",6)
func _cancelar_carga() -> void:
	_desmontar();mundo._travel_player_to_point(RUTA[0])
	mundo.player.action_feedback.emit("Partida cargada · el descenso vuelve a la salida")
func _cerrar_sesion() -> void:
	_peticion_pendiente = false;_desmontar();_ultima_postura.clear();carreras.clear();rivales.cancelar();_actualizar_visuales();set_physics_process(false)
func _exit_tree() -> void:
	if is_instance_valid(mundo) and is_instance_valid(mundo.player):_desmontar(false)
	for id in _visuales:
		if is_instance_valid(_visuales[id]):_visuales[id].retirar()
