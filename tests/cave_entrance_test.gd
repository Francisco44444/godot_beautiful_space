extends SceneTree

## Comprueba la envolvente real: ni cielo por los laterales ni suelo como techo.
func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	for nombre in ["InventoryManager","ExplorationManager"]:
		root.get_node(nombre).set("autosave_enabled",false)
	root.get_node("SaveGameManager").set_process(false)
	var mundo: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	for fotograma in 12: await process_frame
	paused = false
	var terreno := mundo.get_node("Terrain3D") as Terrain3D
	var jugador := mundo.get_node("Player") as Node3D
	jugador.set_physics_process(false)
	var grutas := get_nodes_in_group("explorable_cave")
	if grutas.size()!=4: fallar("Faltan grutas en la comprobación de sus bocas."); return
	var muestras := 0
	var camara := Camera3D.new()
	mundo.add_child(camara)
	camara.current = true
	for gruta in grutas:
		gruta.set_process(false)
		gruta.collision_layer = 1
		jugador.global_position = gruta.to_global(Vector3(0,0,10))
		camara.global_position = jugador.global_position+Vector3.UP*4
		if "--break-cave-envelope" in OS.get_cmdline_user_args():
			gruta.get_node("VestibuloCollision").disabled = true
		for fotograma in 3: await physics_frame
		await process_frame
		if terreno.get_camera()!=camara: fallar("El LOD del terreno sigue una cámara que ya no está activa."); return
		var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
		var huecos := 0
		for x in range(-10,11):
			for z in range(-50,-13):
				var punto: Vector3 = gruta.to_global(Vector3(x,0,z))
				if not terreno.data.get_control_hole(punto): continue
				huecos += 1
				var rayo := PhysicsRayQueryParameters3D.create(punto+Vector3.UP*18,punto-Vector3.UP*30,1)
				var impacto := espacio.intersect_ray(rayo)
				var suelo := clampf((float(z)-18.0)*0.1875,-18.0,0.0)
				if impacto.is_empty() or float(impacto.position.y)-gruta.global_position.y<suelo+5.0:
					fallar("La boca de %s deja un hueco sin cubierta en (%d,%d)." % [gruta.name,x,z]); return
		if huecos<10: fallar("No se han muestreado los agujeros reales de %s." % gruta.name); return
		muestras += huecos
		# A la altura de los ojos, los dos laterales de la transición deben ser
		# piedra continua. Un raycast que toca sólo terreno al fondo no sirve.
		for z in [-18.0,-26.0,-34.0]:
			var altura: float = (float(z)-18.0)*0.1875+1.7
			for lado in [-1.0,1.0]:
				var inicio: Vector3 = gruta.to_global(Vector3(0,altura,z))
				var fin: Vector3 = gruta.to_global(Vector3(float(lado)*12,altura,z))
				var impacto := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(inicio,fin,1))
				if impacto.is_empty() or impacto.collider!=gruta:
					fallar("El intradós de %s está abierto por un lateral en z=%s." % [gruta.name,z]); return
	print("CAVE ENTRANCE TEST OK: cuatro portadas, %d muestras de cubierta y 24 cierres laterales de piedra." % muestras)
	quit()

func fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
