extends SceneTree

## Comprueba la identidad Quaternius, el lobby, el límite de ocho jugadores,
## la creación ENet y la réplica visual que utilizarán los compañeros remotos.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var settings := root.get_node_or_null("GameSettings")
	var session := root.get_node_or_null("NetworkSession")
	var directory := root.get_node_or_null("LobbyDirectory")
	var save_manager := root.get_node_or_null("SaveGameManager")
	if settings == null or session == null or directory == null or save_manager == null:
		_fail("No se cargaron GameSettings, NetworkSession, LobbyDirectory y SaveGameManager.")
		return
	if NetworkSession.MAX_PLAYERS != 8 or NetworkSession.PORT != 24567:
		_fail("La sesión no está limitada a ocho jugadores en el puerto previsto.")
		return
	var options: Array = settings.call("get_character_options")
	if options.size() != 8:
		_fail("La identidad no ofrece exactamente ocho personajes.")
		return
	for option in options:
		if not FileAccess.file_exists(String(option.path)):
			_fail("Falta el personaje Quaternius: %s" % option.path)
			return

	settings.call("set_player_identity", "Lúa", 6, false)
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in range(5):
		await process_frame
	var player := world.get_node("Player") as Player
	var hud := world.get_node("HUD")
	var lobby := hud.get_node_or_null("MultiplayerLobby") as Control
	var name_edit: LineEdit
	var character_selector: OptionButton
	var room_list: ItemList
	var advanced_connection: VBoxContainer
	if lobby != null:
		name_edit = lobby.find_child("LobbyPlayerName", true, false) as LineEdit
		character_selector = lobby.find_child("LobbyCharacterSelector", true, false) as OptionButton
		room_list = lobby.find_child("ActiveRoomList", true, false) as ItemList
		advanced_connection = lobby.find_child("AdvancedConnection", true, false) as VBoxContainer
	if (
		lobby == null or name_edit == null or character_selector == null
		or room_list == null or advanced_connection == null or advanced_connection.visible
		or character_selector.item_count != 8
		or player.character_index != 6
		or player.player_display_name != "Lúa"
	):
		_fail("El lobby NAS, su modo avanzado o la identidad no están bien configurados.")
		return

	var host_error: Error = session.call("host_game")
	if host_error != OK or not bool(session.call("is_networked")) or int(session.call("get_player_count")) != 1:
		_fail("No se pudo crear una partida ENet para el anfitrión.")
		return
	if not bool(session.call("is_world_authority")) or not is_equal_approx(float(save_manager.call("get_autosave_seconds")), 120.0):
		_fail("El anfitrión no gobierna el mundo o el autoguardado cooperativo no dura dos minutos.")
		return
	var shared_state := world.call("get_network_world_state") as Dictionary
	if (
		not shared_state.has("sun_cycle_radians")
		or not shared_state.has("tide_phase")
		or not shared_state.has("wildlife")
		or (shared_state.wildlife as Array).is_empty()
		or not shared_state.has("vegetation_resources")
		or not shared_state.has("adventure_resources")
	):
		_fail("La autoridad no prepara clima, fauna y recursos persistentes para los invitados.")
		return
	var host_save_states := session.call("get_party_save_states") as Dictionary
	if not host_save_states.has("Lúa") or not (host_save_states["Lúa"] as Dictionary).has("inventory"):
		_fail("La ranura cooperativa no conserva el inventario independiente del anfitrión.")
		return

	var fake_roster := {
		1: {"name": "Lúa", "character_index": 6},
		42: {"name": "Compañero", "character_index": 2},
	}
	world.call("_on_network_roster_changed", fake_roster)
	var replica := world.get_node_or_null("NetworkPlayers/Peer_42") as Player
	if replica == null or not replica.network_remote or replica.player_display_name != "Compañero" or replica.character_index != 2:
		_fail("El mundo no crea la réplica visual del compañero remoto.")
		return
	replica.apply_network_state(Vector3(12.0, 3.0, -8.0), 0.7, Vector3(4.0, 0.0, 0.0), 2)
	for _frame in range(3):
		await physics_frame
	if not replica.get_node("PlayerName").visible or replica.equipped_slot != 2:
		_fail("La réplica no muestra nombre o equipo sincronizado.")
		return
	# Una petición remota solo prospera cerca del objeto y con el hacha. El id
	# aceptado entra inmediatamente en el estado autoritativo que reciben todos.
	var scatter := world.get_node("VegetationScatter") as VegetationScatter
	var resource_ids: PackedStringArray = scatter.get("_harvest_tree_ids")
	var tree_positions: Array[Vector3] = scatter.get("_harvest_tree_positions")
	var network_tree_id := resource_ids[0]
	var network_tree_position := tree_positions[0]
	replica.global_position = network_tree_position + Vector3(0.0, 0.0, 2.4)
	replica.equipped_slot = 1
	if bool(world.call(
		"_on_network_world_resource_break_requested", 42, "vegetation", network_tree_id
	)):
		_fail("El anfitrión aceptó una tala remota sin el hacha.")
		return
	replica.equipped_slot = 2
	replica.global_position = network_tree_position + Vector3(30.0, 0.0, 0.0)
	if bool(world.call(
		"_on_network_world_resource_break_requested", 42, "vegetation", network_tree_id
	)):
		_fail("El anfitrión aceptó una tala remota desde demasiada distancia.")
		return
	replica.global_position = network_tree_position + Vector3(0.0, 0.0, 2.4)
	# La prueba no debe escribir una ranura real del usuario.
	save_manager.call("bind_world", null)
	if not bool(world.call(
		"_on_network_world_resource_break_requested", 42, "vegetation", network_tree_id
	)):
		_fail("El anfitrión rechazó una tala remota válida y cercana.")
		return
	var authoritative_state := world.call("get_network_world_state") as Dictionary
	var destroyed_ids := (
		(authoritative_state.vegetation_resources as Dictionary)
		.get("destroyed_resource_ids", []) as Array
	)
	if network_tree_id not in destroyed_ids:
		_fail("La tala aceptada no entró en el estado mundial compartido.")
		return

	session.call("leave_session")
	settings.call("reset_defaults", false)
	var audio := world.get_node("AmbientAudio") as AmbientAudio
	audio.music.stop()
	audio.snow_music.stop()
	audio.desert_music.stop()
	audio.wind.stop()
	audio.birds.stop()
	world.queue_free()
	for _frame in range(8):
		await process_frame
	print("MULTIPLAYER TEST OK: lobby, 8 personajes, autoridad del mundo, guardado cooperativo y réplica remota disponibles.")
	quit(0)


func _fail(message: String) -> void:
	var session := root.get_node_or_null("NetworkSession")
	if session != null:
		session.call("leave_session")
	paused = false
	push_error(message)
	quit(1)
