extends SceneTree
func _init():call_deferred("_probar")
func exigir(valor: bool, mensaje: String) -> bool:
	if valor:return true
	push_error(mensaje);quit(1);return false
func _probar() -> void:
	root.get_node("SaveGameManager").set_process(false)
	for n in ["InventoryManager","ExplorationManager"]:root.get_node(n).set("autosave_enabled",false)
	root.get_node("GameSettings").set_player_identity("RetoMensajeros",0,false)
	var m = load("res://scenes/world.tscn").instantiate();root.add_child(m);current_scene = m;root.get_node("SaveGameManager").bind_world(null)
	for i in 15:await process_frame
	paused = false;m.player.set_physics_process(false)
	var c = m.get_node("RPGStoryRuntime").aventura_pacifica.descenso;var r = c.rivales;var inv = root.get_node("InventoryManager");var antes: int = inv.get_count("Crystal3")
	c._empezar(1,m.player);r.avanzar(1.0)
	if not exigir(r.bots.size()==3 and r.bots[0].distancia==0,"Los rivales se saltan la cuenta atrás"):return
	if not exigir(not r.resultado(200.0).ganado and r.tiempo== -2.0 and r.bots[0].distancia==0,"La penalización no cuenta o mueve a los rivales visibles"):return
	var velocidades := [0.0,0.0,0.0]
	var pasos := 0
	while r.activa and pasos<2400:
		var previos: Array = r.bots.duplicate(true)
		r.avanzar(0.1);pasos += 1
		for i in 3:
			var e: Dictionary = r.bots[i];velocidades[i] = maxf(velocidades[i],e.rapidez)
			if not exigir(float(e.distancia)>=float(previos[i].distancia) and float(e.distancia)-float(previos[i].distancia)<4.0,"Un rival se teletransporta por el circuito"):return
	if not exigir(not r.activa,"Los mensajeros no completan el descenso"):return
	var tiempos: Array = []
	for i in 3:
		tiempos.append(r.bots[i].meta)
		if not exigir(r.bots[i].meta>115 and r.bots[i].meta<200 and r.bots[i].saltos.size()==3,"El rival no corre durante un tiempo realista o atraviesa los saltos"):return
	if not exigir(absf(tiempos[0]-tiempos[2])>4.0,"Todos los rivales tienen el mismo ritmo"):return
	var reloj: float = r.tiempo
	c._physics_process(0.6)
	if not exigir(r.tiempo>reloj+0.5,"El reloj del jugador se congela cuando llegan todos los rivales"):return
	c._terminar(1,m.player,{"tiempo":r.tiempo+1,"penalizacion":0.0})
	if not exigir(not c.premiados.has("RetoMensajeros") and inv.get_count("Crystal3")==antes,"Perder contra los mensajeros supera el reto"):return
	c._empezar(1,m.player);c._terminar(1,m.player,{"tiempo":120.0,"penalizacion":0.0})
	if not exigir(c.premiados.has("RetoMensajeros") and inv.get_count("Crystal3")==antes+3,"Ganar a los mensajeros no supera el reto"):return
	c.abandonar()
	if not exigir(not c.is_physics_processing() and not r.activa,"Abandonar deja una carrera vacía activa"):return
	print("SNOW RIVALS PASS: tiempos=",tiempos," premios sólo por victoria; tres saltos por rival.");quit(0)
