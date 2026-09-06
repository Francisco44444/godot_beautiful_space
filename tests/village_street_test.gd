extends SceneTree

const Street := preload("res://scripts/village_street.gd")


class Hills extends RefCounted:
	func get_height(point: Vector3) -> float:
		return point.x * 0.12 + sin(point.z * 0.2) * 0.9


class TerrainStub extends Node:
	var data := Hills.new()


func _initialize() -> void:
	assert(VillageLayout.plots().size() == 58, "Robledal debe conservar sus 58 parcelas ampliadas.")
	var claims: Array[Rect2] = []
	for plot in VillageLayout.plots():
		var claim := Rect2(plot.offset - Vector2.ONE * VillageLayout.RESERVE * 0.5, Vector2.ONE * VillageLayout.RESERVE)
		assert(not claim.intersects(VillageLayout.CASTLE), "Una parcela nueva invade el castillo.")
		for other in claims:
			assert(not claim.intersects(other), "Dos parcelas nuevas se solapan.")
		claims.append(claim)
		for road in VillageLayout.street_segments():
			var nearest := Geometry2D.get_closest_point_to_segment(plot.offset, road[0], road[1])
			# La reserva incluye 3 m de patio por lado; las calles sí pueden
			# tocar el patio, pero nunca el cuerpo de hasta 48 m de la casa.
			assert(not claim.grow(float(road[2]) - 3.1).has_point(nearest), "Una calle atraviesa la casa de la parcela %s: %s." % [plot.offset, road])
	var terrain := TerrainStub.new()
	var center := Vector2(-32.0, 47.0)
	var yaw := 0.42
	var exclusion := Rect2(8.0, -7.0, 9.0, 14.0)
	var mesh := Street.build(terrain, center, yaw, 20.0, exclusion)
	assert(mesh.get_surface_count() == 1, "La calle debe conservar un solo lote de dibujo.")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert(not vertices.is_empty(), "Falta la malla del empedrado.")
	for index in vertices.size():
		var vertex := vertices[index]
		assert(absf(vertex.y - terrain.data.get_height(vertex) - Street.SURFACE_OFFSET) < 0.0001,
			"Una esquina de la calle flota o queda enterrada en una pendiente.")
		assert(normals[index].y > 0.8, "El empedrado tiene caras o normales hacia abajo.")
		var local := (Vector2(vertex.x, vertex.z) - center).rotated(-yaw)
		assert(uvs[index].distance_to(local * Street.UV_SCALE) < 0.0001,
			"La textura deja de ser continua entre celdas.")
	for triangle in range(0, indices.size(), 3):
		var middle := (vertices[indices[triangle]] + vertices[indices[triangle + 1]] + vertices[indices[triangle + 2]]) / 3.0
		var local := (Vector2(middle.x, middle.z) - center).rotated(-yaw)
		assert(not exclusion.has_point(local), "El empedrado invade la reserva del castillo.")
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	assert(material != null and material.albedo_texture == Street.COBBLES,
		"Se ha cambiado el empedrado de caminos por una textura de fachada.")
	terrain.free()
	print("VILLAGE STREET PASS: pendiente, normales, UV continuas, reserva del castillo y un lote de dibujo.")
	quit()
