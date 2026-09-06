class_name RPGForge
extends RefCounted

## La forja: cómo sube de grado el equipo del héroe.
##
## Todo lo que aparece aquí existe de verdad en el catálogo del inventario; las
## escaleras se escribieron después de listarlo, no antes. Cuatro grados de
## espada, cinco de escudo, cuatro de hacha y dos de arco.
##
## Lo que ata la progresión al mundo es el PRECIO. Cada cristal lo suelta un
## bioma distinto —Crystal4 los limos del valle, Crystal2 los orcos y las
## guarniciones, Crystal3 los yetis de la nieve, Crystal5 los cactoros del
## desierto y Crystal1 los espectros del Bosque Tenebroso y los jefes—, así que
## para subir de grado hay que ir a buscarlo donde vive. Una espada mejor no se
## compra: se gana cruzando la isla.

const LADDERS := {
	"sword": ["Sword", "Sword_2", "Sword_Big", "Claymore", "Sword_Golden", "Sword_big_Golden"],
	"shield": ["Shield_Round", "Shield_Round_2", "Shield_Heater", "Shield_Heater_2", "Shield_Celtic_Golden"],
	"bow": ["Bow_Wooden", "Bow_Wooden2", "Bow_Evil", "Bow_Golden"],
	"axe": ["Axe_small", "Axe_Double", "Axe_small_Golden", "Axe_Double_Golden"],
}

## Qué cuesta pasar de un grado al siguiente, y de dónde sale ese material.
## La escalera de la espada recorre los CINCO biomas en orden: valle, orcos,
## nieve, desierto y Bosque Tenebroso. No es decoración: es lo que convierte
## "quiero una espada mejor" en "tengo que cruzar la isla".
const RECIPES := {
	"Sword": {"to": "Sword_2", "cost": {"Crystal4": 3}, "name": "Acero de Robledal"},
	"Sword_2": {"to": "Sword_Big", "cost": {"Crystal2": 3}, "name": "Mandoble del guardia"},
	"Sword_Big": {"to": "Claymore", "cost": {"Crystal3": 3, "Gold_Ingots": 1}, "name": "Claymore de escarcha"},
	"Claymore": {"to": "Sword_Golden", "cost": {"Crystal5": 4, "Gold_Ingots": 1}, "name": "Filo del Alba"},
	"Sword_Golden": {"to": "Sword_big_Golden", "cost": {"Crystal1": 5, "Gold_Ingots": 2}, "name": "Mandoble del Horizonte"},
	"Shield_Round": {"to": "Shield_Round_2", "cost": {"Crystal4": 2}, "name": "Rodela reforzada"},
	"Shield_Round_2": {"to": "Shield_Heater", "cost": {"Crystal5": 3}, "name": "Adarga de arena"},
	"Shield_Heater": {"to": "Shield_Heater_2", "cost": {"Crystal3": 3}, "name": "Broquel de escarcha"},
	"Shield_Heater_2": {"to": "Shield_Celtic_Golden", "cost": {"Crystal1": 4, "Gold_Ingots": 1}, "name": "Égida del Eco"},
	"Bow_Wooden": {"to": "Bow_Wooden2", "cost": {"Crystal4": 2}, "name": "Arco de tejo"},
	"Bow_Wooden2": {"to": "Bow_Evil", "cost": {"Crystal1": 3}, "name": "Arco de la sombra"},
	"Bow_Evil": {"to": "Bow_Golden", "cost": {"Crystal5": 4, "Gold_Ingots": 1}, "name": "Arco del mediodía"},
	"Axe_small": {"to": "Axe_Double", "cost": {"Crystal4": 2}, "name": "Hacha doble"},
	"Axe_Double": {"to": "Axe_small_Golden", "cost": {"Crystal2": 3}, "name": "Segur dorada"},
	"Axe_small_Golden": {"to": "Axe_Double_Golden", "cost": {"Crystal1": 3, "Gold_Ingots": 1}, "name": "Hacha del Horizonte"},
}

## Daño por grado. Antes la bonificación era un `+2` si el nombre contenía
## "Golden" o "big", así que la espada dorada grande —que contiene las dos—
## pegaba exactamente igual que la dorada, y la última mejora no se notaba.
const WEAPON_DAMAGE := {
	"Sword": 3, "Sword_2": 4, "Sword_Big": 6, "Claymore": 8,
	"Sword_Golden": 10, "Sword_big_Golden": 13, "Sword_big": 6,
	"Bow_Wooden": 2, "Bow_Wooden2": 3, "Bow_Evil": 5, "Bow_Golden": 7,
	"Axe_small": 2, "Axe_Double": 4, "Axe_small_Golden": 5, "Axe_Double_Golden": 7,
	"Axe": 3, "Axe_Small": 2,
	"Dagger": 2, "Dagger_2": 3, "Dagger_Golden": 4,
	"Spear": 5, "Scythe": 6, "Hammer_Small": 3, "Hammer_Double": 5,
	"Hammer_Double_Golden": 8,
}

## Cuánto daño deja pasar cada escudo al cubrirse. Con una reducción fija,
## mejorar de rodela a égida no cambiaba nada y media forja no servía.
const SHIELD_GUARD := {
	"Shield_Round": 0.55, "Shield_Round_2": 0.45, "Shield_Heater": 0.34,
	"Shield_Heater_2": 0.24, "Shield_Celtic_Golden": 0.12,
}


static func tier_of(item_id: String) -> int:
	for category in LADDERS:
		var ladder: Array = LADDERS[category]
		var index := ladder.find(item_id)
		if index >= 0:
			return index + 1
	return 0


static func ladder_length(category: String) -> int:
	return (LADDERS.get(category, []) as Array).size()


static func recipe_for(item_id: String) -> Dictionary:
	return RECIPES.get(item_id, {})


static func weapon_damage(item_id: String, fallback: int) -> int:
	return int(WEAPON_DAMAGE.get(item_id, fallback))


static func shield_multiplier(item_id: String, fallback: float) -> float:
	return float(SHIELD_GUARD.get(item_id, fallback))


static func cost_line(cost: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item in cost:
		parts.append("%d x %s" % [int(cost[item]), String(item)])
	return " + ".join(parts)
