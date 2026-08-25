class_name AdventureArrow
extends Node3D

## Proyectil con barrido continuo: no atraviesa objetivos aunque el fotograma sea
## largo y comunica impactos a cualquier recurso/enemigo compatible.

var velocity := Vector3.ZERO
var shooter: Node3D
var lifetime := 8.0
var damage := 1


func launch(direction: Vector3, speed: float, owner_node: Node3D) -> void:
	velocity = direction.normalized() * speed
	shooter = owner_node
	look_at(global_position + velocity.normalized(), Vector3.UP, true)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var start := global_position
	velocity += Vector3.DOWN * 6.8 * delta
	var finish := start + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, finish, 5)
	query.collide_with_areas = false
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result.position
		var collider := result.collider as Node
		if collider != null and collider.has_method("receive_projectile_hit"):
			collider.call("receive_projectile_hit", result.position, shooter)
		queue_free()
		return
	global_position = finish
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP, true)
