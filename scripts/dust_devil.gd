class_name DustDevil
extends Node3D

## Remolinos de arena que recorren el desierto. Dan inquietud a un bioma que,
## por lo demás, es una extensión quieta: se ven venir de lejos, giran, se
## desplazan sobre la duna y se deshacen.
##
## El embudo es geometría propia y facetada —anillos de siete lados apilados—,
## no un billboard: así el remolino gira de verdad y encaja con el resto del
## paisaje low poly. Cada uno lleva su propia arena suelta en la base.

## Cuántos pueden verse a la vez y a qué distancia del héroe aparecen.
@export var max_devils: int = 3
@export var spawn_radius_min: float = 45.0
@export var spawn_radius_max: float = 110.0
## Cada cuánto nace uno, con su margen.
@export var spawn_interval: float = 13.0
@export var spawn_interval_jitter: float = 7.0
## Cuánto vive, contando la entrada y la disolución.
@export var lifetime: float = 26.0
## Forma del embudo: alto, radio arriba y abajo, y cuántos anillos y lados.
@export var funnel_height: float = 14.0
@export var funnel_top_radius: float = 3.8
@export var funnel_base_radius: float = 0.8
@export var funnel_rings: int = 10
@export_range(5, 12, 1) var funnel_sides: int = 7
## Vueltas por segundo del embudo y velocidad con la que se desplaza.
@export var spin_speed: float = 1.35
@export var drift_speed: float = 3.6
## Si el héroe se aleja más de esto, el remolino se retira.
@export var cull_distance: float = 210.0

var _player: Node3D
var _terrain: Node
var _vegetation: Node
var _mesh: Mesh
var _material: StandardMaterial3D
var _devils: Array[Dictionary] = []
var _wait := 2.0
var _spawned := 0


func bind(world: Node) -> void:
	_player = world.get_node_or_null("Player") as Node3D
	_terrain = world.get_node_or_null("Terrain3D")
	_vegetation = world.get_node_or_null("VegetationScatter")
	_material = _build_material()
	_mesh = _build_funnel_mesh()
	_wait = randf_range(2.0, spawn_interval)


func get_active_count() -> int:
	return _devils.size()


func get_spawn_count() -> int:
	return _spawned


func spawn_devil() -> bool:
	## Intenta plantar un remolino en un punto de desierto cerca del héroe.
	if _player == null or _devils.size() >= max_devils:
		return false
	var spot := _find_desert_spot()
	if spot == Vector3.INF:
		return false
	var root_node := Node3D.new()
	root_node.name = "DustDevil"
	# La posición se fija DESPUÉS de entrar en el árbol: antes, `global_position`
	# no tiene sentido todavía y Godot lo avisa por consola.
	add_child(root_node)
	root_node.global_position = spot
	var funnel := MeshInstance3D.new()
	funnel.name = "Funnel"
	funnel.mesh = _mesh
	funnel.material_override = _material.duplicate()
	funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_node.add_child(funnel)
	var sand := _build_base_sand()
	root_node.add_child(sand)
	var angle := randf_range(0.0, TAU)
	_devils.append({
		"node": root_node,
		"funnel": funnel,
		"sand": sand,
		"life": lifetime,
		"spin": randf_range(0.0, TAU),
		"turn": spin_speed * randf_range(0.8, 1.3) * (1.0 if randf() < 0.5 else -1.0),
		"drift": Vector3(cos(angle), 0.0, sin(angle)) * drift_speed * randf_range(0.7, 1.3),
		"scale": randf_range(0.75, 1.35),
	})
	_spawned += 1
	return true


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_update_devils(delta)
	if _devils.size() >= max_devils:
		return
	_wait = maxf(_wait - delta, 0.0)
	if _wait > 0.0:
		return
	_wait = maxf(spawn_interval + randf_range(-spawn_interval_jitter, spawn_interval_jitter), 3.0)
	spawn_devil()


func _update_devils(delta: float) -> void:
	for index in range(_devils.size() - 1, -1, -1):
		var devil: Dictionary = _devils[index]
		var node: Node3D = devil["node"]
		# `is_instance_valid` sigue siendo cierto entre el `queue_free` y el
		# borrado real, y en ese hueco el nodo ya está fuera del árbol.
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_devils.remove_at(index)
			continue
		devil["life"] = float(devil["life"]) - delta
		var life := float(devil["life"])
		# Entrada y disolución: el remolino se forma, aguanta y se deshace.
		var fade := minf(
			smoothstep(0.0, 2.2, lifetime - life),
			smoothstep(0.0, 3.0, life)
		)
		if life <= 0.0 or node.global_position.distance_to(_player.global_position) > cull_distance:
			node.queue_free()
			_devils.remove_at(index)
			continue
		devil["spin"] = float(devil["spin"]) + float(devil["turn"]) * TAU * delta
		node.rotation.y = float(devil["spin"])
		var step: Vector3 = (devil["drift"] as Vector3) * delta
		var next := node.global_position + step
		next.y = _ground_height(next)
		node.global_position = next
		var breadth := float(devil["scale"]) * lerpf(0.35, 1.0, fade)
		node.scale = Vector3(breadth, lerpf(0.45, 1.0, fade) * float(devil["scale"]), breadth)
		var funnel: MeshInstance3D = devil["funnel"]
		var material := funnel.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color.a = fade
		var sand: GPUParticles3D = devil["sand"]
		sand.emitting = fade > 0.05
		sand.amount_ratio = clampf(fade, 0.05, 1.0)
		_devils[index] = devil


func _find_desert_spot() -> Vector3:
	## Busca terreno de desierto alrededor del héroe. Si no lo encuentra en unos
	## cuantos intentos, no nace nada: es lo que mantiene el efecto en su bioma.
	for _attempt in 12:
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(spawn_radius_min, spawn_radius_max)
		var candidate := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		candidate.y = _ground_height(candidate)
		if _biome_at(candidate) == "desert":
			return candidate
	return Vector3.INF


func _biome_at(point: Vector3) -> String:
	if _vegetation != null and _vegetation.has_method("biome_at"):
		return String(_vegetation.call("biome_at", point))
	return ""


func _ground_height(point: Vector3) -> float:
	if _terrain == null:
		return point.y
	var data = _terrain.get("data")
	if data == null:
		return point.y
	var height := float(data.get_height(Vector3(point.x, 0.0, point.z)))
	return point.y if is_nan(height) else height


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.vertex_color_use_as_albedo = true
	return material


func _build_funnel_mesh() -> Mesh:
	## Embudo facetado. Tres cosas lo hacen leerse como un remolino low poly y no
	## como un cono translúcido:
	##
	##  - Torsión fuerte de un anillo al siguiente, más de una vuelta completa en
	##    toda la altura, así que la silueta describe una espiral.
	##  - Perfil irregular: cada anillo mete su propio mordisco al radio y su
	##    propio desplazamiento lateral, para que no salga un cono perfecto.
	##  - Un tinte distinto por CARA, no solo por altura: sin ese contraste entre
	##    facetas contiguas la geometría se ve lisa y se pierde el estilo.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	for ring in funnel_rings + 1:
		var ratio := float(ring) / float(funnel_rings)
		var height := funnel_height * ratio
		# El radio crece con una curva, no en línea recta: es lo que le da la
		# cintura estrecha del remolino. El mordisco lo saca de la regularidad.
		var bite := 1.0 + sin(ratio * 9.1) * 0.16
		var radius := lerpf(funnel_base_radius, funnel_top_radius, pow(ratio, 1.7)) * bite
		var twist := ratio * TAU * 1.15
		var sway := Vector3(
			sin(ratio * PI * 2.1) * 0.85,
			0.0,
			cos(ratio * PI * 1.6) * 0.68
		)
		var points: Array[Vector3] = []
		for side in funnel_sides:
			var angle := twist + TAU * float(side) / float(funnel_sides)
			var edge := 1.0 + sin(float(side) * 2.3 + ratio * 5.0) * 0.12
			points.append(
				Vector3(cos(angle) * radius * edge, height, sin(angle) * radius * edge) + sway
			)
		rings.append(points)
	for ring in funnel_rings:
		var lower: Array = rings[ring]
		var upper: Array = rings[ring + 1]
		for side in funnel_sides:
			var next_side := (side + 1) % funnel_sides
			var low_tint := _facet_tint(float(ring) / float(funnel_rings), ring, side)
			var high_tint := _facet_tint(float(ring + 1) / float(funnel_rings), ring + 1, side)
			_add_triangle(surface, lower[side], upper[side], upper[next_side], low_tint, high_tint, high_tint)
			_add_triangle(surface, lower[side], upper[next_side], lower[next_side], low_tint, high_tint, low_tint)
	return surface.commit()


func _facet_tint(ratio: float, ring: int, side: int) -> Color:
	## Arena compacta y opaca abajo, deshecha y translúcida arriba, con un
	## escalón de brillo por faceta que marca las caras.
	# Arena del propio bioma: la duna mide R=1.00 G=0.82 B=0.39 en pantalla, así
	# que el embudo parte de ese amarillo —algo más saturado abajo, donde la
	# arena va compacta— y se aclara al deshacerse arriba.
	var base := Color(0.98, 0.72, 0.16).lerp(Color(1.0, 0.90, 0.46), ratio)
	var facet := 0.84 + 0.16 * float((ring * 3 + side * 2) % 3)
	return Color(
		base.r * facet,
		base.g * facet,
		base.b * facet,
		lerpf(0.92, 0.18, pow(ratio, 0.8))
	)


func _add_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color_a: Color,
	color_b: Color,
	color_c: Color
) -> void:
	surface.set_color(color_a)
	surface.add_vertex(a)
	surface.set_color(color_b)
	surface.add_vertex(b)
	surface.set_color(color_c)
	surface.add_vertex(c)


func _build_base_sand() -> GPUParticles3D:
	## Arena suelta arrastrada en la base, que es lo que ata el embudo al suelo.
	var sand := GPUParticles3D.new()
	sand.name = "BaseSand"
	sand.amount = 150
	sand.lifetime = 1.6
	sand.local_coords = false
	sand.visibility_aabb = AABB(Vector3(-12.0, -1.0, -12.0), Vector3(24.0, 26.0, 24.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 4.4
	process.emission_ring_inner_radius = 1.2
	process.emission_ring_height = 0.5
	process.direction = Vector3.UP
	process.spread = 24.0
	process.gravity = Vector3(0.0, 1.6, 0.0)
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 3.6
	process.tangential_accel_min = 6.0
	process.tangential_accel_max = 12.0
	process.radial_accel_min = -2.2
	process.radial_accel_max = -0.8
	process.scale_min = 0.8
	process.scale_max = 2.2
	process.color = Color(1.0, 0.82, 0.36, 0.50)
	sand.process_material = process
	var mote := QuadMesh.new()
	mote.size = Vector2(0.85, 0.62)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(1.0, 0.84, 0.38, 0.52)
	material.vertex_color_use_as_albedo = true
	mote.material = material
	sand.draw_pass_1 = mote
	sand.emitting = false
	return sand
