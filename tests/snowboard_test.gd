extends SceneTree
func _init() -> void:call_deferred("_probar")
func exigir(valor: bool, texto: String) -> bool:
	if valor:return true
	push_error(texto);quit(1);return false
func _probar() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for n in ["InventoryManager","ExplorationManager"]:root.get_node(n).set("autosave_enabled",false)
	root.get_node("GameSettings").set_player_identity("PruebaNieve",0,false)
	var m = load("res://scenes/world.tscn").instantiate();root.add_child(m);current_scene = m
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12:await process_frame
	paused = false
	var d = m.get_node("RPGStoryRuntime").aventura_pacifica
	var c = d.descenso;var p = m.player
	for punto in m.get_node("VegetationScatter").tree_positions:
		if not exigir(not preload("res://scripts/ruta_nieve.gd").dentro_corredor(Vector2(punto.x,punto.z)),"Un tronco invade el corredor del descenso"):return
	if not exigir(not c.is_physics_processing() and not c.is_processing(),"El descenso trabaja por fotograma sin corredores"):return
	var rampa = c.get_node("RampaNieve_18")
	var punto: Vector3 = rampa.get_meta("centro");punto.y = m.terrain.data.get_height(punto)
	var rayo := PhysicsRayQueryParameters3D.create(punto+Vector3.UP*6,punto-Vector3.UP*3,1)
	var golpe: Dictionary = m.get_world_3d().direct_space_state.intersect_ray(rayo)
	if not exigir(not golpe.is_empty() and golpe.collider==rampa and golpe.position.y>punto.y+0.4,"El salto de nieve no tiene una rampa física por encima del terreno"):return
	var ranura_inicial: int = p.equipped_slot
	var angulo_inicial: float = p.floor_max_angle
	var inicial: float = p.model_root.rotation.y
	p.global_position = c.puertas[0];p.velocity = Vector3.ZERO
	for i in 25:await physics_frame
	if not exigir(c.interactuar("salida",p) and p.en_tabla_nieve,"No se monta la tabla en la salida"):return
	c._physics_process(3.1)
	if not exigir(p.visual.get_node_or_null("TablaDeNieve")!=null,"Falta la tabla visible"):return
	p.velocity = Vector3(0,0,38);c._process(1.0)
	if not exigir(c._efecto_velocidad.visible and float(c._material_velocidad.get_shader_parameter("intensidad"))>0.9,"No se activa el desenfoque lateral a velocidad alta"):return
	p.bloquear_entrada_interfaz(true);c._process(0.1)
	if not exigir(not c._efecto_velocidad.visible,"El desenfoque tapa la interfaz"):return
	p.bloquear_entrada_interfaz(false);p.velocity = Vector3.ZERO
	# Saltarse todas las puertas no puede dar ni marca ni premio.
	p.set_physics_process(false);p.global_position = c.puertas[-1]
	c._physics_process(0.15)
	if not exigir(c.records.is_empty(),"Teletransportarse a meta completa el descenso"):return
	var penalizacion: float = c.carreras["1"].penalizacion
	c._physics_process(0.15)
	if not exigir(is_equal_approx(penalizacion,5.0) and is_equal_approx(c.carreras["1"].penalizacion,5.0),"La recuperación suma varias penalizaciones por la misma caída"):return
	c._volver(c.puertas[0]);p.set_physics_process(true)
	Input.action_press("move_forward")
	for i in 60:await physics_frame
	var velocidad: float = c.movimiento.rapidez
	Input.action_release("move_forward");Input.action_press("move_back")
	for i in 40:await physics_frame
	if not exigir(c.movimiento.rapidez<velocidad,"La frenada no reduce la velocidad"):return
	Input.action_release("move_back");Input.action_press("move_forward")
	var inicio := Time.get_ticks_msec();var salto := false;var en_aire := false;var progreso := 0;var cuclillas := false;var inclinacion := false;var velocidad_agachado := 0.0;var ultimo_diagnostico := 0
	while c.records.is_empty() and Time.get_ticks_msec()-inicio<240000:
		if not c.carreras.has("1"):break
		var i: int = c.carreras["1"].puerta
		Input.action_release("sprint")
		if i in [3,4]:Input.action_press("sprint")
		if p.postura_nieve.x>0.8:cuclillas = true;velocidad_agachado = maxf(velocidad_agachado,c.movimiento.rapidez)
		if absf(p.postura_nieve.y)>0.2:inclinacion = true
		var t: Vector3 = c.puertas[mini(i,c.puertas.size()-1)]-p.global_position
		var deseado := atan2(-t.x,-t.z)
		var giro := angle_difference(c.movimiento.rumbo,deseado)
		var salida_curva: Vector3 = c.puertas[mini(i+1,c.puertas.size()-1)]-c.puertas[mini(i,c.puertas.size()-1)]
		var entrada_curva: Vector3 = c.puertas[mini(i,c.puertas.size()-1)]-c.puertas[maxi(i-1,0)]
		var cerrada: bool = entrada_curva.normalized().dot(salida_curva.normalized())<0.75
		var frenar: bool = absf(giro)>0.60 or (cerrada and t.length()<32 and c.movimiento.rapidez>17)
		Input.action_release("move_forward");Input.action_release("move_back")
		Input.action_press("move_back" if frenar else "move_forward")
		Input.action_release("sprint")
		if not frenar and absf(giro)<0.25:Input.action_press("sprint")
		Input.action_release("move_left");Input.action_release("move_right")
		if absf(giro)>0.035:Input.action_press("move_left" if giro>0 else "move_right")
		Input.action_release("jump")
		if i==18 and t.length()<16 and absf(giro)<0.10 and not salto:Input.action_press("jump");salto = true
		if c.movimiento.en_salto:en_aire = true
		if Time.get_ticks_msec()-ultimo_diagnostico>10000:
			ultimo_diagnostico = Time.get_ticks_msec();print("NIEVE PROGRESO puerta=",i," tiempo=",c.carreras["1"].tiempo," rapidez=",c.movimiento.rapidez)
		if i!=progreso:print("NIEVE PUERTA ",i," posicion=",p.global_position);progreso = i
		await physics_frame
	for accion in ["move_forward","move_back","move_left","move_right","jump","sprint"]:Input.action_release(accion)
	if not exigir(c.records.has("PruebaNieve"),"No se puede completar el descenso con movimiento y colisión reales"):return
	if not exigir(cuclillas and inclinacion and velocidad_agachado>30.5,"Agacharse o tallar no afecta a postura y velocidad física"):return
	if not exigir(float(c.records["PruebaNieve"])>=115 and float(c.records["PruebaNieve"])<210,"La duración real no corresponde al gran descenso de dos minutos"):return
	if not exigir(en_aire,"No se puede saltar con la tabla"):return
	if not exigir(not p.en_tabla_nieve and p.equipped_slot==ranura_inicial and is_equal_approx(p.floor_max_angle,angulo_inicial) and is_equal_approx(p.model_root.rotation.y,inicial),"La llegada no restaura al personaje a pie"):return
	if not exigir(not c.is_processing(),"La llegada deja el efecto de velocidad activo"):return
	while c.rivales.activa:c._physics_process(0.1)
	c._physics_process(0.1)
	if not exigir(not c.is_physics_processing(),"La carrera terminada deja actividad de fondo"):return
	var rastro = m.get_node_or_null("RastroTabla_%d" % p.get_instance_id())
	if not exigir(rastro!=null and rastro.muestras.size()>10 and rastro.muestras.size()<=192,"La tabla no deja una estela acotada en la nieve"):return
	var inventario := root.get_node("InventoryManager");var cristales: int = inventario.get_count("Crystal3")
	c._empezar(1,p);c._terminar(1,p,{"tiempo":30.0,"penalizacion":0.0})
	if not exigir(inventario.get_count("Crystal3")==cristales,"Repetir el descenso duplica la recompensa inicial"):return
	c._empezar(1,p);c._terminar(1,p,{"tiempo":29.0,"penalizacion":0.0,"secreto":true})
	if not exigir(inventario.get_count("Crystal3")==cristales+2,"El secreto no da su premio propio"):return
	c._empezar(1,p);c._terminar(1,p,{"tiempo":28.0,"penalizacion":0.0,"secreto":true})
	if not exigir(inventario.get_count("Crystal3")==cristales+2,"Repetir el secreto duplica su premio"):return
	var datos: Dictionary = JSON.parse_string(JSON.stringify(d.guardar()));d.cargar(datos)
	c._empezar(1,p);p.global_position = c.puertas[25]
	var estado: Dictionary = m.get_local_player_save_state();c.preparar_jugador_guardado(estado)
	if not exigir(c.movimiento!=null and p.global_position.distance_to(c.puertas[25])<0.01,"Guardar interrumpe la carrera actual"):return
	if not exigir(Vector3(estado.position[0],estado.position[1],estado.position[2]).distance_to(c.puertas[0])<0.01 and estado.equipped_slot==ranura_inicial,"El guardado conserva una caída o pierde el equipo anterior"):return
	var serializado: Dictionary = JSON.parse_string(JSON.stringify(d.guardar()))
	if not exigir(serializado.nieve.carreras["1"].anterior is Array,"El guardado de la carrera contiene vectores ilegibles"):return
	d.cargar(serializado);m.apply_local_player_save_state(estado)
	if not exigir(not p.en_tabla_nieve and p.global_position.distance_to(c.puertas[0])<0.01,"Cargar deja al jugador deslizándose fuera de la carrera"):return
	if not exigir(c.records.has("PruebaNieve") and c.secretos.has("PruebaNieve"),"El guardado pierde la marca"):return
	p.global_position = c.puertas[0];c.interactuar("salida",p)
	m.cambiar_modo_aventura(false)
	if not exigir(not p.en_tabla_nieve and p.tabla_nieve==null,"Cambiar de modo deja una tabla activa"):return
	print("SNOWBOARD OK: descenso físico completo, cuclillas, inclinación, velocidad, freno, salto, orden de puertas, premio único, guardado y sin coste inactivo.")
	quit(0)
