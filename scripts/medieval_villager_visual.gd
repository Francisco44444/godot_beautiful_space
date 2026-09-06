class_name MedievalVillagerVisual
extends RefCounted

## Piel humana y paños teñidos: los materiales del paquete son independientes
## por superficie, de modo que no hay que teñir ojos, pelo ni armaduras.
const SKIN_COLOR := Color("d87842")
const CLOTH_COLORS: Array[Color] = [Color("45624b"), Color("76503c"), Color("704153"), Color("375b72"), Color("a08755"), Color("657a72")]
const HAIR_COLORS: Array[Color] = [Color("38251e"), Color("704125"), Color("ba8242"), Color("45322e"), Color("878378")]


static func apply(visual: Node3D, variation: int, skin_color: Color = SKIN_COLOR) -> void:
	var skin_count := 0
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			if source.resource_name == "Skin":
				material.albedo_color = skin_color
				material.metallic = 0.0
				material.roughness = 0.86
				material.set_meta("human_skin_recolor", true)
				skin_count += 1
			elif source.resource_name == "Hair":
				material.albedo_color = HAIR_COLORS[posmod(variation / 2, HAIR_COLORS.size())]
				material.roughness = 0.95
			elif source.resource_name in ["Main", "Clothes"] and not "Knight" in String(visual.get_meta("character_file", "")):
				material.albedo_color = CLOTH_COLORS[posmod(variation, CLOTH_COLORS.size())]
				material.roughness = 0.96
			else:
				continue
			mesh.set_surface_override_material(surface, material)
	visual.set_meta("human_skin_surface_count", skin_count)
	visual.set_meta("medieval_clothing", true)
	visual.set_meta("outfit_variation", variation)


static func player_skin(context: Node) -> Color:
	if context.is_inside_tree():
		var player := context.get_tree().root.find_child("Player", true, false)
		if player != null:
			var skin: Variant = player.get("hero_skin_color")
			if skin is Color:
				return skin
	return SKIN_COLOR
