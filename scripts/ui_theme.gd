class_name UiTheme
extends RefCounted

## Lenguaje visual único para toda la interfaz que no es el mapa.
##
## Antes cada panel construía su propio `StyleBoxFlat` con colores parecidos pero
## nunca iguales: había una docena de ámbares distintos y bordes de grosores
## dispares. Centralizar la paleta y las fábricas de estilo deja un aspecto
## coherente y permite retocar el conjunto desde un solo sitio.

## Fondos: del más oscuro (diálogos a pantalla completa) al más liviano (avisos).
const INK := Color(0.055, 0.065, 0.085, 0.96)
const INK_SOFT := Color(0.085, 0.10, 0.13, 0.90)
const INK_GLASS := Color(0.10, 0.12, 0.16, 0.72)
## Acentos: ámbar de pergamino para lo medieval y azul frío para lo enfático.
const AMBER := Color(0.95, 0.76, 0.36)
const AMBER_DIM := Color(0.58, 0.45, 0.22, 0.85)
const FROST := Color(0.62, 0.86, 1.0)
const PARCHMENT := Color(0.94, 0.92, 0.86)
const MUTED := Color(0.66, 0.70, 0.76)
const DANGER := Color(0.90, 0.36, 0.30)
const SUCCESS := Color(0.52, 0.84, 0.46)

const RADIUS_PANEL := 14
const RADIUS_CHIP := 10
const RADIUS_BAR := 7


static func panel(
	fill: Color = INK_SOFT,
	border: Color = AMBER_DIM,
	radius: int = RADIUS_PANEL,
	margin_x: float = 16.0,
	margin_y: float = 12.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	# Una sombra suave separa el panel del paisaje sin recurrir a fondos opacos.
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


static func chip(fill: Color = INK_GLASS, border: Color = AMBER_DIM) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_CHIP)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


static func bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.78)
	style.border_color = Color(0.0, 0.0, 0.0, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_BAR)
	return style


static func bar_fill(tint: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(RADIUS_BAR)
	return style


static func style_progress(bar: ProgressBar, tint: Color) -> void:
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", bar_background())
	bar.add_theme_stylebox_override("fill", bar_fill(tint))


static func style_button(button: Button, accent: Color = AMBER) -> void:
	## Estados distinguibles sin cambiar de forma: solo el fondo y el borde
	## reaccionan, que es lo que se espera de una interfaz moderna.
	var normal := chip(INK_GLASS, Color(accent.r, accent.g, accent.b, 0.55))
	var hover := chip(Color(0.16, 0.20, 0.26, 0.88), accent)
	var pressed := chip(Color(0.08, 0.10, 0.13, 0.94), accent)
	var disabled := chip(Color(0.10, 0.11, 0.13, 0.55), Color(0.35, 0.37, 0.40, 0.5))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.60))


static func style_title(label: Label, size: int = 22, tint: Color = AMBER) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))


static func style_body(label: Label, size: int = 15, tint: Color = PARCHMENT) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
