class_name KillCam
extends Node

## La cámara del golpe final: ralentiza el tiempo, cierra el encuadre y pinta
## dos franjas negras durante el instante en que algo cae.
##
## Se dispara en tres intensidades, porque no pesa lo mismo un limo que Vaelor:
##   ESCARAMUZA  al abatir una criatura de camino. Muy breve, apenas un latido.
##   HAZAÑA      al abatir a un jefe de acto. Más lenta y más cerrada.
##   CAÍDA       cuando el que cae eres tú. La más larga, y además desatura.
##
## El tiempo se mide en segundos REALES, no en los del juego: con
## `Engine.time_scale` a 0.2 un contador normal tardaría cinco veces más y la
## escena se quedaría colgada en cámara lenta.

enum Beat { SKIRMISH, FEAT, FALL }

const SETTINGS := {
	Beat.SKIRMISH: {"scale": 0.34, "hold": 0.34, "bars": 0.16, "zoom": 4.0, "grey": 0.0},
	Beat.FEAT: {"scale": 0.20, "hold": 1.05, "bars": 0.42, "zoom": 11.0, "grey": 0.22},
	Beat.FALL: {"scale": 0.16, "hold": 1.70, "bars": 0.52, "zoom": 8.0, "grey": 0.70},
}

var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _tint: ColorRect
var _title: Label
## Que se pueda preguntar desde fuera si el remate sigue corriendo: encadenar
## la cinemática de acto sin esperarlo pisa una escena con la otra.
var running := false
var _left := 0.0
var _total := 1.0
var _beat := Beat.SKIRMISH
var _base_fov := 0.0
var _camera: Camera3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(false)


func flourish(beat: int, caption := "") -> void:
	## Un golpe no interrumpe a otro más grande: una escaramuza no puede cortar
	## la caída del héroe a media cinemática.
	if _left > 0.0 and beat < _beat:
		return
	_beat = beat
	var setting: Dictionary = SETTINGS[beat]
	_total = float(setting["hold"])
	_left = _total
	Engine.time_scale = float(setting["scale"])
	_camera = get_viewport().get_camera_3d()
	if _camera != null:
		_base_fov = _camera.fov
	running = true
	_title.text = caption
	_title.visible = not caption.is_empty()
	# El golpe entra ANTES de que baje el tiempo. La sacudida mide en segundos
	# reales, así que a escala 0,16 se ve larga y pesada en vez de acelerada.
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig == null:
		var world := get_tree().current_scene
		if world != null:
			rig = world.get_node_or_null("CameraRig")
	if rig != null and rig.has_method("add_shake"):
		rig.call("add_shake", [0.22, 0.42, 0.68][clampi(beat, 0, 2)])
	set_process(true)


func _process(delta: float) -> void:
	# En segundos reales: `delta` viene ya multiplicado por la escala de tiempo.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_left = maxf(0.0, _left - real)
	var setting: Dictionary = SETTINGS[_beat]
	# Campana de entrada y salida: entra deprisa y suelta despacio.
	var progress := 1.0 - _left / maxf(_total, 0.001)
	var weight := sin(clampf(progress, 0.0, 1.0) * PI)
	var entry := clampf(progress * 6.0, 0.0, 1.0)
	weight = maxf(weight, entry * (1.0 - progress))

	var height := float(setting["bars"]) * weight * 96.0
	_top.size.y = height
	_bottom.size.y = height
	_bottom.position.y = get_viewport().get_visible_rect().size.y - height
	_tint.color.a = float(setting["grey"]) * weight * 0.75
	_title.modulate.a = weight

	if _camera != null and _base_fov > 0.0:
		_camera.fov = _base_fov - float(setting["zoom"]) * weight

	if _left <= 0.0:
		_finish()


func _finish() -> void:
	running = false
	Engine.time_scale = 1.0
	if _camera != null and _base_fov > 0.0:
		_camera.fov = _base_fov
	_top.size.y = 0.0
	_bottom.size.y = 0.0
	_tint.color.a = 0.0
	_title.visible = false
	set_process(false)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "KillCamLayer"
	_layer.layer = 240
	add_child(_layer)
	var width := 4096.0
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.color = Color(0.04, 0.03, 0.05, 0.0)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tint)
	_top = ColorRect.new()
	_top.name = "BarTop"
	_top.color = Color(0.0, 0.0, 0.0, 0.96)
	_top.position = Vector2.ZERO
	_top.size = Vector2(width, 0.0)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_top)
	_bottom = ColorRect.new()
	_bottom.name = "BarBottom"
	_bottom.color = Color(0.0, 0.0, 0.0, 0.96)
	_bottom.size = Vector2(width, 0.0)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bottom)
	_title = Label.new()
	_title.name = "KillCaption"
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.position = Vector2(-460.0, 96.0)
	_title.size = Vector2(920.0, 46.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58))
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.visible = false
	_layer.add_child(_title)
