extends SceneTree

const TEST_EXPLORATION_SAVE := "user://adventure_system_exploration_test.json"
var _inventory: Node
var _exploration: Node


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_cleanup()
	_inventory = root.get_node("InventoryManager")
	_exploration = root.get_node("ExplorationManager")
	_inventory.autosave_enabled = false
	_inventory.call("reset_inventory_for_tests", false)
	var catalog: Array = _inventory.call("get_catalog")
	if catalog.size() < 100:
		_fail("No se incorporó el catálogo completo del Ultimate RPG Items Pack.")
		return
	var shield_count := 0
	for item_value in catalog:
		var item := item_value as Dictionary
		if String(item.category) == "shield":
			shield_count += 1
			if String(item.source) != "medieval":
				_fail("Se incorporó un escudo fuera del Medieval Weapons Pack.")
				return
	if shield_count != 5:
		_fail("No están disponibles exactamente los cinco escudos medievales permitidos.")
		return
	if _inventory.call("get_quick_slot_item", 1) != "Sword" or _inventory.call("get_quick_slot_item", 2) != "Axe_small" or _inventory.call("get_quick_slot_item", 3) != "Bow_Wooden" or _inventory.call("get_quick_slot_item", 4) != "Torch":
		_fail("Los huecos rápidos no son espada, hacha, arco y antorcha.")
		return
	if (_inventory.call("get_item_definition", "Compass_Open") as Dictionary).size() > 0:
		_fail("La brújula antigua sigue formando parte del inventario de aventura.")
		return

	var original_exploration_path := String(_exploration.get("save_path"))
	_exploration.set("save_path", TEST_EXPLORATION_SAVE)
	_exploration.call("clear_progress", false)
	var scene := load("res://scenes/world.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	for _frame in 8:
		await process_frame
	var system := world.get_node_or_null("AdventureSystem")
	var player := world.get_node_or_null("Player")
	if system == null or player == null:
		_fail("El mundo no contiene AdventureSystem y Player.")
		return
	if int(system.get("generated_chest_count")) < 20 or int(system.get("generated_tree_count")) < 12 or int(system.get("generated_rock_count")) < 18 or int(system.get("generated_animal_count")) < 15 or int(system.get("generated_relic_count")) < 10:
		_fail("Los 200 retos no materializaron suficientes cofres, recursos, animales y reliquias.")
		return

	var chest := _first_resource(world, "chest")
	var animal := _first_resource(world, "animal")
	var relic := _first_resource(world, "relic")
	var tree := _first_resource(world, "tree")
	var rock := _first_resource(world, "rock")
	if chest == null or animal == null or relic == null or tree == null or rock == null:
		_fail("Falta al menos una familia de objetos interactivos.")
		return
	if not bool(chest.call("interact", player)) or not bool(_exploration.call("is_discovered", String(chest.get("zone_id")))):
		_fail("Abrir un cofre no completó su reto ni generó recompensa.")
		return
	if system.get_tree().get_nodes_in_group("adventure_pickup").size() < 3:
		_fail("El cofre no expulsó flechas y tesoros recogibles.")
		return
	if not bool(animal.call("interact", player)) or not bool(_exploration.call("is_discovered", String(animal.get("zone_id")))):
		_fail("Descubrir un animal no actualizó el bestiario/progreso.")
		return
	var relic_item: String = String(relic.get("reward_item_id"))
	var relic_before := int(_inventory.call("get_count", relic_item))
	if not bool(relic.call("interact", player)) or int(_inventory.call("get_count", relic_item)) != relic_before + 1 or not bool(_exploration.call("is_discovered", String(relic.get("zone_id")))):
		_fail("Recoger una reliquia no la incorporó al inventario.")
		return

	var tree_health: int = int(tree.get("health"))
	tree.call("receive_tool_hit", "sword", "Sword", tree.global_position, player)
	if int(tree.get("health")) != tree_health:
		_fail("La espada pudo talar un árbol reservado al hacha.")
		return
	for _hit in 3:
		tree.call("receive_tool_hit", "axe", "Axe_small", tree.global_position, player)
	await create_timer(0.82).timeout
	await process_frame
	var log_pickup := _pickup_for_zone(world, String(tree.get("zone_id")))
	if log_pickup == null:
		_fail("El árbol talado no se convirtió en un tronco recogible.")
		return
	var logs_before := int(_inventory.call("get_count", "WoodLog"))
	log_pickup.call("_on_body_entered", player)
	await process_frame
	if int(_inventory.call("get_count", "WoodLog")) != logs_before + 1 or not bool(_exploration.call("is_discovered", String(tree.get("zone_id")))):
		_fail("Pasar sobre el tronco no lo recogió ni completó la tala.")
		return

	for _hit in 3:
		rock.call("receive_tool_hit", "axe", "Axe_small", rock.global_position, player)
	await create_timer(0.38).timeout
	await process_frame
	var ruby_pickup := _pickup_for_zone(world, String(rock.get("zone_id")))
	if ruby_pickup == null:
		_fail("La veta rota no dejó rubíes recogibles.")
		return
	var ruby_id := String(ruby_pickup.get("item_id"))
	var rubies_before := int(_inventory.call("get_count", ruby_id))
	ruby_pickup.call("_on_body_entered", player)
	await process_frame
	if int(_inventory.call("get_count", ruby_id)) <= rubies_before or not bool(_exploration.call("is_discovered", String(rock.get("zone_id")))):
		_fail("Los rubíes no entraron en el inventario al pasar sobre ellos.")
		return

	_inventory.call("add_item", "Sword_Golden", 1, false)
	if _inventory.call("get_equipped_item", "sword") != "Sword_Golden" or not bool(player.call("equip_item", 1)) or player.call("get_equipped_item_id") != "Sword_Golden":
		_fail("Una espada conseguida no sustituyó a la espada actual del personaje.")
		return
	_inventory.call("add_item", "Axe_small_Golden", 1, false)
	if _inventory.call("get_equipped_item", "axe") != "Axe_small_Golden" or not bool(player.call("equip_item", 2)) or player.call("get_equipped_item_id") != "Axe_small_Golden":
		_fail("Un hacha conseguida no sustituyó al hacha actual.")
		return
	_inventory.call("add_item", "Shield_Round", 1, false)
	await process_frame
	var shield_mesh := player.get("_shield_mesh") as MeshInstance3D
	if shield_mesh == null or not bool(shield_mesh.get_meta("medieval_shield_only", false)):
		_fail("El escudo medieval conseguido no apareció en la mano izquierda.")
		return

	if not bool(player.call("equip_item", 3)):
		_fail("La tecla 3 no puede equipar el arco.")
		return
	var arrows_before := int(_inventory.call("get_arrow_count"))
	if not player.call("_begin_bow_draw"):
		_fail("No se pudo comenzar a tensar el arco teniendo flechas.")
		return
	player.set("_bow_draw_time", 0.92)
	player.set("_bow_draw_strength", 0.88)
	player.call("_update_bow_pose", 0.0)
	for _frame in 3:
		await process_frame
	var nocked_arrow := world.find_child("NockedArrow", true, false)
	var bow_strings := player.get("_bow_string_segments") as Array
	var string_target := player.get("_bow_right_target") as Marker3D
	if nocked_arrow == null or nocked_arrow.get_node_or_null("ReadableShaft") == null:
		_fail("La flecha no aparece encajada mientras se tensa el arco.")
		return
	if bow_strings.size() != 2 or string_target == null or string_target.position.y < 1.70:
		_fail("La cuerda dinámica no acompaña la mano hasta la mejilla durante el tensado.")
		return
	var released_strength := float(player.call("get_bow_draw_strength"))
	if not player.call("_release_bow_arrow") or int(_inventory.call("get_arrow_count")) != arrows_before - 1:
		_fail("Soltar el arco no disparó ni consumió exactamente una flecha.")
		return
	await process_frame
	var projectile := world.find_child("ArrowProjectile", true, false)
	if projectile == null:
		_fail("El disparo no creó el proyectil físico de flecha.")
		return
	var flight_trail := projectile.get_node_or_null("FlightTrail") as GPUParticles3D
	if projectile.get_node_or_null("ReadableShaft") == null or flight_trail == null or not flight_trail.emitting:
		_fail("La flecha no tiene una silueta legible y una estela de vuelo visible.")
		return
	if absf(float(projectile.get("draw_strength")) - released_strength) > 0.01 or (projectile.get("velocity") as Vector3).length() < 65.0:
		_fail("La velocidad/estela de la flecha no dependen de la fuerza de tensado.")
		return
	if player.get("_bow_string_segments").size() != 0:
		_fail("La cuerda tensada no desapareció limpiamente al soltar la flecha.")
		return

	var hud := world.get_node("HUD")
	var inventory_overlay := hud.get_node_or_null("InventoryOverlay")
	if (
		inventory_overlay == null
		or inventory_overlay.find_child("InventoryGrid", true, false) == null
		or hud.get_node_or_null("AdventureQuickbar") == null
		or hud.find_child("CallHorseButton", true, false) == null
	):
		_fail("Faltan la cuadrícula de inventario, la botonera visual o la llamada del caballo.")
		return
	world.get_node("AmbientAudio").call("_exit_tree")
	world.queue_free()
	_exploration.set("save_path", original_exploration_path)
	_inventory.autosave_enabled = true
	_cleanup()
	for _frame in 4:
		await process_frame
	print("ADVENTURE SYSTEM TEST OK: 200 retos, inventario RPG, cofres, fauna, tala, minería, armas, escudos y arco operativos.")
	quit(0)


func _first_resource(world: Node, kind: String) -> Node:
	for node in world.get_tree().get_nodes_in_group("adventure_interactable"):
		var resource := node as Node
		if resource != null and String(resource.get("kind")) == kind:
			return resource
	return null


func _pickup_for_zone(world: Node, zone_id: String) -> Node:
	for node in world.get_tree().get_nodes_in_group("adventure_pickup"):
		var pickup := node as Node
		if pickup != null and String(pickup.get("zone_id")) == zone_id:
			return pickup
	return null


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = TEST_EXPLORATION_SAVE + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	if _inventory != null:
		_inventory.autosave_enabled = true
	paused = false
	_cleanup()
	push_error(message)
	quit(1)
