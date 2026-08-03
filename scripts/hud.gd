extends CanvasLayer

@onready var hint: Label = $Margin/Panel/Padding/Content/MouseHint
@onready var controls: Label = $Margin/Panel/Padding/Content/Controls
@onready var mount_hint: Label = $MountHint
@onready var player: Player = get_node("../Player") as Player


func _process(_delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		hint.text = "Esc libera el ratón"
	else:
		hint.text = "Clic para volver a controlar la cámara"

	if player.is_mounted():
		controls.text = "WASD / flechas · guiar   Mayús · galopar\nE · desmontar   Ratón · mirar"
		mount_hint.text = "E · Desmontar de %s" % player.current_mount.horse_name
		mount_hint.visible = true
	else:
		controls.text = "WASD / flechas · caminar   Espacio · saltar\nClic izq. · espada   Mayús · correr   E · montar"
		var nearby_horse := player.get_nearby_mount()
		mount_hint.visible = nearby_horse != null
		if nearby_horse != null:
			mount_hint.text = "E · Montar a %s" % nearby_horse.horse_name
