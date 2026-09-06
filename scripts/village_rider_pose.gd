extends "res://scripts/archer_arms_modifier.gd"

## SitDown sienta los pies juntos dentro del caballo. La misma solución de dos
## huesos abre las rodillas y sitúa las botas a ambos lados del lomo.
func _process_modification() -> void:
	super._process_modification()
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_solve_arm(skeleton, "UpperLeg.L", "LowerLeg.L", "Foot.L", Vector3(0.72, 0.05, -0.08), Vector3(1.0, 0.0, 0.6), 1.0)
	_solve_arm(skeleton, "UpperLeg.R", "LowerLeg.R", "Foot.R", Vector3(-0.72, 0.05, -0.08), Vector3(-1.0, 0.0, 0.6), 1.0)
