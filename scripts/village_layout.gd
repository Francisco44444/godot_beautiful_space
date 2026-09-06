class_name VillageLayout
extends RefCounted

const CENTER := Vector2(-1450, 650)
const YAW := 0.42
const RADIUS := 370.0
const PITCH := 60.0
const SETBACK := 46.0
const SECOND_RANK := 112.0
const RESERVE := 54.0
const SCALE := Vector3(2.4, 2.4, 2.4)
const CASTLE := Rect2(57, -53, 136, 112)
static var _plots: Array[Dictionary] = []


static func plots() -> Array[Dictionary]:
	if not _plots.is_empty():
		return _plots
	var candidates: Array[Dictionary] = []
	var reach := int(RADIUS / PITCH)
	for step in range(-reach, reach + 1):
		if step == 0:
			continue
		for side in [-1.0, 1.0]:
			candidates.append({"offset": Vector2(side * SETBACK, step * PITCH), "facing": -side * PI * 0.5, "hall": false})
	for step in range(-reach, reach):
		for side in [-1.0, 1.0]:
			candidates.append({"offset": Vector2(side * SECOND_RANK, (step + 0.5) * PITCH), "facing": -side * PI * 0.5, "hall": false})
	for step in range(-reach, reach + 1):
		if absf(step * PITCH) < SETBACK + PITCH * 0.5:
			continue
		for side in [-1.0, 1.0]:
			candidates.append({"offset": Vector2(step * PITCH, side * SETBACK), "facing": PI if side > 0 else 0.0, "hall": false})
	candidates.append({"offset": Vector2(0, RADIUS - 18), "facing": PI, "hall": true})
	candidates.append({"offset": Vector2(0, -RADIUS + 18), "facing": 0.0, "hall": true})
	var reserved: Array[Rect2] = []
	for candidate in candidates:
		var claim := Rect2(candidate.offset - Vector2.ONE * RESERVE * 0.5, Vector2.ONE * RESERVE)
		if claim.intersects(CASTLE.grow(4.0)):
			continue
		var occupied := false
		for existing in reserved:
			if existing.intersects(claim):
				occupied = true
				break
		if not occupied:
			reserved.append(claim)
			_plots.append(candidate)
	return _plots


static func street_segments() -> Array:
	return [
		[Vector2(0, -RADIUS + 50), Vector2(0, RADIUS - 50), 5.0],
		[Vector2(-RADIUS, 0), Vector2(RADIUS, 0), 5.0],
		[Vector2(-79, -RADIUS), Vector2(-79, RADIUS), 3.0],
		[Vector2(79, -RADIUS), Vector2(79, RADIUS), 3.0],
		[Vector2(0, -90), Vector2(79, -90), 3.0],
		[Vector2(0, 90), Vector2(79, 90), 3.0],
		[Vector2(79, -120), Vector2(210, -120), 3.0],
		[Vector2(79, 120), Vector2(210, 120), 3.0],
		[Vector2(210, -120), Vector2(210, 120), 3.0],
	]


static func nearest_street(local: Vector2) -> Vector2:
	var nearest := Vector2.ZERO
	var distance := INF
	for segment in street_segments():
		var candidate := Geometry2D.get_closest_point_to_segment(local, segment[0], segment[1])
		if candidate.distance_squared_to(local) < distance:
			distance = candidate.distance_squared_to(local)
			nearest = candidate
	return nearest


static func occupies(world_point: Vector2, padding: float = 0.0) -> bool:
	var local := (world_point - CENTER).rotated(-YAW)
	if absf(local.x) > RADIUS + RESERVE + padding or absf(local.y) > RADIUS + RESERVE + padding:
		return false
	for plot in plots():
		if Rect2(plot.offset - Vector2.ONE * RESERVE * 0.5, Vector2.ONE * RESERVE).grow(padding).has_point(local):
			return true
	for segment in street_segments():
		if local.distance_to(Geometry2D.get_closest_point_to_segment(local, segment[0], segment[1])) < float(segment[2]) + 3.0 + padding:
			return true
	return false
