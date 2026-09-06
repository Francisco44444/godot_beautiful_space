class_name BuildingCatalog
extends RefCounted

## Qué pieza del kit va en cada sitio.
##
## Los datos medidos sobre los propios glTF, no supuestos. Los módulos de muro
## del Medieval Village MegaKit miden 2.0000 x 3.1227 x 0.4065 m, ocupan de
## z = -0.3140 a z = +0.0925 y NO están centrados en su espesor: el núcleo
## macizo son 0.20 m enteros del lado negativo, de z = 0 a z = -0.20. Lo que
## asoma por +Z es relieve de ladrillo y lo que se mete por -Z es cornisa.
##
## De ahí sale la consecuencia que importa: EL +Z LOCAL ES LA CARA BUENA, la que
## mira a la calle. Lo confirman por separado las contraventanas (z de +0.09 a
## +0.56), los balcones (+0.90 a +1.10) y las aceras (0 a +0.70), que van todos
## por fuera. Por eso el giro de una pieza no puede derivarse sólo de la
## orientación de la arista, sino del LADO de la celda que esa arista cierra: con
## el giro fijo por orientación, media casa enseñaba el revoco interior a la
## calle. La fórmula vive en BuildingAssembler.wall_transform().

const ROOT := "res://assets/quaternius/store_bundle/glTF/"


static var _roof_cache: Dictionary = {}


static func roof_metrics() -> Dictionary:
	## AABB real de cada cubierta, medida una vez y guardada. El anclaje de un
	## tejado no puede salir de una constante escrita a ojo: así es como el taller
	## acabó con faldones 3.77 m por debajo del alero, más de una planta entera.
	if not _roof_cache.is_empty():
		return _roof_cache
	for mesh_name in BuildingRecipes.ROOF_MESHES:
		var scene := load(ROOT + mesh_name + ".gltf") as PackedScene
		if scene == null:
			continue
		var node := scene.instantiate()
		var box := AABB()
		var first := true
		for mesh_instance in _mesh_instances(node):
			var stack := Transform3D.IDENTITY
			var walker: Node = mesh_instance
			while walker != null and walker != node.get_parent():
				if walker is Node3D:
					stack = (walker as Node3D).transform * stack
				walker = walker.get_parent()
			var world: AABB = stack * mesh_instance.get_aabb()
			box = world if first else box.merge(world)
			first = false
		node.queue_free()
		if not first:
			_roof_cache[mesh_name] = box
	return _roof_cache


static func _mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_mesh_instances(child))
	return out


static func families() -> Dictionary:
	## Cada estilo declara qué pone en planta baja, en plantas altas, en la
	## medianera y en el hueco de la puerta. La medianera lleva arco: un muro
	## ciego entre dos cuerpos deja el ala incomunicada.
	return {
		"root": ROOT,
		"stone": {
			"ground": "Wall_UnevenBrick_Straight",
			"upper": "Wall_UnevenBrick_Straight",
			"window": "Wall_UnevenBrick_Window_Wide_Round",
			"narrow": "Wall_UnevenBrick_Window_Thin_Round",
			"party": "Wall_Arch",
			"door": "Wall_UnevenBrick_Door_Round",
		},
		"timber": {
			"ground": "Wall_Plaster_Straight",
			"upper": "Wall_Plaster_Straight",
			"window": "Wall_Plaster_Window_Wide_Flat",
			"party": "Wall_Arch",
			"door": "Wall_Plaster_Door_Round",
		},
		"tavern": {
			"ground": "Wall_Plaster_Straight",
			"upper": "Wall_Plaster_Straight",
			"window": "Wall_Plaster_Window_Wide_Round",
			"narrow": "Wall_Plaster_Window_Thin_Round",
			"party": "Wall_Arch",
			"door": "Wall_Plaster_Door_Round",
		},
		"manor": {
			"ground": "Wall_UnevenBrick_Straight",
			"upper": "Wall_Plaster_Straight",
			"window": "Wall_Plaster_Window_Wide_Round",
			"narrow": "Wall_Plaster_Window_Thin_Round",
			"party": "Wall_Arch",
			"door": "Wall_UnevenBrick_Door_Round",
		},
		"floor": "Floor_UnevenBrick",
		"stair": "Stair_Interior_Simple",
	}
