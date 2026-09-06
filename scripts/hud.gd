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
var mini_map_open := true
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
var campaign_progress_label: Label
var quest_tracker_panel: PanelContainer
var quest_tracker_rows: VBoxContainer
var exploration_prompt: Label
var exploration_journal_overlay: ColorRect
var exploration_journal_list: ItemList
var exploration_journal_summary: Label
var exploration_journal_open := false
var exploration_nearby_zone: Dictionary = {}
var exploration_notice_seconds := 0.0
var inventory_overlay: ColorRect
var inventory_grid: GridContainer
var inventory_scroll: ScrollContainer
var inventory_summary: Label
var inventory_open := false
var quickbar_panel: PanelContainer
var quickbar_buttons: Array[Button] = []
var arrow_counter: Label
## Marca de impacto del arco, creada la primera vez que se tensa.
var arrow_impact_marker: Label
var horse_call_button: Button
var bow_power_bar: ProgressBar
var _spin_hint_shown := false
var adventure_action_hint: Label
var action_feedback_label: Label
var action_feedback_seconds := 0.0
var story_hint_panel: PanelContainer
var story_hint_label: Label
var story_hint_expanded := false
var story_hint_index := 0
var _pending_choices: Array = []
var story_current_objective: Dictionary = {}
var story_dialogue_overlay: ColorRect
var story_dialogue_title: Label
var story_dialogue_body: RichTextLabel
var story_dialogue_choices: VBoxContainer
var story_dialogue_close: Button
var story_dialogue_open := false
var player_health_bar: ProgressBar
var vitals_panel: PanelContainer
var vitals_health_bar: UiVitalBar
var vitals_stamina_bar: UiVitalBar
var inventory_manager: Node
var pause_menu: PauseMenu
var fps_counter: Label
var chronicle_view: RichTextLabel = null
var journal_title: Label = null
var journal_help: Label = null
var journal_page := 0
var ally_strip: PanelContainer = null
var ally_strip_rows: VBoxContainer = null
var boss_banner: PanelContainer = null
var boss_banner_name: Label = null
var boss_banner_bar: UiVitalBar = null
var boss_banner_demand: Label = null
var boss_banner_site: Label = null
var boss_banner_elapsed := 0.0
var fps_refresh_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	controls_panel.visible = false
	mini_map.visible = false
	full_map.visible = false
	credits_overlay.visible = false
	_build_fps_counter()
	_build_settings_overlay()
	_build_lobby_overlay()
	_build_exploration_hud()
	_build_exploration_journal()
	_build_inventory_overlay()
	_build_quickbar()
	_build_story_hud()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	var credits_text := credits_overlay.get_node_or_null("CreditsPanel/Padding/Content/CreditsText") as RichTextLabel
	if credits_text != null:
		pause_menu.set_credits_content(credits_text.text.replace("0 · cerrar", "Esc · volver"))
	pause_menu.closed.connect(func() -> void:
		mini_map.visible = mini_map_open and not map_open
	)
	pause_menu.multiplayer_requested.connect(func() -> void:
		pause_menu.set_open(false)
		_set_lobby_open(true)
	)
	inventory_manager = get_node_or_null("/root/InventoryManager")
	GameSettings.resolution_changed.connect(_sync_resolution_selector)
	GameSettings.lod_distance_changed.connect(_sync_lod_slider)
	GameSettings.identity_changed.connect(_sync_identity_controls)
	NetworkSession.session_started.connect(_on_network_session_started)
	NetworkSession.session_status_changed.connect(_on_network_status_changed)
	NetworkSession.roster_changed.connect(_on_network_roster_changed)
	LobbyDirectory.rooms_changed.connect(_on_directory_rooms_changed)
	LobbyDirectory.directory_status_changed.connect(_on_directory_status_changed)
	if inventory_manager != null:
		inventory_manager.connect("inventory_changed", Callable(self, "_on_inventory_changed"))
		inventory_manager.connect("equipment_changed", Callable(self, "_on_inventory_equipment_changed"))
	player.action_feedback.connect(_on_player_action_feedback)
	player.bow_draw_changed.connect(_on_bow_draw_changed)
	player.arrow_fired.connect(_on_arrow_fired)
	player.charge_changed.connect(_on_charge_changed)
	player.equipment_changed.connect(_on_player_quickslot_changed)
	_on_inventory_changed(inventory_manager.call("get_inventory_entries") as Array if inventory_manager != null else [])
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration != null:
		exploration.connect("progress_changed", Callable(self, "_on_exploration_progress_changed"))
		exploration.connect("nearby_zone_changed", Callable(self, "_on_exploration_nearby_changed"))
		exploration.connect("zone_discovered", Callable(self, "_on_exploration_zone_discovered"))
		exploration.connect("selected_zone_changed", Callable(self, "_on_exploration_selected_changed"))
		exploration.connect("story_objective_changed", Callable(self, "_on_story_objective_changed"))
		_on_exploration_progress_changed(
			int(exploration.call("get_completed_count")),
			int(exploration.call("get_zone_count")),
			float(exploration.call("get_progress_ratio"))
		)
		_on_exploration_nearby_changed(exploration.call("get_nearby_zone") as Dictionary)
		_on_story_objective_changed(exploration.call("get_current_story_objective") as Dictionary)
	var story_runtime := get_node_or_null("../RPGStoryRuntime")
	if story_runtime != null:
		story_runtime.connect("dialogue_requested", Callable(self, "_on_story_dialogue_requested"))
		story_runtime.connect("player_health_changed", Callable(self, "_on_player_health_changed"))
		if story_runtime.has_signal("dialogue_with_choices"):
			story_runtime.connect("dialogue_with_choices", Callable(self, "_on_dialogue_with_choices"))
	var hero := get_tree().root.find_child("Player", true, false)
	if hero != null and hero.has_signal("stamina_changed"):
		hero.connect("stamina_changed", Callable(self, "_on_player_stamina_changed"))
	# El mundo arranca siempre como partida individual. El vestíbulo cooperativo
	# solo se abre cuando el jugador lo solicita desde ESC → Multijugador.
	lobby_open = false
	lobby_overlay.visible = false
	mini_map.visible = mini_map_open
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_cancel()
		get_viewport().set_input_as_handled()
		return
	if lobby_open:
		return
	if pause_menu != null and pause_menu.visible:
		return
	if story_dialogue_open:
		# Contestar con el teclado tiene que resolverse aquí, antes del corte:
		# más abajo el diálogo abierto ya ha descartado el evento.
		if not _pending_choices.is_empty() and event is InputEventKey:
			var reply := event as InputEventKey
			if reply.pressed and not reply.echo:
				var slot := int(reply.keycode) - int(KEY_1)
				if slot >= 0 and slot < _pending_choices.size():
					_answer_dialogue(slot)
					get_viewport().set_input_as_handled()
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
		if journal_key.pressed and not journal_key.echo and journal_code == KEY_I:
			_set_inventory_open(not inventory_open)
			get_viewport().set_input_as_handled()
			return
		if exploration_journal_open and journal_key.pressed and not journal_key.echo \
				and journal_code == KEY_TAB:
			_flip_journal_page()
			get_viewport().set_input_as_handled()
			return
		if journal_key.pressed and not journal_key.echo and journal_code == KEY_L:
			_set_exploration_journal_open(not exploration_journal_open)
			get_viewport().set_input_as_handled()
			return
		if journal_key.pressed and not journal_key.echo and journal_code == KEY_C:
			_call_companions()
			get_viewport().set_input_as_handled()
			return
		if journal_key.pressed and not journal_key.echo and journal_code == KEY_H:
			_call_horse()
			get_viewport().set_input_as_handled()
			return
		if journal_key.pressed and not journal_key.echo and journal_code == KEY_P:
			_cycle_story_hint()
			get_viewport().set_input_as_handled()
			return
	if exploration_journal_open:
		return
	if inventory_open:
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
	if credits_open:
		return
	if pressed_key == KEY_N:
		controls_open = not controls_open
		controls_panel.visible = controls_open
		get_viewport().set_input_as_handled()
	elif pressed_key == KEY_B and not map_open:
		mini_map_open = not mini_map_open
		mini_map.visible = mini_map_open
		get_viewport().set_input_as_handled()


func _handle_cancel() -> void:
	# Cierra primero el nivel visual actual. Solo cuando no queda ninguna ventana
	# abre el menú de pausa, como esperan los juegos convencionales.
	if story_dialogue_open:
		_set_story_dialogue_open(false)
	elif story_hint_expanded:
		_set_story_hint_expanded(false)
	elif lobby_open:
		_set_lobby_open(false)
	elif settings_open:
		_set_settings_open(false)
	elif inventory_open:
		_set_inventory_open(false)
	elif exploration_journal_open:
		_set_exploration_journal_open(false)
	elif map_open:
		map_open = false
		full_map.visible = false
		mini_map.visible = mini_map_open
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif credits_open:
		_set_credits_open(false)
	elif controls_open:
		controls_open = false
		controls_panel.visible = false
	elif pause_menu != null and pause_menu.visible:
		pause_menu.close_one_level()
	elif pause_menu != null:
		pause_menu.set_open(true)
		mini_map.visible = false


func _call_companions() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("call_companions_to_player"):
		return
	var notice := String(world.call("call_companions_to_player"))
	if notice != "":
		_on_player_action_feedback(notice)


func _call_horse() -> void:
	var world := get_parent()
	if world != null and world.has_method("call_horse_to_player") and bool(world.call("call_horse_to_player")):
		_on_player_action_feedback("🐎 Brisa viene hacia ti")
	else:
		_on_player_action_feedback("No puedes llamar al caballo ahora")


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
	if (settings_open or lobby_open or exploration_journal_open or inventory_open or story_dialogue_open or (pause_menu != null and pause_menu.visible)) and get_tree() != null:
		get_tree().paused = false


func is_credits_open() -> bool:
	return credits_open


func _process(delta: float) -> void:
	fps_refresh_elapsed += delta
	if fps_counter != null and fps_refresh_elapsed >= 0.20:
		fps_refresh_elapsed = 0.0
		fps_counter.text = str(Engine.get_frames_per_second())
	boss_banner_elapsed += delta
	if boss_banner_elapsed >= 0.25:
		boss_banner_elapsed = 0.0
		refresh_boss_banner()
		refresh_ally_strip()
	if exploration_notice_seconds > 0.0:
		exploration_notice_seconds = maxf(exploration_notice_seconds - delta, 0.0)
		if exploration_notice_seconds <= 0.0:
			_refresh_exploration_prompt()
	if action_feedback_seconds > 0.0:
		action_feedback_seconds = maxf(action_feedback_seconds - delta, 0.0)
		if action_feedback_seconds <= 0.0 and action_feedback_label != null:
			action_feedback_label.visible = false
	_update_arrow_marker()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		hint.text = "Esc abre el menú"
	else:
		hint.text = "Clic para volver a controlar la cámara"

	var equipped := player.get_equipped_item_name()
	var adventure_prompt := player.get_nearby_adventure_prompt()
	if adventure_action_hint != null:
		adventure_action_hint.text = adventure_prompt
		adventure_action_hint.visible = not adventure_prompt.is_empty() and not inventory_open and not exploration_journal_open
		if not adventure_prompt.is_empty() and exploration_notice_seconds <= 0.0 and exploration_prompt != null:
			exploration_prompt.visible = false
	if player.is_mounted():
		controls.text = "WASD / flechas · guiar   Mayús · galopar   E · explorar / desmontar\n1 Espada · 2 Hacha · 3 Arco · 4 Antorcha\nEn mano: %s   H · caballo   C · aliados   I · inventario\nM · mapa   L · 200 retos   Esc · menú" % equipped
		mount_hint.text = "E · Desmontar de %s" % player.current_mount.horse_name
		mount_hint.visible = true
	else:
		controls.text = "WASD / flechas · caminar   Espacio · saltar   Mayús · correr\n1 Espada · 2 Hacha · 3 Arco · 4 Antorcha\nEn mano: %s   Clic · tajo · mantener · giro   H · caballo   C · aliados\nE · interactuar   I · inventario   M · mapa   Esc · menú" % equipped
		var nearby_horse := player.get_nearby_mount()
		mount_hint.visible = nearby_horse != null
		if nearby_horse != null:
			mount_hint.text = "E · Montar a %s" % nearby_horse.horse_name


func _build_fps_counter() -> void:
	fps_counter = Label.new()
	fps_counter.name = "FPSCounter"
	fps_counter.z_index = 300
	fps_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_counter.offset_left = -84.0
	fps_counter.offset_top = 7.0
	fps_counter.offset_right = -12.0
	fps_counter.offset_bottom = 35.0
	fps_counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_counter.add_theme_font_size_override("font_size", 18)
	fps_counter.add_theme_color_override("font_color", Color.WHITE)
	fps_counter.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	fps_counter.add_theme_constant_override("outline_size", 5)
	fps_counter.text = str(Engine.get_frames_per_second())
	fps_counter.set_meta("displays_frames_per_second", true)
	add_child(fps_counter)


func _build_story_hud() -> void:
	story_hint_panel = PanelContainer.new()
	story_hint_panel.name = "PersistentStoryHint"
	story_hint_panel.z_index = 78
	story_hint_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Debajo del seguidor de misiones, no encima: antes ambos se dibujaban en
	# (-448, 218) y se tapaban el uno al otro.
	story_hint_panel.position = Vector2(-448.0, 430.0)
	story_hint_panel.size = Vector2(428.0, 132.0)
	story_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_hint_panel.visible = false
	story_hint_panel.add_theme_stylebox_override(
		"panel", UiTheme.panel(UiTheme.INK_SOFT, UiTheme.AMBER_DIM, UiTheme.RADIUS_CHIP, 12.0, 8.0)
	)
	add_child(story_hint_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	story_hint_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	story_hint_label = Label.new()
	story_hint_label.name = "StoryHintText"
	story_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_hint_label.add_theme_font_size_override("font_size", 16)
	story_hint_label.add_theme_color_override("font_color", Color(1.0, 0.89, 0.65))
	story_hint_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	story_hint_label.add_theme_constant_override("shadow_offset_x", 2)
	story_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	content.add_child(story_hint_label)
	player_health_bar = ProgressBar.new()
	player_health_bar.name = "PlayerHealth"
	player_health_bar.max_value = 100.0
	player_health_bar.value = 100.0
	player_health_bar.show_percentage = false
	player_health_bar.custom_minimum_size = Vector2(0.0, 9.0)
	player_health_bar.tooltip_text = "Vida"
	content.add_child(player_health_bar)

	_build_vitals_panel()
	_build_boss_banner()
	_build_ally_strip()
	_build_quest_tracker()

	story_dialogue_overlay = ColorRect.new()
	story_dialogue_overlay.name = "StoryDialogue"
	story_dialogue_overlay.z_index = 292
	story_dialogue_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_dialogue_overlay.color = Color(0.008, 0.012, 0.018, 0.76)
	story_dialogue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	story_dialogue_overlay.visible = false
	add_child(story_dialogue_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430.0, -235.0)
	panel.size = Vector2(860.0, 470.0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.INK, UiTheme.AMBER, 18))
	story_dialogue_overlay.add_child(panel)
	var dialogue_margin := MarginContainer.new()
	dialogue_margin.add_theme_constant_override("margin_left", 34)
	dialogue_margin.add_theme_constant_override("margin_top", 28)
	dialogue_margin.add_theme_constant_override("margin_right", 34)
	dialogue_margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(dialogue_margin)
	var dialogue_content := VBoxContainer.new()
	dialogue_content.add_theme_constant_override("separation", 15)
	dialogue_margin.add_child(dialogue_content)
	story_dialogue_title = Label.new()
	story_dialogue_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_dialogue_title.add_theme_font_size_override("font_size", 28)
	story_dialogue_title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.40))
	dialogue_content.add_child(story_dialogue_title)
	story_dialogue_body = RichTextLabel.new()
	story_dialogue_body.bbcode_enabled = true
	story_dialogue_body.fit_content = false
	story_dialogue_body.custom_minimum_size = Vector2(790.0, 300.0)
	story_dialogue_body.add_theme_font_size_override("normal_font_size", 18)
	story_dialogue_body.add_theme_color_override("default_color", Color(0.94, 0.91, 0.82))
	dialogue_content.add_child(story_dialogue_body)
	# Las respuestas. Van en su propia caja porque una conversación con opciones
	# y otra sin ellas usan el mismo panel: se enseña una u otra.
	story_dialogue_choices = VBoxContainer.new()
	story_dialogue_choices.name = "StoryDialogueChoices"
	story_dialogue_choices.add_theme_constant_override("separation", 6)
	story_dialogue_choices.visible = false
	dialogue_content.add_child(story_dialogue_choices)
	story_dialogue_close = Button.new()
	story_dialogue_close.text = "Continuar  ·  Esc"
	story_dialogue_close.custom_minimum_size = Vector2(0.0, 42.0)
	story_dialogue_close.pressed.connect(func() -> void: _set_story_dialogue_open(false))
	dialogue_content.add_child(story_dialogue_close)


func _on_story_objective_changed(objective: Dictionary) -> void:
	story_current_objective = objective.duplicate(true)
	_refresh_story_hint()


func _refresh_story_hint() -> void:
	## La pista ya no habla de las 200 zonas de exploración —eso es el diario—:
	## habla de LO QUE ESTÁS SIGUIENDO. Con P se rota entre la historia y cada
	## encargo aceptado, y cada ficha dice rumbo y distancia reales, porque en
	## una isla de 12 x 12 km "busca las marcas del Eco" no es una pista.
	if story_hint_label == null:
		return
	var cards := _hint_cards()
	if cards.is_empty():
		story_hint_label.text = "SIN RASTRO QUE SEGUIR\n\nHabla con los habitantes para\nque te encarguen algo."
		return
	var card: Dictionary = cards[posmod(story_hint_index, cards.size())]
	var lines := PackedStringArray()
	lines.append(String(card["kicker"]))
	lines.append("◆ %s" % String(card["title"]))
	lines.append("")
	lines.append(String(card["body"]))
	if not String(card.get("where", "")).is_empty():
		lines.append("")
		lines.append(String(card["where"]))
	var bearing := String(card.get("bearing", ""))
	if not bearing.is_empty():
		lines.append("")
		lines.append(bearing)
	if not String(card.get("tail", "")).is_empty():
		lines.append("")
		lines.append(String(card["tail"]))
	lines.append("")
	lines.append("P · %s" % ("siguiente pista (%d/%d)" % [
		posmod(story_hint_index, cards.size()) + 1, cards.size()] if cards.size() > 1 else "ocultar"))
	story_hint_label.text = "\n".join(lines)


func _hint_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var runtime := get_tree().root.find_child("RPGStoryRuntime", true, false)
	if runtime == null:
		return cards
	var hero := get_tree().root.find_child("Player", true, false) as Node3D
	var campaign = runtime.get("campaign")
	if campaign != null:
		for raw in (campaign.call("open_acts") as Array):
			var act: Dictionary = raw
			cards.append({
				"kicker": "HISTORIA",
				"title": "Acto %s · %s" % [String(act["numeral"]), String(act["title"])],
				"body": String(act["goal"]),
				"where": String(act["hint"]),
				"bearing": _bearing_line(hero, RPGCampaign.where_of(act)),
				"tail": "Te enseñará: %s." % String(act["teaches"]),
			})
	var quests = runtime.get("sidequests")
	if quests != null:
		for quest in RPGSideQuests.QUESTS:
			if not bool(quests.call("is_taken", quest)) or bool(quests.call("is_done", quest)):
				continue
			var have: int = quests.call("progress_of", quest)
			var need := int(quest["needed"])
			cards.append({
				"kicker": "ENCARGO",
				"title": String(quest["title"]),
				"body": String(quest["brief"]),
				"where": String(quest.get("where", "")),
				"bearing": _quest_bearing(hero, quest, quests),
				"tail": "Llevas %d de %d." % [mini(have, need), need],
			})
	return cards


func _quest_bearing(hero: Node3D, quest: Dictionary, quests: Node = null) -> String:
	## Para una cacería el rumbo apunta a la criatura viva más cercana QUE
	## CUENTE. Desde que cada cacería tiene comarca, apuntar a la más cercana a
	## secas mandaba al jugador a matar bichos que no suman: peor que no decir
	## nada. Si no queda ninguna a la vista, apunta a la comarca.
	if hero == null or int(quest["kind"]) != RPGSideQuests.Kind.HUNT:
		return ""
	var target := String(quest["target"])
	var best := INF
	var spot := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("rpg_enemy"):
		var creature := node as Node3D
		if creature == null or not String(creature.get("enemy_id")).begins_with(target):
			continue
		if bool(creature.get("dead")):
			continue
		var here := Vector2(creature.global_position.x, creature.global_position.z)
		if quests != null and not bool(quests.call("counts_here", quest, here)):
			continue
		var distance := here.distance_to(Vector2(hero.global_position.x, hero.global_position.z))
		if distance < best:
			best = distance
			spot = here
	if best == INF:
		if float(quest.get("zone", 0.0)) > 0.0:
			return _bearing_line(hero, quest.get("at", Vector2.ZERO))
		return ""
	return _bearing_line(hero, spot)


func _bearing_line(hero: Node3D, target) -> String:
	if hero == null or target == null:
		return ""
	var spot: Vector2 = target
	var here := Vector2(hero.global_position.x, hero.global_position.z)
	var delta := spot - here
	var distance := delta.length()
	if distance < 1.0:
		return "Estás encima."
	var compass := PackedStringArray(["N", "NE", "E", "SE", "S", "SO", "O", "NO"])
	# El norte del mundo es -Z; el ángulo se mide desde ahí en sentido horario.
	var angle := rad_to_deg(atan2(delta.x, -delta.y))
	var facing: String = compass[int(round(posmod(angle, 360.0) / 45.0)) % 8]
	if distance >= 1000.0:
		return "Rumbo %s · a %.1f km" % [facing, distance / 1000.0]
	return "Rumbo %s · a %d m" % [facing, roundi(distance)]


func _cycle_story_hint() -> void:
	## P abre la primera ficha, luego pasa a la siguiente, y al llegar al final
	## se cierra. Un solo botón para "¿dónde voy?" y para "¿y lo otro?".
	var total := _hint_cards().size()
	if not story_hint_expanded:
		story_hint_index = 0
		_set_story_hint_expanded(true)
		return
	story_hint_index += 1
	if total <= 0 or story_hint_index >= total:
		_set_story_hint_expanded(false)
		return
	_refresh_story_hint()


func _set_story_hint_expanded(open: bool) -> void:
	story_hint_expanded = open
	if story_hint_panel != null:
		story_hint_panel.visible = open
		story_hint_panel.position.y = 430.0
		story_hint_panel.size.y = 306.0
		story_hint_panel.set_meta("expanded", open)
	_refresh_story_hint()


func _on_story_dialogue_requested(speaker: String, role: String, title: String, body: String) -> void:
	_show_dialogue(speaker, role, title, body, [])


func _on_dialogue_with_choices(speaker: String, role: String, title: String, body: String, choices: Array) -> void:
	_show_dialogue(speaker, role, title, body, choices)


func _show_dialogue(speaker: String, role: String, title: String, body: String, choices: Array) -> void:
	story_dialogue_title.text = "%s · %s\n%s" % [speaker, role, title]
	story_dialogue_body.text = body
	for old in story_dialogue_choices.get_children():
		old.queue_free()
	var offered := not choices.is_empty()
	story_dialogue_choices.visible = offered
	story_dialogue_close.visible = not offered
	if offered:
		var index := 0
		for raw in choices:
			var choice: Dictionary = raw
			var button := Button.new()
			# El número delante permite contestar con el teclado, que es como se
			# contesta en un juego con las manos ocupadas.
			button.text = "%d.  %s" % [index + 1, String(choice["line"])]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0.0, 38.0)
			button.add_theme_font_size_override("font_size", 16)
			button.tooltip_text = _tone_hint(String(choice["tone"]))
			var picked := index
			button.pressed.connect(func() -> void: _answer_dialogue(picked))
			story_dialogue_choices.add_child(button)
			index += 1
		_pending_choices = choices.duplicate(true)
	else:
		_pending_choices.clear()
	_set_story_dialogue_open(true)


func _tone_hint(tone: String) -> String:
	match tone:
		"humilde":
			return "Piden menos y te lo cuentan todo. Pagan menos."
		"altivo":
			return "Piden más y pagan mucho más. No te dirán dónde buscar."
		_:
			return "El trato tal cual."


func _answer_dialogue(index: int) -> void:
	var runtime := get_tree().root.find_child("RPGStoryRuntime", true, false)
	if runtime != null and runtime.has_method("answer_dialogue") and index < _pending_choices.size():
		runtime.call("answer_dialogue", _pending_choices[index])
	_pending_choices.clear()
	_set_story_dialogue_open(false)


func _set_story_dialogue_open(open: bool) -> void:
	story_dialogue_open = open
	if story_dialogue_overlay != null:
		story_dialogue_overlay.visible = open
	if open:
		mini_map.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		mini_map.visible = mini_map_open and not map_open
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_quest_tracker() -> void:
	## Seguidor de misiones, a la derecha y bajo el minimapa. La historia y los
	## encargos van en BLOQUES SEPARADOS: son dos cosas distintas y el jugador
	## decide a cuál atender. Antes todo iba junto en una línea de arriba con las
	## 200 zonas de exploración de por medio, y no se entendía qué contaba qué.
	quest_tracker_panel = PanelContainer.new()
	quest_tracker_panel.name = "QuestTracker"
	quest_tracker_panel.z_index = 74
	quest_tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_tracker_panel.position = Vector2(-336.0, 208.0)
	quest_tracker_panel.custom_minimum_size = Vector2(316.0, 0.0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.032, 0.042, 0.86)
	frame.set_corner_radius_all(10)
	frame.set_border_width_all(1)
	frame.border_color = Color(0.62, 0.48, 0.26, 0.50)
	frame.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	frame.shadow_size = 6
	frame.set_content_margin_all(13)
	quest_tracker_panel.add_theme_stylebox_override("panel", frame)
	add_child(quest_tracker_panel)
	quest_tracker_rows = VBoxContainer.new()
	quest_tracker_rows.add_theme_constant_override("separation", 3)
	quest_tracker_panel.add_child(quest_tracker_rows)


## Estandarte de jefe. Antes entrabas a una arena y no sabías ni en qué fase
## iba, ni qué mecánica te exigía, ni que el sitio iba a pelear contigo: te
## enterabas cuando ya te había mordido. Las tres cosas caben en cuatro líneas.
const BOSS_BANNER_REACH := 62.0
const DEMAND_NAMES := ["escudo", "arco", "carga", "esquiva", "las cuatro"]


func _build_boss_banner() -> void:
	boss_banner = PanelContainer.new()
	boss_banner.name = "BossBanner"
	boss_banner.z_index = 78
	boss_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Debajo de la línea de avisos (y=90): puesto a la misma altura, el aviso
	# «Acto III · La corona de invierno · Coloso de Escarcha» quedaba escrito
	# por detrás del estandarte y se leían los dos a la vez.
	boss_banner.position = Vector2(-232.0, 124.0)
	boss_banner.custom_minimum_size = Vector2(464.0, 0.0)
	boss_banner.visible = false
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.022, 0.026, 0.88)
	frame.set_corner_radius_all(12)
	frame.set_border_width_all(1)
	frame.border_color = Color(0.78, 0.28, 0.22, 0.62)
	frame.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	frame.shadow_size = 7
	frame.set_content_margin_all(12)
	boss_banner.add_theme_stylebox_override("panel", frame)
	add_child(boss_banner)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	boss_banner.add_child(rows)
	boss_banner_name = Label.new()
	boss_banner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_banner_name.add_theme_font_size_override("font_size", 19)
	boss_banner_name.add_theme_color_override("font_color", Color(0.97, 0.86, 0.72))
	rows.add_child(boss_banner_name)
	boss_banner_bar = UiVitalBar.new()
	boss_banner_bar.custom_minimum_size = Vector2(0.0, 17.0)
	boss_banner_bar.bright = Color(0.90, 0.30, 0.24)
	boss_banner_bar.deep = Color(0.30, 0.05, 0.06)
	boss_banner_bar.icon = "heart"
	boss_banner_bar.warn_below = 0.34
	rows.add_child(boss_banner_bar)
	boss_banner_demand = Label.new()
	boss_banner_demand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_banner_demand.add_theme_font_size_override("font_size", 14)
	boss_banner_demand.add_theme_color_override("font_color", Color(0.92, 0.78, 0.44))
	rows.add_child(boss_banner_demand)
	boss_banner_site = Label.new()
	boss_banner_site.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_banner_site.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_banner_site.add_theme_font_size_override("font_size", 13)
	boss_banner_site.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	rows.add_child(boss_banner_site)


func refresh_boss_banner() -> void:
	if boss_banner == null:
		return
	var hero := get_tree().get_first_node_in_group("local_player") as Node3D
	var near: Node = null
	var best := BOSS_BANNER_REACH
	if hero != null:
		for node in get_tree().get_nodes_in_group("rpg_boss"):
			var boss := node as Node3D
			if boss == null or bool(boss.get("dead")) or bool(boss.get("sealed")):
				continue
			var span := hero.global_position.distance_to(boss.global_position)
			if span < best:
				best = span
				near = boss
	for node in get_tree().get_nodes_in_group("rpg_boss"):
		if node != near and node.has_method("set_banner_shown"):
			node.call("set_banner_shown", false)
	if near == null:
		boss_banner.visible = false
		return
	boss_banner.visible = true
	if near.has_method("set_banner_shown"):
		near.call("set_banner_shown", true)
	var phases := 3
	boss_banner_name.text = "%s · fase %d de %d" % [
		String(near.get("display_name")).to_upper(), int(near.get("phase")), phases]
	boss_banner_bar.set_values(float(near.get("health")), float(near.get("max_health")))
	var demand := int(near.get("demand"))
	var line := "Exige: %s" % DEMAND_NAMES[clampi(demand, 0, DEMAND_NAMES.size() - 1)]
	var ward := int(near.get("_ward"))
	if ward > 0:
		# Rombos llenos: lo que le queda de coraza. Es la única lectura de si
		# estás resolviendo la mecánica o pegando en balde.
		line += "   coraza %s" % "◆".repeat(ward)
	elif int(near.get("stance")) == RPGBoss.Stance.OPEN:
		line += "   ¡EXPUESTO!"
	boss_banner_demand.text = line
	var site: Node = near.get("hazard")
	boss_banner_site.text = String(site.call("_rule")) if site != null else ""


## Tira de aliados, encima de las barras del héroe. Sólo se ve si has ganado a
## alguien, así que la mayor parte de la partida no ocupa nada.
func _build_ally_strip() -> void:
	ally_strip = PanelContainer.new()
	ally_strip.name = "AllyStrip"
	ally_strip.z_index = 74
	ally_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ally_strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ally_strip.position = Vector2(20.0, -224.0)
	ally_strip.custom_minimum_size = Vector2(292.0, 0.0)
	ally_strip.visible = false
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.032, 0.042, 0.82)
	frame.set_corner_radius_all(10)
	frame.set_border_width_all(1)
	frame.border_color = Color(0.40, 0.56, 0.72, 0.46)
	frame.set_content_margin_all(11)
	ally_strip.add_theme_stylebox_override("panel", frame)
	add_child(ally_strip)
	ally_strip_rows = VBoxContainer.new()
	ally_strip_rows.add_theme_constant_override("separation", 3)
	ally_strip.add_child(ally_strip_rows)


func refresh_ally_strip() -> void:
	if ally_strip == null:
		return
	var runtime := get_tree().get_first_node_in_group("rpg_story_runtime")
	if runtime == null or not runtime.has_method("companion_roster"):
		ally_strip.visible = false
		return
	var roster: Array = runtime.call("companion_roster")
	if roster.is_empty():
		ally_strip.visible = false
		return
	ally_strip.visible = true
	for child in ally_strip_rows.get_children():
		child.queue_free()
	for mate in roster:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		var state := String(mate.call("status_line"))
		var mark := "◆" if not bool(mate.get("downed")) else "◇"
		var vigour := ""
		if bool(mate.call("is_here")) and not bool(mate.get("downed")):
			var full := maxi(int(mate.get("max_health")), 1)
			var filled := int(round(8.0 * float(mate.get("health")) / float(full)))
			vigour = "  %s%s" % ["█".repeat(maxi(filled, 0)), "░".repeat(maxi(8 - filled, 0))]
		row.text = "%s %s%s   %s" % [mark, String(mate.get("display_name")).to_upper(), vigour, state]
		var tone := Color(0.86, 0.90, 0.96)
		if bool(mate.get("downed")):
			tone = Color(0.82, 0.44, 0.40)
		elif bool(mate.call("is_available")):
			tone = Color(0.66, 0.88, 0.68)
		row.add_theme_color_override("font_color", tone)
		ally_strip_rows.add_child(row)


func refresh_quest_tracker() -> void:
	if quest_tracker_rows == null:
		return
	for child in quest_tracker_rows.get_children():
		child.queue_free()
	var runtime := get_tree().root.find_child("RPGStoryRuntime", true, false)
	if runtime == null:
		return
	var campaign = runtime.get("campaign")
	var quests = runtime.get("sidequests")

	if campaign != null:
		var open: Array = campaign.call("open_acts")
		_tracker_heading("HISTORIA", Color(0.98, 0.78, 0.42))
		if open.is_empty():
			_tracker_line("Aeloria ha recuperado su voz.", Color(0.86, 0.84, 0.78), "")
		else:
			# Con tres caminos a la vez hay que enseñar los tres: elegir es
			# parte de la aventura y no se puede elegir lo que no se ve.
			for raw in open:
				var act: Dictionary = raw
				_tracker_line("%s · %s" % [String(act["numeral"]), String(act["title"])],
					Color(1.0, 0.93, 0.80), "", 13)
				if open.size() == 1:
					_tracker_line(String(act["goal"]), Color(0.80, 0.77, 0.70), "›")
			if open.size() > 1:
				_tracker_line("Elige por dónde. Con P los ves todos.",
					Color(0.74, 0.71, 0.66), "", 11)
			var progress: Dictionary = campaign.call("progress")
			_tracker_line("Nombres recuperados", Color(0.70, 0.66, 0.60), "",
				11, "%d/%d" % [int(progress["relics"]), int(progress["total"])])

	if quests != null:
		var taken := _tracked_quests(quests)
		if not taken.is_empty():
			_tracker_gap()
			_tracker_heading("ENCARGOS", Color(0.62, 0.86, 0.98))
			for quest in taken:
				var have: int = quests.call("progress_of", quest)
				var need := int(quest["needed"])
				_tracker_line(String(quest["title"]), Color(0.88, 0.92, 0.96), "›",
					12, "%d/%d" % [mini(have, need), need])
		var done := int(quests.call("completed_count"))
		if taken.is_empty() and done > 0:
			_tracker_gap()
			_tracker_heading("ENCARGOS", Color(0.62, 0.86, 0.98))
			_tracker_line("Habla con los habitantes", Color(0.74, 0.78, 0.82), "›",
				12, "%d/%d" % [done, RPGSideQuests.QUESTS.size()])


func _tracked_quests(quests: Node) -> Array:
	## Sólo los aceptados y sin entregar, y como mucho tres: un seguidor con
	## dieciocho líneas deja de ser un seguidor.
	var out: Array = []
	for quest in RPGSideQuests.QUESTS:
		if bool(quests.call("is_taken", quest)) and not bool(quests.call("is_done", quest)):
			out.append(quest)
		if out.size() >= 3:
			break
	return out


func _tracker_heading(text: String, tint: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", tint)
	quest_tracker_rows.add_child(label)
	var rule := ColorRect.new()
	rule.color = Color(tint, 0.28)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	quest_tracker_rows.add_child(rule)


func _tracker_gap() -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 8.0)
	quest_tracker_rows.add_child(gap)


func _tracker_line(text: String, tint: Color, bullet: String, font_size := 12, tail := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	quest_tracker_rows.add_child(row)
	if not bullet.is_empty():
		var mark := Label.new()
		mark.text = bullet
		mark.add_theme_font_size_override("font_size", font_size)
		mark.add_theme_color_override("font_color", Color(tint, 0.7))
		row.add_child(mark)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", font_size)
	body.add_theme_color_override("font_color", tint)
	row.add_child(body)
	if not tail.is_empty():
		var count := Label.new()
		count.text = tail
		count.add_theme_font_size_override("font_size", font_size)
		count.add_theme_color_override("font_color", Color(tint, 0.82))
		row.add_child(count)


func _build_vitals_panel() -> void:
	## Vida y vigor, abajo a la izquierda. La vida ya se pintaba, pero en una
	## tira de nueve píxeles metida dentro del panel de pistas: no se leía y no
	## había ningún sitio donde ver el vigor, que es lo que limita la fuerza
	## especial. Las barras se dibujan a mano (UiVitalBar) porque un ProgressBar
	## no da bisel, degradado, marcas de segmento ni estela de daño.
	vitals_panel = PanelContainer.new()
	vitals_panel.name = "Vitals"
	vitals_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals_panel.position = Vector2(20.0, -118.0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.045, 0.04, 0.05, 0.72)
	frame.set_corner_radius_all(9)
	frame.set_border_width_all(1)
	frame.border_color = Color(0.62, 0.48, 0.26, 0.55)
	frame.set_content_margin_all(11)
	frame.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	frame.shadow_size = 7
	vitals_panel.add_theme_stylebox_override("panel", frame)
	add_child(vitals_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	vitals_panel.add_child(rows)

	vitals_health_bar = UiVitalBar.new()
	vitals_health_bar.icon = "heart"
	vitals_health_bar.bright = Color(0.97, 0.33, 0.28)
	vitals_health_bar.deep = Color(0.38, 0.06, 0.08)
	rows.add_child(vitals_health_bar)

	vitals_stamina_bar = UiVitalBar.new()
	vitals_stamina_bar.icon = "drop"
	vitals_stamina_bar.bright = Color(0.32, 0.68, 0.99)
	vitals_stamina_bar.deep = Color(0.06, 0.20, 0.44)
	vitals_stamina_bar.warn_below = 0.18
	rows.add_child(vitals_stamina_bar)


func _on_player_stamina_changed(current: float, maximum: float) -> void:
	if vitals_stamina_bar != null:
		vitals_stamina_bar.set_values(current, maximum)


func _on_player_health_changed(current: int, maximum: int) -> void:
	if player_health_bar == null:
		return
	player_health_bar.max_value = maximum
	player_health_bar.value = current
	player_health_bar.tooltip_text = "Vida · %d/%d" % [current, maximum]
	if vitals_health_bar != null:
		vitals_health_bar.set_values(float(current), float(maximum))


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
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.INK, UiTheme.AMBER_DIM, 18))
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
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.INK, UiTheme.AMBER_DIM, 18))
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
	# Las 200 zonas son EXPLORACIÓN, no la historia. Tenerlas fijas arriba junto
	# al acto mezclaba tres progresiones distintas en la misma línea y no se
	# entendía nada: ahora sólo aparecen con el diario, que es su sitio.
	exploration_progress_panel.visible = false
	exploration_progress_panel.position = Vector2(-190.0, 10.0)
	exploration_progress_panel.size = Vector2(380.0, 48.0)
	exploration_progress_panel.add_theme_stylebox_override(
		"panel", UiTheme.panel(UiTheme.INK_GLASS, UiTheme.AMBER_DIM, UiTheme.RADIUS_CHIP, 11.0, 7.0)
	)
	add_child(exploration_progress_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 5)
	exploration_progress_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	exploration_progress_label = Label.new()
	exploration_progress_label.name = "ExplorationProgressLabel"
	exploration_progress_label.text = "AVENTURA DE LA ISLA · 0 / 200 · L: diario · P: pista"
	exploration_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exploration_progress_label.add_theme_font_size_override("font_size", 12)
	exploration_progress_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	content.add_child(exploration_progress_label)
	# Segunda línea, pequeña: el acto en curso y lo secundario cumplido. La barra
	# sólo decía cuántas zonas llevabas descubiertas, así que la campaña —que es
	# el hilo de la aventura— no se veía por ninguna parte.
	exploration_progress_bar = ProgressBar.new()
	exploration_progress_bar.name = "ExplorationProgressBar"
	exploration_progress_bar.max_value = 200.0
	exploration_progress_bar.value = 0.0
	exploration_progress_bar.show_percentage = false
	exploration_progress_bar.custom_minimum_size = Vector2(350.0, 8.0)
	UiTheme.style_progress(exploration_progress_bar, UiTheme.SUCCESS)
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
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.INK, UiTheme.AMBER, 18))
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
	journal_title = title
	title.text = "DIARIO DE AVENTURA · 200 RETOS"
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
	journal_help = help
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
	# La crónica ocupa el mismo hueco que la lista de zonas: son dos páginas del
	# mismo diario, no dos ventanas. Las 200 zonas y la historia contaban cosas
	# distintas y juntarlas en una sola lista ya fue un error una vez.
	chronicle_view = RichTextLabel.new()
	chronicle_view.name = "Chronicle"
	chronicle_view.bbcode_enabled = true
	chronicle_view.scroll_active = true
	chronicle_view.custom_minimum_size = Vector2(870.0, 500.0)
	chronicle_view.add_theme_font_size_override("normal_font_size", 16)
	chronicle_view.add_theme_color_override("default_color", Color(0.90, 0.88, 0.80))
	chronicle_view.visible = false
	content.add_child(chronicle_view)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	var flip := Button.new()
	flip.text = "Crónica / Retos · Tab"
	flip.pressed.connect(_flip_journal_page)
	buttons.add_child(flip)
	var clear_target := Button.new()
	clear_target.text = "Quitar marcador"
	clear_target.pressed.connect(_clear_exploration_target)
	buttons.add_child(clear_target)
	var close_button := Button.new()
	close_button.text = "Cerrar · L"
	close_button.pressed.connect(func() -> void: _set_exploration_journal_open(false))
	buttons.add_child(close_button)


func _flip_journal_page() -> void:
	journal_page = 1 - journal_page
	_apply_journal_page()


func _apply_journal_page() -> void:
	var chronicle := journal_page == 0
	if chronicle_view != null:
		chronicle_view.visible = chronicle
	if exploration_journal_list != null:
		exploration_journal_list.visible = not chronicle
	if exploration_journal_summary != null:
		exploration_journal_summary.visible = not chronicle
	if journal_help != null:
		journal_help.visible = not chronicle
	if journal_title != null:
		journal_title.text = "CRÓNICA DE LA ISLA" if chronicle else "DIARIO DE AVENTURA · 200 RETOS"
	if chronicle:
		var runtime := get_tree().get_first_node_in_group("rpg_story_runtime")
		if runtime != null and runtime.has_method("chronicle"):
			chronicle_view.text = String(runtime.call("chronicle"))
	else:
		_rebuild_exploration_journal()


func _set_exploration_journal_open(open: bool) -> void:
	exploration_journal_open = open
	_sync_exploration_panel()
	exploration_journal_overlay.visible = open
	if open:
		map_open = false
		credits_open = false
		controls_open = false
		full_map.visible = false
		credits_overlay.visible = false
		controls_panel.visible = false
		mini_map.visible = false
		_apply_journal_page()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		mini_map.visible = mini_map_open and not map_open
		controls_panel.visible = controls_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED


func is_exploration_journal_open() -> bool:
	return exploration_journal_open


func _sync_exploration_panel() -> void:
	if exploration_progress_panel != null:
		exploration_progress_panel.visible = exploration_journal_open


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
		exploration_journal_list.add_item("%s  %s  ·  %s  ·  %s" % [prefix, String(zone.name), String(zone.type).capitalize(), String(zone.biome).capitalize()])
		var index := exploration_journal_list.item_count - 1
		exploration_journal_list.set_item_metadata(index, String(zone.id))
		exploration_journal_list.set_item_tooltip(index, String(zone.description))
		exploration_journal_list.set_item_custom_fg_color(
			index,
			Color(0.53, 0.88, 0.52) if completed else Color(0.91, 0.84, 0.66)
		)
	var completed_count := int(exploration.call("get_completed_count"))
	var total := int(exploration.call("get_zone_count"))
	exploration_journal_summary.text = "%d de %d retos completados · %.1f%%" % [
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
		exploration_progress_label.text = "AVENTURA DE LA ISLA · %d / %d · %.1f%% · L: diario · P: pista" % [
			completed,
			total,
			ratio * 100.0,
		]
	if exploration_journal_open:
		_rebuild_exploration_journal()
	_sync_exploration_panel()


func refresh_campaign_bar() -> void:
	## Compatibilidad: quien avisaba a la barra de arriba ahora refresca el
	## seguidor de la derecha, que es donde vive esa información.
	refresh_quest_tracker()
	if true:
		return
	## La llaman el guion RPG al cambiar de acto y al cerrar un encargo. Se
	## recalcula entera en vez de ir sumando: así lo que se lee sale siempre del
	## estado real y no de una cuenta que pudiera desincronizarse.
	if campaign_progress_label == null:
		return
	var runtime := get_tree().root.find_child("RPGStoryRuntime", true, false)
	if runtime == null:
		return
	var campaign = runtime.get("campaign")
	var quests = runtime.get("sidequests")
	if campaign == null:
		return
	var progress: Dictionary = campaign.call("progress")
	var done := 0
	var total := 0
	if quests != null:
		done = int(quests.call("completed_count"))
		total = int(RPGSideQuests.QUESTS.size())
	var taken := 0 if quests == null else int(quests.call("taken_count"))
	var pending := "" if taken <= 0 else " · %d en curso" % taken
	campaign_progress_label.text = "◆ %s · reliquias %d/%d · encargos %d/%d%s" % [
		String(campaign.call("headline")),
		int(progress["relics"]), int(progress["total"]),
		done, total, pending,
	]


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
	_sync_exploration_panel()


func _refresh_exploration_prompt() -> void:
	if exploration_prompt == null:
		return
	if exploration_nearby_zone.is_empty():
		exploration_prompt.visible = false
		return
	var objective_hint := String(exploration_nearby_zone.get("objective_hint", "E · registrar el lugar"))
	exploration_prompt.text = "%s · %s" % [objective_hint, String(exploration_nearby_zone.name)]
	exploration_prompt.visible = true


func _build_quickbar() -> void:
	quickbar_panel = PanelContainer.new()
	quickbar_panel.name = "AdventureQuickbar"
	quickbar_panel.z_index = 72
	quickbar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	quickbar_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quickbar_panel.position = Vector2(-344.0, -70.0)
	quickbar_panel.size = Vector2(324.0, 52.0)
	quickbar_panel.add_theme_stylebox_override(
		"panel", UiTheme.panel(UiTheme.INK_GLASS, UiTheme.AMBER_DIM, UiTheme.RADIUS_PANEL, 8.0, 5.0)
	)
	add_child(quickbar_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	quickbar_panel.add_child(row)
	for slot in range(1, 5):
		var button := Button.new()
		button.name = "QuickSlot%d" % slot
		button.custom_minimum_size = Vector2(42.0, 42.0)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 27)
		button.add_theme_font_size_override("font_size", 11)
		UiTheme.style_button(button)
		button.pressed.connect(_on_quickslot_button_pressed.bind(slot))
		row.add_child(button)
		quickbar_buttons.append(button)
	arrow_counter = Label.new()
	arrow_counter.custom_minimum_size = Vector2(40.0, 40.0)
	arrow_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_counter.add_theme_font_size_override("font_size", 10)
	arrow_counter.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	row.add_child(arrow_counter)
	horse_call_button = Button.new()
	horse_call_button.name = "CallHorseButton"
	horse_call_button.text = "H\n🐎"
	horse_call_button.tooltip_text = "Llamar a Brisa"
	horse_call_button.custom_minimum_size = Vector2(42.0, 42.0)
	horse_call_button.add_theme_font_size_override("font_size", 11)
	UiTheme.style_button(horse_call_button, UiTheme.AMBER)
	horse_call_button.pressed.connect(_call_horse)
	row.add_child(horse_call_button)

	bow_power_bar = ProgressBar.new()
	bow_power_bar.name = "BowPower"
	bow_power_bar.z_index = 76
	bow_power_bar.visible = false
	bow_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bow_power_bar.set_anchors_preset(Control.PRESET_CENTER)
	bow_power_bar.position = Vector2(34.0, 27.0)
	bow_power_bar.size = Vector2(180.0, 12.0)
	bow_power_bar.max_value = 1.0
	bow_power_bar.show_percentage = false
	UiTheme.style_progress(bow_power_bar, UiTheme.AMBER)
	add_child(bow_power_bar)

	adventure_action_hint = Label.new()
	adventure_action_hint.name = "AdventureActionHint"
	adventure_action_hint.z_index = 76
	adventure_action_hint.visible = false
	adventure_action_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	adventure_action_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	adventure_action_hint.position = Vector2(-350.0, -128.0)
	adventure_action_hint.size = Vector2(700.0, 34.0)
	adventure_action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adventure_action_hint.add_theme_font_size_override("font_size", 20)
	adventure_action_hint.add_theme_color_override("font_color", Color(1.0, 0.82, 0.40))
	adventure_action_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	adventure_action_hint.add_theme_constant_override("shadow_offset_x", 2)
	adventure_action_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(adventure_action_hint)

	action_feedback_label = Label.new()
	action_feedback_label.name = "ActionFeedback"
	action_feedback_label.z_index = 78
	action_feedback_label.visible = false
	action_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_feedback_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	action_feedback_label.position = Vector2(-360.0, 90.0)
	action_feedback_label.size = Vector2(720.0, 42.0)
	action_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_feedback_label.add_theme_font_size_override("font_size", 22)
	action_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	action_feedback_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.98))
	action_feedback_label.add_theme_constant_override("shadow_offset_x", 2)
	action_feedback_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(action_feedback_label)
	_refresh_quickbar()


func _build_inventory_overlay() -> void:
	inventory_overlay = ColorRect.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.z_index = 285
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.color = Color(0.018, 0.024, 0.019, 0.95)
	inventory_overlay.visible = false
	add_child(inventory_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-450.0, -330.0)
	panel.size = Vector2(900.0, 660.0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.INK, UiTheme.AMBER, 18))
	inventory_overlay.add_child(panel)
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
	title.text = "INVENTARIO DE AVENTURA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46))
	content.add_child(title)
	inventory_summary = Label.new()
	inventory_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_summary.add_theme_font_size_override("font_size", 16)
	inventory_summary.add_theme_color_override("font_color", Color(0.88, 0.84, 0.67))
	content.add_child(inventory_summary)
	var help := Label.new()
	help.text = "Pulsa una casilla de arma o escudo para equiparla · la cifra indica la cantidad · I cerrar"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.60))
	content.add_child(help)
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.name = "InventoryScroll"
	inventory_scroll.custom_minimum_size = Vector2(840.0, 505.0)
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(inventory_scroll)
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryGrid"
	inventory_grid.columns = 7
	inventory_grid.add_theme_constant_override("h_separation", 9)
	inventory_grid.add_theme_constant_override("v_separation", 9)
	inventory_scroll.add_child(inventory_grid)
	var close_button := Button.new()
	close_button.text = "Cerrar inventario · I"
	close_button.pressed.connect(func() -> void: _set_inventory_open(false))
	content.add_child(close_button)


func _set_inventory_open(open: bool) -> void:
	inventory_open = open
	inventory_overlay.visible = open
	if open:
		map_open = false
		credits_open = false
		controls_open = false
		exploration_journal_open = false
		full_map.visible = false
		credits_overlay.visible = false
		controls_panel.visible = false
		exploration_journal_overlay.visible = false
		mini_map.visible = false
		_rebuild_inventory()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		mini_map.visible = mini_map_open and not map_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED


func is_inventory_open() -> bool:
	return inventory_open


func _rebuild_inventory() -> void:
	if inventory_grid == null:
		return
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	var entries: Array = inventory_manager.call("get_inventory_entries") if inventory_manager != null else []
	var total_objects := 0
	for entry_value in entries:
		var entry := entry_value as Dictionary
		var amount := int(entry.get("amount", 0))
		total_objects += amount
		var equipped := bool(entry.get("equipped", false))
		var display_name := String(entry.get("display_name", entry.id))
		var icon: Texture2D
		var icon_path := String(entry.get("icon_path", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon = load(icon_path) as Texture2D
		var cell := Button.new()
		cell.name = "Item_%s" % String(entry.id).validate_node_name()
		cell.custom_minimum_size = Vector2(111.0, 108.0)
		cell.text = display_name if icon == null else ""
		cell.icon = icon
		cell.expand_icon = true
		cell.add_theme_constant_override("icon_max_width", 74)
		cell.tooltip_text = "%s · %s · cantidad %d%s" % [
			display_name,
			String(entry.get("category", "objeto")).capitalize(),
			amount,
			" · EQUIPADO" if equipped else "",
		]
		cell.clip_text = true
		cell.add_theme_font_size_override("font_size", 12)
		# El objeto equipado se distingue por el acento del borde, no por un
		# grosor distinto: mantiene todas las celdas de la rejilla alineadas.
		UiTheme.style_button(cell, UiTheme.AMBER if equipped else UiTheme.MUTED)
		if equipped:
			cell.add_theme_stylebox_override("normal", UiTheme.chip(Color(0.19, 0.15, 0.075, 0.96), UiTheme.AMBER))
		cell.pressed.connect(_on_inventory_item_pressed.bind(String(entry.id)))
		inventory_grid.add_child(cell)
		var count_badge := Label.new()
		count_badge.name = "Count"
		count_badge.text = "×%d" % amount
		count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_badge.position = Vector2(-42.0, -26.0)
		count_badge.size = Vector2(38.0, 22.0)
		count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_badge.add_theme_font_size_override("font_size", 14)
		count_badge.add_theme_color_override("font_color", Color(1.0, 0.91, 0.57))
		count_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
		count_badge.add_theme_constant_override("shadow_offset_x", 2)
		count_badge.add_theme_constant_override("shadow_offset_y", 2)
		cell.add_child(count_badge)
	inventory_summary.text = "%d tipos · %d objetos · %d flechas" % [entries.size(), total_objects, _inventory_arrow_count()]


func _on_inventory_item_pressed(item_id: String) -> void:
	if inventory_manager != null and bool(inventory_manager.call("equip_item", item_id)):
		var definition := inventory_manager.call("get_item_definition", item_id) as Dictionary
		_on_player_action_feedback("Equipado: %s" % String(definition.get("display_name", item_id)))
		_rebuild_inventory()


func _on_inventory_changed(_entries: Array) -> void:
	_refresh_quickbar()
	if inventory_open:
		_rebuild_inventory()


func _on_inventory_equipment_changed(_category: String, _item_id: String) -> void:
	_refresh_quickbar()


func _on_player_quickslot_changed(_slot: int, _item_name: String) -> void:
	_refresh_quickbar()


func _refresh_quickbar() -> void:
	if quickbar_buttons.is_empty():
		return
	var fallback_icons := PackedStringArray(["⚔", "🪓", "🏹", "🔥"])
	for index in 4:
		var item_id := String(inventory_manager.call("get_quick_slot_item", index + 1)) if inventory_manager != null else ""
		var display_name: String = ["Espada", "Hacha", "Arco", "Antorcha"][index]
		var icon: Texture2D
		if not item_id.is_empty():
			var definition := inventory_manager.call("get_item_definition", item_id) as Dictionary
			display_name = String(definition.get("display_name", item_id))
			var icon_path := String(definition.get("icon_path", ""))
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon = load(icon_path) as Texture2D
		quickbar_buttons[index].icon = icon
		quickbar_buttons[index].text = str(index + 1) if icon != null else "%d\n%s" % [index + 1, fallback_icons[index]]
		quickbar_buttons[index].tooltip_text = "%d · %s" % [index + 1, display_name]
		# El hueco activo se marca con el acento del propio tema en vez de
		# tintar el botón entero, que apagaba el icono del objeto.
		var active := player != null and player.equipped_slot == index + 1
		var stowed := active and player != null and player.is_weapon_on_back()
		quickbar_buttons[index].modulate = Color.WHITE
		if active:
			var accent := UiTheme.FROST if stowed else UiTheme.AMBER
			quickbar_buttons[index].add_theme_stylebox_override(
				"normal", UiTheme.chip(Color(0.17, 0.21, 0.26, 0.94), accent)
			)
			quickbar_buttons[index].add_theme_color_override("font_color", accent)
		else:
			UiTheme.style_button(quickbar_buttons[index])
	if arrow_counter != null:
		arrow_counter.text = "🏹\n×%d" % _inventory_arrow_count()


func _inventory_arrow_count() -> int:
	return int(inventory_manager.call("get_arrow_count")) if inventory_manager != null else 0


func _on_quickslot_button_pressed(slot: int) -> void:
	player.equip_item(slot)
	_refresh_quickbar()


func _on_player_action_feedback(message: String) -> void:
	action_feedback_seconds = 3.2
	if action_feedback_label != null:
		action_feedback_label.text = message
		action_feedback_label.visible = true
	_refresh_quickbar()


func _update_arrow_marker() -> void:
	## Marca de impacto del arco. La retícula del centro dice hacia dónde miras,
	## no dónde cae la flecha: con la gravedad encima podían diferir más de cien
	## metros. Esta marca se coloca en el punto donde la flecha se va a clavar de
	## verdad, así que apuntar deja de ser adivinar.
	var crosshair := get_node_or_null("Crosshair") as Label
	if not player.is_drawing_bow:
		if arrow_impact_marker != null:
			arrow_impact_marker.visible = false
		if crosshair != null:
			crosshair.visible = true
		return
	if arrow_impact_marker == null:
		arrow_impact_marker = Label.new()
		arrow_impact_marker.name = "ArrowImpactMarker"
		arrow_impact_marker.text = "⊕"
		arrow_impact_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_impact_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow_impact_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow_impact_marker.add_theme_font_size_override("font_size", 30)
		add_child(arrow_impact_marker)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var prediction := player.get_predicted_impact()
	var impact: Vector3 = prediction.get("position", Vector3.ZERO)
	if camera.is_position_behind(impact):
		arrow_impact_marker.visible = false
		return
	var screen := camera.unproject_position(impact)
	arrow_impact_marker.size = Vector2(34.0, 34.0)
	arrow_impact_marker.position = screen - arrow_impact_marker.size * 0.5
	arrow_impact_marker.visible = true
	# Ámbar cuando la flecha llega justo a la retícula; blanco frío cuando se
	# queda corta, que es la forma de leer el alcance sin ningún número.
	arrow_impact_marker.add_theme_color_override(
		"font_color",
		UiTheme.AMBER if bool(prediction.get("reaches_aim", false)) else UiTheme.FROST
	)
	# La retícula del centro estorba encima de la marca: mientras se apunta
	# manda la marca.
	if crosshair != null:
		crosshair.visible = false


func _on_bow_draw_changed(strength: float, arrows: int) -> void:
	if bow_power_bar != null:
		bow_power_bar.value = strength
		bow_power_bar.visible = player.is_drawing_bow
		var fill := bow_power_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			fill.bg_color = Color(0.92, 0.68, 0.24, 0.96)
	var crosshair := get_node_or_null("Crosshair") as Label
	if crosshair != null:
		crosshair.text = "◎" if player.is_drawing_bow else "·"
		crosshair.add_theme_font_size_override("font_size", 34 if player.is_drawing_bow else 18)
	if arrow_counter != null:
		arrow_counter.text = "🏹\n×%d" % arrows


func _on_charge_changed(strength: float, spin_ready: bool) -> void:
	## La carga no lleva barra: la propia tormenta —viento, oscurecimiento y
	## rayos sobre el filo— dice cuánta fuerza se lleva acumulada, y una barra
	## encima resultaba fea y redundante.
	var crosshair := get_node_or_null("Crosshair") as Label
	if crosshair != null and not player.is_drawing_bow:
		crosshair.text = "✦" if spin_ready else "·"
	if spin_ready and not _spin_hint_shown:
		_spin_hint_shown = true
		_on_player_action_feedback("¡Fuerza especial lista! Suelta para girar")
	elif strength <= 0.01:
		_spin_hint_shown = false


func _on_arrow_fired(remaining_arrows: int, _strength: float) -> void:
	if arrow_counter != null:
		arrow_counter.text = "🏹\n×%d" % remaining_arrows
	_refresh_quickbar()


func _controls_summary() -> String:
	return (
		"[b]MOVIMIENTO Y ACCIÓN[/b]\n"
		+ "Avanzar: %s     Retroceder: %s\n" % [GameSettings.action_keys("move_forward"), GameSettings.action_keys("move_back")]
		+ "Izquierda: %s     Derecha: %s\n" % [GameSettings.action_keys("move_left"), GameSettings.action_keys("move_right")]
		+ "Saltar: %s     Correr / galopar: %s\n" % [GameSettings.action_keys("jump"), GameSettings.action_keys("sprint")]
		+ "Interactuar / montar: %s     Atacar: %s     H: llamar caballo\n\n" % [GameSettings.action_keys("interact"), GameSettings.action_keys("attack")]
		+ "[b]EQUIPO Y NAVEGACIÓN[/b]\n"
		+ "1 Espada · 2 Hacha · 3 Arco · 4 Antorcha · I Inventario\n"
		+ "Con el arco: mantén clic para tensar y apuntar; suelta para disparar\n"
		+ "Con espada o hacha: un clic da un tajo; mantén hasta cargar la fuerza\n"
		+ "especial y suelta para el ataque giratorio de 360°, que además tumba\n"
		+ "la hierba de alrededor. Puedes seguir andando mientras cargas\n"
		+ "Escudo: mantén el clic derecho para cubrirte; el resto del tiempo va\n"
		+ "colgado a la espalda, igual que el arma cuando corres sin pelear\n"
		+ "Esquiva: Ctrl te mueve de costado y Ctrl + dirección + salto rueda\n"
		+ "5 Dunas · 6 Nieve · 7 Villa · 8 Bosque Umbrío · 9 Bosque Tenebroso\n"
		+ "Mapa: %s · B Minimapa · L Diario de 200 zonas · N Ayuda · 0 Siguiente jefe final\n" % GameSettings.action_keys("map")
		+ "Configuración / identidad / multijugador: %s · Esc cerrar ventana / menú de pausa" % GameSettings.action_keys("settings")
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
