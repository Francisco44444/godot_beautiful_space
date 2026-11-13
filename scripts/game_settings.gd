extends Node

## Ajustes persistentes compartidos por el HUD y el renderizador. La distancia
## expresada en metros gobierna el HLOD explícito; el Viewport recibe además un
## umbral equivalente para todos los LOD generados por el importador de Godot.

signal resolution_changed(resolution: Vector2i)
signal lod_distance_changed(distance_metres: float)
signal vsync_changed(enabled: bool)
signal render_profile_changed(profile: int)
signal identity_changed(player_name: String, character_index: int)

const PerfilesRender = preload("res://scripts/perfiles_render.gd")
const RENDER_PROFILE_OPTIONS: Array[String] = ["Nativo", "Equilibrado", "Más fluido"]

const SETTINGS_PATH := "user://graphics_settings.cfg"
const SETTINGS_SCHEMA_VERSION := 2
const LEGACY_DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_RESOLUTION := Vector2i(1600, 900)
const DEFAULT_LOD_DISTANCE := 340.0
const MIN_LOD_DISTANCE := 180.0
const MAX_LOD_DISTANCE := 900.0
const DEFAULT_PLAYER_NAME := "Aventurero"
const DEFAULT_CHARACTER_INDEX := 0
const CHARACTER_OPTIONS: Array[Dictionary] = [
	{"name": "Explorador", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Male.gltf"},
	{"name": "Exploradora", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Female.gltf"},
	{"name": "Caballero", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Knight_Male.gltf"},
	{"name": "Caballera dorada", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Knight_Golden_Female.gltf"},
	{"name": "Vikingo", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Viking_Male.gltf"},
	{"name": "Vikinga", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Viking_Female.gltf"},
	{"name": "Elfo", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Elf.gltf"},
	{"name": "Hechicera", "path": "res://assets/quaternius/ultimate_animated_characters/glTF/Witch.gltf"},
]
const SUPPORTED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var resolution := DEFAULT_RESOLUTION
var lod_distance_metres := DEFAULT_LOD_DISTANCE
var vsync_enabled := true
var render_profile := 0
var settings_path := SETTINGS_PATH
var player_name := DEFAULT_PLAYER_NAME
var character_index := DEFAULT_CHARACTER_INDEX
var _settings_need_migration_save := false


func _ready() -> void:
	_load_settings()
	if _settings_need_migration_save:
		_save_settings()
	_apply_vsync()
	# La reconstrucción sólo se recalcula al cambiar el ajuste o el tamaño real;
	# ampliar la ventana con el ratón no añade trabajo a cada fotograma.
	get_window().size_changed.connect(_apply_render_profile)
	call_deferred("_apply_resolution")
	call_deferred("_apply_render_profile")


func set_resolution(value: Vector2i, persist: bool = true) -> void:
	resolution = _closest_supported_resolution(value)
	_apply_resolution()
	resolution_changed.emit(resolution)
	if persist:
		_save_settings()


func set_lod_distance(value: float, persist: bool = true) -> void:
	lod_distance_metres = snappedf(clampf(value, MIN_LOD_DISTANCE, MAX_LOD_DISTANCE), 10.0)
	lod_distance_changed.emit(lod_distance_metres)
	if persist:
		_save_settings()


func set_vsync_enabled(value: bool, persist: bool = true) -> void:
	vsync_enabled = value
	_apply_vsync()
	vsync_changed.emit(vsync_enabled)
	if persist: _save_settings()


func set_render_profile(value: int, persist: bool = true) -> void:
	render_profile = value if value >= 0 and value < RENDER_PROFILE_OPTIONS.size() else 0
	_apply_render_profile()
	render_profile_changed.emit(render_profile)
	if persist: _save_settings()


func render_profile_description() -> String:
	match render_profile:
		1: return "Reconstruye la imagen 3D para ganar fluidez; los detalles finos pueden perder nitidez. Interfaz a resolución completa."
		2: return "Prioriza los FPS con menor nitidez en la imagen 3D. Interfaz a resolución completa."
	return "Máxima nitidez: imagen 3D e interfaz a resolución completa."


func _apply_render_profile() -> void:
	if not is_inside_tree(): return
	var ventana := get_window()
	var renderer := "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()
	var dispositivo := RenderingServer.get_rendering_device() if renderer == "forward_plus" else null
	var metal_espacial := dispositivo != null and dispositivo.has_feature(RenderingDevice.SUPPORTS_METALFX_SPATIAL)
	var perfil := PerfilesRender.resolver(render_profile,ventana.size,renderer,metal_espacial)
	# El perfil no toca densidad, distancias, iluminación, LOD ni antialiasing.
	# Nativo sigue siendo el valor inicial y el retorno seguro sin soporte.
	ventana.scaling_3d_mode = perfil.mode
	ventana.scaling_3d_scale = perfil.scale


func set_player_identity(name_value: String, index_value: int, persist: bool = true) -> void:
	player_name = _sanitize_player_name(name_value)
	character_index = clampi(index_value, 0, CHARACTER_OPTIONS.size() - 1)
	identity_changed.emit(player_name, character_index)
	if persist:
		_save_settings()


func get_character_options() -> Array[Dictionary]:
	return CHARACTER_OPTIONS.duplicate(true)


func get_character_name(index: int) -> String:
	var safe_index := clampi(index, 0, CHARACTER_OPTIONS.size() - 1)
	return String(CHARACTER_OPTIONS[safe_index].name)


func get_character_path(index: int) -> String:
	var safe_index := clampi(index, 0, CHARACTER_OPTIONS.size() - 1)
	return String(CHARACTER_OPTIONS[safe_index].path)


func reset_defaults(persist: bool = true) -> void:
	set_resolution(DEFAULT_RESOLUTION, false)
	set_lod_distance(DEFAULT_LOD_DISTANCE, false)
	set_vsync_enabled(true, false)
	set_render_profile(0, false)
	set_player_identity(DEFAULT_PLAYER_NAME, DEFAULT_CHARACTER_INDEX, false)
	if persist:
		_save_settings()


func get_supported_resolutions() -> Array[Vector2i]:
	return SUPPORTED_RESOLUTIONS.duplicate()


func action_keys(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "Sin asignar"
	var labels: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			var label := event.as_text().replace(" (Physical)", "")
			if label not in labels:
				labels.append(label)
	return " / ".join(labels) if not labels.is_empty() else "Sin asignar"


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var stored_schema := int(config.get_value("general", "schema_version", 1))
	var stored_width := int(config.get_value("video", "width", DEFAULT_RESOLUTION.x))
	var stored_height := int(config.get_value("video", "height", DEFAULT_RESOLUTION.y))
	var stored_resolution := Vector2i(stored_width, stored_height)
	# Las instalaciones existentes guardaron 1280×720 como valor inicial. Se
	# migra una sola vez al nuevo tamaño; después, si el usuario elige 1280 desde
	# Gráficos, la versión 2 de la configuración respetará esa decisión.
	if stored_schema < SETTINGS_SCHEMA_VERSION and stored_resolution == LEGACY_DEFAULT_RESOLUTION:
		stored_resolution = DEFAULT_RESOLUTION
	resolution = _closest_supported_resolution(stored_resolution)
	vsync_enabled = bool(config.get_value("video", "vsync_enabled", true))
	var stored_profile := int(config.get_value("graphics", "render_profile", 0))
	render_profile = stored_profile if stored_profile >= 0 and stored_profile < RENDER_PROFILE_OPTIONS.size() else 0
	lod_distance_metres = snappedf(clampf(
		float(config.get_value("graphics", "lod_distance_metres", DEFAULT_LOD_DISTANCE)),
		MIN_LOD_DISTANCE,
		MAX_LOD_DISTANCE
	), 10.0)
	player_name = _sanitize_player_name(String(config.get_value("identity", "player_name", DEFAULT_PLAYER_NAME)))
	character_index = clampi(
		int(config.get_value("identity", "character_index", DEFAULT_CHARACTER_INDEX)),
		0,
		CHARACTER_OPTIONS.size() - 1
	)
	_settings_need_migration_save = stored_schema < SETTINGS_SCHEMA_VERSION


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "schema_version", SETTINGS_SCHEMA_VERSION)
	config.set_value("video", "width", resolution.x)
	config.set_value("video", "height", resolution.y)
	config.set_value("video", "vsync_enabled", vsync_enabled)
	config.set_value("graphics", "render_profile", render_profile)
	config.set_value("graphics", "lod_distance_metres", lod_distance_metres)
	config.set_value("identity", "player_name", player_name)
	config.set_value("identity", "character_index", character_index)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("No se pudieron guardar los ajustes gráficos: %s" % error_string(error))


func _apply_vsync() -> void:
	if DisplayServer.get_name().to_lower()=="headless": return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)


func _apply_resolution() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(usable.position + (usable.size - resolution) / 2)


func _closest_supported_resolution(value: Vector2i) -> Vector2i:
	var closest := DEFAULT_RESOLUTION
	var closest_distance := INF
	for candidate in SUPPORTED_RESOLUTIONS:
		var distance := Vector2(candidate - value).length_squared()
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _sanitize_player_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while "  " in clean:
		clean = clean.replace("  ", " ")
	if clean.is_empty():
		clean = DEFAULT_PLAYER_NAME
	return clean.left(24)
