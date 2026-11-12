extends SceneTree

## El remate conserva el tronco sobre la pelvis y las piernas siguen andando.
var maximo := 0.0

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("InventoryManager").reset_inventory_for_tests(false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	var jugador := mundo.get_node("Player") as Player
	jugador.set_physics_process(false)
	for heroe in Player.CHARACTER_PATHS.size():
		jugador.apply_identity("Remate", heroe)
		jugador.equip_item(1)
		await create_timer(0.6).timeout
		var biblioteca := jugador.get("_library") as LibraryAnimation
		var esqueleto := jugador.skeleton
		var torso := esqueleto.find_bone("Torso")
		var pelvis := esqueleto.find_bone("Hips")
		var muslo := esqueleto.find_bone("UpperLeg.R")
		var medidas := {}
		# Fuera de esta señal Godot ya ha restaurado los huesos previos al
		# modificador; medirlos allí daría siempre el reposo y ocultaría el fallo.
		biblioteca.modification_processed.connect(func():
			var referencias: Dictionary = biblioteca.get("_target_ref")
			if not referencias.has("Torso"): return
			var giro_torso := esqueleto.get_bone_global_pose(torso).basis.orthonormalized() * (referencias.Torso as Basis).inverse()
			var giro_pelvis := esqueleto.get_bone_global_pose(pelvis).basis.orthonormalized() * (referencias.Hips as Basis).inverse()
			medidas["giro"] = rad_to_deg((giro_pelvis.inverse() * giro_torso).get_rotation_quaternion().get_angle())
			medidas["muslo"] = esqueleto.get_bone_pose_rotation(muslo))
		jugador.attack_phase = Player.AttackPhase.SLASH
		jugador.is_attacking = true
		biblioteca.upper_body_only = true
		biblioteca.bone_filter = PackedStringArray()
		biblioteca.influence = 1.0
		for tajo in ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]:
			var primera_pierna := Quaternion.IDENTITY
			var recorrido := 0.0
			for muestra in 21:
				jugador.animation_player.play(Player.ANIM_WALK, 0.0)
				jugador.animation_player.seek(float(muestra) / 20.0 * 0.7, true)
				jugador.animation_player.speed_scale = 0.0
				biblioteca.hold_library(tajo, float(muestra) / 20.0 * biblioteca.get_length(tajo))
				for i in 3: await process_frame
				if not medidas.has("giro"): _fallar("El remate no procesa la pose modificada."); return
				var giro: float = medidas.giro
				maximo = maxf(maximo, giro)
				if giro > 90.0: _fallar("El tajo %s retuerce el tronco sobre la pelvis: héroe %d, muestra %d, %.2f grados." % [tajo, heroe, muestra, giro]); return
				if muestra == 0: primera_pierna = medidas.muslo
				recorrido = maxf(recorrido, primera_pierna.angle_to(medidas.muslo))
			if recorrido < 0.15: _fallar("El remate detiene las piernas del héroe al caminar."); return
		jugador.attack_phase = Player.AttackPhase.NONE
		jugador.is_attacking = false
	print("SLASH RETARGET TEST OK: 504 poses modificadas en ocho héroes, giro máximo %.2f grados y piernas libres." % maximo)
	quit(0)

func _fallar(texto: String) -> void:
	push_error(texto)
	quit(1)
