extends SceneTree

## Verifica la escala insular, el mapa interactivo y que las viviendas grandes
## sean cuerpos modulares con suelo, paredes físicas y una entrada atravesable.

const FLOOR_LEVEL_FOR_TEST := 0.35


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
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
	if (
		cliff_barrier == null
		or int(world.get("coastal_cliff_barrier_segment_count")) < 12
		or not bool(cliff_barrier.get_meta("coastal_only", false))
		or float(cliff_barrier.get_meta("slope_threshold_degrees", 0.0)) < 48.0
		or float(cliff_barrier.get_meta("jump_proof_height", 0.0)) < 4.5
		or int(cliff_barrier.get_meta("terrain_texture_id", -1)) != 6
	):
		_fail("Las cornisas costeras peligrosas no tienen una barrera física selectiva.")
		return
	var cliff_collider_count := 0
	for barrier_part in cliff_barrier.get_children():
		if barrier_part is MeshInstance3D:
			_fail("La barrera de las cornisas debe ser invisible.")
			return
		if not barrier_part is CollisionShape3D:
			continue
		cliff_collider_count += 1
		var cliff_shape := (barrier_part as CollisionShape3D).shape as BoxShape3D
		if cliff_shape == null or cliff_shape.size.y < 4.5 or cliff_shape.size.z < 2.5:
			_fail("Un tramo del acantilado no bloquea físicamente un salto por la cornisa.")
			return
	if cliff_collider_count != int(world.get("coastal_cliff_barrier_segment_count")) or cliff_barrier.collision_layer != 1:
		_fail("El contador de protección no coincide con los colliders físicos del acantilado.")
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

	var medieval := world.get_node("MedievalSetDressing") as MedievalSetDressing
	var building_count := 0
	var doorway_checked := false
	var upper_floor_checked := false
	var house_guardrail_checked := false
	var three_storey_count := 0
	for child in medieval.get_children():
		if not child is StaticBody3D:
			continue
		if "House" not in child.name and "Hall" not in child.name:
			continue
		var building := child as StaticBody3D
		building_count += 1
		var foundation := building.get_node_or_null("StoneFoundation") as MeshInstance3D
		var doorway := building.get_node_or_null("Doorway") as Node3D
		var interior := building.get_node_or_null("InteriorPoint") as Node3D
		var collision_count := 0
		var upper_floor_collision_count := 0
		var stair_ramp_count := 0
		var stair_step_count := 0
		var stair_rail_count := 0
		var stair_guard_collision_count := 0
		var stair_guard_visual_count := 0
		var reversed_stair_count := 0
		var upper_floor_tile_count := 0
		for part in child.get_children():
			if part is CollisionShape3D:
				collision_count += 1
				if part.name.begins_with("UpperFloorCollision"):
					upper_floor_collision_count += 1
				elif part.name.begins_with("StairRampCollision"):
					stair_ramp_count += 1
					var ramp := part as CollisionShape3D
					if not ramp.shape is ConvexPolygonShape3D or (ramp.shape as ConvexPolygonShape3D).points.size() != 8:
						_fail("La escalera de %s no tiene una cuña transitable ajustada a ambos pisos." % child.name)
						return
				elif part.name.begins_with("HouseGuard"):
					stair_guard_collision_count += 1
			elif part is Node3D:
				var part_3d := part as Node3D
				if part.name.begins_with("InteriorStairSteps"):
					stair_step_count += 1
					if absf(absf(part_3d.rotation.y) - PI) < 0.01:
						reversed_stair_count += 1
				elif part.name.begins_with("InteriorStairRails"):
					stair_rail_count += 1
				elif part.name.begins_with("UpperFloorL"):
					upper_floor_tile_count += 1
				elif part.name.begins_with("HouseGuard"):
					stair_guard_visual_count += 1
				if absf(part_3d.rotation.x) > 0.001 or absf(part_3d.rotation.z) > 0.001:
					_fail("Una pieza de %s está inclinada fuera de la cuadrícula modular." % child.name)
					return
		var footprint: Vector2 = building.get_meta("footprint", Vector2.ZERO)
		var floor_count := int(building.get_meta("floor_count", 0))
		if foundation == null or collision_count < 40 or doorway == null or interior == null:
			_fail("%s no tiene suelo, paredes físicas y entrada interior completas." % child.name)
			return
		if not bool(building.get_meta("enterable", false)) or footprint.x < 12.0 or footprint.y < 21.0:
			_fail("%s no conserva la nueva escala habitable mínima de 12 x 21 metros." % child.name)
			return
		var expected_upper_levels := floor_count - 1
		if (
			float(building.get_meta("storey_clearance", 0.0)) < 4.75
			or int(building.get_meta("upper_floor_count", -1)) != expected_upper_levels
			or int(building.get_meta("stair_count", -1)) != expected_upper_levels
			or not bool(building.get_meta("stairs_traversable", false))
			or upper_floor_collision_count != expected_upper_levels * 3
			or stair_ramp_count != expected_upper_levels
			or stair_step_count != expected_upper_levels
			or stair_rail_count != expected_upper_levels
			or stair_guard_collision_count != expected_upper_levels * 3
			or stair_guard_visual_count != expected_upper_levels * 3
			or upper_floor_tile_count != expected_upper_levels * 25
			or int(building.get_meta("stair_guardrails_per_floor", 0)) != 3
			or String(building.get_meta("stair_layout", "")) != "alternating_side_switchback"
			or float(building.get_meta("stair_column_spacing", 0.0)) < 9.0
			or not bool(building.get_meta("stair_transition_is_flush", false))
			or String(building.get_meta("stair_visual", "")) != "Stair_Interior_Simple"
		):
			_fail("%s no tiene suelos y escaleras completos en cada planta." % child.name)
			return
		if floor_count == 3:
			three_storey_count += 1
			if reversed_stair_count != 1:
				_fail("%s apila sus dos tramos en la misma dirección." % child.name)
				return
		elif floor_count != 2:
			_fail("%s no tiene dos o tres pisos declarados." % child.name)
			return
		var threshold_point := building.to_global(Vector3(-1.0, 0.34, 7.65))
		var terrain_height := terrain.data.get_height(threshold_point)
		if is_nan(terrain_height) or absf(threshold_point.y - terrain_height) > 0.08 or float(building.get_meta("threshold_height", 1.0)) > 0.01:
			_fail("El umbral de %s no está a ras del terreno." % child.name)
			return
		if not doorway_checked:
			var outside: Vector3 = building.to_global(Vector3(-1.0, 1.7, 8.6))
			var inside: Vector3 = building.to_global(Vector3(-1.0, 1.7, 4.8))
			var query := PhysicsRayQueryParameters3D.create(outside, inside, 1)
			var obstruction: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			if not obstruction.is_empty():
				_fail("La puerta de %s sigue bloqueada por una colisión invisible." % child.name)
				return
			doorway_checked = true
		if not upper_floor_checked:
			var floor_above := building.to_global(Vector3(0.0, 4.15, 0.0))
			var floor_below := building.to_global(Vector3(0.0, 2.75, 0.0))
			var floor_query := PhysicsRayQueryParameters3D.create(floor_above, floor_below, 1)
			var floor_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(floor_query)
			if floor_hit.is_empty() or floor_hit.get("collider") != building:
				_fail("La primera planta de %s no tiene un suelo físico transitable." % child.name)
				return
			upper_floor_checked = true
		if not house_guardrail_checked:
			var guard_start := building.to_global(Vector3(3.0, 4.17, 0.0))
			var guard_end := building.to_global(Vector3(1.55, 4.17, 0.0))
			var guard_query := PhysicsRayQueryParameters3D.create(guard_start, guard_end, 1)
			var guard_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(guard_query)
			if guard_hit.is_empty() or guard_hit.get("collider") != building:
				_fail("El hueco de escalera de %s no tiene protección lateral física." % child.name)
				return
			house_guardrail_checked = true
		# Cada tramo debe terminar en suelo firme, tener abierta la salida y dejar
		# altura libre para la cápsula del personaje. Se comprueban todas las casas,
		# no solo la primera vivienda generada.
		for stair_level in range(expected_upper_levels):
			var stair_direction := 1.0 if stair_level % 2 == 0 else -1.0
			var base_y := FLOOR_LEVEL_FOR_TEST + stair_level * 3.1
			var destination_y := FLOOR_LEVEL_FOR_TEST + (stair_level + 1) * 3.1
			var stair_x := 3.0 if stair_level % 2 == 0 else -3.0
			var landing_z := -stair_direction * 3.72
			var landing_top := building.to_global(Vector3(stair_x, destination_y + 0.75, landing_z))
			var landing_bottom := building.to_global(Vector3(stair_x, destination_y - 0.55, landing_z))
			var landing_query := PhysicsRayQueryParameters3D.create(landing_top, landing_bottom, 1)
			var landing_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(landing_query)
			if landing_hit.is_empty() or landing_hit.get("collider") != building:
				_fail("La escalera %d de %s desemboca sobre un hueco sin suelo." % [stair_level + 1, child.name])
				return
			var bridge_z := -stair_direction * 2.72
			var bridge_top := building.to_global(Vector3(stair_x, destination_y + 0.55, bridge_z))
			var bridge_bottom := building.to_global(Vector3(stair_x, destination_y - 0.35, bridge_z))
			var bridge_query := PhysicsRayQueryParameters3D.create(bridge_top, bridge_bottom, 1)
			var bridge_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(bridge_query)
			if bridge_hit.is_empty() or bridge_hit.get("collider") != building:
				_fail("La escalera %d de %s no tiene una base física bajo el último peldaño." % [stair_level + 1, child.name])
				return
			var entry_z := stair_direction * 3.85
			var entry_top := building.to_global(Vector3(stair_x, base_y + 0.65, entry_z))
			var entry_bottom := building.to_global(Vector3(stair_x, base_y - 0.30, entry_z))
			var entry_query := PhysicsRayQueryParameters3D.create(entry_top, entry_bottom, 1)
			var entry_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(entry_query)
			if entry_hit.is_empty() or entry_hit.get("collider") != building:
				_fail("La escalera %d de %s empieza sobre un hueco y obliga a saltar." % [stair_level + 1, child.name])
				return
			var exit_start := building.to_global(Vector3(stair_x, destination_y + 0.72, -stair_direction * 2.50))
			var exit_end := building.to_global(Vector3(stair_x, destination_y + 0.72, landing_z))
			var exit_query := PhysicsRayQueryParameters3D.create(exit_start, exit_end, 1)
			var exit_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(exit_query)
			if not exit_hit.is_empty() and exit_hit.get("collider") == building:
				_fail("La barandilla bloquea el desembarco de la escalera %d de %s." % [stair_level + 1, child.name])
				return
			var head_start := building.to_global(Vector3(stair_x, base_y + 1.30, stair_direction * 2.60))
			var head_end := building.to_global(Vector3(stair_x, base_y + 3.1 + 1.30, -stair_direction * 2.60))
			var head_query := PhysicsRayQueryParameters3D.create(head_start, head_end, 1)
			var head_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(head_query)
			if not head_hit.is_empty() and head_hit.get("collider") == building:
				_fail("La escalera %d de %s no deja altura libre para subir." % [stair_level + 1, child.name])
				return
	if building_count != 54 or medieval.generated_castle_count != 3:
		_fail("Se esperaban 54 edificios correctos y 3 castillos; hay %d y %d." % [building_count, medieval.generated_castle_count])
		return

	if medieval.generated_enterable_house_count != 54 or medieval.generated_hamlet_count != 8 or not doorway_checked:
		_fail("Las cincuenta y cuatro viviendas de villas y caseríos deben ser accesibles.")
		return
	if three_storey_count != 10 or medieval.generated_roof_facade_count != 108:
		_fail("Deben existir diez edificios de tres pisos y 108 hastiales cerrados.")
		return
	if medieval.generated_upper_floor_count != 64 or medieval.generated_stair_count != 64 or not upper_floor_checked:
		_fail("Las 54 casas deben sumar 64 plantas superiores y 64 escaleras transitables.")
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

	print("ISLAND WORLD TEST OK: HUD N/B/0, 54 casas, 64 escaleras completas y 3 castillos modulares monumentales.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
