extends CanvasLayer

@onready var hint: Label = $Margin/Panel/Padding/Content/MouseHint
@onready var controls: Label = $Margin/Panel/Padding/Content/Controls
@onready var controls_panel: Control = $Margin
@onready var mount_hint: Label = $MountHint
@onready var player: Player = get_node("../Player") as Player
@onready var mini_map: Control = $MiniMap
@onready var full_map: Control = $FullMap
@onready var credits_overlay: Control = $CreditsOverlay

var map_open := false
var controls_open := false
var mini_map_open := false
var credits_open := false
var settings_open := false
var settings_overlay: ColorRect
var settings_controls: RichTextLabel
var resolution_selector: OptionButton
var lod_slider: HSlider
var lod_value_label: Label
var settings_status: Label
var settings_name_edit: LineEdit
var settings_character_selector: OptionButton
var network_status_label: Label
var lobby_overlay: ColorRect
var lobby_name_edit: LineEdit
var lobby_character_selector: OptionButton
var lobby_room_name_edit: LineEdit
var lobby_room_list: ItemList
var lobby_join_room_button: Button
var lobby_advanced_box: VBoxContainer
var lobby_address_edit: LineEdit
var lobby_status: Label
var lobby_open := false
var exploration_progress_panel: PanelContainer
var exploration_progress_bar: ProgressBar
var exploration_progress_label: Label
var exploration_prompt: Label
var exploration_journal_overlay: ColorRect
var exploration_journal_list: ItemList
var exploration_journal_summary: Label
var exploration_journal_open := false
var exploration_nearby_zone: Dictionary = {}
var exploration_notice_seconds := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	controls_panel.visible = false
	mini_map.visible = false
	full_map.visible = false
	credits_overlay.visible = false
	_build_settings_overlay()
	_build_lobby_overlay()
	_build_exploration_hud()
	_build_exploration_journal()
	GameSettings.resolution_changed.connect(_sync_resolution_selector)
	GameSettings.lod_distance_changed.connect(_sync_lod_slider)
	GameSettings.identity_changed.connect(_sync_identity_controls)
	NetworkSession.session_started.connect(_on_network_session_started)
	NetworkSession.session_status_changed.connect(_on_network_status_changed)
	NetworkSession.roster_changed.connect(_on_network_roster_changed)
	LobbyDirectory.rooms_changed.connect(_on_directory_rooms_changed)
	LobbyDirectory.directory_status_changed.connect(_on_directory_status_changed)
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration != null:
		exploration.connect("progress_changed", Callable(self, "_on_exploration_progress_changed"))
		exploration.connect("nearby_zone_changed", Callable(self, "_on_exploration_nearby_changed"))
		exploration.connect("zone_discovered", Callable(self, "_on_exploration_zone_discovered"))
		exploration.connect("selected_zone_changed", Callable(self, "_on_exploration_selected_changed"))
		_on_exploration_progress_changed(
			int(exploration.call("get_completed_count")),
			int(exploration.call("get_zone_count")),
			float(exploration.call("get_progress_ratio"))
		)
		_on_exploration_nearby_changed(exploration.call("get_nearby_zone") as Dictionary)
	if DisplayServer.get_name().to_lower() != "headless":
		_set_lobby_open(true)


func _unhandled_input(event: InputEvent) -> void:
	if lobby_open:
		return
	if event.is_action_pressed("settings"):
		_set_settings_open(not settings_open)
		get_viewport().set_input_as_handled()
		return
	if settings_open:
		return
	if event is InputEventKey:
		var journal_key := event as InputEventKey
		var journal_code := journal_key.physical_keycode if journal_key.physical_keycode != 0 else journal_key.keycode
		if journal_key.pressed and not journal_key.echo and journal_code == KEY_L:
			_set_exploration_journal_open(not exploration_journal_open)
			get_viewport().set_input_as_handled()
			return
	if exploration_journal_open:
		return
	if event.is_action_pressed("map"):
		if credits_open:
			return
		map_open = not map_open
		full_map.visible = map_open
		mini_map.visible = mini_map_open and not map_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if pressed_key == KEY_0:
		_set_credits_open(not credits_open)
		get_viewport().set_input_as_handled()
	elif credits_open:
		return
	elif pressed_key == KEY_N:
		controls_open = not controls_open
		controls_panel.visible = controls_open
		get_viewport().set_input_as_handled()
	elif pressed_key == KEY_B and not map_open:
		mini_map_open = not mini_map_open
		mini_map.visible = mini_map_open
		get_viewport().set_input_as_handled()


func _set_credits_open(open: bool) -> void:
	credits_open = open
	credits_overlay.visible = open
	if open:
		map_open = false
		full_map.visible = false
		mini_map.visible = false
		controls_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		mini_map.visible = mini_map_open
		controls_panel.visible = controls_open
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_settings_open(open: bool) -> void:
	if open and exploration_journal_open:
		_set_exploration_journal_open(false)
	settings_open = open
	settings_overlay.visible = open
	if open:
		map_open = false
		credits_open = false
		controls_open = false
		full_map.visible = false
		credits_overlay.visible = false
		controls_panel.visible = false
		mini_map.visible = false
		settings_controls.text = _controls_summary()
		_sync_resolution_selector(GameSettings.resolution)
		_sync_lod_slider(GameSettings.lod_distance_metres)
		_sync_identity_controls(GameSettings.player_name, GameSettings.character_index)
		_update_network_status_label()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		mini_map.visible = mini_map_open
		controls_panel.visible = controls_open
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_settings_open() -> bool:
	return settings_open


func _exit_tree() -> void:
	if (settings_open or lobby_open or exploration_journal_open) and get_tree() != null:
		get_tree().paused = false


func is_credits_open() -> bool:
	return credits_open


func _process(delta: float) -> void:
	if exploration_notice_seconds > 0.0:
		exploration_notice_seconds = maxf(exploration_notice_seconds - delta, 0.0)
		if exploration_notice_seconds <= 0.0:
			_refresh_exploration_prompt()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		hint.text = "Esc libera el ratón"
	else:
		hint.text = "Clic para volver a controlar la cámara"

	var equipped := player.get_equipped_item_name()
	if player.is_mounted():
		controls.text = "WASD / flechas · guiar   Mayús · galopar   E · explorar / desmontar\n1 Cuchillo · 2 Hacha · 3 Antorcha · 4 Brújula\nEn mano: %s   M · mapa   B · minimapa   L · 200 zonas\n5–9 · viaje rápido   Z · configuración   0 · créditos" % equipped
		mount_hint.text = "E · Desmontar de %s" % player.current_mount.horse_name
		mount_hint.visible = true
	else:
		controls.text = "WASD / flechas · caminar   Espacio · saltar   Mayús · correr\n1 Cuchillo · 2 Hacha · 3 Antorcha · 4 Brújula\nEn mano: %s   Clic izq. · atacar   E · explorar / montar\nM · mapa   B · minimapa   L · 200 zonas   5–9 · viaje rápido" % equipped
		var nearby_horse := player.get_nearby_mount()
		mount_hint.visible = nearby_horse != null
		if nearby_horse != null:
			mount_hint.text = "E · Montar a %s" % nearby_horse.horse_name


func _build_settings_overlay() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.name = "SettingsOverlay"
	settings_overlay.z_index = 300
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.color = Color(0.012, 0.022, 0.032, 0.93)
	settings_overlay.visible = false
	add_child(settings_overlay)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-450.0, -345.0)
	panel.size = Vector2(900.0, 690.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.065, 0.075, 0.98)
	panel_style.border_color = Color(0.77, 0.60, 0.32, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	settings_overlay.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 30)
	padding.add_theme_constant_override("margin_top", 24)
	padding.add_theme_constant_override("margin_right", 30)
	padding.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(padding)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	padding.add_child(content)

	var title := Label.new()
	title.name = "Title"
	title.text = "CONFIGURACIÓN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58))
	content.add_child(title)

	var identity_row := HBoxContainer.new()
	identity_row.name = "IdentityRow"
	identity_row.add_theme_constant_override("separation", 10)
	content.add_child(identity_row)
	var name_label := Label.new()
	name_label.text = "Nombre"
	name_label.add_theme_font_size_override("font_size", 17)
	identity_row.add_child(name_label)
	settings_name_edit = LineEdit.new()
	settings_name_edit.name = "PlayerNameEdit"
	settings_name_edit.max_length = 24
	settings_name_edit.custom_minimum_size = Vector2(175.0, 36.0)
	settings_name_edit.text = GameSettings.player_name
	identity_row.add_child(settings_name_edit)
	var character_label := Label.new()
	character_label.text = "Personaje"
	character_label.add_theme_font_size_override("font_size", 17)
	identity_row.add_child(character_label)
	settings_character_selector = OptionButton.new()
	settings_character_selector.name = "CharacterSelector"
	settings_character_selector.custom_minimum_size = Vector2(190.0, 36.0)
	_fill_character_selector(settings_character_selector)
	identity_row.add_child(settings_character_selector)
	var apply_identity_button := Button.new()
	apply_identity_button.name = "ApplyIdentityButton"
	apply_identity_button.text = "Aplicar"
	apply_identity_button.pressed.connect(_apply_settings_identity)
	identity_row.add_child(apply_identity_button)

	settings_controls = RichTextLabel.new()
	settings_controls.name = "AssignedControls"
	settings_controls.custom_minimum_size = Vector2(820.0, 210.0)
	settings_controls.bbcode_enabled = true
	settings_controls.fit_content = false
	settings_controls.scroll_active = true
	settings_controls.add_theme_font_size_override("normal_font_size", 17)
	settings_controls.add_theme_font_size_override("bold_font_size", 18)
	settings_controls.add_theme_color_override("default_color", Color(0.91, 0.94, 0.91))
	settings_controls.text = _controls_summary()
	content.add_child(settings_controls)

	var resolution_row := HBoxContainer.new()
	resolution_row.name = "ResolutionRow"
	resolution_row.add_theme_constant_override("separation", 18)
	content.add_child(resolution_row)
	var resolution_label := Label.new()
	resolution_label.text = "Resolución"
	resolution_label.custom_minimum_size.x = 260.0
	resolution_label.add_theme_font_size_override("font_size", 18)
	resolution_row.add_child(resolution_label)
	resolution_selector = OptionButton.new()
	resolution_selector.name = "ResolutionSelector"
	resolution_selector.custom_minimum_size = Vector2(230.0, 38.0)
	for resolution in GameSettings.get_supported_resolutions():
		resolution_selector.add_item("%d × %d" % [resolution.x, resolution.y])
	resolution_selector.item_selected.connect(_on_resolution_selected)
	resolution_row.add_child(resolution_selector)

	var lod_row := HBoxContainer.new()
	lod_row.name = "LodDistanceRow"
	lod_row.add_theme_constant_override("separation", 18)
	content.add_child(lod_row)
	var lod_title := Label.new()
	lod_title.text = "Distancia antes del LOD"
	lod_title.custom_minimum_size.x = 260.0
	lod_title.add_theme_font_size_override("font_size", 18)
	lod_row.add_child(lod_title)
	lod_slider = HSlider.new()
	lod_slider.name = "LodDistanceSlider"
	lod_slider.custom_minimum_size = Vector2(310.0, 38.0)
	lod_slider.min_value = GameSettings.MIN_LOD_DISTANCE
	lod_slider.max_value = GameSettings.MAX_LOD_DISTANCE
	lod_slider.step = 10.0
	lod_slider.value = GameSettings.lod_distance_metres
	lod_slider.value_changed.connect(_on_lod_distance_changed)
	lod_row.add_child(lod_slider)
	lod_value_label = Label.new()
	lod_value_label.name = "LodDistanceValue"
	lod_value_label.custom_minimum_size.x = 95.0
	lod_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lod_value_label.add_theme_font_size_override("font_size", 18)
	lod_row.add_child(lod_value_label)

	settings_status = Label.new()
	settings_status.name = "SettingsStatus"
	settings_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_status.add_theme_color_override("font_color", Color(0.66, 0.82, 0.68))
	settings_status.add_theme_font_size_override("font_size", 15)
	content.add_child(settings_status)
	network_status_label = Label.new()
	network_status_label.name = "NetworkStatus"
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.add_theme_color_override("font_color", Color(0.68, 0.82, 0.95))
	network_status_label.add_theme_font_size_override("font_size", 15)
	content.add_child(network_status_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 18)
	content.add_child(button_row)
	var reset_button := Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "Restaurar valores"
	reset_button.pressed.connect(func() -> void: GameSettings.reset_defaults())
	button_row.add_child(reset_button)
	var multiplayer_button := Button.new()
	multiplayer_button.name = "MultiplayerButton"
	multiplayer_button.text = "Multijugador"
	multiplayer_button.pressed.connect(func() -> void:
		_set_settings_open(false)
		_set_lobby_open(true)
	)
	button_row.add_child(multiplayer_button)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Cerrar · Z"
	close_button.pressed.connect(func() -> void: _set_settings_open(false))
	button_row.add_child(close_button)
	_sync_resolution_selector(GameSettings.resolution)
	_sync_lod_slider(GameSettings.lod_distance_metres)
	_sync_identity_controls(GameSettings.player_name, GameSettings.character_index)
	_update_network_status_label()


func _build_lobby_overlay() -> void:
	lobby_overlay = ColorRect.new()
	lobby_overlay.name = "MultiplayerLobby"
	lobby_overlay.z_index = 350
	lobby_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_overlay.color = Color(0.008, 0.018, 0.026, 0.95)
	lobby_overlay.visible = false
	add_child(lobby_overlay)

	var panel := PanelContainer.new()
	panel.name = "LobbyPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-410.0, -355.0)
	panel.size = Vector2(820.0, 710.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.067, 0.073, 0.99)
	style.border_color = Color(0.78, 0.60, 0.31, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	lobby_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var title := Label.new()
	title.text = "SENDEROS DEL HORIZONTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Elige tu aventurero · Cooperativo para un máximo de 8 jugadores"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	content.add_child(subtitle)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	content.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Tu nombre"
	name_label.custom_minimum_size.x = 190.0
	name_label.add_theme_font_size_override("font_size", 18)
	name_row.add_child(name_label)
	lobby_name_edit = LineEdit.new()
	lobby_name_edit.name = "LobbyPlayerName"
	lobby_name_edit.max_length = 24
	lobby_name_edit.text = GameSettings.player_name
	lobby_name_edit.custom_minimum_size = Vector2(410.0, 40.0)
	name_row.add_child(lobby_name_edit)

	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 18)
	content.add_child(character_row)
	var character_label := Label.new()
	character_label.text = "Personaje Quaternius"
	character_label.custom_minimum_size.x = 190.0
	character_label.add_theme_font_size_override("font_size", 18)
	character_row.add_child(character_label)
	lobby_character_selector = OptionButton.new()
	lobby_character_selector.name = "LobbyCharacterSelector"
	lobby_character_selector.custom_minimum_size = Vector2(410.0, 40.0)
	_fill_character_selector(lobby_character_selector)
	character_row.add_child(lobby_character_selector)

	var room_name_row := HBoxContainer.new()
	room_name_row.add_theme_constant_override("separation", 18)
	content.add_child(room_name_row)
	var room_name_label := Label.new()
	room_name_label.text = "Nombre de expedición"
	room_name_label.custom_minimum_size.x = 190.0
	room_name_label.add_theme_font_size_override("font_size", 18)
	room_name_row.add_child(room_name_label)
	lobby_room_name_edit = LineEdit.new()
	lobby_room_name_edit.name = "LobbyRoomName"
	lobby_room_name_edit.max_length = 40
	lobby_room_name_edit.text = "Expedición de %s" % GameSettings.player_name
	lobby_room_name_edit.custom_minimum_size = Vector2(410.0, 40.0)
	room_name_row.add_child(lobby_room_name_edit)

	var rooms_title := Label.new()
	rooms_title.text = "PARTIDAS ACTIVAS EN EL NAS"
	rooms_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rooms_title.add_theme_font_size_override("font_size", 17)
	rooms_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.52))
	content.add_child(rooms_title)
	lobby_room_list = ItemList.new()
	lobby_room_list.name = "ActiveRoomList"
	lobby_room_list.custom_minimum_size = Vector2(680.0, 128.0)
	lobby_room_list.select_mode = ItemList.SELECT_SINGLE
	lobby_room_list.allow_reselect = true
	lobby_room_list.item_selected.connect(_on_room_selected)
	lobby_room_list.item_activated.connect(func(_index: int) -> void: _on_join_room_pressed())
	content.add_child(lobby_room_list)
	var room_actions := HBoxContainer.new()
	room_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	room_actions.add_theme_constant_override("separation", 14)
	content.add_child(room_actions)
	var refresh_button := Button.new()
	refresh_button.name = "RefreshRoomsButton"
	refresh_button.text = "Actualizar lista"
	refresh_button.pressed.connect(func() -> void: LobbyDirectory.refresh_rooms())
	room_actions.add_child(refresh_button)
	lobby_join_room_button = Button.new()
	lobby_join_room_button.name = "JoinRoomButton"
	lobby_join_room_button.text = "Unirse a la seleccionada"
	lobby_join_room_button.disabled = true
	lobby_join_room_button.pressed.connect(_on_join_room_pressed)
	room_actions.add_child(lobby_join_room_button)
	var advanced_button := Button.new()
	advanced_button.name = "AdvancedConnectionButton"
	advanced_button.text = "Avanzado · IP manual"
	advanced_button.pressed.connect(func() -> void:
		lobby_advanced_box.visible = not lobby_advanced_box.visible
	)
	room_actions.add_child(advanced_button)

	lobby_advanced_box = VBoxContainer.new()
	lobby_advanced_box.name = "AdvancedConnection"
	lobby_advanced_box.add_theme_constant_override("separation", 6)
	lobby_advanced_box.visible = false
	content.add_child(lobby_advanced_box)

	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 18)
	lobby_advanced_box.add_child(address_row)
	var address_label := Label.new()
	address_label.text = "IP del anfitrión"
	address_label.custom_minimum_size.x = 190.0
	address_label.add_theme_font_size_override("font_size", 18)
	address_row.add_child(address_label)
	lobby_address_edit = LineEdit.new()
	lobby_address_edit.name = "HostAddress"
	lobby_address_edit.placeholder_text = "192.168.1.50 o IP pública"
	lobby_address_edit.text = "127.0.0.1"
	lobby_address_edit.custom_minimum_size = Vector2(410.0, 40.0)
	address_row.add_child(lobby_address_edit)

	var help := Label.new()
	var local_addresses := NetworkSession.get_lan_addresses()
	var local_text := ", ".join(local_addresses) if not local_addresses.is_empty() else "no detectada"
	help.text = "LAN del anfitrión: %s  ·  Internet: abrir UDP %d en el router" % [local_text, NetworkSession.PORT]
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.68, 0.78, 0.80))
	lobby_advanced_box.add_child(help)
	var manual_join_button := Button.new()
	manual_join_button.name = "JoinButton"
	manual_join_button.text = "Unirse por IP manual"
	manual_join_button.pressed.connect(_on_join_pressed)
	lobby_advanced_box.add_child(manual_join_button)

	lobby_status = Label.new()
	lobby_status.name = "LobbyStatus"
	lobby_status.text = "Consultando el tablón de partidas del NAS…"
	lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status.add_theme_font_size_override("font_size", 17)
	lobby_status.add_theme_color_override("font_color", Color(0.71, 0.88, 0.71))
	content.add_child(lobby_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	content.add_child(buttons)
	var solo_button := Button.new()
	solo_button.name = "SoloButton"
	solo_button.text = "Jugar solo"
	solo_button.pressed.connect(_on_play_solo_pressed)
	buttons.add_child(solo_button)
	var host_button := Button.new()
	host_button.name = "HostButton"
	host_button.text = "Crear y anunciar"
	host_button.pressed.connect(_on_host_pressed)
	buttons.add_child(host_button)
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "Volver"
	back_button.pressed.connect(func() -> void: _set_lobby_open(false))
	buttons.add_child(back_button)
	_sync_identity_controls(GameSettings.player_name, GameSettings.character_index)


func _fill_character_selector(selector: OptionButton) -> void:
	selector.clear()
	for option in GameSettings.get_character_options():
		selector.add_item(String(option.name))
	selector.select(GameSettings.character_index)


func _sync_identity_controls(name_value: String, index_value: int) -> void:
	if settings_name_edit != null:
		settings_name_edit.text = name_value
	if settings_character_selector != null:
		settings_character_selector.select(index_value)
	if lobby_name_edit != null:
		lobby_name_edit.text = name_value
	if lobby_character_selector != null:
		lobby_character_selector.select(index_value)


func _apply_settings_identity() -> void:
	GameSettings.set_player_identity(settings_name_edit.text, settings_character_selector.selected)
	settings_status.text = "Identidad aplicada: %s · %s" % [GameSettings.player_name, GameSettings.get_character_name(GameSettings.character_index)]


func _save_lobby_identity() -> void:
	GameSettings.set_player_identity(lobby_name_edit.text, lobby_character_selector.selected)


func _on_play_solo_pressed() -> void:
	_save_lobby_identity()
	NetworkSession.play_offline()
	_set_lobby_open(false)


func _on_host_pressed() -> void:
	_save_lobby_identity()
	var error := NetworkSession.host_game()
	if error == OK:
		LobbyDirectory.publish_room(lobby_room_name_edit.text)


func _on_join_pressed() -> void:
	_save_lobby_identity()
	NetworkSession.join_game(lobby_address_edit.text)


func _on_join_room_pressed() -> void:
	var selected := lobby_room_list.get_selected_items()
	if selected.is_empty():
		lobby_status.text = "Selecciona una partida activa"
		return
	var room := LobbyDirectory.get_room(int(lobby_room_list.get_item_metadata(selected[0])))
	if room.is_empty():
		lobby_status.text = "La sala ya no está disponible; actualiza la lista"
		return
	if not LobbyDirectory.is_compatible(room):
		lobby_status.text = "La sala usa la versión %s y tú tienes %s" % [
			String(room.get("game_version", "?")),
			String(ProjectSettings.get_setting("application/config/version", "?")),
		]
		return
	_save_lobby_identity()
	NetworkSession.join_game(String(room.address), int(room.port))


func _on_room_selected(index: int) -> void:
	var room := LobbyDirectory.get_room(int(lobby_room_list.get_item_metadata(index)))
	lobby_join_room_button.disabled = room.is_empty() or not LobbyDirectory.is_compatible(room)


func _on_directory_rooms_changed(active_rooms: Array) -> void:
	if lobby_room_list == null:
		return
	lobby_room_list.clear()
	for room_index in active_rooms.size():
		var room := active_rooms[room_index] as Dictionary
		var compatible := LobbyDirectory.is_compatible(room)
		var label := "%s  ·  %s  ·  %d/%d  ·  v%s" % [
			String(room.get("name", "Expedición")),
			String(room.get("host_name", "Aventurero")),
			int(room.get("players", 1)),
			int(room.get("max_players", 8)),
			String(room.get("game_version", "?")),
		]
		if not compatible:
			label += "  ·  versión incompatible"
		var item := lobby_room_list.item_count
		lobby_room_list.add_item(label)
		lobby_room_list.set_item_metadata(item, room_index)
		lobby_room_list.set_item_disabled(item, not compatible)
	if active_rooms.is_empty():
		var empty_item := lobby_room_list.item_count
		lobby_room_list.add_item("No hay partidas anunciadas ahora mismo")
		lobby_room_list.set_item_disabled(empty_item, true)
	lobby_join_room_button.disabled = true


func _on_directory_status_changed(message: String) -> void:
	if lobby_status != null:
		lobby_status.text = message


func _set_lobby_open(open: bool) -> void:
	if open and exploration_journal_open:
		_set_exploration_journal_open(false)
	lobby_open = open
	lobby_overlay.visible = open
	if open:
		map_open = false
		credits_open = false
		controls_open = false
		full_map.visible = false
		credits_overlay.visible = false
		controls_panel.visible = false
		mini_map.visible = false
		_sync_identity_controls(GameSettings.player_name, GameSettings.character_index)
		LobbyDirectory.refresh_rooms()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		mini_map.visible = mini_map_open
		controls_panel.visible = controls_open
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_lobby_open() -> bool:
	return lobby_open


func _on_network_session_started(_mode_name: String) -> void:
	if lobby_open:
		_set_lobby_open(false)
	_update_network_status_label()


func _on_network_status_changed(message: String) -> void:
	if lobby_status != null:
		lobby_status.text = message
	_update_network_status_label()


func _on_network_roster_changed(_roster: Dictionary) -> void:
	_update_network_status_label()


func _update_network_status_label() -> void:
	if network_status_label != null:
		network_status_label.text = "Sesión: %s · %d/%d jugadores · UDP %d" % [
			NetworkSession.get_mode_name(),
			NetworkSession.get_player_count(),
			NetworkSession.MAX_PLAYERS,
			NetworkSession.PORT,
		]


func _build_exploration_hud() -> void:
	exploration_progress_panel = PanelContainer.new()
	exploration_progress_panel.name = "ExplorationProgress"
	exploration_progress_panel.z_index = 70
	exploration_progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exploration_progress_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	exploration_progress_panel.position = Vector2(-260.0, 14.0)
	exploration_progress_panel.size = Vector2(520.0, 66.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.052, 0.045, 0.88)
	panel_style.border_color = Color(0.82, 0.64, 0.32, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	exploration_progress_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(exploration_progress_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	exploration_progress_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	exploration_progress_label = Label.new()
	exploration_progress_label.name = "ExplorationProgressLabel"
	exploration_progress_label.text = "EXPLORACIÓN DE LA ISLA · 0 / 200 · L diario"
	exploration_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exploration_progress_label.add_theme_font_size_override("font_size", 16)
	exploration_progress_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	content.add_child(exploration_progress_label)
	exploration_progress_bar = ProgressBar.new()
	exploration_progress_bar.name = "ExplorationProgressBar"
	exploration_progress_bar.max_value = 200.0
	exploration_progress_bar.value = 0.0
	exploration_progress_bar.show_percentage = false
	exploration_progress_bar.custom_minimum_size = Vector2(490.0, 14.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.10, 0.14, 0.11, 0.96)
	background.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.34, 0.72, 0.30, 0.98)
	fill.set_corner_radius_all(7)
	exploration_progress_bar.add_theme_stylebox_override("background", background)
	exploration_progress_bar.add_theme_stylebox_override("fill", fill)
	content.add_child(exploration_progress_bar)

	exploration_prompt = Label.new()
	exploration_prompt.name = "ExplorationPrompt"
	exploration_prompt.z_index = 75
	exploration_prompt.visible = false
	exploration_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exploration_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	exploration_prompt.position = Vector2(-340.0, -142.0)
	exploration_prompt.size = Vector2(680.0, 42.0)
	exploration_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exploration_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exploration_prompt.add_theme_font_size_override("font_size", 21)
	exploration_prompt.add_theme_color_override("font_color", Color(1.0, 0.87, 0.48))
	exploration_prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.96))
	exploration_prompt.add_theme_constant_override("shadow_offset_x", 2)
	exploration_prompt.add_theme_constant_override("shadow_offset_y", 2)
	add_child(exploration_prompt)


func _build_exploration_journal() -> void:
	exploration_journal_overlay = ColorRect.new()
	exploration_journal_overlay.name = "ExplorationJournal"
	exploration_journal_overlay.z_index = 280
	exploration_journal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exploration_journal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	exploration_journal_overlay.color = Color(0.018, 0.025, 0.019, 0.94)
	exploration_journal_overlay.visible = false
	add_child(exploration_journal_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-470.0, -340.0)
	panel.size = Vector2(940.0, 680.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.095, 0.06, 0.99)
	panel_style.border_color = Color(0.86, 0.67, 0.33, 0.96)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	exploration_journal_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var title := Label.new()
	title.text = "DIARIO DE EXPLORACIÓN · 200 LUGARES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	content.add_child(title)
	exploration_journal_summary = Label.new()
	exploration_journal_summary.name = "ExplorationJournalSummary"
	exploration_journal_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exploration_journal_summary.add_theme_font_size_override("font_size", 16)
	exploration_journal_summary.add_theme_color_override("font_color", Color(0.88, 0.86, 0.72))
	content.add_child(exploration_journal_summary)
	var help := Label.new()
	help.text = "✓ descubierta · ○ pendiente · Pulsa una entrada para marcarla y verla en el mapa"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.60))
	content.add_child(help)
	exploration_journal_list = ItemList.new()
	exploration_journal_list.name = "ExplorationZoneList"
	exploration_journal_list.custom_minimum_size = Vector2(870.0, 500.0)
	exploration_journal_list.select_mode = ItemList.SELECT_SINGLE
	exploration_journal_list.allow_reselect = true
	exploration_journal_list.fixed_icon_size = Vector2i(0, 0)
	exploration_journal_list.add_theme_font_size_override("font_size", 16)
	exploration_journal_list.item_clicked.connect(_on_exploration_item_clicked)
	content.add_child(exploration_journal_list)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	var clear_target := Button.new()
	clear_target.text = "Quitar marcador"
	clear_target.pressed.connect(_clear_exploration_target)
	buttons.add_child(clear_target)
	var close_button := Button.new()
	close_button.text = "Cerrar · L"
	close_button.pressed.connect(func() -> void: _set_exploration_journal_open(false))
	buttons.add_child(close_button)


func _set_exploration_journal_open(open: bool) -> void:
	exploration_journal_open = open
	exploration_journal_overlay.visible = open
	if open:
		map_open = false
		credits_open = false
		controls_open = false
		full_map.visible = false
		credits_overlay.visible = false
		controls_panel.visible = false
		mini_map.visible = false
		_rebuild_exploration_journal()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		mini_map.visible = mini_map_open and not map_open
		controls_panel.visible = controls_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED


func is_exploration_journal_open() -> bool:
	return exploration_journal_open


func _rebuild_exploration_journal() -> void:
	if exploration_journal_list == null:
		return
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration == null:
		return
	exploration_journal_list.clear()
	var zones: Array = exploration.call("get_zones")
	for zone_value in zones:
		var zone := zone_value as Dictionary
		var completed := bool(zone.get("discovered", false))
		var selected := bool(zone.get("selected", false))
		var prefix := "✓" if completed else "○"
		if selected:
			prefix = "➤ " + prefix
		exploration_journal_list.add_item("%s  %s  ·  %s" % [prefix, String(zone.name), String(zone.biome).capitalize()])
		var index := exploration_journal_list.item_count - 1
		exploration_journal_list.set_item_metadata(index, String(zone.id))
		exploration_journal_list.set_item_tooltip(index, String(zone.description))
		exploration_journal_list.set_item_custom_fg_color(
			index,
			Color(0.53, 0.88, 0.52) if completed else Color(0.91, 0.84, 0.66)
		)
	var completed_count := int(exploration.call("get_completed_count"))
	var total := int(exploration.call("get_zone_count"))
	exploration_journal_summary.text = "%d de %d zonas exploradas · %.1f%%" % [
		completed_count,
		total,
		100.0 * float(exploration.call("get_progress_ratio")),
	]


func _on_exploration_item_clicked(index: int, _position: Vector2, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT or exploration_journal_list == null:
		return
	var zone_id := String(exploration_journal_list.get_item_metadata(index))
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration == null or not bool(exploration.call("select_zone", zone_id)):
		return
	_set_exploration_journal_open(false)
	map_open = true
	full_map.visible = true
	mini_map.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _clear_exploration_target() -> void:
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration != null:
		exploration.call("clear_selected_zone")
	_rebuild_exploration_journal()


func _on_exploration_progress_changed(completed: int, total: int, ratio: float) -> void:
	if exploration_progress_bar != null:
		exploration_progress_bar.max_value = float(total)
		exploration_progress_bar.value = float(completed)
	if exploration_progress_label != null:
		exploration_progress_label.text = "EXPLORACIÓN DE LA ISLA · %d / %d · %.1f%% · L diario" % [
			completed,
			total,
			ratio * 100.0,
		]
	if exploration_journal_open:
		_rebuild_exploration_journal()


func _on_exploration_nearby_changed(zone: Dictionary) -> void:
	exploration_nearby_zone = zone
	if exploration_notice_seconds <= 0.0:
		_refresh_exploration_prompt()


func _on_exploration_zone_discovered(zone: Dictionary, completed: int, total: int) -> void:
	exploration_notice_seconds = 4.5
	if exploration_prompt != null:
		exploration_prompt.text = "✓ ZONA EXPLORADA · %s · %d/%d · guardado automático" % [
			String(zone.name),
			completed,
			total,
		]
		exploration_prompt.visible = true


func _on_exploration_selected_changed(_zone: Dictionary) -> void:
	if exploration_journal_open:
		_rebuild_exploration_journal()


func _refresh_exploration_prompt() -> void:
	if exploration_prompt == null:
		return
	if exploration_nearby_zone.is_empty():
		exploration_prompt.visible = false
		return
	exploration_prompt.text = "E · EXPLORAR · %s" % String(exploration_nearby_zone.name)
	exploration_prompt.visible = true


func _controls_summary() -> String:
	return (
		"[b]MOVIMIENTO Y ACCIÓN[/b]\n"
		+ "Avanzar: %s     Retroceder: %s\n" % [GameSettings.action_keys("move_forward"), GameSettings.action_keys("move_back")]
		+ "Izquierda: %s     Derecha: %s\n" % [GameSettings.action_keys("move_left"), GameSettings.action_keys("move_right")]
		+ "Saltar: %s     Correr / galopar: %s\n" % [GameSettings.action_keys("jump"), GameSettings.action_keys("sprint")]
		+ "Interactuar / montar: %s     Atacar: %s\n\n" % [GameSettings.action_keys("interact"), GameSettings.action_keys("attack")]
		+ "[b]EQUIPO Y NAVEGACIÓN[/b]\n"
		+ "1 Cuchillo · 2 Hacha · 3 Antorcha · 4 Brújula\n"
		+ "5 Dunas · 6 Nieve · 7 Villa · 8 Bosque Umbrío · 9 Bosque Tenebroso\n"
		+ "Mapa: %s · B Minimapa · L Diario de 200 zonas · N Ayuda · 0 Créditos\n" % GameSettings.action_keys("map")
		+ "Configuración / identidad / multijugador: %s · Esc Liberar ratón" % GameSettings.action_keys("settings")
	)


func _on_resolution_selected(index: int) -> void:
	var resolutions := GameSettings.get_supported_resolutions()
	if index < 0 or index >= resolutions.size():
		return
	GameSettings.set_resolution(resolutions[index])
	settings_status.text = "Resolución aplicada: %d × %d" % [resolutions[index].x, resolutions[index].y]


func _on_lod_distance_changed(value: float) -> void:
	GameSettings.set_lod_distance(value)
	settings_status.text = "Distancia LOD aplicada a todo el mundo"


func _sync_resolution_selector(resolution: Vector2i) -> void:
	if resolution_selector == null:
		return
	var resolutions := GameSettings.get_supported_resolutions()
	for index in resolutions.size():
		if resolutions[index] == resolution:
			resolution_selector.select(index)
			return


func _sync_lod_slider(value: float) -> void:
	if lod_slider != null and not is_equal_approx(lod_slider.value, value):
		lod_slider.set_value_no_signal(value)
	if lod_value_label != null:
		lod_value_label.text = "%d m" % roundi(value)
