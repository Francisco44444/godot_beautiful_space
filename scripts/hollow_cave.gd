extends StaticBody3D

const HOLLOW: ArrayMesh = preload("res://generated/caves/hollow.res")
const MEMORY = preload("res://scripts/cave_memory.gd")
const ROUTE := [Vector3(0, 0, 34), Vector3(0, -4.5, -6), Vector3(0, -12.0, -46), Vector3(0, -18, -95), Vector3(-24, -18, -132), Vector3(18, -18, -146), Vector3(0, -18, -95)]
const SECRET := Vector3(29, -18, -91)
const BOCA_Z := -12.0
const FONDO_VESTIBULO := -60.0
const COTA_CUBIERTA := 2.0
var terrain: Terrain3D
var spec: Dictionary
var director: Node
var gate: RPGCaveGate
var lights: Array[OmniLight3D] = []
var _tick := 0.0
var _active := true
static var _shape: ConcavePolygonShape3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("explorable_cave")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.29, 0.23)
	material.roughness = 0.96
	material.albedo_texture = preload("res://assets/textures/stylized_terrain/quaternius_rock_albedo_seamless.png")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE*0.18
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var visual := MeshInstance3D.new()
	visual.name = "Hollow"
	visual.mesh = HOLLOW
	visual.material_override = material
	visual.visibility_range_end = 450.0
	add_child(visual)
	if _shape == null:
		_shape = HOLLOW.create_trimesh_shape()
		_shape.backface_collision = true
	var shape := CollisionShape3D.new()
	shape.name = "HollowCollision"
	shape.shape = _shape
	add_child(shape)
	_sculpt_approach()
	_build_approach()
	_decorate()
	for i in 3:
		var at: Vector3 = ROUTE[3 + i]
		_add_memory("rune%d" % i, "Escuchar la piedra %d" % (i + 1), String(spec.fragments[i]), at + Vector3(-2.0, 1.0, 0.0), "rune")
	_add_memory("heart", "Restituir el recuerdo", String(spec.ending), Vector3(18, -17, -148), "heart")
	_add_memory("secret", "Abrir el relicario oculto", "Alguien escondió aquí lo que no podía llevarse. El polvo conserva la forma de sus dedos.", SECRET + Vector3(0, 0.9, 0), "secret")
	gate = RPGCaveGate.new()
	gate.gate_id = String(spec.id)
	gate.display_name = String(spec.name)
	gate.key_item_id = String(spec.key)
	gate.destination_hint = String(spec.hint)
	gate.story_runtime = director.get_parent()
	add_child(gate)
	gate.position = Vector3(0, -10.5, -38)
	# El sello ocupa todo el pasadizo: la llave no se puede rodear por un lateral.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 3.1, -6.9, -38), Vector3(2.7, 7.2, 1.0), material)
	_add_box(Vector3(0,-5.0,-38),Vector3(7.8,3,1.0),material)
	_medieval_portal()
	_construir_vestibulo()
	_carve_mouth()
	_roca_de_encaje()
	set_meta("route_length", 0.0)
	var length := 0.0
	for i in range(1, ROUTE.size()): length += ROUTE[i].distance_to(ROUTE[i-1])
	set_meta("route_length", length)
	set_meta("mesh_triangles", HOLLOW.get_faces().size() / 3)

func _sculpt_approach() -> void:
	# El verde pertenece al heightmap de Terrain3D. No hay faldones de malla
	# pintados de césped: la ladera, su colisión y las briznas comparten suelo.
	var spacing := terrain.vertex_spacing
	var center := Vector2(global_position.x,global_position.z)
	var changed := 0
	for x in range(floori((center.x-90)/spacing),ceili((center.x+90)/spacing)):
		for z in range(floori((center.y-90)/spacing),ceili((center.y+90)/spacing)):
			var at := Vector3(x*spacing,global_position.y,z*spacing)
			var local := to_local(at)
			if absf(local.x)>26 or local.z < -48 or local.z>60: continue
			var original := terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,at).r
			if not is_finite(original): continue
			var width := 18.0+sin(local.z*0.07)*1.7+sin(local.z*0.13+1.3)*1.3
			var centerline := sin((local.z+20)*0.04)*0.6
			var cerca_boca := (1.0-smoothstep(8.0,26.0,absf(local.z-BOCA_Z)))
			var canal := 6.0
			var borde := lerpf(width,9.5,cerca_boca)
			var lateral := smoothstep(canal,borde,absf(local.x-centerline))
			var end_blend := maxf(smoothstep(34,54,local.z),1.0-smoothstep(-48,-32,local.z))
			var blend := maxf(lateral,end_blend)
			if blend >= 1.0: continue
			var floor_y := global_position.y+clampf((local.z-18)*0.1875,-18.0,0.0)
			# La bóveda queda enterrada en una loma real. El agujero sólo elimina
			# los triángulos gruesos que atravesarían la transición hacia el techo.
			var cubierta := maxf(original,global_position.y+COTA_CUBIERTA+0.5)
			var altura_canal := lerpf(floor_y,cubierta,1.0-smoothstep(-26.0,-18.0,local.z))
			# Los hombros de la loma abrazan la portada. Las pendientes siguen
			# siendo suelo con césped, sin una pared verde de geometría rígida.
			var hombro := cerca_boca*smoothstep(6.0,9.5,absf(local.x-centerline))
			floor_y = lerpf(altura_canal,maxf(original,global_position.y+2.6),hombro)
			terrain.data.set_height(at,lerpf(floor_y,original,blend))
			changed += 1
	set_meta("sculpted_terrain_vertices",changed)


func _build_approach() -> void:
	# Únicamente se construye el pavimento de piedra, sobre el suelo esculpido.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for z in range(-44,56,2):
		for x in range(-4,4,2):
			var quad := PackedVector3Array()
			for offset in [Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)]:
				var point := Vector3(x+offset.x,0,z+offset.y)
				var floor_y := clampf((point.z-18)*0.1875,-18.0,0.0)
				if point.z>34:
					var height := terrain.data.get_height(to_global(point))-global_position.y
					if is_finite(height): floor_y = height
				point.y = floor_y+0.08
				quad.append(point)
			for i in [0,2,1,0,3,2]: st.add_vertex(quad[i])
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/stylized_terrain/quaternius_rock_albedo_seamless.png")
	material.albedo_color = Color(0.45,0.43,0.36)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE*0.15
	st.set_material(material)
	var mesh := st.commit()
	var view := MeshInstance3D.new()
	view.name = "StonePath"
	view.mesh = mesh
	view.visibility_range_end = 450
	add_child(view)
	var collision := CollisionShape3D.new()
	collision.name = "ApproachCollision"
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	add_child(collision)

func _carve_mouth() -> void:
	var spacing := terrain.vertex_spacing
	var center := Vector2(global_position.x, global_position.z)
	var reach := 70.0
	for x in range(floori((center.x-reach)/spacing), ceili((center.x+reach)/spacing)):
		for z in range(floori((center.y-reach)/spacing), ceili((center.y+reach)/spacing)):
			var world := Vector3(x*spacing, global_position.y, z*spacing)
			var local := to_local(world)
			if absf(local.x)<24 and local.z>-64 and local.z<60:
				var agujero := false
				if absf(local.x)<3.2 and local.z>-46 and local.z<-18:
					var maximo := -INF
					for dx in range(-1,2):
						for dz in range(-1,2):
							var muestra := world+Vector3(dx*spacing,0,dz*spacing)
							var altura := terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,muestra).r-global_position.y
							var suelo := clampf((to_local(muestra).z-18)*0.1875,-18.0,0.0)
							maximo = maxf(maximo,altura-suelo)
					# Sólo retirar las celdas que cruzan el volumen transitable.
					# Cuando la tierra ya está encima de la bóveda, conservarla:
					# así la cubierta es una loma de Terrain3D con hierba real.
					var altura_actual := terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,world).r-global_position.y
					var suelo_actual := clampf((local.z-18)*0.1875,-18.0,0.0)
					agujero = maximo>0.2 and altura_actual-suelo_actual<8.5
				terrain.data.set_control_hole(world,agujero)
				var suelo := clampf((local.z-18)*0.1875,-18.0,0.0)
				var altura := terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,world).r-global_position.y
				if absf(local.x)<2.4 and local.z>BOCA_Z-12 and local.z<BOCA_Z+4 and altura<suelo+2.5:
					# El pequeño borde del suelo que asome junto al pavimento es
					# piedra también; no una cuña verde dentro de la puerta.
					terrain.data.set_control_base_id(world,5)
					terrain.data.set_control_overlay_id(world,5)
					terrain.data.set_control_blend(world,0.0)
					terrain.data.set_control_auto(world,false)


func _construir_vestibulo() -> void:
	# Terrain3D tiene vértices cada 4,6875 m: un agujero no acaba exactamente
	# en el arco. Esta fábrica continua absorbe ese borde bajo la loma y se
	# solapa con la gruta horneada; no quedan laterales abiertos al cielo.
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.62,0.50,0.34)
	piedra.albedo_texture = preload("res://assets/textures/stylized_terrain/quaternius_rock_albedo_seamless.png")
	piedra.uv1_triplanar = true
	piedra.uv1_scale = Vector3.ONE*0.22
	piedra.roughness = 0.98
	piedra.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frontal := _perfil_vestibulo(BOCA_Z,3.05,3.8,3.05)
	var cuello := _perfil_vestibulo(BOCA_Z-5.0,3.2,3.1,2.1)
	var fondo := _perfil_vestibulo(FONDO_VESTIBULO,3.65,3.2,2.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for indice in frontal.size()-1:
		# Intradós, fachada, trasera y volumen enterrado. El camino proporciona
		# el pavimento; la base también cierra la unión bajo sus bordes.
		_agregar_cara(st,frontal[indice+1].interior,frontal[indice].interior,cuello[indice].interior,cuello[indice+1].interior)
		_agregar_cara(st,cuello[indice+1].interior,cuello[indice].interior,fondo[indice].interior,fondo[indice+1].interior)
		_agregar_cara(st,frontal[indice].exterior,frontal[indice].interior,frontal[indice+1].interior,frontal[indice+1].exterior)
		_agregar_cara(st,fondo[indice].interior,fondo[indice].exterior,fondo[indice+1].exterior,fondo[indice+1].interior)
		_agregar_cara(st,frontal[indice].exterior,frontal[indice+1].exterior,cuello[indice+1].exterior,cuello[indice].exterior)
		_agregar_cara(st,cuello[indice].exterior,cuello[indice+1].exterior,fondo[indice+1].exterior,fondo[indice].exterior)
	st.set_material(piedra)
	var malla := st.commit()
	var vista := MeshInstance3D.new()
	vista.name = "VestibuloDePiedra"
	vista.mesh = malla
	vista.visibility_range_end = 450
	add_child(vista)
	var colision := CollisionShape3D.new()
	colision.name = "VestibuloCollision"
	var forma := malla.create_trimesh_shape()
	forma.backface_collision = true
	colision.shape = forma
	add_child(colision)
	set_meta("portal_z",BOCA_Z)
	_colocar_antorchas()


func _roca_de_encaje() -> void:
	# El borde que descarta el shader del terreno no coincide con el raycast
	# de su mapa de controles. Cerrar esa costura con roca apoyada en sus alturas
	# impide ver el cielo desde arriba o al mirar oblicuamente hacia la boca.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paso := terrain.vertex_spacing
	var celdas := {}
	for x in range(-14,14,2):
		for z in range(-58,-16,2):
			var centro := to_global(Vector3(x+1,0,z+1))
			var cerca_hueco := false
			for dx in range(-2,3):
				for dz in range(-2,3):
					if terrain.data.get_control_hole(centro+Vector3(dx*paso,0,dz*paso)): cerca_hueco = true
			if not cerca_hueco: continue
			var cara := PackedVector3Array()
			for desplazamiento in [Vector2.ZERO,Vector2(0,2),Vector2(2,2),Vector2(2,0)]:
				var punto := Vector3(x+desplazamiento.x,0,z+desplazamiento.y)
				var mundo := to_global(punto)
				var rejilla := Vector2(mundo.x,mundo.z)/paso
				var base := rejilla.floor()
				var fraccion := rejilla-base
				var alturas := PackedFloat32Array()
				for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
					var muestra := Vector3((base.x+offset.x)*paso,0,(base.y+offset.y)*paso)
					alturas.append(terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,muestra).r-global_position.y)
				var altura := lerpf(lerpf(alturas[0],alturas[1],fraccion.x),lerpf(alturas[2],alturas[3],fraccion.x),fraccion.y)
				var borde_recortado := false
				for dx in range(-1,3):
					for dz in range(-1,3):
						if terrain.data.get_control_hole(Vector3((base.x+dx)*paso,0,(base.y+dz)*paso)): borde_recortado = true
				if not borde_recortado:
					# Fuera del recorte, la roca queda bajo la cota menor de la
					# celda. No forma repisas superpuestas al césped o la nieve.
					altura = minf(minf(alturas[0],alturas[1]),minf(alturas[2],alturas[3]))-0.35
				var suelo := clampf((punto.z-18)*0.1875,-18.0,0.0)
				punto.y = maxf(altura+0.05,suelo+6.0)
				cara.append(punto)
			celdas[Vector2i(x,z)] = cara
	if celdas.is_empty(): return
	for celda in celdas:
		var cara: PackedVector3Array = celdas[celda]
		_agregar_cara(st,cara[0],cara[1],cara[2],cara[3])
		var vecinos := [Vector2i(-2,0),Vector2i(0,2),Vector2i(2,0),Vector2i(0,-2)]
		for lado in 4:
			if celdas.has(celda+vecinos[lado]): continue
			var a := cara[lado]
			var b := cara[(lado+1)%4]
			var base_a := a
			var base_b := b
			# El remate no invade el intradós del pasadizo. En los flancos se
			# prolonga hacia abajo para formar roca maciza, sin láminas flotantes.
			base_a.y = clampf((a.z-18)*0.1875,-18.0,0.0)+(5.8 if absf(a.x)<4.3 else 3.5)
			base_b.y = clampf((b.z-18)*0.1875,-18.0,0.0)+(5.8 if absf(b.x)<4.3 else 3.5)
			if absf(a.x)>=4.3:
				base_a.y = minf(base_a.y,terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,to_global(a)).r-global_position.y-0.35)
			if absf(b.x)>=4.3:
				base_b.y = minf(base_b.y,terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT,to_global(b)).r-global_position.y-0.35)
			_agregar_cara(st,a,b,base_b,base_a)
	st.set_material(($VestibuloDePiedra as MeshInstance3D).mesh.surface_get_material(0))
	var malla := st.commit()
	var vista := MeshInstance3D.new()
	vista.name = "RocaDeEncaje"
	vista.mesh = malla
	vista.visibility_range_end = 450
	add_child(vista)
	var colision := CollisionShape3D.new()
	colision.name = "EncajeCollision"
	var forma := malla.create_trimesh_shape()
	forma.backface_collision = true
	colision.shape = forma
	add_child(colision)


func _perfil_vestibulo(z: float, ancho: float, arranque: float, radio: float) -> Array[Dictionary]:
	var suelo := clampf((z-18)*0.1875,-18.0,0.0)
	var perfil: Array[Dictionary] = []
	var portada := is_equal_approx(z,BOCA_Z)
	var ancho_exterior := 4.8 if portada else 13.0
	perfil.append({"interior":Vector3(-ancho,suelo-0.2,z),"exterior":Vector3(-ancho_exterior,suelo-0.8,z)})
	for indice in 17:
		var angulo := PI-float(indice)*PI/16.0
		var x_exterior := lerpf(-ancho_exterior,ancho_exterior,float(indice)/16.0)
		var techo_exterior := maxf(suelo+5.1,suelo+arranque+radio+0.65-4.0*pow(absf(x_exterior)/ancho_exterior,1.25))
		var exterior := Vector3(cos(angulo)*ancho_exterior,suelo+arranque+sin(angulo)*4.1,z) if portada else Vector3(x_exterior,techo_exterior,z)
		perfil.append({"interior":Vector3(cos(angulo)*ancho,suelo+arranque+sin(angulo)*radio,z),"exterior":exterior})
	perfil.append({"interior":Vector3(ancho,suelo-0.2,z),"exterior":Vector3(ancho_exterior,suelo-0.8,z)})
	# Cerrar bajo el pavimento evita ver el vacío desde un lateral bajo.
	perfil.append(perfil[0])
	return perfil


func _agregar_cara(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Una normal por cara evita la diagonal de sombreado de un cuadrilátero
	# no plano; la forma sigue teniendo exactamente sus seis vértices.
	var normal := -((b-a).cross(c-a)+(c-a).cross(d-a)).normalized()
	st.set_normal(normal)
	for punto in [a,b,c,a,c,d]: st.add_vertex(punto)


func _colocar_antorchas() -> void:
	var antorcha: PackedScene = preload("res://assets/quaternius/Fantasy Props MegaKit/Exports/glTF/Torch_Metal.gltf")
	for lado in [-1.0,1.0]:
		var soporte := antorcha.instantiate() as Node3D
		soporte.position = Vector3(lado*2.85,-2.6,BOCA_Z-3.2)
		soporte.scale = Vector3.ONE*1.2
		add_child(soporte)
		var luz := OmniLight3D.new()
		luz.position = soporte.position+Vector3(0,0.6,0.2)
		luz.light_color = Color(1.0,0.63,0.28)
		luz.light_energy = 2.8
		luz.omni_range = 11.0
		luz.shadow_enabled = false
		add_child(luz)
		lights.append(luz)

func _decorate() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = String(spec.id).hash()
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.48
	crystal.height = 2.4
	crystal.radial_segments = 5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = spec.color
	glow.emission_enabled = true
	glow.emission = spec.color
	glow.emission_energy_multiplier = 0.42
	glow.roughness = 0.55
	glow.metallic = 0.15
	crystal.material = glow
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = crystal
	mm.instance_count = 110
	for i in mm.instance_count:
		var room: Vector3 = [Vector3(0,-18,-95),Vector3(-24,-18,-132),Vector3(18,-18,-146),SECRET][i % 4]
		var angle := random.randf()*TAU
		var radius := random.randf_range(4.5, 8.0) if i % 4 != 3 else random.randf_range(3.5, 5.2)
		var scale_value := random.randf_range(0.35,1.5)
		var at := room + Vector3(cos(angle)*radius, scale_value*1.2, sin(angle)*radius)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE*scale_value),at))
	var instances := MultiMeshInstance3D.new()
	instances.name = "CrystalGarden"
	instances.multimesh = mm
	instances.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instances.visibility_range_end = 240
	add_child(instances)
	for at in [Vector3(0,-13,-91),Vector3(-24,-15,-132),Vector3(18,-15,-146),SECRET+Vector3.UP*4]:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = (spec.color as Color).lerp(Color(1,0.72,0.4),0.18)
		light.light_energy = 1.7
		light.omni_range = 19.0
		light.shadow_enabled = false
		add_child(light)
		lights.append(light)
	var pool := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 3.6
	disk.bottom_radius = 3.6
	disk.height = 0.035
	disk.radial_segments = 18
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.025,0.13,0.18)
	water.metallic = 0.65
	water.roughness = 0.22
	disk.material = water
	pool.mesh = disk
	pool.position = Vector3(-24,-17.94,-132)
	add_child(pool)

func _add_memory(id: String, title: String, text: String, at: Vector3, kind: String) -> void:
	var memory := MEMORY.new()
	memory.director = director
	memory.memory_id = String(spec.id)+":"+id
	memory.cave_id = String(spec.id)
	memory.title = title
	memory.text = text
	memory.kind = kind
	memory.position = at
	add_child(memory)
	var stone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.50
	mesh.bottom_radius = 0.65
	mesh.height = 1.0
	mesh.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32,0.37,0.40)
	mat.emission_enabled = true
	mat.emission = spec.color
	mat.emission_energy_multiplier = 0.24
	mesh.material = mat
	stone.mesh = mesh
	memory.add_child(stone)

func _medieval_portal() -> void:
	# Dovelas de piedra, no la carcasa lisa del túnel sobre la hierba. El acceso
	# se lee como una ruina de los fundidores y el hueco sigue bajo la ladera.
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.53,0.51,0.43)
	stone.albedo_texture = preload("res://assets/textures/stylized_terrain/quaternius_rock_albedo_seamless.png")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE*0.3
	stone.roughness = 0.98
	var suelo := (BOCA_Z-18)*0.1875
	for row in 4:
		for side in [-1.0,1.0]:
			_add_box(Vector3(side*3.62,suelo+0.48+row*0.96,BOCA_Z-0.35),Vector3(1.16,0.94,1.7),stone)
	for i in 13:
		var angle := float(i)*PI/12.0
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.91,1.16,1.7)
		mesh.material = stone
		block.mesh = mesh
		block.position = Vector3(cos(angle)*3.62,suelo+3.8+sin(angle)*3.62,BOCA_Z-0.35)
		block.rotation.z = angle-PI*0.5
		add_child(block)


func _add_box(at: Vector3, size: Vector3, material: Material) -> void:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	view.mesh = mesh
	view.position = at
	add_child(view)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	add_child(shape)

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0: return
	_tick = 0.35
	var player: Node3D = director.player
	var near := player.global_position.distance_squared_to(to_global(Vector3(0,-15,-85))) < 240.0*240.0
	if near == _active: return
	_active = near
	collision_layer = 1 if near else 0
	for light in lights: light.visible = near
