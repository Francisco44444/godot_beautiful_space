extends SceneTree
func _init() -> void:
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://generated/caves/cave_surface.json"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for point in data:
		st.add_vertex(Vector3(point[0], point[1], point[2]))
	st.generate_normals()
	st.index()
	var mesh := st.commit()
	ResourceSaver.save(mesh, "res://generated/caves/hollow.res")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://generated/caves/cave_surface.json"))
	print("CAVE PACK: ", mesh.get_faces().size()/3, " triángulos")
	quit()
