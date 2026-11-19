extends SceneTree


func _init() -> void:
	call_deferred("_comprobar")


func _comprobar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() != 1 or not ProjectSettings.load_resource_pack(argumentos[0]):
		_fallar("No se pudo montar el paquete exportado.")
		return
	var codigo := load("res://scripts/inventory_manager.gd") as Script
	if codigo == null:
		_fallar("Falta el inventario en el paquete.")
		return
	var inventario = codigo.new()
	inventario.initialize(false)
	var ids := PackedStringArray(["Sword", "Axe_small", "Bow_Wooden", "Torch"])
	if inventario.get_catalog().size() < 100 or inventario.get_arrow_count() != 12:
		inventario.free()
		_fallar("El paquete pierde parte del catálogo o de la munición inicial.")
		return
	for i in ids.size():
		if inventario.get_quick_slot_item(i + 1) != ids[i]:
			inventario.free()
			_fallar("El paquete pierde el equipo de inicio.")
			return
		if i < 3:
			var ruta := String(inventario.get_item_definition(ids[i]).get("icon_path", ""))
			if ruta.is_empty() or not ResourceLoader.exists(ruta) or not load(ruta) is Texture2D:
				inventario.free()
				_fallar("Falta el icono de %s en el paquete." % ids[i])
				return
	# El catálogo incompleto de una exportación anterior podía guardar
	# la identidad del equipo inicial después de perder los propios objetos.
	var guardado: Dictionary = inventario.get_save_state()
	guardado.items = {"Torch": 1, "Shield_Round": 1}
	if not inventario.apply_save_state(guardado, false):
		inventario.free()
		_fallar("El paquete no puede abrir un inventario previo.")
		return
	for id in ids:
		if not inventario.has_item(id):
			inventario.free()
			_fallar("No se recupera el equipo inicial en el guardado anterior.")
			return
	inventario.free()
	print("PACKAGED INVENTORY OK: catálogo, ranuras, iconos y guardado previo.")
	quit()


func _fallar(mensaje: String) -> void:
	push_error(mensaje)
	quit(1)
