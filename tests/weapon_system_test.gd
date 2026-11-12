extends SceneTree

## Valida el sistema de armas reconstruido: agarre en la mano, ataque cargado
## que se suelta girando y flecha visible que se clava donde apunta la retícula.


const ANIM_HELD_POSE := "SwordSlash"


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	if scene == null:
		_fail("No se pudo cargar la escena principal.")
		return
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 8:
		await physics_frame
	var player := world.get_node("Player") as Player
	# El inventario es persistente: sin reponer flechas la prueba mediría un arco
	# que ni siquiera puede tensarse.
	var inventory := root.get_node_or_null("/root/InventoryManager")
	if inventory != null:
		inventory.call("add_item", "Arrow", 30, false)

	# --- 1. Clic corto con espada: tajo frontal, nunca giro ---
	if not player.equip_item(1):
		_fail("No se pudo equipar la espada.")
		return

	# El arma tiene que bascular con el braceo, pero acompasada: sin corrección
	# daba bandazos de más de 30° por zancada y con corrección total quedaba
	# clavada al mundo, que es justo lo que se veía mal.
	var animator := player.get_node("Visual/ModelRoot").find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sway := await _measure_sway(player, animator)
	if sway < 4.0:
		_fail("El arma va rígida contra el mundo: no acompaña el braceo (%.1f°)." % sway)
		return
	if sway > 24.0:
		_fail("El arma da bandazos en cada paso (%.1f°)." % sway)
		return
	if not player.start_charge():
		_fail("El botón de ataque no inicia la postura de carga.")
		return
	if not player.is_charging_attack() or player.is_spin_ready():
		_fail("La carga debe empezar en cero y sin giro disponible.")
		return
	var aura := player.get_equipped_mesh().get_node_or_null("ChargeAura")
	if aura == null:
		_fail("El arma no muestra el aura de fuerza especial al cargar.")
		return
	player.call("_start_slash")
	if player.attack_phase != Player.AttackPhase.SLASH or not player.is_attacking:
		_fail("Un clic corto debe resolverse como tajo normal.")
		return
	# El tajo usa las animaciones de espada de la Universal Animation Library 2,
	# retargeteadas al rig de Quaternius, y encadena tres golpes distintos.
	if not player.has_library_animation("Sword_Regular_A"):
		_fail("No se cargó el tajo de espada de la biblioteca de animaciones.")
		return
	var first_slash := player.get_library_animation()
	if first_slash.is_empty():
		_fail("El tajo no está usando la animación de la biblioteca.")
		return

	var front := BreakableProp.new()
	var back := BreakableProp.new()
	var forward := -player.visual.global_basis.z.normalized()
	for target in [front, back]:
		target.collision_layer = 5
		target.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 1.1, 1.1)
		shape.shape = box
		shape.position.y = 0.55
		target.add_child(shape)
		world.add_child(target)
	front.global_position = player.global_position + forward * 1.3
	back.global_position = player.global_position - forward * 1.9
	await physics_frame
	for _frame in 60:
		await physics_frame
	if front.health != 1:
		_fail("El tajo frontal no dañó exactamente una vez al objetivo de delante (salud %d)." % front.health)
		return
	if back.health != 2 or back.broken:
		_fail("El tajo frontal alcanzó a un objetivo que estaba a la espalda.")
		return

	# --- 2. Carga completa: se suelta girando y barre los 360° ---
	front.health = 4
	back.health = 4
	var start_yaw := player.visual.rotation.y
	if not player.start_charge():
		_fail("No se pudo volver a cargar tras el tajo.")
		return
	player.set("_charge_time", player.charge_full_time * 1.2)
	player.set("_charge_strength", 1.0)
	if not player.is_spin_ready():
		_fail("La carga llena no habilita el ataque giratorio.")
		return
	# La tormenta atenúa la luz a través del ciclo día/noche en vez de escribir
	# el sol directamente: hacerlo a pelo dejaba el efecto borrado al fotograma
	# siguiente y el giro salía a plena luz.
	var sun := world.get_node("Sun") as DirectionalLight3D
	var storm := player.get("_charge_storm") as ChargeStorm
	if storm == null:
		_fail("La carga no levanta la tormenta de la fuerza especial.")
		return
	player.call("_update_attack", 0.016)
	await process_frame
	await process_frame
	if storm.get_dimming() > 0.6:
		_fail("La tormenta no atenúa la luz del mundo (%.2f)." % storm.get_dimming())
		return
	var stormy_sun := sun.light_energy
	var vortex := storm.get_node_or_null("WindVortex") as GPUParticles3D
	if vortex == null or not vortex.emitting:
		_fail("La carga no levanta el torbellino de viento alrededor del héroe.")
		return
	# Avanzar fotogramas con la carga llena y sin botón pulsado ya suelta el
	# giro por sí solo, que es justo el comportamiento esperado en juego.
	if player.attack_phase != Player.AttackPhase.SPIN and not player.start_spin_attack():
		_fail("Soltar con la carga llena no lanzó el ataque giratorio.")
		return
	# El rayo y el viento tienen que seguir vivos durante el giro, que es el
	# gesto que el jugador está mirando.
	var bolts := 0
	for child in storm.get_children():
		if child.name.begins_with("LightningBolt"):
			bolts += 1
	if bolts == 0:
		_fail("El giro no descarga ningún rayo sobre el filo.")
		return
	player.call("_update_attack", 0.016)
	await process_frame
	await process_frame
	if storm.get_dimming() > 0.75:
		_fail("La tormenta se apaga en cuanto empieza el giro (%.2f)." % storm.get_dimming())
		return
	if not vortex.emitting:
		_fail("El torbellino de viento se apaga al empezar el giro.")
		return
	if sun.light_energy > stormy_sun * 1.6:
		_fail("El ciclo día/noche está pisando el oscurecimiento de la tormenta.")
		return
	if player.attack_phase != Player.AttackPhase.SPIN:
		_fail("El ataque giratorio no llegó a activarse.")
		return
	if player.visual.get_node_or_null("WeaponChargeEffect/SpinShockwave") == null:
		_fail("El giro no emite el anillo de choque de la fuerza especial.")
		return
	# La fuerza especial tiene que tumbar la hierba de todo el ruedo.
	var vegetation := world.get_node_or_null("VegetationScatter")
	if vegetation == null:
		_fail("No se encontró la vegetación para comprobar la onda de hierba.")
		return
	if float(vegetation.get("_grass_blast_radius")) < player.spin_reach:
		_fail("La onda de hierba no cubre el alcance del giro.")
		return
	if (vegetation.get("_grass_blast_center") as Vector3).distance_to(player.global_position) > 0.5:
		_fail("La onda de hierba no se centra en el héroe.")
		return
	# La vegetación empuja sus uniformes en su propio `_process`, que corre
	# después del de esta prueba: hacen falta dos fotogramas.
	await process_frame
	await process_frame
	var grass_materials := vegetation.get("_grass_wind_materials") as Array
	if grass_materials.is_empty():
		_fail("La pradera no expone materiales de hierba con onda de choque.")
		return
	var flattened := float((grass_materials[0] as ShaderMaterial).get_shader_parameter("shockwave_strength"))
	if flattened < 0.5:
		_fail("El shader de hierba no recibió la fuerza de la onda (%.2f)." % flattened)
		return
	if animator.current_animation == ANIM_HELD_POSE:
		_fail("La carga congela la animación completa en vez de mover las piernas.")
		return
	var max_turn := 0.0
	while player.attack_phase == Player.AttackPhase.SPIN:
		max_turn = maxf(max_turn, absf(player.visual.rotation.y - start_yaw))
		await physics_frame
	if max_turn < TAU * 0.95:
		_fail("El ataque giratorio no completó una vuelta entera (%.2f rad)." % max_turn)
		return
	if absf(angle_difference(player.visual.rotation.y, start_yaw)) > 0.08:
		_fail("El héroe no termina el giro mirando adonde empezó.")
		return
	if front.health >= 4 or back.health >= 4:
		_fail("El giro no alcanzó a la vez a los objetivos de delante (%d) y de detrás (%d)." % [front.health, back.health])
		return
	if front.health > 2 or back.health > 2:
		_fail("El giro cargado debe repartir más de un impacto por objetivo.")
		return
	# Al terminar, el mundo recupera su luz: una tormenta interrumpida no puede
	# dejar el escenario a oscuras.
	for _frame in 40:
		await physics_frame
		await process_frame
	if storm.get_dimming() < 0.99:
		_fail("La tormenta no devuelve la luz al terminar el ataque (%.2f)." % storm.get_dimming())
		return
	front.queue_free()
	back.queue_free()

	# --- 3. Arco: un clic corto dispara y la flecha se clava ---
	for _frame in 40:
		await physics_frame
	if not player.equip_item(3):
		_fail("No se pudo equipar el arco.")
		return
	await process_frame
	# La cámara decide la puntería, así que se fija casi horizontal: con la vista
	# hacia el suelo la flecha se clava a dos metros y la medición de vuelo no
	# significa nada.
	var camera_rig := world.get_node_or_null("CameraRig")
	if camera_rig != null:
		camera_rig.set("pitch", deg_to_rad(2.0))
	for _frame in 4:
		await physics_frame
		await process_frame
	var arrows_before := player.get_arrow_count()
	player.call("_begin_bow_draw")
	# La orientación se comprueba tensando: es la pose con la que se dispara. El
	# arco sube desde su ladeo de reposo con una interpolación suave, así que hay
	# que dejarla converger.
	# Se espera a que la orientación converja en vez de fijar un número de
	# fotogramas: el arco sube desde su ladeo de reposo con interpolación suave y
	# un recuento fijo dejaba la prueba al borde del umbral.
	var bow := player.get_equipped_mesh()
	var upright := 0.0
	for _frame in 60:
		await process_frame
		upright = bow.global_basis.orthonormalized().y.dot(Vector3.UP)
		if upright >= 0.9:
			break
	if upright < 0.9:
		_fail("El arco no llega a poner las palas verticales al apuntar (%.3f)." % upright)
		return
	var bow_basis := bow.global_basis.orthonormalized()
	if (-bow_basis.x).dot(player.get_aim_direction()) < 0.6:
		_fail("La cuerda del arco no mira al arquero.")
		return
	if absf(bow_basis.z.dot(player.get_aim_direction())) < 0.25:
		_fail("El arco queda de canto a la cámara: se vería como una astilla.")
		return
	if player.get_node_or_null("Visual/ModelRoot/NockedArrow") == null:
		_fail("Al tensar no aparece la flecha encajada en la cuerda.")
		return
	# Un clic de ratón normal dura menos de 120 ms: debe disparar igualmente.
	player.set("_bow_draw_time", 0.05)
	player.set("_bow_draw_strength", 0.05)
	if not player.call("_release_bow_arrow"):
		_fail("Un clic corto con el arco no dispara ninguna flecha.")
		return
	if player.get_arrow_count() != arrows_before - 1:
		_fail("El disparo no consumió exactamente una flecha del inventario.")
		return
	await physics_frame
	var arrow := _find_arrow(world)
	if arrow == null:
		_fail("La flecha disparada no existe en la escena.")
		return
	var aim_point := player.get_aim_point()
	var straight := (aim_point - player.get_arrow_launch_origin()).normalized()
	# La flecha NO sale en línea recta hacia la retícula: sale por encima, con el
	# ángulo que compensa la caída. Disparando recto acababa muy por debajo del
	# punto marcado —151 m por debajo a 179 m de distancia, medido— y el punto de
	# mira no indicaba nada.
	var launched := arrow.velocity.normalized()
	if launched.dot(straight) > 0.9999:
		_fail("El disparo no compensa la gravedad: sale recto a la retícula.")
		return
	if launched.y <= straight.y:
		_fail("El disparo debería salir elevado respecto a la línea de la retícula.")
		return
	# Y la parábola tiene que pasar por donde apunta: la trayectoria simulada y
	# la línea de tiro comparten el mismo plano vertical.
	var flat_launch := Vector2(launched.x, launched.z).normalized()
	var flat_straight := Vector2(straight.x, straight.z).normalized()
	if flat_launch.dot(flat_straight) < 0.999:
		_fail("El disparo se desvía en horizontal respecto a la retícula.")
		return
	if (-arrow.global_basis.z.normalized()).dot(arrow.velocity.normalized()) < 0.99:
		_fail("La flecha vuela de culo: la punta no mira en la dirección del disparo.")
		return
	# La potencia tiene que escalar con el tensado: un toque sale flojo y un
	# tensado completo, muy por encima.
	var weak_speed := arrow.velocity.length()
	player.call("_begin_bow_draw")
	player.set("_bow_draw_time", player.bow_full_draw_time * 1.2)
	player.set("_bow_draw_strength", 1.0)
	if not player.call("_release_bow_arrow"):
		_fail("El arco no dispara con el tensado completo.")
		return
	await physics_frame
	var strong := _find_arrow(world, arrow)
	if strong == null:
		_fail("El segundo disparo no creó su propio proyectil.")
		return
	if strong.velocity.length() < weak_speed * 1.4:
		_fail("Tensar el arco a fondo no aumenta la potencia (%.1f frente a %.1f m/s)." % [
			strong.velocity.length(), weak_speed])
		return
	strong.queue_free()
	await physics_frame

	# Contra un blanco dentro de alcance, la flecha se clava donde marca la
	# retícula. La predicción que dibuja el HUD usa esta misma cuenta.
	var target_wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(16.0, 12.0, 1.0)
	wall_shape.shape = wall_box
	target_wall.add_child(wall_shape)
	target_wall.collision_layer = 1
	world.add_child(target_wall)
	var aim_camera := world.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D
	target_wall.global_position = (
		aim_camera.global_position - aim_camera.global_basis.z.normalized() * 34.0
	)
	for _frame in 20:
		await physics_frame
	player.call("_begin_bow_draw")
	player.set("_bow_draw_time", player.bow_full_draw_time * 1.2)
	player.set("_bow_draw_strength", 1.0)
	await physics_frame
	var marked := player.get_aim_point()
	var prediction: Dictionary = player.get_predicted_impact()
	if not bool(prediction.get("reaches_aim", false)):
		_fail("La predicción de impacto no alcanza un blanco a 34 m con el arco a tope.")
		return
	if not player.call("_release_bow_arrow"):
		_fail("El arco no dispara contra el blanco de prueba.")
		return
	await physics_frame
	var aimed := _find_arrow(world, arrow)
	if aimed == null:
		_fail("El disparo contra el blanco no creó proyectil.")
		return
	var landing := aimed.global_position
	for _frame in 200:
		await physics_frame
		if not is_instance_valid(aimed):
			break
		landing = aimed.global_position
		if aimed.is_stuck():
			break
	var aim_error := marked.distance_to(landing)
	if aim_error > 1.5:
		_fail("La flecha se clava a %.2f m del punto marcado por la retícula." % aim_error)
		return
	if is_instance_valid(aimed):
		aimed.queue_free()
	target_wall.queue_free()
	for _frame in 12:
		await physics_frame

	var flight_start := arrow.global_position
	# La estela es una cinta continua construida en coordenadas del mundo: es lo
	# que dibuja la dirección del disparo en vez de un rosario de motas.
	var ribbon := arrow.get_node_or_null("TrailRibbon") as MeshInstance3D
	if ribbon == null or not ribbon.top_level:
		_fail("La flecha no lleva la cinta de estela en coordenadas del mundo.")
		return
	for _frame in 6:
		await physics_frame
		await process_frame
	var ribbon_mesh := ribbon.mesh as ImmediateMesh
	if ribbon_mesh == null or ribbon_mesh.get_surface_count() == 0:
		_fail("La estela de la flecha no dibuja ninguna geometría en vuelo.")
		return
	if ribbon_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() < 8:
		_fail("La estela es demasiado corta para leer la dirección del disparo.")
		return
	var flown := 0.0
	# El disparo flojo va al punto de la retícula con la parábola que compensa
	# la gravedad, y si el blanco queda fuera de alcance sale con los 45° de
	# máximo recorrido: ese arco tarda más de cuatro segundos en caer, así que
	# hay que esperarle todo su tiempo de vida y no 240 fotogramas justos.
	for _frame in 540:
		if not is_instance_valid(arrow) or arrow.is_stuck():
			break
		flown = maxf(flown, flight_start.distance_to(arrow.global_position))
		await physics_frame
	if not is_instance_valid(arrow) or not arrow.is_stuck():
		_fail("La flecha no llegó a clavarse en ningún sitio tras %.2f m de vuelo." % flown)
		return
	if flown < 2.0:
		_fail("La flecha se clavó antes de recorrer una distancia visible (%.2f m)." % flown)
		return
	var stuck_position := arrow.global_position
	for _frame in 90:
		await physics_frame
	if not is_instance_valid(arrow):
		_fail("La flecha clavada desaparece demasiado rápido para verla.")
		return
	if arrow.global_position.distance_to(stuck_position) > 0.001:
		_fail("La flecha clavada no se queda quieta en el punto de impacto.")
		return

	# --- 7. Postura de recarga: agachado y con el arma en alto al costado ---
	# El fotograma congelado de `SwordSlash` que se usaba antes dejaba una pose
	# rara y sin escorzo. Ahora la da `Sword_Heavy_Combo` de la biblioteca, que
	# es el único gesto que sube el arma por encima de la cabeza y hunde el
	# tronco a la vez. Y lo hace SOLO en el tren superior, así que el héroe
	# sigue dando pasos mientras carga.
	player.equip_item(1)
	for _frame in 45:
		await physics_frame
	var probe_skeleton := _hero_skeleton(player)
	var head_probe := _attach_bone(probe_skeleton, "Head")
	var hand_probe := _attach_bone(probe_skeleton, "Fist.R")
	var thigh_probe := _attach_bone(probe_skeleton, "UpperLeg.R")
	for _frame in 6:
		await physics_frame
	var rest_head := _bone_local(player, head_probe)
	var rest_hand := _bone_local(player, hand_probe)

	# Un clic corto NO debe levantar ni una hoja: las pulsaciones repetidas
	# dejaban una nube de restos flotando sin motivo.
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	for _frame in 4:
		await physics_frame
	if storm.is_debris_active():
		_fail("Un clic corto ya levanta restos en el aire: falta el umbral de mantenido.")
		return
	# Y tampoco puede levantar viento ni apagar el cielo: la tormenta es de la
	# fuerza especial, no de cualquier tajo. Antes la intensidad entraba con una
	# curva acelerada y el primer fotograma de un clic ya movía la hierba.
	if float(vegetation.call("get_grass_storm_bend")) > 0.001:
		_fail("Un clic corto levanta viento (%.3f m)." % float(vegetation.call("get_grass_storm_bend")))
		return
	if storm.get_dimming() < 0.999:
		_fail("Un clic corto oscurece el cielo (%.2f)." % storm.get_dimming())
		return
	while player.is_attacking or player.attack_phase != Player.AttackPhase.NONE:
		await physics_frame

	Input.action_press("move_forward")
	for _frame in 30:
		await physics_frame
	Input.action_press("attack")
	if not await _esperar_carga(player):
		_fail("Mantener el botón no carga tras el tajo inicial.")
		return
	var thigh_travel_min := 1000.0
	var thigh_travel_max := -1000.0
	var raised := 0.0
	for _frame in 100:
		await physics_frame
		var thigh_height := _bone_local(player, thigh_probe).y
		thigh_travel_min = minf(thigh_travel_min, thigh_height)
		thigh_travel_max = maxf(thigh_travel_max, thigh_height)
		raised = maxf(raised, _bone_local(player, hand_probe).y - rest_hand.y)
	if raised < 0.25:
		_fail("La postura de recarga no levanta la mano: solo sube %.2f m sobre el reposo." % raised)
		return
	if thigh_travel_max - thigh_travel_min < 0.05:
		_fail("Los pies se paran al cargar: el muslo solo recorre %.3f m." % (thigh_travel_max - thigh_travel_min))
		return

	# --- 7b. La postura de recarga: espada horizontal al frente ---
	# La referencia es Link cargando el mandoble: filo horizontal apuntando al
	# frente, codo pegado a las costillas y tronco inclinado. No sale de ningún
	# fotograma de la biblioteca —se probaron varios y todos dejaban el brazo
	# doblado en L o cruzando por detrás del hombro, donde atravesaba el escudo
	# colgado—, así que se construye: se adelanta el antebrazo y la muñeca lleva
	# el filo a la horizontal.
	var shoulder_probe := _attach_bone(probe_skeleton, "UpperArm.R")
	var elbow_probe := _attach_bone(probe_skeleton, "LowerArm.R")
	for _frame in 4:
		await physics_frame
	var blade_mesh := player.get_equipped_mesh()
	var blade_bounds := blade_mesh.mesh.get_aabb()
	var blade_grip := blade_mesh.to_global(
		Vector3(blade_bounds.position.x + blade_bounds.size.x * 0.5, blade_bounds.position.y, 0.0)
	)
	var blade_axis := (
		player.visual.global_basis.orthonormalized().inverse()
		* (player.get_blade_tip() - blade_grip)
	).normalized()
	var blade_pitch := absf(rad_to_deg(asin(clampf(blade_axis.y, -1.0, 1.0))))
	if blade_pitch > 25.0:
		_fail("El filo de la recarga no queda horizontal: %.1f° sobre la horizontal." % blade_pitch)
		return
	# Al COSTADO DERECHO, no al frente: es donde tiene que estar para que el
	# remolino la barra en círculo sin mover el brazo.
	var blade_side := absf(
		rad_to_deg(Vector2(blade_axis.x, blade_axis.z).angle_to(Vector2(1.0, 0.0)))
	)
	if blade_side > 30.0:
		_fail("El filo de la recarga no apunta al costado derecho: %.1f° desviado." % blade_side)
		return
	var tip_local := player.visual.global_basis.orthonormalized().inverse() * (
		player.get_blade_tip() - player.global_position
	)
	if tip_local.x < 1.5:
		_fail("La punta no se abre al costado: queda en x=%+.2f." % tip_local.x)
		return
	# La mano deja el porte de reposo y se abre del cuerpo. Lo importante aquí es
	# la apertura lateral, no la altura: la postura es horizontal, y el braceo de
	# la animación de andar hace oscilar unos centímetros la altura de la muñeca.
	var charge_wrist := _bone_local(player, hand_probe)
	if charge_wrist.y - rest_hand.y < 0.15:
		_fail("La mano de la recarga no deja el porte de reposo (%.3f m)." % (charge_wrist.y - rest_hand.y))
		return
	if charge_wrist.x <= _bone_local(player, elbow_probe).x:
		_fail("El brazo no se abre: la muñeca no queda al costado del codo.")
		return
	# Brazo extendido y en línea con la hoja, pero con el codo algo flexionado:
	# recto del todo se leía como una tabla, y muy doblado no alarga la silueta.
	var charge_shoulder := _bone_local(player, shoulder_probe)
	var charge_elbow := _bone_local(player, elbow_probe)
	var elbow_degrees := 180.0 - rad_to_deg(
		(charge_elbow - charge_shoulder).normalized().angle_to(
			(charge_wrist - charge_elbow).normalized()
		)
	)
	if elbow_degrees < 145.0:
		_fail("El brazo de la recarga queda demasiado doblado: codo a %.1f°." % elbow_degrees)
		return
	if elbow_degrees > 175.0:
		_fail("El codo de la recarga queda recto como una tabla (%.1f°)." % elbow_degrees)
		return
	# El brazo libre acompaña: puño arriba y codo muy flexionado, haciendo fuerza.
	var free_shoulder := _attach_bone(probe_skeleton, "UpperArm.L")
	var free_elbow := _attach_bone(probe_skeleton, "LowerArm.L")
	var free_fist := _attach_bone(probe_skeleton, "Fist.L")
	for _frame in 3:
		await physics_frame
	var free_angle := 180.0 - rad_to_deg(
		(_bone_local(player, free_elbow) - _bone_local(player, free_shoulder)).normalized().angle_to(
			(_bone_local(player, free_fist) - _bone_local(player, free_elbow)).normalized()
		)
	)
	if free_angle > 110.0:
		_fail("El brazo libre no se flexiona al cargar: codo a %.1f°." % free_angle)
		return
	var free_fist_local := _bone_local(player, free_fist)
	var free_elbow_local := _bone_local(player, free_elbow)
	if free_fist_local.y < free_elbow_local.y + 0.10:
		_fail("El brazo libre no levanta el puño por encima del codo.")
		return
	# Y se separa del cuerpo: cruzándolo del todo el antebrazo acababa metido en
	# la barriga.
	if free_fist_local.z > -0.35:
		_fail("El antebrazo libre queda pegado al torso (puño en z=%+.2f)." % free_fist_local.z)
		return
	if free_fist_local.z > free_elbow_local.z - 0.15:
		_fail("El antebrazo libre no se adelanta al codo.")
		return
	# El húmero se despega de la axila: el codo queda claramente por fuera del
	# eje del hombro, en ala, y no pegado a las costillas.
	var free_shoulder_local := _bone_local(player, free_shoulder)
	if free_shoulder_local.x - free_elbow_local.x < 0.18:
		_fail("El brazo libre no se separa de la axila: el codo abre %.3f m." % (
			free_shoulder_local.x - free_elbow_local.x))
		return
	# Su húmero cuelga paralelo al eje del tronco inclinado. Se compara en el
	# plano sagital: la apertura lateral —el codo hacia fuera— es deliberada y no
	# cuenta como desvío.
	var humerus := (
		_bone_local(player, free_elbow) - _bone_local(player, free_shoulder)
	).normalized()
	var lean_radians := deg_to_rad(player.charge_lean_degrees)
	var torso_axis := Vector3(0.0, -cos(lean_radians), sin(lean_radians))
	var sagittal := Vector2(humerus.y, humerus.z).normalized()
	var sagittal_torso := Vector2(torso_axis.y, torso_axis.z).normalized()
	var parallel_gap := absf(rad_to_deg(sagittal.angle_to(sagittal_torso)))
	if parallel_gap > 18.0:
		_fail("El húmero libre no cae paralelo al tronco: %.1f° de desvío." % parallel_gap)
		return
	# Y el tronco gira hacia el lado del arma: el hombro armado se retrasa
	# respecto al libre, que es como se recoge la fuerza.
	var twist_gap := _bone_local(player, shoulder_probe).z - _bone_local(player, free_shoulder).z
	if twist_gap < 0.05:
		_fail("El tronco no gira al cargar: los hombros quedan a la par (%.3f m)." % twist_gap)
		return
	var arm_line := (charge_wrist - charge_shoulder).normalized()
	var arm_blade_gap := rad_to_deg(arm_line.angle_to(blade_axis))
	if arm_blade_gap > 15.0:
		_fail("La hoja no prolonga el brazo: forma %.1f° con él." % arm_blade_gap)
		return
	# El tronco se inclina, y sin llevarse las piernas.
	var leaned_forward := rest_head.z - _bone_local(player, head_probe).z
	if leaned_forward < 0.20:
		_fail("El héroe no se inclina al cargar: %.3f m." % leaned_forward)
		return
	# Nada de atravesar la cabeza ni el escudo colgado.
	var head_centre := head_probe.global_position + Vector3.UP * 0.10
	var forearm_clearance := _segment_distance(
		elbow_probe.global_position, hand_probe.global_position, head_centre
	)
	if forearm_clearance < 0.26:
		_fail("El antebrazo de la recarga roza la cabeza (%.3f m)." % forearm_clearance)
		return
	var arm_clearance := _segment_distance(
		shoulder_probe.global_position, elbow_probe.global_position, head_centre
	)
	if arm_clearance < 0.26:
		_fail("El brazo de la recarga atraviesa la cabeza: pasa a %.3f m." % arm_clearance)
		return
	var back_shield: MeshInstance3D = null
	for node in player.find_children("EquippedShield*", "MeshInstance3D", true, false):
		back_shield = node as MeshInstance3D
	if back_shield == null:
		_fail("No se encontró el escudo colgado para comprobar la postura de recarga.")
		return
	var blade_gap := _box_clearance(back_shield, hand_probe.global_position, player.get_blade_tip())
	if blade_gap < 0.05:
		_fail("La espada de la recarga atraviesa el escudo de la espalda (%.3f m)." % blade_gap)
		return
	var forearm_gap := _box_clearance(
		back_shield, elbow_probe.global_position, hand_probe.global_position
	)
	if forearm_gap < 0.05:
		_fail("El antebrazo atraviesa el escudo de la espalda (%.3f m)." % forearm_gap)
		return

	# --- 8. El vendaval mueve de verdad la hierba y los árboles ---
	# `gust_strength` solo actuaba en la cresta del ciclo natural de rachas, que
	# llega una vez por minuto: durante una carga de dos segundos la vegetación
	# no se movía. La tormenta tiene ahora su propio término de doblado.
	var grass_bend := float(vegetation.call("get_grass_storm_bend"))
	var tree_bend := float(vegetation.call("get_tree_storm_bend"))
	if grass_bend < 0.30:
		_fail("El vendaval no dobla la hierba: solo %.3f m de barrido." % grass_bend)
		return
	if tree_bend < 0.50:
		_fail("El vendaval no mueve las copas: solo %.3f m de barrido." % tree_bend)
		return
	if not storm.is_debris_active():
		_fail("Con la carga mantenida no aparecen restos en el aire.")
		return
	if storm.get_debris_biome().is_empty():
		_fail("El remolino no eligió paleta de restos para el bioma del héroe.")
		return
	var charge_blade_axis := blade_axis
	Input.action_release("attack")
	Input.action_release("move_forward")
	await physics_frame
	if player.attack_phase != Player.AttackPhase.SPIN:
		_fail("La carga llena no se soltó como ataque giratorio.")
		return
	# La descarga es un salto: el héroe se despega del suelo, gira en el aire y
	# aterriza al cerrar la vuelta.
	var ground_height := player.global_position.y
	var jump_peak := 0.0
	var left_ground := false
	# El remolino conserva la MISMA postura. Antes tomaba prestado un fotograma
	# de la biblioteca al soltar y el brazo se iba hacia arriba, justo en el
	# gesto que el jugador está mirando.
	for _frame in 10:
		await physics_frame
		var spin_grip := blade_mesh.to_global(
			Vector3(
				blade_bounds.position.x + blade_bounds.size.x * 0.5,
				blade_bounds.position.y,
				0.0
			)
		)
		var spin_axis := (
			player.visual.global_basis.orthonormalized().inverse()
			* (player.get_blade_tip() - spin_grip)
		).normalized()
		var drift := rad_to_deg(spin_axis.angle_to(charge_blade_axis))
		if drift > 12.0:
			_fail("El arma cambia de postura al soltar: se desvía %.1f° del gesto de carga." % drift)
			return
		jump_peak = maxf(jump_peak, player.global_position.y - ground_height)
		if not player.is_on_floor():
			left_ground = true
	if not left_ground or jump_peak < 0.20:
		_fail("La descarga no salta: se eleva %.3f m." % jump_peak)
		return
	# El viento se mide mientras el giro sigue en marcha: esperar antes a que el
	# héroe aterrice dejaba pasar el remolino entero y la tormenta ya calmada.
	var spin_grass := 0.0
	var landing_frames := -1
	for frame_index in 12:
		await physics_frame
		spin_grass = maxf(spin_grass, float(vegetation.call("get_grass_storm_bend")))
		if landing_frames < 0 and player.is_on_floor():
			landing_frames = frame_index
	if spin_grass < 0.25:
		_fail("El viento se apaga en cuanto empieza el giro (%.3f m)." % spin_grass)
		return
	var extra_frames := 0
	while not player.is_on_floor() and extra_frames < 200:
		extra_frames += 1
		await physics_frame
	if extra_frames >= 200:
		_fail("El héroe no aterriza tras el salto de la descarga.")
		return
	for _frame in 100:
		await physics_frame
	if float(vegetation.call("get_grass_storm_bend")) > 0.02:
		_fail("El vendaval no se calma al terminar el ataque.")
		return

	# --- 8b. Durante la carga caen rayos sobre el filo ---
	# No se exige que haya uno en pantalla en la mayoría de los fotogramas: el
	# destello escaso y limpio es deliberado, y encadenarlos quedaba feo. Basta
	# con que la carga sostenida descargue varios.
	while player.is_attacking or player.attack_phase != Player.AttackPhase.NONE:
		await physics_frame
	for _frame in 25:
		await physics_frame
	Input.action_press("attack")
	if not await _esperar_carga(player):
		_fail("No comienza la carga para comprobar los rayos.")
		return
	var struck := 0
	var seen: Dictionary = {}
	for _frame in 110:
		await physics_frame
		for child in storm.get_children():
			if String(child.name).begins_with("LightningBolt"):
				var key := child.get_instance_id()
				if not seen.has(key):
					seen[key] = true
					struck += 1
	Input.action_release("attack")
	for _frame in 100:
		await physics_frame
	if struck < 2:
		_fail("Una carga sostenida solo descargó %d rayos." % struck)
		return

	# --- 9. Restos propios de cada bioma ---
	# Las hojas solo tienen sentido donde hay hojas: en la nieve gira brisa
	# blanca y en el desierto polvo.
	var biome_spots := {
		"valley": Vector3(0.0, 0.0, 190.0),
		"snow": Vector3(150.0, 0.0, -3400.0),
		"desert": Vector3(2400.0, 0.0, 2050.0),
		"dark_forest": Vector3(4380.0, 0.0, -1320.0),
	}
	for biome_name in biome_spots:
		var reported := String(vegetation.call("biome_at", biome_spots[biome_name]))
		if reported != biome_name:
			_fail("El bioma de %s se lee como «%s»." % [biome_name, reported])
			return
		if not ChargeStorm.DEBRIS_PRESETS.has(biome_name):
			_fail("No hay paleta de restos para el bioma %s." % biome_name)
			return

	# --- 10. Escudo por delante de la mano y héroe encogido tras él ---
	Input.action_press("block")
	for _frame in 40:
		await physics_frame
	if not player.is_guarding:
		_fail("El botón derecho no levanta el escudo.")
		return
	var shield_mesh: MeshInstance3D = null
	for node in player.find_children("EquippedShield*", "MeshInstance3D", true, false):
		shield_mesh = node as MeshInstance3D
	if shield_mesh == null:
		_fail("La guardia no trae el escudo a la mano.")
		return
	var shield_bounds := shield_mesh.mesh.get_aabb()
	var hand_in_shield := shield_mesh.to_local(_attach_bone(probe_skeleton, "Fist.L").global_position)
	if shield_bounds.has_point(hand_in_shield):
		_fail("La mano sigue atravesando la tabla del escudo.")
		return
	if hand_in_shield.z > shield_bounds.position.z:
		_fail("El escudo no queda por delante de la mano (mano en z=%.3f, tabla desde %.3f)." % [
			hand_in_shield.z, shield_bounds.position.z])
		return
	var guard_head := _bone_local(player, head_probe)
	var leaned := rest_head.z - guard_head.z
	if leaned < 0.12:
		_fail("El héroe no se encoge tras el escudo: solo se adelanta %.3f m." % leaned)
		return
	Input.action_release("block")
	for _frame in 25:
		await physics_frame

	# --- 10b. Envainar mueve el brazo, no teletransporta la espada ---
	while player.is_attacking or player.attack_phase != Player.AttackPhase.NONE:
		await physics_frame
	if not player.equip_item(1):
		_fail("No se pudo reequipar la espada para comprobar el envainado.")
		return
	for _frame in 35:
		await physics_frame
	var rest_wrist := _bone_local(player, hand_probe)
	if not player.stow_weapon():
		_fail("No se pudo envainar el arma.")
		return
	var wrist_lift := 0.0
	var wrist_back := 0.0
	for _frame in 34:
		await physics_frame
		var wrist := _bone_local(player, hand_probe)
		wrist_lift = maxf(wrist_lift, wrist.y - rest_wrist.y)
		wrist_back = maxf(wrist_back, rest_wrist.z - wrist.z)
	if wrist_lift < 0.20:
		_fail("Al envainar la mano no sube hacia el hombro (%.3f m)." % wrist_lift)
		return
	if wrist_back < 0.30:
		_fail("Al envainar la mano no se echa hacia la espalda (%.3f m)." % wrist_back)
		return
	if not player.draw_weapon():
		_fail("No se pudo desenvainar tras el envainado.")
		return
	for _frame in 40:
		await physics_frame

	# --- 11. Toda la biblioteca disponible sobre cualquier personaje ---
	# Los ocho avatares del multijugador comparten rig —23 huesos, mismos
	# nombres y misma pose de reposo—, así que el sistema entero tiene que
	# funcionar igual con el que elija cada jugador.
	for index in Player.CHARACTER_PATHS.size():
		player.apply_identity("Prueba", index)
		for _frame in 30:
			await physics_frame
		var avatar := Player.CHARACTER_PATHS[index].get_file()
		var reloaded := _hero_skeleton(player)
		if reloaded == null:
			_fail("El personaje %s no cargó esqueleto." % avatar)
			return
		for bone_name in ["Fist.R", "Fist.L", "Abdomen", "Torso", "Head"]:
			if reloaded.find_bone(bone_name) < 0:
				_fail("Al personaje %s le falta el hueso %s." % [avatar, bone_name])
				return
		var absent: Array[String] = []
		for gesture_name in Player.GESTURES:
			if not player.has_library_animation(gesture_name):
				absent.append(gesture_name)
		if not absent.is_empty():
			_fail("Con %s no resuelven estos gestos: %s" % [avatar, absent])
			return
		if not player.equip_item(1):
			_fail("Con %s no se pudo equipar la espada." % avatar)
			return
		for _frame in 30:
			await physics_frame
		var grip := player.get_equipped_mesh()
		if grip == null or grip.get_parent() == null:
			_fail("Con %s la espada no queda agarrada." % avatar)
			return
		if not player.start_charge():
			_fail("Con %s no arranca la postura de recarga." % avatar)
			return
		player.call("_cancel_melee_charge")
		for _frame in 4:
			await physics_frame

	world.queue_free()
	for _frame in 8:
		await process_frame
	print("WEAPON SYSTEM TEST OK: recarga con brazo y filo en línea al costado, brazo libre en tensión, tronco girado y todo quieto durante el giro, vendaval sobre hierba (%.2f m) y copas (%.2f m), restos por bioma, escudo por delante de la mano y %d gestos sobre los %d personajes." % [
		grass_bend, tree_bend, Player.GESTURES.size(), Player.CHARACTER_PATHS.size()])
	quit(0)


func _box_clearance(target: MeshInstance3D, from: Vector3, to: Vector3) -> float:
	## Holgura mínima entre un segmento y la caja de una malla, en su propio
	## sistema local. Negativa significa que el segmento entra en ella.
	var bounds := target.mesh.get_aabb()
	var centre := bounds.get_center()
	var half := bounds.size * 0.5
	var best := 1000.0
	for step in 41:
		var local := target.to_local(from.lerp(to, float(step) / 40.0))
		var delta := Vector3(
			absf(local.x - centre.x) - half.x,
			absf(local.y - centre.y) - half.y,
			absf(local.z - centre.z) - half.z
		)
		var outside := Vector3(maxf(delta.x, 0.0), maxf(delta.y, 0.0), maxf(delta.z, 0.0))
		var distance := outside.length()
		if distance <= 0.0001:
			distance = maxf(maxf(delta.x, delta.y), delta.z)
		best = minf(best, distance)
	return best


func _segment_distance(from: Vector3, to: Vector3, point: Vector3) -> float:
	## Distancia mínima de un punto al segmento: es la medida que dice si un
	## hueso pasa por dentro de la cabeza y no solo cerca de ella.
	var span := to - from
	if span.length_squared() < 0.000001:
		return from.distance_to(point)
	var ratio := clampf((point - from).dot(span) / span.length_squared(), 0.0, 1.0)
	return (from + span * ratio).distance_to(point)


func _hero_skeleton(player: Player) -> Skeleton3D:
	for node in player.get_node("Visual/ModelRoot").find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _attach_bone(skeleton: Skeleton3D, bone_name: String) -> BoneAttachment3D:
	## `get_bone_global_pose` devuelve la pose ANTES de los modificadores, así
	## que no sirve para comprobar lo que se ve. Un `BoneAttachment3D` sí refleja
	## el resultado final.
	var existing := skeleton.get_node_or_null("Probe_" + bone_name) as BoneAttachment3D
	if existing != null:
		return existing
	var attachment := BoneAttachment3D.new()
	attachment.name = "Probe_" + bone_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	return attachment


func _bone_local(player: Player, attachment: BoneAttachment3D) -> Vector3:
	## Posición del hueso en el sistema del héroe: así la medida no depende de
	## hacia dónde mire ni de dónde esté en el mapa.
	return player.visual.global_basis.orthonormalized().inverse() * (
		attachment.global_position - player.global_position
	)


func _measure_sway(player: Player, animator: AnimationPlayer) -> float:
	## Ángulo máximo que el eje del arma se aparta de su media a lo largo de un
	## ciclo completo de paseo.
	# La corrección de muñeca entra con rampa: medir mientras sube contaminaría
	# la lectura con el estado transitorio.
	animator.play("Walk", 0.0)
	for _frame in 24:
		await process_frame
	var axes: Array[Vector3] = []
	var length := animator.get_animation("Walk").length
	for step in 10:
		animator.play("Walk", 0.0)
		animator.seek(length * float(step) / 10.0, true)
		await process_frame
		await process_frame
		var mesh := player.get_equipped_mesh() as MeshInstance3D
		axes.append(player.visual.global_basis.orthonormalized().inverse() * mesh.global_basis.orthonormalized().y)
	var mean := Vector3.ZERO
	for axis in axes:
		mean += axis
	mean = mean.normalized()
	var worst := 0.0
	for axis in axes:
		worst = maxf(worst, rad_to_deg(axis.angle_to(mean)))
	return worst


func _find_arrow(node: Node, ignore: AdventureArrow = null) -> AdventureArrow:
	# Se filtra por tipo y no por nombre exacto: Godot renombra el segundo
	# proyectil para no repetir nombre entre hermanos.
	for child in node.get_children():
		if child is AdventureArrow and child.name != "NockedArrow" and child != ignore:
			return child as AdventureArrow
		var found := _find_arrow(child, ignore)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _esperar_carga(player: Player) -> bool:
	var limite := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < limite:
		if player.is_charging_attack(): return true
		await physics_frame
	return false
