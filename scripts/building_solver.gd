class_name BuildingSolver
extends RefCounted

## Resuelve la geometría de un edificio ANTES de instanciar nada.
##
## El generador del taller de casas construía cada cuerpo como una caja cerrada
## independiente, con pared en sus cuatro lados y sin saber nada de sus vecinos;
## y los cuerpos se declaraban en metros con centros arbitrarios, así que se
## solapaban medio módulo. Resultado medido: la cara compartida recibía pared de
## los dos cuerpos —dos módulos idénticos en la misma ranura, 0.41 x 3.12 x 2.00
## m de solape— y el tejado del ala baja cortaba el interior del cuerpo alto,
## hasta 3.77 m por debajo del alero, más de una planta entera.
##
## Aquí se invierte la responsabilidad: la pared no pertenece a un cuerpo, sino
## a una ARISTA de la rejilla, y todo se declara en CELDAS ENTERAS de 2 m. Con
## claves enteras el solape no se evita: no se puede expresar. Una celda tiene
## exactamente un dueño, y si dos cuerpos la reclaman es un error de receta que
## se reporta, no un artefacto que aparece al mirar la casa por dentro.

const CELL := 2.0
const STOREY := 3.1
## Cuánto puede caer la falda de un faldón por debajo de su propio alero. Las
## piezas del kit caen entre 0.516 y 0.782 m, medido; por encima de esto la
## cubierta ya no es un alero sino un muro tapado.
const MAX_SKIRT_DROP := 0.80
## Un tejado puede asomar sobre un vecino más alto, pero no puede meterse dentro:
## este es el margen que se le perdona antes de considerarlo invasión.
const ROOF_INTRUSION_TOLERANCE := 0.02
## Longitud del tramo, en módulos. Con 3 la pendiente sale a 27.3 grados, que es
## escalera de casa; con el fondo completo se queda en 17 y no se sube, se rampea.
const STAIR_RUN_CELLS := 3
const MIN_STAIR_PITCH := 20.0
const MAX_STAIR_PITCH := 32.0
## Tramos por vuelta del caracol y hueco que se le deja al muro.
const SPIRAL_STEPS := 4
const SPIRAL_MARGIN := 0.45

enum Face { EXTERIOR, PARTY, NONE }
enum Opening { SOLID, DOOR, ARCH }

## Plan resultante: listas planas listas para instanciar, más el informe.
var walls: Array[Dictionary] = []
var floors_plan: Array[Dictionary] = []
var stairs: Array[Dictionary] = []
var roofs: Array[Dictionary] = []
var report: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()

var _owner: Dictionary = {}
var _edges: Dictionary = {}


func solve(recipe: Dictionary, roof_metrics: Dictionary = {}) -> bool:
	## Devuelve false si la receta es inconsistente. `roof_metrics` asocia el
	## nombre de cada malla de tejado con su AABB medida, para poder anclar la
	## cubierta a una medida real y no a una constante mágica.
	walls.clear()
	floors_plan.clear()
	stairs.clear()
	roofs.clear()
	report.clear()
	errors = PackedStringArray()
	_owner.clear()
	_edges.clear()
	var volumes: Array = recipe.get("volumes", [])
	if volumes.is_empty():
		errors.append("La receta '%s' no declara ningún cuerpo." % recipe.get("id", "?"))
		return false
	_claim_cells(volumes)
	_build_edge_ledger(volumes)
	_plan_floors(volumes)
	_plan_stairs(volumes)
	_plan_roofs(volumes, roof_metrics)
	_check_reachability(volumes)
	report = {
		"cell_conflicts": int(report.get("cell_conflicts", 0)),
		"duplicate_edges": int(report.get("duplicate_edges", 0)),
		"wall_count": walls.size(),
		"floor_count": floors_plan.size(),
		"stair_count": stairs.size(),
		"roof_count": roofs.size(),
		"roof_below_eave_count": int(report.get("roof_below_eave_count", 0)),
		"worst_roof_dip": float(report.get("worst_roof_dip", 0.0)),
		"unsupported_cells": int(report.get("unsupported_cells", 0)),
		"unreachable_cells": int(report.get("unreachable_cells", 0)),
		"door_count": int(report.get("door_count", 0)),
		"arch_count": int(report.get("arch_count", 0)),
		"errors": errors.size(),
	}
	return errors.is_empty()


func _claim_cells(volumes: Array) -> void:
	## Cada celda de cada planta tiene exactamente un dueño. Dos reclamaciones
	## son un conflicto exacto: claves enteras, sin epsilon ni tolerancia.
	var conflicts := 0
	var unsupported := 0
	for index in volumes.size():
		var volume: Dictionary = volumes[index]
		var origin: Vector2i = volume["origin"]
		var size: Vector2i = volume["size"]
		var base_level := int(volume.get("base_level", 0))
		var floors := int(volume["floors"])
		for level in range(base_level, base_level + floors):
			for i in range(origin.x, origin.x + size.x):
				for j in range(origin.y, origin.y + size.y):
					var key := Vector3i(i, j, level)
					if _owner.has(key):
						conflicts += 1
						errors.append(
							"Los cuerpos '%s' y '%s' reclaman la celda (%d, %d) en la planta %d."
							% [volumes[_owner[key]]["name"], volume["name"], i, j, level]
						)
						continue
					_owner[key] = index
	# Un cuerpo elevado necesita apoyo debajo, o flota.
	for index in volumes.size():
		var volume: Dictionary = volumes[index]
		var base_level := int(volume.get("base_level", 0))
		if base_level <= 0:
			continue
		var origin: Vector2i = volume["origin"]
		var size: Vector2i = volume["size"]
		for i in range(origin.x, origin.x + size.x):
			for j in range(origin.y, origin.y + size.y):
				if not _owner.has(Vector3i(i, j, base_level - 1)):
					unsupported += 1
	if unsupported > 0:
		errors.append("Hay %d celdas de cuerpo elevado sin apoyo debajo." % unsupported)
	report["cell_conflicts"] = conflicts
	report["unsupported_cells"] = unsupported


func _build_edge_ledger(volumes: Array) -> void:
	## Una arista, un muro. Se recorren las celdas ocupadas y se anota, por cada
	## una de sus cuatro caras, quién la reclama. Una arista con una sola
	## reclamación es fachada; con dos de cuerpos distintos, medianera —y se
	## levanta UNA sola vez—; con dos del mismo cuerpo, interior de estancia y no
	## se levanta nada. Aquí es donde muere el muro doblado.
	var duplicates := 0
	for key in _owner:
		var cell: Vector3i = key
		var index: int = _owner[key]
		for side in 4:
			var edge := _edge_key(cell, side)
			if not _edges.has(edge):
				_edges[edge] = []
			var claims: Array = _edges[edge]
			if claims.size() >= 2:
				duplicates += 1
				continue
			claims.append({"cell": cell, "volume": index, "side": side})
	report["duplicate_edges"] = duplicates
	for edge in _edges:
		var claims: Array = _edges[edge]
		if claims.is_empty():
			continue
		var first: Dictionary = claims[0]
		var kind := Face.EXTERIOR
		if claims.size() == 2:
			kind = Face.NONE if claims[0]["volume"] == claims[1]["volume"] else Face.PARTY
		if kind == Face.NONE:
			continue
		var volume: Dictionary = volumes[first["volume"]]
		walls.append({
			"edge": edge,
			"kind": kind,
			"cell": first["cell"],
			"side": first["side"],
			"volume": first["volume"],
			"style": volume.get("style", "stone"),
			"level": (first["cell"] as Vector3i).z,
			"opening": Opening.SOLID,
			"pair": _pair_key(claims),
		})
	_open_party_arches()
	_open_doors(volumes)


func _pair_key(claims: Array) -> Vector2i:
	if claims.size() < 2:
		return Vector2i(-1, -1)
	var a := int(claims[0]["volume"])
	var b := int(claims[1]["volume"])
	return Vector2i(mini(a, b), maxi(a, b))


func _open_party_arches() -> void:
	## Una medianera ciega deja el ala incomunicada, pero abrirla entera la
	## convierte en un porche. Se abre UN arco por planta y por pareja de
	## cuerpos, el del medio del tramo compartido, y el resto queda macizo.
	var groups := {}
	for index in walls.size():
		var wall: Dictionary = walls[index]
		if int(wall["kind"]) != Face.PARTY:
			continue
		var pair: Vector2i = wall["pair"]
		var key := Vector3i(pair.x, pair.y, int(wall["level"]))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(index)
	for key in groups:
		var members: Array = groups[key]
		members.sort()
		walls[members[members.size() / 2]]["opening"] = Opening.ARCH


func _open_doors(volumes: Array) -> void:
	## La puerta no es decoración: es el único hueco por el que se entra, y sin
	## ella la casa es una caja preciosa y cerrada. Se declara en la receta como
	## un lado del cuerpo y un módulo a lo largo de ese lado.
	for index in volumes.size():
		var volume: Dictionary = volumes[index]
		var door = volume.get("door", null)
		if door == null:
			continue
		var origin: Vector2i = volume["origin"]
		var size: Vector2i = volume["size"]
		var side := int(door["side"])
		var module := int(door["module"])
		var target := _door_edge(origin, size, side, module)
		var placed := false
		for wall in walls:
			if wall["edge"] == target and int(wall["level"]) == 0:
				wall["opening"] = Opening.DOOR
				placed = true
				break
		if not placed:
			errors.append(
				"El cuerpo '%s' declara puerta en el lado %d módulo %d, y ahí no hay fachada."
				% [volume["name"], side, module]
			)


func _door_edge(origin: Vector2i, size: Vector2i, side: int, module: int) -> Vector4i:
	## Lados: 0 = -X, 1 = +X, 2 = -Z, 3 = +Z. El módulo recorre el lado.
	match side:
		0:
			return Vector4i(0, origin.x, origin.y + module, 0)
		1:
			return Vector4i(0, origin.x + size.x, origin.y + module, 0)
		2:
			return Vector4i(1, origin.x + module, origin.y, 0)
		_:
			return Vector4i(1, origin.x + module, origin.y + size.y, 0)


func _edge_key(cell: Vector3i, side: int) -> Vector4i:
	## Identidad entera y canónica de una arista: dos celdas vecinas comparten
	## exactamente la misma clave, sea cual sea desde cuál se mire.
	match side:
		0:
			return Vector4i(0, cell.x, cell.y, cell.z)
		1:
			return Vector4i(0, cell.x + 1, cell.y, cell.z)
		2:
			return Vector4i(1, cell.x, cell.y, cell.z)
		_:
			return Vector4i(1, cell.x, cell.y + 1, cell.z)


func _plan_floors(volumes: Array) -> void:
	for index in volumes.size():
		var volume: Dictionary = volumes[index]
		var base_level := int(volume.get("base_level", 0))
		var floors := int(volume["floors"])
		for level in range(base_level, base_level + floors):
			floors_plan.append({
				"volume": index,
				"level": level,
				"origin": volume["origin"],
				"size": volume["size"],
				"y": float(level) * STOREY,
			})


func _plan_stairs(volumes: Array) -> void:
	## Dos tramos por transición de planta, uno a cada lado del cuerpo, y en cada
	## transición se invierte el sentido: es una ida y vuelta de verdad, se llega
	## arriba andando y sin saltar. La casa del juego sólo tenía UN tramo por
	## planta, alternando el lado, y para subir había que cruzar la planta entera.
	##
	## Todo se calcula en CELDAS, incluido el hueco que el tramo abre en el
	## forjado de arriba. Sin ese hueco la escalera sube contra el techo y la
	## planta alta es inalcanzable por mucho que la escalera exista.
	for index in volumes.size():
		var volume: Dictionary = volumes[index]
		if not bool(volume.get("stairs", false)):
			continue
		var size: Vector2i = volume["size"]
		if size.x < 3 or size.y < 5:
			# Una torre no da para un tramo recto: sube en caracol, como suben
			# las torres de verdad. Cuatro cuartos de vuelta por planta.
			if size.x >= 2 and size.y >= 2:
				_plan_spiral(index, volume)
				continue
			errors.append(
				"El cuerpo '%s' lleva escaleras pero mide %dx%d celdas: hacen falta 3x5."
				% [volume["name"], size.x, size.y]
			)
			continue
		var origin: Vector2i = volume["origin"]
		var base_level := int(volume.get("base_level", 0))
		var floors := int(volume["floors"])
		var run_start := origin.y + (size.y - STAIR_RUN_CELLS) / 2
		var run := float(STAIR_RUN_CELLS) * CELL
		var pitch := rad_to_deg(atan(STOREY / run))
		if pitch < MIN_STAIR_PITCH or pitch > MAX_STAIR_PITCH:
			errors.append(
				"La escalera de '%s' tiene %.1f grados, fuera del rango %.0f-%.0f."
				% [volume["name"], pitch, MIN_STAIR_PITCH, MAX_STAIR_PITCH]
			)
		for transition in range(floors - 1):
			var level := base_level + transition
			var ascending := transition % 2 == 0
			# El tramo de vuelta se corre una celda. Si no, su pie cae justo en
			# el borde del hueco que abrió el tramo de ida en este mismo forjado,
			# y quien sube se despeña por él en lugar de seguir subiendo.
			# Medido: la cápsula subía 2 de los 4 tramos de un hall.
			var start := run_start + (0 if ascending else 1)
			# El tramo siguiente no puede volver sobre la cabeza de quien acaba
			# de subir. Alternar también la columna deja libre el desembarco y
			# permite rodear el arranque siguiente desde el descansillo frontal.
			var inset := 1 if not ascending and size.x >= 4 else 0
			for column in [origin.x + inset, origin.x + size.x - 1 - inset]:
				# El hueco cubre los dos tramos de celda donde el gálibo bajo el
				# forjado cae por debajo de dos metros. El primero deja 2.07 m
				# libres y se puede pasar por debajo, así que se queda macizo.
				var holes: Array[Vector2i] = []
				for step in range(1, STAIR_RUN_CELLS):
					var j := start + (step if ascending else STAIR_RUN_CELLS - 1 - step)
					holes.append(Vector2i(column, j))
				stairs.append({
					"volume": index,
					"level": level,
					"kind": "straight",
					"column_cell": column,
					"run_start": start,
					"ascending": ascending,
					"x": (float(column) + 0.5) * CELL,
					"direction": 1.0 if ascending else -1.0,
					"base_y": float(level) * STOREY,
					"top_y": float(level + 1) * STOREY,
					"run": run,
					"pitch_degrees": pitch,
					"holes": holes,
				})


func _plan_spiral(index: int, volume: Dictionary) -> void:
	## Caracol de cuatro tramos por planta alrededor de un machón central. El
	## radio medio sale del propio cuerpo, así que una torre más ancha da una
	## escalera más tendida sin tocar una constante.
	var size: Vector2i = volume["size"]
	var base_level := int(volume.get("base_level", 0))
	var floors := int(volume["floors"])
	var radius := (minf(float(size.x), float(size.y)) * CELL) * 0.5 - SPIRAL_MARGIN
	if radius <= 0.4:
		errors.append("La torre '%s' es demasiado estrecha para un caracol." % volume["name"])
		return
	var rise := STOREY / float(SPIRAL_STEPS)
	var run := (TAU / float(SPIRAL_STEPS)) * radius
	var pitch := rad_to_deg(atan(rise / run))
	if pitch > MAX_STAIR_PITCH:
		errors.append(
			"El caracol de '%s' sube a %.1f grados, más de %.0f."
			% [volume["name"], pitch, MAX_STAIR_PITCH]
		)
	for transition in range(floors - 1):
		var level := base_level + transition
		for step in SPIRAL_STEPS:
			stairs.append({
				"volume": index,
				"level": level,
				"kind": "spiral",
				"step": step,
				"radius": radius,
				"x": 0.0,
				"direction": 1.0,
				"base_y": float(level) * STOREY + rise * float(step),
				"top_y": float(level) * STOREY + rise * float(step + 1),
				"run": run,
				"pitch_degrees": pitch,
			})


func _plan_roofs(volumes: Array, roof_metrics: Dictionary) -> void:
	## La cumbrera y los hastiales permanecen centrados sobre sus muros. El
	## alero que toca una medianera se recorta: desplazar toda la cubierta dejaba
	## el hastial fuera de la fachada y un hueco abierto sobre el muro opuesto.
	var below := 0
	var worst := 0.0
	for index in volumes.size():
		var volume: Dictionary = volumes[index]
		var mesh_name := String(volume.get("roof", ""))
		if mesh_name.is_empty():
			continue
		var size: Vector2i = volume["size"]
		var base_level := int(volume.get("base_level", 0))
		var floors := int(volume["floors"])
		var wall_top := float(base_level + floors) * STOREY
		var overhang := Vector2.ZERO
		var skirt_drop := 0.0
		if roof_metrics.has(mesh_name):
			var box: AABB = roof_metrics[mesh_name]
			skirt_drop = maxf(-box.position.y, 0.0)
			overhang = Vector2(
				maxf(box.size.x * 0.5 - float(size.x) * CELL * 0.5, 0.0),
				maxf(box.size.z * 0.5 - float(size.y) * CELL * 0.5, 0.0)
			)
		var skirt_bottom := wall_top - skirt_drop
		if skirt_drop > MAX_SKIRT_DROP:
			errors.append(
				"El faldón de '%s' cae %.2f m bajo su alero (máximo %.2f)."
				% [volume["name"], skirt_drop, MAX_SKIRT_DROP]
			)
		var footprint := _footprint_rect(volume)
		var plan := footprint.grow_individual(overhang.x, overhang.y, overhang.x, overhang.y)
		var clip_min := Vector2(-10000.0, -10000.0)
		var clip_max := Vector2(10000.0, 10000.0)
		for other_index in volumes.size():
			if other_index == index:
				continue
			var other: Dictionary = volumes[other_index]
			var other_top := float(int(other.get("base_level", 0)) + int(other["floors"])) * STOREY
			if other_top <= skirt_bottom + ROOF_INTRUSION_TOLERANCE:
				continue
			match _shared_side(volume, other):
				0:
					clip_min.x = footprint.position.x
				1:
					clip_max.x = footprint.end.x
				2:
					clip_min.y = footprint.position.y
				3:
					clip_max.y = footprint.end.y
		plan = plan.intersection(Rect2(clip_min, clip_max - clip_min))
		for other_index in volumes.size():
			if other_index == index:
				continue
			var other: Dictionary = volumes[other_index]
			var other_top := float(int(other.get("base_level", 0)) + int(other["floors"])) * STOREY
			if other_top <= skirt_bottom + ROOF_INTRUSION_TOLERANCE:
				continue
			var intrusion := _rect_overlap(plan, _footprint_rect(other))
			if intrusion <= ROOF_INTRUSION_TOLERANCE:
				continue
			below += 1
			var dip := other_top - skirt_bottom
			worst = maxf(worst, dip)
			errors.append(
				"El tejado de '%s' se mete %.2f m dentro de '%s', que le saca %.2f m."
				% [volume["name"], intrusion, other["name"], dip]
			)
		roofs.append({
			"volume": index,
			"mesh": mesh_name,
			"front": volume.get("roof_front", ""),
			"anchor_y": wall_top,
			"skirt_bottom": skirt_bottom,
			"shift": Vector2.ZERO,
			"clip_min": clip_min,
			"clip_max": clip_max,
			"overhang": overhang,
		})
	report["roof_below_eave_count"] = below
	report["worst_roof_dip"] = worst


func _footprint_rect(volume: Dictionary) -> Rect2:
	var origin: Vector2i = volume["origin"]
	var size: Vector2i = volume["size"]
	return Rect2(
		Vector2(float(origin.x), float(origin.y)) * CELL,
		Vector2(float(size.x), float(size.y)) * CELL
	)


func _roof_rect(volume: Dictionary, overhang: Vector2, shift: Vector2) -> Rect2:
	var rect := _footprint_rect(volume)
	return Rect2(rect.position - overhang + shift, rect.size + overhang * 2.0)


func _rect_overlap(a: Rect2, b: Rect2) -> float:
	## Cuánto se solapan dos huellas por su lado más corto: 0 si sólo se tocan.
	var x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var z := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	if x <= 0.0 or z <= 0.0:
		return 0.0
	return minf(x, z)


func _shared_side(volume: Dictionary, other: Dictionary) -> int:
	## Por qué lado de `volume` cae `other`: 0 = -X, 1 = +X, 2 = -Z, 3 = +Z.
	var a := _footprint_rect(volume)
	var b := _footprint_rect(other)
	var shared_z := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y) > 0.01
	var shared_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x) > 0.01
	if shared_z and absf(b.end.x - a.position.x) < 0.01:
		return 0
	if shared_z and absf(b.position.x - a.end.x) < 0.01:
		return 1
	if shared_x and absf(b.end.y - a.position.y) < 0.01:
		return 2
	if shared_x and absf(b.position.y - a.end.y) < 0.01:
		return 3
	return -1


func _check_reachability(volumes: Array) -> void:
	## La prueba de que la casa se puede recorrer: se entra por la puerta y se
	## inunda. Se pasa de una celda a la vecina si entre ellas no hay muro (misma
	## estancia) o si el muro es un arco o la propia puerta; y de una planta a la
	## siguiente por las escaleras del cuerpo. Cada celda que no se alcance es una
	## habitación tapiada, que es justo lo que tenían las casas del taller.
	var blocked := {}
	var doors := 0
	var arches := 0
	for wall in walls:
		var opening := int(wall["opening"])
		if opening == Opening.DOOR:
			doors += 1
		elif opening == Opening.ARCH:
			arches += 1
		if opening == Opening.SOLID:
			blocked[wall["edge"]] = true
	report["door_count"] = doors
	report["arch_count"] = arches

	# Por qué transición de planta tiene escaleras cada cuerpo.
	var climbable := {}
	for stair in stairs:
		climbable[Vector2i(int(stair["volume"]), int(stair["level"]))] = true

	var entrance := _entrance_cell()
	if entrance.is_empty():
		report["unreachable_cells"] = 0
		return
	var seen := {}
	var queue: Array[Vector3i] = []
	queue.append(entrance[0])
	seen[entrance[0]] = true
	while not queue.is_empty():
		var cell: Vector3i = queue.pop_back()
		for side in 4:
			var neighbour := _neighbour(cell, side)
			if not _owner.has(neighbour) or seen.has(neighbour):
				continue
			if blocked.has(_edge_key(cell, side)):
				continue
			seen[neighbour] = true
			queue.append(neighbour)
		# Subir y bajar por las escaleras del cuerpo al que pertenece la celda.
		var volume_index: int = _owner[cell]
		for step in [1, -1]:
			var above := Vector3i(cell.x, cell.y, cell.z + step)
			if not _owner.has(above) or seen.has(above):
				continue
			if int(_owner[above]) != volume_index:
				continue
			var transition := cell.z if step > 0 else cell.z - 1
			if not climbable.has(Vector2i(volume_index, transition)):
				continue
			seen[above] = true
			queue.append(above)

	var unreachable := 0
	for key in _owner:
		if not seen.has(key):
			unreachable += 1
	report["unreachable_cells"] = unreachable
	if unreachable > 0:
		errors.append(
			"Hay %d celdas a las que no se llega desde la puerta de %d que tiene el edificio."
			% [unreachable, _owner.size()]
		)


func _entrance_cell() -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	for wall in walls:
		if int(wall["opening"]) == Opening.DOOR:
			found.append(wall["cell"])
			break
	return found


func _neighbour(cell: Vector3i, side: int) -> Vector3i:
	match side:
		0:
			return Vector3i(cell.x - 1, cell.y, cell.z)
		1:
			return Vector3i(cell.x + 1, cell.y, cell.z)
		2:
			return Vector3i(cell.x, cell.y - 1, cell.z)
		_:
			return Vector3i(cell.x, cell.y + 1, cell.z)


func footprint() -> Rect2:
	## Huella total del edificio en metros, en el sistema de la receta.
	var box := Rect2()
	var first := true
	for key in _owner:
		var cell: Vector3i = key
		var rect := Rect2(float(cell.x) * CELL, float(cell.y) * CELL, CELL, CELL)
		box = rect if first else box.merge(rect)
		first = false
	return box


func door_position() -> Vector3:
	## Dónde está el umbral, ya centrado como queda el edificio montado. El mundo
	## lo necesita para posar la casa a la cota del suelo justo delante de la
	## puerta, y no a la del centro de la parcela: así se entra andando.
	var shift := centre_offset()
	for wall in walls:
		if int(wall["opening"]) != Opening.DOOR:
			continue
		var edge: Vector4i = wall["edge"]
		if edge.x == 0:
			return Vector3(float(edge.y) * CELL, 0.0, (float(edge.z) + 0.5) * CELL) + shift
		return Vector3((float(edge.y) + 0.5) * CELL, 0.0, float(edge.z) * CELL) + shift
	return shift


func door_outward() -> Vector3:
	## Hacia dónde mira la puerta, para poder buscar el suelo un paso por fuera.
	for wall in walls:
		if int(wall["opening"]) != Opening.DOOR:
			continue
		match int(wall["side"]):
			0:
				return Vector3.LEFT
			1:
				return Vector3.RIGHT
			2:
				return Vector3.FORWARD
			_:
				return Vector3.BACK
	return Vector3.BACK


func centre_offset() -> Vector3:
	## Cuánto hay que mover el edificio para que su huella quede centrada en el
	## origen. Las recetas se escriben en celdas cómodas de leer, no simétricas,
	## y sin esto cada casa aparecería descolocada de su parcela.
	var box := footprint()
	var centre := box.position + box.size * 0.5
	return Vector3(-centre.x, 0.0, -centre.y)
