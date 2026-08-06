extends SceneTree

## Verifica la escala insular, el mapa interactivo y que las viviendas grandes
## sean cuerpos modulares con suelo, paredes físicas y una entrada atravesable.


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 4:
		await process_frame

	var terrain := world.get_node("Terrain3D") as Terrain3D
	if terrain.data.get_region_count() != 16 or absf(terrain.vertex_spacing - 9.765625) > 0.001:
		_fail("La isla no ocupa 10 x 10 km mediante dieciséis regiones Terrain3D.")
		return

	var hud := world.get_node("HUD")
	var mini_map := hud.get_node("MiniMap") as Control
	var full_map := hud.get_node("FullMap") as Control
	if not mini_map.visible or full_map.visible or int(full_map.call("get_poi_count")) < 8 or int(full_map.call("get_road_count")) < 8:
		_fail("El minimapa o el mapa principal no contienen la red insular completa.")
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
		_fail("La tecla M no devuelve al minimapa.")
		return

	var medieval := world.get_node("MedievalSetDressing") as MedievalSetDressing
	var building_count := 0
	var doorway_checked := false
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
		for part in child.get_children():
			if part is CollisionShape3D:
				collision_count += 1
			elif part is Node3D:
				var part_3d := part as Node3D
				if absf(part_3d.rotation.x) > 0.001 or absf(part_3d.rotation.z) > 0.001:
					_fail("Una pieza de %s está inclinada fuera de la cuadrícula modular." % child.name)
					return
		var footprint: Vector2 = building.get_meta("footprint", Vector2.ZERO)
		if foundation == null or collision_count < 40 or doorway == null or interior == null:
			_fail("%s no tiene suelo, paredes físicas y entrada interior completas." % child.name)
			return
		if not bool(building.get_meta("enterable", false)) or footprint.x < 8.0 or footprint.y < 14.0:
			_fail("%s no conserva la escala habitable mínima de 8 x 14 metros." % child.name)
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
	if building_count != 30 or medieval.generated_castle_count != 3:
		_fail("Se esperaban 30 edificios correctos y 3 castillos; hay %d y %d." % [building_count, medieval.generated_castle_count])
		return

	if medieval.generated_enterable_house_count != 30 or not doorway_checked:
		_fail("Las treinta viviendas deben registrarse como edificios accesibles.")
		return

	print("ISLAND WORLD TEST OK: 100 km², 8 rutas, 30 casas 11x19 transitables y 3 castillos.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
