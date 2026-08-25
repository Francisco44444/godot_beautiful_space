extends Node

## Inventario persistente de la aventura. El catálogo se construye a partir de
## todos los OBJ del Ultimate RPG Items Pack y añade exclusivamente los escudos
## del Medieval Weapons Pack, tal como exige la dirección artística del juego.

signal inventory_changed(entries: Array)
signal item_added(item_id: String, amount: int, new_total: int)
signal item_removed(item_id: String, amount: int, new_total: int)
signal equipment_changed(category: String, item_id: String)
signal save_completed(path: String)

const SAVE_VERSION := 1
const SAVE_PATH := "user://adventure_inventory_v1.json"
const RPG_ROOT := "res://assets/quaternius/Ultimate RPG Items Pack - Aug 2019/"
const RPG_OBJ_ROOT := RPG_ROOT + "OBJ/"
const RPG_ICON_ROOT := RPG_ROOT + "Icons/"
const MEDIEVAL_OBJ_ROOT := "res://assets/quaternius/Medieval Weapons Pack by @Quaternius/OBJ/"
const SURVIVAL_OBJ_ROOT := "res://assets/quaternius/Survival Pack - Sept 2020/OBJ/"
const SHIELD_FILES: PackedStringArray = [
	"Shield_Celtic_Golden", "Shield_Heater", "Shield_Heater_2",
	"Shield_Round", "Shield_Round_2",
]
const STARTING_ITEMS := {
	"Sword": 1,
	"Axe_small": 1,
	"Bow_Wooden": 1,
	"Arrow": 12,
	"Torch": 1,
}
const STARTING_EQUIPMENT := {
	"sword": "Sword",
	"axe": "Axe_small",
	"bow": "Bow_Wooden",
	"shield": "",
}

@export_file("*.json") var save_path := SAVE_PATH
@export var autosave_enabled := true

var _catalog: Dictionary = {}
var _inventory: Dictionary = {}
var _equipped: Dictionary = STARTING_EQUIPMENT.duplicate(true)
var _initialized := false


func _ready() -> void:
	initialize(true)


func initialize(load_saved: bool = true) -> void:
	if not _initialized:
		_build_catalog()
		_initialized = true
	if load_saved and load_inventory():
		return
	if _inventory.is_empty():
		_inventory = STARTING_ITEMS.duplicate(true)
		_equipped = STARTING_EQUIPMENT.duplicate(true)
	_emit_changed()


func get_catalog() -> Array[Dictionary]:
	_ensure_initialized()
	var result: Array[Dictionary] = []
	var ids := PackedStringArray(_catalog.keys())
	ids.sort()
	for item_id in ids:
		result.append((_catalog[item_id] as Dictionary).duplicate(true))
	return result


func get_item_definition(item_id: String) -> Dictionary:
	_ensure_initialized()
	var definition: Dictionary = _catalog.get(item_id, {})
	return definition.duplicate(true) if not definition.is_empty() else {}


func get_inventory_entries() -> Array[Dictionary]:
	_ensure_initialized()
	var result: Array[Dictionary] = []
	var ids: Array = _inventory.keys()
	ids.sort_custom(func(a, b) -> bool:
		var left: Dictionary = _catalog.get(a, {})
		var right: Dictionary = _catalog.get(b, {})
		var left_key := "%s:%s" % [String(left.get("category", "zz")), String(left.get("display_name", a))]
		var right_key := "%s:%s" % [String(right.get("category", "zz")), String(right.get("display_name", b))]
		return left_key < right_key
	)
	for item_id in ids:
		var amount := int(_inventory.get(item_id, 0))
		if amount <= 0:
			continue
		var entry: Dictionary = (_catalog.get(item_id, {"id": item_id, "display_name": item_id}) as Dictionary).duplicate(true)
		entry["amount"] = amount
		entry["equipped"] = item_id in _equipped.values()
		result.append(entry)
	return result


func add_item(item_id: String, amount: int = 1, autosave: bool = true) -> bool:
	_ensure_initialized()
	if amount <= 0 or not _catalog.has(item_id):
		return false
	var new_total := int(_inventory.get(item_id, 0)) + amount
	_inventory[item_id] = new_total
	var definition: Dictionary = _catalog[item_id]
	var category := String(definition.get("category", "misc"))
	# Un arma nueva sustituye inmediatamente a la de su familia. Así el premio
	# de un cofre se ve en la mano sin navegar por un menú adicional.
	if category in ["sword", "axe", "bow", "shield"]:
		_equipped[category] = item_id
		equipment_changed.emit(category, item_id)
	item_added.emit(item_id, amount, new_total)
	_emit_changed()
	if autosave and autosave_enabled:
		save_inventory()
	return true


func remove_item(item_id: String, amount: int = 1, autosave: bool = true) -> bool:
	_ensure_initialized()
	var current := int(_inventory.get(item_id, 0))
	if amount <= 0 or current < amount:
		return false
	var remaining := current - amount
	if remaining > 0:
		_inventory[item_id] = remaining
	else:
		_inventory.erase(item_id)
	item_removed.emit(item_id, amount, remaining)
	_emit_changed()
	if autosave and autosave_enabled:
		save_inventory()
	return true


func get_count(item_id: String) -> int:
	_ensure_initialized()
	return int(_inventory.get(item_id, 0))


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_count(item_id) >= amount


func equip_item(item_id: String, autosave: bool = true) -> bool:
	_ensure_initialized()
	if not has_item(item_id):
		return false
	var definition: Dictionary = _catalog.get(item_id, {})
	var category := String(definition.get("category", ""))
	if category not in ["sword", "axe", "bow", "shield"]:
		return false
	_equipped[category] = item_id
	equipment_changed.emit(category, item_id)
	_emit_changed()
	if autosave and autosave_enabled:
		save_inventory()
	return true


func get_equipped_item(category: String) -> String:
	_ensure_initialized()
	return String(_equipped.get(category, ""))


func get_quick_slot_item(slot: int) -> String:
	match slot:
		1:
			return get_equipped_item("sword")
		2:
			return get_equipped_item("axe")
		3:
			return get_equipped_item("bow")
		4:
			return "Torch" if has_item("Torch") else ""
	return ""


func get_arrow_count() -> int:
	return get_count("Arrow") + get_count("Arrow_Golden")


func consume_arrow() -> String:
	var consumed := ""
	if remove_item("Arrow", 1, false):
		consumed = "Arrow"
	elif remove_item("Arrow_Golden", 1, false):
		consumed = "Arrow_Golden"
	if not consumed.is_empty() and autosave_enabled:
		save_inventory()
	return consumed


func get_random_reward_id(seed_value: int) -> String:
	_ensure_initialized()
	var reward_ids: PackedStringArray = []
	for item_id in _catalog:
		var definition: Dictionary = _catalog[item_id]
		if bool(definition.get("rewardable", true)) and String(definition.get("category", "")) != "world":
			reward_ids.append(String(item_id))
	if reward_ids.is_empty():
		return "Coin"
	reward_ids.sort()
	return reward_ids[posmod(seed_value * 73 + 19, reward_ids.size())]


func reset_inventory_for_tests(persist: bool = false) -> void:
	_inventory = STARTING_ITEMS.duplicate(true)
	_equipped = STARTING_EQUIPMENT.duplicate(true)
	_emit_changed()
	if persist:
		save_inventory()


func save_inventory() -> bool:
	_ensure_initialized()
	var payload := {
		"schema_version": SAVE_VERSION,
		"items": _inventory,
		"equipped": _equipped,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	var text_file := FileAccess.open(save_path + ".tmp", FileAccess.READ)
	if text_file == null:
		return false
	var text := text_file.get_as_text()
	text_file = null
	var final_file := FileAccess.open(save_path, FileAccess.WRITE)
	if final_file == null:
		return false
	final_file.store_string(text)
	final_file.flush()
	final_file = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + ".tmp"))
	save_completed.emit(save_path)
	return true


func load_inventory() -> bool:
	_ensure_initialized()
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", -1)) != SAVE_VERSION:
		return false
	var stored_items = parsed.get("items", {})
	var stored_equipment = parsed.get("equipped", {})
	if not stored_items is Dictionary or not stored_equipment is Dictionary:
		return false
	_inventory.clear()
	for raw_id in stored_items:
		var item_id := String(raw_id)
		var amount := int(stored_items[raw_id])
		if _catalog.has(item_id) and amount > 0:
			_inventory[item_id] = amount
	_equipped = STARTING_EQUIPMENT.duplicate(true)
	for category in ["sword", "axe", "bow", "shield"]:
		var item_id := String(stored_equipment.get(category, _equipped[category]))
		if item_id.is_empty() or has_item(item_id):
			_equipped[category] = item_id
	if _inventory.is_empty():
		_inventory = STARTING_ITEMS.duplicate(true)
	_emit_changed()
	return true


func _build_catalog() -> void:
	_catalog.clear()
	var directory := DirAccess.open(RPG_OBJ_ROOT)
	if directory != null:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while not file_name.is_empty():
			if not directory.current_is_dir() and file_name.get_extension().to_lower() == "obj":
				var item_id := file_name.get_basename()
				_add_catalog_item(item_id, RPG_OBJ_ROOT + file_name, RPG_ICON_ROOT + _icon_file_for(item_id), "rpg")
			file_name = directory.get_next()
		directory.list_dir_end()
	for shield_name in SHIELD_FILES:
		_add_catalog_item(shield_name, MEDIEVAL_OBJ_ROOT + shield_name + ".obj", "", "medieval")
	_catalog["Torch"] = {
		"id": "Torch", "display_name": "Antorcha", "category": "torch",
		"obj_path": SURVIVAL_OBJ_ROOT + "WoodenTorch_Fire.obj", "icon_path": "",
		"source": "survival", "stackable": false, "rewardable": false,
	}
	# El tronco es un recurso del mundo y forma parte del inventario aunque su
	# representación 3D sea un cilindro low-poly creado en tiempo real.
	_catalog["WoodLog"] = {
		"id": "WoodLog", "display_name": "Tronco de madera", "category": "material",
		"obj_path": "", "icon_path": "", "source": "world", "stackable": true,
		"rewardable": false,
	}


func _add_catalog_item(item_id: String, obj_path: String, icon_path: String, source: String) -> void:
	_catalog[item_id] = {
		"id": item_id,
		"display_name": _display_name(item_id),
		"category": _category_for(item_id),
		"obj_path": obj_path,
		"icon_path": icon_path,
		"source": source,
		"stackable": _category_for(item_id) not in ["sword", "axe", "bow", "shield", "armor"],
		"rewardable": not item_id.begins_with("Chest_") and not item_id.ends_with("_Empty"),
	}


func _category_for(item_id: String) -> String:
	var lower := item_id.to_lower()
	if lower.begins_with("sword") or lower == "claymore":
		return "sword"
	if lower.begins_with("axe"):
		return "axe"
	if lower.begins_with("bow"):
		return "bow"
	if lower.begins_with("arrow"):
		return "ammo"
	if lower.begins_with("shield"):
		return "shield"
	if lower.begins_with("armor"):
		return "armor"
	if lower.begins_with("potion") or lower.begins_with("heart"):
		return "consumable"
	if lower.begins_with("crystal") or lower == "mineral" or lower == "gold_ingots":
		return "mineral"
	if lower.begins_with("coin"):
		return "currency"
	if lower.begins_with("book") or lower in ["scroll", "parchment"]:
		return "lore"
	if lower.begins_with("key"):
		return "key"
	return "treasure"


func _icon_file_for(item_id: String) -> String:
	var direct := item_id + ".png"
	if FileAccess.file_exists(RPG_ICON_ROOT + direct):
		return direct
	var title_case := item_id.replace("small", "Small").replace("big", "Big") + ".png"
	return title_case if FileAccess.file_exists(RPG_ICON_ROOT + title_case) else ""


func _display_name(item_id: String) -> String:
	if item_id == "Crystal4":
		return "Rubí"
	return item_id.replace("_", " ").capitalize()


func _ensure_initialized() -> void:
	if not _initialized:
		_build_catalog()
		_initialized = true


func _emit_changed() -> void:
	inventory_changed.emit(get_inventory_entries())
