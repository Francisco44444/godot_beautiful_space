extends CanvasLayer

@onready var hint: Label = $Margin/Panel/Padding/Content/MouseHint
@onready var controls: Label = $Margin/Panel/Padding/Content/Controls
@onready var mount_hint: Label = $MountHint
@onready var player: Player = get_node("../Player") as Player
@onready var mini_map: Control = $MiniMap
@onready var full_map: Control = $FullMap

var map_open := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		map_open = not map_open
		full_map.visible = map_open
		mini_map.visible = not map_open
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		hint.text = "Esc libera el ratón"
	else:
		hint.text = "Clic para volver a controlar la cámara"

	if player.is_mounted():
		controls.text = "WASD / flechas · guiar   Mayús · galopar\nE · desmontar   M · mapa   1–4 · viaje rápido"
		mount_hint.text = "E · Desmontar de %s" % player.current_mount.horse_name
		mount_hint.visible = true
	else:
		controls.text = "WASD / flechas · caminar   Espacio · saltar\nClic izq. · cuchillo   Mayús · correr   E · montar   M · mapa   1–4 · viaje rápido"
		var nearby_horse := player.get_nearby_mount()
		mount_hint.visible = nearby_horse != null
		if nearby_horse != null:
			mount_hint.text = "E · Montar a %s" % nearby_horse.horse_name
