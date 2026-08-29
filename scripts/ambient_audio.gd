class_name AmbientAudio
extends Node

## Mezcla tres canciones acreditadas de FiftySounds según el bioma con los
## ambientes originales de viento y pájaros generados en tools/generate_audio.py.

@export var fade_in_seconds := 4.5
@export var music_volume_db := -11.0
@export var wind_volume_db := -12.0
@export var birds_volume_db := -17.0
@export var horse_path := NodePath("../Horse")
@export var player_path := NodePath("../Player")
@export var terrain_path := NodePath("../Terrain3D")

@onready var music: AudioStreamPlayer = $Music
@onready var snow_music: AudioStreamPlayer = $SnowMusic
@onready var desert_music: AudioStreamPlayer = $DesertMusic
@onready var wind: AudioStreamPlayer = $Wind
@onready var birds: AudioStreamPlayer = $Birds
@onready var horse: Horse = get_node_or_null(horse_path) as Horse
@onready var player: Player = get_node_or_null(player_path) as Player
@onready var terrain: Terrain3D = get_node_or_null(terrain_path) as Terrain3D

var layers_started := 0
var current_music_zone := "valley"
var snow_music_weight := 0.0
var desert_music_weight := 0.0
var dark_forest_weight := 0.0
var music_transition_count := 0


func _ready() -> void:
	_start_loop(music)
	_start_loop(snow_music)
	_start_loop(desert_music)
	_start_loop(wind)
	_start_loop(birds)


func _process(delta: float) -> void:
	# Al galopar, el viento sube ligeramente y deja más espacio a los cascos;
	# al detenerse, vuelve la mezcla contemplativa sin un salto perceptible.
	var riding_amount := 0.0
	if horse != null and horse.mounted:
		var speed := Vector2(horse.velocity.x, horse.velocity.z).length()
		riding_amount = clampf(speed / horse.gallop_speed, 0.0, 1.0)
	_update_biome_weights()
	var fade_speed := 52.0 / maxf(fade_in_seconds, 0.1)
	var music_base_db := music_volume_db - riding_amount * 1.8
	var special_weight := clampf(maxf(maxf(snow_music_weight, desert_music_weight), dark_forest_weight), 0.0, 1.0)
	var valley_weight := 1.0 - special_weight
	music.volume_db = move_toward(music.volume_db, _weighted_music_db(music_base_db, valley_weight), fade_speed * delta)
	# El bosque tenebroso no recibe una cuarta canción: el silencio musical es
	# parte de su identidad. Este factor también evita que se filtre una cola de
	# Promise o Ashes al atravesar transiciones cercanas.
	var audible_music := 1.0 - dark_forest_weight
	snow_music.volume_db = move_toward(snow_music.volume_db, _weighted_music_db(music_base_db, snow_music_weight * audible_music), fade_speed * delta)
	desert_music.volume_db = move_toward(desert_music.volume_db, _weighted_music_db(music_base_db, desert_music_weight * audible_music), fade_speed * delta)
	wind.volume_db = move_toward(wind.volume_db, wind_volume_db + riding_amount * 4.5, fade_speed * delta)
	# Los pájaros pertenecen al valle templado. Desaparecen progresivamente antes
	# de entrar en nieve, desierto o Bosque Tenebroso, sin cortes en los límites.
	var bird_biome_mute := smoothstep(0.08, 0.62, maxf(maxf(desert_music_weight, snow_music_weight), dark_forest_weight))
	var bird_target := lerpf(birds_volume_db - riding_amount * 3.0, -60.0, bird_biome_mute)
	birds.volume_db = move_toward(birds.volume_db, bird_target, fade_speed * delta)


func _update_biome_weights() -> void:
	var listener_position := Vector3.ZERO
	if horse != null and horse.mounted:
		listener_position = horse.global_position
	elif player != null:
		listener_position = player.global_position
	else:
		return
	var point := Vector2(listener_position.x, listener_position.z)
	var dark_local := point - Vector2(4520.0, -1320.0)
	var dark_radius := sqrt(pow(dark_local.x / 1500.0, 2.0) + pow(dark_local.y / 1120.0, 2.0))
	dark_forest_weight = 1.0 - smoothstep(0.72, 1.08, dark_radius)
	var desert_local := point - Vector2(2350.0, 2050.0)
	var desert_radius := sqrt(pow(desert_local.x / 1420.0, 2.0) + pow(desert_local.y / 1220.0, 2.0))
	desert_music_weight = (1.0 - smoothstep(0.78, 1.04, desert_radius)) * (1.0 - dark_forest_weight)

	var height := listener_position.y
	if terrain != null and terrain.data != null:
		var terrain_height := terrain.data.get_height(Vector3(point.x, 0.0, point.y))
		if not is_nan(terrain_height):
			height = terrain_height
	var snow_offset := point - Vector2(150.0, -3400.0)
	var northern := exp(-((snow_offset.x * snow_offset.x) / (2.0 * 1650.0 * 1650.0) + (snow_offset.y * snow_offset.y) / (2.0 * 1250.0 * 1250.0)))
	var snow_strength := northern * smoothstep(90.0, 260.0, height)
	var snow_probability := smoothstep(0.22, 0.78, snow_strength)
	snow_music_weight = smoothstep(0.10, 0.52, snow_probability) * (1.0 - desert_music_weight) * (1.0 - dark_forest_weight)

	var next_zone := "valley"
	if dark_forest_weight >= 0.5:
		next_zone = "dark_forest"
	elif desert_music_weight >= 0.5:
		next_zone = "desert"
	elif snow_music_weight >= 0.5:
		next_zone = "snow"
	if next_zone != current_music_zone:
		current_music_zone = next_zone
		music_transition_count += 1


func _weighted_music_db(base_db: float, weight: float) -> float:
	if weight <= 0.001:
		return -60.0
	# Raíz cuadrada para un crossfade de potencia aproximadamente constante.
	return maxf(-60.0, base_db + linear_to_db(sqrt(weight)))


func _start_loop(player: AudioStreamPlayer) -> void:
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = true
	elif player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = true
	player.volume_db = -60.0
	player.play()
	layers_started += 1


func all_layers_playing() -> bool:
	return music.playing and snow_music.playing and desert_music.playing and wind.playing and birds.playing


func _exit_tree() -> void:
	# Cierra los playbacks explícitamente; también mantiene limpias las pruebas
	# headless que terminan el SceneTree mientras los loops siguen activos.
	if is_instance_valid(music):
		music.stop()
	if is_instance_valid(snow_music):
		snow_music.stop()
	if is_instance_valid(desert_music):
		desert_music.stop()
	if is_instance_valid(wind):
		wind.stop()
	if is_instance_valid(birds):
		birds.stop()
