extends Node

## Las llaves pertenecen al inventario de cada jugador; el acceso abierto
## pertenece al mundo del anfitrión. No se añade actividad por fotograma.
var mundo: Node3D
var jugador: Player
var replicas: Node3D
var sesion: Node
var _revision := Time.get_ticks_usec()
var _revision_host := -1
var _peticiones: Dictionary = {}
var _ultima_peticion: Dictionary = {}

func configurar(nivel: Node3D, heroe: Player, invitados: Node3D) -> void:
	mundo = nivel
	jugador = heroe
	replicas = invitados

func _ready() -> void:
	add_to_group("puertas_cooperativas")
	sesion = get_node("/root/NetworkSession")
	sesion.session_started.connect(func(_modo): _limpiar())
	sesion.session_ended.connect(_limpiar)
	sesion.roster_changed.connect(func(roster):
		for peer in _ultima_peticion.keys():
			if not roster.has(peer): _ultima_peticion.erase(peer))

func _limpiar() -> void:
	_revision_host = -1
	_peticiones.clear()
	_ultima_peticion.clear()

func get_state() -> Dictionary:
	var puertas: Array[Dictionary] = []
	for nodo in get_tree().get_nodes_in_group("rpg_cave_gate"):
		if mundo.is_ancestor_of(nodo): puertas.append(nodo.get_save_state())
	return {"revision":_revision, "doors":puertas}

func aplicar_estado_red(estado: Dictionary) -> void:
	if not sesion.is_networked() or sesion.is_host(): return
	if typeof(estado.get("revision")) != TYPE_INT or not estado.get("doors") is Array: return
	if int(estado.revision) < _revision_host: return
	var restauracion := int(estado.revision) != _revision_host
	_revision_host = int(estado.revision)
	for datos in estado.doors:
		if not datos is Dictionary: continue
		var puerta := _buscar(String(datos.get("id", "")))
		# La confirmación fiable y las instantáneas viajan por canales distintos.
		# Dentro de la misma partida una puerta abierta no vuelve a sellarse.
		if puerta != null and (restauracion or not puerta.opened): puerta.apply_network_state(datos)

func partida_cargada() -> void:
	if not sesion.is_world_authority(): return
	# Un paquete de apertura anterior a una carga no puede reabrir la partida nueva.
	_revision += 1
	_peticiones.clear()

func puerta_abierta(puerta: RPGCaveGate) -> void:
	if not sesion.is_world_authority(): return
	if sesion.is_host():
		for identificador in sesion.players:
			var peer := int(identificador)
			if peer > 1 and sesion._is_peer_ready(peer):
				_confirmar.rpc_id(peer, puerta.gate_id, _revision, true, puerta.get_save_state())
	sesion.broadcast_world_state_now()
	var guardado := get_node_or_null("/root/SaveGameManager")
	if guardado != null and guardado.is_processing(): guardado.save_current_game("puerta de gruta abierta")

func solicitar(puerta: RPGCaveGate, actor: Player) -> bool:
	if sesion.session_mode != sesion.SessionMode.CLIENT or actor != jugador: return false
	if _revision_host < 0:
		puerta._feedback(actor, "El anfitrión todavía no comparte las puertas de esta expedición.")
		return true
	var ahora := Time.get_ticks_msec()
	if ahora - int(_peticiones.get(puerta.gate_id, -2000)) < 1000: return true
	_peticiones[puerta.gate_id] = ahora
	_pedir_apertura.rpc_id(1, puerta.gate_id, _revision_host, sesion._local_save_snapshot(jugador))
	return true

func _buscar(id: String) -> RPGCaveGate:
	for nodo in get_tree().get_nodes_in_group("rpg_cave_gate"):
		if mundo.is_ancestor_of(nodo) and nodo.gate_id == id: return nodo as RPGCaveGate
	return null

func paquete_valido(id: String, estado: Dictionary) -> bool:
	if id.is_empty() or id.length() > 64 or "\n" in id: return false
	var posicion: Variant = estado.get("position")
	if not posicion is Array or posicion.size() != 3: return false
	for numero in posicion:
		if typeof(numero) not in [TYPE_INT, TYPE_FLOAT]: return false
	if typeof(estado.get("yaw", 0.0)) not in [TYPE_INT, TYPE_FLOAT]: return false
	if not sesion._is_valid_save_snapshot(estado): return false
	return var_to_bytes(estado).size() <= 65536

func autorizar(peer: int, id: String, revision: int, estado: Dictionary) -> bool:
	if not sesion.is_host() or not multiplayer.is_server() or revision != _revision or not sesion._is_peer_ready(peer): return false
	if not paquete_valido(id, estado): return false
	var replica := replicas.get_node_or_null("Peer_%d" % peer) as Player
	if replica == null or not bool(replica.get("_network_state_ready")): return false
	var puerta := _buscar(id)
	if puerta == null: return false
	var punto := Vector3(float(estado.position[0]), float(estado.position[1]), float(estado.position[2]))
	# La intención lleva la posición y el inventario actuales del propietario,
	# como el guardado cooperativo; no se usa el inventario del anfitrión.
	if punto.distance_squared_to(puerta.global_position) > 4.5 * 4.5: return false
	var inventario: Dictionary = estado.get("inventory", {})
	var objetos: Dictionary = inventario.get("items", {})
	var cantidad: Variant = objetos.get(puerta.key_item_id, 0)
	if not puerta.opened and (typeof(cantidad) != TYPE_INT or int(cantidad) <= 0): return false
	if not sesion.registrar_instantanea(peer, estado): return false
	puerta.open_gate(replica)
	return true

@rpc("any_peer", "call_remote", "reliable", 3)
func _pedir_apertura(id: String, revision: int, estado: Dictionary) -> void:
	if not sesion.is_host() or not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	if peer <= 1 or not sesion.players.has(peer) or not sesion._is_peer_ready(peer): return
	var ahora := Time.get_ticks_msec()
	if ahora - int(_ultima_peticion.get(peer, -1000)) < 250: return
	_ultima_peticion[peer] = ahora
	var aceptada := autorizar(peer, id, revision, estado)
	var puerta := _buscar(id)
	_confirmar.rpc_id(peer, id, _revision, aceptada, puerta.get_save_state() if puerta != null else {})

@rpc("authority", "call_remote", "reliable", 3)
func _confirmar(id: String, revision: int, aceptada: bool, estado: Dictionary) -> void:
	if sesion.session_mode != sesion.SessionMode.CLIENT or revision != _revision_host: return
	_peticiones.erase(id)
	var puerta := _buscar(id)
	if puerta == null: return
	if aceptada: puerta.apply_network_state(estado)
	else: puerta._feedback(jugador, "El acceso sigue sellado. Acércate y comprueba la llave.")
