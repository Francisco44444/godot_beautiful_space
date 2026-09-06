class_name BuildingRecipes
extends RefCounted

## Las cuatro casas del taller, redeclaradas en CELDAS ENTERAS de 2 m.
##
## En el taller cada cuerpo se declaraba por su centro en metros —5.5, 5.2, -7.2,
## -2.1— y ninguno caía sobre la rejilla del kit. Dos cuerpos se solapaban medio
## módulo y cada uno pintaba su pared en la cara compartida: de ahí los muros
## dobles con la firma medida de 0.41 x 3.12 x 2.00 m, que son literalmente dos
## módulos idénticos metidos en la misma ranura.
##
## Aquí una celda tiene un único dueño y los cuerpos se tocan por sus caras, no
## se pisan. `origin` es la esquina mínima en celdas y `size` el tamaño en
## celdas; los metros se derivan, nunca se escriben a mano.

const ROOF_MESHES: PackedStringArray = [
	"Roof_RoundTiles_8x12", "Roof_RoundTiles_8x14", "Roof_RoundTiles_6x10",
	"Roof_RoundTiles_6x8", "Roof_RoundTiles_4x8", "Roof_RoundTiles_4x4",
	"Roof_Tower_RoundTiles",
]


static func all() -> Array[Dictionary]:
	return [cottage(), merchant_house(), tavern(), manor()]


static func for_house(floors: int, variant: int) -> Dictionary:
	## Lo que el mundo pide es "una casa de N plantas"; aquí se elige cuál de las
	## siluetas del taller le toca. Alternarlas es lo que hace que una villa
	## grande no parezca la misma casa repetida cincuenta veces.
	var storeys := maxi(floors, 2)
	match posmod(variant, 3):
		0:
			return cottage(storeys)
		1:
			return merchant_house(storeys)
		_:
			return tavern(storeys)


static func cottage(floors: int = 3) -> Dictionary:
	return {
		"id": &"casa_del_rio",
		"display_name": "Casa del Río",
		"volumes": [
			{
				"name": "principal", "origin": Vector2i(-2, -3), "size": Vector2i(4, 6),
				"floors": floors, "style": "stone", "stairs": true,
				"roof": "Roof_RoundTiles_8x12", "roof_front": "Roof_Front_Brick8",
				"door": {"side": 3, "module": 1},
			},
			{
				"name": "ala", "origin": Vector2i(2, -3), "size": Vector2i(2, 4),
				"floors": maxi(floors - 1, 1), "style": "stone",
				"roof": "Roof_RoundTiles_4x8", "roof_front": "Roof_Front_Brick4",
			},
		],
	}


static func merchant_house(floors: int = 3) -> Dictionary:
	return {
		"id": &"casa_del_mercader",
		"display_name": "Casa del Mercader",
		"volumes": [
			{
				"name": "principal", "origin": Vector2i(-2, -4), "size": Vector2i(4, 7),
				"floors": floors, "style": "timber", "stairs": true,
				"roof": "Roof_RoundTiles_8x14", "roof_front": "Roof_Front_Brick8",
				"door": {"side": 3, "module": 2},
			},
			{
				"name": "almacen", "origin": Vector2i(2, -4), "size": Vector2i(3, 5),
				"floors": maxi(floors - 1, 1), "style": "stone",
				"roof": "Roof_RoundTiles_6x10", "roof_front": "Roof_Front_Brick6",
			},
			{
				"name": "mirador", "origin": Vector2i(-2, 3), "size": Vector2i(2, 2),
				"floors": floors, "style": "timber",
				"roof": "Roof_RoundTiles_4x4", "roof_front": "Roof_Front_Brick4",
			},
		],
	}


static func tavern(floors: int = 3) -> Dictionary:
	return {
		"id": &"posada_del_ciervo",
		"display_name": "Posada del Ciervo Dorado",
		"volumes": [
			{
				"name": "salon", "origin": Vector2i(-2, -4), "size": Vector2i(4, 7),
				"floors": floors, "style": "tavern", "stairs": true,
				"roof": "Roof_RoundTiles_8x14", "roof_front": "Roof_Front_Brick8",
				"door": {"side": 3, "module": 1},
			},
			{
				"name": "ala_este", "origin": Vector2i(2, -4), "size": Vector2i(3, 5),
				"floors": maxi(floors - 1, 1), "style": "stone",
				"roof": "Roof_RoundTiles_6x10", "roof_front": "Roof_Front_Brick6",
			},
			{
				"name": "ala_oeste", "origin": Vector2i(-5, -4), "size": Vector2i(3, 4),
				"floors": maxi(floors - 1, 1), "style": "stone",
				"roof": "Roof_RoundTiles_6x8", "roof_front": "Roof_Front_Brick6",
			},
		],
	}


static func manor() -> Dictionary:
	## Las torres van al frente flanqueando la entrada, no clavadas en el costado
	## de las alas: ahí quedaban aprisionadas entre el cuerpo alto y el ala, y el
	## faldón del ala no tenía hacia dónde apartarse sin meterse en una de las dos.
	return {
		"id": &"solar_de_valdoria",
		"display_name": "Solar de Valdoria",
		"volumes": [
			{
				"name": "cuerpo", "origin": Vector2i(-2, -4), "size": Vector2i(4, 7),
				"floors": 4, "style": "manor", "stairs": true,
				"roof": "Roof_RoundTiles_8x14", "roof_front": "Roof_Front_Brick8",
				"door": {"side": 3, "module": 1},
			},
			{
				"name": "ala_oeste", "origin": Vector2i(-5, -4), "size": Vector2i(3, 5),
				"floors": 3, "style": "stone", "stairs": true,
				"roof": "Roof_RoundTiles_6x10", "roof_front": "Roof_Front_Brick6",
			},
			{
				"name": "ala_este", "origin": Vector2i(2, -4), "size": Vector2i(3, 5),
				"floors": 3, "style": "stone", "stairs": true,
				"roof": "Roof_RoundTiles_6x10", "roof_front": "Roof_Front_Brick6",
			},
			{
				"name": "torre_oeste", "origin": Vector2i(-2, -6), "size": Vector2i(2, 2),
				"floors": 5, "style": "manor", "stairs": true,
				"roof": "Roof_Tower_RoundTiles",
			},
			{
				"name": "torre_este", "origin": Vector2i(0, -6), "size": Vector2i(2, 2),
				"floors": 5, "style": "manor", "stairs": true,
				"roof": "Roof_Tower_RoundTiles",
			},
		],
	}
