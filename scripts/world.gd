extends Node3D

## Conecta el mundo de 100 km² y gobierna un ciclo completo con amanecer,
## atardecer y noche real, incluida la iluminación ambiental.

const LOOKOUT_POSITION := Vector3(98.0, 0.0, -110.0)
const FAST_TRAVEL_POINTS: Array[Dictionary] = [
	{"name": "Dunas Doradas", "position": Vector2(2350.0, 2050.0)},
	{"name": "Cumbres Blancas", "position": Vector2(520.0, -3000.0)},
	{"name": "Villa Robledal", "position": Vector2(-1450.0, 650.0)},
	{"name": "Bosque Umbrío", "position": Vector2(-2180.0, 1650.0)},
]

@export_category("Ciclo de luz")
@export var sun_cycle_enabled := true
@export_range(120.0, 1800.0, 10.0) var sun_cycle_seconds := 480.0

@onready var terrain: Terrain3D = $Terrain3D
@onready var player: Player = $Player
@onready var horse: Horse = $Horse
@onready var lookout: Node3D = $Lookout
@onready var objective: Label = $HUD/Objective
@onready var sun: DirectionalLight3D = $Sun
@onready var sky_fill: DirectionalLight3D = $SkyFill
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var camera_rig: ThirdPersonCamera = $CameraRig

var lookout_reached := false
var sun_cycle_radians := 0.86
var daylight_factor := 1.0
var time_of_day := "Día"
var last_fast_travel_slot := 0
var _fast_travel_notice := ""
var _fast_travel_notice_time := 0.0


func _ready() -> void:
	_place_on_terrain(player, 0.12)
	player.spawn_position = player.global_position
	_place_on_terrain(horse, 0.12)
	horse.spawn_position = horse.global_position
	_place_on_terrain(lookout, 0.04)


func _process(delta: float) -> void:
	_update_sun_cycle(delta)
	_fast_travel_notice_time = maxf(_fast_travel_notice_time - delta, 0.0)
	var flat_player := Vector2(player.global_position.x, player.global_position.z)
	var flat_lookout := Vector2(LOOKOUT_POSITION.x, LOOKOUT_POSITION.z)
	var distance := flat_player.distance_to(flat_lookout)

	if distance < 18.0:
		lookout_reached = true

	if _fast_travel_notice_time > 0.0:
		objective.text = _fast_travel_notice
	elif lookout_reached:
		objective.text = "✦ Mirador alcanzado · %s · M abre el mapa de la isla" % time_of_day
	else:
		objective.text = "✦ %s · sigue el sendero al mirador · %d m · M mapa" % [time_of_day, roundi(distance)]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	var slot := 0
	match pressed_key:
		KEY_1:
			slot = 1
		KEY_2:
			slot = 2
		KEY_3:
			slot = 3
		KEY_4:
			slot = 4
	if slot > 0 and fast_travel_to(slot):
		get_viewport().set_input_as_handled()


func fast_travel_to(slot: int) -> bool:
	if slot < 1 or slot > FAST_TRAVEL_POINTS.size() or terrain.data == null:
		return false
	var destination: Dictionary = FAST_TRAVEL_POINTS[slot - 1]
	var point: Vector2 = destination.position
	var height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
	if is_nan(height):
		push_warning("No se pudo encontrar terreno para el viaje rápido %d." % slot)
		return false
	var was_mounted := player.is_mounted()
	if was_mounted:
		player.dismount()
	player.global_position = Vector3(point.x, height + 0.18, point.y)
	player.velocity = Vector3.ZERO
	player.spawn_position = player.global_position
	last_fast_travel_slot = slot
	_fast_travel_notice = "✦ Viaje rápido %d · %s%s" % [slot, destination.name, " · has desmontado" if was_mounted else ""]
	_fast_travel_notice_time = 3.5
	if camera_rig != null:
		camera_rig.snap_to_target()
	return true


func get_fast_travel_count() -> int:
	return FAST_TRAVEL_POINTS.size()


func get_fast_travel_position(slot: int) -> Vector2:
	if slot < 1 or slot > FAST_TRAVEL_POINTS.size():
		return Vector2(INF, INF)
	return FAST_TRAVEL_POINTS[slot - 1].position


func _place_on_terrain(node: Node3D, vertical_offset: float) -> void:
	var height := terrain.data.get_height(node.global_position)
	if not is_nan(height):
		node.global_position.y = height + vertical_offset


func _update_sun_cycle(delta: float) -> void:
	if not sun_cycle_enabled or sun_cycle_seconds <= 0.0:
		return
	sun_cycle_radians = fmod(sun_cycle_radians + delta * TAU / sun_cycle_seconds, TAU)
	var solar_height := sin(sun_cycle_radians)
	daylight_factor = smoothstep(-0.12, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.02, 0.34, absf(solar_height))
	sun.rotation_degrees.x = -rad_to_deg(sun_cycle_radians)
	sun.rotation_degrees.y = -122.0 + sin(sun_cycle_radians * 0.5) * 18.0
	sun.light_energy = daylight_factor * lerpf(0.62, 1.35, maxf(solar_height, 0.0))
	sun.light_color = Color(1.0, 0.58, 0.32).lerp(Color(1.0, 0.93, 0.79), smoothstep(0.05, 0.62, solar_height))
	sky_fill.light_energy = lerpf(0.19, 0.22, daylight_factor)
	sky_fill.light_color = Color(0.34, 0.44, 0.78).lerp(Color(0.58, 0.7, 0.92), daylight_factor)
	if daylight_factor < 0.14:
		time_of_day = "Noche"
	elif twilight > 0.48 and sun_cycle_radians > PI * 0.5:
		time_of_day = "Atardecer"
	elif twilight > 0.48:
		time_of_day = "Amanecer"
	else:
		time_of_day = "Día"

	var environment := world_environment.environment
	if environment == null or environment.sky == null:
		return
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material == null:
		return
	var night_top := Color(0.012, 0.025, 0.10)
	var night_horizon := Color(0.075, 0.11, 0.20)
	var day_top := Color(0.16, 0.50, 0.88)
	var day_horizon := Color(0.82, 0.94, 1.0)
	var sunset_horizon := Color(1.0, 0.36, 0.12)
	sky_material.sky_top_color = night_top.lerp(day_top, daylight_factor)
	sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight_factor).lerp(sunset_horizon, twilight * 0.72)
	sky_material.ground_bottom_color = Color(0.018, 0.025, 0.045).lerp(Color(0.20, 0.31, 0.18), daylight_factor)
	environment.ambient_light_energy = lerpf(0.22, 0.66, daylight_factor)
	environment.ambient_light_color = Color(0.28, 0.36, 0.62).lerp(Color(0.91, 0.93, 0.87), daylight_factor)
	environment.tonemap_exposure = lerpf(0.84, 0.98, daylight_factor)
	for lantern in get_tree().get_nodes_in_group("night_lantern"):
		(lantern as OmniLight3D).light_energy = lerpf(4.8, 0.18, daylight_factor)
	for glow in get_tree().get_nodes_in_group("night_lantern_glow"):
		(glow as MeshInstance3D).visible = daylight_factor < 0.72
