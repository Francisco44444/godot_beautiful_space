class_name WeaponChargeEffect
extends Node3D

## Fuerza especial acumulada en el arma. El aura crece sobre el filo mientras
## se mantiene el botón de ataque y estalla en un anillo de choque cuando el
## héroe se suelta girando.

const READY_COLOR := Color(0.62, 0.92, 1.0)
const CHARGE_COLOR := Color(1.0, 0.72, 0.24)

var _aura: MeshInstance3D
var _aura_material: StandardMaterial3D
var _sparks: GPUParticles3D
var _strength := 0.0
var _pulse := 0.0


func _ready() -> void:
	_build_sparks()


func attach_to_weapon(weapon: MeshInstance3D) -> void:
	## El aura vive dentro de la malla del arma para heredar su empuñadura y su
	## escala: así envuelve el filo exacto de la espada o del hacha sin números
	## mágicos por arma.
	_release_aura()
	if weapon == null or weapon.mesh == null:
		return
	var bounds := weapon.mesh.get_aabb()
	_aura = MeshInstance3D.new()
	_aura.name = "ChargeAura"
	var capsule := CylinderMesh.new()
	# El radio sale del largo del arma, no de su ancho: tomarlo del ancho hacía
	# que la guarda de la espada inflara el aura hasta tragarse al héroe.
	capsule.top_radius = bounds.size.y * 0.042
	capsule.bottom_radius = capsule.top_radius * 0.4
	capsule.height = bounds.size.y * 0.72
	capsule.radial_segments = 8
	_aura_material = StandardMaterial3D.new()
	_aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_aura_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_aura_material.albedo_color = Color(CHARGE_COLOR, 0.0)
	capsule.material = _aura_material
	_aura.mesh = capsule
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura.position.y = bounds.position.y + bounds.size.y * 0.62
	_aura.visible = false
	weapon.add_child(_aura)
	set_charge(0.0)


func set_charge(strength: float) -> void:
	_strength = clampf(strength, 0.0, 1.0)
	if _aura != null:
		_aura.visible = _strength > 0.02
		var color := CHARGE_COLOR.lerp(READY_COLOR, smoothstep(0.7, 1.0, _strength))
		_aura_material.albedo_color = Color(color, lerpf(0.0, 0.62, _strength))
		var width := lerpf(0.55, 1.35, _strength)
		_aura.scale = Vector3(width, 1.0, width)
	if _sparks != null:
		_sparks.emitting = _strength > 0.05
		_sparks.amount_ratio = lerpf(0.2, 1.0, _strength)


func get_charge() -> float:
	return _strength


func update_pulse(delta: float) -> void:
	## Un latido rápido cuando la carga está lista avisa de que el giro ya está
	## disponible sin tener que mirar la interfaz.
	if _aura == null or _strength <= 0.02:
		return
	_pulse += delta * lerpf(6.0, 22.0, _strength)
	var beat := 1.0 + sin(_pulse) * lerpf(0.04, 0.16, _strength)
	var width := lerpf(0.55, 1.35, _strength) * beat
	_aura.scale = Vector3(width, beat, width)


func burst(radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "SpinShockwave"
	var disc := TorusMesh.new()
	# Anillo fino: con un tubo grueso el efecto salía como un disco blanco que
	# tapaba al héroe en vez de leerse como onda de choque.
	disc.inner_radius = 0.40
	disc.outer_radius = 0.45
	disc.rings = 28
	disc.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(READY_COLOR, 0.7)
	disc.material = material
	ring.mesh = disc
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.22
	add_child(ring)
	var target_scale := maxf(radius, 0.5) / 0.425
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(target_scale, 1.0, target_scale), 0.42)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.46)
	tween.tween_callback(ring.queue_free)
	if _sparks != null:
		_sparks.emitting = false


func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "ChargeSparks"
	_sparks.amount = 40
	_sparks.lifetime = 0.55
	_sparks.local_coords = false
	_sparks.position.y = 1.15
	_sparks.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 1.15
	# Velocidad radial negativa: las chispas convergen hacia el héroe, que es
	# la lectura clásica de "estoy acumulando fuerza".
	process.direction = Vector3.ZERO
	process.gravity = Vector3.ZERO
	process.radial_velocity_min = -3.4
	process.radial_velocity_max = -1.8
	# Igual que en la flecha: la escala multiplica el tamaño de la malla.
	process.scale_min = 0.7
	process.scale_max = 1.9
	process.color = Color(0.72, 0.94, 1.0, 0.9)
	_sparks.process_material = process
	var mote := SphereMesh.new()
	mote.radius = 0.05
	mote.height = 0.1
	mote.radial_segments = 5
	mote.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.78, 0.95, 1.0, 0.9)
	glow.emission_enabled = true
	glow.emission = Color(0.5, 0.85, 1.0)
	glow.emission_energy_multiplier = 2.8
	mote.material = glow
	_sparks.draw_pass_1 = mote
	_sparks.emitting = false
	add_child(_sparks)


func _release_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	_aura_material = null
