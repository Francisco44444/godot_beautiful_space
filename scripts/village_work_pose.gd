extends "res://scripts/archer_arms_modifier.gd"

## Sólo trabajan brazos/manos: PickUp del pack recogía del SUELO, lo que
## atravesaba las mesas con la cabeza. Idle conserva pies y tronco erguidos.
var trade := 3
var phase := 0.0

func _process_modification() -> void:
	phase += get_process_delta_time()
	left_influence = 1.0
	right_influence = 1.0
	left_pole = Vector3(0.9, -0.5, -0.1)
	right_pole = Vector3(-0.9, -0.5, -0.1)
	left_target = Vector3(0.24, 1.04, 0.67)
	if trade == 3:
		var lift := pow((sin(phase * 4.6) + 1.0) * 0.5, 2.0)
		right_target = Vector3(-0.24, 1.04 + lift * 0.54, 0.64 - lift * 0.2)
	elif trade == 4:
		right_target = Vector3(-0.24, 1.1, 0.64 + sin(phase * 3.0) * 0.1)
	else:
		left_target.x += sin(phase * 1.8) * 0.12
		right_target = Vector3(-0.25 + sin(phase * 1.8 + PI) * 0.12, 1.1 + sin(phase * 2.5) * 0.08, 0.64)
	super._process_modification()
