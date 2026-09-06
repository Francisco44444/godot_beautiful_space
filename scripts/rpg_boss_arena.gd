class_name RPGBossArena
extends Node3D

## La arena de un jefe. Un bicho grande en mitad de un prado no impone; el mismo
## bicho en un círculo de monolitos con braseros encendidos, sí.
##
## Cada acto tiene su lugar y su material:
##   I    CÍRCULO DE RAÍCES     árboles muertos inclinados hacia dentro y huesos
##   II   LAS NUEVE PIEDRAS     monolitos y dinteles, cadenas entre ellos
##   III  OBSERVATORIO SEPULTADO muros de fortaleza medio enterrados en el hielo
##   IV   SANTUARIO SOLAR       columnata y estandartes sobre losa de arena
##   V    LA CÁMARA SIN ECO     nave en ruinas, jaulas, oro y muchas antorchas
##
## Lo único que colisiona son los monolitos y los muros: lo demás es decorado y
## no puede dejarte encerrado ni engancharte en mitad de un combate.

const NATURE := "res://assets/quaternius/Stylized Nature MegaKit[Standard]/"
const PROPS := "res://assets/quaternius/Fantasy Props MegaKit/Exports/glTF/"
const VILLAGE := "res://assets/quaternius/store_bundle/glTF/"
const CASTLE := "res://assets/quaternius/Modular Medieval Buildings - Jul 2017/OBJ/"

## Escalas medidas sobre las propias mallas. La antorcha del kit mide 0,65 m de
## alto y el muro de fortaleza 2,35: puestos a su tamaño original junto a un
## jefe de cinco metros no se ven, y la arena parecía un cementerio de lápidas.
const TORCH_SCALE := 5.2      # 0.65 m -> 3.4 m de brasero
const WALL_SCALE := 4.8       # 2.35 m -> 11.3 m de muro roto
const COIN_SCALE := 11.0      # 0.07 m -> 0.8 m de montón

var built_pieces := 0
var built_lights := 0
var _terrain: Node = null
var _rng := RandomNumberGenerator.new()
var _patina := Color(1.0, 1.0, 1.0)
var approach_bearing := 0.0
## Dónde puede refugiarse quien pelea aquí: monolitos, columnas, lo que tenga
## cuerpo. Lo usa el peligro propio de cada arena.
var shelter_points: PackedVector2Array = PackedVector2Array()
## La pieza visible de cada refugio, en el mismo orden. Sin el par, derribar un
## menhir dejaba el bulto en pie y sólo desaparecía la colisión: peor que nada,
## porque el jugador sigue viendo cobijo donde ya no lo hay.
var shelter_visuals: Array[Node3D] = []
var _last_visual: Node3D = null


func build(terrain: Node, spec: Dictionary) -> void:
	_terrain = terrain
	_rng.seed = hash(String(spec["id"]))
	var centre: Vector2 = spec["centre"]
	_floor_ring(centre, float(spec.get("floor_radius", 13.0)))
	_patina = Color(spec.get("patina", Color(1.0, 1.0, 1.0)))
	match String(spec["style"]):
		"raices":
			_roots_circle(centre, spec)
		"piedras":
			_stone_circle(centre, spec)
		"observatorio":
			_buried_keep(centre, spec)
		"solar":
			_sun_colonnade(centre, spec)
		_:
			_echoless_hall(centre, spec)
	approach_bearing = _raise_approach(centre, float(spec.get("radius", 18.0)))
	set_meta("arena_pieces", built_pieces)
	set_meta("arena_lights", built_lights)
	set_meta("approach_bearing", approach_bearing)
	# Los hitos de la cuesta también tienen cuerpo, pero están fuera: quien se
	# refugia allí no está peleando.
	var inside := PackedVector2Array()
	var kept: Array[Node3D] = []
	for index in shelter_points.size():
		if shelter_points[index].distance_to(centre) <= float(spec.get("radius", 18.0)) + 4.0:
			inside.append(shelter_points[index])
			kept.append(shelter_visuals[index] if index < shelter_visuals.size() else null)
	shelter_points = inside
	shelter_visuals = kept
	set_meta("shelter_points", shelter_points)


## La cuesta buena marcada con hitos. Sin esto una arena en una meseta es un
## sitio al que no sabes cómo se sube: das la vuelta entera y te rindes. Medido
## en el Coloso: sólo 19 de 32 rumbos son subibles, y desde abajo no se ve cuál.
func _raise_approach(centre: Vector2, radius: float) -> float:
	var best_bearing := 0.0
	var best_slope := 1e9
	for k in 16:
		var direction := Vector2.RIGHT.rotated(TAU * k / 16.0)
		var worst := 0.0
		var last: float = _height(centre + direction * 180.0)
		for step in range(1, 30):
			var span: float = 180.0 - step * 6.0
			if span < radius:
				break
			var probe: float = _height(centre + direction * span)
			if is_nan(probe) or is_nan(last):
				worst = 99.0
				break
			worst = maxf(worst, absf(probe - last) / 6.0)
			last = probe
		if worst < best_slope:
			best_slope = worst
			best_bearing = TAU * k / 16.0
	var direction := Vector2.RIGHT.rotated(best_bearing)
	var across := Vector2(-direction.y, direction.x)
	var hito := 0
	var span := 165.0
	while span > radius + 6.0:
		var side := 1.0 if hito % 2 == 0 else -1.0
		# Los hitos van menguando: de lejos leen como una escalera que sube.
		# Los hitos llevan la pátina de la arena ACLARADA hacia piedra: con el
		# tinte a pelo, una pátina oscura (la de Vaelor es 0.30,0.26,0.32) sale
		# azul eléctrico, porque el material plano se come el ambiente del cielo.
		_monolith(centre + direction * span + across * side * 5.5,
			3.4 + (span / 165.0) * 2.2, _patina.lerp(Color(0.63, 0.59, 0.54), 0.62))
		hito += 1
		span -= 22.0
	# Dos braseros al pie de la cuesta: de noche marcan por dónde se entra.
	for side in PackedFloat32Array([1.0, -1.0]):
		var foot := centre + direction * (radius + 26.0) + across * side * 6.5
		_place(PROPS + "CandleStick_Stand.gltf", foot, best_bearing, Vector3.ONE * 3.4)
		_place(PROPS + "Torch_Metal.gltf", foot, best_bearing, Vector3.ONE * TORCH_SCALE, 3.9)
		var flame := OmniLight3D.new()
		flame.name = "ArenaApproach%02d" % built_lights
		flame.position = _ground(foot, 4.6)
		flame.light_color = Color(1.0, 0.58, 0.24)
		flame.light_energy = 5.4
		flame.omni_range = 30.0
		flame.shadow_enabled = false
		flame.add_to_group("night_lantern")
		add_child(flame)
		built_lights += 1
	return best_bearing


func _height(point: Vector2) -> float:
	if _terrain == null:
		return NAN
	var data = _terrain.get("data")
	return NAN if data == null else data.get_height(Vector3(point.x, 0.0, point.y))


# --- estilos -----------------------------------------------------------------

func _roots_circle(centre: Vector2, spec: Dictionary) -> void:
	## Árboles muertos inclinados HACIA DENTRO: el círculo se cierra sobre quien
	## pelea y se lee como una trampa, no como un claro.
	var radius := float(spec.get("radius", 17.0))
	for index in 10:
		var angle := TAU * float(index) / 10.0
		var point := centre + Vector2(cos(angle), sin(angle)) * radius
		var tree := _place(NATURE + "glTF/DeadTree_%d.gltf" % (1 + index % 5),
			point, angle + PI * 0.5, Vector3.ONE * _rng.randf_range(1.6, 2.4))
		if tree != null:
			tree.rotation.x = deg_to_rad(_rng.randf_range(7.0, 15.0))
	for index in 4:
		var angle := TAU * float(index) / 4.0 + 0.4
		_monolith(centre + Vector2(cos(angle), sin(angle)) * (radius * 0.62),
			_rng.randf_range(3.4, 4.6))
	_bone_field(centre, radius * 0.55, 9)
	_braziers(centre, radius * 0.72, 4)


func _stone_circle(centre: Vector2, spec: Dictionary) -> void:
	## Nueve piedras y tres dinteles. Las cadenas cuelgan entre ellas.
	var radius := float(spec.get("radius", 16.0))
	for index in 9:
		var angle := TAU * float(index) / 9.0
		_monolith(centre + Vector2(cos(angle), sin(angle)) * radius,
			_rng.randf_range(5.0, 7.2))
	for index in 3:
		var angle := TAU * float(index) / 3.0 + 0.5
		var point := centre + Vector2(cos(angle), sin(angle)) * (radius * 0.55)
		for level in 3:
			_place(VILLAGE + "Wall_Arch.gltf", point, angle + PI * 0.5,
				Vector3(1.8, 1.8, 1.8), float(level) * 5.4)
	for index in 6:
		var angle := TAU * float(index) / 6.0
		_place(PROPS + "Chain_Coil.gltf",
			centre + Vector2(cos(angle), sin(angle)) * (radius * 0.9),
			angle, Vector3.ONE * 2.2)
	_braziers(centre, radius * 0.68, 6)


func _buried_keep(centre: Vector2, spec: Dictionary) -> void:
	## Muros de fortaleza medio enterrados: lo que queda de un observatorio.
	var radius := float(spec.get("radius", 19.0))
	for index in 7:
		var angle := TAU * float(index) / 7.0 + 0.3
		var point := centre + Vector2(cos(angle), sin(angle)) * radius
		var wall := _place_mesh(CASTLE + "TallWall.obj", point, angle + PI * 0.5,
			Vector3.ONE * _rng.randf_range(WALL_SCALE * 0.8, WALL_SCALE * 1.15),
			-_rng.randf_range(5.0, 9.0))
		if wall != null:
			wall.rotation.z = deg_to_rad(_rng.randf_range(-9.0, 9.0))
			_wall_collision(point, angle + PI * 0.5, 10.0)
	for index in 5:
		var angle := TAU * float(index) / 5.0
		_monolith(centre + Vector2(cos(angle), sin(angle)) * (radius * 0.5),
			_rng.randf_range(4.0, 6.0), Color(0.78, 0.88, 0.98))
	_braziers(centre, radius * 0.62, 5)


func _sun_colonnade(centre: Vector2, spec: Dictionary) -> void:
	## Columnata y estandartes. Las columnas son torres del pack de fortaleza
	## estiradas: no hay pieza de columna en el kit, pero una torre estrecha y
	## alta hace exactamente ese papel.
	var radius := float(spec.get("radius", 18.0))
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var point := centre + Vector2(cos(angle), sin(angle)) * radius
		_place_mesh(CASTLE + "PointyTower.obj", point, 0.0, Vector3(1.9, 4.2, 1.9))
		_pillar_collision(point, 2.4, 13.0)
		if index % 2 == 0:
			_place(PROPS + "Banner_1_Cloth.gltf", point + Vector2(cos(angle), sin(angle)) * -1.6,
				angle + PI, Vector3.ONE * 2.6, 5.2)
	_braziers(centre, radius * 0.55, 8)
	_place(PROPS + "Cauldron.gltf", centre, 0.0, Vector3.ONE * 2.4)


func _echoless_hall(centre: Vector2, spec: Dictionary) -> void:
	## La nave en ruinas donde termina todo: dos hileras de muro rotas, arcos
	## caídos, jaulas, oro y antorchas de sobra.
	var half := float(spec.get("radius", 22.0))
	for row in 2:
		var side := 1.0 if row == 0 else -1.0
		for index in 6:
			var along := -half + float(index) * (half * 2.0 / 5.0)
			var point := centre + Vector2(side * half * 0.55, along)
			var wall := _place_mesh(CASTLE + "TallWallBricks.obj", point,
				PI * 0.5, Vector3.ONE * _rng.randf_range(WALL_SCALE * 0.75, WALL_SCALE * 1.1),
				-_rng.randf_range(0.0, 6.0))
			if wall != null:
				wall.rotation.z = deg_to_rad(_rng.randf_range(-12.0, 12.0))
				_wall_collision(point, PI * 0.5, 11.0)
	for index in 4:
		_place(VILLAGE + "Wall_Arch.gltf", centre + Vector2(0.0, -half + float(index) * half * 0.5),
			0.0, Vector3(2.6, 2.6, 2.6))
	for index in 5:
		var angle := TAU * float(index) / 5.0
		_place(PROPS + "Cage_Small.gltf",
			centre + Vector2(cos(angle), sin(angle)) * (half * 0.34), angle, Vector3.ONE * 3.4)
	_place(PROPS + "Coin_Pile.gltf", centre + Vector2(3.4, -2.6), 0.0, Vector3.ONE * COIN_SCALE)
	_place(PROPS + "Coin_Pile_2.gltf", centre + Vector2(-2.8, 3.6), 1.1, Vector3.ONE * COIN_SCALE)
	_bone_field(centre, half * 0.42, 14)
	_braziers(centre, half * 0.5, 8)


# --- piezas comunes ----------------------------------------------------------

func _floor_ring(centre: Vector2, radius: float) -> void:
	## Losa de piedra bajo los pies: es lo que dice "aquí se pelea" antes de que
	## aparezca nada.
	var names := ["RockPath_Round_Wide", "RockPath_Square_Wide", "RockPath_Round_Thin"]
	for ring in 3:
		var r := radius * (0.35 + 0.32 * float(ring))
		var count := 8 + ring * 7
		for index in count:
			var angle := TAU * float(index) / float(count) + float(ring) * 0.3
			_place(NATURE + "glTF/%s.gltf" % names[ring % names.size()],
				centre + Vector2(cos(angle), sin(angle)) * r,
				_rng.randf_range(0.0, TAU), Vector3.ONE * _rng.randf_range(1.5, 2.3), 0.04)


func _monolith(point: Vector2, height: float, tint := Color(1.0, 1.0, 1.0)) -> void:
	var rock := _place(NATURE + "glTF/Rock_Medium_%d.gltf" % _rng.randi_range(1, 3),
		point, _rng.randf_range(0.0, TAU),
		Vector3(1.5, height * 0.9, 1.5), -0.6)
	if rock != null and tint != Color(1.0, 1.0, 1.0):
		_tint(rock, tint)
	_pillar_collision(point, 1.5, height)


func _bone_field(centre: Vector2, radius: float, count: int) -> void:
	var bones := ["Skull", "Skull2", "Bone", "FishBone"]
	for index in count:
		var angle := _rng.randf_range(0.0, TAU)
		var point := centre + Vector2(cos(angle), sin(angle)) * _rng.randf_range(1.5, radius)
		_place_mesh(
			"res://assets/quaternius/Ultimate RPG Items Pack - Aug 2019/OBJ/%s.obj"
				% bones[index % bones.size()],
			point, _rng.randf_range(0.0, TAU), Vector3.ONE * _rng.randf_range(0.9, 1.5), 0.08)


func _braziers(centre: Vector2, radius: float, count: int) -> void:
	## Un brasero de verdad: pie, pebetero y llama. La antorcha del kit es de
	## PARED —mide 0,22 x 0,65 x 0,39— y puesta en el suelo no se veía; hace
	## falta levantarla sobre un candelabro de pie.
	for index in count:
		var angle := TAU * float(index) / float(count) + 0.25
		var point := centre + Vector2(cos(angle), sin(angle)) * radius
		_place(PROPS + "CandleStick_Stand.gltf", point, angle, Vector3.ONE * 3.4)
		_place(PROPS + "Torch_Metal.gltf", point, angle, Vector3.ONE * TORCH_SCALE, 3.9)
		var flame := OmniLight3D.new()
		flame.name = "ArenaBrazier%02d" % built_lights
		flame.position = _ground(point, 4.6)
		flame.light_color = Color(1.0, 0.52, 0.19)
		flame.light_energy = 6.2
		flame.omni_range = 28.0
		flame.shadow_enabled = false
		flame.light_volumetric_fog_energy = 2.1
		flame.add_to_group("night_lantern")
		add_child(flame)
		built_lights += 1


# --- colocación --------------------------------------------------------------

func _place(path: String, point: Vector2, yaw: float, scale_value: Vector3, lift := 0.0) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	node.position = _ground(point, lift)
	node.rotation.y = yaw
	node.scale = scale_value
	add_child(node)
	built_pieces += 1
	_last_visual = node
	return node


## Derriba el refugio `index`: hunde la pieza y la quita de la lista. Lo llama
## el jefe al cambiar de fase.
func topple_shelter(index: int) -> Vector2:
	if index < 0 or index >= shelter_points.size():
		return Vector2.ZERO
	var gone: Vector2 = shelter_points[index]
	var piece: Node3D = shelter_visuals[index] if index < shelter_visuals.size() else null
	if piece != null and is_instance_valid(piece):
		var fall := create_tween()
		fall.tween_property(piece, "rotation:z", piece.rotation.z + deg_to_rad(74.0), 0.7)
		fall.parallel().tween_property(piece, "position:y", piece.position.y - 7.5, 1.2)
		fall.tween_callback(piece.queue_free)
	for body in get_children():
		if body is StaticBody3D and Vector2(body.position.x, body.position.z).distance_to(gone) < 0.6:
			body.queue_free()
			break
	var left := PackedVector2Array()
	var keep: Array[Node3D] = []
	for other in shelter_points.size():
		if other == index:
			continue
		left.append(shelter_points[other])
		keep.append(shelter_visuals[other] if other < shelter_visuals.size() else null)
	shelter_points = left
	shelter_visuals = keep
	return gone


func _place_mesh(path: String, point: Vector2, yaw: float, scale_value: Vector3, lift := 0.0) -> MeshInstance3D:
	var mesh := load(path) as Mesh
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if _patina != Color(1.0, 1.0, 1.0):
		var stone := StandardMaterial3D.new()
		stone.albedo_color = _patina
		stone.roughness = 0.95
		node.material_override = stone
	node.position = _ground(point, lift)
	node.rotation.y = yaw
	node.scale = scale_value
	add_child(node)
	built_pieces += 1
	_last_visual = node
	return node


func _pillar_collision(point: Vector2, radius: float, height: float) -> void:
	shelter_points.append(point)
	shelter_visuals.append(_last_visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.position = _ground(point, 0.0)
	add_child(body)


func _wall_collision(point: Vector2, yaw: float, height: float) -> void:
	## Un muro también cobija: la nave de Vaelor no levanta ni un monolito y sin
	## esto su peligro no tenía dónde refugiarse, o sea que era insuperable.
	shelter_points.append(point)
	shelter_visuals.append(_last_visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.4, height, 2.0)
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	body.position = _ground(point, 0.0)
	body.rotation.y = yaw
	add_child(body)


func _tint(node: Node, colour: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var material := StandardMaterial3D.new()
			material.albedo_color = colour
			material.roughness = 0.88
			(child as MeshInstance3D).material_override = material
		_tint(child, colour)


func _ground(point: Vector2, lift: float) -> Vector3:
	if _terrain == null:
		return Vector3(point.x, lift, point.y)
	var data = _terrain.get("data")
	if data == null:
		return Vector3(point.x, lift, point.y)
	var height: float = data.get_height(Vector3(point.x, 0.0, point.y))
	return Vector3(point.x, (0.0 if is_nan(height) else height) + lift, point.y)
