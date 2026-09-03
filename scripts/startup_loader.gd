class_name StartupLoader
extends Control

## Pantalla mínima que se renderiza antes de solicitar el mundo pesado. No
## referencia world.tscn como ExtResource, de modo que la ventana aparece sin
## esperar a Terrain3D, personajes ni decorado.

const WORLD_PATH := "res://scenes/world.tscn"

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var stage_label: Label = %StageLabel

var _load_started := false
var _instantiating := false
var _progress: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	progress_bar.value = 2.0
	stage_label.text = "Preparando la expedición…"
	call_deferred("_begin_world_load")


func _begin_world_load() -> void:
	var error := ResourceLoader.load_threaded_request(WORLD_PATH, "PackedScene", true)
	if error != OK:
		stage_label.text = "No se pudo iniciar la carga del mundo"
		push_error("No se pudo solicitar %s: %s" % [WORLD_PATH, error_string(error)])
		return
	_load_started = true


func _process(_delta: float) -> void:
	if not _load_started or _instantiating:
		return
	var status := ResourceLoader.load_threaded_get_status(WORLD_PATH, _progress)
	if not _progress.is_empty():
		progress_bar.value = lerpf(5.0, 82.0, clampf(float(_progress[0]), 0.0, 1.0))
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			stage_label.text = "Cargando recursos del mundo…"
		ResourceLoader.THREAD_LOAD_LOADED:
			_instantiating = true
			progress_bar.value = 86.0
			stage_label.text = "Colocando el paisaje…"
			call_deferred("_enter_world")
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_load_started = false
			stage_label.text = "La carga del mundo ha fallado"
			push_error("Falló la carga en segundo plano de %s" % WORLD_PATH)


func _enter_world() -> void:
	# El layout de vegetación ya está horneado; esta instanciación conserva el
	# aspecto actual pero evita millones de comprobaciones de terreno.
	var packed := ResourceLoader.load_threaded_get(WORLD_PATH) as PackedScene
	if packed == null:
		stage_label.text = "No se pudo abrir el mundo"
		return
	var world := packed.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	progress_bar.value = 100.0
	queue_free()
