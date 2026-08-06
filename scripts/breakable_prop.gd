class_name BreakableProp
extends StaticBody3D

## Objetivo sencillo para combate cuerpo a cuerpo: aguanta dos golpes y se rompe.

@export var health := 2
var broken := false


func receive_melee_hit(_hit_position: Vector3) -> void:
	if broken:
		return
	health -= 1
	if health <= 0:
		break_apart()
	else:
		var tween := create_tween()
		tween.tween_property(self, "rotation:z", 0.09, 0.055)
		tween.tween_property(self, "rotation:z", -0.065, 0.065)
		tween.tween_property(self, "rotation:z", 0.0, 0.075)


func break_apart() -> void:
	broken = true
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.25, 0.12, 1.25), 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation:y", rotation.y + 0.65, 0.22)
	tween.chain().tween_interval(1.4)
	tween.chain().tween_callback(queue_free)
