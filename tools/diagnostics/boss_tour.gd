extends SceneTree

## Recorrido de jefes: lanza el juego y deja saltar de un jefe a otro.
##
##   1..5 (teclado numérico o F1..F5)  te planta ante el jefe del acto I..V
##   F6  equipo de grado alto      F7  vida al máximo
##   F8  ficha del jefe más cercano

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _frame in 16:
		await process_frame
	var pilot := load("res://tools/diagnostics/boss_pilot.gd").new()
	pilot.name = "BossPilot"
	world.add_child(pilot)
