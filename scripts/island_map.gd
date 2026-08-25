class_name IslandMapView
extends Control

## Cartografía dinámica sobre pergamino: carreteras, mareas, biomas, relieve,
## pueblos y marcador del jugador se dibujan en coordenadas reales del mundo.

const WORLD_HALF := 6000.0
const PARCHMENT: Texture2D = preload("res://assets/textures/ui/parchment_map_background.png")
const PARCHMENT_MASK_SHADER := """
shader_type canvas_item;
render_mode unshaded;

// La ilustracion original es RGB y trae negro alrededor del borde rasgado.
// Convertimos esos pixeles casi negros en transparencia para conservar la
// silueta organica del pergamino sin mostrar un rectangulo.
void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float brightest_channel = max(paper.r, max(paper.g, paper.b));
	float edge_alpha = smoothstep(0.018, 0.075, brightest_channel);
	COLOR = vec4(paper.rgb * vec3(1.0, 0.97, 0.88), paper.a * edge_alpha);
}
"""
const ROADS: Array = [
	[Vector2(0, 190), Vector2(-120, 520), Vector2(-420, 760), Vector2(-980, 780), Vector2(-1450, 650)],
	[Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)],
	[Vector2(-1450, 650), Vector2(-1780, 230), Vector2(-2050, -420), Vector2(-2200, -900)],
	[Vector2(0, 190), Vector2(620, 320), Vector2(1260, 120), Vector2(1840, -420), Vector2(2260, -980)],
	[Vector2(620, 320), Vector2(1120, 820), Vector2(1660, 1320), Vector2(2180, 1880)],
	[Vector2(-1450, 650), Vector2(-1850, 1120), Vector2(-2180, 1650)],
	[Vector2(-420, -2150), Vector2(260, -2500), Vector2(720, -3080)],
	[Vector2(98, -110), Vector2(420, -420), Vector2(920, -560), Vector2(1840, -420)],
	[Vector2(2780, 1480), Vector2(3070, 1540), Vector2(3340, 1640), Vector2(3600, 1770), Vector2(3890, 1900)],
	[Vector2(2260, -980), Vector2(2860, -1120), Vector2(3480, -1320), Vector2(4140, -1260), Vector2(4920, -1080)],
]
const RIAS: Array = [
	[Vector2(-4780, -2100), Vector2(-4420, -1950), Vector2(-4090, -1640), Vector2(-3720, -1510), Vector2(-3360, -1740)],
	[Vector2(-4780, 2250), Vector2(-4380, 2040), Vector2(-3990, 2200), Vector2(-3610, 1880), Vector2(-3220, 1960)],
	[Vector2(-2550, -4480), Vector2(-2390, -4100), Vector2(-2070, -3820), Vector2(-1760, -3520), Vector2(-1600, -3180)],
]
const FOSSA_BRANCHES: Array = [
	[Vector2(2760, 620), Vector2(3060, 850), Vector2(3240, 1160), Vector2(3470, 1430), Vector2(3760, 1690), Vector2(4140, 1980), Vector2(4320, 2420), Vector2(4230, 2860)],
	[Vector2(3240, 1160), Vector2(3560, 980), Vector2(3920, 810), Vector2(4250, 920)],
	[Vector2(3470, 1430), Vector2(3310, 1770), Vector2(3420, 2160), Vector2(3710, 2380), Vector2(3990, 2710)],
	[Vector2(3760, 1690), Vector2(4050, 1510), Vector2(4350, 1580)],
	[Vector2(3420, 2160), Vector2(3130, 2450), Vector2(3060, 2820), Vector2(3280, 3090)],
]
const POINTS_OF_INTEREST: Array = [
	{"name": "Puerto Alba", "point": Vector2(0, 190), "kind": "village"},
	{"name": "Villa Robledal", "point": Vector2(-1450, 650), "kind": "castle"},
	{"name": "Aldea de la Bruma", "point": Vector2(-2200, -900), "kind": "village"},
	{"name": "Bastion del Este", "point": Vector2(2260, -980), "kind": "castle"},
	{"name": "Oasis Dorado", "point": Vector2(2180, 1880), "kind": "village"},
	{"name": "Castillo Boreal", "point": Vector2(-295, -2147), "kind": "castle"},
	{"name": "Bosque Umbrio", "point": Vector2(-2180, 1650), "kind": "forest"},
	{"name": "Cumbres Blancas", "point": Vector2(180, -3350), "kind": "mountain"},
	{"name": "Gruta del Acantilado", "point": Vector2(3600, 1770), "kind": "grotto"},
	{"name": "Bosque Tenebroso", "point": Vector2(4620, -1260), "kind": "mystery"},
]

@export var player_path: NodePath = NodePath("../../Player")
@export var full_map := false
@onready var player: Node3D = get_node_or_null(player_path) as Node3D
@onready var island_environment: Node = get_node_or_null("../../IslandEnvironment")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_install_parchment_background()
	set_meta("ocean_fills_exterior", true)
	set_meta("false_beach_border_removed", true)
	set_meta("rotating_player_marker", true)
	set_meta("rectangular_map_tint_removed", true)
	set_meta("parchment_edge_is_transparent", true)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func get_road_count() -> int:
	return ROADS.size()


func get_poi_count() -> int:
	return POINTS_OF_INTEREST.size()


func _draw() -> void:
	# El fondo vive en un TextureRect independiente: así se recorta el negro
	# exterior sin volver transparentes las líneas oscuras de la cartografía.
	# La antigua plancha azul rectangular se elimina por completo.
	_draw_sea_marks()
	_draw_island()
	_draw_biomes()
	_draw_contours_and_symbols()
	_draw_rias_and_fossa()
	_draw_roads()
	_draw_points_of_interest()
	_draw_exploration_target()
	_draw_player()
	var font := ThemeDB.fallback_font
	if full_map:
		draw_string(font, Vector2(42, 46), "ISLA DE LOS SENDEROS · 12 × 12 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.23, 0.12, 0.055))
		var tide_name := "PLEAMAR" if _tide_amount() > 0.58 else "BAJAMAR"
		draw_string(font, Vector2(42, size.y - 50), "%s · M cerrar · B minimapa · N controles · 0 créditos" % tide_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.31, 0.18, 0.08))
		_draw_compass_rose(Vector2(size.x - 92.0, size.y - 86.0), 31.0)
	else:
		draw_string(font, Vector2(12, 22), "ISLA · B ocultar · M ampliar", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.22, 0.11, 0.045))


func _install_parchment_background() -> void:
	if has_node("ParchmentBackground"):
		return
	var background := TextureRect.new()
	background.name = "ParchmentBackground"
	background.texture = PARCHMENT
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	background.z_index = -1
	var shader := Shader.new()
	shader.code = PARCHMENT_MASK_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	background.material = shader_material
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw_island() -> void:
	var island := _island_polygon(1.0)
	# El límite marrón fino es la costa cartográfica. La gruesa cinta amarilla
	# anterior se elimina: fuera de este polígono ya está dibujado el mar.
	draw_colored_polygon(island, Color(0.42, 0.58, 0.30, 0.97))
	var closed := island + PackedVector2Array([island[0]])
	draw_polyline(closed, Color(0.20, 0.12, 0.065, 0.92), 3.0 if full_map else 1.4, true)
	draw_polyline(closed, Color(0.55, 0.76, 0.72, 0.72), 1.0 if full_map else 0.6, true)


func _draw_biomes() -> void:
	_draw_world_blob(Vector2(3060, 2480), Vector2(2350, 1450), Color(0.84, 0.59, 0.22, 0.90), 2.4)
	_draw_world_blob(Vector2(120, -3850), Vector2(2500, 1250), Color(0.78, 0.87, 0.91, 0.92), 6.1)
	_draw_world_blob(Vector2(-2550, 1150), Vector2(1650, 1650), Color(0.08, 0.28, 0.16, 0.88), 3.7)
	_draw_world_blob(Vector2(-2700, -1050), Vector2(1450, 1900), Color(0.10, 0.31, 0.21, 0.82), 8.2)
	_draw_world_blob(Vector2(720, -1450), Vector2(1050, 1350), Color(0.13, 0.36, 0.22, 0.72), 5.5)
	_draw_world_blob(Vector2(-2860, -2250), Vector2(1320, 980), Color(0.38, 0.42, 0.39, 0.72), 1.9)
	_draw_world_blob(Vector2(2700, -2380), Vector2(1240, 980), Color(0.40, 0.43, 0.39, 0.72), 9.1)
	_draw_world_blob(Vector2(-820, 3000), Vector2(1650, 980), Color(0.38, 0.47, 0.35, 0.74), 7.2)
	_draw_world_blob(Vector2(4380, -1420), Vector2(1720, 1420), Color(0.055, 0.16, 0.27, 0.94), 4.3)


func _draw_rias_and_fossa() -> void:
	var tide := _tide_amount()
	for ria in RIAS:
		var points := PackedVector2Array()
		for world_point in ria:
			points.append(_world_to_map(world_point))
		draw_polyline(points, Color(0.13, 0.34, 0.48, 0.58), (10.0 if full_map else 4.2) + tide * 3.0, true)
		draw_polyline(points, Color(0.24, 0.62, 0.73, 0.96), (4.2 if full_map else 1.8) + tide * 2.2, true)
	for branch in FOSSA_BRANCHES:
		var points := PackedVector2Array()
		for world_point in branch:
			points.append(_world_to_map(world_point))
		draw_polyline(points, Color(0.12, 0.075, 0.055, 0.98), 8.0 if full_map else 3.5, true)
		draw_polyline(points, Color(0.78, 0.39, 0.16, 0.92), 2.0 if full_map else 1.0, true)


func _draw_roads() -> void:
	for road in ROADS:
		var points := PackedVector2Array()
		for world_point in road:
			points.append(_world_to_map(world_point))
		draw_polyline(points, Color(0.27, 0.13, 0.055, 0.72), 5.5 if full_map else 2.6, true)
		draw_polyline(points, Color(0.91, 0.60, 0.23, 0.98), 2.6 if full_map else 1.25, true)


func _draw_points_of_interest() -> void:
	var font := ThemeDB.fallback_font
	for poi in POINTS_OF_INTEREST:
		var point := _world_to_map(poi.point)
		var color := Color(1.0, 0.74, 0.28)
		if poi.kind == "forest":
			color = Color(0.45, 0.86, 0.48)
		elif poi.kind == "mountain":
			color = Color(0.84, 0.93, 1.0)
		elif poi.kind == "grotto":
			color = Color(0.96, 0.52, 0.22)
		elif poi.kind == "mystery":
			color = Color(0.25, 0.78, 0.94)
		draw_circle(point, 5.0 if full_map else 3.0, color)
		if full_map:
			draw_string(font, point + Vector2(9, 6), poi.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.12, 0.07, 0.035, 0.88))
			draw_string(font, point + Vector2(8, 5), poi.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.97, 0.91, 0.72))


func _draw_player() -> void:
	if player == null:
		return
	var world_point := Vector2(player.global_position.x, player.global_position.z)
	var point := _world_to_map(world_point)
	var radius := 7.5 if full_map else 5.0
	draw_circle(point, radius + 3.0, Color(0.03, 0.05, 0.08, 0.86))
	draw_circle(point, radius, Color(1.0, 0.34, 0.19, 1.0))
	var direction := _player_map_direction()
	var tip := point + direction * (radius + 9.0)
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([tip, point + side * 3.2, point - side * 3.2]), Color(1.0, 0.97, 0.86, 1.0))
	draw_polyline(PackedVector2Array([point + side * 3.2, tip, point - side * 3.2]), Color(0.12, 0.08, 0.045, 0.86), 1.0, true)


func _draw_exploration_target() -> void:
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration == null:
		return
	var zone := exploration.call("get_selected_zone") as Dictionary
	if zone.is_empty():
		return
	var location: Vector3 = zone.position
	var point := _world_to_map(Vector2(location.x, location.z))
	var pulse := sin(float(Time.get_ticks_msec()) * 0.006) * 0.5 + 0.5
	var radius := (12.0 if full_map else 6.0) + pulse * (4.0 if full_map else 2.0)
	var gold := Color(1.0, 0.75, 0.18, 0.98)
	draw_arc(point, radius, 0.0, TAU, 32, gold, 3.0 if full_map else 1.8, true)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0.0, -8.0 if full_map else -4.0),
		point + Vector2(6.0 if full_map else 3.0, 0.0),
		point + Vector2(0.0, 8.0 if full_map else 4.0),
		point + Vector2(-6.0 if full_map else -3.0, 0.0),
	]), gold)
	if full_map:
		var caption := "OBJETIVO · %s" % String(zone.name)
		draw_string(ThemeDB.fallback_font, point + Vector2(16.0, -11.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.16, 0.08, 0.025))
		draw_string(ThemeDB.fallback_font, point + Vector2(15.0, -12.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.91, 0.56))


func _player_map_direction() -> Vector2:
	if player != null and player.has_method("get_facing_direction_xz"):
		return (player.call("get_facing_direction_xz") as Vector2).normalized()
	return Vector2.UP


func _draw_world_blob(center: Vector2, radii: Vector2, color: Color, seed: float) -> void:
	var points := PackedVector2Array()
	for index in 64:
		var angle := TAU * float(index) / 64.0
		var distortion := 1.0 + sin(angle * 3.0 + seed) * 0.12
		distortion += sin(angle * 7.0 - seed * 0.63) * 0.065
		var candidate := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * distortion
		points.append(_world_to_map(candidate))
	# Intersección poligonal real: conserva la forma orgánica y evita manchas
	# fuera del litoral sin crear puntos repetidos ni autointersecciones.
	var clipped_polygons := Geometry2D.intersect_polygons(points, _island_polygon(0.885))
	for clipped in clipped_polygons:
		if clipped.size() < 3:
			continue
		draw_colored_polygon(clipped, color)
		draw_polyline(clipped + PackedVector2Array([clipped[0]]), color.darkened(0.28), 1.4 if full_map else 0.7, true)


func _draw_contours_and_symbols() -> void:
	for ratio in [0.42, 0.58, 0.72]:
		var contour := PackedVector2Array()
		for index in 96:
			var angle := TAU * float(index) / 96.0
			var radius: float = _coast_radius_at_angle(angle) * float(ratio)
			contour.append(_world_to_map(Vector2(cos(angle), sin(angle)) * radius))
		draw_polyline(contour + PackedVector2Array([contour[0]]), Color(0.25, 0.16, 0.075, 0.18), 1.0, true)
	for mountain in [Vector2(180, -3350), Vector2(-2850, -2200), Vector2(2700, -2350), Vector2(-980, 2940)]:
		_draw_mountain_symbol(_world_to_map(mountain), 11.0 if full_map else 5.0)
	for forest in [Vector2(-2180, 1650), Vector2(-3300, 650), Vector2(760, -1550), Vector2(3900, -1250), Vector2(4650, -1650), Vector2(5050, -650)]:
		_draw_tree_symbol(_world_to_map(forest), 8.5 if full_map else 3.8, forest.x > 3500.0)


func _draw_mountain_symbol(point: Vector2, scale_value: float) -> void:
	var dark := Color(0.25, 0.20, 0.15, 0.74)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-scale_value, scale_value * 0.72), point + Vector2(0, -scale_value), point + Vector2(scale_value, scale_value * 0.72)]), Color(0.44, 0.43, 0.39, 0.84))
	draw_polyline(PackedVector2Array([point + Vector2(-scale_value, scale_value * 0.72), point + Vector2(0, -scale_value), point + Vector2(scale_value, scale_value * 0.72)]), dark, 1.2, true)


func _draw_tree_symbol(point: Vector2, scale_value: float, mystery: bool) -> void:
	var leaf := Color(0.055, 0.20, 0.30, 0.94) if mystery else Color(0.08, 0.31, 0.17, 0.92)
	draw_line(point + Vector2(0, scale_value * 0.45), point + Vector2(0, scale_value), Color(0.28, 0.16, 0.07), 1.5, true)
	for tier in 3:
		var y := -scale_value * 0.72 + tier * scale_value * 0.42
		var width := scale_value * (0.58 - tier * 0.10)
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, y - scale_value * 0.38), point + Vector2(-width, y + scale_value * 0.35), point + Vector2(width, y + scale_value * 0.35)]), leaf)


func _draw_sea_marks() -> void:
	var ink := Color(0.12, 0.34, 0.42, 0.34)
	for row in 4:
		for column in 7:
			if (row + column) % 2 == 0:
				var origin := Vector2(55.0 + column * size.x / 7.4, 72.0 + row * size.y / 4.8)
				draw_arc(origin, 8.0 if full_map else 3.5, PI * 1.10, PI * 1.90, 10, ink, 1.2, true)


func _draw_compass_rose(center: Vector2, radius: float) -> void:
	var ink := Color(0.29, 0.14, 0.055, 0.88)
	draw_circle(center, radius, Color(0.88, 0.70, 0.38, 0.35))
	draw_arc(center, radius, 0.0, TAU, 32, ink, 2.0, true)
	for index in 8:
		var angle := TAU * float(index) / 8.0 - PI * 0.5
		var length := radius * (0.92 if index % 2 == 0 else 0.62)
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * length, ink, 2.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-5, -radius - 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)


func _island_polygon(ratio: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in 120:
		var angle := TAU * float(index) / 120.0
		var radius := _coast_radius_at_angle(angle) * ratio
		polygon.append(_world_to_map(Vector2(cos(angle), sin(angle)) * radius))
	return polygon


func _coast_radius_at_angle(angle: float) -> float:
	var cosine := cos(angle)
	var sine := sin(angle)
	var ellipse_radius := 1.0 / sqrt((cosine * cosine) / (4740.0 * 4740.0) + (sine * sine) / (4540.0 * 4540.0))
	var mystery_angle := atan2(sin(angle + 0.27), cos(angle + 0.27))
	var extension := 1200.0 * exp(-(mystery_angle * mystery_angle) / (2.0 * 0.27 * 0.27))
	var desert_angle := atan2(sin(angle - 0.50), cos(angle - 0.50))
	var desert_shoulder := 420.0 * exp(-(desert_angle * desert_angle) / (2.0 * 0.32 * 0.32))
	var north_neck_angle := atan2(sin(angle + 0.82), cos(angle + 0.82))
	var north_inlet := 350.0 * exp(-(north_neck_angle * north_neck_angle) / (2.0 * 0.20 * 0.20))
	var south_neck_angle := atan2(sin(angle - 0.04), cos(angle - 0.04))
	var south_inlet := 430.0 * exp(-(south_neck_angle * south_neck_angle) / (2.0 * 0.18 * 0.18))
	var wobble := sin(angle * 7.0) * 0.018 + sin(angle * 13.0 + 0.7) * 0.009
	return (ellipse_radius + extension + desert_shoulder - north_inlet - south_inlet) / (1.0 + wobble)


func _tide_amount() -> float:
	return float(island_environment.get("tide_normalized")) if island_environment != null else 0.5


func _world_to_map(world_point: Vector2) -> Vector2:
	var margin := 13.0 if not full_map else 42.0
	var usable := size - Vector2.ONE * margin * 2.0
	var normalized := Vector2(world_point.x / WORLD_HALF, world_point.y / WORLD_HALF) * 0.5 + Vector2(0.5, 0.5)
	return Vector2(margin, margin) + Vector2(normalized.x * usable.x, normalized.y * usable.y)
