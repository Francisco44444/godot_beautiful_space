class_name AdventureArrow
extends Node3D

## Proyectil con barrido continuo: no atraviesa objetivos aunque el fotograma sea
## largo y comunica impactos a cualquier recurso/enemigo compatible.

var velocity := Vector3.ZERO
var shooter: Node3D
var lifetime := 8.0
var damage := 1
var draw_strength := 0.0
var _flying := true
var _trail: GPUParticles3D


func _ready() -> void:
	_build_readable_arrow()
	_build_flight_trail()


func launch(direction: Vector3, speed: float, owner_node: Node3D, strength: float = 1.0) -> void:
	velocity = direction.normalized() * speed
	shooter = owner_node
	draw_strength = clampf(strength, 0.0, 1.0)
	damage = 1 + floori(draw_strength * 2.0)
	lifetime = 8.0
	_flying = true
	set_physics_process(true)
	if _trail != null:
		_trail.amount_ratio = lerpf(0.38, 1.0, draw_strength)
		_trail.emitting = true
	look_at(global_position + velocity.normalized(), Vector3.UP, true)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_finish_flight()
		return
	var start := global_position
	velocity += Vector3.DOWN * 6.8 * delta
	var finish := start + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, finish, 5)
	query.collide_with_areas = false
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result.position
		var collider := result.collider as Node
		if collider != null and collider.has_method("receive_projectile_hit"):
			collider.call("receive_projectile_hit", result.position, shooter)
		_finish_flight()
		return
	global_position = finish
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP, true)


func _build_readable_arrow() -> void:
	## El OBJ original mide pocos centímetros en la escala del mundo. Esta silueta
	## low-poly garantiza que la flecha sea legible incluso a máxima velocidad.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.43, 0.20, 0.07)
	material.roughness = 0.82
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.78, 0.84, 0.89)
	metal.metallic = 0.72
	metal.roughness = 0.28
	var shaft := MeshInstance3D.new()
	shaft.name = "ReadableShaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.024
	shaft_mesh.bottom_radius = 0.024
	shaft_mesh.height = 1.18
	shaft_mesh.radial_segments = 6
	shaft_mesh.material = material
	shaft.mesh = shaft_mesh
	shaft.rotation.x = PI * 0.5
	add_child(shaft)
	var head := MeshInstance3D.new()
	head.name = "ReadableArrowHead"
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.105
	head_mesh.height = 0.30
	head_mesh.radial_segments = 4
	head_mesh.material = metal
	head.mesh = head_mesh
	head.position.z = 0.72
	head.rotation.x = PI * 0.5
	add_child(head)
	for side in [-1.0, 1.0]:
		var feather := MeshInstance3D.new()
		feather.name = "Feather"
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.16, 0.018, 0.30)
		var feather_material := StandardMaterial3D.new()
		feather_material.albedo_color = Color(0.72, 0.13, 0.10)
		feather_material.roughness = 0.9
		feather_mesh.material = feather_material
		feather.mesh = feather_mesh
		feather.position = Vector3(side * 0.065, 0.0, -0.48)
		add_child(feather)


func _build_flight_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.name = "FlightTrail"
	_trail.amount = 48
	_trail.lifetime = 0.52
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.scale_min = 0.045
	process.scale_max = 0.11
	process.color = Color(1.0, 0.72, 0.20, 0.84)
	_trail.process_material = process
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 5
	mote.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.67, 0.18, 0.86)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.42, 0.07)
	glow.emission_energy_multiplier = 2.1
	mote.material = glow
	_trail.draw_pass_1 = mote
	add_child(_trail)
	_trail.emitting = true


func _finish_flight() -> void:
	if not _flying:
		return
	_flying = false
	set_physics_process(false)
	if _trail != null:
		_trail.emitting = false
	await get_tree().create_timer(0.58).timeout
	queue_free()
