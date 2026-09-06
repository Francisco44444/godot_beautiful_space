extends Node

## El piloto del recorrido: escucha las teclas y mueve al héroe.

const BOSS_ORDER: PackedStringArray = [
	"rey_fungico", "centinela_bruma", "coloso_escarcha", "guardian_solar", "vaelor",
]
const TOP_GEAR := {
	"sword": "Claymore", "shield": "Shield_Heater_2",
	"bow": "Bow_Evil", "axe": "Axe_Double",
}

var _player: Node3D
var _runtime: Node
var _terrain: Node


func _ready() -> void:
	var world := get_parent()
	_player = world.get_node_or_null("Player")
	_runtime = world.get_node_or_null("RPGStoryRuntime")
	_terrain = world.get_node_or_null("Terrain3D")
	_menu()


func _menu() -> void:
	print("\n=========== RECORRIDO DE JEFES ===========")
	print("  F1..F5  ir al jefe del acto I..V (despierta al llegar)")
	print("  F6  equipo de grado alto    F7  vida al máximo")
	print("  F8  ficha del jefe cercano")
	for index in BOSS_ORDER.size():
		var boss := _boss(BOSS_ORDER[index])
		if boss == null:
			continue
		print("  F%d · %-26s vida %3d · daño %2d · exige %s · en (%.0f, %.0f)" % [
			index + 1, boss.display_name, boss.max_health, boss.strike_damage,
			_demand_name(boss.demand), boss.global_position.x, boss.global_position.z])
	print("==========================================\n")


static func _demand_name(demand: int) -> String:
	return ["ESCUDO", "ARCO", "CARGA", "ESQUIVA", "LAS CUATRO"][clampi(demand, 0, 4)]


func _boss(id: String) -> RPGBoss:
	if _runtime == null:
		return null
	for child in _runtime.get_children():
		if child is RPGBoss and (child as RPGBoss).enemy_id == id:
			return child as RPGBoss
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_F1 and key <= KEY_F5:
		_go_to(int(key) - int(KEY_F1))
	elif key == KEY_F6:
		_give_gear()
	elif key == KEY_F7:
		_heal()
	elif key == KEY_F8:
		_sheet()


func _go_to(index: int) -> void:
	var boss := _boss(BOSS_ORDER[index])
	if boss == null or _player == null:
		return
	# Despertarlo aunque su acto no haya llegado: esto es un recorrido, no una
	# partida. La campaña de verdad los mantiene sellados.
	boss.set_sealed(false)
	var away := Vector3(cos(float(index) * 1.7), 0.0, sin(float(index) * 1.7)) * 13.0
	var spot := boss.global_position + away
	if _terrain != null:
		var height: float = _terrain.get("data").get_height(Vector3(spot.x, 0.0, spot.z))
		if not is_nan(height):
			spot.y = height + 1.2
	_player.global_position = spot
	_player.velocity = Vector3.ZERO
	_player.look_at(Vector3(boss.global_position.x, spot.y, boss.global_position.z), Vector3.UP)
	_say("Acto %d · %s · exige %s" % [
		index + 1, boss.display_name, _demand_name(boss.demand)])
	print("→ %s · vida %d · exige %s" % [
		boss.display_name, boss.max_health, _demand_name(boss.demand)])


func _give_gear() -> void:
	var inventory := get_tree().root.get_node_or_null("InventoryManager")
	if inventory == null:
		return
	for category in TOP_GEAR:
		var item := String(TOP_GEAR[category])
		inventory.call("add_item", item, 1, false)
		inventory.call("equip_item", item, false)
	inventory.call("add_item", "Arrow", 60, false)
	_say("Equipo de grado alto entregado")
	print("→ equipado: %s" % TOP_GEAR)


func _heal() -> void:
	if _runtime == null:
		return
	_runtime.set("player_health", int(_runtime.get("player_max_health")))
	_say("Vida al máximo")


func _sheet() -> void:
	var nearest: RPGBoss = null
	var best := INF
	for id in BOSS_ORDER:
		var boss := _boss(id)
		if boss == null:
			continue
		var distance := boss.global_position.distance_to(_player.global_position)
		if distance < best:
			best = distance
			nearest = boss
	if nearest == null:
		return
	print("\n--- %s ---" % nearest.display_name)
	print("  vida %d/%d · fase %d · daño de golpe %d" % [
		nearest.health, nearest.max_health, nearest.phase, nearest.strike_damage])
	print("  exige: %s · guardas por romper: %d" % [
		_demand_name(nearest.demand), nearest._ward])
	print("  postura: %s · sellado: %s" % [
		["ACECHA", "SE PREPARA", "GOLPEA", "ABIERTO"][nearest.stance], nearest.sealed])
	print("  a %.0f m de ti\n" % best)


func _say(message: String) -> void:
	if _player != null and _player.has_signal("action_feedback"):
		_player.emit_signal("action_feedback", message)
