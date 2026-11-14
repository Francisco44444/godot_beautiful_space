class_name IslandMapView
extends Control

## Atlas de tinta sobre pergamino. El minimapa desplaza una textura retenida:
## el relieve y los caminos no se reconstruyen al caminar o girar.
const WORLD_HALF := 6000.0
const TAMANO_ATLAS := 2048
const ALCANCE_MINIMAPA := 1700.0
const FUENTE_TITULO: Font = preload("res://assets/fonts/cartografia/Cinzel.ttf")
const FUENTE_CARTA: Font = preload("res://assets/fonts/cartografia/CrimsonPro.ttf")
const TINTA := Color(0.23,0.19,0.13)
const TINTA_SUAVE := Color(0.37,0.32,0.23,0.65)
const PAPEL := Color(0.92,0.86,0.70)
const LACRE := Color(0.48,0.16,0.12)
const PARCHMENT: Texture2D = preload("res://assets/textures/ui/parchment_map_background.png")
const PARCHMENT_MASK_SHADER := """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec4 paper = texture(TEXTURE, UV);
    float luma = dot(paper.rgb,vec3(0.30,0.59,0.11));
    vec3 crema = mix(vec3(luma),paper.rgb,0.30)*vec3(1.12,1.09,1.0)+vec3(0.13,0.13,0.12);
    float alpha = smoothstep(0.018,0.075,max(paper.r,max(paper.g,paper.b)));
    COLOR = vec4(crema,paper.a*alpha);
}
"""
const ROADS: Array = [
	[Vector2(0, 190), Vector2(-120, 520), Vector2(-420, 760), Vector2(-980, 780), Vector2(-1450, 650)],
	[Vector2(0, 190), Vector2(80, -240), Vector2(320, -720), Vector2(40, -1320), Vector2(-420, -2150)],
	[Vector2(-1450, 650), Vector2(-1780, 230), Vector2(-2050, -420), Vector2(-2200, -900)],
	[Vector2(0, 190), Vector2(620, 320), Vector2(1260, 120), Vector2(1840, -420), Vector2(2260, -980)],
	[Vector2(620, 320), Vector2(1120, 820), Vector2(1660, 1320), Vector2(2180, 1880)],
	[Vector2(-1450, 650), Vector2(-1850, 1120), Vector2(-2180, 1650)],
	[Vector2(-420, -2150), Vector2(260, -2500), Vector2(720, -3080)],
	[Vector2(98, -110), Vector2(420, -420), Vector2(920, -560), Vector2(1840, -420)],
	[Vector2(2780, 1480), Vector2(3070, 1540), Vector2(3340, 1640), Vector2(3600, 1770), Vector2(3890, 1900)],
	[Vector2(2260, -980), Vector2(2860, -1120), Vector2(3480, -1320), Vector2(4140, -1260), Vector2(4920, -1080)],
]
const RIAS: Array = [
	[Vector2(-4780, -2100), Vector2(-4420, -1950), Vector2(-4090, -1640), Vector2(-3720, -1510), Vector2(-3360, -1740)],
	[Vector2(-4780, 2250), Vector2(-4380, 2040), Vector2(-3990, 2200), Vector2(-3610, 1880), Vector2(-3220, 1960)],
	[Vector2(-2550, -4480), Vector2(-2390, -4100), Vector2(-2070, -3820), Vector2(-1760, -3520), Vector2(-1600, -3180)],
]
const FOSSA_BRANCHES: Array = [
	[Vector2(2760, 620), Vector2(3060, 850), Vector2(3240, 1160), Vector2(3470, 1430), Vector2(3760, 1690), Vector2(4140, 1980), Vector2(4320, 2420), Vector2(4230, 2860)],
	[Vector2(3240, 1160), Vector2(3560, 980), Vector2(3920, 810), Vector2(4250, 920)],
	[Vector2(3470, 1430), Vector2(3310, 1770), Vector2(3420, 2160), Vector2(3710, 2380), Vector2(3990, 2710)],
	[Vector2(3760, 1690), Vector2(4050, 1510), Vector2(4350, 1580)],
	[Vector2(3420, 2160), Vector2(3130, 2450), Vector2(3060, 2820), Vector2(3280, 3090)],
]
const POINTS_OF_INTEREST: Array = [
	{"name": "Puerto Alba", "point": Vector2(0, 190), "kind": "village"},
	{"name": "Villa Robledal", "point": Vector2(-1450, 650), "kind": "castle"},
	{"name": "Aldea de la Bruma", "point": Vector2(-2200, -900), "kind": "village"},
	{"name": "Bastión del Este", "point": Vector2(2260, -980), "kind": "castle"},
	{"name": "Oasis Dorado", "point": Vector2(2180, 1880), "kind": "village"},
	{"name": "Castillo Boreal", "point": Vector2(-295, -2147), "kind": "castle"},
	{"name": "Bosque Umbrío", "point": Vector2(-2180, 1650), "kind": "forest"},
	{"name": "Cumbres Blancas", "point": Vector2(180, -3350), "kind": "mountain"},
	{"name": "Gruta del Acantilado", "point": Vector2(3600, 1770), "kind": "grotto"},
	{"name": "Bosque Tenebroso", "point": Vector2(4620, -1260), "kind": "mystery"},
]


class CartographyLayer:
	extends Control
	var map_view: Control
	func _draw() -> void:map_view._draw_cartography(self)

class MarginaliaLayer:
	extends Control
	var mapa: Control
	func _draw() -> void:mapa._dibujar_marco(self)

var _cartography: Control
var _drawing: CanvasItem
var _marco: Control
var _velo: ColorRect
var _atlas: SubViewport
var _ventana: Control
var _imagen_atlas: TextureRect
var _foco := Vector2.ZERO
var _destino_actual: Dictionary = {}
var _cached_tide := NAN
var _cached_size := Vector2.ZERO
var _cached_full_map := false
var _cached_caves := -1
var _static_redraw_count := 0
var _rotulos_ocupados: Array[Rect2] = []

@export var player_path: NodePath = NodePath("../../Player")
@export var full_map := false
@onready var player: Node3D = get_node_or_null(player_path) as Node3D
@onready var island_environment: Node = get_node_or_null("../../IslandEnvironment")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_install_parchment_background()
	_velo=ColorRect.new()
	_velo.name="FondoDeLectura"
	_velo.color=Color(0.025,0.03,0.025,0.55)
	_velo.z_index=-2
	_velo.show_behind_parent=true
	_velo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_velo)
	_atlas=SubViewport.new()
	_atlas.name="AtlasRetenido"
	_atlas.size=Vector2i(2,2) if full_map else Vector2i(TAMANO_ATLAS,TAMANO_ATLAS)
	_atlas.disable_3d=true
	_atlas.transparent_bg=true
	_atlas.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(_atlas)
	_ventana=Control.new()
	_ventana.name="VentanaCartografica"
	_ventana.clip_contents=true
	_ventana.show_behind_parent=true
	_ventana.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_ventana)
	_imagen_atlas=TextureRect.new()
	_imagen_atlas.texture=_atlas.get_texture()
	_imagen_atlas.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_imagen_atlas.size=Vector2(TAMANO_ATLAS,TAMANO_ATLAS)
	_imagen_atlas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_ventana.add_child(_imagen_atlas)
	_cartography=CartographyLayer.new()
	_cartography.name="Cartography"
	_cartography.map_view=self
	_cartography.show_behind_parent=true
	_cartography.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_cartography)
	_marco=MarginaliaLayer.new()
	_marco.name="OrlaYLeyenda"
	_marco.mapa=self
	_marco.show_behind_parent=true
	_marco.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_marco)
	resized.connect(_invalidate_cartography)
	if full_map:
		get_viewport().size_changed.connect(_ajustar_a_ventana)
		_ajustar_a_ventana()
	_invalidate_cartography()
	set_meta("ocean_fills_exterior",true)
	set_meta("false_beach_border_removed",true)
	set_meta("rotating_player_marker",true)
	set_meta("rectangular_map_tint_removed",true)
	set_meta("parchment_edge_is_transparent",true)
	queue_redraw()

func _ajustar_a_ventana() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	var disponible:=get_viewport_rect().size-Vector2(32,32)
	var medidas:=Vector2(minf(1080,disponible.x),minf(760,disponible.y))
	offset_left=-medidas.x*0.5;offset_right=medidas.x*0.5
	offset_top=-medidas.y*0.5;offset_bottom=medidas.y*0.5
	if _cartography!=null:_invalidate_cartography()

func _process(_delta: float) -> void:
	if not is_visible_in_tree():return
	var tide:=_tide_amount()
	var caves:=get_tree().get_nodes_in_group("explorable_cave").size()
	if size!=_cached_size or full_map!=_cached_full_map or absf(tide-_cached_tide)>0.02 or caves!=_cached_caves:
		_invalidate_cartography()
	_actualizar_foco()
	queue_redraw()

func _actualizar_foco() -> void:
	_foco=Vector2(player.global_position.x,player.global_position.z) if player!=null else Vector2.ZERO
	if not full_map and _imagen_atlas!=null:
		var escala:=_pixeles_por_metro()/(float(TAMANO_ATLAS)/(WORLD_HALF*2.0))
		_imagen_atlas.scale=Vector2.ONE*escala
		_imagen_atlas.position=_ventana.size*0.5-_punto_atlas(_foco)*escala

func _invalidate_cartography() -> void:
	_cached_size=size;_cached_full_map=full_map;_cached_tide=_tide_amount()
	_cached_caves=get_tree().get_nodes_in_group("explorable_cave").size()
	if _cartography==null:return
	var destino: Node=self if full_map else _atlas
	if _cartography.get_parent()!=destino:_cartography.reparent(destino,false)
	_cartography.size=size if full_map else Vector2(TAMANO_ATLAS,TAMANO_ATLAS)
	_ventana.visible=not full_map
	_velo.visible=full_map
	_velo.position=-global_position
	_velo.size=get_viewport_rect().size
	_atlas.size=Vector2i(2,2) if full_map else Vector2i(TAMANO_ATLAS,TAMANO_ATLAS)
	var zona:=_rectangulo_mapa()
	_ventana.position=zona.position;_ventana.size=zona.size
	_cartography.queue_redraw()
	_marco.queue_redraw()
	_atlas.render_target_update_mode=SubViewport.UPDATE_DISABLED if full_map else SubViewport.UPDATE_ONCE
	_actualizar_foco()

func get_road_count() -> int:return ROADS.size()
func get_poi_count() -> int:return POINTS_OF_INTEREST.size()

func _draw() -> void:
	_drawing=self
	_draw_exploration_target()
	_draw_player()
	var pie:="M · cerrar carta" if full_map else "M · Carta   B · Ocultar"
	var base:=Vector2(48,size.y-34) if full_map else Vector2(14,size.y-12)
	_rotulo(pie,base,16 if full_map else 13)
	if full_map:
		_rotulo("Pleamar" if _tide_amount()>0.58 else "Bajamar",Vector2(size.x-135,size.y-34),16)
		var destino:Dictionary=_destino_actual
		if not destino.is_empty():
			var texto:="Destino: "+String(destino.name)
			var espacio:=maxf(size.x-390,60)
			while texto.length()>4 and FUENTE_CARTA.get_string_size(texto,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>espacio:
				texto=texto.left(-2)+"…"
			_rotulo(texto,Vector2(208,size.y-34),15)


func _draw_cartography(layer: CanvasItem) -> void:
	_drawing=layer
	_static_redraw_count+=1
	_rotulos_ocupados.clear()
	_draw_sea_marks()
	_draw_island()
	_draw_biomes()
	_draw_contours_and_symbols()
	_draw_rias_and_fossa()
	_draw_roads()
	_draw_points_of_interest()
	_draw_cave_entrances()

func _install_parchment_background() -> void:
	var fondo:=TextureRect.new()
	fondo.name="ParchmentBackground";fondo.texture=PARCHMENT
	fondo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode=TextureRect.STRETCH_SCALE
	fondo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fondo.show_behind_parent=true;fondo.z_index=-1
	var shader:=Shader.new();shader.code=PARCHMENT_MASK_SHADER
	var material:=ShaderMaterial.new();material.shader=shader;fondo.material=material
	add_child(fondo);fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _rectangulo_mapa() -> Rect2:
	if not full_map:return Rect2(12,32,maxf(size.x-24,1),maxf(size.y-58,1))
	return Rect2(42,94,maxf(size.x-(270 if _con_leyenda() else 84),1),maxf(size.y-166,1))

func _con_leyenda() -> bool:return full_map and size.x>=820 and size.y>=620
func _pixeles_por_metro() -> float:
	return _rectangulo_mapa().size.y/ALCANCE_MINIMAPA
func _punto_atlas(punto: Vector2) -> Vector2:
	return Vector2.ONE*TAMANO_ATLAS*0.5+punto*(float(TAMANO_ATLAS)/(WORLD_HALF*2.0))
func _world_to_map(world_point: Vector2) -> Vector2:
	var zona:=_rectangulo_mapa()
	if not full_map:return zona.get_center()+(world_point-_foco)*_pixeles_por_metro()
	return zona.get_center()+world_point*(minf(zona.size.x,zona.size.y)/(WORLD_HALF*2.0))
func _carta(punto: Vector2) -> Vector2:
	return _world_to_map(punto) if full_map else _punto_atlas(punto)

func _rotulo(texto: String,punto: Vector2,tamano: int,centrado: bool=false,color: Color=TINTA,fuente: Font=FUENTE_CARTA) -> void:
	if centrado:punto.x-=fuente.get_string_size(texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamano).x*0.5
	_drawing.draw_string_outline(fuente,punto,texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamano,2,Color(PAPEL,0.85))
	_drawing.draw_string(fuente,punto,texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamano,color)

func _dibujar_marco(capa: CanvasItem) -> void:
	_drawing=capa
	var borde:=Rect2(Vector2(19,18),size-Vector2(38,36)) if full_map else Rect2(Vector2(6,5),size-Vector2(12,10))
	_drawing.draw_rect(borde,Color(TINTA,0.52),false,1.0)
	if full_map:
		_drawing.draw_rect(borde.grow(-4),Color(TINTA,0.22),false,1.0)
		_rotulo("Senderos del Horizonte",Vector2(size.x*0.5,54),27,true,TINTA,FUENTE_TITULO)
		_rotulo("CARTA DE AELORIA  ·  TIERRAS, CAMINOS Y REFUGIOS",Vector2(size.x*0.5,77),13,true,TINTA_SUAVE)
		_drawing.draw_line(Vector2(48,87),Vector2(size.x-48,87),Color(TINTA,0.35),1.0,true)
		_drawing.draw_line(Vector2(48,size.y-58),Vector2(size.x-48,size.y-58),Color(TINTA,0.35),1.0,true)
		if _con_leyenda():_dibujar_leyenda()
		else:_draw_compass_rose(Vector2(size.x-78,140),23)
		var zona:=_rectangulo_mapa()
		var ancho:=2000.0*(minf(zona.size.x,zona.size.y)/(WORLD_HALF*2.0))
		var inicio:=Vector2(zona.position.x+12,zona.end.y-6)
		_drawing.draw_line(inicio,inicio+Vector2(ancho,0),TINTA,1.5,true)
		for t in [0.0,0.5,1.0]:_drawing.draw_line(inicio+Vector2(ancho*t,-3),inicio+Vector2(ancho*t,3),TINTA,1.0,true)
		_rotulo("0",inicio+Vector2(0,-8),12,true)
		_rotulo("1",inicio+Vector2(ancho*.5,-8),12,true)
		_rotulo("2 km",inicio+Vector2(ancho,-8),12,true)
	else:
		_rotulo("Aeloria",Vector2(14,24),14,false,TINTA,FUENTE_TITULO)
		_rotulo("N",Vector2(size.x-24,24),13,false,LACRE,FUENTE_TITULO)
		_drawing.draw_line(Vector2(12,29),Vector2(size.x-12,29),Color(TINTA,0.35),1.0)

func _dibujar_leyenda() -> void:
	var x:=size.x-206
	_drawing.draw_line(Vector2(x-12,108),Vector2(x-12,size.y-78),Color(TINTA,0.24),1.0,true)
	_draw_compass_rose(Vector2(x+74,170),42)
	_rotulo("SIGNOS DE LA CARTA",Vector2(x,254),13,false,TINTA,FUENTE_TITULO)
	var filas:=[['village','Villa y refugio'],['castle','Fortaleza'],['grotto','Gruta explorable'],['forest','Bosque'],['mountain','Cumbres']]
	for i in filas.size():
		var centro:=Vector2(x+8,282+i*30)
		_simbolo(filas[i][0],centro,7)
		_rotulo(filas[i][1],centro+Vector2(20,5),17)
	var y:=minf(size.y-170,464)
	_drawing.draw_line(Vector2(x,y),Vector2(size.x-44,y),Color(TINTA,0.25),1.0)
	_rotulo("TU EXPEDICIÓN",Vector2(x,y+27),13,false,TINTA,FUENTE_TITULO)
	_drawing.draw_colored_polygon(PackedVector2Array([Vector2(x+8,y+42),Vector2(x+3,y+57),Vector2(x+13,y+57)]),LACRE)
	_rotulo("Posición y rumbo",Vector2(x+28,y+54),16)
	_drawing.draw_arc(Vector2(x+8,y+78),6,0,TAU,20,LACRE,1.4,true)
	_rotulo("Destino del diario",Vector2(x+28,y+83),16)

func _draw_island() -> void:
	var isla:=_island_polygon(1.0)
	for distancia in [4.0,9.0]:
		for costa in Geometry2D.offset_polygon(isla,distancia):
			_drawing.draw_polyline(costa+PackedVector2Array([costa[0]]),Color(0.32,0.41,0.41,0.25),0.8,true)
	_drawing.draw_colored_polygon(isla,Color(0.67,0.71,0.49,0.29))
	_drawing.draw_polyline(isla+PackedVector2Array([isla[0]]),Color(TINTA,0.90),1.5 if full_map else 2.5,true)

func _draw_biomes() -> void:
	_draw_world_blob(Vector2(3060,2480),Vector2(2350,1450),Color(0.71,0.53,0.27,0.20),2.4)
	_draw_world_blob(Vector2(120,-3850),Vector2(2500,1250),Color(0.89,0.88,0.77,0.67),6.1)
	_draw_world_blob(Vector2(-2550,1150),Vector2(1650,1650),Color(0.27,0.36,0.23,0.13),3.7)
	_draw_world_blob(Vector2(-2700,-1050),Vector2(1450,1900),Color(0.27,0.36,0.23,0.12),8.2)
	_draw_world_blob(Vector2(720,-1450),Vector2(1050,1350),Color(0.29,0.38,0.24,0.12),5.5)
	_draw_world_blob(Vector2(-2860,-2250),Vector2(1320,980),Color(0.37,0.34,0.28,0.15),1.9)
	_draw_world_blob(Vector2(2700,-2380),Vector2(1240,980),Color(0.37,0.34,0.28,0.15),9.1)
	_draw_world_blob(Vector2(-820,3000),Vector2(1650,980),Color(0.37,0.34,0.28,0.15),7.2)
	_draw_world_blob(Vector2(4380,-1420),Vector2(1720,1420),Color(0.22,0.27,0.26,0.22),4.3)

func _draw_world_blob(center: Vector2,radii: Vector2,color: Color,seed: float) -> void:
	var puntos:=PackedVector2Array()
	for i in 64:
		var angulo:=TAU*float(i)/64.0
		var radio:=1.0+sin(angulo*3+seed)*0.12+sin(angulo*7-seed*0.63)*0.065
		puntos.append(_carta(center+Vector2(cos(angulo)*radii.x,sin(angulo)*radii.y)*radio))
	for recorte in Geometry2D.intersect_polygons(puntos,_island_polygon(0.985)):
		if recorte.size()>=3:_drawing.draw_colored_polygon(recorte,color)

func _draw_rias_and_fossa() -> void:
	for ria in RIAS:
		var puntos:=PackedVector2Array()
		for p in ria:puntos.append(_carta(p))
		_drawing.draw_polyline(puntos,Color(0.32,0.42,0.43,0.68),(3.0 if full_map else 6.0)+_tide_amount(),true)
	for rama in FOSSA_BRANCHES:
		var puntos:=PackedVector2Array()
		for p in rama:puntos.append(_carta(p))
		_drawing.draw_polyline(puntos,Color(TINTA,0.8),2.4 if full_map else 5.0,true)
		_drawing.draw_polyline(puntos,Color(0.74,0.57,0.36,0.8),0.8 if full_map else 1.6,true)

func _draw_roads() -> void:
	for camino in ROADS:
		var puntos:=PackedVector2Array()
		for p in camino:puntos.append(_carta(p))
		_drawing.draw_polyline(puntos,Color(PAPEL,0.85),3.2 if full_map else 5.0,true)
		for i in range(puntos.size()-1):
			_drawing.draw_dashed_line(puntos[i],puntos[i+1],Color(TINTA,0.85),1.15 if full_map else 2.0,4.0 if full_map else 7.0,true)

func _draw_points_of_interest() -> void:
	var offsets:={"Castillo Boreal":Vector2(-128,4),"Cumbres Blancas":Vector2(-55,-27),"Bosque Tenebroso":Vector2(-164,-17),"Gruta del Acantilado":Vector2(-95,37)}
	for poi in POINTS_OF_INTEREST:
		var punto:=_carta(poi.point)
		_simbolo(poi.kind,punto,7 if full_map else 10)
		if full_map:
			var posicion:Vector2=punto+offsets.get(poi.name,Vector2(12,-10))
			_rotulo_lugar(poi.name,punto,posicion-punto,17)

func _draw_cave_entrances() -> void:
	if get_tree()==null:return
	for cave in get_tree().get_nodes_in_group("explorable_cave"):
		var punto:=_carta(Vector2(cave.global_position.x,cave.global_position.z))
		_simbolo("grotto",punto,6 if full_map else 10)
		if full_map:_rotulo_lugar(String(cave.spec.name),punto,Vector2(10,20),15)

func _simbolo(tipo: String,punto: Vector2,r: float) -> void:
	match tipo:
		"forest","mystery":_draw_tree_symbol(punto,r,tipo=="mystery")
		"mountain":_draw_mountain_symbol(punto,r)
		"grotto":
			_drawing.draw_arc(punto+Vector2(0,r*0.4),r,PI,TAU,16,TINTA,1.5,true)
			_drawing.draw_line(punto+Vector2(-r,r*0.4),punto+Vector2(r,r*0.4),TINTA,1.2,true)
		_:
			_drawing.draw_rect(Rect2(punto+Vector2(-r,-r*.45),Vector2(r*2,r*1.2)),PAPEL)
			_drawing.draw_rect(Rect2(punto+Vector2(-r,-r*.45),Vector2(r*2,r*1.2)),TINTA,false,1.2)
			if tipo=="castle":
				for x in [-1,0,1]:_drawing.draw_rect(Rect2(punto+Vector2(x*r*.75-r*.22,-r),Vector2(r*.44,r*.65)),TINTA)
			else:
				_drawing.draw_polyline(PackedVector2Array([punto+Vector2(-r*1.2,-r*.4),punto+Vector2(0,-r*1.2),punto+Vector2(r*1.2,-r*.4)]),TINTA,1.4,true)

func _draw_contours_and_symbols() -> void:
	var costa:=_island_polygon(0.96)
	for centro in [Vector2(-2180,1650),Vector2(-3300,650),Vector2(-2700,-900),Vector2(760,-1550),Vector2(3900,-1250),Vector2(4650,-1650),Vector2(5050,-650)]:
		for fila in 3:
			for columna in 4:
				var p:Vector2=_carta(centro+Vector2((columna-1.5)*270+(fila%2)*110,(fila-1)*240))
				if Geometry2D.is_point_in_polygon(p,costa):_draw_tree_symbol(p,5 if full_map else 11,centro.x>3500)
	for centro in [Vector2(120,-3700),Vector2(-2850,-2200),Vector2(2700,-2350),Vector2(-980,2940)]:
		for i in 7:
			var p:Vector2=_carta(centro+Vector2((i-3)*310,sin(i*1.7)*210))
			if Geometry2D.is_point_in_polygon(p,costa):_draw_mountain_symbol(p,(7 if full_map else 14)+posmod(i,3)*1.5)

func _draw_mountain_symbol(p: Vector2,r: float) -> void:
	var pico:=p+Vector2(0,-r)
	_drawing.draw_colored_polygon(PackedVector2Array([p+Vector2(-r,r*.55),pico,p+Vector2(r,r*.55)]),Color(PAPEL,0.5))
	_drawing.draw_polyline(PackedVector2Array([p+Vector2(-r,r*.55),pico,p+Vector2(r,r*.55)]),Color(TINTA,0.75),1.0,true)
	_drawing.draw_line(pico,p+Vector2(-r*.22,r*.4),Color(TINTA,0.5),0.8,true)
	for i in 4:
		var inicio:=p+Vector2(r*(.12+i*.14),-r*.65+i*r*.25)
		_drawing.draw_line(inicio,inicio+Vector2(-r*.18,r*.6),Color(TINTA,0.4),0.7,true)

func _draw_tree_symbol(p: Vector2,r: float,mystery: bool) -> void:
	var tinta:=Color(0.20,0.25,0.21,0.8 if mystery else 0.62)
	_drawing.draw_line(p+Vector2(0,-r*.7),p+Vector2(0,r),tinta,0.8,true)
	for i in 3:
		var alto:=-r*.7+i*r*.42
		var ancho:=r*(.28+i*.16)
		_drawing.draw_polyline(PackedVector2Array([p+Vector2(-ancho,alto+r*.55),p+Vector2(0,alto),p+Vector2(ancho,alto+r*.55)]),tinta,1.0,true)

func _draw_sea_marks() -> void:
	var dimensiones:=size if full_map else Vector2(TAMANO_ATLAS,TAMANO_ATLAS)
	var isla:=_island_polygon(1.05)
	var zona:=_rectangulo_mapa() if full_map else Rect2(Vector2.ZERO,dimensiones)
	for fila in 9:
		for columna in 13:
			var p:=zona.position+Vector2((columna+.5)*zona.size.x/13,(fila+.5)*zona.size.y/9)
			if Geometry2D.is_point_in_polygon(p,isla):continue
			var r:=4.0 if full_map else 9.0
			_drawing.draw_arc(p,r,PI*.15,PI*.85,8,Color(0.27,0.38,0.40,0.2),0.8,true)

func _draw_compass_rose(c: Vector2,r: float) -> void:
	_drawing.draw_arc(c,r*.87,0,TAU,64,Color(TINTA,0.55),1.0,true)
	_drawing.draw_arc(c,r,0,TAU,64,Color(TINTA,0.35),0.8,true)
	for i in 8:
		var d:=Vector2.UP.rotated(i*TAU/8)
		var lado:=d.orthogonal()
		var largo:=r*(1.0 if i%2==0 else .63)
		_drawing.draw_colored_polygon(PackedVector2Array([c,c+d*largo,c+lado*r*.13]),LACRE if i==0 else TINTA)
		_drawing.draw_colored_polygon(PackedVector2Array([c,c+d*largo,c-lado*r*.13]),Color(PAPEL,0.8))
	for letra in [["N",Vector2(0,-r-7)],["S",Vector2(0,r+17)],["O",Vector2(-r-13,5)],["E",Vector2(r+13,5)]]:
		_rotulo(letra[0],c+letra[1],14,true,TINTA,FUENTE_TITULO)

func _rotulo_lugar(texto: String,origen: Vector2,preferido: Vector2,tamano: int) -> void:
	# Resolver una vez al invalidar la carta. Las grutas añadidas después del
	# HUD también reservan espacio: sus nombres antes se pisaban con el bosque.
	var ancho:=FUENTE_CARTA.get_string_size(texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamano).x
	var alto:=FUENTE_CARTA.get_ascent(tamano)
	var limites:=_rectangulo_mapa().grow(-2)
	var alternativas:=[preferido,Vector2(12,-10),Vector2(12,23),Vector2(-ancho-12,-10),Vector2(-ancho-12,23),Vector2(12,43),Vector2(-ancho-12,43),Vector2(12,-34),Vector2(-ancho-12,-34),Vector2(-ancho*.5,-52),Vector2(-ancho*.5,62)]
	var elegido:=origen+preferido
	var caja:=Rect2(elegido-Vector2(2,alto+2),Vector2(ancho+4,alto+7))
	for alternativa:Vector2 in alternativas:
		var punto:=origen+alternativa
		var candidata:=Rect2(punto-Vector2(2,alto+2),Vector2(ancho+4,alto+7))
		var ocupado:=false
		for otra in _rotulos_ocupados:
			if candidata.intersects(otra.grow(3)):ocupado=true;break
		if not ocupado and limites.encloses(candidata):
			elegido=punto;caja=candidata;break
	_rotulos_ocupados.append(caja)
	if elegido.distance_to(origen)>28:
		var cerca:=origen.clamp(caja.position,caja.end)
		_drawing.draw_line(origen,cerca,Color(TINTA,0.42),0.7,true)
	_rotulo(texto,elegido,tamano)

func _draw_player() -> void:
	if player==null:return
	var punto:=_world_to_map(Vector2(player.global_position.x,player.global_position.z))
	var rumbo:=_player_map_direction()
	var lado:=rumbo.orthogonal()
	var r:=8.0 if full_map else 6.0
	_drawing.draw_circle(punto,r+3,Color(PAPEL,0.95))
	var flecha:=PackedVector2Array([punto+rumbo*r*1.5,punto-rumbo*r*.8+lado*r*.7,punto-rumbo*r*.35,punto-rumbo*r*.8-lado*r*.7])
	_drawing.draw_colored_polygon(flecha,LACRE)
	_drawing.draw_polyline(flecha+PackedVector2Array([flecha[0]]),TINTA,1.0,true)

func _draw_exploration_target() -> void:
	var diario:=get_node_or_null("/root/ExplorationManager")
	_destino_actual=diario.call("get_selected_zone") if diario!=null else {}
	var zona:Dictionary=_destino_actual
	if zona.is_empty():return
	var destino:Vector3=zona.position
	var p:=_world_to_map(Vector2(destino.x,destino.z))
	if not full_map:
		var limites:=_rectangulo_mapa().grow(-9)
		p=p.clamp(limites.position,limites.end)
	var pulso:=sin(Time.get_ticks_msec()*.004)*.5+.5
	_drawing.draw_circle(p,5,Color(PAPEL,.9))
	_drawing.draw_arc(p,(10.0 if full_map else 6.0)+pulso*2,0,TAU,32,LACRE,1.5,true)
	_drawing.draw_circle(p,2.2,LACRE)

func _player_map_direction() -> Vector2:
	if player!=null and player.has_method("get_facing_direction_xz"):return (player.call("get_facing_direction_xz") as Vector2).normalized()
	return Vector2.UP

func _island_polygon(ratio: float) -> PackedVector2Array:
	var puntos:=PackedVector2Array()
	for i in 120:
		var angulo:=TAU*float(i)/120.0
		puntos.append(_carta(Vector2(cos(angulo),sin(angulo))*_coast_radius_at_angle(angulo)*ratio))
	return puntos

func _tide_amount() -> float:
	return float(island_environment.get("tide_normalized")) if island_environment!=null else 0.5

func _coast_radius_at_angle(angle: float) -> float:
	var cosine := cos(angle)
	var sine := sin(angle)
	var ellipse_radius := 1.0 / sqrt((cosine * cosine) / (4740.0 * 4740.0) + (sine * sine) / (4540.0 * 4540.0))
	var mystery_angle := atan2(sin(angle + 0.27), cos(angle + 0.27))
	var extension := 1200.0 * exp(-(mystery_angle * mystery_angle) / (2.0 * 0.27 * 0.27))
	var desert_angle := atan2(sin(angle - 0.50), cos(angle - 0.50))
	var desert_shoulder := 420.0 * exp(-(desert_angle * desert_angle) / (2.0 * 0.32 * 0.32))
	var north_neck_angle := atan2(sin(angle + 0.82), cos(angle + 0.82))
	var north_inlet := 350.0 * exp(-(north_neck_angle * north_neck_angle) / (2.0 * 0.20 * 0.20))
	var south_neck_angle := atan2(sin(angle - 0.04), cos(angle - 0.04))
	var south_inlet := 430.0 * exp(-(south_neck_angle * south_neck_angle) / (2.0 * 0.18 * 0.18))
	var wobble := sin(angle * 7.0) * 0.018 + sin(angle * 13.0 + 0.7) * 0.009
	return (ellipse_radius + extension + desert_shoulder - north_inlet - south_inlet) / (1.0 + wobble)
