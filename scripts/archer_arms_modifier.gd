class_name ArcherArmsModifier
extends SkeletonModifier3D

## Poses de brazo resueltas a mano, dos huesos por brazo, con mezcla propia para
## cada lado: la sirven tanto el tensado del arco (los dos brazos) como la
## guardia con escudo (solo el izquierdo).
##
## Godot 4.7 dejó obsoleto `SkeletonIK3D`, que en este rig solo desplazaba los
## `BoneAttachment3D`: el arco se alzaba delante del pecho mientras los brazos
## seguían colgando. `TwoBoneIK3D` tampoco resuelve la cadena Shoulder →
## UpperArm → LowerArm → Fist de Quaternius. Al escribir las poses en la fase
## de modificación del esqueleto —la única que la animación no vuelve a pisar—
## el brazo del arco se estira hacia el objetivo y la piel se deforma con él.

## Objetivos en el espacio del esqueleto: la mano del arco y la de la cuerda.
var left_target := Vector3.ZERO
var right_target := Vector3.ZERO
## Mezcla independiente por brazo. La guardia con escudo solo necesita el
## izquierdo, así que el derecho tiene que poder seguir en su animación.
var left_influence := 0.0
var right_influence := 0.0
## Hacia dónde cae cada codo. El del arco sale hacia fuera y abajo; el de la
## cuerda se abre hacia atrás, como en la postura real de tiro.
var left_pole := Vector3(0.92, -0.72, -0.20)
var right_pole := Vector3(-1.0, 0.10, -0.45)
## Torsión del tronco alrededor de la columna, en radianes. Es la que abre los
## hombros como hace un arquero de verdad: sin ella la línea de tiro pasa por el
## eje del cuerpo y uno de los dos brazos tiene que cruzar el torso por dentro.
var torso_twist := 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_twist_torso(skeleton)
	if left_influence > 0.001:
		_solve_arm(skeleton, "UpperArm.L", "LowerArm.L", "Fist.L", left_target, left_pole, left_influence)
	if right_influence > 0.001:
		_solve_arm(skeleton, "UpperArm.R", "LowerArm.R", "Fist.R", right_target, right_pole, right_influence)


func _twist_torso(skeleton: Skeleton3D) -> void:
	if absf(torso_twist) < 0.0001:
		return
	var bone := skeleton.find_bone("Torso")
	if bone < 0:
		return
	# El eje Y del hueso recorre la columna, así que girar sobre él abre los
	# hombros sin inclinar al héroe.
	var twist := Quaternion(Vector3.UP, torso_twist * clampf(right_influence, 0.0, 1.0))
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * twist)


func _solve_arm(
	skeleton: Skeleton3D,
	root_name: String,
	middle_name: String,
	end_name: String,
	target: Vector3,
	pole: Vector3,
	weight: float
) -> void:
	var root_bone := skeleton.find_bone(root_name)
	var middle_bone := skeleton.find_bone(middle_name)
	var end_bone := skeleton.find_bone(end_name)
	if root_bone < 0 or middle_bone < 0 or end_bone < 0:
		return
	var root_pose := skeleton.get_bone_global_pose(root_bone)
	var middle_pose := skeleton.get_bone_global_pose(middle_bone)
	var end_pose := skeleton.get_bone_global_pose(end_bone)
	var shoulder := root_pose.origin
	var elbow := middle_pose.origin
	var hand := end_pose.origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(hand)
	if upper_length <= 0.0001 or lower_length <= 0.0001:
		return

	# La influencia se aplica al objetivo, no a cada rotación: la rampa de
	# entrada y salida sale suave con una sola interpolación.
	var goal := hand.lerp(target, clampf(weight, 0.0, 1.0))
	var to_goal := goal - shoulder
	var reach := clampf(to_goal.length(), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	if to_goal.length_squared() <= 0.000001:
		return
	var direction := to_goal.normalized()

	# Codo por el teorema del coseno; el plano de flexión lo fija el polo.
	var cos_shoulder := clampf(
		(upper_length * upper_length + reach * reach - lower_length * lower_length) / (2.0 * upper_length * reach),
		-1.0,
		1.0
	)
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.UP)
		if bend.length_squared() < 0.0001:
			bend = direction.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var shoulder_angle := acos(cos_shoulder)
	var new_elbow := shoulder + (direction * cos(shoulder_angle) + bend * sin(shoulder_angle)) * upper_length
	var new_hand := shoulder + direction * reach

	# Primer hueso: gira para apuntar al codo calculado.
	var rotated_root := _aim_bone(root_pose, elbow, new_elbow)
	skeleton.set_bone_global_pose(root_bone, rotated_root)
	# El segundo hueso ya se ha movido con su padre: se relee antes de apuntar
	# a la mano, o el giro se aplicaría dos veces.
	var updated_middle := skeleton.get_bone_global_pose(middle_bone)
	var updated_hand := skeleton.get_bone_global_pose(end_bone).origin
	skeleton.set_bone_global_pose(middle_bone, _aim_bone(updated_middle, updated_hand, new_hand))


func _aim_bone(pose: Transform3D, current_tip: Vector3, desired_tip: Vector3) -> Transform3D:
	var from := current_tip - pose.origin
	var to := desired_tip - pose.origin
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return pose
	var turn := Quaternion(from.normalized(), to.normalized())
	return Transform3D(Basis(turn) * pose.basis, pose.origin)
