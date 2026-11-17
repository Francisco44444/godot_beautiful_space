extends Node3D

## Interacciones por eventos: los puzles, arquetas y refugios no procesan frames.
const Catalogo = preload("res://scripts/catalogo_aventura.gd")
var historia: Node
var mundo: Node3D
var hechos := {}
var pasos := {}
var refugios: Array = []
var retorno: Array = []
var objetos := {}
var _refugio_pendiente := false
var _ultima_construccion := {}

func iniciar(runtime: Node) -> void:
	historia = runtime
	mundo = runtime.get_parent()
	name = "AventuraPacifica"
	NetworkSession.session_ended.connect(_cancelar_construccion)
	for i in historia.campaign.actos().size():
		var acto: Dictionary = historia.campaign.actos()[i]
		var centro: Vector2 = RPGCampaign.where_of(acto)
		for j in 3:
			var punto := centro + Vector2((j-1)*3.8, 0)
			_crear("acto:%d:%d" % [i,j], Catalogo.SIMBOLOS[i][j], punto, Color(0.45,0.51,0.40), true)
		_visual_puzle(i)
		_rotulo(centro + Vector2(0,5), "%s\n%s" % [acto.title, Catalogo.PISTAS[i]])
	for i in historia.sidequests.encargos().size():
		var q: Dictionary = historia.sidequests.encargos()[i]
		var origen := Vector2(-247,40)
		for npc in historia.NPC_SPECS:
			if npc.id == q.giver: origen = npc.point
		var centro: Vector2 = q.get("at", origen)
		if centro == Vector2.ZERO: centro = Vector2(500,300)
		var punto := centro + Vector2(cos(i*2.4),sin(i*2.4))*68.0
		_crear("encargo:%d" % i, "Arqueta · " + q.title, punto, Color(0.52,0.29,0.12), false)
		q["at"] = punto
		q.where = "Busca la arqueta de «%s» en las afueras de la comarca; la cartografía del encargo señala el lugar." % q.title
	# Una cadena de llaves independiente de las entregas impide perder un acceso
	# por consumir una llave en un encargo. Están antes de sus puertas.
	for i in historia.GATE_SPECS.size():
		var spec: Dictionary = historia.GATE_SPECS[i]
		var punto: Vector2 = spec.point + Vector2(7,9)
		_crear("llave:%d" % i, "Examinar el escondrijo de la llave", punto, Color(0.65,0.48,0.17), false)

	var retos = preload("res://scripts/retos_senderos.gd").new()
	add_child(retos); retos.iniciar(self)

func _crear(id: String, titulo: String, punto: Vector2, color: Color, piedra: bool) -> void:
	var nodo = preload("res://scripts/objeto_aventura.gd").new()
	nodo.director = self; nodo.identificador = id; nodo.titulo = titulo
	add_child(nodo); nodo.position = historia._grounded_position(punto,0.0)
	var m := MeshInstance3D.new()
	var forma := CylinderMesh.new(); forma.top_radius = 0.55; forma.bottom_radius = 0.8; forma.height = 1.2; forma.radial_segments = 7
	if not piedra: forma.height = 0.65
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.9
	forma.material = material; m.mesh = forma; m.position.y = forma.height/2.0; nodo.add_child(m)
	objetos[id] = nodo
	preload("res://scripts/arte_aventura.gd").decorar(nodo,id)
	_rotulo(punto,titulo)

func _rotulo(punto: Vector2, texto: String) -> void:
	var etiqueta := Label3D.new(); etiqueta.text = texto; etiqueta.font_size = 28; etiqueta.outline_size = 5
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED; etiqueta.visibility_range_end = 24
	add_child(etiqueta); etiqueta.position = historia._grounded_position(punto,2.1)

func interactuar(id: String, actor: Node) -> bool:
	if not objetos.has(id): return false
	if NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		_pedir.rpc_id(1,id,NetworkSession._local_save_snapshot(mundo.player))
		return true
	return _resolver(id,actor)

@rpc("any_peer","call_remote","reliable",5)
func _pedir(id: String, estado: Dictionary) -> void:
	if not NetworkSession.is_host(): return
	var peer := multiplayer.get_remote_sender_id()
	var actor: Node = mundo.network_players.get_node_or_null("Peer_%d" % peer)
	if actor != null and NetworkSession._is_valid_save_snapshot(estado):
		NetworkSession.registrar_instantanea(peer,estado)
		_resolver(id,actor)

func _resolver(id: String, actor: Node) -> bool:
	if not objetos.has(id) or actor == null: return false
	var punto: Vector3 = actor.get_network_authoritative_position() if actor.network_remote else actor.global_position
	if punto.distance_to(objetos[id].global_position)>4.5: return false
	var partes := id.split(":")
	var i := int(partes[1])
	if partes[0] == "lava":
		if not hechos.has(id):
			hechos[id] = true; _dar(actor,"Crystal5",5)
			actor.action_feedback.emit("Paso de la Caldera superado")
	elif partes[0] == "refugio":
		if actor.network_remote:
			_descanso.rpc_id(int(String(actor.name).trim_prefix("Peer_")),objetos[id].global_position)
		else: _descanso(objetos[id].global_position)
	elif partes[0] == "acto":
		var acto: Dictionary = historia.campaign.actos()[i]
		if not historia.campaign.is_open(acto):
			actor.action_feedback.emit("Este recuerdo todavía está sellado o ya ha sido recuperado.")
			return true
		if accionar_piedra(i,int(partes[2])):
			historia.campaign.on_boss_defeated(acto.boss,historia._inventory)
			for identificador in NetworkSession.players:
				var peer := int(identificador)
				if peer>1 and NetworkSession._is_peer_ready(peer):
					var viajero = mundo.network_players.get_node_or_null("Peer_%d" % peer)
					if viajero != null:
						for item in acto.reward: _dar(viajero,item,int(acto.reward[item]))
						_recibir_acto.rpc_id(peer,i)
			actor.action_feedback.emit("El mecanismo recuerda su nombre.")
		else: actor.action_feedback.emit("El mecanismo responde. Observa las piedras y la inscripción.")
	elif partes[0] == "encargo":
		var propietario := "local"
		if actor.network_remote:
			propietario = str(NetworkSession.get_identity(int(String(actor.name).trim_prefix("Peer_"))).get("name","invitado"))
		else: propietario = GameSettings.player_name
		var recibo := id + "|" + propietario
		if hechos.has(recibo): return true
		hechos[recibo] = true
		var q: Dictionary = historia.sidequests.encargos()[i]
		# Cada viajero recoge su entrega una sola vez, también al reconectar.
		_dar(actor,q.target,int(q.needed)+3)
		actor.action_feedback.emit("Arqueta recuperada · entrega los objetos a %s" % q.giver.capitalize())
	elif partes[0] == "llave":
		var propietario := "local"
		if actor.network_remote:
			propietario = str(NetworkSession.get_identity(int(String(actor.name).trim_prefix("Peer_"))).get("name","invitado"))
		else: propietario = GameSettings.player_name
		var recibo := id + "|" + propietario
		if hechos.has(recibo): return true
		hechos[recibo] = true
		var spec: Dictionary = historia.GATE_SPECS[i]
		_dar(actor,spec.key,3)
		actor.action_feedback.emit("Llave del acceso recuperada")
	NetworkSession.broadcast_world_state_now()
	return true

func construir_refugio() -> bool:
	var inventario: Node = historia._inventory
	if inventario.get_count("WoodLog") < 6 or _refugio_pendiente:
		mundo.player.action_feedback.emit("Necesitas seis troncos para construir un refugio.")
		return false
	if NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		_refugio_pendiente = true
		_pedir_refugio.rpc_id(1,NetworkSession._local_save_snapshot(mundo.player))
		return true
	var punto := _ubicacion_refugio(mundo.player,mundo.player.global_position)
	if not punto.is_finite():
		mundo.player.action_feedback.emit("Busca terreno seco, llano y despejado para el refugio.")
		return false
	inventario.remove_item("WoodLog",6,false)
	_levantar_refugio(punto)
	return true

func _ubicacion_refugio(actor: Node3D, origen: Vector3) -> Vector3:
	var punto := origen + Vector3(4,0,0)
	var h: float = mundo.terrain.data.get_height(punto)
	if not is_finite(h) or h < 4.0: return Vector3.INF
	for esquina in [Vector3(-2,0,-2),Vector3(2,0,-2),Vector3(-2,0,2),Vector3(2,0,2)]:
		var cota: float = mundo.terrain.data.get_height(punto+esquina)
		if not is_finite(cota) or absf(cota-h)>0.65: return Vector3.INF
	var consulta := PhysicsShapeQueryParameters3D.new()
	var volumen := BoxShape3D.new(); volumen.size = Vector3(4.0,2.8,3.5)
	consulta.shape = volumen; consulta.transform = Transform3D(Basis.IDENTITY,Vector3(punto.x,h+1.6,punto.z)); consulta.collision_mask = 1
	consulta.exclude = [actor.get_rid(),mundo.horse.get_rid()]
	if not mundo.get_world_3d().direct_space_state.intersect_shape(consulta,1).is_empty(): return Vector3.INF
	punto.y = h
	for p in refugios:
		if punto.distance_to(Vector3(p[0],p[1],p[2])) < 8: return Vector3.INF
	return punto

func _levantar_refugio(punto: Vector3) -> void:
	refugios.append([punto.x,punto.y,punto.z]); _dibujar_refugio(punto)
	NetworkSession.broadcast_world_state_now()

@rpc("any_peer","call_remote","reliable",5)
func _pedir_refugio(estado: Dictionary) -> void:
	if not NetworkSession.is_host(): return
	var peer := multiplayer.get_remote_sender_id()
	var actor: Node3D = mundo.network_players.get_node_or_null("Peer_%d" % peer)
	var aceptado := false
	if actor != null and NetworkSession._is_peer_ready(peer) and NetworkSession._is_valid_save_snapshot(estado):
		var troncos = estado.inventory.get("items",{}).get("WoodLog",0)
		var origen := Vector3(float(estado.position[0]),float(estado.position[1]),float(estado.position[2]))
		var ahora := Time.get_ticks_msec()
		if typeof(troncos)==TYPE_INT and troncos>=6 and ahora-int(_ultima_construccion.get(peer,-2000))>1000 and origen.distance_to(actor.get_network_authoritative_position())<4.5:
			var punto := _ubicacion_refugio(actor,origen)
			if punto.is_finite():
				_ultima_construccion[peer] = ahora
				estado.inventory.items.WoodLog = troncos-6
				NetworkSession.registrar_instantanea(peer,estado)
				_levantar_refugio(punto)
				aceptado = true
	_confirmar_refugio.rpc_id(peer,aceptado)

@rpc("authority","call_remote","reliable",5)
func _confirmar_refugio(aceptado: bool) -> void:
	if not _refugio_pendiente: return
	_refugio_pendiente = false
	if aceptado:
		historia._inventory.remove_item("WoodLog",6,false)
		_confirmar_inventario.rpc_id(1,NetworkSession._local_save_snapshot(mundo.player))
	mundo.player.action_feedback.emit("Refugio construido. Acércate para descansar." if aceptado else "Busca terreno seco, llano y despejado para el refugio.")

func _cancelar_construccion() -> void:
	_refugio_pendiente = false

func _dibujar_refugio(punto: Vector3, indice: int = -1) -> void:
	var casa = preload("res://scripts/objeto_aventura.gd").new(); casa.director = self; casa.identificador = "refugio:%d" % (refugios.size()-1 if indice < 0 else indice); casa.titulo = "Descansar en el refugio"; objetos[casa.identificador] = casa; casa.name = "Refugio"; add_child(casa); casa.position = punto
	for x in [-1.7,1.7]:
		for z in [-1.3,1.3]:
			var m := MeshInstance3D.new(); var palo := CylinderMesh.new(); palo.top_radius = 0.1; palo.bottom_radius = 0.14; palo.height = 2.5; palo.radial_segments = 6; palo.material = preload("res://scripts/arte_aventura.gd").material(Color("63472f"))
			m.mesh = palo; m.position = Vector3(x,1.25,z); casa.add_child(m)
	for lado in [-1.0,1.0]:
		var m := MeshInstance3D.new(); var techo := BoxMesh.new(); techo.size = Vector3(2.1,0.16,3.3)
		var material := StandardMaterial3D.new(); material.albedo_color = Color(0.37,0.20,0.10); techo.material = material
		m.mesh = techo; m.position = Vector3(lado*0.85,2.8,0); m.rotation.z = lado*-0.42; casa.add_child(m)

func guardar() -> Dictionary:
	return {"hechos":hechos.duplicate(),"pasos":pasos.duplicate(),"refugios":refugios.duplicate(true),"retorno":retorno.duplicate()}
func cargar(datos: Dictionary) -> void:
	if datos.has("retorno"): retorno = datos.retorno.duplicate()
	hechos = datos.get("hechos",{}).duplicate()
	var nuevos_pasos: Dictionary = datos.get("pasos",{})
	if pasos != nuevos_pasos:
		pasos = nuevos_pasos.duplicate(true)
		for i in 5: _visual_puzle(i)
	var nuevos: Array = datos.get("refugios",[])
	if nuevos != refugios:
		for n in get_children():
			if n.name.begins_with("Refugio"): remove_child(n); n.queue_free()
		refugios = nuevos.duplicate(true)
		for id in objetos.keys():
			if String(id).begins_with("refugio:"): objetos.erase(id)
		for i in refugios.size():
			var p: Array = refugios[i]
			_dibujar_refugio(Vector3(p[0],p[1],p[2]),i)

func _dar(actor: Node, item: String, cantidad: int) -> void:
	if actor.network_remote:
		var peer := int(String(actor.name).trim_prefix("Peer_"))
		var nombre := String(NetworkSession.get_identity(peer).get("name",""))
		var estado: Dictionary = NetworkSession.get_party_save_states().get(nombre,{})
		if not estado.is_empty():
			var inventario: Dictionary = estado.inventory.items
			inventario[item] = int(inventario.get(item,0))+cantidad
			NetworkSession.registrar_instantanea(peer,estado)
		_recibir_objetos.rpc_id(peer,item,cantidad)
	else: historia._inventory.add_item(item,cantidad,false)

@rpc("authority","call_remote","reliable",5)
func _recibir_acto(indice: int) -> void:
	if NetworkSession.session_mode != NetworkSession.SessionMode.CLIENT or indice<0 or indice>=5: return
	var acto: Dictionary = historia.campaign.actos()[indice]
	historia.grow_hero(historia.ACT_HEALTH_BONUS,historia.ACT_STAMINA_BONUS,"Recuerdo compartido · "+acto.relic)
	if indice==4: historia._show_epilogue()

@rpc("authority","call_remote","reliable",5)
func _recibir_objetos(item: String, cantidad: int) -> void:
	if NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		historia._inventory.add_item(item,cantidad,false)
		_confirmar_inventario.rpc_id(1,NetworkSession._local_save_snapshot(mundo.player))

@rpc("any_peer","call_remote","reliable",5)
func _confirmar_inventario(estado: Dictionary) -> void:
	if NetworkSession.is_host(): NetworkSession.registrar_instantanea(multiplayer.get_remote_sender_id(),estado)

func accionar_piedra(acto: int, pieza: int) -> bool:
	if acto < 0 or acto > 4 or pieza < 0 or pieza > 2: return false
	var id := str(acto)
	var completo := false
	if acto == 1:
		var mascara := int(pasos.get(id,0)) ^ (1 << pieza)
		pasos[id] = mascara
		var peso := 0
		for j in 3:
			if mascara & (1 << j): peso += j+1
		completo = peso == 4
	elif acto == 2:
		var giros: Array = pasos.get(id,[0,0,0]).duplicate()
		giros[pieza] = (int(giros[pieza])+1)%4
		pasos[id] = giros
		completo = giros == [2,1,3]
	elif acto == 3:
		pasos[id] = int(pasos.get(id,0)) ^ [3,6,4][pieza]
		completo = int(pasos[id]) == 7
	else:
		var orden: Array = [2,0,1] if acto == 4 else [0,1,2]
		var siguiente := int(pasos.get(id,0))
		pasos[id] = siguiente+1 if siguiente < 3 and pieza == orden[siguiente] else 0
		completo = pasos[id] == 3
	_visual_puzle(acto)
	return completo

func _visual_puzle(acto: int) -> void:
	for j in 3:
		var nodo: Node3D = objetos["acto:%d:%d" % [acto,j]]
		var malla := nodo.get_child(0) as MeshInstance3D
		if acto == 1:
			malla.position.y = 0.85 if int(pasos.get(str(acto),0)) & (1 << j) else 0.6
		elif acto == 2:
			nodo.get_node("Espejo").rotation.y = float(pasos.get(str(acto),[0,0,0])[j])*PI/2
		if acto == 3:
			nodo.get_node("Agua").visible = bool(int(pasos.get(str(acto),0)) & (1 << j))
		var material := malla.mesh.material as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color(0.12,0.25,0.05) if acto != 3 else (Color(0.05,0.35,0.55) if int(pasos.get(str(acto),0)) & (1 << j) else Color.BLACK)

@rpc("authority","call_remote","reliable",5)
func _descanso(punto: Vector3) -> void:
	retorno = [punto.x,punto.y,punto.z]
	mundo.player.spawn_position = punto
	mundo.player.stamina = mundo.player.stamina_max
	historia.heal_player(999,"Descanso en el refugio")
	mundo.player.action_feedback.emit("Has descansado. El refugio será tu punto de regreso.")
	if NetworkSession.session_mode == NetworkSession.SessionMode.CLIENT:
		_confirmar_inventario.rpc_id(1,NetworkSession._local_save_snapshot(mundo.player))
