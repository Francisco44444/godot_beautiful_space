extends SceneTree
const Colisiones = preload("res://scripts/colisiones_bosque.gd")
var registros := PackedFloat32Array()
var ids := PackedStringArray()
var gestor: Node3D

func _init() -> void: call_deferred("comprobar")

func comprobar() -> void:
	gestor = Colisiones.new()
	root.add_child(gestor)
	agregar(Vector3.ZERO,1,4,"cero")
	agregar(Vector3(-256.1,3,0),0.6,7,"borde")
	agregar(Vector3(256.1,-2,0),1.4,8,"cero")
	agregar(Vector3(255.9,0,20),1.2,5,"cruce")
	agregar(Vector3(-0.01,2,-0.01),0.4,4,"")
	var azar := RandomNumberGenerator.new()
	azar.seed = 14112026
	for indice in 180:
		agregar(Vector3(1800+indice*7,azar.randf_range(-30,50),-1300+indice%11*11),azar.randf_range(0.38,1.42),azar.randf_range(4,25),"compartido" if indice%13==0 else "r%d"%indice)
	gestor.preparar(registros,ids)
	gestor.actualizar({},{})
	if gestor.is_processing() or gestor.is_physics_processing(): fallar("La colisión estática añade callbacks continuos."); return
	if not gestor.get("_celdas").has(Vector2i(-1,-1)): fallar("La rejilla redondea mal las coordenadas negativas."); return
	if not iguales(gestor.caras_activas(),referencia({},{})): fallar("Las celdas cambian algún vértice o el sentido de los triángulos."); return
	var cambios: int = gestor.estadisticas().reconstrucciones
	for repeticion in 100: gestor.actualizar({},{"id_desconocido":true})
	if int(gestor.estadisticas().reconstrucciones)!=cambios: fallar("Un id desconocido o la repetición reconstruye celdas intactas."); return
	await physics_frame
	await process_frame
	if not rayo(Vector3(3,1,0),Vector3.ZERO+Vector3.UP): fallar("Falta la colisión real del tronco cercano."); return
	if not rayo(Vector3(259,1,0),Vector3(256.1,1,0)): fallar("Falta el segundo prisma que comparte el mismo id."); return
	if not rayo(Vector3(259,1,20),Vector3(255.9,1,20)): fallar("El borde de una celda recorta el tronco que lo cruza."); return
	var personaje := CharacterBody3D.new()
	personaje.collision_layer = 0
	personaje.collision_mask = 1
	personaje.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var capsula := CollisionShape3D.new()
	capsula.shape = CapsuleShape3D.new()
	capsula.shape.radius = 0.25
	capsula.shape.height = 1.6
	capsula.position.y = 0.8
	personaje.add_child(capsula)
	root.add_child(personaje)
	personaje.position = Vector3(3,0,0)
	await physics_frame
	await process_frame
	personaje.move_and_collide(Vector3(-3,0,0))
	if personaje.position.x<1.2 or personaje.position.x>1.5: fallar("El cuerpo del personaje atraviesa el tronco o choca antes de su superficie."); return
	gestor.actualizar({"cero":true},{})
	if int(gestor.estadisticas().ultima_actualizacion)!=2: fallar("Una tala no actualiza exactamente sus dos celdas."); return
	if not iguales(gestor.caras_activas(),referencia({"cero":true},{})): fallar("Ocultar un id compartido pierde o conserva triángulos equivocados."); return
	await physics_frame
	await process_frame
	if rayo(Vector3(3,1,0),Vector3.UP) or rayo(Vector3(259,1,0),Vector3(256.1,1,0)): fallar("Queda colisión fantasma al talar o vaciar una celda."); return
	if not rayo(Vector3(259,1,20),Vector3(255.9,1,20)): fallar("Talar elimina otro tronco de la misma celda."); return
	personaje.position = Vector3(3,0,0)
	personaje.move_and_collide(Vector3(-3,0,0))
	if absf(personaje.position.x)>0.001: fallar("El personaje sigue bloqueado después de talar."); return
	gestor.actualizar({"cero":true,"compartido":true,"":true},{"compartido":true,"borde":true})
	if not iguales(gestor.caras_activas(),referencia({"cero":true,"compartido":true,"":true},{"compartido":true,"borde":true})): fallar("La unión de reservas y talas cambia ids vacíos o compartidos."); return
	cambios = gestor.estadisticas().reconstrucciones
	gestor.actualizar({"compartido":true},{"cero":true,"compartido":true,"borde":true})
	if int(gestor.estadisticas().reconstrucciones)!=cambios: fallar("Cambiar un id entre tala y reserva repite el mismo trabajo físico."); return
	var muchos := {}
	for indice in 1000: muchos["desconocido%d"%indice] = true
	gestor.actualizar(muchos,{"borde":true})
	if not iguales(gestor.caras_activas(),referencia(muchos,{"borde":true})): fallar("Una partida con muchos ids pierde las reservas del bosque."); return
	gestor.actualizar({},{})
	await physics_frame
	await process_frame
	if not rayo(Vector3(3,1,0),Vector3.UP) or not rayo(Vector3(259,1,0),Vector3(256.1,1,0)): fallar("Restaurar no reactiva la colisión real de ambas celdas."); return
	personaje.position = Vector3(3,0,0)
	personaje.move_and_collide(Vector3(-3,0,0))
	if personaje.position.x<1.2 or personaje.position.x>1.5: fallar("Restaurar no vuelve a bloquear al personaje."); return
	if not iguales(gestor.caras_activas(),referencia({},{})): fallar("La restauración no recupera los triángulos originales."); return
	# La geometría nueva debe invalidar el registro aunque no haya talas nuevas.
	agregar(Vector3(-800,0,900),0.8,6,"tardio")
	gestor.preparar(registros,ids)
	gestor.actualizar({},{})
	if not iguales(gestor.caras_activas(),referencia({},{})): fallar("Un alta tardía conserva geometría de un registro anterior."); return
	gestor.preparar(registros.slice(0,5),PackedStringArray(["cero"]))
	gestor.actualizar({},{})
	if rayo(Vector3(259,1,0),Vector3(256.1,1,0)): fallar("Una celda retirada sigue activa durante el fotograma de sustitución."); return
	await physics_frame
	await process_frame
	if int(gestor.estadisticas().troncos)!=1 or int(gestor.estadisticas().triangulos)!=12 or int(gestor.estadisticas().celdas)!=1: fallar("Reducir la distribución conserva estadísticas o celdas antiguas."); return
	if rayo(Vector3(259,1,0),Vector3(256.1,1,0)): fallar("Una celda retirada sigue bloqueando la física."); return
	gestor.actualizar({"cero":true},{})
	await physics_frame
	await process_frame
	if rayo(Vector3(3,1,0),Vector3.UP) or not gestor.caras_activas().is_empty(): fallar("Vaciar el último tronco no desactiva el cuerpo."); return
	gestor.preparar(PackedFloat32Array(),PackedStringArray())
	gestor.actualizar({},{})
	for fotograma in 3: await process_frame
	if gestor.get_child_count()!=0 or int(gestor.estadisticas().triangulos)!=0: fallar("Vaciar la distribución deja cuerpos o triángulos anteriores."); return
	print("FOREST COLLISION TEST OK: triángulos exactos, ids compartidos, límites negativos, reservas, física real, celda vacía, restauración y altas tardías.")
	quit()

func agregar(base: Vector3, radio: float, altura: float, id: String) -> void:
	for valor in [base.x,base.y,base.z,radio,altura]: registros.append(valor)
	ids.append(id)

func referencia(destruidos: Dictionary, reservados: Dictionary) -> PackedVector3Array:
	var caras := PackedVector3Array()
	for indice in ids.size():
		if not ids[indice].is_empty() and (destruidos.has(ids[indice]) or reservados.has(ids[indice])): continue
		var base := Vector3(registros[indice*5],registros[indice*5+1],registros[indice*5+2])
		for lado in 6:
			var a := TAU*float(lado)/6.0
			var b := TAU*float(lado+1)/6.0
			var bajo_a := base+Vector3(cos(a)*registros[indice*5+3],0,sin(a)*registros[indice*5+3])
			var bajo_b := base+Vector3(cos(b)*registros[indice*5+3],0,sin(b)*registros[indice*5+3])
			var alto_a := bajo_a+Vector3.UP*registros[indice*5+4]
			var alto_b := bajo_b+Vector3.UP*registros[indice*5+4]
			caras.append_array(PackedVector3Array([bajo_a,bajo_b,alto_b,bajo_a,alto_b,alto_a]))
	return caras

func iguales(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size()!=b.size(): return false
	var claves_a := PackedStringArray()
	var claves_b := PackedStringArray()
	for indice in range(0,a.size(),3):
		claves_a.append(var_to_bytes(a.slice(indice,indice+3)).hex_encode())
		claves_b.append(var_to_bytes(b.slice(indice,indice+3)).hex_encode())
	claves_a.sort()
	claves_b.sort()
	return claves_a==claves_b

func rayo(desde: Vector3, hasta: Vector3) -> bool:
	return not gestor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(desde,hasta,1)).is_empty()

func fallar(mensaje: String) -> void:
	push_error("FOREST COLLISION TEST FAIL: "+mensaje)
	quit(1)
