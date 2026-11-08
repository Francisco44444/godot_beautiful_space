class_name AdventureArrow
extends Node3D

## Proyectil con barrido continuo: no atraviesa objetivos aunque el fotograma
## sea largo, deja una espiga blanca visible en pleno vuelo y se queda clavada
## en el punto de impacto para que el jugador vea si acertó.

enum Phase {
	NOCKED,
	FLYING,
	STUCK,
}

## Un arco tenso y plano deja el proyectil como un punto que se aleja de la
## cámara. Con más gravedad la flecha describe una parábola visible y además
## obliga a apuntar alto de lejos, que es lo propio de un arco.
const GRAVITY := 10.5
## La punta se construye hacia -Z, el eje que Godot considera "delante", y por
## eso `_aim_along` llama a `look_at` sin `use_model_front`. Mezclar las dos
## convenciones es lo que antes hacía volar la flecha de culo.
const TIP_OFFSET := -0.66
const NOCK_OFFSET := 0.52
const HEAD_LENGTH := 0.20
const MAX_TRAIL_POINTS := 96

@export var stuck_lifetime: float = 7.0
@export var stuck_fade_time: float = 1.2
## Cuánto sobrevive cada tramo de la cinta y su anchura en el extremo delantero.
@export var trail_duration: float = 1.0
@export var trail_width: float = 0.13

var solo_visual_red := false
var _terreno_red: Node
var velocity := Vector3.ZERO
var shooter: Node3D
var lifetime := 8.0
var damage := 1
var draw_strength := 0.0
var phase := Phase.NOCKED
var _ribbon: MeshInstance3D
var _ribbon_mesh: ImmediateMesh
var _trail_points: PackedVector3Array = PackedVector3Array()
var _trail_ages: PackedFloat32Array = PackedFloat32Array()
var _body_materials: Array[StandardMaterial3D] = []
var _stuck_time := 0.0


func _ready() -> void:
	_build_readable_arrow()
	_build_trail_ribbon()
	set_physics_process(false)


func launch(direction: Vector3, speed: float, owner_node: Node3D, strength: float = 1.0) -> void:
	velocity = direction.normalized() * speed
	shooter = owner_node
	draw_strength = clampf(strength, 0.0, 1.0)
	damage = 1 + floori(draw_strength * 2.0)
	lifetime = 8.0
	phase = Phase.FLYING
	_stuck_time = 0.0
	set_physics_process(true)
	_trail_points.clear()
	_trail_ages.clear()
	_aim_along(velocity)
	_record_trail_point()


func is_stuck() -> bool:
	return phase == Phase.STUCK


func _physics_process(delta: float) -> void:
	if phase != Phase.FLYING:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_stick_in_place(global_position, Vector3.UP)
		return
	var start := global_position
	velocity += Vector3.DOWN * GRAVITY * delta
	var finish := start + velocity * delta
	# El barrido arranca en la punta y no en el centro de la malla: así una
	# flecha rápida no se clava con medio astil dentro de la pared.
	var travel := velocity.normalized()
	var query := PhysicsRayQueryParameters3D.create(start + travel * absf(TIP_OFFSET), finish + travel * absf(TIP_OFFSET), 5)
	query.collide_with_areas = false
	if shooter != null and is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	# Terrain3D sólo tiene suelo físico junto al anfitrión. La cota impide
	# que una flecha remota atraviese una loma fuera de esa ventana de colisión.
	if shooter!=null and bool(shooter.get("network_remote")) and get_node("/root/NetworkSession").is_world_authority():
		if _terreno_red==null and get_parent()!=null: _terreno_red = get_parent().get_node_or_null("Terrain3D")
		if _terreno_red!=null:
			var punta_inicial := start+travel*absf(TIP_OFFSET)
			var punta_final := finish+travel*absf(TIP_OFFSET)
			var suelo: float = _terreno_red.data.get_height(punta_final)
			if not is_nan(suelo) and not _terreno_red.data.get_control_hole(punta_final) and punta_final.y<suelo:
				var lo := 0.0
				var hi := 1.0
				for paso in 12:
					var medio := (lo+hi)*0.5
					var punto := punta_inicial.lerp(punta_final,medio)
					var altura: float = _terreno_red.data.get_height(punto)
					if is_nan(altura) or _terreno_red.data.get_control_hole(punto) or punto.y>=altura: lo = medio
					else: hi = medio
				var contacto := punta_inicial.lerp(punta_final,hi)
				if result.is_empty() or punta_inicial.distance_squared_to(contacto)<punta_inicial.distance_squared_to(result.position):
					_stick_in_place(contacto,Vector3.UP)
					return
	if not result.is_empty():
		var collider := result.collider as Node
		if collider != null and collider.has_method("receive_projectile_hit") and not solo_visual_red:
			if shooter!=null and bool(shooter.get("network_remote")) and not collider is RPGEnemy:
				_stick_in_place(result.position,result.get("normal",Vector3.UP))
				return
			collider.call("receive_projectile_hit", result.position, shooter)
		_stick_in_place(result.position, result.get("normal", Vector3.UP))
		return
	global_position = finish
	if velocity.length_squared() > 0.01:
		_aim_along(velocity)
	_record_trail_point()


func _process(delta: float) -> void:
	_update_trail_ribbon(delta)
	if phase != Phase.STUCK:
		return
	_stuck_time += delta
	if _stuck_time < stuck_lifetime:
		return
	var fade := clampf((_stuck_time - stuck_lifetime) / maxf(stuck_fade_time, 0.05), 0.0, 1.0)
	for material in _body_materials:
		material.albedo_color.a = 1.0 - fade
	if fade >= 1.0:
		queue_free()


func _aim_along(direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		return
	look_at(global_position + direction.normalized(), Vector3.UP, false)


func _stick_in_place(hit_position: Vector3, normal: Vector3) -> void:
	if phase == Phase.STUCK:
		return
	phase = Phase.STUCK
	set_physics_process(false)
	# La punta queda dentro de la superficie y el astil sobresale en la
	# dirección desde la que llegó el disparo: se lee como flecha clavada.
	var travel := velocity.normalized() if velocity.length_squared() > 0.0001 else -normal
	_aim_along(travel)
	global_position = hit_position - travel * (absf(TIP_OFFSET) - 0.10)
	velocity = Vector3.ZERO
	_record_trail_point()
	_spawn_impact_flash(hit_position)


func _spawn_impact_flash(hit_position: Vector3) -> void:
	var flash := MeshInstance3D.new()
	flash.name = "ImpactFlash"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.98, 0.88, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.6)
	material.emission_energy_multiplier = 3.4
	sphere.material = material
	flash.mesh = sphere
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(flash)
	flash.global_position = hit_position
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 4.2, 0.26)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.34)
	tween.tween_callback(flash.queue_free)


func _build_readable_arrow() -> void:
	## El OBJ original mide pocos centímetros en la escala del mundo. Esta
	## silueta low-poly garantiza que la flecha sea legible incluso a máxima
	## velocidad, y toda ella crece hacia -Z para casar con `look_at`.
	var wood := _register_material(Color(0.52, 0.28, 0.11), 0.82, 0.0)
	var metal := _register_material(Color(0.90, 0.94, 0.99), 0.24, 0.68)
	metal.emission_enabled = true
	metal.emission = Color(0.75, 0.85, 1.0)
	metal.emission_energy_multiplier = 0.32
	var shaft := MeshInstance3D.new()
	shaft.name = "ReadableShaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.023
	shaft_mesh.bottom_radius = 0.023
	shaft_mesh.height = NOCK_OFFSET - TIP_OFFSET
	shaft_mesh.radial_segments = 6
	shaft_mesh.material = wood
	shaft.mesh = shaft_mesh
	shaft.position.z = (TIP_OFFSET + NOCK_OFFSET) * 0.5
	shaft.rotation.x = PI * 0.5
	add_child(shaft)
	var head := MeshInstance3D.new()
	head.name = "ReadableArrowHead"
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.050
	head_mesh.height = HEAD_LENGTH
	head_mesh.radial_segments = 4
	head_mesh.material = metal
	head.mesh = head_mesh
	# La punta exacta cae en TIP_OFFSET, que es la distancia que usan el barrido
	# de colisión y el clavado.
	head.position.z = TIP_OFFSET + HEAD_LENGTH * 0.5
	head.rotation.x = -PI * 0.5
	add_child(head)
	# Tres aletas radiales que arrancan en el borde del astil. Con dos plumas
	# centradas en el eje se solapaban y la cola parecía una paleta roja plana.
	var feather_material := _register_material(Color(0.94, 0.24, 0.18), 0.9, 0.0)
	for vane in 3:
		var angle := TAU * float(vane) / 3.0 + PI * 0.5
		var feather := MeshInstance3D.new()
		feather.name = "Feather%d" % (vane + 1)
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.068, 0.014, 0.25)
		feather_mesh.material = feather_material
		feather.mesh = feather_mesh
		feather.position = Vector3(cos(angle) * 0.053, sin(angle) * 0.053, NOCK_OFFSET - 0.13)
		feather.rotation.z = angle
		add_child(feather)


func _register_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	# Todas las superficies comparten el canal alfa para poder desvanecer la
	# flecha clavada sin duplicar materiales al vuelo.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_materials.append(material)
	return material


func _build_trail_ribbon() -> void:
	## Cinta continua que dibuja el recorrido, no un rosario de motas. Vive con
	## `top_level` activo para construirse en coordenadas del mundo: así la
	## estela se queda donde pasó la flecha en vez de girar con ella.
	_ribbon = MeshInstance3D.new()
	_ribbon.name = "TrailRibbon"
	_ribbon.top_level = true
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbon_mesh = ImmediateMesh.new()
	_ribbon.mesh = _ribbon_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	material.no_depth_test = false
	_ribbon.material_override = material
	# La cinta abarca todo el vuelo, así que su caja de visibilidad no puede
	# depender de la posición de la flecha.
	_ribbon.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	add_child(_ribbon)


func _record_trail_point() -> void:
	_trail_points.append(global_position)
	_trail_ages.append(0.0)
	if _trail_points.size() > MAX_TRAIL_POINTS:
		_trail_points.remove_at(0)
		_trail_ages.remove_at(0)


func _update_trail_ribbon(delta: float) -> void:
	if _ribbon == null:
		return
	for index in _trail_ages.size():
		_trail_ages[index] += delta
	while not _trail_ages.is_empty() and _trail_ages[0] > trail_duration:
		_trail_points.remove_at(0)
		_trail_ages.remove_at(0)
	_ribbon_mesh.clear_surfaces()
	if _trail_points.size() < 2:
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera != null else global_position + Vector3.UP * 8.0
	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in _trail_points.size():
		var point: Vector3 = _trail_points[index]
		var ahead: Vector3 = _trail_points[mini(index + 1, _trail_points.size() - 1)]
		var behind: Vector3 = _trail_points[maxi(index - 1, 0)]
		var along := ahead - behind
		if along.length_squared() < 0.000001:
			along = velocity if velocity.length_squared() > 0.0001 else Vector3.FORWARD
		# La cinta se orienta de canto a la cámara para leerse siempre igual de
		# ancha, mire el jugador desde donde mire.
		var side := along.normalized().cross((eye - point).normalized())
		if side.length_squared() < 0.000001:
			side = Vector3.UP
		side = side.normalized()
		var head_ratio := float(index) / float(maxi(_trail_points.size() - 1, 1))
		var fade := 1.0 - clampf(_trail_ages[index] / maxf(trail_duration, 0.01), 0.0, 1.0)
		var width := trail_width * lerpf(0.18, 1.0, head_ratio) * fade
		var tint := Color(1.0, 0.97, 0.86, fade * lerpf(0.25, 0.95, head_ratio))
		_ribbon_mesh.surface_set_color(tint)
		_ribbon_mesh.surface_add_vertex(point + side * width)
		_ribbon_mesh.surface_set_color(tint)
		_ribbon_mesh.surface_add_vertex(point - side * width)
	_ribbon_mesh.surface_end()
