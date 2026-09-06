class_name RPGCinematic
extends Node

## Cinemática de acto: bandas negras, cámara que orbita lo que acaba de pasar y
## el texto pasando por abajo.
##
## Un acto se cerraba con un cuadro de diálogo, y el cuadro de diálogo PAUSA el
## árbol: justo después de tumbar a un jefe, el mundo se congelaba —el cadáver
## a medio caer, el polvo quieto— para leer un párrafo. Aquí el mundo sigue
## vivo y la cámara lo mira; lo único que se bloquea es el mando del héroe.

signal finished()

## Tiempos en segundos REALES. La cámara lenta del golpe final baja la escala a
## 0,16, y con el reloj de juego una tarjeta de 4 s duraría veinticinco.
const FADE_IN := 0.55
const FADE_OUT := 0.85
const BAR_HEIGHT := 0.13
const ORBIT_SPEED := 0.22
const ORBIT_RADIUS := 15.5
const ORBIT_HEIGHT := 7.2

var running := false
var plays := 0

var _layer: CanvasLayer
var _veil: ColorRect
var _top: ColorRect
var _bottom: ColorRect
var _card: RichTextLabel
var _skip: Label
var _camera: Camera3D
var _previous: Camera3D = null
var _focus := Vector3.ZERO
var _cards: Array = []
var _index := -1
var _left := 0.0
var _angle := 0.0
var _fade := 0.0
var _closing := false
var _radius := ORBIT_RADIUS
var _player: Node = null


func _ready() -> void:
	_build_overlay()
	set_process(false)


## `cards` son diccionarios {text, hold}. `focus` es lo que mira la cámara.
func play(cards: Array, focus: Vector3, player: Node = null,
		frame_radius := ORBIT_RADIUS) -> void:
	if running or cards.is_empty():
		return
	# El encuadre lo dicta lo que se mira. Con un radio fijo de 15,5 m la cámara
	# quedaba DENTRO de Vaelor, que va a escala 5, y la escena era una mano.
	_radius = maxf(frame_radius, 8.0)
	_cards = cards
	_focus = focus
	_player = player
	_index = -1
	_fade = FADE_IN
	_closing = false
	running = true
	plays += 1
	_angle = 0.0
	_layer.visible = true
	_veil.color = Color(0.0, 0.0, 0.0, 1.0)
	_take_camera()
	# Colocarla YA, no en el primer `_process`: si no, el primer fotograma de la
	# cinemática se ve desde el origen del mundo y parpadea.
	_aim_camera()
	_hold_player(true)
	set_process(true)
	_advance()


func skip() -> void:
	if running and not _closing:
		_begin_closing()


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_angle += real * ORBIT_SPEED
	_aim_camera()
	if _fade > 0.0:
		_fade = maxf(0.0, _fade - real)
		var weight := _fade / FADE_IN if not _closing else 1.0 - _fade / FADE_OUT
		_veil.color = Color(0.0, 0.0, 0.0, clampf(weight, 0.0, 1.0))
		if _closing and _fade <= 0.0:
			_finish()
			return
	_left -= real
	if _left <= 0.0 and not _closing:
		_advance()


func _aim_camera() -> void:
	if _camera == null:
		return
	var offset := Vector3(cos(_angle), 0.0, sin(_angle)) * _radius
	_camera.global_position = _focus + offset + Vector3.UP * (_radius * 0.46)
	_camera.look_at(_focus, Vector3.UP)


func _advance() -> void:
	_index += 1
	if _index >= _cards.size():
		_begin_closing()
		return
	var card: Dictionary = _cards[_index]
	_card.text = "[center]%s[/center]" % String(card.get("text", ""))
	_left = float(card.get("hold", 3.4))


func _begin_closing() -> void:
	_closing = true
	_fade = FADE_OUT
	_card.text = ""


func _finish() -> void:
	running = false
	set_process(false)
	_layer.visible = false
	_hold_player(false)
	_release_camera()
	finished.emit()


## Bloquea el mando sin pausar el árbol: el mundo tiene que seguir moviéndose
## detrás de las bandas, que es justo lo que el cuadro de diálogo no permitía.
func _hold_player(held: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_cinematic_hold"):
		_player.call("set_cinematic_hold", held)
	else:
		_player.set_physics_process(not held)


func _take_camera() -> void:
	_previous = get_viewport().get_camera_3d()
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "CinematicEye"
		_camera.far = 2200.0
		_camera.fov = 52.0
		get_tree().current_scene.add_child(_camera) if get_tree().current_scene != null \
			else get_parent().add_child(_camera)
	_camera.current = true


func _release_camera() -> void:
	if _camera != null:
		_camera.current = false
	if _previous != null and is_instance_valid(_previous):
		_previous.current = true


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 96
	_layer.visible = false
	add_child(_layer)

	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 1.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_veil)

	_top = ColorRect.new()
	_top.color = Color(0.0, 0.0, 0.0, 1.0)
	_top.anchor_right = 1.0
	_top.anchor_bottom = BAR_HEIGHT
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_top)

	_bottom = ColorRect.new()
	_bottom.color = Color(0.0, 0.0, 0.0, 1.0)
	_bottom.anchor_top = 1.0 - BAR_HEIGHT
	_bottom.anchor_right = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bottom)

	_card = RichTextLabel.new()
	_card.bbcode_enabled = true
	_card.fit_content = true
	_card.scroll_active = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_left = 0.14
	_card.anchor_right = 0.86
	_card.anchor_top = 1.0 - BAR_HEIGHT + 0.012
	_card.anchor_bottom = 1.0
	_card.add_theme_font_size_override("normal_font_size", 21)
	_card.add_theme_color_override("default_color", Color(0.96, 0.93, 0.86))
	_layer.add_child(_card)

	_skip = Label.new()
	_skip.text = "cualquier tecla · seguir"
	_skip.anchor_left = 0.78
	_skip.anchor_top = 0.02
	_skip.anchor_right = 0.99
	_skip.add_theme_font_size_override("font_size", 13)
	_skip.add_theme_color_override("font_color", Color(0.78, 0.75, 0.70, 0.62))
	_layer.add_child(_skip)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	var pressed := (event is InputEventKey and (event as InputEventKey).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if pressed:
		skip()
		get_viewport().set_input_as_handled()
