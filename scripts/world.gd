extends Node3D

## Conecta los elementos jugables con la altura real de Terrain3D y mantiene
## una indicación sencilla hacia el mirador de la Fase 2.

const LOOKOUT_POSITION := Vector3(98.0, 0.0, -110.0)

@export_category("Ciclo de luz")
@export var sun_cycle_enabled := true
@export_range(90.0, 1200.0, 10.0) var sun_cycle_seconds := 300.0

@onready var terrain: Terrain3D = $Terrain3D
@onready var player: Player = $Player
@onready var horse: Horse = $Horse
@onready var lookout: Node3D = $Lookout
@onready var objective: Label = $HUD/Objective
@onready var sun: DirectionalLight3D = $Sun
@onready var sky_fill: DirectionalLight3D = $SkyFill
@onready var world_environment: WorldEnvironment = $WorldEnvironment

var lookout_reached := false
var sun_cycle_radians := 0.0


func _ready() -> void:
	_place_on_terrain(player, 0.12)
	player.spawn_position = player.global_position
	_place_on_terrain(horse, 0.12)
	horse.spawn_position = horse.global_position
	_place_on_terrain(lookout, 0.04)


func _process(delta: float) -> void:
	_update_sun_cycle(delta)
	var flat_player := Vector2(player.global_position.x, player.global_position.z)
	var flat_lookout := Vector2(LOOKOUT_POSITION.x, LOOKOUT_POSITION.z)
	var distance := flat_player.distance_to(flat_lookout)

	if distance < 18.0:
		lookout_reached = true

	if lookout_reached:
		objective.text = "✦ Mirador alcanzado · contempla el valle"
	else:
		objective.text = "✦ Sigue el sendero ocre hasta el mirador · %d m" % roundi(distance)


func _place_on_terrain(node: Node3D, vertical_offset: float) -> void:
	var height := terrain.data.get_height(node.global_position)
	if not is_nan(height):
		node.global_position.y = height + vertical_offset


func _update_sun_cycle(delta: float) -> void:
	if not sun_cycle_enabled or sun_cycle_seconds <= 0.0:
		return
	sun_cycle_radians = fmod(sun_cycle_radians + delta * TAU / sun_cycle_seconds, TAU)
	# Arco continuo de amanecer a tarde. Mantiene el valle jugable y luminoso,
	# pero desplaza claramente las sombras y la temperatura del cielo.
	var arc := (sin(sun_cycle_radians) + 1.0) * 0.5
	var elevation_degrees := lerpf(-24.0, -138.0, arc)
	sun.rotation_degrees.x = elevation_degrees
	sun.rotation_degrees.y = -122.0 + cos(sun_cycle_radians) * 34.0
	var daylight := sin(deg_to_rad(absf(elevation_degrees)))
	sun.light_energy = lerpf(0.78, 1.34, daylight)
	sun.light_color = Color(1.0, lerpf(0.79, 0.94, daylight), lerpf(0.62, 0.84, daylight))
	sky_fill.light_energy = lerpf(0.34, 0.16, daylight)

	var environment := world_environment.environment
	if environment == null or environment.sky == null:
		return
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material == null:
		return
	var edge_light := 1.0 - daylight
	sky_material.sky_top_color = Color(0.16, 0.50, 0.88).lerp(Color(0.28, 0.43, 0.70), edge_light * 0.45)
	sky_material.sky_horizon_color = Color(0.82, 0.94, 1.0).lerp(Color(1.0, 0.66, 0.40), edge_light * 0.48)
