extends Node3D

const CAVE = preload("res://scripts/hollow_cave.gd")
const MEMORY = preload("res://scripts/cave_memory.gd")
const START := Vector2(75,60)
const CLEARING := Vector2(-110,-60)
const COLORS := [Color(0.30,0.86,0.65),Color(0.36,0.65,1.0),Color(1.0,0.58,0.17),Color(0.74,0.36,1.0)]
const FRAGMENTS := [
	["El roble no guardaba oro: guardaba la voz de quienes descansaron bajo él.","La fundidora se llamaba Elia. Nadie escribió su apellido; todos conocían su risa.","Cuando rasparon el bronce, las raíces aprendieron el nombre para no olvidarlo."],
	["La astrónoma dejó una lente apuntando al lugar donde faltaba una estrella.","El cielo no se detuvo. Fue su hermano quien dejó de recordar cómo volver a casa.","Su nombre era Soren. La última cuenta del observatorio dice: todavía te espero."],
	["Aquí se guardaba agua para quien llegase sin nada, incluso para el enemigo.","La campana del oasis no anunciaba las horas: anunciaba que había sitio en la mesa.","Nadia fue la última en beber. Antes de partir dejó su vaso para el siguiente."],
	["El silencio no nació del odio, sino del miedo a escuchar una despedida.","Vaelor guardó todos los nombres menos el suyo. Por eso ninguna voz lo alcanza.","En el quinto hueco hay una marca reciente. El polvo de tus manos tiene el mismo color."]]
var player: Player
var terrain: Terrain3D
var world: Node3D
var flags: Dictionary = {}
var guide_stage := 0
var guide_index := 0
var route := PackedVector3Array()
var _guide: Node3D
var _gold_light: OmniLight3D
var _animator: AnimationPlayer
var _fireflies: MultiMeshInstance3D
var _swarm: MultiMeshInstance3D
var _clearing_swarm: MultiMeshInstance3D
var _farewell_time := 0.0
var _gold_materials: Array[ShaderMaterial] = []
var _last_center := Vector3.INF
var _tick := 0.0
var _tree_cells: Dictionary = {}
var trace_replants := 0
var trace_waypoints := 0
var trace_rewards := 0
var _was_night := false
var _running_warning := false

func _ready() -> void:
	world = get_parent().get_parent()
	player = world.get_node("Player")
	terrain = world.get_node("Terrain3D")
	var cache := load("res://generated/vegetation_layout_cache.res") as VegetationLayoutCache
	for i in range(0,cache.forest_records.size(),9):
		var p := Vector2(cache.forest_records[i],cache.forest_records[i+2])
		var cell := Vector2i(floori(p.x/32),floori(p.y/32))
		if not _tree_cells.has(cell): _tree_cells[cell] = []
		_tree_cells[cell].append(p)
	_fireflies = _make_swarm(112,32.0,0.30,Color(0.78,1.0,0.36))
	_fireflies.name = "NightFireflies"
	_swarm = _make_swarm(48,3.5,0.22,Color(1.0,0.79,0.32))
	_swarm.name = "GuidingLights"
	_swarm.visible = false
	_clearing_swarm = _make_swarm(256,18.0,0.24,Color(0.88,1.0,0.43))
	_clearing_swarm.name = "MemoryClearingLights"
	_clearing_swarm.global_position = grounded(CLEARING)
	_clearing_swarm.visible = false
	_clearing_swarm.material_override.set_shader_parameter("rise",3.0)
	_make_guide()
	var ribbon := MEMORY.new()
	ribbon.director = self
	ribbon.memory_id = "forest:start"
	ribbon.kind = "forest"
	ribbon.title = "Leer la cinta del guardabosques"
	ribbon.text = "Tavia ató esta cinta a una rama: «Cuando caiga la noche, sigue las luces con calma. El ciervo de ámbar te esperará si tú también sabes esperar.»"
	add_child(ribbon)
	ribbon.global_position = grounded(START + Vector2(3,0),1.1)
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12,1.8,0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85,0.52,0.15)
	mesh.material = mat
	marker.mesh = mesh
	ribbon.add_child(marker)
	var moonflower := MEMORY.new()
	moonflower.director = self
	moonflower.memory_id = "forest:flower"
	moonflower.kind = "flower"
	moonflower.title = "Recoger la flor de la memoria"
	moonflower.text = "Entre sus pétalos hay una campanilla de madera. Al tocarla recuerdas una voz que aún no has oído. Tavia tenía razón: el bosque conserva lo que el bronce perdió."
	add_child(moonflower)
	moonflower.global_position = grounded(CLEARING,1.1)
	var flower := MeshInstance3D.new()
	var gem := PrismMesh.new()
	gem.size = Vector3(0.5,0.9,0.5)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1,0.73,0.22)
	gold.emission_enabled = true
	gold.emission = Color(1,0.54,0.08)
	gold.emission_energy_multiplier = 1.5
	gem.material = gold
	flower.mesh = gem
	moonflower.add_child(flower)
	for i in 5:
		var petal := MeshInstance3D.new()
		var mesh_petal := SphereMesh.new()
		mesh_petal.radius = 0.28
		mesh_petal.height = 0.13
		mesh_petal.radial_segments = 6
		mesh_petal.rings = 3
		mesh_petal.material = gold
		petal.mesh = mesh_petal
		petal.position = Vector3(cos(i*TAU/5.0)*0.24,0.25,sin(i*TAU/5.0)*0.24)
		moonflower.add_child(petal)

func create_cave(original: Dictionary, index: int) -> Node:
	var spec := original.duplicate(true)
	spec["color"] = COLORS[index]
	spec["fragments"] = FRAGMENTS[index]
	spec["ending"] = ["Elia vuelve a tener un lugar en la memoria del valle.","Soren vuelve a figurar en el cielo del observatorio.","Nadia vuelve a tener un vaso junto a la fuente.","La piedra no te devuelve un nombre. Te devuelve una pregunta: ¿qué harás con él cuando lo encuentres?"][index]
	var cave := CAVE.new()
	cave.name = "Cave_"+String(spec.id)
	cave.terrain = terrain
	cave.director = self
	cave.spec = spec
	cave.position = grounded(spec.point)
	cave.rotation.y = float(spec.yaw)
	get_parent().add_child(cave)
	return cave

func finish_caves() -> void:
	var scatter := world.get_node("VegetationScatter")
	var texture := scatter.get_meta("grass_urban_mask") as ImageTexture
	var image := texture.get_image()
	var corridors: Array[Transform3D] = []
	for cave in get_tree().get_nodes_in_group("explorable_cave"):
		_enmascarar_acceso(scatter,image,cave)
		corridors.append(cave.global_transform)
	texture.update(image)
	scatter.reserve_story_corridors(corridors)
	# update_maps puede cambiar el RID del array de controles. La hierba debe
	# leer el mismo RID nuevo para que no flote encima del agujero de la boca.
	for material in scatter.get("_grass_wind_materials"):
		scatter._set_grass_terrain_shader_parameters(material)


func _enmascarar_acceso(scatter: Node, image: Image, cave: Node3D) -> void:
	# La máscara es 2D, pero el acceso tiene dos alturas. Recuperar únicamente
	# los píxeles sobre tierra por encima de la bóveda impide plantar dentro.
	var escala := float(image.get_width())/12000.0
	var minimo := Vector2(INF,INF)
	var maximo := Vector2(-INF,-INF)
	for esquina in [Vector2(-7,-50),Vector2(7,-50),Vector2(-7,-12),Vector2(7,-12)]:
		var mundo := cave.to_global(Vector3(esquina.x,0,esquina.y))
		var pixel := (Vector2(mundo.x,mundo.z)+Vector2.ONE*6000)*escala
		minimo = minimo.min(pixel)
		maximo = maximo.max(pixel)
	var conservar := {}
	for x in range(maxi(0,floori(minimo.x)),mini(image.get_width(),ceili(maximo.x))):
		for y in range(maxi(0,floori(minimo.y)),mini(image.get_height(),ceili(maximo.y))):
			var mundo := Vector3((x+0.5)/escala-6000,cave.global_position.y,(y+0.5)/escala-6000)
			var local := cave.to_local(mundo)
			if absf(local.x)>5 or local.z < -44 or local.z > -13: continue
			var cubierta := true
			for dx in [-1.5,0.0,1.5]:
				for dz in [-1.5,0.0,1.5]:
					var muestra := mundo+Vector3(dx,0,dz)
					var altura := terrain.data.get_height(muestra)-cave.global_position.y
					var suelo := clampf((cave.to_local(muestra).z-18)*0.1875,-18.0,0.0)
					if not is_finite(altura) or altura<suelo+8.5: cubierta = false
			if cubierta: conservar[Vector2i(x,y)] = image.get_pixel(x,y)
	scatter._paint_grass_mask_rect(image,cave.global_transform,Rect2(-5,-44,10,101))
	for pixel in conservar: image.set_pixelv(pixel,conservar[pixel])
	cave.set_meta("roof_grass_texels",conservar.size())


func grounded(point: Vector2, offset: float = 0.0) -> Vector3:
	var height := terrain.data.get_height(Vector3(point.x,0,point.y))
	return Vector3(point.x,(height if is_finite(height) else 0.0)+offset,point.y)

func _make_swarm(count: int, radius: float, size: float, color: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = count
	var random := RandomNumberGenerator.new()
	random.seed = 712 + count
	for i in count:
		var angle := random.randf()*TAU
		var r := sqrt(random.randf())*radius
		mm.set_instance_transform(i,Transform3D(Basis(),Vector3(cos(angle)*r,random.randf_range(1.3,4.5),sin(angle)*r)))
		mm.set_instance_custom_data(i,Color(random.randf()*TAU,random.randf_range(2.6,5.8),0.35,random.randf_range(size*0.7,size*1.4)))
	var view := MultiMeshInstance3D.new()
	view.multimesh = mm
	view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.custom_aabb = AABB(Vector3(-radius-3,-3,-radius-3),Vector3(radius*2+6,12,radius*2+6))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/forest_firefly.gdshader")
	material.set_shader_parameter("color",color)
	view.material_override = material
	add_child(view)
	return view

func _make_guide() -> void:
	_guide = load("res://assets/quaternius/ultimate_animated_animals/glTF/Stag.gltf").instantiate()
	_guide.name = "AmberStag"
	_guide.scale = Vector3.ONE*0.65
	add_child(_guide)
	_guide.global_position = grounded(START)
	for node in _guide.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(surface) as BaseMaterial3D
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/amber_stag.gdshader")
			if source != null and source.albedo_texture != null:
				mat.set_shader_parameter("coat_texture",source.albedo_texture)
				mat.set_shader_parameter("textured",true)
			node.set_surface_override_material(surface,mat)
			_gold_materials.append(mat)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gold_light = OmniLight3D.new()
	_gold_light.light_color = Color(1.0,0.76,0.32)
	_gold_light.light_energy = 2.2
	_gold_light.omni_range = 7.0
	_gold_light.shadow_enabled = false
	_gold_light.position = Vector3(1.8,3.0,0.4)
	_guide.add_child(_gold_light)
	_animator = _guide.find_child("AnimationPlayer",true,false)
	_guide.visible = false

func _play(name: String) -> void:
	for key in _animator.get_animation_list():
		if String(key).ends_with(name):
			if _animator.current_animation != key: _animator.play(key,0.2)
			return

func _build_route() -> void:
	# Una búsqueda pequeña, una sola vez. Los troncos son obstáculos: el guía
	# no atraviesa árboles ni obliga al jugador a saltar para seguirlo.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-100,-80,200,160)
	grid.cell_size = Vector2.ONE*2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for values in _tree_cells.values():
		for value in values:
			var tree: Vector2 = value
			if tree.x < -205 or tree.x > 205 or tree.y < -165 or tree.y > 165: continue
			var cell := Vector2i(roundi(tree.x/2),roundi(tree.y/2))
			for z in range(cell.y-2,cell.y+3):
				for x in range(cell.x-2,cell.x+3):
					var id := Vector2i(x,z)
					if grid.is_in_boundsv(id) and (Vector2(id)*2).distance_to(tree) < 3.0: grid.set_point_solid(id)
	var start := Vector2i(roundi(START.x/2),roundi(START.y/2))
	var finish := Vector2i(roundi(CLEARING.x/2),roundi(CLEARING.y/2))
	grid.set_point_solid(start,false)
	grid.set_point_solid(finish,false)
	route.clear()
	for at in grid.get_point_path(start,finish): route.append(grounded(at))
	guide_index = mini(guide_index,maxi(route.size()-1,0))

func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0:
		_tick = 0.3
		_update_ambient()
	var night: bool = world.daylight_factor < 0.25
	if _farewell_time > 0 and guide_stage == 2:
		_farewell_time = maxf(_farewell_time-delta,0.0)
		var progress := 1.0-_farewell_time/1.8
		_guide.visible = _farewell_time>0
		_guide.scale = Vector3.ONE*0.65*maxf(1.0-progress*progress,0.001)
		for material in _gold_materials: material.set_shader_parameter("departure",progress)
		_swarm.visible = _farewell_time>0
		return
	_guide.visible = night and guide_stage == 1 and player.global_position.distance_to(_guide.global_position)<160
	_swarm.visible = _guide.visible
	if not _guide.visible: return
	if route.is_empty(): _build_route()
	if route.is_empty(): return
	var distance := player.global_position.distance_to(_guide.global_position)
	# Caminar es una invitación; correr cerca lo detiene, nunca borra progreso.
	var calm := Vector2(player.velocity.x,player.velocity.z).length() < 6.0
	if not calm and distance < 22 and not _running_warning:
		player.action_feedback.emit("El ciervo espera: camina despacio para que vuelva a confiar.")
	_running_warning = not calm and distance < 22
	if distance < 22 and calm and guide_index < route.size():
		var next: Vector3 = route[guide_index]
		var movement := next-_guide.global_position
		if movement.length()<0.35:
			guide_index += 1
			trace_waypoints += 1
		else:
			_guide.global_position = _guide.global_position.move_toward(next,delta*2.6)
			_guide.rotation.y = lerp_angle(_guide.rotation.y,atan2(movement.x,movement.z),1-exp(-delta*7))
			_play("Walk")
	else: _play("Idle")
	_swarm.global_position = _guide.global_position
	if guide_index >= route.size():
		guide_stage = 2
		_farewell_time = 1.8
		get_parent()._refresh_hud_bar()
		player.action_feedback.emit("El ciervo se deshace en luz. Una flor dorada despierta en el claro. E para recogerla.")

func _update_ambient() -> void:
	var night: bool = world.daylight_factor < 0.25
	var p := player.global_position
	var biome: String = world.get_node("VegetationScatter").biome_at(p)
	var forest := _near_tree(Vector2(p.x,p.z))
	_fireflies.visible = night and forest and biome == "valley" and absf(p.y-grounded(Vector2(p.x,p.z)).y)<8.0 and not "--without-fireflies" in OS.get_cmdline_user_args()
	if _fireflies.visible and (not is_finite(_last_center.x) or p.distance_to(_last_center)>12):
		_last_center = p
		_fireflies.global_position = Vector3(p.x,grounded(Vector2(p.x,p.z)).y,p.z)
		trace_replants += 1
	var celebration := night and guide_stage >= 2 and p.distance_to(grounded(CLEARING))<55
	_clearing_swarm.visible = celebration and not "--without-fireflies" in OS.get_cmdline_user_args()
	if celebration:
		_fireflies.visible = not "--without-fireflies" in OS.get_cmdline_user_args()
		_fireflies.global_position = grounded(CLEARING)
	if night != _was_night: get_parent()._refresh_hud_bar()
	_was_night = night

func _near_tree(point: Vector2) -> bool:
	var cell := Vector2i(floori(point.x/32),floori(point.y/32))
	for z in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			for tree in _tree_cells.get(Vector2i(x,z),[]):
				if point.distance_squared_to(tree)<45*45: return true
	return false

func interact_memory(memory: Node3D, actor: Node) -> bool:
	if actor == null or actor.global_position.distance_to(memory.global_position)>5.0: return false
	var text: String = memory.text
	var id: String = memory.memory_id
	if memory.kind == "forest":
		if guide_stage == 0:
			guide_stage = 1
			_build_route()
			_guide.global_position = route[guide_index] if not route.is_empty() else grounded(START)
		text += "\n\n[b]El ciervo de ámbar[/b]\nVuelve de noche al bosque al noreste de Puerto Alba. Camina detrás del ciervo; si te quedas atrás, te esperará. El diario L conserva el encargo."
	elif memory.kind == "flower":
		if guide_stage < 2: text = "La flor sigue cerrada. Una cinta al noreste de Puerto Alba habla de un ciervo que conoce su despertar."
		elif not flags.has(id):
			if not _reward(id,"Crystal4",3): return false
			guide_stage = 3
	elif memory.kind == "rune":
		flags[id] = true
	elif memory.kind == "heart":
		var count := rune_count(memory.cave_id)
		if count < 3: text = "Tres voces rodeaban esta memoria. Has escuchado %d de 3. Busca las piedras de las otras cámaras." % count
		elif not flags.has(id):
			if not _reward(id,"Gold_Ingots",2): return false
			text += "\n\nHas restituido un recuerdo. +2 lingotes para la forja."
	elif memory.kind == "secret" and not flags.has(id):
		if not _reward(id,"Crystal4",2): return false
		text += "\n\nSecreto descubierto · +2 cristales verdes."
	get_parent()._refresh_hud_bar()
	get_parent().dialogue_requested.emit(memory.title,"Memorias de Aeloria",memory.title,text)
	return true

func _reward(id: String, item: String, count: int) -> bool:
	if flags.has(id): return true
	var inventory := get_node("/root/InventoryManager")
	if not inventory.add_item(item,count): return false
	flags[id] = true
	trace_rewards += 1
	return true

func rune_count(id: String) -> int:
	var count := 0
	for i in 3:
		if flags.has(id+":rune%d"%i): count += 1
	return count

func save_state() -> Dictionary:
	return {"flags":flags.duplicate(true),"guide_stage":guide_stage,"guide_index":guide_index}

func load_state(state: Dictionary) -> void:
	_farewell_time = 0.0
	_guide.scale = Vector3.ONE*0.65
	for material in _gold_materials: material.set_shader_parameter("departure",0.0)
	flags = (state.get("flags",{}) as Dictionary).duplicate(true)
	guide_stage = clampi(int(state.get("guide_stage",0)),0,3)
	guide_index = maxi(int(state.get("guide_index",0)),0)
	if guide_stage == 1:
		_build_route()
		if not route.is_empty(): _guide.global_position = route[guide_index]

func chronicle() -> String:
	var lines := PackedStringArray(["\n[color=#f0d089][b]LOS RECUERDOS DEL BOSQUE[/b][/color]"])
	lines.append(["Una cinta al noreste de Puerto Alba habla de luces entre los árboles.","El ciervo de ámbar: sigue las luces de noche, caminando. Te espera si te retrasas.","El ciervo de ámbar: recoge con E la flor del claro.","✓ El ciervo de ámbar: la memoria del bosque ha despertado."][guide_stage])
	for spec in RPGStoryRuntime.GATE_SPECS:
		lines.append("%s · %d/3 voces · %s · secreto %s" % [spec.name,rune_count(spec.id),"recuperado" if flags.has(spec.id+":heart") else "pendiente","hallado" if flags.has(spec.id+":secret") else "oculto"])
	return "\n".join(lines)
