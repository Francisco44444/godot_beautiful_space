class_name RPGBestiary
extends RefCounted

## El bestiario de Aeloria y dónde vive cada cosa.
##
## Antes había 48 enemigos clavados en doce puntos fijos, todos a más de 300 m
## del héroe y ninguno junto a un camino: nunca te cruzabas con ninguno. Aquí la
## amenaza se reparte por donde de verdad se pasa —las diez rutas de la isla— y
## se agrupa en guaridas dentro de los bosques y los biomas duros.
##
## La escala tiene dos ejes. El primero es la DISTANCIA a Puerto Alba, que es
## donde empieza la aventura: cerca hay limos, lejos hay demonios. El segundo es
## el BIOMA, que manda sobre el primero: en la nieve salen yetis aunque estés
## cerca de casa, y en el desierto cactoros. Así el mundo enseña por sí solo
## hasta dónde puedes llegar con la espada que llevas.

const MONSTER_ROOT := "res://assets/quaternius/Ultimate Monsters/"
const START := Vector2(0.0, 190.0)

## Umbrales de distancia a Puerto Alba que separan un escalón del siguiente.
const TIER_DISTANCES: PackedFloat32Array = [640.0, 1700.0, 3000.0]

## Cada especie declara su escalón, su malla y sus números. `biome` vacío
## significa que puede salir en cualquier sitio de su escalón.
const SPECIES: Array[Dictionary] = [
	{
		"id": "limo_sendero", "name": "Limo del sendero", "tier": 1, "biome": "",
		"model": "Blob/glTF/GreenBlob.gltf", "health": 3, "damage": 4, "speed": 2.2,
		"reward": "Coin_Skull", "amount": 1, "scale": 0.9,
	},
	{
		"id": "mohin_raiz", "name": "Mohín de raíz", "tier": 1, "biome": "valley",
		"model": "Blob/glTF/Mushnub.gltf", "health": 4, "damage": 5, "speed": 2.0,
		"reward": "Coin_Skull", "amount": 1, "scale": 0.95,
	},
	{
		"id": "espina_verde", "name": "Espina verde", "tier": 2, "biome": "",
		"model": "Blob/glTF/GreenSpikyBlob.gltf", "health": 7, "damage": 6, "speed": 2.9,
		"reward": "Crystal4", "amount": 1, "scale": 1.0,
	},
	{
		"id": "setal_crecido", "name": "Setal crecido", "tier": 2, "biome": "valley",
		"model": "Blob/glTF/Mushnub_Evolved.gltf", "health": 9, "damage": 7, "speed": 2.6,
		"reward": "Crystal4", "amount": 1, "scale": 1.05,
	},
	{
		"id": "orco_merodeador", "name": "Orco merodeador", "tier": 3, "biome": "",
		"model": "Big/glTF/Orc.gltf", "health": 13, "damage": 9, "speed": 3.2,
		"reward": "Crystal2", "amount": 1, "scale": 1.0,
	},
	{
		"id": "calavera_orca", "name": "Calavera orca", "tier": 3, "biome": "",
		"model": "Big/glTF/Orc_Skull.gltf", "health": 15, "damage": 10, "speed": 3.0,
		"reward": "Crystal2", "amount": 1, "scale": 1.0,
	},
	{
		"id": "espectro_eco", "name": "Espectro del Eco", "tier": 3, "biome": "dark_forest",
		"model": "Flying/glTF/Ghost.gltf", "health": 11, "damage": 11, "speed": 3.6,
		"reward": "Crystal1", "amount": 1, "scale": 1.0,
	},
	{
		"id": "yeti_sin_nombre", "name": "Yeti sin nombre", "tier": 3, "biome": "snow",
		"model": "Big/glTF/Yeti.gltf", "health": 20, "damage": 12, "speed": 2.8,
		"reward": "Crystal3", "amount": 1, "scale": 1.1,
	},
	{
		"id": "cactoro", "name": "Cactoro", "tier": 3, "biome": "desert",
		"model": "Big/glTF/Cactoro.gltf", "health": 16, "damage": 10, "speed": 2.7,
		"reward": "Crystal5", "amount": 1, "scale": 1.05,
	},
	{
		"id": "demonio_azul", "name": "Demonio azul", "tier": 4, "biome": "",
		"model": "Big/glTF/BlueDemon.gltf", "health": 24, "damage": 14, "speed": 3.4,
		"reward": "Crystal1", "amount": 2, "scale": 1.1,
	},
	{
		"id": "guardia_caido", "name": "Guardia caído", "tier": 3, "biome": "castle",
		"model": "Big/glTF/Orc.gltf", "health": 18, "damage": 11, "speed": 3.0,
		"reward": "Crystal2", "amount": 1, "scale": 1.05,
	},
	{
		"id": "capitan_hueso", "name": "Capitán de hueso", "tier": 4, "biome": "castle",
		"model": "Big/glTF/Orc_Skull.gltf", "health": 26, "damage": 13, "speed": 3.1,
		"reward": "Crystal2", "amount": 2, "scale": 1.15,
	},
	{
		"id": "calavera_espectral", "name": "Calavera espectral", "tier": 4, "biome": "dark_forest",
		"model": "Flying/glTF/Ghost_Skull.gltf", "health": 22, "damage": 15, "speed": 3.8,
		"reward": "Crystal1", "amount": 2, "scale": 1.05,
	},
]

## Los jefes no se reparten: cada uno cierra un acto y tiene su sitio.
const BOSSES: Array[Dictionary] = [
	{
		"id": "rey_fungico", "name": "Rey Fúngico de Robledal", "boss": true,
		"model": "Big/glTF/MushroomKing.gltf", "health": 46, "damage": 15, "speed": 2.6,
		"reward": "Crystal3", "amount": 3, "scale": 3.0, "point": Vector2(-2520.0, 1440.0),
		"demand": 0, "act": "I · Raíces de Robledal",
	},
	{
		"id": "centinela_bruma", "name": "Centinela de la Bruma", "boss": true,
		"model": "Big/glTF/Demon.gltf", "health": 62, "damage": 17, "speed": 3.1,
		"reward": "Crystal2", "amount": 3, "scale": 3.2, "point": Vector2(-2460.0, -1260.0),
		"demand": 1, "act": "II · La bruma que habla",
	},
	{
		"id": "coloso_escarcha", "name": "Coloso de Escarcha", "boss": true,
		"model": "Big/glTF/Dino.gltf", "health": 78, "damage": 19, "speed": 2.9,
		"reward": "Crystal3", "amount": 4, "scale": 3.6, "point": Vector2(-1620.0, -2880.0),
		"demand": 2, "act": "III · La corona de invierno",
	},
	{
		"id": "guardian_solar", "name": "Guardián Solar", "boss": true,
		"model": "Flying/glTF/Dragon.gltf", "health": 96, "damage": 21, "speed": 3.4,
		"reward": "Crystal5", "amount": 4, "scale": 3.4, "point": Vector2(2760.0, 3000.0),
		"demand": 3, "act": "IV · El sol bajo la arena",
	},
	{
		"id": "vaelor", "name": "Vaelor, la Voz sin Cuerpo", "boss": true,
		"model": "Flying/glTF/Dragon_Evolved.gltf", "health": 140, "damage": 25, "speed": 3.6,
		"reward": "Crystal1", "amount": 6, "scale": 5.0, "point": Vector2(2880.0, -2460.0),
		"demand": 4, "act": "V · La voz del horizonte",
	},
]

## Guaridas: racimos de enemigos fuera del camino, para que el bosque tenga
## dientes y no sólo los senderos.
const LAIRS: Array[Dictionary] = [
	# Alrededor de Puerto Alba, que es donde se empieza: sin criaturas de sobra
	# en el primer kilómetro no hay dónde aprender a pelear ni con qué cumplir
	# el primer encargo. Medido antes de añadirlas: sólo tres limos en toda la
	# isla, y la primera cacería pedía cuatro.
	{"point": Vector2(-150.0, 330.0), "count": 5, "radius": 14.0},
	{"point": Vector2(190.0, 60.0), "count": 5, "radius": 14.0},
	{"point": Vector2(-260.0, 40.0), "count": 4, "radius": 13.0},
	{"point": Vector2(300.0, 420.0), "count": 4, "radius": 13.0},
	# Las cumbres nevadas apenas las tocan los caminos, así que sin guaridas
	# propias sólo salían tres yetis en toda la isla y su cacería pedía tres.
	{"point": Vector2(-1350.0, -2700.0), "count": 5, "radius": 19.0},
	{"point": Vector2(-1800.0, -2700.0), "count": 5, "radius": 19.0},
	{"point": Vector2(-900.0, -3150.0), "count": 4, "radius": 17.0},
	{"point": Vector2(-820.0, 900.0), "count": 4, "radius": 16.0},
	{"point": Vector2(-1720.0, 1180.0), "count": 5, "radius": 18.0},
	{"point": Vector2(-2260.0, -560.0), "count": 5, "radius": 18.0},
	{"point": Vector2(420.0, -1620.0), "count": 4, "radius": 16.0},
	{"point": Vector2(-260.0, -2600.0), "count": 6, "radius": 20.0},
	{"point": Vector2(1580.0, 1180.0), "count": 5, "radius": 18.0},
	{"point": Vector2(2940.0, 1660.0), "count": 6, "radius": 20.0},
	{"point": Vector2(3620.0, -1280.0), "count": 6, "radius": 20.0},
	{"point": Vector2(4680.0, -1180.0), "count": 7, "radius": 22.0},
	# Guaridas con especie dictada. Dos encargos mentían: Tavia habla de setales
	# comiéndose los robles «al oeste de Robledal» y los más cercanos vivían a
	# 1.356 m al ESTE; los orcos que «bajan de la sierra hacia la Aldea de la
	# Bruma» estaban en la nieve, a 2 km. Antes que reescribir la prosa —que
	# sostiene la historia— se pone el bicho donde se dice que está.
	{"point": Vector2(-1900.0, 700.0), "count": 4, "radius": 17.0, "species": "setal_crecido"},
	{"point": Vector2(-2060.0, 900.0), "count": 4, "radius": 16.0, "species": "setal_crecido"},
	{"point": Vector2(-2300.0, -1480.0), "count": 4, "radius": 18.0, "species": "orco_merodeador"},
	{"point": Vector2(-2020.0, -1340.0), "count": 4, "radius": 17.0, "species": "orco_merodeador"},
	# Con la comarca puesta, tres cacerías no reunían lo que piden si además
	# regateabas con altivez (+2): quedaban IMPOSIBLES y jugando no había forma
	# de saberlo. Se siembra en el sitio que nombra su texto.
	{"point": Vector2(-836.0, 900.0), "count": 4, "radius": 17.0, "species": "espina_verde"},
	{"point": Vector2(-700.0, 1060.0), "count": 4, "radius": 16.0, "species": "espina_verde"},
	{"point": Vector2(3151.0, -1196.0), "count": 4, "radius": 18.0, "species": "espectro_eco"},
	{"point": Vector2(3320.0, -1360.0), "count": 4, "radius": 17.0, "species": "espectro_eco"},
	{"point": Vector2(1598.0, 1180.0), "count": 4, "radius": 17.0, "species": "cactoro"},
	{"point": Vector2(1470.0, 1330.0), "count": 4, "radius": 16.0, "species": "cactoro"},
	{"point": Vector2(-247.0, 40.0), "count": 4, "radius": 15.0, "species": "limo_sendero"},
	{"point": Vector2(-1331.0, -2700.0), "count": 4, "radius": 17.0, "species": "yeti_sin_nombre"},
	{"point": Vector2(4702.0, -1180.0), "count": 4, "radius": 17.0, "species": "calavera_espectral"},
	{"point": Vector2(-2300.0, -1462.0), "count": 4, "radius": 17.0, "species": "orco_merodeador"},
	{"point": Vector2(-1900.0, 717.0), "count": 4, "radius": 16.0, "species": "setal_crecido"},
]


static func species_by_id(species_id: String) -> Dictionary:
	for species in SPECIES:
		if String(species["id"]) == species_id:
			return species
	return {}


## Guarniciones: los castillos tienen quien los defienda, y esa gente pelea de
## otra manera —se cubre— porque son soldados, no alimañas.
const GARRISONS: Array[Dictionary] = [
	{"point": Vector2(-1337.0, 703.0), "count": 6, "radius": 74.0},
	{"point": Vector2(2385.0, -1042.0), "count": 6, "radius": 74.0},
	{"point": Vector2(-545.0, -2212.0), "count": 6, "radius": 74.0},
]

## Qué estilo de combate corresponde a cada bioma. Los índices son los del
## enum Style de RPGEnemy: LUNGE, SLAM, SPINES, BLINK, GUARD.
## La arena de cada jefe: dónde se pelea y con qué está hecho el sitio.
const ARENAS: Array[Dictionary] = [
	{"id": "rey_fungico", "style": "raices", "centre": Vector2(-2520.0, 1440.0),
	 "radius": 17.0, "floor_radius": 13.0},
	{"id": "centinela_bruma", "style": "piedras", "centre": Vector2(-2460.0, -1260.0),
	 "radius": 16.0, "floor_radius": 12.0},
	{"id": "coloso_escarcha", "style": "observatorio", "centre": Vector2(-1620.0, -2880.0),
	 "radius": 19.0, "floor_radius": 14.0, "patina": Color(0.74, 0.84, 0.96)},
	{"id": "guardian_solar", "style": "solar", "centre": Vector2(2760.0, 3000.0),
	 "radius": 18.0, "floor_radius": 14.0, "patina": Color(0.94, 0.80, 0.52)},
	# Los cinco sitios salieron de rastrear la isla en rejilla de 60 m buscando
	# llano dentro del radio, desnivel contra el anillo de 120 m y distancia a
	# caminos y casas. Antes tres de las cinco arenas estaban a menos de 200 m
	# de un camino y el Centinela a 91 m de una casa: te las encontrabas sin
	# buscarlas. Medido ahora: camino 400..1405 m, casa 307..996 m.
	{"id": "vaelor", "style": "eco", "centre": Vector2(2880.0, -2460.0),
	 "radius": 22.0, "floor_radius": 16.0, "patina": Color(0.30, 0.26, 0.32)},
]


static func style_for(biome: String) -> int:
	match biome:
		"snow":
			return 1
		"desert":
			return 2
		"dark_forest":
			return 3
		"castle":
			return 4
		_:
			return 0


static func tier_for(point: Vector2) -> int:
	var distance := point.distance_to(START)
	for index in TIER_DISTANCES.size():
		if distance < TIER_DISTANCES[index]:
			return index + 1
	return TIER_DISTANCES.size() + 1


static func species_for(tier: int, biome: String, pick: int) -> Dictionary:
	## El bioma manda sobre el escalón: en la nieve sale un yeti aunque estés
	## cerca de casa, porque el mundo tiene que enseñar por sí solo hasta dónde
	## se puede llegar con el arma que llevas.
	var by_biome: Array[Dictionary] = []
	var by_tier: Array[Dictionary] = []
	for species in SPECIES:
		if String(species["biome"]) == biome and biome != "" and biome != "valley":
			by_biome.append(species)
		if int(species["tier"]) == tier and String(species["biome"]) in ["", biome]:
			by_tier.append(species)
	if not by_biome.is_empty():
		return by_biome[posmod(pick, by_biome.size())]
	if not by_tier.is_empty():
		return by_tier[posmod(pick, by_tier.size())]
	return SPECIES[posmod(pick, SPECIES.size())]


static func patrol_points(roads: Array, spacing: float, offset: float) -> Array[Dictionary]:
	## Puntos de emboscada a lo largo de cada ruta, apartados del eje para que
	## queden en la linde y no plantados en mitad de la calzada.
	var out: Array[Dictionary] = []
	var seed := 0
	for road in roads:
		var polyline: Array = road
		for segment in range(polyline.size() - 1):
			var from: Vector2 = polyline[segment]
			var to: Vector2 = polyline[segment + 1]
			var span := to - from
			var length := span.length()
			if length < spacing:
				continue
			var steps := int(length / spacing)
			var direction := span / length
			var side := Vector2(-direction.y, direction.x)
			for step in range(1, steps):
				seed += 1
				var along := from + direction * (float(step) * spacing)
				var lateral := side * (offset + float(seed % 4) * 3.0) * (1.0 if seed % 2 == 0 else -1.0)
				out.append({"point": along + lateral, "seed": seed})
	return out
