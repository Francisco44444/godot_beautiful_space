extends CanvasLayer

@onready var hint: Label = $Margin/Panel/Padding/Content/MouseHint


func _process(_delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		hint.text = "Esc libera el ratón"
	else:
		hint.text = "Clic para volver a controlar la cámara"

