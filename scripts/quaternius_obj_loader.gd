class_name QuaterniusObjLoader
extends RefCounted

## Cargador mínimo de OBJ para los accesorios del Survival Pack. Evita que el
## juego dependa de la caché local `.godot/imported` y conserva los materiales
## de color definidos en el MTL de Quaternius.


static func load_mesh(obj_path: String) -> ArrayMesh:
	var file := FileAccess.open(obj_path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el OBJ Quaternius: %s" % obj_path)
		return null

	var positions: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var surfaces: Dictionary = {}
	var material_colors: Dictionary = {}
	var current_material := "Default"
	var directory := obj_path.get_base_dir()

	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"mtllib":
				if parts.size() > 1:
					material_colors = _load_material_colors(directory.path_join(parts[1]))
			"v":
				if parts.size() >= 4:
					positions.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vn":
				if parts.size() >= 4:
					normals.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])).normalized())
			"usemtl":
				if parts.size() > 1:
					current_material = parts[1]
			"f":
				if parts.size() >= 4:
					if not surfaces.has(current_material):
						surfaces[current_material] = []
					var face_tokens := parts.slice(1)
					for triangle_index in range(1, face_tokens.size() - 1):
						for token in [face_tokens[0], face_tokens[triangle_index], face_tokens[triangle_index + 1]]:
							var vertex_data := _parse_vertex_token(token, positions, normals)
							if not vertex_data.is_empty():
								surfaces[current_material].append(vertex_data)

	var mesh := ArrayMesh.new()
	for material_name in surfaces:
		var entries: Array = surfaces[material_name]
		if entries.is_empty():
			continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var has_normals := false
		for entry in entries:
			var normal: Vector3 = entry["normal"]
			if normal.length_squared() > 0.0:
				builder.set_normal(normal)
				has_normals = true
			builder.add_vertex(entry["position"])
		if not has_normals:
			builder.generate_normals()
		builder.set_material(_make_material(material_name, material_colors))
		builder.commit(mesh)
	return mesh


static func _parse_vertex_token(token: String, positions: Array[Vector3], normals: Array[Vector3]) -> Dictionary:
	var indices := token.split("/", true)
	if indices.is_empty() or indices[0].is_empty():
		return {}
	var position_index := _resolve_index(int(indices[0]), positions.size())
	if position_index < 0 or position_index >= positions.size():
		return {}
	var normal := Vector3.ZERO
	if indices.size() >= 3 and not indices[2].is_empty():
		var normal_index := _resolve_index(int(indices[2]), normals.size())
		if normal_index >= 0 and normal_index < normals.size():
			normal = normals[normal_index]
	return {"position": positions[position_index], "normal": normal}


static func _resolve_index(obj_index: int, count: int) -> int:
	return obj_index - 1 if obj_index > 0 else count + obj_index


static func _load_material_colors(mtl_path: String) -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open(mtl_path, FileAccess.READ)
	if file == null:
		return result
	var current_material := ""
	for raw_line in file.get_as_text().split("\n"):
		var parts := raw_line.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		if parts[0] == "newmtl" and parts.size() > 1:
			current_material = parts[1]
		elif parts[0] == "Kd" and parts.size() >= 4 and not current_material.is_empty():
			result[current_material] = Color(float(parts[1]), float(parts[2]), float(parts[3]))
	return result


static func _make_material(material_name: String, colors: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = colors.get(material_name, Color(0.42, 0.42, 0.42))
	var metal_surface := material_name.contains("Grey") or material_name.contains("Yellow")
	material.metallic = 0.82 if metal_surface else 0.03
	material.roughness = 0.24 if metal_surface else 0.76
	return material
