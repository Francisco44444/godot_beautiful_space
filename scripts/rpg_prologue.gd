class_name RPGPrologue
extends Node

## La apertura en frío. El juego empezaba sin decir nada: aparecías en un puerto
## y a los diez minutos alguien te hablaba de campanas que no habías oído callar.
##
## Cinco rótulos sobre negro plantan el misterio y la vuelta final en el mismo
## aliento: que las campanas sujetaban algo, que alguien borró los nombres, y
## que nadie en la isla sabe cómo te llamas —tú tampoco lo has dicho—. Esa
## última línea es la que hace que el jugador se acuerde de ella cinco actos
## después, cuando Calen confiesa.
##
## Se salta con cualquier tecla, porque una apertura que no se puede saltar es
## un peaje. Y sólo se pone la primera vez: se recuerda en `user://`.

const MARKER := "user://prologue_seen_v1"
const CARDS: Array[Dictionary] = [
	{"text": "Aeloria tenía cinco campanas.", "hold": 3.1},
	{"text": "No tocaban las horas.\nSujetaban algo.", "hold": 3.6},
	{"text": "Cada una llevaba grabado el nombre\nde quien la fundió.\nEse nombre era lo que la ataba.", "hold": 4.4},
	{"text": "Alguien raspó los nombres.", "hold": 3.2},
	{"text": "Hace tres años que la isla no suena.", "hold": 3.4},
	{"text": "Y nadie de aquí sabe cómo te llamas.\n\nTú tampoco lo has dicho.", "hold": 4.6},
]
const FADE := 0.9

var _layer: CanvasLayer
var _veil: ColorRect
var _card: Label
var _skip: Label
var _index := -1
var _left := 0.0
var _running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	set_process(false)


func should_play() -> bool:
	return not FileAccess.file_exists(MARKER)


func play() -> void:
	if _running:
		return
	_running = true
	_index = 0
	_left = _hold(0)
	_layer.visible = true
	_veil.color.a = 1.0
	set_process(true)


func mark_seen() -> void:
	var file := FileAccess.open(MARKER, FileAccess.WRITE)
	if file != null:
		file.store_string("visto")
		file.close()


func _process(delta: float) -> void:
	# En segundos reales: la cinemática del golpe final puede tener el tiempo
	# ralentizado y la apertura no debe alargarse por eso.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_left = maxf(0.0, _left - real)
	var hold := _hold(_index)
	var elapsed := hold - _left
	# Campana de entrada y salida por rótulo.
	var alpha := clampf(elapsed / FADE, 0.0, 1.0)
	alpha = minf(alpha, clampf(_left / FADE, 0.0, 1.0))
	_card.modulate.a = alpha
	_skip.modulate.a = alpha * 0.55
	if _left > 0.0:
		return
	_index += 1
	if _index >= CARDS.size():
		_finish()
		return
	_card.text = String(CARDS[_index]["text"])
	_left = _hold(_index)


func _hold(index: int) -> float:
	if index < 0 or index >= CARDS.size():
		return 0.1
	return float(CARDS[index]["hold"])


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		_finish()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish()


func _finish() -> void:
	_running = false
	set_process(false)
	mark_seen()
	# El velo se retira con un desvanecido propio, no de golpe: cortar a negro
	# y aparecer en el puerto de un fotograma a otro se lee como un error.
	var fade := create_tween()
	fade.tween_property(_card, "modulate:a", 0.0, 0.25)
	fade.parallel().tween_property(_skip, "modulate:a", 0.0, 0.25)
	fade.tween_property(_veil, "color:a", 0.0, 1.4)
	fade.tween_callback(func() -> void: _layer.visible = false)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PrologueLayer"
	_layer.layer = 300
	_layer.visible = false
	add_child(_layer)
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0.012, 0.010, 0.016, 1.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_veil)
	_card = Label.new()
	_card.name = "Card"
	_card.text = String(CARDS[0]["text"])
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.position = Vector2(-520.0, -90.0)
	_card.size = Vector2(1040.0, 180.0)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_theme_font_size_override("font_size", 34)
	_card.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	_card.modulate.a = 0.0
	_layer.add_child(_card)
	_skip = Label.new()
	_skip.name = "Skip"
	_skip.text = "cualquier tecla para saltar"
	_skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip.position = Vector2(-200.0, -74.0)
	_skip.size = Vector2(400.0, 24.0)
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip.add_theme_font_size_override("font_size", 13)
	_skip.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	_skip.modulate.a = 0.0
	_layer.add_child(_skip)
