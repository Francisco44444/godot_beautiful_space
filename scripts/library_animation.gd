class_name LibraryAnimation
extends SkeletonModifier3D

## Reproduce animaciones de la *Universal Animation Library 2* sobre el rig de
## Quaternius, que tiene otros huesos y otra pose de reposo.
##
## La biblioteca usa un esqueleto de estilo Unreal (`upperarm_r`, `hand_r`,
## `spine_02`…) y su pose de bind es distinta de la del héroe, así que copiar
## rotaciones tal cual retuerce al personaje. En su lugar se transfiere el
## *delta global* respecto a una pose de referencia equivalente en cada rig: se
## mide cuánto se ha girado cada hueso de la biblioteca desde su referencia y se
## aplica ese mismo giro sobre la referencia del héroe. Así cada esqueleto parte
## de su propio reposo y el gesto se conserva.

const LIBRARY_PATH := "res://assets/animations/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"
## Las dos referencias tienen que ser poses EQUIVALENTES —de pie, brazos
## caídos— una en cada rig. Transferir el delta contra referencias distintas es
## lo que mandaba la mano por encima de la cabeza.
const SOURCE_REFERENCE := "Idle_No_Loop"
const TARGET_REFERENCE := "Idle"
## Correspondencia de huesos. Se omiten dedos y `root`: el rig del héroe no los
## tiene y su movimiento lo aporta el propio desplazamiento del personaje.
const BONE_MAP := {
	"pelvis": "Hips",
	"spine_01": "Abdomen",
	"spine_02": "Torso",
	"neck_01": "Neck",
	"Head": "Head",
	"clavicle_l": "Shoulder.L",
	"upperarm_l": "UpperArm.L",
	"lowerarm_l": "LowerArm.L",
	"hand_l": "Fist.L",
	"clavicle_r": "Shoulder.R",
	"upperarm_r": "UpperArm.R",
	"lowerarm_r": "LowerArm.R",
	"hand_r": "Fist.R",
	"thigh_l": "UpperLeg.L",
	"calf_l": "LowerLeg.L",
	"thigh_r": "UpperLeg.R",
	"calf_r": "LowerLeg.R",
}
## Huesos que el retargeting no toca cuando solo interesa la mitad superior: así
## el héroe puede blandir la espada de la biblioteca mientras sus piernas siguen
## caminando con la animación propia.
const LOWER_BODY: Array[String] = ["Hips", "UpperLeg.L", "LowerLeg.L", "UpperLeg.R", "LowerLeg.R"]

## Solo se aplica el tren superior. Es lo que permite atacar en movimiento. Los
## gestos que se apoderan del cuerpo entero —talar, abrir un cofre, aterrizar—
## lo desactivan; el cambio invalida los enlaces, que se recalculan solos.
var upper_body_only := true:
	set(value):
		if upper_body_only == value:
			return
		upper_body_only = value
		_links.clear()
## Si no está vacío, solo estos huesos del héroe reciben la pose. La usa la
## postura de recarga, que solo quiere el brazo: al transferir también la columna
## el tronco se doblaba mucho más de lo que trae el fotograma original.
var bone_filter: PackedStringArray = PackedStringArray():
	set(value):
		if bone_filter == value:
			return
		bone_filter = value
		_links.clear()

var _source_root: Node3D
var _source_skeleton: Skeleton3D
var _source_player: AnimationPlayer
var _available: PackedStringArray = PackedStringArray()
## bone_name del héroe -> {"source": índice origen, "target": índice destino,
## "delta_base": Basis de referencia del origen, "target_ref": Basis del héroe}
var _links: Array[Dictionary] = []
var _current := ""
var _ready_to_play := false
## Bases de referencia de los dos rigs, cacheadas una sola vez. Calibrar exige
## mover los dos reproductores a su pose de referencia, así que no puede
## repetirse cada vez que cambia el filtro de huesos: se veía un tirón en el
## héroe al alternar entre gestos de tren superior y de cuerpo entero.
var _source_ref: Dictionary = {}
var _target_ref: Dictionary = {}
var _calibrated := false
## Reproductor del héroe, necesario para poder situarlo en su pose de referencia
## mientras se calibran las bases.
var target_animator: AnimationPlayer
## Dónde colgar el esqueleto de la biblioteca. Tiene que quedar FUERA del modelo
## del héroe: dentro, su `AnimationPlayer` y su `Skeleton3D` suplantaban a los
## del personaje en cualquier búsqueda por nombre o por tipo.
var source_host: Node


func _ready() -> void:
	_load_library()


func _exit_tree() -> void:
	## El esqueleto fuente vive fuera de este nodo, así que hay que retirarlo a
	## mano cuando el modificador desaparece con el modelo del héroe.
	if _source_root != null and is_instance_valid(_source_root):
		_source_root.queue_free()
	_source_root = null


func resolve(animation_name: String) -> String:
	## El importador de Godot recorta el sufijo `_Loop` y marca la animación como
	## cíclica, así que el nombre del glTF crudo y el del recurso importado no
	## coinciden. Se aceptan los dos.
	if animation_name in _available:
		return animation_name
	if animation_name.ends_with("_Loop"):
		var trimmed := animation_name.trim_suffix("_Loop")
		if trimmed in _available:
			return trimmed
	var suffixed := animation_name + "_Loop"
	return suffixed if suffixed in _available else ""


func has_animation(animation_name: String) -> bool:
	return not resolve(animation_name).is_empty()


func get_available() -> PackedStringArray:
	return _available


func is_playing_library() -> bool:
	return _ready_to_play and not _current.is_empty() and _source_player.is_playing()


func get_current() -> String:
	return _current


func get_length(animation_name: String) -> float:
	var resolved := resolve(animation_name)
	return _source_player.get_animation(resolved).length if not resolved.is_empty() else 0.0


func play_library(animation_name: String, speed: float = 1.0, from_start: bool = true) -> bool:
	if not _ready_to_play:
		return false
	var resolved := resolve(animation_name)
	if resolved.is_empty():
		return false
	if _current != resolved or from_start:
		_source_player.play(resolved, 0.05)
		_source_player.seek(0.0, true)
	_source_player.speed_scale = speed
	_current = resolved
	return true


func hold_library(animation_name: String, time: float) -> bool:
	## Congela un fotograma concreto. Es lo que necesitan las poses sostenidas
	## —recarga, guardia— frente a `play_library`, que reproduce.
	##
	## Se mezcla con blend 0 y se vuelve a buscar el fotograma en cada llamada:
	## con `speed_scale = 0` un crossfade pendiente no terminaría nunca, porque
	## la animación ya no avanza.
	if not _ready_to_play:
		return false
	var resolved := resolve(animation_name)
	if resolved.is_empty():
		return false
	if _current != resolved:
		_source_player.play(resolved, 0.0)
		_current = resolved
	_source_player.speed_scale = 0.0
	_source_player.seek(clampf(time, 0.0, _source_player.get_animation(resolved).length), true)
	return true


func stop_library() -> void:
	_current = ""
	if _source_player != null:
		_source_player.speed_scale = 1.0
		_source_player.stop()


func seek_library(time: float) -> void:
	if _ready_to_play and not _current.is_empty():
		_source_player.seek(time, true)


func get_position_in_library() -> float:
	return _source_player.current_animation_position if _ready_to_play else 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not _ready_to_play or _current.is_empty() or influence <= 0.001:
		return
	if _links.is_empty():
		_build_links(skeleton)
	var weight := clampf(influence, 0.0, 1.0)
	for link in _links:
		var target_bone := int(link["target"])
		var source_bone := int(link["source"])
		# Giro acumulado del hueso de la biblioteca desde su pose de referencia.
		var moved := _source_skeleton.get_bone_global_pose(source_bone).basis.orthonormalized()
		var delta := moved * (link["delta_base"] as Basis)
		var wanted := (delta * (link["target_ref"] as Basis)).orthonormalized()
		var current := skeleton.get_bone_global_pose(target_bone)
		var blended := current.basis.orthonormalized().slerp(wanted, weight)
		skeleton.set_bone_global_pose(target_bone, Transform3D(blended, current.origin))


func _load_library() -> void:
	var imported := ResourceLoader.load(LIBRARY_PATH)
	if imported is PackedScene:
		_source_root = (imported as PackedScene).instantiate() as Node3D
	else:
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		if document.append_from_file(LIBRARY_PATH, state) != OK:
			push_warning("No se pudo abrir la biblioteca de animaciones: %s" % LIBRARY_PATH)
			return
		_source_root = document.generate_scene(state) as Node3D
	if _source_root == null:
		return
	_source_root.name = "AnimationLibrarySource"
	# El esqueleto de la biblioteca solo sirve como fuente de poses: no se
	# dibuja nada de él.
	_source_root.visible = false
	var host: Node = source_host if source_host != null else self
	host.add_child(_source_root)
	for node in _source_root.find_children("*", "Skeleton3D", true, false):
		_source_skeleton = node as Skeleton3D
		break
	for node in _source_root.find_children("*", "AnimationPlayer", true, false):
		_source_player = node as AnimationPlayer
		break
	if _source_player != null:
		# Nombre propio para que ninguna búsqueda del juego lo confunda con el
		# reproductor del héroe.
		_source_player.name = "LibraryAnimationPlayer"
	if _source_skeleton == null or _source_player == null:
		push_warning("La biblioteca de animaciones no trae esqueleto ni reproductor.")
		return
	for mesh_node in _source_root.find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).visible = false
	_available = PackedStringArray(_source_player.get_animation_list())
	for animation_name in _available:
		if animation_name.ends_with("_Loop"):
			_source_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	_ready_to_play = true


func _calibrate(skeleton: Skeleton3D) -> void:
	## Mide las bases de referencia de los dos rigs. Las dos poses tienen que ser
	## equivalentes —de pie, brazos caídos—, así que hay que colocar cada
	## reproductor en la suya. Se hace una única vez para todos los huesos del
	## mapa: los filtros se aplican luego, sin volver a mover a nadie.
	var reference := resolve(SOURCE_REFERENCE)
	if reference.is_empty():
		return
	var previous := _current
	var previous_time := _source_player.current_animation_position
	var previous_speed := _source_player.speed_scale
	_source_player.speed_scale = 1.0
	_source_player.play(reference, 0.0)
	_source_player.seek(0.0, true)
	_source_player.advance(0.0)
	# El héroe también se coloca en su referencia: sin esto se tomaba como base
	# la pose que tuviera en ese fotograma, que es arbitraria.
	var target_previous := ""
	var target_previous_time := 0.0
	if target_animator != null and target_animator.has_animation(TARGET_REFERENCE):
		target_previous = target_animator.current_animation
		target_previous_time = target_animator.current_animation_position
		target_animator.play(TARGET_REFERENCE, 0.0)
		target_animator.seek(0.0, true)
		target_animator.advance(0.0)
	for source_name in BONE_MAP:
		var target_name := String(BONE_MAP[source_name])
		var source_bone := _source_skeleton.find_bone(String(source_name))
		var target_bone := skeleton.find_bone(target_name)
		if source_bone < 0 or target_bone < 0:
			continue
		_source_ref[target_name] = _source_skeleton.get_bone_global_pose(source_bone).basis.orthonormalized()
		_target_ref[target_name] = skeleton.get_bone_global_pose(target_bone).basis.orthonormalized()
	if not previous.is_empty():
		_source_player.play(previous, 0.0)
		_source_player.seek(previous_time, true)
		_source_player.speed_scale = previous_speed
	if not target_previous.is_empty():
		target_animator.play(target_previous, 0.0)
		target_animator.seek(target_previous_time, true)
	_calibrated = not _source_ref.is_empty()


func _build_links(skeleton: Skeleton3D) -> void:
	if not _calibrated:
		_calibrate(skeleton)
		if not _calibrated:
			return
	for source_name in BONE_MAP:
		var target_name := String(BONE_MAP[source_name])
		if upper_body_only and target_name in LOWER_BODY:
			continue
		if not bone_filter.is_empty() and target_name not in bone_filter:
			continue
		if not _source_ref.has(target_name):
			continue
		var source_bone := _source_skeleton.find_bone(String(source_name))
		var target_bone := skeleton.find_bone(target_name)
		if source_bone < 0 or target_bone < 0:
			continue
		_links.append({
			"source": source_bone,
			"target": target_bone,
			"delta_base": (_source_ref[target_name] as Basis).inverse(),
			"target_ref": _target_ref[target_name],
		})
