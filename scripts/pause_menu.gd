class_name PauseMenu
extends ColorRect

## Menú de pausa convencional. Sus subpaneles viven dentro del mismo overlay,
## por lo que Escape siempre retrocede un nivel antes de volver al juego.

signal closed()
signal multiplayer_requested()

var _main: VBoxContainer
var _page: VBoxContainer
var _page_title: Label
var _page_content: VBoxContainer
var _save_list: ItemList
var _status: Label
var _credits_bbcode := ""


func _ready() -> void:
	name = "PauseMenu"
	z_index = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.008, 0.014, 0.019, 0.88)
	visible = false
	_build_interface()
	SaveGameManager.status_changed.connect(_set_status)


func set_open(open: bool) -> void:
	visible = open
	if open:
		_show_main()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit()


func close_one_level() -> bool:
	if not visible:
		return false
	if _page.visible:
		_show_main()
	else:
		set_open(false)
	return true


func _build_interface() -> void:
	var panel := PanelContainer.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330.0, -330.0)
	panel.size = Vector2(660.0, 660.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.068, 0.061, 0.985)
	style.border_color = Color(0.86, 0.66, 0.30, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)
	var root_content := VBoxContainer.new()
	root_content.add_theme_constant_override("separation", 12)
	margin.add_child(root_content)
	var title := Label.new()
	title.text = "SENDEROS DEL HORIZONTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	root_content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "MENÚ DE PAUSA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.77, 0.66))
	root_content.add_child(subtitle)
	_main = VBoxContainer.new()
	_main.name = "MainButtons"
	_main.add_theme_constant_override("separation", 9)
	root_content.add_child(_main)
	_add_main_button("Continuar", "ContinueButton", func() -> void: set_open(false))
	_add_main_button("Guardar partida", "SaveButton", func() -> void: SaveGameManager.save_current_game("manual"))
	_add_main_button("Cargar / gestionar partidas", "LoadButton", _show_saves)
	_add_main_button("Controles", "ControlsButton", _show_controls)
	_add_main_button("Gráficos", "GraphicsButton", _show_graphics)
	_add_main_button("Sonido", "SoundButton", _show_sound)
	_add_main_button("Agradecimientos", "CreditsButton", _show_credits)
	_add_main_button("Multijugador", "MultiplayerButton", func() -> void: multiplayer_requested.emit())
	_add_main_button("Salir del juego", "QuitButton", func() -> void:
		SaveGameManager.save_current_game("salida")
		get_tree().quit()
	)
	_page = VBoxContainer.new()
	_page.name = "SubPage"
	_page.visible = false
	_page.add_theme_constant_override("separation", 12)
	root_content.add_child(_page)
	_page_title = Label.new()
	_page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_title.add_theme_font_size_override("font_size", 23)
	_page_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	_page.add_child(_page_title)
	_page_content = VBoxContainer.new()
	_page_content.add_theme_constant_override("separation", 10)
	_page.add_child(_page_content)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Volver · Esc"
	back.pressed.connect(_show_main)
	_page.add_child(back)
	_status = Label.new()
	_status.name = "PauseStatus"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.66, 0.87, 0.68))
	root_content.add_child(_status)


func _add_main_button(text_value: String, node_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(callback)
	_main.add_child(button)


func _clear_page(title_value: String) -> void:
	for child in _page_content.get_children():
		_page_content.remove_child(child)
		child.queue_free()
	_page_title.text = title_value
	_main.visible = false
	_page.visible = true


func _show_main() -> void:
	_main.visible = true
	_page.visible = false
	_status.text = "Esc · continuar"


func _show_controls() -> void:
	_clear_page("CONTROLES")
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = false
	text.custom_minimum_size = Vector2(540.0, 410.0)
	text.add_theme_font_size_override("normal_font_size", 17)
	text.text = (
		"[b]Movimiento[/b]\nWASD / flechas · caminar   Mayús · correr / galopar   Espacio · saltar\n"
		+ "E · interactuar / explorar / montar   H · llamar al caballo\n\n"
		+ "[b]Equipo[/b]\n1 espada   2 hacha   3 arco   4 antorcha   Clic · atacar / tensar\n"
		+ "I · inventario   L · diario de aventura\n\n"
		+ "[b]Mundo e interfaz[/b]\nM · mapa   B · minimapa   N · ayuda   Z · configuración\n"
		+ "5–9 · viajes de prueba   0 · siguiente jefe final   Esc · cerrar ventana / pausa"
	)
	_page_content.add_child(text)


func set_credits_content(bbcode: String) -> void:
	_credits_bbcode = bbcode


func _show_credits() -> void:
	_clear_page("AGRADECIMIENTOS")
	var text := RichTextLabel.new()
	text.name = "CreditsText"
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = true
	text.custom_minimum_size = Vector2(540.0, 410.0)
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 18)
	text.text = _credits_bbcode if not _credits_bbcode.is_empty() else (
		"[center][b]Gracias por acompañarnos en Senderos del Horizonte.[/b][/center]"
	)
	_page_content.add_child(text)


func _show_graphics() -> void:
	_clear_page("GRÁFICOS")
	var resolution_label := Label.new()
	resolution_label.text = "Resolución"
	_page_content.add_child(resolution_label)
	var selector := OptionButton.new()
	for resolution in GameSettings.get_supported_resolutions():
		selector.add_item("%d × %d" % [resolution.x, resolution.y])
		if resolution == GameSettings.resolution:
			selector.select(selector.item_count - 1)
	selector.item_selected.connect(func(index: int) -> void:
		GameSettings.set_resolution(GameSettings.get_supported_resolutions()[index])
	)
	_page_content.add_child(selector)
	var lod_label := Label.new()
	lod_label.text = "Distancia de detalle: %.0f m" % GameSettings.lod_distance_metres
	_page_content.add_child(lod_label)
	var lod := HSlider.new()
	lod.min_value = GameSettings.MIN_LOD_DISTANCE
	lod.max_value = GameSettings.MAX_LOD_DISTANCE
	lod.step = 10.0
	lod.value = GameSettings.lod_distance_metres
	lod.value_changed.connect(func(value: float) -> void:
		GameSettings.set_lod_distance(value)
		lod_label.text = "Distancia de detalle: %.0f m" % value
	)
	_page_content.add_child(lod)
	var hint := Label.new()
	hint.text = "El LOD cambia automáticamente modelos lejanos por versiones ligeras."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_content.add_child(hint)


func _show_sound() -> void:
	_clear_page("SONIDO")
	for bus_name in ["Master", "Music", "Ambience", "SFX"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = {"Master": "General", "Music": "Música", "Ambience": "Ambiente", "SFX": "Efectos"}.get(bus_name, bus_name)
		label.custom_minimum_size.x = 150.0
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 350.0
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		var bus_index := AudioServer.get_bus_index(bus_name)
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index)) if bus_index >= 0 else 1.0
		slider.value_changed.connect(func(value: float) -> void:
			var index := AudioServer.get_bus_index(bus_name)
			if index >= 0:
				AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
		)
		row.add_child(slider)
		_page_content.add_child(row)


func _show_saves() -> void:
	_clear_page("PARTIDAS GUARDADAS")
	var explanation := Label.new()
	explanation.text = "En cooperativo la ranura se identifica por los nombres del grupo. Autoguardado cada 2 minutos."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_content.add_child(explanation)
	_save_list = ItemList.new()
	_save_list.name = "SaveSlotList"
	_save_list.custom_minimum_size = Vector2(540.0, 300.0)
	_page_content.add_child(_save_list)
	_refresh_saves()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_content.add_child(row)
	var save := Button.new()
	save.text = "Guardar ahora"
	save.pressed.connect(func() -> void:
		SaveGameManager.save_current_game("manual")
		_refresh_saves()
	)
	row.add_child(save)
	var load_button := Button.new()
	load_button.text = "Cargar seleccionada"
	load_button.pressed.connect(_load_selected_save)
	row.add_child(load_button)


func _refresh_saves() -> void:
	if _save_list == null:
		return
	_save_list.clear()
	var slots := SaveGameManager.list_slots()
	for slot_value in slots:
		var slot := slot_value as Dictionary
		var stamp := Time.get_datetime_string_from_unix_time(int(slot.saved_at_unix), true).replace("T", "  ")
		_save_list.add_item("%s  ·  %d jugador(es)  ·  %s" % [String(slot.display_name), int(slot.player_count), stamp])
		_save_list.set_item_metadata(_save_list.item_count - 1, String(slot.path))
	if slots.is_empty():
		_save_list.add_item("Todavía no hay partidas guardadas")
		_save_list.set_item_disabled(0, true)


func _load_selected_save() -> void:
	if _save_list == null or _save_list.get_selected_items().is_empty():
		_set_status("Selecciona una ranura")
		return
	var index := int(_save_list.get_selected_items()[0])
	var path := String(_save_list.get_item_metadata(index))
	if SaveGameManager.load_slot(path):
		set_open(false)


func _set_status(message: String) -> void:
	if _status != null:
		_status.text = message
