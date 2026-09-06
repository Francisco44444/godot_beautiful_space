class_name VillageStreet
extends RefCounted

## Calzada continua sobre Terrain3D, con el empedrado de caminos del proyecto.
## Cada vértice toma la cota del terreno: no quedan losas horizontales flotando
## ni baldosas de fachada repetidas con un giro diferente cada dos metros.
const COBBLES: Texture2D = preload("res://assets/textures/stylized_terrain/quaternius_rock_albedo_seamless.png")
const HALF_WIDTH := 5
const UV_SCALE := 0.28
const SURFACE_OFFSET := 0.025


static func build(terrain: Node, center: Vector2, yaw: float, radius: float, keep_out: Rect2, roads: Array = []) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights: Dictionary = {}
	if roads.is_empty():
		roads = [[Vector2(0, -radius), Vector2(0, radius), float(HALF_WIDTH)], [Vector2(-radius, 0), Vector2(radius, 0), float(HALF_WIDTH)]]
	var cells := {}
	for road in roads:
		var start: Vector2 = road[0]
		var finish: Vector2 = road[1]
		var width := float(road[2])
		var minimum := start.min(finish) - Vector2.ONE * width
		var maximum := start.max(finish) + Vector2.ONE * width
		for x in range(floori(minimum.x), ceili(maximum.x)):
			for z in range(floori(minimum.y), ceili(maximum.y)):
				var sample := Vector2(x + 0.5, z + 0.5)
				if sample.distance_to(Geometry2D.get_closest_point_to_segment(sample, start, finish)) <= width:
					cells[Vector2i(x, z)] = true
	for cell: Vector2i in cells:
		var corners: Array[Vector2] = [Vector2(cell), Vector2(cell + Vector2i(1, 0)), Vector2(cell + Vector2i(1, 1)), Vector2(cell + Vector2i(0, 1))]
		var blocked := false
		var vertices: Array[Vector3] = []
		for corner in corners:
			if keep_out.has_area() and keep_out.has_point(corner):
				blocked = true
			var point := center + corner.rotated(yaw)
			if not heights.has(corner):
				heights[corner] = float(terrain.data.get_height(Vector3(point.x, 0, point.y)))
			var height := float(heights[corner])
			if not is_finite(height):
				blocked = true
			vertices.append(Vector3(point.x, height + SURFACE_OFFSET, point.y))
		if blocked:
			continue
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_color(Color(0.97, 0.98, 0.93))
			surface.set_uv(corners[index] * UV_SCALE)
			surface.add_vertex(vertices[index])
	surface.generate_normals()
	surface.index()
	var material := StandardMaterial3D.new()
	material.resource_name = "Empedrado de caminos Quaternius"
	material.albedo_texture = COBBLES
	material.albedo_color = Color(0.76, 0.78, 0.73)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.97
	surface.set_material(material)
	return surface.commit()
