class_name Player
extends CharacterBody3D

## Aventurero Quaternius en tercera persona con inventario rápido, combate
## cuerpo a cuerpo y objetos Survival Pack unidos al hueso de la mano.

signal mount_state_changed(mounted: bool, horse: Horse)
signal attack_started(combo_index: int)
signal melee_hit(target: Node)
signal equipment_changed(slot: int, item_name: String)
signal action_feedback(message: String)
signal bow_draw_changed(strength: float, arrows: int)
signal arrow_fired(remaining_arrows: int, strength: float)

enum ControlState {
	ON_FOOT,
	MOUNTED,
}

const OBJ_LOADER: Script = preload("res://scripts/quaternius_obj_loader.gd")
const ARROW_SCRIPT: Script = preload("res://scripts/adventure_arrow.gd")
const SURVIVAL_OBJ_ROOT := "res://assets/quaternius/Survival Pack - Sept 2020/OBJ/"
const CHARACTER_PATHS: Array[String] = [
	"res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Male.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Female.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Knight_Male.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Knight_Golden_Female.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Viking_Male.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Viking_Female.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Elf.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Witch.gltf",
]
const EQUIPMENT_SPECS: Dictionary = {
	1: {
		"category": "sword", "node_name": "EquippedSword",
		"scale": 0.72, "position": Vector3(0.07, 0.01, -0.10),
		"rotation": Vector3(PI * 0.16, 0.0, -0.08), "reach": 2.35,
	},
	2: {
		"category": "axe", "node_name": "EquippedAxe",
		"scale": 0.66, "position": Vector3(0.11, 0.015, -0.12),
		"rotation": Vector3(-0.52, 0.0, PI + 0.62), "reach": 2.25,
	},
	3: {
		"category": "bow", "node_name": "EquippedBow",
		"scale": 0.68, "position": Vector3(0.10, 0.04, -0.12),
		"rotation": Vector3(PI * 0.48, -0.12, PI * 0.48), "reach": 0.0,
	},
	4: {
		"category": "torch", "node_name": "EquippedTorch",
		"scale": 0.38, "position": Vector3(0.10, 0.015, -0.10),
		"rotation": Vector3(-0.46, 0.0, PI + 0.58), "reach": 0.0,
	},
}

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walk"
const ANIM_RUN := "Run"
const ANIM_JUMP := "Jump"
const ANIM_ATTACK := "SwordSlash"
const ANIM_STAB := "Punch"
const ANIM_SIT := "SitDown"
const REALISTIC_IDLE := ANIM_IDLE

@export_category("Movimiento")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 10.0
@export var acceleration: float = 26.0
@export var air_acceleration: float = 7.0
@export var jump_velocity: float = 5.3
@export var turn_speed: float = 12.0
@export var walk_animation_rate: float = 1.42
@export var run_animation_rate: float = 1.18

@export_category("Combate")
@export var attack_duration: float = 0.78
@export var attack_hit_start: float = 0.16
@export var attack_hit_end: float = 0.54
@export var attack_recovery: float = 0.18

@export_category("Seguridad")
@export var respawn_height: float = -12.0

@export_category("Quaternius")
@export_file("*.gltf") var quaternius_hero_path := "res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Male.gltf"
@export var hero_skin_color := Color("d87842")
@export var network_remote := false

@export_category("Montura")
@export var mount_distance: float = 3.6
@export var dismount_offset: float = 1.65

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $Collision
@onready var model_root: Node3D = $Visual/ModelRoot
@onready var attack_area: Area3D = $Visual/AttackArea
@onready var attack_shape: CollisionShape3D = $Visual/AttackArea/CollisionShape3D

var skeleton: Skeleton3D
var character_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var realistic_pose: Node3D
var realistic_model: Node3D
var realistic_skeleton: Skeleton3D
var realistic_animation: AnimationPlayer
var spawn_position: Vector3
var control_state := ControlState.ON_FOOT
var current_mount: Horse
var is_attacking := false
var attacks_performed := 0
var _attack_time := 0.0
var _attack_cooldown := 0.0
var _attack_hits: Dictionary = {}
var _realistic_stride := 0.0
var _weapon_grip: Node3D
var _weapon_base_rotation := Vector3.ZERO
var _weapon_socket: BoneAttachment3D
var _equipped_mesh: MeshInstance3D
var _shield_socket: BoneAttachment3D
var _shield_grip: Node3D
var _shield_mesh: MeshInstance3D
var _equipment_mesh_cache: Dictionary = {}
var _attack_reach := 1.25
var skin_surface_count := 0
var equipped_slot := 0
var equipped_item_name := "Manos vacías"
var equipped_item_id := ""
var equipped_category := ""
var is_drawing_bow := false
var _bow_draw_time := 0.0
var _bow_draw_strength := 0.0
var player_display_name := "Aventurero"
var character_index := 0
var _network_target_position := Vector3.ZERO
var _network_target_yaw := 0.0
var _network_target_velocity := Vector3.ZERO
var _network_state_ready := false
var _nameplate: Label3D


func _ready() -> void:
	spawn_position = global_position
	if not network_remote:
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null:
			player_display_name = String(settings.get("player_name"))
			character_index = int(settings.get("character_index"))
			settings.connect("identity_changed", Callable(self, "_on_local_identity_changed"))
		quaternius_hero_path = _character_path(character_index)
		add_to_group("local_player")
	else:
		collision_layer = 0
		collision_mask = 0
		collision.disabled = true
		attack_area.monitoring = false
		attack_area.monitorable = false
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	attack_shape.disabled = true
	attack_shape.shape = attack_shape.shape.duplicate()
	_load_quaternius_hero()
	model_root.visible = true
	_configure_realistic_hero()
	_build_right_hand_socket()
	_build_left_hand_socket()
	_refresh_equipped_shield()
	if not network_remote:
		var inventory := _inventory_manager()
		if inventory != null:
			inventory.connect("equipment_changed", Callable(self, "_on_inventory_equipment_changed"))
	_configure_animation_loops()
	_play_animation(ANIM_IDLE, 0.0)
	_build_nameplate()


func _process(delta: float) -> void:
	_update_realistic_visual(delta)


func _unhandled_input(event: InputEvent) -> void:
	if network_remote:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	var slot := 0
	match pressed_key:
		KEY_1:
			slot = 1
		KEY_2:
			slot = 2
		KEY_3:
			slot = 3
		KEY_4:
			slot = 4
	if slot > 0 and equip_item(slot):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if network_remote:
		_update_network_replica(delta)
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if control_state == ControlState.MOUNTED:
		_cancel_bow_draw()
		_sync_with_mount()
		if Input.is_action_just_pressed("interact"):
			if _confirm_nearby_exploration():
				return
			dismount()
		return

	if equipped_category == "bow":
		_update_bow_input(delta)
	elif Input.is_action_just_pressed("attack"):
		start_attack()
	if Input.is_action_just_pressed("interact") and not is_attacking:
		if _interact_with_adventure_object():
			return
		if _confirm_nearby_exploration():
			return
		var nearby_horse := get_nearby_mount()
		if nearby_horse != null:
			mount_horse(nearby_horse)
			return

	_update_attack(delta)
	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	move_and_slide()
	_update_locomotion_animation()

	if global_position.y < respawn_height:
		_respawn()


func _confirm_nearby_exploration() -> bool:
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration == null:
		return false
	# Actualización inmediata: no obliga a esperar al muestreo periódico de 160 ms
	# cuando el jugador llega a un hito y pulsa E en el mismo instante.
	exploration.call("update_player_position", global_position)
	var discovered := exploration.call("confirm_current_zone") as Dictionary
	return not discovered.is_empty()


func _interact_with_adventure_object() -> bool:
	var nearest: AdventureResource
	var nearest_distance := 4.2
	for node in get_tree().get_nodes_in_group("adventure_interactable"):
		var candidate := node as AdventureResource
		if candidate == null:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance and not candidate.get_interaction_prompt().is_empty():
			nearest = candidate
			nearest_distance = distance
	return nearest != null and nearest.interact(self)


func get_nearby_adventure_prompt() -> String:
	var best_prompt := ""
	var nearest_distance := 5.0
	for node in get_tree().get_nodes_in_group("adventure_interactable"):
		var candidate := node as AdventureResource
		if candidate == null:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			var prompt := candidate.get_interaction_prompt()
			if not prompt.is_empty():
				best_prompt = prompt
				nearest_distance = distance
	return best_prompt


func start_attack() -> bool:
	if equipped_slot == 0 or _equipped_mesh == null:
		return false
	if equipped_category in ["bow", "torch"]:
		return false
	if is_mounted() or is_attacking or _attack_cooldown > 0.0:
		return false
	is_attacking = true
	_attack_time = 0.0
	_attack_hits.clear()
	attacks_performed += 1
	var equipped_animation := ANIM_ATTACK
	_play_animation(equipped_animation, 0.06, 1.45)
	attack_started.emit(attacks_performed)
	return true


func is_mounted() -> bool:
	return control_state == ControlState.MOUNTED and is_instance_valid(current_mount)


func get_facing_direction_xz() -> Vector2:
	# El CharacterBody no gira: gira Visual, y al montar Visual pasa a ser hijo
	# del caballo. Leer su base global mantiene brújula y mapa correctos en ambos
	# estados sin duplicar lógica de orientación.
	var forward := -visual.global_basis.z
	var direction := Vector2(forward.x, forward.z)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.UP


func get_network_facing_yaw() -> float:
	var direction := get_facing_direction_xz()
	return atan2(-direction.x, -direction.y)


func configure_network_replica(name_value: String, index_value: int) -> void:
	network_remote = true
	player_display_name = name_value.strip_edges().left(24)
	if player_display_name.is_empty():
		player_display_name = "Aventurero"
	character_index = clampi(index_value, 0, CHARACTER_PATHS.size() - 1)
	quaternius_hero_path = _character_path(character_index)


func apply_identity(name_value: String, index_value: int) -> void:
	player_display_name = name_value.strip_edges().left(24)
	if player_display_name.is_empty():
		player_display_name = "Aventurero"
	var safe_index := clampi(index_value, 0, CHARACTER_PATHS.size() - 1)
	var next_path := _character_path(safe_index)
	var character_changed := safe_index != character_index or next_path != quaternius_hero_path
	character_index = safe_index
	quaternius_hero_path = next_path
	if _nameplate != null:
		_nameplate.text = player_display_name
	if character_changed and is_node_ready():
		_reload_quaternius_hero()


func apply_network_state(position_value: Vector3, yaw_value: float, velocity_value: Vector3, slot_value: int) -> void:
	_network_target_position = position_value
	_network_target_yaw = yaw_value
	_network_target_velocity = velocity_value
	if not _network_state_ready:
		global_position = position_value
		visual.rotation.y = yaw_value
		_network_state_ready = true
	if slot_value != equipped_slot:
		if slot_value > 0:
			equip_item(slot_value)
		else:
			_clear_equipped_item()


func get_camera_target() -> Node3D:
	return current_mount if is_mounted() else self


func get_nearby_mount() -> Horse:
	var nearest: Horse
	var nearest_distance := mount_distance
	for node in get_tree().get_nodes_in_group("mountable"):
		var horse := node as Horse
		if horse == null or horse.mounted:
			continue
		var distance := global_position.distance_to(horse.global_position)
		if distance <= nearest_distance:
			nearest = horse
			nearest_distance = distance
	return nearest


func mount_horse(horse: Horse) -> bool:
	if control_state != ControlState.ON_FOOT or horse == null or horse.mounted or is_attacking:
		return false

	current_mount = horse
	control_state = ControlState.MOUNTED
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	attack_shape.set_deferred("disabled", true)
	horse.set_mounted(true)
	visual.reparent(horse.rider_anchor, false)
	# El rig conserva la colisión a pie, pero hundimos las piernas en la montura
	# para que el torso quede sentado sobre la silla real del caballo.
	visual.position = Vector3(0.0, -0.15, 0.08)
	visual.rotation = Vector3.ZERO
	global_position = horse.global_position
	_play_animation(ANIM_SIT, 0.12, 1.25)
	mount_state_changed.emit(true, horse)
	return true


func dismount() -> bool:
	if not is_mounted():
		return false

	var horse := current_mount
	var exit_direction := horse.visual.global_basis.x.normalized()
	visual.reparent(self, false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3(0.0, horse.get_facing_yaw(), 0.0)
	global_position = horse.global_position + exit_direction * dismount_offset + Vector3.UP * 0.35
	velocity = Vector3.ZERO
	control_state = ControlState.ON_FOOT
	current_mount = null
	collision.set_deferred("disabled", false)
	horse.set_mounted(false)
	_play_animation(ANIM_IDLE, 0.12)
	mount_state_changed.emit(false, horse)
	return true


func _update_attack(delta: float) -> void:
	if not is_attacking:
		attack_shape.disabled = true
		return
	_attack_time += delta
	var active := _attack_time >= attack_hit_start and _attack_time <= attack_hit_end
	attack_shape.disabled = not active
	if active:
		_apply_melee_hits()
	if _attack_time >= attack_duration:
		is_attacking = false
		attack_shape.disabled = true
		_attack_cooldown = attack_recovery


func _apply_melee_hits() -> void:
	var candidates: Array[Node] = []
	for body in attack_area.get_overlapping_bodies():
		candidates.append(body)

	# La consulta física adicional evita perder golpes si el arma cruza un
	# objetivo entre dos actualizaciones del monitor de Area3D.
	var forward := -visual.global_basis.z.normalized()
	var query_shape := BoxShape3D.new()
	query_shape.size = Vector3(1.65, 2.05, _attack_reach)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = Transform3D(
		visual.global_basis.orthonormalized(),
		global_position + Vector3.UP * 1.05 + forward * (_attack_reach * 0.52)
	)
	query.collision_mask = 5
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 24):
		var collider := result.get("collider") as Node
		if collider != null and collider not in candidates:
			candidates.append(collider)

	for body in candidates:
		_apply_hit_to_body(body)


func _apply_hit_to_body(body: Node) -> void:
	if body == self or _attack_hits.has(body.get_instance_id()):
		return
	_attack_hits[body.get_instance_id()] = true
	var hit_position := _equipped_mesh.global_position if _equipped_mesh != null else attack_area.global_position
	if body.has_method("receive_tool_hit"):
		body.call("receive_tool_hit", equipped_category, equipped_item_id, hit_position, self)
	elif body.has_method("receive_melee_hit"):
		body.call("receive_melee_hit", hit_position)
	melee_hit.emit(body)


func _sync_with_mount() -> void:
	if not is_instance_valid(current_mount):
		control_state = ControlState.ON_FOOT
		current_mount = null
		collision.set_deferred("disabled", false)
		return
	global_position = current_mount.global_position
	velocity = current_mount.velocity


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _apply_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity


func _apply_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	if camera != null and input_vector.length_squared() > 0.0:
		var camera_forward := -camera.global_basis.z
		var camera_right := camera.global_basis.x
		camera_forward.y = 0.0
		camera_right.y = 0.0
		direction = (camera_right.normalized() * input_vector.x - camera_forward.normalized() * input_vector.y).normalized()

	var target_speed := sprint_speed if _is_sprint_pressed() else walk_speed
	if is_attacking:
		target_speed *= 0.28
	if is_drawing_bow:
		target_speed *= 0.30
	var target_velocity := direction * target_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)
	if is_drawing_bow:
		var aim_camera := get_viewport().get_camera_3d()
		if aim_camera != null:
			var aim_forward := -aim_camera.global_basis.z
			aim_forward.y = 0.0
			if aim_forward.length_squared() > 0.001:
				var aim_yaw := atan2(-aim_forward.x, -aim_forward.z)
				visual.rotation.y = lerp_angle(visual.rotation.y, aim_yaw, turn_speed * delta)
	elif direction.length_squared() > 0.0:
		var desired_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, turn_speed * delta)


func _update_locomotion_animation() -> void:
	if is_attacking:
		return
	if not is_on_floor():
		_play_animation(ANIM_JUMP, 0.1)
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > walk_speed + 0.8:
		_play_animation(ANIM_RUN, 0.10, clampf(horizontal_speed / sprint_speed * run_animation_rate, 0.95, 1.48))
	elif horizontal_speed > 0.25:
		_play_animation(ANIM_WALK, 0.10, clampf(horizontal_speed / walk_speed * walk_animation_rate, 0.82, 1.68))
	else:
		_play_animation(ANIM_IDLE, 0.18)


func _play_animation(animation_name: String, blend: float, speed: float = 1.0) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, blend, speed)
	else:
		animation_player.speed_scale = speed


func _configure_animation_loops() -> void:
	if animation_player == null:
		return
	for animation_name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func _configure_realistic_hero() -> void:
	if realistic_animation == null:
		return
	if realistic_animation.has_animation(REALISTIC_IDLE):
		var idle := realistic_animation.get_animation(REALISTIC_IDLE)
		idle.loop_mode = Animation.LOOP_LINEAR
		realistic_animation.play(REALISTIC_IDLE)


func _update_realistic_visual(delta: float) -> void:
	if realistic_pose == null:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var motion_amount := clampf(horizontal_speed / sprint_speed, 0.0, 1.0)
	_realistic_stride += delta * lerpf(2.2, 8.5, motion_amount)
	var desired_position := Vector3.ZERO
	var desired_rotation := Vector3.ZERO
	var desired_weapon_rotation := _weapon_base_rotation

	if is_mounted():
		desired_position.y = sin(_realistic_stride * 2.0) * 0.018
		desired_rotation.x = deg_to_rad(-4.0)
	elif is_drawing_bow:
		desired_position.z = -0.07 * _bow_draw_strength
		desired_rotation.y = deg_to_rad(-8.0 * _bow_draw_strength)
		desired_weapon_rotation.y += deg_to_rad(-12.0 * _bow_draw_strength)
		desired_weapon_rotation.z += deg_to_rad(9.0 * _bow_draw_strength)
	elif is_attacking:
		var phase := clampf(_attack_time / attack_duration, 0.0, 1.0)
		var strike := sin(phase * PI)
		var follow_through := sin(phase * PI * 0.72)
		var slash_progress := smoothstep(0.04, 0.78, phase)
		desired_position.z = -0.18 * strike
		desired_rotation.y = deg_to_rad(16.0 * strike - 6.0 * follow_through)
		desired_rotation.z = deg_to_rad(-4.0 * strike)
		desired_weapon_rotation.y += deg_to_rad(7.0 * strike)
		desired_weapon_rotation.z += deg_to_rad(lerpf(92.0, -110.0, slash_progress))
	else:
		desired_position.y = absf(sin(_realistic_stride)) * 0.035 * motion_amount
		desired_rotation.x = deg_to_rad(-5.5 * motion_amount)
		desired_rotation.z = deg_to_rad(sin(_realistic_stride * 0.5) * 1.8 * motion_amount)

	var blend := 1.0 - exp(-14.0 * delta)
	realistic_pose.position = realistic_pose.position.lerp(desired_position, blend)
	realistic_pose.rotation = realistic_pose.rotation.lerp(desired_rotation, blend)
	if _weapon_grip != null:
		_weapon_grip.rotation = _weapon_grip.rotation.lerp(desired_weapon_rotation, blend)
	if realistic_animation != null:
		realistic_animation.speed_scale = lerpf(0.72, 1.25, motion_amount)


func _build_right_hand_socket() -> void:
	if skeleton == null:
		push_error("El protagonista no tiene esqueleto para sujetar objetos.")
		return
	var fist_index := skeleton.find_bone("Fist.R")
	if fist_index < 0:
		push_error("El protagonista no tiene el hueso Fist.R.")
		return
	_weapon_socket = BoneAttachment3D.new()
	_weapon_socket.name = "RightHandSocket"
	skeleton.add_child(_weapon_socket)
	_weapon_socket.bone_name = "Fist.R"
	_weapon_socket.set_meta("equipment_socket", true)
	_weapon_grip = Node3D.new()
	_weapon_grip.name = "EquipmentGrip"
	_weapon_socket.add_child(_weapon_grip)
	_weapon_base_rotation = Vector3.ZERO


func _build_left_hand_socket() -> void:
	if skeleton == null:
		return
	var fist_index := skeleton.find_bone("Fist.L")
	if fist_index < 0:
		return
	_shield_socket = BoneAttachment3D.new()
	_shield_socket.name = "LeftHandShieldSocket"
	skeleton.add_child(_shield_socket)
	_shield_socket.bone_name = "Fist.L"
	_shield_grip = Node3D.new()
	_shield_grip.name = "ShieldGrip"
	_shield_grip.position = Vector3(-0.08, 0.02, -0.08)
	_shield_grip.rotation = Vector3(PI * 0.5, 0.0, -PI * 0.5)
	_shield_socket.add_child(_shield_grip)


func _refresh_equipped_shield() -> void:
	if _shield_grip == null:
		return
	for child in _shield_grip.get_children():
		_shield_grip.remove_child(child)
		child.queue_free()
	_shield_mesh = null
	var inventory := _inventory_manager()
	if inventory == null:
		return
	var shield_id := String(inventory.call("get_equipped_item", "shield"))
	if shield_id.is_empty() or not bool(inventory.call("has_item", shield_id)):
		return
	var definition := inventory.call("get_item_definition", shield_id) as Dictionary
	var path := String(definition.get("obj_path", ""))
	var mesh := _equipment_mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = OBJ_LOADER.load_mesh(path)
		if mesh == null:
			return
		_equipment_mesh_cache[path] = mesh
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "Equipped%s" % shield_id
	_shield_mesh.mesh = mesh.duplicate() as ArrayMesh
	_shield_mesh.scale = Vector3.ONE * 0.68
	_shield_mesh.set_meta("medieval_shield_only", true)
	_shield_grip.add_child(_shield_mesh)
	_configure_equipment_materials(_shield_mesh)


func equip_item(slot: int) -> bool:
	if not EQUIPMENT_SPECS.has(slot) or _weapon_grip == null:
		return false
	var inventory := _inventory_manager()
	if inventory == null:
		return false
	var item_id := String(inventory.call("get_quick_slot_item", slot))
	if item_id.is_empty():
		action_feedback.emit("Todavía no posees ese objeto")
		return false
	_cancel_bow_draw()
	if _equipped_mesh != null:
		_weapon_grip.remove_child(_equipped_mesh)
		_equipped_mesh.queue_free()
		_equipped_mesh = null
	for child in _weapon_grip.get_children():
		_weapon_grip.remove_child(child)
		child.queue_free()

	var spec: Dictionary = EQUIPMENT_SPECS[slot]
	var definition := inventory.call("get_item_definition", item_id) as Dictionary
	var path := String(definition.get("obj_path", ""))
	if path.is_empty():
		return false
	var equipment_mesh := _equipment_mesh_cache.get(path) as ArrayMesh
	if equipment_mesh == null:
		equipment_mesh = OBJ_LOADER.load_mesh(path)
		if equipment_mesh == null:
			return false
		_equipment_mesh_cache[path] = equipment_mesh

	_equipped_mesh = MeshInstance3D.new()
	_equipped_mesh.name = spec.node_name
	# Cada objeto recibe su propia copia de malla/materiales. Así puede
	# desaparecer al cambiar de hueco sin dejar instancias de material colgadas.
	_equipped_mesh.mesh = equipment_mesh.duplicate() as ArrayMesh
	_equipped_mesh.scale = Vector3.ONE * float(spec.scale)
	_equipped_mesh.set_meta("equipment_slot", slot)
	_equipped_mesh.set_meta("held_in_right_hand", true)
	_equipped_mesh.set_meta("grip_position", spec.position)
	_equipped_mesh.set_meta("grip_rotation", spec.rotation)
	_weapon_grip.position = spec.position
	_weapon_grip.rotation = spec.rotation
	_weapon_base_rotation = _weapon_grip.rotation
	_weapon_grip.add_child(_equipped_mesh)
	_configure_equipment_materials(_equipped_mesh)
	if slot == 3:
		_equipped_mesh.set_meta("ranged_weapon", true)
	if slot == 4:
		_add_torch_light()

	equipped_slot = slot
	equipped_item_id = item_id
	equipped_item_name = String(definition.get("display_name", item_id.replace("_", " ")))
	equipped_category = String(spec.category)
	_attack_reach = maxf(float(spec.reach), 0.15)
	var box := attack_shape.shape as BoxShape3D
	if box != null:
		box.size = Vector3(1.7, 2.2, _attack_reach)
	attack_area.position.z = -_attack_reach * 0.52
	equipment_changed.emit(equipped_slot, equipped_item_name)
	return true


func get_equipped_mesh() -> MeshInstance3D:
	return _equipped_mesh


func get_equipped_item_name() -> String:
	return equipped_item_name


func get_equipped_item_id() -> String:
	return equipped_item_id


func get_equipped_category() -> String:
	return equipped_category


func get_arrow_count() -> int:
	var inventory := _inventory_manager()
	return int(inventory.call("get_arrow_count")) if inventory != null else 0


func get_bow_draw_strength() -> float:
	return _bow_draw_strength


func _update_bow_input(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_begin_bow_draw()
	if not is_drawing_bow:
		return
	_bow_draw_time += delta
	_bow_draw_strength = clampf(_bow_draw_time / 1.05, 0.0, 1.0)
	bow_draw_changed.emit(_bow_draw_strength, get_arrow_count())
	if Input.is_action_just_released("attack"):
		_release_bow_arrow()


func _begin_bow_draw() -> bool:
	if is_mounted() or is_attacking or equipped_category != "bow":
		return false
	if get_arrow_count() <= 0:
		action_feedback.emit("No tienes flechas: busca cofres o recógelas")
		bow_draw_changed.emit(0.0, 0)
		return false
	is_drawing_bow = true
	_bow_draw_time = 0.0
	_bow_draw_strength = 0.0
	_set_camera_aiming(true)
	bow_draw_changed.emit(0.0, get_arrow_count())
	return true


func _release_bow_arrow() -> bool:
	if not is_drawing_bow:
		return false
	var strength := _bow_draw_strength
	if _bow_draw_time < 0.12:
		_cancel_bow_draw()
		action_feedback.emit("Mantén el clic para tensar el arco")
		return false
	var inventory := _inventory_manager()
	if inventory == null:
		_cancel_bow_draw()
		return false
	var arrow_item := String(inventory.call("consume_arrow"))
	if arrow_item.is_empty():
		_cancel_bow_draw()
		return false
	var camera := get_viewport().get_camera_3d()
	var direction := -visual.global_basis.z.normalized()
	if camera != null:
		direction = -camera.global_basis.z.normalized()
	var arrow := AdventureArrow.new()
	arrow.name = "ArrowProjectile"
	var definition := inventory.call("get_item_definition", arrow_item) as Dictionary
	var path := String(definition.get("obj_path", ""))
	var mesh := _equipment_mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = OBJ_LOADER.load_mesh(path)
		if mesh != null:
			_equipment_mesh_cache[path] = mesh
	if mesh != null:
		var visual_arrow := MeshInstance3D.new()
		visual_arrow.name = "ArrowVisual"
		visual_arrow.mesh = mesh.duplicate() as ArrayMesh
		visual_arrow.scale = Vector3.ONE * 0.78
		arrow.add_child(visual_arrow)
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(arrow)
	arrow.global_position = _weapon_grip.global_position + direction * 0.55
	arrow.launch(direction, lerpf(27.0, 78.0, strength), self)
	_cancel_bow_draw()
	arrow_fired.emit(get_arrow_count(), strength)
	return true


func _cancel_bow_draw() -> void:
	if not is_drawing_bow and _bow_draw_strength <= 0.0:
		return
	is_drawing_bow = false
	_bow_draw_time = 0.0
	_bow_draw_strength = 0.0
	_set_camera_aiming(false)
	bow_draw_changed.emit(0.0, get_arrow_count())


func _set_camera_aiming(active: bool) -> void:
	var camera_rig := get_node_or_null("../CameraRig")
	if camera_rig != null and camera_rig.has_method("set_aiming"):
		camera_rig.call("set_aiming", active)


func _clear_equipped_item() -> void:
	_cancel_bow_draw()
	if _weapon_grip != null:
		for child in _weapon_grip.get_children():
			_weapon_grip.remove_child(child)
			child.queue_free()
	_equipped_mesh = null
	equipped_slot = 0
	equipped_item_name = "Manos vacías"
	equipped_item_id = ""
	equipped_category = ""
	_attack_reach = 1.25


func _reload_quaternius_hero() -> void:
	var previous_slot := equipped_slot
	_clear_equipped_item()
	for child in model_root.get_children():
		model_root.remove_child(child)
		child.queue_free()
	skeleton = null
	character_mesh = null
	animation_player = null
	realistic_skeleton = null
	realistic_animation = null
	_weapon_socket = null
	_weapon_grip = null
	_shield_socket = null
	_shield_grip = null
	_shield_mesh = null
	_load_quaternius_hero()
	_configure_realistic_hero()
	_build_right_hand_socket()
	_build_left_hand_socket()
	_refresh_equipped_shield()
	_configure_animation_loops()
	_play_animation(ANIM_IDLE, 0.0)
	if previous_slot > 0:
		equip_item(previous_slot)


func _load_quaternius_hero() -> void:
	var loaded_scene := _load_gltf_scene(quaternius_hero_path)
	if loaded_scene != null:
		model_root.add_child(loaded_scene)
		loaded_scene.rotation_degrees.y = 180.0
		_recolor_hero_skin(loaded_scene)
		loaded_scene.set_meta("character_source", quaternius_hero_path)
	realistic_pose = model_root
	realistic_model = model_root
	skeleton = _find_skeleton(model_root)
	character_mesh = _find_visible_mesh(model_root)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	realistic_skeleton = skeleton
	realistic_animation = animation_player


func _recolor_hero_skin(loaded_scene: Node3D) -> void:
	# Cowboy_Male trae la cabeza casi negra en el material Skin. Ojos, cejas y
	# bigote usan Face/Hair, por lo que se conservan al aplicar un tono humano.
	skin_surface_count = 0
	var mesh_nodes: Array[Node] = loaded_scene.find_children("*", "MeshInstance3D", true, false)
	if loaded_scene is MeshInstance3D:
		mesh_nodes.push_front(loaded_scene)
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != "Skin":
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.albedo_color = hero_skin_color
			material.metallic = 0.0
			material.roughness = 0.86
			material.set_meta("human_skin_recolor", true)
			mesh_instance.set_surface_override_material(surface, material)
			mesh_instance.set_meta("human_skin_recolored", true)
			skin_surface_count += 1


func _load_gltf_scene(path: String) -> Node3D:
	var imported := ResourceLoader.load(path)
	if imported is PackedScene:
		var imported_node := (imported as PackedScene).instantiate() as Node3D
		if imported_node != null:
			imported_node.set_meta("loaded_via_project_importer", true)
		return imported_node
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el modelo Quaternius: %s" % path)
		return null
	var node := document.generate_scene(state)
	if node != null:
		node.set_meta("loaded_via_project_importer", false)
	return node as Node3D


func _configure_equipment_materials(equipment: MeshInstance3D) -> void:
	for surface in equipment.mesh.get_surface_count():
		var source := equipment.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		var material_name := source.resource_name.to_lower()
		var is_steel := "steel" in material_name or "grey" in material_name or "silver" in material_name
		var is_gold := "gold" in material_name or "yellow" in material_name
		var is_metal := is_steel or is_gold
		# Los MTL de los distintos packs usan nombres diferentes (Steel,
		# DarkSteel, Grey, Gold...). Normalizamos la familia completa para evitar
		# que las recompensas RPG recién equipadas aparezcan casi negras.
		if is_steel:
			material.albedo_color = Color("9aa9b5") if "light" in material_name else Color("687887")
		elif is_gold:
			material.albedo_color = Color("d29a32") if "dark" not in material_name else Color("986326")
		elif "wood" in material_name:
			material.albedo_color = Color("7a4228") if "light" in material_name else Color("5e321f")
		elif "red" in material_name:
			material.albedo_color = Color("c94a3b")
		elif "white" in material_name:
			material.albedo_color = Color("e1e1d8")
		elif "black" in material_name:
			material.albedo_color = Color("353b45")
		material.roughness = 0.36 if is_metal else 0.76
		material.metallic = 0.42 if is_metal else 0.03
		if material_name == "fire":
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = Color(1.0, 0.19, 0.025)
			material.emission_energy_multiplier = 4.2
		equipment.mesh.surface_set_material(surface, material)


func _add_torch_light() -> void:
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	# Coordenada local del remate de WoodenTorch_Fire; hereda rotación y escala.
	light.position = Vector3(0.0, 2.62, 0.0)
	light.light_color = Color(1.0, 0.42, 0.12)
	light.light_energy = 4.2
	light.omni_range = 13.0
	light.shadow_enabled = true
	light.set_meta("equipped_torch_light", true)
	_equipped_mesh.add_child(light)


func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)


func _find_skeleton(parent: Node) -> Skeleton3D:
	for node in parent.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _find_visible_mesh(parent: Node) -> MeshInstance3D:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			return mesh_instance
	return null


func _build_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.name = "PlayerName"
	_nameplate.position = Vector3(0.0, 2.35, 0.0)
	_nameplate.text = player_display_name
	_nameplate.font_size = 34
	_nameplate.outline_size = 8
	_nameplate.modulate = Color(1.0, 0.91, 0.66)
	_nameplate.outline_modulate = Color(0.04, 0.055, 0.07, 0.94)
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = true
	_nameplate.visible = network_remote
	add_child(_nameplate)


func _update_network_replica(delta: float) -> void:
	if not _network_state_ready:
		return
	var position_blend := 1.0 - exp(-11.0 * delta)
	global_position = global_position.lerp(_network_target_position, position_blend)
	visual.rotation.y = lerp_angle(visual.rotation.y, _network_target_yaw, position_blend)
	velocity = _network_target_velocity
	_update_locomotion_animation()


func _on_local_identity_changed(name_value: String, index_value: int) -> void:
	if not network_remote:
		apply_identity(name_value, index_value)


func _on_inventory_equipment_changed(category: String, _item_id: String) -> void:
	if category == "shield":
		_refresh_equipped_shield()
	elif category == equipped_category and equipped_slot > 0:
		equip_item(equipped_slot)


func _inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")


func _character_path(index_value: int) -> String:
	return CHARACTER_PATHS[clampi(index_value, 0, CHARACTER_PATHS.size() - 1)]


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
