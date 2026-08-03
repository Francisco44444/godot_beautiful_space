extends Node3D

## Conecta los elementos jugables con la altura real de Terrain3D y mantiene
## una indicación sencilla hacia el mirador de la Fase 2.

const LOOKOUT_POSITION := Vector3(98.0, 0.0, -110.0)

@onready var terrain: Terrain3D = $Terrain3D
@onready var player: Player = $Player
@onready var horse: Horse = $Horse
@onready var lookout: Node3D = $Lookout
@onready var objective: Label = $HUD/Objective

var lookout_reached := false


func _ready() -> void:
	_place_on_terrain(player, 0.12)
	player.spawn_position = player.global_position
	_place_on_terrain(horse, 0.12)
	horse.spawn_position = horse.global_position
	_place_on_terrain(lookout, 0.04)


func _process(_delta: float) -> void:
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
