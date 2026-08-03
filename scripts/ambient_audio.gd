class_name AmbientAudio
extends Node

## Mezcla las tres capas continuas de la Fase 6. Los Ogg son composiciones y
## ambientes originales generados en tools/generate_audio.py.

@export var fade_in_seconds := 4.5
@export var music_volume_db := -8.5
@export var wind_volume_db := -12.0
@export var birds_volume_db := -17.0
@export var horse_path := NodePath("../Horse")

@onready var music: AudioStreamPlayer = $Music
@onready var wind: AudioStreamPlayer = $Wind
@onready var birds: AudioStreamPlayer = $Birds
@onready var horse: Horse = get_node_or_null(horse_path) as Horse

var layers_started := 0


func _ready() -> void:
	_start_loop(music)
	_start_loop(wind)
	_start_loop(birds)


func _process(delta: float) -> void:
	# Al galopar, el viento sube ligeramente y deja más espacio a los cascos;
	# al detenerse, vuelve la mezcla contemplativa sin un salto perceptible.
	var riding_amount := 0.0
	if horse != null and horse.mounted:
		var speed := Vector2(horse.velocity.x, horse.velocity.z).length()
		riding_amount = clampf(speed / horse.gallop_speed, 0.0, 1.0)
	var fade_speed := 52.0 / maxf(fade_in_seconds, 0.1)
	music.volume_db = move_toward(music.volume_db, music_volume_db - riding_amount * 1.8, fade_speed * delta)
	wind.volume_db = move_toward(wind.volume_db, wind_volume_db + riding_amount * 4.5, fade_speed * delta)
	birds.volume_db = move_toward(birds.volume_db, birds_volume_db - riding_amount * 3.0, fade_speed * delta)


func _start_loop(player: AudioStreamPlayer) -> void:
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = true
	player.volume_db = -60.0
	player.play()
	layers_started += 1


func all_layers_playing() -> bool:
	return music.playing and wind.playing and birds.playing


func _exit_tree() -> void:
	# Cierra los playbacks explícitamente; también mantiene limpias las pruebas
	# headless que terminan el SceneTree mientras los loops siguen activos.
	if is_instance_valid(music):
		music.stop()
	if is_instance_valid(wind):
		wind.stop()
	if is_instance_valid(birds):
		birds.stop()
