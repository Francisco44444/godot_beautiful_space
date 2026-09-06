extends SceneTree

## Verifica la escala insular, el mapa interactivo y que las viviendas grandes
## sean cuerpos modulares con suelo, paredes físicas y una entrada atravesable.
##
## La cota de planta ya no se escribe aquí. El generador viejo apoyaba la casa
## sobre una losa a 0.35 m y la prueba llevaba ese 0.35 y un stair_x de ±3.0
## metidos en sus rayos; con el generador nuevo cada casa se posa a la cota real
## por encima del relieve interior, y cada tramo está donde su receta lo pone,
## así que todas las cotas se LEEN de la casa montada o se derivan de la receta.

## Censo del mundo, MEDIDO ejecutando la escena y contando los nodos, no elegido
## para que la prueba pase. Todo lo demás de las casas se deriva de su receta;
## esto es lo único que no se puede derivar, porque depende de cuántas parcelas
## traza cada villa. Si el generador cambia ese trazado hay que volver a MEDIR,
## no ajustar a ojo: el mensaje de fallo dice siempre la cifra encontrada.
const EXPECTED_HOUSES := 107
const EXPECTED_ROBLEDAL_HOUSES := 58
const EXPECTED_VILLAGES := 6
const EXPECTED_HAMLETS := 8
const EXPECTED_CASTLES := 3


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for singleton_name in ["ExplorationManager", "InventoryManager"]:
		root.get_node(singleton_name).set("autosave_enabled", false)
	root.get_node("SaveGameManager").set_process(false)
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	root.get_node("SaveGameManager").call("bind_world", null)
	for _frame in 4:
		await process_frame

	var terrain := world.get_node("Terrain3D") as Terrain3D
	if terrain.data.get_region_count() != 100 or terrain.region_size != 256 or absf(terrain.vertex_spacing - 4.6875) > 0.001:
		_fail("El mundo no conserva los 12 x 12 km y cien regiones Terrain3D de alta resolución.")
		return
	var sea_boundary := world.get_node_or_null("SeaBoundary") as StaticBody3D
	if sea_boundary == null or int(world.get("sea_boundary_segment_count")) < 96 or not bool(sea_boundary.get_meta("forbids_swimming", false)):
		_fail("El perímetro marítimo no impide físicamente que el personaje entre al agua.")
		return
	var cliff_barrier := world.get_node_or_null("CoastalCliffBarrier") as StaticBody3D
	if cliff_barrier != null or int(world.get("coastal_cliff_barrier_segment_count")) != 0 or not bool(world.get_meta("coastal_fall_barrier_disabled", false)):
		_fail("La antigua barrera invisible todavía impide caer por los acantilados.")
		return

	var hud := world.get_node("HUD")
	var controls_panel := hud.get_node("Margin") as Control
	var mini_map := hud.get_node("MiniMap") as Control
	var full_map := hud.get_node("FullMap") as Control
	var credits_overlay := hud.get_node("CreditsOverlay") as Control
	if controls_panel.visible or not mini_map.visible or full_map.visible or credits_overlay.visible or int(full_map.call("get_poi_count")) < 10 or int(full_map.call("get_road_count")) < 10:
		_fail("Los controles deben empezar ocultos y el minimapa activo sin perder la red insular.")
		return
	if (
		not bool(full_map.get_meta("ocean_fills_exterior", false))
		or not bool(full_map.get_meta("false_beach_border_removed", false))
		or not bool(full_map.get_meta("rotating_player_marker", false))
	):
		_fail("El mapa todavía conserva fondo negro, borde amarillo falso o marcador fijo.")
		return
	var controls_event := InputEventKey.new()
	controls_event.physical_keycode = KEY_N
	controls_event.pressed = true
	hud.call("_unhandled_input", controls_event)
	if not controls_panel.visible:
		_fail("La tecla N no muestra la leyenda de controles.")
		return
	hud.call("_unhandled_input", controls_event)
	var minimap_event := InputEventKey.new()
	minimap_event.physical_keycode = KEY_B
	minimap_event.pressed = true
	hud.call("_unhandled_input", minimap_event)
	if mini_map.visible:
		_fail("La tecla B no oculta el minimapa.")
		return
	hud.call("_unhandled_input", minimap_event)
	if not mini_map.visible:
		_fail("La tecla B no vuelve a mostrar el minimapa.")
		return
	var map_event := InputEventAction.new()
	map_event.action = "map"
	map_event.pressed = true
	hud.call("_unhandled_input", map_event)
	if mini_map.visible or not full_map.visible:
		_fail("La tecla M no abre el mapa completo.")
		return
	hud.call("_unhandled_input", map_event)
	if not mini_map.visible or full_map.visible:
		_fail("La tecla M no recupera el estado elegido del minimapa.")
		return
	var pause_menu := hud.get_node_or_null("PauseMenu")
	if pause_menu == null:
		_fail("El menú de pausa no existe.")
		return
	pause_menu.call("set_open", true)
	var credits_button := pause_menu.find_child("CreditsButton", true, false) as Button
	if credits_button == null:
		_fail("Agradecimientos no aparece como entrada del menú de pausa.")
		return
	credits_button.pressed.emit()
	var credits_text := pause_menu.find_child("CreditsText", true, false) as RichTextLabel
	if (
		credits_text == null
		or "La Colina que Conoce tu Voz" not in credits_text.text
		or "Promise" not in credits_text.text
		or "Ashes" not in credits_text.text
		or "Música de https://www.fiftysounds.com/es/" not in credits_text.text
	):
		_fail("La entrada Agradecimientos no contiene la atribución completa de FiftySounds.")
		return
	pause_menu.call("set_open", false)
	if credits_overlay.visible or paused:
		_fail("Cerrar el menú de agradecimientos no devuelve correctamente al juego.")
		return

	if int(world.call("get_fast_travel_count")) != 5:
		_fail("El mapa no expone los cinco destinos de viaje rápido, incluido el Bosque Tenebroso.")
		return
	var player := world.get_node("Player") as Player
	if int(world.call("get_boss_travel_count")) != 4:
		_fail("La tecla 0 no expone los cuatro enfrentamientos finales.")
		return
	var boss_event := InputEventKey.new()
	boss_event.physical_keycode = KEY_0
	boss_event.pressed = true
	for boss_index in 4:
		world.call("_unhandled_input", boss_event)
		var boss_destination: Vector2 = world.call("get_boss_travel_position", boss_index)
		var player_position := Vector2(player.global_position.x, player.global_position.z)
		if player_position.distance_to(boss_destination) > 0.05 or int(world.get("last_boss_travel_index")) != boss_index:
			_fail("La pulsación 0 no viaja al jefe final %d en orden." % (boss_index + 1))
			return
	world.call("_unhandled_input", boss_event)
	if int(world.get("last_boss_travel_index")) != 0:
		_fail("Después del último jefe, la tecla 0 no vuelve al primero.")
		return
	var travel_event := InputEventKey.new()
	travel_event.physical_keycode = KEY_5
	travel_event.pressed = true
	world.call("_unhandled_input", travel_event)
	var hero_visual := player.get_node("Visual") as Node3D
	hero_visual.rotation.y = 0.0
	var north_facing := full_map.call("_player_map_direction") as Vector2
	hero_visual.rotation.y = PI * 0.5
	var turned_facing := full_map.call("_player_map_direction") as Vector2
	if north_facing.dot(turned_facing) > 0.20:
		_fail("El pico blanco del mapa no gira cuando cambia la orientación visual del protagonista.")
		return
	hero_visual.rotation.y = 0.0
	var first_destination: Vector2 = world.call("get_fast_travel_position", 1)
	if Vector2(player.global_position.x, player.global_position.z).distance_to(first_destination) > 0.05 or int(world.get("last_fast_travel_slot")) != 1:
		_fail("La tecla 5 no transporta al jugador a las Dunas Doradas.")
		return
	for slot in range(2, 6):
		if not bool(world.call("fast_travel_to", slot)):
			_fail("No se pudo viajar al destino %d." % slot)
			return
		var destination: Vector2 = world.call("get_fast_travel_position", slot)
		if Vector2(player.global_position.x, player.global_position.z).distance_to(destination) > 0.05:
			_fail("El destino de viaje rápido %d no coincide con su marcador del mapa." % slot)
			return
	var mystery_event := InputEventKey.new()
	mystery_event.physical_keycode = KEY_9
	mystery_event.pressed = true
	world.call("_unhandled_input", mystery_event)
	var mystery_destination: Vector2 = world.call("get_fast_travel_position", 5)
	if (
		int(world.get("last_fast_travel_slot")) != 5
		or Vector2(player.global_position.x, player.global_position.z).distance_to(mystery_destination) > 0.05
	):
		_fail("La tecla 9 no transporta al jugador al Bosque Tenebroso.")
		return

	# ------------------------------------------------------------------------
	# CONTRATO DE LAS VIVIENDAS, migrado al generador de BuildingSolver.
	#
	# El generador viejo levantaba UNA caja cerrada por casa, con UNA escalera
	# por planta puesta en el extremo contrario cada vez, y publicaba nodos
	# llamados UpperFloorCollision*, StairRampCollision*, InteriorStairSteps*,
	# InteriorStairRails*, HouseGuard* y UpperFloorL*. Ninguno de esos nombres
	# existe ya: contarlos daría cero siempre y compararlo contra cero pasaría
	# sin probar nada, que es peor que no tener aserto. Aquí se cuentan los
	# nombres nuevos —Muro, Jamba, Dintel, Forjado, Escalera, Cimiento— y cada
	# cifra esperada se DERIVA de la receta reconstruida, no se escribe a mano.
	#
	# Asertos retirados porque el diseño nuevo no tiene la pieza, con el defecto
	# que prevenían:
	#   - stair_guardrails_per_floor / HouseGuard* (3 barandillas por planta,
	#     colisión y visual): prevenían que el hueco del forjado quedara sin
	#     protección lateral y el héroe se despeñara por él al desembarcar. Ya
	#     no aplica: los dos tramos de cada transición nacen en las dos columnas
	#     EXTREMAS del cuerpo, contra su muro, así que el hueco que abren queda
	#     pegado a la pared y no hay borde interior por el que caerse. Lo que
	#     antes protegía la barandilla lo comprueba ahora el aserto de "el pie
	#     apoya en suelo macizo" tramo a tramo, que es más fuerte porque mide el
	#     apoyo real en vez de la presencia de un pasamanos.
	#   - stair_visual == "Stair_Interior_Simple" e InteriorStairSteps/Rails:
	#     prevenían que la escalera fuera una rampa pelada sin malla de peldaños.
	#     La escalera usa ahora peldaños y pasamanos del kit sobre una cuña física
	#     de ocho puntos. house_traversal_test comprueba su presencia y tránsito.
	#   - stair_column_spacing >= 9.0 y stair_transition_is_flush: prevenían que
	#     los dos tramos consecutivos se apilaran encima. Ya no aplica tal cual:
	#     ahora se exige la separación EXACTA entre las dos columnas de la
	#     transición, derivada del ancho del cuerpo, y el desfase de una celda
	#     entre transiciones.
	#   - stair_count == floor_count - 1: era UNA escalera por planta. Ahora son
	#     DOS por transición, una a cada lado.
	#   - UpperFloorCollision* == plantas altas * 3 y StairRampCollision* ==
	#     plantas altas: prevenían que una planta alta se quedara sin suelo
	#     físico o sin rampa. Siguen comprobados, con más grano: el forjado se
	#     emite CELDA A CELDA y aquí se exige el número exacto de celdas que pide
	#     la receta menos el hueco de escalera, y cada tramo tiene que ser una
	#     cuña convexa de ocho puntos.
	#   - UpperFloorL* == plantas altas * 25 (las baldosas de madera del kit):
	#     prevenían que la planta alta se viera como un vacío desde abajo. Este
	#     ahora se conserva en el MultiMesh Solado, con baldosas visibles.
	# ------------------------------------------------------------------------
	var medieval := world.get_node("MedievalSetDressing") as MedievalSetDressing
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var cell := float(BuildingSolver.CELL)
	var storey := float(BuildingSolver.STOREY)
	var flight_pitch := rad_to_deg(atan(storey / (float(BuildingSolver.STAIR_RUN_CELLS) * cell)))
	var building_count := 0
	var three_storey_count := 0
	var tall_house_count := 0
	var robledal_floors: Dictionary = {}
	var robledal_count := 0
	var switchbacks_measured := 0
	var measured_flights := 0
	var measured_slabs := 0
	var measured_gables := 0
	var measured_roofs := 0
	var measured_footings := 0
	var expected_flights := 0
	var expected_slabs := 0
	var expected_gables := 0
	var expected_roofs := 0
	var expected_footings := 0
	for child in medieval.get_children():
		if not child is StaticBody3D:
			continue
		if "House" not in child.name and "Hall" not in child.name:
			continue
		var building := child as StaticBody3D
		var scale_factor := building.scale
		var house_name := building.name
		building_count += 1
		var floors := int(building.get_meta("floor_count", 0))
		if floors < 2 or floors > 5:
			_fail("%s declara %d plantas, fuera del rango habitable de 2 a 5." % [house_name, floors])
			return
		if floors == 3:
			three_storey_count += 1
		if floors >= 3:
			tall_house_count += 1
		if String(house_name).begins_with("Villa Robledal"):
			if floors < 3:
				_fail("%s debe tener entre tres y cinco plantas." % house_name)
				return
			robledal_count += 1
			robledal_floors[floors] = int(robledal_floors.get(floors, 0)) + 1

		# La receta se reconstruye para poder derivar cada cifra esperada —alero,
		# losas, forjados, hastiales, columnas de escalera— en vez de escribir
		# números mágicos de los que nadie sabe luego de dónde salen.
		var recipe := _recipe_named(String(building.get_meta("recipe", "")), floors)
		if recipe.is_empty():
			_fail("%s dice ser '%s' de %d plantas y no existe tal receta." % [
				house_name, building.get_meta("recipe", "?"), floors])
			return
		var volumes: Array = recipe["volumes"]
		var shift := _centre_offset(volumes)
		var eave := _eave_height(volumes)

		# 1. Lo que el propio generador ha comprobado. Si alguno deja de ser
		#    cero la casa está mal construida y no hay que volver a medirla.
		for key in [
			"cell_conflicts", "duplicate_edges", "roof_below_eave_count",
			"unreachable_cells", "unsupported_cells",
		]:
			if int(building.get_meta(key, -1)) != 0:
				_fail("%s publica %s = %s; debe ser cero." % [
					house_name, key, building.get_meta(key, -1)])
				return
		if float(building.get_meta("worst_roof_dip", 1.0)) > 0.0:
			_fail("%s mete un faldón %.2f m dentro de otro cuerpo." % [
				house_name, building.get_meta("worst_roof_dip", 1.0)])
			return

		# 2. Dos tramos por transición, ida y vuelta, no uno por planta.
		if (
			not bool(building.get_meta("enterable", false))
			or not bool(building.get_meta("stairs_traversable", false))
			or int(building.get_meta("stairs_per_transition", 0)) != 2
			or String(building.get_meta("stair_layout", "")) != "double_opposed_switchback"
			or int(building.get_meta("upper_floor_count", -1)) != floors - 1
			or int(building.get_meta("stair_count", -1)) != (floors - 1) * 2
			or int(building.get_meta("volume_count", -1)) != volumes.size()
			or absf(float(building.get_meta("storey_clearance", 0.0)) - storey * scale_factor.y) > 0.01
			or absf(float(building.get_meta("stair_pitch_degrees", 0.0)) - flight_pitch) > 0.05
		):
			_fail("%s no cumple el contrato de plantas y escaleras del generador nuevo." % house_name)
			return

		# 3. Huella exacta de su receta, no un mínimo laxo. La Casa del Río mide
		#    18.6 x 18.6 m: el viejo "al menos 12 x 21" ya no describe nada.
		var footprint: Vector2 = building.get_meta("footprint", Vector2.ZERO)
		var cells := _cell_box(volumes)
		var expected_footprint := Vector2(
			cells.size.x * cell * scale_factor.x, cells.size.y * cell * scale_factor.z)
		if footprint.distance_to(expected_footprint) > 0.05:
			_fail("%s mide %s y su receta '%s' da %s." % [
				house_name, footprint, recipe["display_name"], expected_footprint])
			return

		# 4. Marcadores de habitabilidad. Sin umbral y punto interior nadie sabe
		#    por dónde se entra ni hacia dónde ir una vez dentro.
		var foundation := building.get_node_or_null("StoneFoundation") as MeshInstance3D
		var doorway := building.get_node_or_null("Doorway") as Node3D
		var interior := building.get_node_or_null("InteriorPoint") as Node3D
		var decorado := building.get_node_or_null("Decorado") as Node3D
		if foundation == null or doorway == null or interior == null or decorado == null:
			_fail("%s no tiene losa, umbral, punto interior y rama de decorado." % house_name)
			return

		# 5. Censo de piezas, derivado de los metadatos: una arista, un muro; y
		#    un hueco son dos jambas y un dintel, nunca una caja en el medio.
		var census := _census(building)
		var doors := int(building.get_meta("door_count", -1))
		var arches := int(building.get_meta("arch_count", -1))
		var walls := int(building.get_meta("wall_count", -1))
		if doors < 1:
			_fail("%s no tiene puerta." % house_name)
			return
		if arches < volumes.size() - 1:
			_fail("%s tiene %d arcos para %d cuerpos: alguna medianera es un muro ciego." % [
				house_name, arches, volumes.size()])
			return
		if int(census.get("Muro", -1)) != walls - doors - arches:
			_fail("%s levanta %s muros macizos y su plan declara %d aristas con %d huecos." % [
				house_name, census.get("Muro", -1), walls, doors + arches])
			return
		if int(census.get("Jamba", -1)) != (doors + arches) * 2:
			_fail("%s pone %s jambas para %d huecos; tocan dos por hueco." % [
				house_name, census.get("Jamba", -1), doors + arches])
			return
		if int(census.get("Dintel", -1)) != doors + arches:
			_fail("%s pone %s dinteles para %d huecos." % [
				house_name, census.get("Dintel", -1), doors + arches])
			return
		var footings := int(census.get("Cimiento", -1))
		if footings != _expected_footings(volumes):
			_fail("%s pone %d losas de cimiento para %d cuerpos apoyados en tierra." % [
				house_name, footings, _expected_footings(volumes)])
			return
		var slabs := int(census.get("Forjado", -1))
		var want_slabs := _expected_slabs(volumes)
		if slabs != want_slabs:
			_fail("%s tiene %d celdas de forjado y su receta pide %d (celdas altas menos el hueco de escalera)." % [
				house_name, slabs, want_slabs])
			return
		var gables := _count_prefix(decorado, "Roof_Front")
		var roofs := _count_prefix(decorado, "Roof_RoundTiles") + _count_prefix(decorado, "Roof_Tower")
		if gables != _expected_gables(volumes) or roofs != _expected_roofs(volumes):
			_fail("%s cierra %d hastiales y %d faldones; su receta pide %d y %d." % [
				house_name, gables, roofs, _expected_gables(volumes), _expected_roofs(volumes)])
			return
		measured_footings += footings
		measured_slabs += slabs
		measured_gables += gables
		measured_roofs += roofs
		expected_footings += _expected_footings(volumes)
		expected_slabs += want_slabs
		expected_gables += _expected_gables(volumes)
		expected_roofs += _expected_roofs(volumes)

		# 6. La cubierta no se pisa: ni una colisión en la rama de decorado ni
		#    una sola forma por encima del alero. Y ni una colisión de malla
		#    completa: el castillo viejo arrastraba 33 con 19.026 caras.
		var dressing_shapes := _shapes(decorado)
		if not dressing_shapes.is_empty():
			_fail("%s cuelga %d colisiones del decorado; el tejado no colisiona." % [
				house_name, dressing_shapes.size()])
			return
		var wedges := 0
		for shape in _shapes(building):
			if shape.shape is ConcavePolygonShape3D:
				_fail("%s usa colisión de malla completa en %s." % [house_name, shape.name])
				return
			var local := building.to_local(shape.global_position)
			if local.y + _shape_top(shape) > eave + 0.05:
				_fail("%s tiene colisión a %.2f m, por encima del alero (%.2f m): %s." % [
					house_name, local.y + _shape_top(shape), eave, shape.name])
				return
			if not shape.name.begins_with("Escalera") and not shape.name.begins_with("Caracol"):
				continue
			wedges += 1
			if not shape.shape is ConvexPolygonShape3D:
				_fail("%s tiene una escalera que no es una cuña convexa: %s." % [
					house_name, shape.name])
				return
			if (shape.shape as ConvexPolygonShape3D).points.size() != 8:
				_fail("%s tiene una cuña de escalera de %d puntos; deben ser ocho." % [
					house_name, (shape.shape as ConvexPolygonShape3D).points.size()])
				return
		if wedges != (floors - 1) * 2:
			_fail("%s monta %d cuñas de escalera y declara %d." % [
				house_name, wedges, (floors - 1) * 2])
			return
		measured_flights += wedges
		expected_flights += (floors - 1) * 2

		# 7. Nada inclinado fuera de la cuadrícula modular.
		for part in building.get_children() + decorado.get_children():
			if not part is Node3D:
				continue
			var part_3d := part as Node3D
			if absf(part_3d.rotation.x) > 0.001 or absf(part_3d.rotation.z) > 0.001:
				_fail("Una pieza de %s está inclinada fuera de la cuadrícula modular: %s." % [
					house_name, part.name])
				return

		# 8. Suelo por encima del relieve y rampa conectada a tierra. El antiguo
		# umbral a ras permitía que una loma atravesase el interior de la casa.
		var outward := (doorway.position - interior.position) / 3.0
		if absf(outward.length() - 1.0) > 0.01:
			_fail("%s no coloca umbral y punto interior sobre el eje de su puerta." % house_name)
			return
		var entrance_approach := building.get_node_or_null("ApproachPoint") as Node3D
		if entrance_approach == null or building.get_node_or_null("EntranceRamp") == null or building.get_node_or_null("StoneEntranceRamp") == null:
			_fail("%s carece de acceso exterior con rampa visible y física." % house_name)
			return
		var approach_floor := entrance_approach.global_position
		var terrain_height := terrain.data.get_height(approach_floor)
		if not is_finite(terrain_height) or absf(approach_floor.y - terrain_height) > 0.06:
			_fail("La rampa exterior de %s no conecta con el terreno." % house_name)
			return
		for volume in volumes:
			if int(volume.get("base_level", 0)) > 0:
				continue
			var origin: Vector2i = volume["origin"]
			var size: Vector2i = volume["size"]
			for x in range(size.x + 1):
				for z in range(size.y + 1):
					var floor_point := building.to_global(Vector3((origin.x + x) * cell, 0.0, (origin.y + z) * cell) + shift)
					if floor_point.y < terrain.data.get_height(floor_point) + 0.10:
						_fail("El terreno atraviesa la planta baja de %s." % house_name)
						return

		# 9. Se entra andando: la puerta no tiene colisión invisible. Se
		#    comprueba en TODAS las casas, no sólo en la primera generada.
		var door_hit := _ray_to_building(
			space,
			building,
			building.to_global(doorway.position + outward * 1.0),
			building.to_global(interior.position)
		)
		if not door_hit.is_empty():
			_fail("La puerta de %s sigue bloqueada por una colisión invisible en %s." % [
				house_name, building.to_local(door_hit["position"])])
			return

		# 10. Cada planta alta de cada cuerpo tiene forjado físico bajo los pies,
		#     medido en la fila frontal, fuera de los huecos alternos de escalera.
		for volume in volumes:
			var origin: Vector2i = volume["origin"]
			var size: Vector2i = volume["size"]
			var centre := Vector3(
				(float(origin.x) + float(size.x) * 0.5) * cell,
				0.0,
				(float(origin.y) + 0.5) * cell
			) + shift
			for level in range(1, int(volume["floors"])):
				var y := float(level) * storey
				if not _floor_under(space, building, Vector3(centre.x, y, centre.z), y):
					_fail("%s no tiene forjado físico en la planta %d del cuerpo '%s'." % [
						house_name, level + 1, volume["name"]])
					return

		# 11. Geometría de los tramos, leída de las propias cuñas.
		var stair_volume := _stair_volume(volumes)
		if stair_volume.is_empty():
			_fail("%s no declara ningún cuerpo con escaleras." % house_name)
			return
		if int((stair_volume["size"] as Vector2i).x) < 3 or int((stair_volume["size"] as Vector2i).y) < 5:
			_fail("%s sube en caracol y este contrato sólo cubre tramos rectos: hay que extenderlo." % house_name)
			return
		var flights := _flights(building)
		if flights.size() != wedges:
			_fail("%s tiene %d cuñas y sólo %d son tramos rectos axiales; el contrato no cubre caracoles." % [
				house_name, wedges, flights.size()])
			return
		var by_level := {}
		for flight in flights:
			var foot: Vector3 = flight["foot"]
			var level := int(roundf(foot.y / storey))
			if absf(foot.y - float(level) * storey) > 0.01:
				_fail("%s arranca un tramo a %.2f m, fuera de cota de planta." % [
					house_name, foot.y])
				return
			if not by_level.has(level):
				by_level[level] = []
			(by_level[level] as Array).append(flight)
		for level in range(floors - 1):
			var expected_columns := _stair_columns(stair_volume, shift)
			if level % 2 == 1 and (stair_volume["size"] as Vector2i).x >= 4:
				expected_columns[0] += cell
				expected_columns[1] -= cell
			if not by_level.has(level) or (by_level[level] as Array).size() != 2:
				_fail("%s no tiene DOS tramos en la transición de la planta %d." % [
					house_name, level + 1])
				return
			var pair: Array = by_level[level]
			var got := [float(pair[0]["x"]), float(pair[1]["x"])]
			got.sort()
			if (
				absf(float(got[0]) - float(expected_columns[0])) > 0.02
				or absf(float(got[1]) - float(expected_columns[1])) > 0.02
			):
				_fail("%s no pone los dos tramos de la planta %d en las columnas opuestas del cuerpo (%.2f/%.2f frente a %.2f/%.2f)." % [
					house_name, level + 1, got[0], got[1],
					expected_columns[0], expected_columns[1]])
				return
			# El sentido se invierte en cada transición: es una ida y vuelta, no
			# dos tramos seguidos que obligan a cruzar la planta entera.
			var want := 1.0 if level % 2 == 0 else -1.0
			for flight in pair:
				var sense := signf(float((flight["head"] as Vector3).z) - float((flight["foot"] as Vector3).z))
				if sense != want:
					_fail("%s no invierte el sentido del tramo en la transición de la planta %d." % [
						house_name, level + 1])
					return
		if floors == 3:
			# Y el tramo de vuelta va corrido exactamente una celda: si no, su
			# pie cae en el borde del hueco que abrió el tramo de ida y quien
			# sube se despeña por él. Medido en el taller: la cápsula subía dos
			# de los cuatro tramos de un hall.
			var low := _run_origin(by_level[0])
			var high := _run_origin(by_level[1])
			if absf(high - low - cell) > 0.02:
				_fail("%s no corre una celda el tramo de vuelta: desfase %.2f m, esperado %.2f." % [
					house_name, high - low, cell])
				return
			switchbacks_measured += 1
		for flight in flights:
			var foot: Vector3 = flight["foot"]
			var head: Vector3 = flight["head"]
			var sense := signf(head.z - foot.z)
			# El pie apoya en suelo macizo.
			var approach := Vector3(foot.x, foot.y, foot.z - sense * 0.9)
			if not _floor_under(space, building, approach, foot.y):
				_fail("%s arranca un tramo sobre el hueco del forjado: el pie no apoya en suelo macizo (%s)." % [
					house_name, flight["name"]])
				return
			# El desembarco tiene suelo.
			var landing := Vector3(head.x, head.y, head.z + sense * 0.9)
			if not _floor_under(space, building, landing, head.y):
				_fail("%s desemboca un tramo sobre un hueco sin suelo (%s)." % [
					house_name, flight["name"]])
				return
			# Y el hueco está abierto sobre el tramo: con el forjado macizo la
			# escalera sube contra el techo y la planta alta es inalcanzable por
			# mucho que la escalera exista.
			var mid := foot + (head - foot) * 0.8
			var ceiling := _ray_to_building(
				space,
				building,
				building.to_global(mid + Vector3.UP * 0.30),
				building.to_global(Vector3(mid.x, head.y - 0.02, mid.z))
			)
			if not ceiling.is_empty():
				_fail("%s cierra con forjado el hueco por el que sube su escalera: se subiría contra el techo (%s)." % [
					house_name, flight["name"]])
				return

	# Censo global. Las cifras salen de EXPECTED_* (medidas, arriba) y de la suma
	# de lo que cada receta pide casa por casa: si las dos no coinciden, o alguna
	# casa perdió piezas o el mundo dejó de trazar parcelas.
	if building_count != EXPECTED_HOUSES or medieval.generated_house_count != EXPECTED_HOUSES:
		_fail("Se esperaban %d viviendas; hay %d nodos y el generador cuenta %d." % [
			EXPECTED_HOUSES, building_count, medieval.generated_house_count])
		return
	if robledal_count != EXPECTED_ROBLEDAL_HOUSES or not (robledal_floors.has(3) and robledal_floors.has(4) and robledal_floors.has(5)):
		_fail("Robledal debe conservar %d casas y variantes de 3/4/5 plantas: %d, %s." % [EXPECTED_ROBLEDAL_HOUSES, robledal_count, robledal_floors])
		return
	if medieval.generated_three_storey_count != tall_house_count:
		_fail("El generador no contabiliza correctamente las casas de tres plantas o más.")
		return
	if switchbacks_measured != three_storey_count:
		_fail("Sólo %d de las %d casas de tres plantas han medido el desfase de su ida y vuelta." % [
			switchbacks_measured, three_storey_count])
		return
	if (
		medieval.generated_village_count != EXPECTED_VILLAGES
		or medieval.generated_hamlet_count != EXPECTED_HAMLETS
		or medieval.generated_castle_count != EXPECTED_CASTLES
	):
		_fail("Se esperaban %d villas, %d caseríos y %d castillos; hay %d, %d y %d." % [
			EXPECTED_VILLAGES, EXPECTED_HAMLETS, EXPECTED_CASTLES,
			medieval.generated_village_count, medieval.generated_hamlet_count,
			medieval.generated_castle_count])
		return
	for tally in [
		["tramos de escalera", measured_flights, expected_flights],
		["celdas de forjado", measured_slabs, expected_slabs],
		["hastiales", measured_gables, expected_gables],
		["faldones", measured_roofs, expected_roofs],
		["losas de cimiento", measured_footings, expected_footings],
	]:
		if int(tally[1]) != int(tally[2]):
			_fail("Las %d casas montan %d %s y sus recetas piden %d: alguna ha perdido piezas." % [
				building_count, tally[1], tally[0], tally[2]])
			return
	var complete_castle_count := 0
	for castle in medieval.get_children():
		if castle is StaticBody3D and bool(castle.get_meta("complete_fortress", false)):
			complete_castle_count += 1
			if int(castle.get_meta("open_gate_count", 0)) != 2 or int(castle.get_meta("escape_stair_count", 0)) != 2:
				_fail("%s no tiene sus dos puertas y escaleras de salida." % castle.name)
				return
			if castle.get_node_or_null("StoneFoundation") == null:
				_fail("%s no posee una plataforma física bajo las torres." % castle.name)
				return
			if castle.get_meta("fortress_size", Vector2.ZERO) != Vector2(126.0, 100.0):
				_fail("%s no tiene la escala monumental prevista." % castle.name)
				return
			if int(castle.get_meta("interior_room_count", 0)) < 40 or int(castle.get_meta("interior_floor_count", 0)) != 10:
				_fail("%s carece de estancias interiores o plantas transitables." % castle.name)
				return
			if castle.get_meta("citadel_footprint", Vector2.ZERO) != Vector2(42.0, 24.5) or int(castle.get_meta("citadel_staircase_count", 0)) != 18:
				_fail("%s no contiene la nueva ciudadela monumental con sus dos escaleras." % castle.name)
				return
			if int(castle.get_meta("citadel_guardrail_count", 0)) != 54 or String(castle.get_meta("citadel_stair_layout", "")) != "double_side_switchback":
				_fail("%s no protege los huecos de sus escaleras en zigzag." % castle.name)
				return
			var citadel_guard_collision_count := 0
			var citadel_ramp_collision_count := 0
			var precise_tower_collision_count := 0
			var broad_tower_collision_count := 0
			var castle_access_visual_count := 0
			var castle_access_collision_count := 0
			var citadel_stair_step_count := 0
			var citadel_stair_rail_count := 0
			var citadel_reversed_stair_count := 0
			var observation_parapet_visual_count := 0
			var observation_parapet_collision_count := 0
			for castle_part in castle.get_children():
				if castle_part is CollisionShape3D and castle_part.name.begins_with("CitadelGuard"):
					citadel_guard_collision_count += 1
				elif castle_part is CollisionShape3D and castle_part.name.begins_with("KeepStairRamp"):
					citadel_ramp_collision_count += 1
				elif castle_part is CollisionShape3D and "TowerMeshCollision" in castle_part.name:
					precise_tower_collision_count += 1
				elif castle_part is CollisionShape3D and (
					castle_part.name.begins_with("GatehouseTowerCollision")
					or castle_part.name.begins_with("CornerTowerCollision")
					or castle_part.name.begins_with("CitadelFlankTowerCollision")
					or castle_part.name.begins_with("CitadelCrownTowerCollision")
				):
					broad_tower_collision_count += 1
				elif castle_part is CollisionShape3D and castle_part.name.begins_with("CastleAccessRampCollision"):
					castle_access_collision_count += 1
				elif castle_part is CollisionShape3D and castle_part.name.begins_with("ObservationDeckParapet"):
					observation_parapet_collision_count += 1
				elif castle_part is Node3D and castle_part.name.begins_with("CastleAccessRampVisual"):
					castle_access_visual_count += 1
				elif castle_part is MeshInstance3D and castle_part.name.begins_with("ObservationDeckParapet"):
					observation_parapet_visual_count += 1
				elif castle_part is Node3D and castle_part.name.begins_with("CitadelStairSteps"):
					citadel_stair_step_count += 1
					if absf(absf((castle_part as Node3D).rotation.y) - PI) < 0.01:
						citadel_reversed_stair_count += 1
				elif castle_part is Node3D and castle_part.name.begins_with("CitadelStairRails"):
					citadel_stair_rail_count += 1
			if citadel_guard_collision_count != 54:
				_fail("%s no tiene 54 segmentos físicos de barandilla." % castle.name)
				return
			if citadel_ramp_collision_count != 18 or not bool(castle.get_meta("citadel_stair_transition_is_flush", false)) or String(castle.get_meta("citadel_stair_visual", "")) != "Stair_Interior_Simple":
				_fail("%s no tiene escaleras simples alineadas y rampas continuas en sus 18 tramos." % castle.name)
				return
			if (
				not bool(castle.get_meta("observation_deck_open", false))
				or bool(castle.get_meta("observation_deck_roof", true))
				or int(castle.get_meta("observation_deck_parapet_count", 0)) != 4
				or observation_parapet_visual_count != 4
				or observation_parapet_collision_count != 4
				or castle.get_node_or_null("CrownObservationDeck") == null
			):
				_fail("%s no remata en una torre-mirador abierta con parapeto físico." % castle.name)
				return
			var deck_origin: Vector3 = castle.get_meta("citadel_origin", Vector3.ZERO)
			var deck_storey_height := float(castle.get_meta("citadel_storey_height", 0.0))
			var deck_y := deck_origin.y + 9.0 * deck_storey_height
			var sky_query := PhysicsRayQueryParameters3D.create(
				castle.to_global(Vector3(deck_origin.x, deck_y + 1.8, deck_origin.z)),
				castle.to_global(Vector3(deck_origin.x, deck_y + 14.0, deck_origin.z)),
				1
			)
			var sky_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(sky_query)
			if not sky_hit.is_empty() and sky_hit.get("collider") == castle:
				_fail("%s conserva un techo sobre la torre-mirador." % castle.name)
				return
			if precise_tower_collision_count != 11 or broad_tower_collision_count != 0:
				_fail("%s conserva cajas invisibles en las torres en vez de colisión precisa." % castle.name)
				return
			if castle_access_visual_count != 2 or castle_access_collision_count != 2:
				_fail("%s no tiene dos rampas de entrada continuas y visibles." % castle.name)
				return
			if citadel_stair_step_count != 18 or citadel_stair_rail_count != 18 or citadel_reversed_stair_count != 8:
				_fail("%s no tiene sus 18 escaleras completas alternadas planta a planta." % castle.name)
				return
			if int(castle.get_meta("citadel_zone_count", 0)) != 10 or float(castle.get_meta("citadel_height", 0.0)) < 54.0:
				_fail("%s no tiene sus diez zonas verticales o la altura imponente requerida." % castle.name)
				return
			var citadel_entry_start: Vector3 = castle.to_global(Vector3(0.0, 4.0, 11.0))
			var citadel_entry_end: Vector3 = castle.to_global(Vector3(0.0, 4.0, 0.0))
			var citadel_entry_query := PhysicsRayQueryParameters3D.create(citadel_entry_start, citadel_entry_end, 1)
			var citadel_entry_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(citadel_entry_query)
			if not citadel_entry_hit.is_empty() and citadel_entry_hit.get("collider") == castle:
				_fail("%s tiene bloqueada la entrada ceremonial de la ciudadela." % castle.name)
				return
			var citadel_origin: Vector3 = castle.get_meta("citadel_origin", Vector3.ZERO)
			var storey_height: float = float(castle.get_meta("citadel_storey_height", 0.0))
			var citadel_guard_start: Vector3 = castle.to_global(Vector3(15.75, citadel_origin.y + storey_height + 0.9, citadel_origin.z))
			var citadel_guard_end: Vector3 = castle.to_global(Vector3(13.35, citadel_origin.y + storey_height + 0.9, citadel_origin.z))
			var citadel_guard_query := PhysicsRayQueryParameters3D.create(citadel_guard_start, citadel_guard_end, 1)
			var citadel_guard_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(citadel_guard_query)
			if citadel_guard_hit.is_empty() or citadel_guard_hit.get("collider") != castle:
				_fail("%s no tiene una protección física efectiva junto al primer hueco." % castle.name)
				return
			for passage_node in castle.get_children():
				if not passage_node is Node3D or not passage_node.name.begins_with("CitadelCrossPassage"):
					continue
				var passage := passage_node as Node3D
				var passage_level := roundi((passage.position.y - citadel_origin.y) / storey_height)
				var forbidden_modules: Array[float] = []
				if passage_level > 0:
					forbidden_modules.append(float(medieval.call("_citadel_stair_module", passage_level - 1)))
				if passage_level < 9:
					forbidden_modules.append(float(medieval.call("_citadel_stair_module", passage_level)))
				var passage_module := absf((passage.position.x - citadel_origin.x) / 1.75)
				if forbidden_modules.has(passage_module):
					_fail("%s conserva un arco decorativo bloqueando una escalera de la planta %d." % [castle.name, passage_level + 1])
					return
			for stair_level in range(9):
				var stair_direction := 1.0 if stair_level % 2 == 0 else -1.0
				var stair_module := 9.0 if stair_level % 2 == 0 else 7.0
				if stair_level >= 4:
					stair_module = 3.0 if stair_level % 2 == 0 else 1.0
				var base_y := citadel_origin.y + stair_level * storey_height
				var destination_y := base_y + storey_height
				for stair_side in [-1.0, 1.0]:
					var stair_x: float = float(stair_side) * stair_module * 1.75
					var landing_z := citadel_origin.z - stair_direction * 6.15
					var landing_top: Vector3 = castle.to_global(Vector3(stair_x, destination_y + 0.85, landing_z))
					var landing_bottom: Vector3 = castle.to_global(Vector3(stair_x, destination_y - 0.65, landing_z))
					var landing_query := PhysicsRayQueryParameters3D.create(landing_top, landing_bottom, 1)
					var landing_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(landing_query)
					if landing_hit.is_empty() or landing_hit.get("collider") != castle:
						_fail("La escalera %d de %s desemboca sobre un hueco sin suelo." % [stair_level + 1, castle.name])
						return
					var bridge_z := citadel_origin.z - stair_direction * 5.02
					var bridge_top: Vector3 = castle.to_global(Vector3(stair_x, destination_y + 0.65, bridge_z))
					var bridge_bottom: Vector3 = castle.to_global(Vector3(stair_x, destination_y - 0.45, bridge_z))
					var bridge_query := PhysicsRayQueryParameters3D.create(bridge_top, bridge_bottom, 1)
					var bridge_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(bridge_query)
					if bridge_hit.is_empty() or bridge_hit.get("collider") != castle:
						_fail("La escalera %d de %s carece de base bajo el último peldaño." % [stair_level + 1, castle.name])
						return
					var entry_z := citadel_origin.z + stair_direction * 6.20
					var entry_top: Vector3 = castle.to_global(Vector3(stair_x, base_y + 0.85, entry_z))
					var entry_bottom: Vector3 = castle.to_global(Vector3(stair_x, base_y - 0.45, entry_z))
					var entry_query := PhysicsRayQueryParameters3D.create(entry_top, entry_bottom, 1)
					var entry_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(entry_query)
					if entry_hit.is_empty() or entry_hit.get("collider") != castle:
						_fail("La escalera %d de %s empieza sobre un hueco y obliga a saltar." % [stair_level + 1, castle.name])
						return
					var exit_start: Vector3 = castle.to_global(Vector3(stair_x, destination_y + 0.82, citadel_origin.z - stair_direction * 4.45))
					var exit_end: Vector3 = castle.to_global(Vector3(stair_x, destination_y + 0.82, landing_z))
					var exit_query := PhysicsRayQueryParameters3D.create(exit_start, exit_end, 1)
					var exit_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(exit_query)
					if not exit_hit.is_empty() and exit_hit.get("collider") == castle:
						_fail("La barandilla bloquea la salida de la escalera %d de %s." % [stair_level + 1, castle.name])
						return
					var head_start: Vector3 = castle.to_global(Vector3(stair_x, base_y + 2.05, citadel_origin.z + stair_direction * 4.55))
					var head_end: Vector3 = castle.to_global(Vector3(stair_x, destination_y + 2.05, citadel_origin.z - stair_direction * 4.55))
					var head_query := PhysicsRayQueryParameters3D.create(head_start, head_end, 1)
					var head_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(head_query)
					if not head_hit.is_empty() and head_hit.get("collider") == castle:
						_fail("La escalera %d de %s está bloqueada o no deja altura libre." % [stair_level + 1, castle.name])
						return
			for floor_level in range(1, 10):
				var floor_y := citadel_origin.y + floor_level * storey_height
				var floor_start: Vector3 = castle.to_global(Vector3(0.0, floor_y + 1.0, -14.0))
				var floor_end: Vector3 = castle.to_global(Vector3(0.0, floor_y - 0.6, -14.0))
				var floor_query := PhysicsRayQueryParameters3D.create(floor_start, floor_end, 1)
				var floor_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(floor_query)
				if floor_hit.is_empty() or floor_hit.get("collider") != castle:
					_fail("%s no tiene forjado físico en su planta %d." % [castle.name, floor_level + 1])
					return
			if String(castle.get_meta("modular_pack", "")) != "Modular Medieval Buildings - Jul 2017":
				_fail("%s no usa el nuevo pack modular de Quaternius." % castle.name)
				return
			for gate_z in [-55.0, 55.0]:
				var gate_start: Vector3 = castle.to_global(Vector3(0.0, 4.0, gate_z))
				var gate_end: Vector3 = castle.to_global(Vector3(0.0, 4.0, gate_z * 0.55))
				var gate_query := PhysicsRayQueryParameters3D.create(gate_start, gate_end, 1)
				var gate_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(gate_query)
				if not gate_hit.is_empty() and gate_hit.get("collider") == castle:
					_fail("%s tiene una colisión invisible cerrando una de sus puertas en %s (shape %s)." % [castle.name, gate_hit.get("position"), gate_hit.get("shape")])
					return
	if complete_castle_count != 3 or medieval.generated_castle_keep_count != 3 or medieval.generated_castle_gate_count != 6 or medieval.generated_escape_stair_count != 6:
		_fail("Los tres castillos deben ser fortalezas completas con torre del homenaje y dos salidas.")
		return

	print("ISLAND WORLD TEST OK: HUD N/B/0, %d casas del generador nuevo (%d de tres plantas) con %d tramos de ida y vuelta, %d celdas de forjado, %d hastiales y %d castillos modulares monumentales." % [
		building_count, three_storey_count, measured_flights, measured_slabs, measured_gables,
		medieval.generated_castle_count])
	quit(0)


func _recipe_named(display_name: String, floors: int) -> Dictionary:
	## La receta que dice ser esa casa, reparametrizada a sus plantas. Con ella la
	## prueba deriva alero, losas, forjados, hastiales y columnas de escalera en
	## vez de arrastrar constantes.
	for recipe in [
		BuildingRecipes.cottage(floors),
		BuildingRecipes.merchant_house(floors),
		BuildingRecipes.tavern(floors),
	]:
		if String(recipe["display_name"]) == display_name:
			return recipe
	return {}


func _cell_box(volumes: Array) -> Rect2:
	## Huella del edificio en CELDAS: la unión de los cuerpos.
	var box := Rect2()
	var first := true
	for volume in volumes:
		var origin: Vector2i = volume["origin"]
		var size: Vector2i = volume["size"]
		var rect := Rect2(Vector2(origin), Vector2(size))
		box = rect if first else box.merge(rect)
		first = false
	return box


func _centre_offset(volumes: Array) -> Vector3:
	## Lo mismo que hace el generador para centrar la casa en su parcela.
	var box := _cell_box(volumes)
	var centre := box.position + box.size * 0.5
	return Vector3(
		-centre.x * float(BuildingSolver.CELL), 0.0, -centre.y * float(BuildingSolver.CELL))


func _eave_height(volumes: Array) -> float:
	## Cota del alero más alto: por encima de esto no puede haber ni una colisión,
	## porque el tejado no se pisa.
	var top := 0.0
	for volume in volumes:
		var base_level := int(volume.get("base_level", 0))
		top = maxf(top, float(base_level + int(volume["floors"])) * float(BuildingSolver.STOREY))
	return top


func _stair_volume(volumes: Array) -> Dictionary:
	for volume in volumes:
		if bool(volume.get("stairs", false)):
			return volume
	return {}


func _stair_columns(volume: Dictionary, shift: Vector3) -> Array:
	## Las dos columnas EXTREMAS del cuerpo, que es donde caen los dos tramos de
	## cada transición. Antes había un solo tramo y se cruzaba la planta entera.
	var origin: Vector2i = volume["origin"]
	var size: Vector2i = volume["size"]
	var cell := float(BuildingSolver.CELL)
	var near := (float(origin.x) + 0.5) * cell + shift.x
	var far := (float(origin.x + size.x - 1) + 0.5) * cell + shift.x
	return [minf(near, far), maxf(near, far)]


func _expected_footings(volumes: Array) -> int:
	## Una losa por cuerpo apoyado en tierra.
	var count := 0
	for volume in volumes:
		if int(volume.get("base_level", 0)) == 0:
			count += 1
	return count


func _expected_roofs(volumes: Array) -> int:
	var count := 0
	for volume in volumes:
		if not String(volume.get("roof", "")).is_empty():
			count += 1
	return count


func _expected_gables(volumes: Array) -> int:
	## Dos hastiales por faldón con frontón: uno a cada testero. Sin ellos se ve
	## el hueco del bajo cubierta desde fuera y la casa parece a medio construir.
	var count := 0
	for volume in volumes:
		if not String(volume.get("roof_front", "")).is_empty():
			count += 2
	return count


func _expected_slabs(volumes: Array) -> int:
	## Celdas de forjado que toca haber: todas las de cada planta alta menos las
	## que el tramo de escalera necesita libres. Una losa maciza de planta entera
	## deja la escalera subiendo contra el techo, y entonces la planta alta es
	## inalcanzable por mucho que la escalera exista.
	var holes_per_flight := int(BuildingSolver.STAIR_RUN_CELLS) - 1
	var count := 0
	for volume in volumes:
		var size: Vector2i = volume["size"]
		var transitions := maxi(int(volume["floors"]) - 1, 0)
		count += transitions * size.x * size.y
		if bool(volume.get("stairs", false)):
			count -= transitions * holes_per_flight * 2
	return count


func _census(node: Node) -> Dictionary:
	## Cuántas piezas de cada familia cuelgan del nodo, por su nombre sin el
	## número de serie. Los nombres son los del generador nuevo: Muro, Jamba,
	## Dintel, Forjado, Escalera, Caracol, Cimiento.
	var counts := {}
	for child in node.get_children():
		var family := child.name.rstrip("0123456789")
		counts[family] = int(counts.get(family, 0)) + 1
	return counts


func _count_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child in node.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


func _shapes(node: Node) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if node is CollisionShape3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_shapes(child))
	return out


func _shape_top(shape: CollisionShape3D) -> float:
	if shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size.y * 0.5
	if shape.shape is ConvexPolygonShape3D:
		var high := -INF
		for point in (shape.shape as ConvexPolygonShape3D).points:
			high = maxf(high, point.y)
		return high
	return 0.0


func _flights(body: StaticBody3D) -> Array:
	## Pie y meseta de cada tramo recto, leídos de la propia cuña. La cuña tiene
	## dos planos de z —arranque y llegada— y en cada uno la esquina alta es la
	## cara pisable; el eje x del nodo es la columna por la que sube.
	var out: Array = []
	for shape in _shapes(body):
		if not shape.name.begins_with("Escalera"):
			continue
		if not shape.shape is ConvexPolygonShape3D:
			continue
		var points: PackedVector3Array = (shape.shape as ConvexPolygonShape3D).points
		var surface := {}
		for point in points:
			var key := snappedf(point.z, 0.001)
			surface[key] = maxf(float(surface.get(key, -INF)), point.y)
		if surface.size() != 2:
			# Una cuña que no corre a lo largo de z es un caracol de torre y este
			# contrato no lo cubre: se deja fuera para que el recuento no cuadre
			# y la prueba lo diga, en vez de darlo por bueno en silencio.
			continue
		var keys: Array = surface.keys()
		var first := Vector3(0.0, float(surface[keys[0]]), float(keys[0]))
		var second := Vector3(0.0, float(surface[keys[1]]), float(keys[1]))
		var low: Vector3 = first if first.y < second.y else second
		var high: Vector3 = second if first.y < second.y else first
		var origin := body.to_local(shape.global_position)
		out.append({
			"name": shape.name,
			"x": origin.x,
			"foot": Vector3(origin.x, origin.y + low.y, origin.z + low.z),
			"head": Vector3(origin.x, origin.y + high.y, origin.z + high.z),
		})
	return out


func _run_origin(pair: Array) -> float:
	## El borde de menor z que ocupan los dos tramos de una transición. Entre una
	## transición y la siguiente tiene que moverse exactamente una celda.
	var lowest := INF
	for flight in pair:
		var foot: Vector3 = flight["foot"]
		var head: Vector3 = flight["head"]
		lowest = minf(lowest, minf(foot.z, head.z))
	return lowest


func _ray_to_building(
	space: PhysicsDirectSpaceState3D,
	building: StaticBody3D,
	from_global: Vector3,
	to_global: Vector3
) -> Dictionary:
	## Primer impacto del rayo CONTRA ESTA CASA, saltándose lo que haya de otros
	## cuerpos por el camino.
	##
	## Hace falta porque en terreno llano la losa de la casa y el suelo del mundo
	## quedan exactamente a la misma cota, y el rayo devuelve una u otro según le
	## parece: la misma comprobación pasaba en la Casa del Río y fallaba en la
	## Posada de al lado. Descartar el cuerpo ajeno y repetir mantiene la
	## exigencia estricta —tiene que ser suelo DE LA CASA— sin depender del
	## desempate.
	var query := PhysicsRayQueryParameters3D.create(from_global, to_global, 1)
	var excluded: Array[RID] = []
	for _attempt in 4:
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return {}
		if hit.get("collider") == building:
			return hit
		excluded.append(hit["rid"])
	return {}


func _floor_under(
	space: PhysicsDirectSpaceState3D,
	building: StaticBody3D,
	point: Vector3,
	expected_y: float
) -> bool:
	## ¿Hay suelo físico de la casa justo bajo ese punto, y a la cota que toca?
	## Sirve para el pie del tramo, para el desembarco y para cada planta alta.
	var hit := _ray_to_building(
		space,
		building,
		building.to_global(point + Vector3.UP * 0.45),
		building.to_global(point + Vector3.DOWN * 0.55)
	)
	if hit.is_empty():
		return false
	var local: Vector3 = building.to_local(hit["position"])
	return absf(local.y - expected_y) <= 0.30


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
