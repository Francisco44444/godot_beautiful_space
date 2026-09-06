class_name WeaponArmModifier
extends SkeletonModifier3D

## Correcciones del brazo armado que la biblioteca de Quaternius no puede dar.
## Hace dos trabajos distintos sobre la misma cadena:
##
##  - `stabilize_weight` corrige únicamente la muñeca para que el eje largo del
##    arma tienda a la dirección de porte mientras hombro y codo bracean con
##    total libertad. Es lo que permite conservar la alegría del paseo sin que
##    la espada dé bandazos de horizontal a vertical en cada paso.
##
##  - `lean_rotations` aplica giros explícitos sobre huesos concretos. Los usan
##    la guardia —que necesita hundir la columna, porque `Idle_Shield` deja al
##    héroe completamente erguido— y la recarga, que además tiene que abrir el
##    brazo armado para que no atraviese la cabeza. Se hace con giros propios y
##    no con otra animación retargeteada: así hay números que ajustar y el
##    resultado se puede comprobar en metros.

## Eje largo del arma expresado en el sistema local del hueso de la mano.
var weapon_axis_local := Vector3.UP
## Dirección de porte, en coordenadas del mundo.
var desired_axis_world := Vector3.UP
var stabilize_weight := 0.0
var hand_bone := "Fist.R"
## Giros que se suman a la animación, en el sistema del esqueleto. Cada entrada
## es {"bone": String, "axis": Vector3, "degrees": float}.
var lean_rotations: Array[Dictionary] = []
var lean_weight := 0.0
## Cadenas de huesos que se orientan a mano. Cada entrada es
## {"chain": PackedStringArray, "direction": Vector3, "bend_degrees": float,
##  "bend_axis": Vector3}: el primer tramo apunta a `direction` y cada tramo
## siguiente gira `bend_degrees` más sobre `bend_axis`, lo que deja la
## articulación flexionada en vez de recta como una tabla.
##
## Las usa la recarga para posar los dos brazos. Buscar fotogramas en la
## biblioteca que dieran la postura no funcionó —los que suben el arma doblan el
## codo, y los de brazo recto la cruzan por detrás del hombro—, así que se
## construye y sale exacta.
var raise_chains: Array[Dictionary] = []
var raise_weight := 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	# La flexión va ANTES de alinear el arma: al revés, girar el húmero después
	# arrastraba la muñeca ya corregida y desviaba el filo tantos grados como
	# midiese la apertura —de 8° a 40° de la vertical, medido—.
	if lean_weight > 0.001 and not lean_rotations.is_empty():
		_apply_lean(skeleton)
	# El posado de los brazos va después de la flexión del tronco —que arrastra
	# los hombros— y antes de alinear el arma, que es la última palabra sobre la
	# muñeca.
	if raise_weight > 0.001:
		for spec in raise_chains:
			_raise_chain(skeleton, spec)
	if stabilize_weight > 0.001:
		_stabilize_weapon_axis(skeleton)


func _raise_chain(skeleton: Skeleton3D, spec: Dictionary) -> void:
	## Orienta la cadena hueso a hueso: cada tramo gira lo mínimo para quedar
	## alineado con su dirección, y la de cada tramo se desvía `bend_degrees` de
	## la anterior. Se recorre de la raíz a la punta y se vuelve a leer la
	## posición del hijo en cada paso, porque girar el padre lo ha movido.
	var chain: PackedStringArray = spec.get("chain", PackedStringArray())
	if chain.size() < 2:
		return
	var direction: Vector3 = spec.get("direction", Vector3.UP)
	if direction.length_squared() < 0.000001:
		return
	var target := (skeleton.global_basis.inverse() * direction).normalized()
	var bend := deg_to_rad(float(spec.get("bend_degrees", 0.0)))
	var bend_axis: Vector3 = spec.get("bend_axis", Vector3.RIGHT)
	if bend_axis.length_squared() > 0.000001 and not is_zero_approx(bend):
		bend_axis = (skeleton.global_basis.inverse() * bend_axis).normalized()
	else:
		bend = 0.0
	var weight := clampf(raise_weight, 0.0, 1.0)
	for index in chain.size() - 1:
		var bone := skeleton.find_bone(chain[index])
		var child := skeleton.find_bone(chain[index + 1])
		if bone < 0 or child < 0:
			continue
		var pose := skeleton.get_bone_global_pose(bone)
		var segment := skeleton.get_bone_global_pose(child).origin - pose.origin
		if segment.length_squared() < 0.000001:
			continue
		var link_target := target
		if not is_zero_approx(bend) and index > 0:
			link_target = target.rotated(bend_axis, bend * float(index)).normalized()
		var turn := Quaternion(segment.normalized(), link_target).normalized()
		var wanted := (Basis(turn) * pose.basis.orthonormalized()).orthonormalized()
		skeleton.set_bone_global_pose(
			bone,
			Transform3D(pose.basis.orthonormalized().slerp(wanted, weight), pose.origin)
		)


func _apply_lean(skeleton: Skeleton3D) -> void:
	## Se gira la pose GLOBAL del hueso: todo lo que cuelga de él acompaña el
	## movimiento —el abdomen arrastra torso, cuello, cabeza y brazos, y el
	## húmero arrastra codo y muñeca—, que es exactamente lo que hacen un
	## encogimiento y una apertura de brazo. Trabajar en global evita depender de
	## la orientación de reposo de cada hueso, que en este rig no es la misma en
	## todos.
	var weight := clampf(lean_weight, 0.0, 1.0)
	for entry in lean_rotations:
		var degrees := float(entry.get("degrees", 0.0))
		if is_zero_approx(degrees):
			continue
		var bone := skeleton.find_bone(String(entry.get("bone", "")))
		if bone < 0:
			continue
		var axis: Vector3 = entry.get("axis", Vector3.RIGHT)
		if axis.length_squared() < 0.000001:
			continue
		var turn := Quaternion(axis.normalized(), deg_to_rad(degrees) * weight)
		var pose := skeleton.get_bone_global_pose(bone)
		skeleton.set_bone_global_pose(
			bone, Transform3D(Basis(turn) * pose.basis.orthonormalized(), pose.origin)
		)


func _stabilize_weapon_axis(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone(hand_bone)
	if bone < 0:
		return
	var pose := skeleton.get_bone_global_pose(bone)
	var current := (pose.basis * weapon_axis_local)
	var desired := skeleton.global_basis.inverse() * desired_axis_world
	if current.length_squared() < 0.000001 or desired.length_squared() < 0.000001:
		return
	# Giro mínimo que lleva el eje del arma a la dirección de porte. Aplicarlo
	# solo en parte deja que la animación siga imprimiendo su vaivén.
	var turn := Quaternion(current.normalized(), desired.normalized())
	var corrected := Basis(turn) * pose.basis
	skeleton.set_bone_global_pose(
		bone,
		Transform3D(pose.basis.orthonormalized().slerp(corrected.orthonormalized(), clampf(stabilize_weight, 0.0, 1.0)), pose.origin)
	)
