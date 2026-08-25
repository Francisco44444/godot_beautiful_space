extends SceneTree

## Comprueba la identidad Quaternius, el lobby, el límite de ocho jugadores,
## la creación ENet y la réplica visual que utilizarán los compañeros remotos.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var settings := root.get_node_or_null("GameSettings")
	var session := root.get_node_or_null("NetworkSession")
	var directory := root.get_node_or_null("LobbyDirectory")
	if settings == null or session == null or directory == null:
		_fail("No se cargaron GameSettings, NetworkSession y LobbyDirectory.")
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
	print("MULTIPLAYER TEST OK: lobby, 8 personajes, ENet y réplica remota disponibles.")
	quit(0)


func _fail(message: String) -> void:
	var session := root.get_node_or_null("NetworkSession")
	if session != null:
		session.call("leave_session")
	paused = false
	push_error(message)
	quit(1)
