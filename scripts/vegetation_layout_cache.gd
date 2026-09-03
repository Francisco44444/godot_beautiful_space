class_name VegetationLayoutCache
extends Resource

## Resultado horneado de las dos distribuciones costosas. El terreno y la
## semilla son deterministas, por lo que recalcularlos en cada arranque no aporta
## variación alguna y bloqueaba el primer fotograma durante unos cuarenta segundos.
## Se regenera ejecutando world.tscn con el argumento de usuario
## `--bake-vegetation` cuando cambien el terreno o los filtros de bioma.

@export var schema_version := 1
@export var signature := ""
@export var forest_records := PackedFloat32Array()
@export var grass_records := PackedFloat32Array()
@export var forest_rng_state := 0
@export var grass_rng_state := 0
@export var forest_counts: Dictionary = {}
