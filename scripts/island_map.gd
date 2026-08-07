class_name IslandMapView
extends Control

## Mapa vectorial de la isla. No usa una captura estática: carreteras, biomas,
## pueblos y marcador del jugador se dibujan en coordenadas reales del mundo.

const WORLD_HALF := 5000.0
const ROADS: Array = [
	[Vector2(0, 190), Vector2(-120, 520), Vector2(-420, 760), Vector2(-980, 780), Vector2(-1450, 650)],
	[Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)],
	[Vector2(-1450, 650), Vector2(-1780, 230), Vector2(-2050, -420), Vector2(-2200, -900)],
	[Vector2(0, 190), Vector2(620, 320), Vector2(1260, 120), Vector2(1840, -420), Vector2(2260, -980)],
	[Vector2(620, 320), Vector2(1120, 820), Vector2(1660, 1320), Vector2(2180, 1880)],
	[Vector2(-1450, 650), Vector2(-1850, 1120), Vector2(-2180, 1650)],
	[Vector2(-420, -2150), Vector2(260, -2500), Vector2(720, -3080)],
	[Vector2(98, -110), Vector2(420, -420), Vector2(920, -560), Vector2(1840, -420)],
]
const POINTS_OF_INTEREST: Array = [
	{"name": "Puerto Alba", "point": Vector2(0, 190), "kind": "village"},
	{"name": "Villa Robledal", "point": Vector2(-1450, 650), "kind": "castle"},
	{"name": "Aldea de la Bruma", "point": Vector2(-2200, -900), "kind": "village"},
	{"name": "Bastion del Este", "point": Vector2(2260, -980), "kind": "castle"},
	{"name": "Oasis Dorado", "point": Vector2(2180, 1880), "kind": "village"},
	{"name": "Castillo Boreal", "point": Vector2(-420, -2150), "kind": "castle"},
	{"name": "Bosque Umbrio", "point": Vector2(-2180, 1650), "kind": "forest"},
	{"name": "Cumbres Blancas", "point": Vector2(520, -3000), "kind": "mountain"},
]

@export var player_path: NodePath = NodePath("../../Player")
@export var full_map := false
@onready var player: Node3D = get_node_or_null(player_path) as Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func get_road_count() -> int:
	return ROADS.size()


func get_poi_count() -> int:
	return POINTS_OF_INTEREST.size()


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.025, 0.055, 0.075, 0.92 if full_map else 0.82), true)
	draw_rect(panel.grow(-3.0), Color(0.45, 0.74, 0.78, 0.72), false, 2.0)
	_draw_island()
	_draw_biomes()
	_draw_roads()
	_draw_points_of_interest()
	_draw_player()
	var font := ThemeDB.fallback_font
	if full_map:
		draw_string(font, Vector2(24, 34), "ISLA DE LOS SENDEROS · 100 km²", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.9, 0.68))
		draw_string(font, Vector2(24, size.y - 18), "1 Dunas · 2 Nieve · 3 Villa · 4 Bosque · M cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.88, 0.92, 0.94))
	else:
		draw_string(font, Vector2(12, 21), "ISLA · M", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.68))


func _draw_island() -> void:
	var island := PackedVector2Array()
	for index in 72:
		var angle := TAU * float(index) / 72.0
		var wobble := 1.0 + sin(angle * 7.0) * 0.022 + sin(angle * 13.0 + 0.7) * 0.012
		island.append(_world_to_map(Vector2(cos(angle) * 4740.0 * wobble, sin(angle) * 4540.0 * wobble)))
	draw_colored_polygon(island, Color(0.31, 0.57, 0.31, 1.0))
	draw_polyline(island + PackedVector2Array([island[0]]), Color(0.84, 0.78, 0.52), 2.0, true)


func _draw_biomes() -> void:
	_draw_world_ellipse(Vector2(2350, 2050), Vector2(1320, 1120), Color(0.86, 0.62, 0.25, 0.84))
	_draw_world_ellipse(Vector2(180, -3040), Vector2(1500, 920), Color(0.82, 0.9, 0.96, 0.88))
	_draw_world_ellipse(Vector2(-2180, 1650), Vector2(720, 650), Color(0.08, 0.25, 0.16, 0.88))
	_draw_world_ellipse(Vector2(-2200, -900), Vector2(760, 650), Color(0.12, 0.31, 0.22, 0.76))
	_draw_world_ellipse(Vector2(760, -1550), Vector2(620, 760), Color(0.12, 0.36, 0.2, 0.72))
	_draw_world_ellipse(Vector2(-3180, -850), Vector2(620, 1050), Color(0.39, 0.43, 0.4, 0.76))


func _draw_roads() -> void:
	for road in ROADS:
		var points := PackedVector2Array()
		for world_point in road:
			points.append(_world_to_map(world_point))
		draw_polyline(points, Color(0.96, 0.71, 0.28, 0.98), 3.0 if full_map else 1.5, true)


func _draw_points_of_interest() -> void:
	var font := ThemeDB.fallback_font
	for poi in POINTS_OF_INTEREST:
		var point := _world_to_map(poi.point)
		var color := Color(1.0, 0.74, 0.28)
		if poi.kind == "forest":
			color = Color(0.45, 0.86, 0.48)
		elif poi.kind == "mountain":
			color = Color(0.84, 0.93, 1.0)
		draw_circle(point, 5.0 if full_map else 3.0, color)
		if full_map:
			draw_string(font, point + Vector2(8, 5), poi.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.96, 0.96, 0.91))


func _draw_player() -> void:
	if player == null:
		return
	var world_point := Vector2(player.global_position.x, player.global_position.z)
	var point := _world_to_map(world_point)
	var radius := 7.5 if full_map else 5.0
	draw_circle(point, radius + 3.0, Color(0.03, 0.05, 0.08, 0.86))
	draw_circle(point, radius, Color(1.0, 0.34, 0.19, 1.0))
	var direction := Vector2(sin(player.global_rotation.y), -cos(player.global_rotation.y))
	draw_line(point, point + direction * (radius + 7.0), Color.WHITE, 2.0, true)


func _draw_world_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 40:
		var angle := TAU * float(index) / 40.0
		points.append(_world_to_map(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)))
	draw_colored_polygon(points, color)


func _world_to_map(world_point: Vector2) -> Vector2:
	var margin := 13.0 if not full_map else 34.0
	var usable := size - Vector2.ONE * margin * 2.0
	var normalized := Vector2(world_point.x / WORLD_HALF, world_point.y / WORLD_HALF) * 0.5 + Vector2(0.5, 0.5)
	return Vector2(margin, margin) + Vector2(normalized.x * usable.x, normalized.y * usable.y)
