class_name ChargeStorm
extends Node3D

## Tormenta que acompaña la carga de la fuerza especial: el viento arrecia sobre
## toda la vegetación, el cielo se apaga y caen rayos sobre el filo del arma.
##
## El oscurecimiento NO se escribe sobre el sol ni sobre la luz ambiental: el
## ciclo día/noche de `world.gd` los recalcula cada fotograma y pisaba el efecto
## en cuanto la tormenta dejaba de forzarlos, con lo que el giro salía a plena
## luz. En su lugar la tormenta publica un factor de atenuación —`get_dimming()`,
## leído por el ciclo a través del grupo `atmosphere_storm`— y solo toca el
## brillo de post-proceso, que no comparte con nadie.

const BOLT_HEIGHT := 24.0
const BOLT_SEGMENTS := 16
const BOLT_SPREAD := 1.35
const SKY_COLOR := Color(0.68, 0.86, 1.0)
## Los restos en el aire no salen con el clic: hasta que el héroe no lleva un
## rato manteniendo el botón no hay tormenta que los levante. Sin este umbral,
## aporrear el ataque dejaba una nube de hojas flotando sin motivo. Con la carga
## llena en 0.60 s, 0.45 son 0.27 s de mantenido: bastante más que un clic.
const DEBRIS_THRESHOLD := 0.45
## Lo que arrastra el remolino en cada bioma. Las hojas solo tienen sentido donde
## hay hojas: en la nieve gira brisa blanca, en el desierto polvo.
const DEBRIS_PRESETS := {
	"valley": {
		"color": Color(0.62, 0.70, 0.45, 0.88),
		"size": Vector2(0.17, 0.10),
		"amount": 190,
		"lifetime": 1.5,
		"rise": 1.10,
		"ring_radius": 5.4,
		"ring_height": 2.2,
		"spin": 320.0,
		"speed": 1.0,
	},
	"dark_forest": {
		"color": Color(0.36, 0.31, 0.44, 0.90),
		"size": Vector2(0.19, 0.11),
		"amount": 220,
		"lifetime": 1.8,
		"rise": 0.85,
		"ring_radius": 5.0,
		"ring_height": 2.6,
		"spin": 260.0,
		"speed": 0.88,
	},
	"snow": {
		"color": Color(0.95, 0.98, 1.0, 0.80),
		"size": Vector2(0.26, 0.035),
		"amount": 320,
		"lifetime": 1.2,
		"rise": 0.45,
		"ring_radius": 6.2,
		"ring_height": 2.8,
		"spin": 90.0,
		"speed": 1.45,
	},
	"desert": {
		"color": Color(0.80, 0.66, 0.44, 0.62),
		"size": Vector2(0.22, 0.16),
		"amount": 300,
		"lifetime": 1.6,
		"rise": 0.30,
		"ring_radius": 6.0,
		"ring_height": 1.1,
		"spin": 140.0,
		"speed": 1.15,
	},
}

## Umbral de carga por debajo del cual NO hay tormenta: ni viento, ni
## oscurecimiento, ni rayos. Un clic de ataque normal dura menos de dos décimas
## —con la carga completa en 0.60 s eso es un 0.20 de carga— y no puede levantar
## un vendaval: la tormenta pertenece a la fuerza especial, que exige mantener
## pulsado. Antes la intensidad entraba con una curva acelerada y el primer
## fotograma de cualquier clic ya movía la hierba y apagaba el cielo.
@export_range(0.0, 0.9, 0.01) var storm_threshold: float = 0.34
## Cuánto se atenúa la luz del mundo a plena carga.
@export_range(0.05, 1.0, 0.05) var storm_dimming: float = 0.26
@export var storm_brightness: float = 0.58
## Umbral de carga a partir del cual empiezan a caer rayos.
@export var bolt_threshold: float = 0.38

var _sun: DirectionalLight3D
var _environment: Environment
var _vegetation: Node
var _flash: OmniLight3D
var _base_brightness := 1.0
var _bound := false
var _intensity := 0.0
## Carga cruda que llega de fuera, antes de aplicar el umbral.
var _charge := 0.0
var _bolt_countdown := 0.0
var _vortex: GPUParticles3D
var _debris_biome := ""
## Una vez levantados, los restos siguen girando hasta que la tormenta se calma.
## Cortarlos al bajar la intensidad los apagaba a mitad del remolino, que es
## justo el gesto donde más se ven.
var _debris_armed := false
var _debris_material: StandardMaterial3D
var _debris_mesh: QuadMesh


func get_dimming() -> float:
	## 1.0 sin tormenta; baja conforme se acumula la carga. Lo aplica el ciclo
	## día/noche sobre la luz que él mismo calcula.
	return lerpf(1.0, storm_dimming, _intensity)


func bind(world: Node) -> void:
	if _bound or world == null:
		return
	add_to_group("atmosphere_storm")
	_sun = world.get_node_or_null("Sun") as DirectionalLight3D
	var holder := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if holder != null:
		_environment = holder.environment
	_vegetation = world.get_node_or_null("VegetationScatter")
	if _environment != null:
		_base_brightness = _environment.adjustment_brightness
	_build_wind_vortex()
	_flash = OmniLight3D.new()
	_flash.name = "BoltFlash"
	_flash.light_color = SKY_COLOR
	_flash.light_energy = 0.0
	_flash.omni_range = 13.0
	_flash.shadow_enabled = false
	add_child(_flash)
	_bound = true


func set_intensity(value: float, delta: float, blade_tip: Vector3, hero_position: Vector3) -> void:
	_charge = clampf(value, 0.0, 1.0)
	# Por debajo del umbral la tormenta no existe. La curva arranca ahí, así que
	# el viento y el oscurecimiento crecen desde cero en cuanto se supera.
	_intensity = smoothstep(storm_threshold, 1.0, _charge)
	_apply_atmosphere(_intensity)
	# El ventarrón sobre la vegetación no se ve si el héroe está en un empedrado
	# o lejos de los árboles. El torbellino gira siempre a su alrededor, así que
	# el viento se lee en cualquier terreno.
	if _vortex != null:
		_vortex.global_position = hero_position
		# Los restos aparecen solo pasado el umbral de mantenido. Un clic corto
		# no llega, que era lo que dejaba hojas flotando al aporrear el botón.
		if _charge >= DEBRIS_THRESHOLD:
			_debris_armed = true
		if _debris_armed:
			_apply_debris_biome(_resolve_biome(hero_position))
		_vortex.emitting = _debris_armed
		_vortex.amount_ratio = clampf(
			smoothstep(DEBRIS_THRESHOLD, 0.9, _charge), 0.08, 1.0
		)
		var process := _vortex.process_material as ParticleProcessMaterial
		if process != null:
			process.tangential_accel_min = lerpf(3.0, 17.0, _intensity)
			process.tangential_accel_max = lerpf(6.0, 26.0, _intensity)
	if _intensity < bolt_threshold:
		_bolt_countdown = 0.0
		return
	# Los rayos se aceleran conforme sube la carga: de uno cada medio segundo a
	# casi encadenados justo antes de soltar. Se probó a encadenarlos más y a
	# alargarlos para que se vieran mejor sobre el verde del valle, pero el
	# resultado quedaba feo: se prefiere el destello escaso y limpio.
	_bolt_countdown -= delta
	if _bolt_countdown <= 0.0:
		_bolt_countdown = lerpf(0.60, 0.22, smoothstep(bolt_threshold, 1.0, _intensity))
		strike(blade_tip, lerpf(0.55, 1.0, _intensity))


func unleash(blade_tip: Vector3) -> void:
	## Descarga final: varios rayos a la vez sobre el filo.
	for index in 4:
		strike(blade_tip + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)), 1.0)


func calm() -> void:
	_intensity = 0.0
	_charge = 0.0
	_bolt_countdown = 0.0
	_debris_armed = false
	_apply_atmosphere(0.0)
	if _vortex != null:
		_vortex.emitting = false


func get_debris_biome() -> String:
	return _debris_biome


func is_debris_active() -> bool:
	return _vortex != null and _vortex.emitting


func _resolve_biome(hero_position: Vector3) -> String:
	if _vegetation != null and _vegetation.has_method("biome_at"):
		return String(_vegetation.call("biome_at", hero_position))
	return "valley"


func _apply_debris_biome(biome: String) -> void:
	## Reconfigura el remolino para el terreno que pisa el héroe. Solo se toca
	## cuando cambia de bioma, así que no cuesta nada por fotograma.
	if biome == _debris_biome:
		return
	var preset: Dictionary = DEBRIS_PRESETS.get(biome, DEBRIS_PRESETS["valley"])
	_debris_biome = biome
	if _vortex == null:
		return
	_vortex.amount = int(preset["amount"])
	_vortex.lifetime = float(preset["lifetime"])
	var process := _vortex.process_material as ParticleProcessMaterial
	if process != null:
		process.gravity = Vector3(0.0, float(preset["rise"]), 0.0)
		process.emission_ring_radius = float(preset["ring_radius"])
		process.emission_ring_height = float(preset["ring_height"])
		process.angular_velocity_min = -float(preset["spin"])
		process.angular_velocity_max = float(preset["spin"])
		process.initial_velocity_min = 1.2 * float(preset["speed"])
		process.initial_velocity_max = 3.4 * float(preset["speed"])
		process.color = preset["color"]
	if _debris_mesh != null:
		_debris_mesh.size = preset["size"]
	if _debris_material != null:
		_debris_material.albedo_color = preset["color"]


func get_intensity() -> float:
	return _intensity


func strike(blade_tip: Vector3, power: float) -> void:
	var bolt := MeshInstance3D.new()
	bolt.name = "LightningBolt"
	bolt.top_level = true
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ImmediateMesh.new()
	bolt.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	bolt.material_override = material
	bolt.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	add_child(bolt)
	_draw_bolt(mesh, blade_tip + Vector3.UP * BOLT_HEIGHT, blade_tip, power)
	# Fogonazo puntual en el filo y un latigazo de claridad en todo el cuadro:
	# es lo que hace que el rayo se sienta y no solo se vea.
	if _flash != null:
		_flash.global_position = blade_tip
		_flash.light_energy = 2.4 * power
		var flash_tween := _flash.create_tween()
		flash_tween.tween_property(_flash, "light_energy", 0.0, 0.18)
	if _environment != null:
		# El relámpago solo devuelve parte de la luz robada: nunca sube del
		# brillo original, o el fotograma entero se quema.
		var storm_level := lerpf(_base_brightness, storm_brightness, _intensity)
		var lit := lerpf(storm_level, _base_brightness, 0.75 * power)
		var sky_tween := create_tween()
		sky_tween.tween_property(_environment, "adjustment_brightness", lit, 0.03)
		sky_tween.tween_property(_environment, "adjustment_brightness", storm_level, 0.15)
	var tween := bolt.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, lerpf(0.14, 0.26, power))
	tween.tween_callback(bolt.queue_free)


func _draw_bolt(mesh: ImmediateMesh, from: Vector3, to: Vector3, power: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera != null else from + Vector3.FORWARD * 20.0
	var points: Array[Vector3] = []
	for step in BOLT_SEGMENTS + 1:
		var ratio := float(step) / float(BOLT_SEGMENTS)
		var straight := from.lerp(to, ratio)
		# La desviación se cierra en los extremos: el rayo nace en el cielo y
		# muere exactamente en la punta del arma.
		var wobble := sin(ratio * PI) * BOLT_SPREAD * power
		straight += Vector3(randf_range(-wobble, wobble), 0.0, randf_range(-wobble, wobble))
		points.append(straight)
	# Una sola cinta fina. Se probó a añadir un halo ancho azulado por debajo
	# para que destacase sobre el verde del valle y quedaba como un borrón: el
	# rayo se lee mejor así, aunque entre los árboles haya que fijarse.
	_draw_ribbon(mesh, points, eye, lerpf(0.035, 0.085, power), Color(SKY_COLOR, 0.88))


func _draw_ribbon(
	mesh: ImmediateMesh,
	points: Array[Vector3],
	eye: Vector3,
	half_width: float,
	tint: Color
) -> void:
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in points.size():
		var point := points[index]
		var along := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
		if along.length_squared() < 0.000001:
			along = Vector3.DOWN
		var side := along.normalized().cross((eye - point).normalized())
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		side = side.normalized() * half_width * lerpf(0.45, 1.0, float(index) / float(points.size() - 1))
		mesh.surface_set_color(tint)
		mesh.surface_add_vertex(point + side)
		mesh.surface_set_color(tint)
		mesh.surface_add_vertex(point - side)
	mesh.surface_end()


func _build_wind_vortex() -> void:
	_vortex = GPUParticles3D.new()
	_vortex.name = "WindVortex"
	_vortex.top_level = true
	_vortex.amount = 190
	_vortex.lifetime = 1.5
	_vortex.local_coords = false
	_vortex.visibility_aabb = AABB(Vector3(-14, -6, -14), Vector3(28, 20, 28))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 5.4
	process.emission_ring_inner_radius = 1.6
	process.emission_ring_height = 2.2
	process.direction = Vector3.UP
	process.spread = 22.0
	process.gravity = Vector3(0.0, 1.1, 0.0)
	process.initial_velocity_min = 1.2
	process.initial_velocity_max = 3.4
	# Aceleración tangencial: es la que convierte la nube en remolino. La radial
	# negativa succiona las hojas hacia el héroe.
	process.tangential_accel_min = 3.0
	process.tangential_accel_max = 6.0
	process.radial_accel_min = -3.4
	process.radial_accel_max = -1.6
	process.angular_velocity_min = -320.0
	process.angular_velocity_max = 320.0
	process.scale_min = 0.6
	process.scale_max = 1.5
	process.color = Color(0.80, 0.86, 0.72, 0.9)
	_vortex.process_material = process
	_debris_mesh = QuadMesh.new()
	_debris_mesh.size = Vector2(0.17, 0.10)
	_debris_material = StandardMaterial3D.new()
	_debris_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debris_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_debris_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_debris_material.albedo_color = Color(0.62, 0.70, 0.45, 0.85)
	_debris_material.vertex_color_use_as_albedo = true
	_debris_mesh.material = _debris_material
	_vortex.draw_pass_1 = _debris_mesh
	_vortex.emitting = false
	add_child(_vortex)


func _apply_atmosphere(intensity: float) -> void:
	if _environment != null:
		_environment.adjustment_brightness = lerpf(_base_brightness, storm_brightness, intensity)
	if _vegetation != null and _vegetation.has_method("set_storm_strength"):
		_vegetation.call("set_storm_strength", intensity)
