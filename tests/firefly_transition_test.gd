extends SceneTree

var mundo: Node3D
var luces: Node3D
var jugador: Player

func _init() -> void: call_deferred("_comprobar")

func _comprobar() -> void:
	for nombre in ["InventoryManager", "ExplorationManager"]: root.get_node(nombre).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	mundo = load("res://scenes/world.tscn").instantiate()
	root.add_child(mundo)
	root.get_node("SaveGameManager").bind_world(null)
	for i in 12: await process_frame
	paused = false
	mundo.sun_cycle_enabled = false
	jugador = mundo.get_node("Player")
	jugador.set_physics_process(false)
	luces = mundo.get_node("RPGStoryRuntime/ForestWonders")
	luces.set_process(false)
	jugador.global_position = luces.grounded(Vector2(-2180,1650),0.12)
	if not luces._near_tree(Vector2(jugador.global_position.x,jugador.global_position.z)): _fallar("El control no está en el bosque real."); return
	mundo.daylight_factor = 0.26
	luces._update_ambient()
	if not luces._fireflies.visible: _fallar("Las luciérnagas siguen teniendo un corte al anochecer."); return
	var intermedio: Variant = luces._fireflies.material_override.get_shader_parameter("aparicion")
	if typeof(intermedio) != TYPE_FLOAT or float(intermedio)<=0 or float(intermedio)>=1: _fallar("Las luciérnagas carecen de niveles intermedios de luz."); return
	var anterior := -1.0
	for dia in PackedFloat32Array([1.0,0.5,0.32,0.30,0.28,0.26,0.25,0.22,0.18,0.12,0.06,0.0]):
		mundo.daylight_factor = dia
		luces._update_ambient()
		var nivel: Variant = luces._fireflies.material_override.get_shader_parameter("aparicion")
		if typeof(nivel) != TYPE_FLOAT or float(nivel) < anterior or float(nivel)<0 or float(nivel)>1:
			_fallar("El brillo no sigue una transición nocturna continua y acotada."); return
		if dia >= 0.32 and (luces._fireflies.visible or float(nivel)!=0): _fallar("Las luciérnagas se dibujan a plena luz."); return
		if dia <= 0.06 and (not luces._fireflies.visible or float(nivel)!=1): _fallar("La noche pierde el brillo completo de las luciérnagas."); return
		anterior = float(nivel)
	for dia in PackedFloat32Array([0.0,0.06,0.12,0.18,0.22,0.25,0.26,0.28,0.30,0.32,0.5,1.0]):
		mundo.daylight_factor = dia
		luces._update_ambient()
		var nivel := float(luces._fireflies.material_override.get_shader_parameter("aparicion"))
		if nivel > anterior: _fallar("Las luces aumentan durante el amanecer."); return
		anterior = nivel
	mundo.daylight_factor = 0.0
	jugador.global_position = luces.grounded(Vector2(4380,-1320),0.12)
	for i in 24: luces._update_ambient()
	if not luces._fireflies.visible or luces._fireflies.multimesh.instance_count != 112: _fallar("El Bosque Tenebroso no conserva su enjambre nocturno."); return
	var tono: Color = luces._fireflies.material_override.get_shader_parameter("color")
	if not (tono.r > tono.g and tono.g > tono.b): _fallar("El Bosque Tenebroso no usa la luz cálida de su ambiente."); return
	jugador.global_position.y += 30
	luces._update_ambient()
	if luces._fireflies.visible: _fallar("Las luces ambientales se plantan sobre una torre o fuera del suelo."); return
	var bosque_original: Dictionary = luces._tree_cells
	luces._tree_cells = bosque_original.duplicate(true)
	for caso in [{"bioma":"snow","punto":Vector2(520,-3000)},{"bioma":"desert","punto":Vector2(2750,1700)}]:
		var punto: Vector2 = caso.punto
		jugador.global_position = luces.grounded(punto,0.12)
		if mundo.get_node("VegetationScatter").biome_at(jugador.global_position) != caso.bioma: _fallar("El control no está en el bioma previsto."); return
		# Un tronco en la búsqueda hace elegible el lugar: no basta con pasar
		# porque la nieve o la arena no tuvieran árboles junto a la muestra.
		luces._tree_cells[Vector2i(floori(punto.x/32),floori(punto.y/32))] = [punto]
		luces._update_ambient()
		if luces._fireflies.visible: _fallar("Las luciérnagas aparecen en un bioma sin su ambiente."); return
	luces._tree_cells = bosque_original
	jugador.global_position = luces.grounded(luces.CLEARING,0.12)
	luces.guide_stage = 0
	luces._update_ambient()
	if luces._clearing_swarm.visible: _fallar("El claro revela su celebración antes de descubrirlo."); return
	luces.guide_stage = 2
	mundo.daylight_factor = 0.26
	luces._update_ambient()
	var nivel_claro := float(luces._clearing_swarm.material_override.get_shader_parameter("aparicion"))
	if not luces._clearing_swarm.visible or nivel_claro<=0 or nivel_claro>=1: _fallar("Las luces del claro no acompañan el crepúsculo."); return
	if luces._fireflies.global_position.distance_to(luces.grounded(luces.CLEARING))>0.001: _fallar("La celebración no queda anclada al claro."); return
	var plantas_claro: int = luces.trace_replants
	for i in 100: luces._update_ambient()
	if luces.trace_replants != plantas_claro: _fallar("La celebración quieta se recoloca repetidamente."); return
	mundo.daylight_factor = 0.0
	jugador.global_position = luces.grounded(Vector2(-2180,1650),0.12)
	luces._update_ambient()
	if luces._fireflies.global_position.distance_to(luces.grounded(Vector2(-2180,1650)))>0.001: _fallar("Las luces se quedan abandonadas en el claro."); return
	var plantas: int = luces.trace_replants
	for i in 100: luces._update_ambient()
	if luces.trace_replants != plantas: _fallar("El enjambre quieto se recoloca repetidamente."); return
	mundo.daylight_factor = 1.0
	luces._update_ambient()
	if luces._fireflies.visible or luces._clearing_swarm.visible: _fallar("Quedan luces de bosque a pleno día."); return
	if "--render-check" in OS.get_cmdline_user_args() and not await _comprobar_render(): return
	print("FIREFLY TRANSITION TEST OK: crepúsculo continuo, noche completa, dos bosques, suelo, celebración y reposo.")
	quit(0)

func _comprobar_render() -> bool:
	var visor := SubViewport.new()
	visor.size = Vector2i(320,180)
	visor.own_world_3d = true
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(visor)
	var escena := Node3D.new()
	visor.add_child(escena)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color.BLACK
	escena.add_child(ambiente)
	var camara := Camera3D.new()
	escena.add_child(camara)
	camara.position = Vector3(0,0,6)
	camara.look_at(Vector3.ZERO)
	camara.current = true
	var muestra: MultiMeshInstance3D = luces._make_swarm(1,0.0,3.0,luces.LUCES_VALLE)
	muestra.reparent(escena,false)
	muestra.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
	muestra.multimesh.set_instance_custom_data(0,Color(0,5,0,3))
	var shader := Shader.new()
	var expresion := RegEx.new()
	expresion.compile("\\bTIME\\b")
	shader.code = expresion.sub(muestra.material_override.shader.code,"0.4",true)
	muestra.material_override.shader = shader
	var energias: Array[float] = []
	for nivel in PackedFloat32Array([0.0,0.4,1.0,0.4]):
		muestra.material_override.set_shader_parameter("aparicion",nivel)
		for i in 3: await process_frame
		RenderingServer.force_draw(false,0.0)
		var imagen := visor.get_texture().get_image()
		if imagen.is_empty(): _fallar("El control gráfico no ha dibujado la luciérnaga."); return false
		var energia := 0.0
		for y in range(0,180,4):
			for x in range(0,320,4):
				var color := imagen.get_pixel(x,y)
				energia += color.r+color.g+color.b
		energias.append(energia)
	if energias[2]<=1 or energias[0]>energias[2]*0.001 or energias[1]>=energias[2]*0.9 or energias[1]<=energias[2]*0.05 or not is_equal_approx(energias[1],energias[3]):
		_fallar("El shader no aplica realmente la aparición gradual de las luciérnagas."); return false
	print("FIREFLY RENDER PASS ",energias)
	visor.queue_free()
	await process_frame
	return true

func _fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
