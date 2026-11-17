extends SceneTree
func _init() -> void: call_deferred("_probar")
func exigir(valor: bool, texto: String) -> bool:
	if valor: return true
	push_error(texto); quit(1); return false
func _probar() -> void:
	var mundo := Node3D.new(); root.add_child(mundo); current_scene = mundo
	var cine = load("res://scripts/rpg_cinematic.gd").new(); mundo.add_child(cine)
	paused = true
	cine.play([{"text":"Recuerdo compartido","hold":5.0}],Vector3.ZERO)
	if not exigir(cine.running and not cine._layer.visible,"La cinemática tapa el menú al recibir un acto cooperativo"): return
	var pendiente: float = cine._left
	for i in 6: await process_frame
	if not exigir(is_equal_approx(cine._left,pendiente),"El menú consume el tiempo de la cinemática pendiente"): return
	paused = false
	for i in 3: await process_frame
	if not exigir(cine._layer.visible and cine._left<pendiente,"La cinemática no continúa al cerrar el menú"): return
	paused = true
	if not exigir(not cine._layer.visible,"Pausar una cinemática deja las bandas encima del menú"): return
	paused = false
	cine._finish()
	if not exigir(not cine.running and not cine._layer.visible,"La cinemática deja una pantalla residual"): return
	print("CINEMATIC MODAL OK: espera sin tapar menús y continúa al reanudar.")
	quit(0)
