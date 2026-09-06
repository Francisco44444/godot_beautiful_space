class_name VillageNeighbour
extends CharacterBody3D

## Un vecino de la villa. Camina por el grafo de calles que le da VillageFolk y
## responde si el héroe le habla, con el mismo contrato de interacción que ya usa
## el resto del juego: pertenecer al grupo "adventure_interactable" y ofrecer
## get_interaction_prompt() e interact().

const TRADE_NAMES: PackedStringArray = ["Vecino", "Porteador", "Mercader", "Herrera", "Carpintero", "Herbolaria", "Guardia a caballo"]
const GREETINGS: PackedStringArray = [
	"Buen día. La calzada nueva se agradece con la lluvia.",
	"Si buscas al alguacil, estará en el hall al fondo.",
	"Cuidado al caer la noche: se oyen cosas en el bosque.",
	"Vengo de descargar grano. Pesa más de lo que parece.",
	"El herrero cobra caro, pero su acero aguanta.",
	"Dicen que el señor del castillo no recibe a nadie.",
]

var trade := 0
var display_name := "Vecino"
var route: Array[Vector3] = []
var pause_left := 0.0
var animator: AnimationPlayer = null
var greeting_index := 0
var conversation_count := 0
var horse_animator: AnimationPlayer = null
var visual: Node3D = null
var work_station: Node3D = null
var work_pose: SkeletonModifier3D = null
var blocked_seconds := 0.0
var current_action := "Idle"
var network_position := Vector3.ZERO
var network_yaw := 0.0
var has_network_state := false


func setup(neighbour_trade: int, neighbour_name: String, greeting: int) -> void:
	trade = neighbour_trade
	display_name = neighbour_name
	greeting_index = greeting
	collision_layer = 5
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("adventure_interactable")
	add_to_group("village_folk")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65 if trade == 6 else 0.34
	capsule.height = 3.0 if trade == 6 else 1.7
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5 + 0.08
	add_child(collision)


func trade_label() -> String:
	return TRADE_NAMES[clampi(trade, 0, TRADE_NAMES.size() - 1)]


func get_interaction_prompt() -> String:
	return "E · Saludar a %s · %s" % [display_name, trade_label()]


func interact(player: Node) -> bool:
	## Se detiene, se gira hacia quien le habla y saluda. El paseo se reanuda solo
	## cuando se agota la pausa, así que no hace falta ninguna máquina de estados
	## aparte para volver a la calle.
	conversation_count += 1
	pause_left = maxf(pause_left, 4.5)
	if work_pose != null:
		work_pose.active = false
	route.clear()
	if player is Node3D:
		var towards := (player as Node3D).global_position - global_position
		towards.y = 0.0
		if towards.length() > 0.05:
			rotation.y = atan2(towards.x, towards.z)
	play("Victory" if conversation_count % 3 == 0 else "Idle")
	# Un saludo al paso va por el canal de aviso corto del héroe, no por el panel
	# de diálogo de la historia: este vecino no tiene ninguna pista que dar.
	if player != null and player.has_signal("action_feedback"):
		player.emit_signal("action_feedback", "%s: «%s»" % [display_name, _greeting()])
	return true


func play(animation: String) -> void:
	current_action = animation
	if horse_animator != null:
		var horse_action := "Walk" if animation == "Walk" else "Idle"
		if horse_animator.current_animation != horse_action and horse_animator.has_animation(horse_action):
			horse_animator.play(horse_action, 0.2)
		return  # El jinete mantiene su postura de montura.
	if animator == null:
		return
	if animator.current_animation == animation:
		return
	if animator.has_animation(animation):
		animator.play(animation, 0.16)


func _greeting() -> String:
	match trade:
		3: return "Trabajo el acero para que la guardia proteja la villa. Escucha el ritmo del martillo."
		4: return "Estoy preparando vigas para los pisos nuevos. La madera buena nunca se desperdicia."
		5: return "Clasifico las hierbas y preparo remedios. Si ves a Tavia, dile que quedan semillas."
		2: return "Contando monedas y revisando la mercancía. Las caravanas traen noticias del castillo."
		6: return "Patrullo estas calles y llevo mensajes a la fortaleza. Buen camino, viajero."
	return GREETINGS[posmod(greeting_index + conversation_count - 1, GREETINGS.size())]
