extends Node

## Las intenciones viajan de forma fiable; el anfitrión ejecuta las mismas
## ventanas de golpe y barridos de flecha que el juego individual.
var mundo: Node
var heroe: Player
var replicas: Node3D
var historia: Node
var _secuencias: Dictionary = {}
var _cargas: Dictionary = {}
var _proximo_ataque: Dictionary = {}
var _sesion: Node

func configurar(nivel: Node, jugador: Player, jugadores: Node3D, guion: Node) -> void:
	mundo = nivel
	heroe = jugador
	replicas = jugadores
	historia = guion

func _ready() -> void:
	_sesion = get_node("/root/NetworkSession")
	_sesion.gestor_combate = Callable(self,"autorizar")
	_sesion.accion_combate_recibida.connect(_representar)
	_sesion.dano_combate_recibido.connect(_recibir_dano)
	_sesion.roster_changed.connect(_depurar_participantes)
	_sesion.session_ended.connect(_limpiar)
	_sesion.session_started.connect(_al_comenzar)

func _exit_tree() -> void:
	if is_instance_valid(_sesion) and _sesion.gestor_combate==Callable(self,"autorizar"):
		_sesion.gestor_combate = Callable()

func _depurar_participantes(lista: Dictionary) -> void:
	for mapa in [_secuencias,_cargas,_proximo_ataque]:
		for peer in mapa.keys():
			if not lista.has(peer): mapa.erase(peer)

func _al_comenzar(_modo: String) -> void:
	_limpiar()

func _limpiar() -> void:
	_secuencias.clear()
	_cargas.clear()
	_proximo_ataque.clear()

func autorizar(peer: int, accion: Dictionary) -> bool:
	if not _sesion.is_host() or not _sesion.players.has(peer) or not _sesion.paquete_combate_valido(accion): return false
	var secuencia := int(accion.secuencia)
	if secuencia<=int(_secuencias.get(peer,0)): return false
	# Una intención rechazada tampoco puede reaparecer cuando termine el cooldown.
	_secuencias[peer] = secuencia
	var actor := replicas.get_node_or_null("Peer_%d"%peer) as Player
	if actor==null: return false
	var tipo := String(accion.tipo)
	if not _equipo_valido(accion): return false
	if tipo in ["tajo","carga","giro","flecha","tensar"]:
		if float(accion.hora)<float(_proximo_ataque.get(peer,-1.0))-0.02: return false
	if tipo=="giro":
		var carga: Dictionary = _cargas.get(peer,{})
		if carga.is_empty() or float(accion.hora)-float(carga.hora)<actor.charge_full_time*0.95: return false
		if int(carga.ranura)!=int(accion.ranura) or String(carga.objeto)!=String(accion.objeto): return false
		_cargas.erase(peer)
	if tipo in ["flecha","tensar"]:
		if not accion.get("direccion") is Vector3 or not (accion.direccion as Vector3).is_finite() or absf((accion.direccion as Vector3).length()-1.0)>0.01: return false
	if tipo=="flecha":
		if not accion.get("origen") is Vector3 or not accion.get("direccion") is Vector3: return false
		var origen: Vector3 = accion.origen
		var direccion: Vector3 = accion.direccion
		if typeof(accion.get("fuerza")) not in [TYPE_FLOAT,TYPE_INT]: return false
		var fuerza := float(accion.fuerza)
		if not origen.is_finite() or not direccion.is_finite() or not is_finite(fuerza): return false
		if fuerza<actor.bow_min_release_strength or fuerza>1.0 or absf(direccion.length()-1.0)>0.01: return false
		if origen.distance_to((accion.posicion as Vector3)+Vector3.UP*1.45)>3.0: return false
	if tipo in ["tajo","carga","giro","flecha","tensar"]:
		# Una animación remota puede ir un paso detrás del reloj que la originó.
		if actor.is_attacking: actor._finish_attack()
		actor.set("_attack_cooldown",0.0)
	_sesion.remote_state_received.emit(peer,accion.posicion,accion.yaw,accion.velocidad,actor.equipped_slot,accion.hora,accion.suelo)
	if not _aplicar(actor,accion): return false
	if tipo=="tajo": _proximo_ataque[peer] = float(accion.hora)+float(actor.get("_slash_duration"))+actor.attack_recovery
	elif tipo=="giro": _proximo_ataque[peer] = float(accion.hora)+actor.spin_duration+actor.attack_recovery
	elif tipo=="flecha": _proximo_ataque[peer] = float(accion.hora)+0.20
	if tipo=="carga": _cargas[peer] = accion.duplicate()
	elif tipo in ["tajo","equipo","guardia","esquiva","reposo","flecha"]: _cargas.erase(peer)
	return true

func _equipo_valido(accion: Dictionary) -> bool:
	var ranura := int(accion.ranura)
	var tipo := String(accion.tipo)
	if tipo in ["flecha","tensar"] and ranura!=3: return false
	if tipo in ["tajo","carga","giro"] and ranura not in [0,1,2]: return false
	if tipo in ["carga","giro"] and ranura==0: return false
	if ranura==0: return String(accion.objeto).is_empty()
	var catalogo := get_node("/root/InventoryManager")
	var pieza: Dictionary = catalogo.get_item_definition(String(accion.objeto))
	return not pieza.is_empty() and String(pieza.get("category",""))==String(Player.EQUIPMENT_SPECS[ranura].category)

func _representar(peer: int, accion: Dictionary) -> void:
	if peer==multiplayer.get_unique_id(): return
	var actor := replicas.get_node_or_null("Peer_%d"%peer) as Player
	if actor==null and mundo.has_method("_on_remote_state_received"):
		mundo._on_remote_state_received(peer,accion.posicion,accion.yaw,accion.velocidad,0,accion.hora,accion.suelo)
		actor = replicas.get_node_or_null("Peer_%d"%peer) as Player
	if actor!=null:
		actor.apply_network_state(accion.posicion,accion.yaw,accion.velocidad,actor.equipped_slot,accion.hora,accion.suelo)
		_aplicar(actor,accion)

func _aplicar(actor: Player, accion: Dictionary) -> bool:
	var ranura := int(accion.ranura)
	var objeto := String(accion.objeto)
	if actor.equipped_slot!=ranura or actor.equipped_item_id!=objeto:
		if ranura==0: actor._clear_equipped_item()
		elif not actor.equip_item(ranura,objeto): return false
	match String(accion.tipo):
		"equipo": return true
		"tajo":
			actor._start_slash()
		"carga":
			# El vigor y el inventario siguen perteneciendo a cada jugador.
			actor.stamina = maxf(actor.stamina,actor.min_charge_stamina)
			return actor.start_charge()
		"giro":
			actor.set("_charge_strength",1.0)
			return actor.start_spin_attack()
		"guardia":
			if bool(accion.get("activo",false)): actor._raise_shield()
			else: actor._lower_shield()
		"esquiva":
			actor._cancel_melee_charge()
			actor.is_rolling = true
			actor.set("_roll_time",0.0)
			actor.set("_roll_duration",actor.animation_player.get_animation(Player.ANIM_ROLL).length if actor.animation_player.has_animation(Player.ANIM_ROLL) else 0.7)
			var direccion: Vector3 = accion.get("direccion",Vector3.FORWARD)
			actor.visual.rotation.y = atan2(-direccion.x,-direccion.z)
			actor._play_animation(Player.ANIM_ROLL,0.05)
		"reposo":
			actor._cancel_bow_draw()
			actor._cancel_melee_charge()
		"tensar":
			actor.is_drawing_bow = true
			actor.set("_bow_draw_time",0.0)
			actor.set("_bow_draw_strength",0.0)
			actor.set("_last_arrow_direction",accion.direccion)
			actor._create_nocked_arrow()
		"flecha":
			var flecha = actor.get("_nocked_arrow") as AdventureArrow
			actor.set("_nocked_arrow",null)
			actor._cancel_bow_draw()
			if flecha==null: flecha = AdventureArrow.new()
			flecha.name = "FlechaCooperativa"
			flecha.solo_visual_red = not _sesion.is_world_authority()
			if flecha.get_parent()==null: mundo.add_child(flecha)
			else: flecha.reparent(mundo,true)
			flecha.global_position = accion.origen
			var fuerza := float(accion.fuerza)
			flecha.launch(accion.direccion,lerpf(actor.arrow_min_speed,actor.arrow_max_speed,fuerza),actor,fuerza)
			actor.set("_attack_cooldown",0.20)
			actor.set("_bow_release_strength",fuerza)
			actor.set("_bow_release_time",actor.bow_release_pose_duration)
			actor.set("_last_arrow_direction",accion.direccion)
	return true

func _recibir_dano(cantidad: int, origen: Vector3, nombre: String) -> void:
	if historia!=null: historia.damage_player(cantidad,origen,nombre)
