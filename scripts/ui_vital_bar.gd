class_name UiVitalBar
extends Control

## Barra de constante dibujada a mano, de perfil redondeado.
##
## La primera versión salió con los cantos en diagonal y se leía como un marcador
## de máquina recreativa; el juego es low-poly y redondo, así que la barra
## también: cápsula limpia, insignia circular para el icono y nada de rótulos.
##
## Lo que de verdad hace que se lea en pleno combate no es el color, es la
## ESTELA: al recibir un golpe el relleno cae al instante y una cinta más clara
## se queda atrás medio segundo. Ese retraso deja ver CUÁNTO te acaban de quitar
## sin tener que leer el número.

const BAR_HEIGHT := 17.0
const BADGE := 12.0
const TRAIL_SPEED := 62.0

@export var value := 100.0
@export var maximum := 100.0
@export var bright := Color(0.98, 0.36, 0.30)
@export var deep := Color(0.44, 0.08, 0.09)
@export var icon := "heart"
@export var warn_below := 0.28

var _trail := 100.0
var _pulse := 0.0
var _font: Font = null


func _ready() -> void:
	custom_minimum_size = Vector2(238.0, BAR_HEIGHT + 6.0)
	_trail = value
	_font = ThemeDB.fallback_font
	set_process(true)


func set_values(current: float, top: float) -> void:
	if top > 0.0:
		maximum = top
	# La estela sólo se retrasa al BAJAR. Al curarte sube de golpe: una cinta
	# persiguiendo hacia arriba no dice nada.
	if current > value:
		_trail = current
	value = clampf(current, 0.0, maximum)
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	if _trail > value:
		_trail = maxf(value, _trail - TRAIL_SPEED * delta)
		changed = true
	if value / maxf(maximum, 0.001) <= warn_below:
		_pulse = fposmod(_pulse + delta * 3.1, TAU)
		changed = true
	elif _pulse != 0.0:
		_pulse = 0.0
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var top := 3.0
	var radius := BAR_HEIGHT * 0.5
	var left := BADGE * 2.0 + 4.0
	var right := size.x
	var span := right - left
	var ratio := clampf(value / maxf(maximum, 0.001), 0.0, 1.0)
	var trail_ratio := clampf(_trail / maxf(maximum, 0.001), 0.0, 1.0)

	# Canal hundido.
	_capsule(left, right, top, BAR_HEIGHT, Color(0.05, 0.045, 0.05, 0.92))
	_capsule(left + 1.4, right - 1.4, top + 1.4, BAR_HEIGHT - 2.8, Color(0.11, 0.10, 0.10, 0.95))

	# Estela: lo que acabas de perder, todavía a la vista.
	if trail_ratio > ratio:
		_capsule(left + 1.6, left + 1.6 + (span - 3.2) * trail_ratio, top + 1.6,
			BAR_HEIGHT - 3.2, Color(bright.lerp(Color.WHITE, 0.55), 0.45))

	# Relleno: cápsula honda y otra más clara encima, que es el degradado.
	if ratio > 0.0:
		var end := left + 1.6 + (span - 3.2) * ratio
		_capsule(left + 1.6, end, top + 1.6, BAR_HEIGHT - 3.2, deep)
		_capsule(left + 2.4, end - 0.8, top + 2.2, (BAR_HEIGHT - 3.2) * 0.58, bright)
		_capsule(left + 3.0, end - 1.4, top + 2.6, (BAR_HEIGHT - 3.2) * 0.26,
			bright.lerp(Color.WHITE, 0.42))
		if _pulse > 0.0:
			_capsule(left + 1.6, end, top + 1.6, BAR_HEIGHT - 3.2,
				Color(1.0, 1.0, 1.0, 0.10 + 0.12 * sin(_pulse)))

	# Cifra, alineada al final de la barra y sin rótulo: el icono ya dice cuál es.
	draw_string(_font, Vector2(right - 54.0, top + BAR_HEIGHT - 4.0),
		"%d" % roundi(value), HORIZONTAL_ALIGNMENT_RIGHT, 50, 11,
		Color(1.0, 0.96, 0.90, 0.92))

	# Insignia redonda con el icono.
	var badge := Vector2(BADGE + 1.0, top + radius)
	draw_circle(badge, BADGE, Color(0.07, 0.06, 0.07, 0.96))
	draw_arc(badge, BADGE - 0.7, 0.0, TAU, 28, bright.lerp(Color.WHITE, 0.2), 1.5, true)
	_draw_icon(badge)


func _capsule(from_x: float, to_x: float, top: float, height: float, colour: Color) -> void:
	## Una cápsula: dos discos y el tramo recto entre ellos. Godot no trae
	## rectángulo redondeado en el dibujado inmediato.
	if to_x <= from_x or height <= 0.0:
		return
	var radius := height * 0.5
	var centre := top + radius
	var a := minf(from_x + radius, to_x - radius)
	var b := maxf(to_x - radius, from_x + radius)
	draw_circle(Vector2(a, centre), radius, colour)
	draw_circle(Vector2(b, centre), radius, colour)
	if b > a:
		draw_rect(Rect2(a, top, b - a, height), colour)


func _draw_icon(centre: Vector2) -> void:
	var tint := bright.lerp(Color.WHITE, 0.30)
	if icon == "heart":
		var r := 3.9
		draw_circle(centre + Vector2(-r * 0.58, -r * 0.30), r * 0.74, tint)
		draw_circle(centre + Vector2(r * 0.58, -r * 0.30), r * 0.74, tint)
		draw_colored_polygon(PackedVector2Array([
			Vector2(centre.x - r * 1.24, centre.y - r * 0.18),
			Vector2(centre.x + r * 1.24, centre.y - r * 0.18),
			Vector2(centre.x, centre.y + r * 1.34),
		]), tint)
	else:
		# Gota de vigor: un rombo redondeado, sin aristas duras.
		draw_colored_polygon(PackedVector2Array([
			centre + Vector2(0.0, -5.4), centre + Vector2(3.6, 0.4),
			centre + Vector2(0.0, 5.4), centre + Vector2(-3.6, 0.4),
		]), tint)
		draw_circle(centre + Vector2(0.0, 1.4), 2.6, tint)
