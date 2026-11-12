class_name Player
extends CharacterBody3D

## Aventurero Quaternius en tercera persona con inventario rápido, combate
## cuerpo a cuerpo y objetos Survival Pack unidos al hueso de la mano.

signal mount_state_changed(mounted: bool, horse: Horse)
signal attack_started(combo_index: int)
signal melee_hit(target: Node)
signal equipment_changed(slot: int, item_name: String)
signal action_feedback(message: String)
signal bow_draw_changed(strength: float, arrows: int)
signal arrow_fired(remaining_arrows: int, strength: float)
signal charge_changed(strength: float, spin_ready: bool)
signal stamina_changed(current: float, maximum: float)
signal vitals_grown(health_bonus: int, stamina_bonus: int)
signal spin_attack_started()
signal dodge_started(direction: Vector3)
signal guard_changed(guarding: bool)
signal weapon_stowed(on_back: bool)
signal gesture_started(animation_name: String)
signal gesture_finished(animation_name: String)

enum ControlState {
	ON_FOOT,
	MOUNTED,
}

enum AttackPhase {
	NONE,
	CHARGING,
	SLASH,
	SPIN,
}

const OBJ_LOADER: Script = preload("res://scripts/quaternius_obj_loader.gd")
const ARROW_SCRIPT: Script = preload("res://scripts/adventure_arrow.gd")
const CHARGE_EFFECT_SCRIPT: Script = preload("res://scripts/weapon_charge_effect.gd")
const ARCHER_ARMS_SCRIPT: Script = preload("res://scripts/archer_arms_modifier.gd")
const WEAPON_ARM_SCRIPT: Script = preload("res://scripts/weapon_arm_modifier.gd")
const CHARGE_STORM_SCRIPT: Script = preload("res://scripts/charge_storm.gd")
const LIBRARY_ANIMATION_SCRIPT: Script = preload("res://scripts/library_animation.gd")
const NETWORK_MOTION_SCRIPT: Script = preload("res://scripts/network_motion.gd")
## Animaciones tomadas de la Universal Animation Library 2. Sustituyen a las de
## Quaternius allí donde esta trae un gesto mucho mejor: el rig no tiene ninguna
## pose de escudo ni un tajo de espada decente.
const LIB_GUARD := "Idle_Shield_Loop"
const LIB_SLASH_A := "Sword_Regular_A"
const LIB_SLASH_B := "Sword_Regular_B"
const LIB_SLASH_C := "Sword_Regular_C"
const UMBRAL_ATAQUE_MANTENIDO := 0.35
## Gesto del que sale la postura de recarga por defecto. El fotograma concreto
## y el gesto son ajustables (`charge_pose_animation` / `charge_pose_time`):
## dar con una pose que se lea bien es cuestión de probarlas.
const LIB_HEAVY := "Sword_Heavy_Combo"
## Hueso del encogimiento. El eje va en el sistema del esqueleto de Quaternius,
## donde +X apunta al costado izquierdo del héroe: girar sobre él lleva el eje
## vertical hacia el frente, que es la flexión que se busca.
const TUCK_BONE := "Abdomen"
const GUARD_TUCK_AXIS := Vector3.RIGHT
## Huesos que recibe la postura de recarga: solo el brazo armado.
const CHARGE_ARM_BONES: PackedStringArray = [
	"Shoulder.R", "UpperArm.R", "LowerArm.R", "Fist.R",
]
## Hueso y eje sobre los que se abre el brazo armado al cargar. El fotograma de
## la biblioteca lleva el húmero por encima del hombro pero pegado a la línea
## media, y con la cabeza de este modelo —muy grande— el brazo la atravesaba: el
## tramo hombro-codo pasaba a 0.23 m del centro del cráneo. Girando el húmero
## sobre el eje frontal del esqueleto, el codo se abre al costado.
## Cadena que se pone recta al cargar: húmero, cúbito y muñeca.
## Cadenas que se posan al cargar: el brazo armado y el libre.
const CHARGE_RAISE_CHAIN: PackedStringArray = ["UpperArm.R", "LowerArm.R", "Fist.R"]
## El brazo libre se posa en dos tramos independientes: al húmero se le da una
## dirección y al antebrazo otra. Doblarlo con un ángulo sobre un eje no daba
## posiciones intermedias —el puño saltaba de pegado al cuerpo a un brazo de
## distancia sin nada en medio—, y hacía falta poder colocarlo.
const CHARGE_FREE_UPPER: PackedStringArray = ["UpperArm.L", "LowerArm.L"]
const CHARGE_FREE_LOWER: PackedStringArray = ["LowerArm.L", "Fist.L"]
## Hueso que gira el tronco al acumular fuerza.
const CHARGE_TWIST_BONE := "Torso"
## Movimiento de envainado. El arranque de `Sword_Regular_A` sube el brazo y lo
## echa por detrás del hombro —0.41 m a su espalda y 0.33 m por encima en el
## fotograma 0.40, medido—, que es justo el gesto de meter la espada atrás. Se
## recorre ese tramo mientras la malla viaja al agarre de la espalda, y al revés
## al desenvainar, así que el arma ya no se teletransporta.
const LIB_SHEATH := "Sword_Regular_A"
const LIB_TORCH_IDLE := "Idle_Lantern_Loop"
const LIB_FOLD_ARMS := "Idle_FoldArms_Loop"
const LIB_PUNCH := "Melee_Hook"
const LIB_HURT := "Hit_Knockback"
const LIB_GUARD_BREAK := "Idle_Shield_Break"
const LIB_SWORD_BLOCK := "Sword_Block"
const LIB_CHOP := "TreeChopping_Loop"
## Fotograma más cerrado de `Sword_Block`: la cabeza baja 0.29 m tras la hoja.
const SWORD_BLOCK_TIME := 0.32

## Catálogo completo de la Universal Animation Library 2 sobre el rig del héroe.
## Las 43 entradas están retargeteadas y disponibles: las que tienen un disparo
## natural en el juego salen solas —tajos, guardia, salto, tala, siega, cofres,
## golpes recibidos—, y cualquiera se puede pedir por nombre con `play_gesture`.
##
## `piernas` separa los gestos que se apoderan del tren inferior —el héroe se
## queda quieto ejecutándolos— de los que solo mueven el tronco y permiten
## seguir andando. `ritmo` corrige las que la biblioteca trae demasiado lentas
## para el juego.
const GESTURES := {
	# --- Espada ---
	"Sword_Regular_A": {"piernas": false, "ritmo": 1.0},
	"Sword_Regular_A_Rec": {"piernas": false, "ritmo": 1.1},
	"Sword_Regular_B": {"piernas": false, "ritmo": 1.0},
	"Sword_Regular_B_Rec": {"piernas": false, "ritmo": 1.1},
	"Sword_Regular_C": {"piernas": false, "ritmo": 1.15},
	"Sword_Regular_Combo": {"piernas": false, "ritmo": 1.1},
	"Sword_Heavy_Combo": {"piernas": false, "ritmo": 1.0},
	"Sword_Block": {"piernas": false, "ritmo": 1.0},
	"Sword_Dash": {"piernas": true, "ritmo": 1.2},
	# --- Escudo y cuerpo a cuerpo ---
	"Idle_Shield": {"piernas": false, "ritmo": 1.0},
	"Idle_Shield_Break": {"piernas": false, "ritmo": 1.0},
	"Shield_OneShot": {"piernas": false, "ritmo": 1.1},
	"Shield_Dash": {"piernas": true, "ritmo": 1.15},
	"Melee_Hook": {"piernas": false, "ritmo": 1.0},
	"Melee_Hook_Rec": {"piernas": false, "ritmo": 1.0},
	"Hit_Knockback": {"piernas": true, "ritmo": 1.0},
	"OverhandThrow": {"piernas": false, "ritmo": 1.1},
	# --- Desplazamiento ---
	"NinjaJump_Start": {"piernas": true, "ritmo": 1.35},
	"NinjaJump_Idle": {"piernas": true, "ritmo": 1.0},
	"NinjaJump_Land": {"piernas": true, "ritmo": 1.25},
	"Slide_Start": {"piernas": true, "ritmo": 1.2},
	"Slide": {"piernas": true, "ritmo": 1.0},
	"Slide_Exit": {"piernas": true, "ritmo": 1.2},
	"ClimbUp_1m": {"piernas": true, "ritmo": 1.0},
	"LayToIdle": {"piernas": true, "ritmo": 1.0},
	"Walk_Carry": {"piernas": true, "ritmo": 1.0},
	# --- Oficios y objetos ---
	"TreeChopping": {"piernas": false, "ritmo": 1.15},
	"Farm_Harvest": {"piernas": true, "ritmo": 1.1},
	"Farm_PlantSeed": {"piernas": true, "ritmo": 1.0},
	"Farm_Watering": {"piernas": true, "ritmo": 1.0},
	"Chest_Open": {"piernas": true, "ritmo": 1.0},
	"Consume": {"piernas": false, "ritmo": 1.0},
	# --- Reposos y conversación ---
	"Idle_FoldArms": {"piernas": false, "ritmo": 1.0},
	"Idle_Lantern": {"piernas": false, "ritmo": 1.0},
	"Idle_No": {"piernas": false, "ritmo": 1.0},
	"Idle_Rail": {"piernas": true, "ritmo": 1.0},
	"Idle_Rail_Call": {"piernas": true, "ritmo": 1.0},
	"Idle_TalkingPhone": {"piernas": false, "ritmo": 1.0},
	"Yes": {"piernas": false, "ritmo": 1.0},
	# --- Criaturas y referencia ---
	"Zombie_Idle": {"piernas": true, "ritmo": 1.0},
	"Zombie_Walk_Fwd": {"piernas": true, "ritmo": 1.0},
	"Zombie_Scratch": {"piernas": true, "ritmo": 1.0},
	"A_TPose": {"piernas": true, "ritmo": 1.0},
}
const SURVIVAL_OBJ_ROOT := "res://assets/quaternius/Survival Pack - Sept 2020/OBJ/"
const CHARACTER_PATHS: Array[String] = [
	"res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Male.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Female.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Knight_Male.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Knight_Golden_Female.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Viking_Male.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Viking_Female.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Elf.gltf",
	"res://assets/quaternius/ultimate_animated_characters/glTF/Witch.gltf",
]
## Agarres medidos sobre la geometría real de cada OBJ de Quaternius.
## `grip_point` es el punto de la malla que el puño abraza (unidades de la malla,
## antes de escalar) y `grip_euler_degrees` gira la malla dentro del sistema
## local del hueso `Fist`: su eje Y recorre los dedos y su eje Z atraviesa el
## puño igual que lo haría una empuñadura. Al describir el agarre en el hueso y
## no en el mundo, el arma hereda la rotación real de la mano en cada fotograma
## y deja de parecer atada al antebrazo.
const HAND_GRIP_OFFSET := Vector3(0.0, 0.105, 0.0)
const EQUIPMENT_SPECS: Dictionary = {
	1: {
		"category": "sword", "node_name": "EquippedSword",
		"scale": 0.92, "hand": "right",
		"grip_point": Vector3(0.0, 0.05, 0.0),
		"grip_euler_degrees": Vector3(118.0, 0.0, 0.0),
		"grip_roll_degrees": 90.0,
		"carry_direction": Vector3(0.12, 0.99, 0.02),
		"reach": 2.45,
	},
	2: {
		"category": "axe", "node_name": "EquippedAxe",
		"scale": 0.62, "hand": "right",
		"grip_point": Vector3(0.05, -0.46, 0.0),
		"grip_euler_degrees": Vector3(150.0, 0.0, 0.0),
		"grip_roll_degrees": 90.0,
		"carry_direction": Vector3(0.62, 0.78, 0.08),
		"reach": 2.25,
	},
	3: {
		"category": "bow", "node_name": "EquippedBow",
		"scale": 0.70, "hand": "left",
		"grip_point": Vector3(0.01, 0.0, 0.0),
		"grip_euler_degrees": Vector3(0.0, 0.0, 0.0),
		"reach": 0.0,
	},
	4: {
		"category": "torch", "node_name": "EquippedTorch",
		"scale": 0.26, "hand": "right",
		"grip_point": Vector3(0.0, 0.02, 0.0),
		"grip_euler_degrees": Vector3(168.0, 0.0, 0.0),
		# Una antorcha se lleva a plomo, quieto o andando. A 40° sobre la
		# horizontal —lo que había— se veía doblada en la mano.
		"carry_direction": Vector3(0.0, 1.0, 0.0),
		# Y con corrección completa: al 62% se quedaba a medio camino entre la
		# vertical y lo que dijera la animación del brazo. La espada sí conserva
		# la corrección parcial, que es lo que le deja acompañar el braceo.
		"carry_stabilization": 1.0,
		"reach": 0.0,
	},
}
## Fotogramas de `SwordSlash` reutilizados como poses fijas: 0,15 s es la espada
## alzada tras la cabeza (carga) y 0,65 s la espada extendida en horizontal,
## que es la silueta correcta para el ataque giratorio.
## Postura de tiro, en coordenadas del esqueleto (+Z es el frente del héroe y
## +X su costado izquierdo, el del arco). El ancla vive junto a la mejilla
## DERECHA, que es la mano que tensa: llevarla al lado izquierdo obligaba al
## brazo derecho a cruzar el pecho entero y lo metía dentro del torso.
const ANCHOR_AT_STRING := Vector3(-0.10, 1.58, 0.34)
const ANCHOR_AT_CHEEK := Vector3(-0.17, 1.76, 0.12)
const LEFT_SHOULDER_LOCAL := Vector3(0.40, 1.45, 0.0)
const ARM_REACH := 0.92
## Poses de reposo sobre la espalda, en el sistema del hueso `Torso` (+X es el
## costado izquierdo del héroe, +Z su frente). El escudo va pegado a la espalda y
## el arma cruzada por delante de él, como se lleva de verdad.
const BACK_SHIELD_POSITION := Vector3(0.0, -0.02, -0.30)
## Desplazamiento lateral del escudo colgado. Centrado, la tabla ocupaba justo
## el hueco por el que sube el brazo armado al cargar y el brazo la atravesaba
## 0.23 m. Colgado hacia el costado izquierdo —el contrario al de la espada—
## deja paso, y es como se lleva un escudo de verdad.
@export var back_shield_side_offset: float = 0.0
const BACK_SHIELD_EULER_DEGREES := Vector3(0.0, 180.0, 0.0)
const BACK_WEAPON_POSITION := Vector3(-0.06, -0.42, -0.30)
const BACK_WEAPON_EULER_DEGREES := Vector3(0.0, 180.0, 26.0)
## Escudo en guardia: sobre el antebrazo izquierdo. Su cara no puede depender de
## la rotación del puño, que sigue animándose, así que se recalcula cada
## fotograma contra el frente del héroe.
const GUARD_SHIELD_FORWARD_OFFSET := 0.46
const GUARD_SHIELD_ARM_OFFSET := Vector3(0.03, 0.10, 0.0)
## Mano izquierda al levantar el escudo, en coordenadas del esqueleto. Bien
## separada del eje del cuerpo: pegada al pecho el escudo quedaba oculto detrás
## del torso desde la cámara de espalda.
const GUARD_HAND_TARGET := Vector3(0.36, 1.50, 0.40)
const SHIELD_SCALE := 0.58
## Igual que con el arco: un escudo perfectamente de frente se ve de canto desde
## la cámara de espalda. Este ladeo enseña parte de su cara sin dejar de cubrir.
const GUARD_SHIELD_CANT_DEGREES := 28.0

const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walk"
const ANIM_RUN := "Run"
const ANIM_JUMP := "Jump"
const ANIM_ATTACK := "SwordSlash"
const ANIM_ROLL := "Roll"
const ANIM_STAB := "Punch"
const ANIM_SIT := "SitDown"
const REALISTIC_IDLE := ANIM_IDLE

@export_category("Movimiento")
@export var walk_speed: float = 5.5
@export var sprint_speed: float = 10.0
@export var acceleration: float = 26.0
@export var air_acceleration: float = 7.0
## A 5.3 el héroe subía 1.43 m —tres cuartos de su altura— y pasaba más de un
## segundo en el aire: parecía flotar de pie mientras bajaba. Con 4.1 sube 0.86 m.
@export var jump_velocity: float = 4.1
## La caída va más rápida que la subida. Es el truco de siempre para que un
## salto no se sienta flotando: sin él, bajar dura lo mismo que subir.
@export_range(1.0, 3.0, 0.05) var fall_gravity_multiplier: float = 1.75
## Vigor que consume cargar, por segundo, y lo que cuesta soltar el giro.
@export var charge_stamina_drain: float = 22.0
@export var spin_stamina_cost: float = 28.0
## Cuánto vigor se recupera por segundo, y cuánto espera tras gastarlo.
@export var stamina_regen: float = 17.0
@export var stamina_regen_delay: float = 0.85
## Vigor mínimo para poder empezar a cargar.
@export var min_charge_stamina: float = 18.0
@export var turn_speed: float = 12.0
@export var walk_animation_rate: float = 1.42
@export var run_animation_rate: float = 1.18

@export_category("Combate")
@export var attack_duration: float = 0.78
@export var attack_hit_start: float = 0.16
@export var attack_hit_end: float = 0.54
@export var attack_recovery: float = 0.18
@export var attack_animation_rate: float = 1.45
@export var charge_full_time: float = 0.60
@export var spin_duration: float = 0.78
## Impulso del salto con el que se suelta la fuerza especial: el héroe se eleva
## y se va hacia su derecha mientras gira, y cae antes de cerrar la vuelta.
@export var spin_jump_velocity: float = 3.6
@export var spin_jump_side_push: float = 2.4
@export var spin_turns: float = 1.0
@export var spin_reach: float = 3.1
## Cuánto se pasa el barrido del giro respecto al alcance del propio gesto. El
## remolino arrastra más allá del filo, así que golpear justo al borde también
## cuenta; sin este margen el ataque especial se sentía más corto que el tajo.
@export_range(1.0, 2.5, 0.05) var spin_area_overreach: float = 1.55
## Cuánto se corrige la muñeca para mantener el arma apuntando a su dirección
## de porte. A 1.0 el arma queda rígida contra el mundo y se pierde el vaivén;
## a 0.0 la espada da bandazos en cada paso.
@export_range(0.0, 1.0, 0.02) var weapon_carry_stabilization: float = 0.62

@export_category("Esquiva")
## Con la tecla de esquiva mantenida el héroe se desplaza de costado sin girar el
## cuerpo, y saltar en ese momento lanza la voltereta lateral.
@export var dodge_speed: float = 8.6
@export var dodge_hop: float = 3.4
@export var dodge_recovery: float = 0.22

@export_category("Gestos de la biblioteca")
## Segundos quieto y con las manos libres antes de que el héroe se cruce de
## brazos. Da vida al reposo sin estorbar ninguna acción.
@export var idle_gesture_delay: float = 4.5
## Cuánto se encoge el héroe detrás del escudo, en grados de flexión del tronco.
## Cada grado adelanta la cabeza unos 1.4 cm y baja el escudo otro tanto: a 26°
## la tabla acababa a la altura de la barriga. A 14° se ve que se protege y el
## escudo sigue cubriendo del pecho al muslo.
@export_range(0.0, 45.0, 1.0) var guard_tuck_degrees: float = 14.0
## Cuánto se inclina el héroe al acumular fuerza. A 20° la cabeza se adelanta
## 0.42 m: el escorzo de quien va a soltar un mandoble. Va aparte del brazo, con
## un solo número que ajustar, y no toca las piernas, así que los pies siguen
## dando pasos.
@export_range(0.0, 40.0, 1.0) var charge_lean_degrees: float = 20.0
## Cuánto se abre el brazo armado al cargar. Hacía falta con la pose de codo
## doblado, que llevaba el húmero pegado a la línea media; con el brazo estirado
## de `Sword_Regular_A` sobra: a 0° el brazo ya pasa a 0.36 m del centro de la
## cabeza y abrirlo más lo acerca (0.28 m a 22°), porque lo hace descender.
## Dirección a la que se adelanta el antebrazo armado al cargar, en el sistema
## del héroe (+x su derecha, +y arriba, +z su frente).
##
## La postura de recarga no sale de ningún fotograma de la biblioteca: se
## construye. El brazo entero se pone recto en esta dirección y el filo la
## toma también, así que brazo y hoja forman una sola línea desde el hombro. El
## tronco se inclina aparte. Al costado es donde tiene que estar el arma para
## que el remolino la barra en círculo sin que el brazo se mueva.
@export var charge_arm_direction := Vector3(0.97, 0.14, 0.06)
## Flexión del codo armado. Recto del todo el brazo se leía como una tabla; unos
## grados de codo dejan el gesto con tensión.
@export_range(0.0, 45.0, 1.0) var charge_elbow_degrees: float = 20.0
## El brazo libre acompaña: se levanta y se flexiona, como haciendo fuerza.
## El brazo libre acompaña. Su húmero cuelga PARALELO al eje del tronco —se
## calcula a partir de `charge_lean_degrees`, así que sigue sola cualquier
## inclinación que se le ponga— y este número lo abre al costado, dejando el
## codo hacia fuera. El antebrazo se pliega hacia arriba cruzando el plano del
## pecho, así que el puño sube por encima del codo: brazo en tensión.
## A 0.74 el codo se abre 0.30 m del eje del hombro: el húmero se despega bien
## de la axila y el brazo queda en ala, no pegado a las costillas.
@export_range(0.0, 0.9, 0.01) var charge_free_arm_flare: float = 0.74
## Dirección del antebrazo libre, en el sistema del héroe: sube, se separa del
## cuerpo hacia delante y apunta 40° a su izquierda. Cruzándolo hacia la derecha
## acababa metido en la barriga.
@export var charge_free_forearm_direction := Vector3(-0.32, 0.55, 0.77)
## Cuánto gira el tronco hacia su derecha al acumular, en grados: el hombro
## armado se retrasa y el libre se adelanta, que es como se recoge la fuerza.
@export_range(0.0, 45.0, 1.0) var charge_twist_degrees: float = 18.0
## Hasta qué fotograma de `Sword_Regular_A` llega el gesto de envainar. El
## retargeting amplía mucho el recorrido: a 0.42 la muñeca subía un metro —un
## mandoble entero— y a 0.22 no se movía nada.
@export_range(0.05, 0.45, 0.01) var sheath_pose_reach: float = 0.34
## Alcance del gancho a mano desnuda. Con las manos libres el héroe ya no se
## queda mirando: `Melee_Hook` de la biblioteca le da un puñetazo.
@export var punch_reach: float = 1.6

@export_category("Porte del equipo")
## Segundos corriendo sin combatir antes de que el arma se guarde a la espalda.
@export var auto_stow_delay: float = 2.2
@export var stow_transition: float = 0.34
@export var shield_transition: float = 0.22
## Cuánto reduce la guardia el daño recibido.
@export_range(0.0, 1.0, 0.05) var guard_damage_reduction: float = 0.65
@export var bow_full_draw_time: float = 1.05
@export var bow_min_release_strength: float = 0.26
## A 66 m/s el vuelo entero duraba tres décimas: no había forma de seguir la
## flecha con la vista. Estas velocidades dejan medio segundo de recorrido
## visible y, con la gravedad del proyectil, una parábola que se lee.
@export var arrow_min_speed: float = 26.0
@export var arrow_max_speed: float = 48.0
## Distancia a la que se supone el blanco cuando la retícula no encuentra nada.
## Estaba en 180 m: más lejos de lo que la flecha puede llegar salvo a tensado
## completo (el alcance es v²/g, entre 64 m flojo y 219 m a tope), así que
## apuntando al horizonte la marca de impacto siempre quedaba corta. A 90 m el
## blanco supuesto está dentro de alcance con medio tensado.
@export var bow_aim_distance: float = 90.0
@export var bow_release_pose_duration: float = 0.24
## Un arco cuyo plano contiene exactamente la dirección de tiro queda de canto
## respecto a la cámara en tercera persona: se veía como una astilla de ocho
## píxeles. Este ladeo lo hace legible sin tocar la trayectoria del proyectil,
## que sigue saliendo hacia el punto de la retícula.
@export_range(-60.0, 60.0, 1.0) var bow_plane_yaw_degrees: float = -34.0
## El cuerpo se abre respecto a la línea de tiro, como en la postura real de
## arquería. Es lo que saca el arco y la flecha de la silueta del héroe para
## que el jugador vea el disparo desde la cámara de hombro.
@export_range(-60.0, 60.0, 1.0) var aiming_body_yaw_degrees: float = 16.0
@export_range(0.0, 60.0, 1.0) var bow_rest_tilt_degrees: float = 34.0
## Torsión del tronco al tensar. Abre los hombros como un arquero real; sin ella
## uno de los dos brazos acaba metido dentro del torso.
@export_range(-60.0, 60.0, 1.0) var archer_torso_twist_degrees: float = -25.0
## La cámara de puntería sigue puesta un instante después de soltar, para que se
## vea salir la flecha y clavarse en vez de cortar a la vista normal.
@export var aim_follow_after_shot: float = 1.3

@export_category("Seguridad")
@export var respawn_height: float = -12.0

@export_category("Quaternius")
@export_file("*.gltf") var quaternius_hero_path := "res://assets/quaternius/ultimate_animated_characters/glTF/Cowboy_Male.gltf"
@export var hero_skin_color := Color("d87842")
@export var network_remote := false

@export_category("Montura")
@export var mount_distance: float = 3.6
@export var dismount_offset: float = 1.65

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $Collision
@onready var model_root: Node3D = $Visual/ModelRoot
@onready var attack_area: Area3D = $Visual/AttackArea
@onready var attack_shape: CollisionShape3D = $Visual/AttackArea/CollisionShape3D

var skeleton: Skeleton3D
var character_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var realistic_pose: Node3D
var realistic_model: Node3D
var realistic_skeleton: Skeleton3D
var realistic_animation: AnimationPlayer
var spawn_position: Vector3
var control_state := ControlState.ON_FOOT
var current_mount: Horse
var entrada_interfaz_bloqueada := false
var _descartar_input_interfaz := false
var is_attacking := false
var attacks_performed := 0
var attack_phase := AttackPhase.NONE
var _charge_time := 0.0
var _charge_strength := 0.0
## El vigor es lo que limita la fuerza especial. Sin él, mantener el botón era
## gratis y el ataque giratorio no tenía coste ninguno: se podía encadenar sin
## parar y cualquier jefe caía a base de girar.
var stamina := 100.0
var stamina_max := 100.0
var _stamina_pause := 0.0
var _spin_time := 0.0
var _spin_start_yaw := 0.0
var is_rolling := false
var _roll_time := 0.0
var _roll_duration := 0.7
var _roll_direction := Vector3.ZERO
var _dodge_cooldown := 0.0
## Duraciones efectivas del tajo en curso. Las fija `_start_slash` a partir de la
## animación que vaya a usarse, sin tocar los ajustes exportados.
var _slash_duration := 0.78
var _slash_hit_start := 0.16
var _slash_hit_end := 0.54
var is_guarding := false
var _shield_arm_influence := 0.0
var _ride_influence := 0.0
var _library: LibraryAnimation
var _library_target := 0.0
## Índice del tajo dentro de la cadena A -> B -> C. Se reinicia si el jugador
## deja de encadenar.
var _slash_chain := 0
var _slash_chain_window := 0.0
## Dos clics anticipados completan la cadena sin perderse durante un tajo.
var _tajos_pendientes := 0
var _ataque_mantenido := false
var _tiempo_pulsacion_ataque := 0.0
## Gesto puntual en curso (`play_gesture`): cofres, siega, brindis, saludos...
var _gesture_name := ""
var _gesture_time := 0.0
var _gesture_duration := 0.0
var _gesture_lower_body := false
var _idle_gesture_time := 0.0
## Cuenta atrás del gesto de envainar o desenvainar, y en qué sentido va.
var _sheath_time := 0.0
var _sheath_reverse := false
var _back_socket: BoneAttachment3D
var _back_shield_grip: Node3D
var _back_weapon_grip: Node3D
var _stowed_slot := 0
var _stowed_mesh: MeshInstance3D
var _weapon_on_back := false
var _idle_combat_time := 0.0
var _pending_draw_attack := false
## Transiciones en curso de mallas entre agarres. Son varias a la vez: al
## cambiar de arma una viaja a la espalda mientras la otra sube a la mano.
var _equipment_moves: Array[Dictionary] = []
var _charge_effect: WeaponChargeEffect
var _charge_storm: ChargeStorm
var _weapon_arm: WeaponArmModifier
var _attack_time := 0.0
var _attack_cooldown := 0.0
var _attack_hits: Dictionary = {}
var _realistic_stride := 0.0
var _weapon_grip: Node3D
var _weapon_socket: BoneAttachment3D
var _left_weapon_socket: BoneAttachment3D
var _equipped_mesh: MeshInstance3D
var _shield_socket: BoneAttachment3D
var _shield_grip: Node3D
var _shield_mesh: MeshInstance3D
var _equipment_mesh_cache: Dictionary = {}
var _attack_reach := 1.25
var skin_surface_count := 0
var equipped_slot := 0
var equipped_item_name := "Manos vacías"
var equipped_item_id := ""
var equipped_category := ""
var is_drawing_bow := false
var _bow_draw_time := 0.0
var _bow_draw_strength := 0.0
var _bow_release_time := 0.0
var _bow_release_strength := 0.0
var _aim_hold_time := 0.0
var _bow_ik: ArcherArmsModifier
var _bow_left_target: Marker3D
var _bow_right_target: Marker3D
var _bow_ik_active := false
var _nocked_arrow: AdventureArrow
var _bow_string_segments: Array[MeshInstance3D] = []
var _last_arrow_origin := Vector3.ZERO
var _last_arrow_direction := Vector3.FORWARD
var player_display_name := "Aventurero"
var character_index := 0
var _network_target_position := Vector3.ZERO
var _yaw_red_autoritativo := 0.0
var _network_state_ready := false
var _network_grounded := true
var _network_motion = NETWORK_MOTION_SCRIPT.new()
var _nameplate: Label3D


func _ready() -> void:
	spawn_position = global_position
	if not network_remote:
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null:
			player_display_name = String(settings.get("player_name"))
			character_index = int(settings.get("character_index"))
			settings.connect("identity_changed", Callable(self, "_on_local_identity_changed"))
		quaternius_hero_path = _character_path(character_index)
		add_to_group("local_player")
	else:
		add_to_group("network_player")
		collision_layer = 0
		collision_mask = 0
		collision.disabled = true
		attack_area.monitoring = false
		attack_area.monitorable = false
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	attack_shape.disabled = true
	attack_shape.shape = attack_shape.shape.duplicate()
	_load_quaternius_hero()
	model_root.visible = true
	_configure_realistic_hero()
	_build_right_hand_socket()
	_build_left_hand_socket()
	_build_bow_ik()
	# El esqueleto procesa sus modificadores en ORDEN DE ÁRBOL, no por
	# `process_priority`. La biblioteca pone la pose y el corrector del brazo la
	# retoca encima, así que tiene que nacer después: al contrario, la
	# biblioteca borraba la flexión del tronco y la corrección de muñeca.
	_build_library_animation()
	_build_weapon_arm_modifier()
	_build_back_socket()
	_refresh_equipped_shield()
	if not network_remote:
		var inventory := _inventory_manager()
		if inventory != null:
			inventory.connect("equipment_changed", Callable(self, "_on_inventory_equipment_changed"))
	_configure_animation_loops()
	_play_animation(ANIM_IDLE, 0.0)
	_build_nameplate()


func _process(delta: float) -> void:
	# Una réplica no tiene colisión: puede presentarse a la frecuencia de dibujo,
	# incluso por encima de los 60 pasos de física del héroe local.
	if network_remote: _update_network_replica(delta)
	_update_realistic_visual(delta)
	_update_ride_pose(delta)
	_update_library_pose(delta)
	_update_shield_carry(delta)
	_update_bow_pose(delta)
	_update_weapon_stabilizer(delta)
	_update_weapon_carry(delta)


func _unhandled_input(event: InputEvent) -> void:
	if network_remote or entrada_interfaz_bloqueada or _descartar_input_interfaz:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	var slot := 0
	match pressed_key:
		KEY_1:
			slot = 1
		KEY_2:
			slot = 2
		KEY_3:
			slot = 3
		KEY_4:
			slot = 4
	if slot > 0 and equip_item(slot):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if network_remote:
		_attack_cooldown = maxf(_attack_cooldown-delta,0.0)
		_slash_chain_window = maxf(_slash_chain_window-delta,0.0)
		if is_rolling: _update_dodge(delta)
		if is_drawing_bow:
			_bow_draw_time += delta
			_bow_draw_strength = clampf(_bow_draw_time/maxf(bow_full_draw_time,0.01),0.0,1.0)
		if attack_phase==AttackPhase.CHARGING:
			_charge_time += delta
			_charge_strength = clampf(_charge_time/maxf(charge_full_time,0.05),0.0,1.0)
		_update_attack(delta,_sesion_red().is_world_authority())
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_slash_chain_window = maxf(_slash_chain_window - delta, 0.0)
	_recover_stamina(delta)
	if entrada_interfaz_bloqueada or _descartar_input_interfaz:
		_descartar_input_interfaz = false
		# La gravedad, los impactos y los gestos ya iniciados siguen vivos.
		# Sólo se dejan de leer las teclas y botones del propietario de la ventana.
		if is_mounted():
			_sync_with_mount()
			return
		if is_rolling:
			_update_dodge(delta)
			_apply_roll_motion(delta)
		else:
			velocity.x = move_toward(velocity.x,0.0,acceleration*delta)
			velocity.z = move_toward(velocity.z,0.0,acceleration*delta)
		_update_attack(delta)
		_apply_gravity(delta)
		move_and_slide()
		_update_locomotion_animation()
		if global_position.y < respawn_height: _respawn()
		return
	if control_state == ControlState.MOUNTED:
		_cancel_bow_draw()
		_cancel_melee_charge()
		if is_guarding:
			_lower_shield()
		_sync_with_mount()
		if Input.is_action_just_pressed("interact"):
			if _confirm_nearby_exploration():
				return
			dismount()
		return

	_update_dodge(delta)
	if is_rolling:
		_apply_gravity(delta)
		_apply_roll_motion(delta)
		move_and_slide()
		return
	if equipped_category == "bow":
		_update_bow_input(delta)
	else:
		_update_melee_input(delta)
	if Input.is_action_just_pressed("interact") and not is_attacking:
		if _interact_with_adventure_object():
			return
		if _confirm_nearby_exploration():
			return
		var nearby_horse := get_nearby_mount()
		if nearby_horse != null:
			mount_horse(nearby_horse)
			return

	_update_attack(delta)
	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	move_and_slide()
	_update_locomotion_animation()

	if global_position.y < respawn_height:
		_respawn()


func bloquear_entrada_interfaz(bloqueada: bool) -> void:
	if network_remote or entrada_interfaz_bloqueada == bloqueada: return
	entrada_interfaz_bloqueada = bloqueada
	if not bloqueada:
		# El clic o Espacio que cierra la ventana pertenece todavía a la interfaz.
		_descartar_input_interfaz = true
		return
	_pending_draw_attack = false
	_cancel_bow_draw()
	var cargando := attack_phase == AttackPhase.CHARGING
	_cancel_melee_charge()
	if cargando: _notificar_combate("reposo")
	if is_guarding: _lower_shield()
	if not is_rolling:
		velocity.x = 0.0
		velocity.z = 0.0


func _confirm_nearby_exploration() -> bool:
	var exploration := get_node_or_null("/root/ExplorationManager")
	if exploration == null:
		return false
	# Actualización inmediata: no obliga a esperar al muestreo periódico de 160 ms
	# cuando el jugador llega a un hito y pulsa E en el mismo instante.
	exploration.call("update_player_position", global_position)
	var discovered := exploration.call("confirm_current_zone") as Dictionary
	return not discovered.is_empty()


func _interact_with_adventure_object() -> bool:
	var nearest: Node
	var nearest_distance := 4.2
	for node in get_tree().get_nodes_in_group("adventure_interactable"):
		var candidate := node as Node
		if candidate == null or not candidate is Node3D or not candidate.has_method("get_interaction_prompt") or not candidate.has_method("interact"):
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance <= nearest_distance and not String(candidate.call("get_interaction_prompt")).is_empty():
			nearest = candidate
			nearest_distance = distance
	return nearest != null and bool(nearest.call("interact", self))


func get_nearby_adventure_prompt() -> String:
	var best_prompt := ""
	var nearest_distance := 5.0
	for node in get_tree().get_nodes_in_group("adventure_interactable"):
		var candidate := node as Node
		if candidate == null or not candidate is Node3D or not candidate.has_method("get_interaction_prompt"):
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance <= nearest_distance:
			var prompt := String(candidate.call("get_interaction_prompt"))
			if not prompt.is_empty():
				best_prompt = prompt
				nearest_distance = distance
	return best_prompt


func is_strafing() -> bool:
	## Mantener la tecla de esquiva desacopla el cuerpo del movimiento: el héroe
	## se mueve de lado mirando adonde mira la cámara, como en un combate real.
	return not entrada_interfaz_bloqueada and Input.is_action_pressed("dodge") and not is_mounted() and not is_rolling


func start_dodge_roll(lateral: float) -> bool:
	if is_rolling or is_mounted() or _dodge_cooldown > 0.0 or not is_on_floor():
		return false
	if attack_phase == AttackPhase.SLASH or attack_phase == AttackPhase.SPIN:
		return false
	var side := _camera_right()
	if side.length_squared() < 0.001:
		return false
	_roll_direction = (side * signf(lateral)).normalized()
	_cancel_bow_draw()
	_cancel_melee_charge()
	is_rolling = true
	_roll_time = 0.0
	_roll_duration = 0.7
	if animation_player != null and animation_player.has_animation(ANIM_ROLL):
		_roll_duration = animation_player.get_animation(ANIM_ROLL).length
	velocity = _roll_direction * dodge_speed + Vector3.UP * dodge_hop
	_play_animation(ANIM_ROLL, 0.05, 1.0)
	dodge_started.emit(_roll_direction)
	_notificar_combate("esquiva",{"direccion":_roll_direction})
	return true


func _update_dodge(delta: float) -> void:
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if is_rolling:
		_roll_time += delta
		if _roll_time >= _roll_duration:
			is_rolling = false
			_dodge_cooldown = dodge_recovery
		return
	if not Input.is_action_just_pressed("jump") or not Input.is_action_pressed("dodge"):
		return
	var lateral := Input.get_axis("move_left", "move_right")
	if absf(lateral) < 0.3:
		return
	start_dodge_roll(lateral)
	get_viewport().set_input_as_handled()


func _apply_roll_motion(delta: float) -> void:
	## El impulso se desvanece con el rodillo y el cuerpo gira hacia el lado del
	## salto, que es lo que hace legible la voltereta.
	var progress := clampf(_roll_time / maxf(_roll_duration, 0.05), 0.0, 1.0)
	var push := dodge_speed * (1.0 - pow(progress, 1.6))
	velocity.x = _roll_direction.x * push
	velocity.z = _roll_direction.z * push
	var roll_yaw := atan2(-_roll_direction.x, -_roll_direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, roll_yaw, 1.0 - exp(-16.0 * delta))


func _camera_right() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else visual.global_basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.001 else visual.global_basis.x


func start_attack() -> bool:
	## Tajo inmediato: es lo que produce un clic corto y lo que usan las pruebas
	## y la replicación de red.
	if not _can_begin_melee():
		return false
	_start_slash()
	return true


func start_charge() -> bool:
	# La fuerza especial vive en el filo: sin arma en la mano no hay nada que
	# cargar.
	if equipped_slot == 0 or not _can_begin_melee():
		return false
	if stamina < min_charge_stamina:
		action_feedback.emit("Sin vigor para la fuerza especial")
		return false
	attack_phase = AttackPhase.CHARGING
	_charge_time = 0.0
	_charge_strength = 0.0
	_release_arm_pose()
	_ensure_charge_effect()
	if _charge_effect != null:
		_charge_effect.set_charge(0.0)
	charge_changed.emit(0.0, false)
	_notificar_combate("carga")
	return true


func start_spin_attack() -> bool:
	if attack_phase == AttackPhase.SLASH or attack_phase == AttackPhase.SPIN:
		return false
	if equipped_slot == 0:
		return false
	if not _can_begin_melee() and attack_phase != AttackPhase.CHARGING:
		return false
	attack_phase = AttackPhase.SPIN
	_spend_stamina(spin_stamina_cost)
	is_attacking = true
	is_drawing_bow = false
	_attack_time = 0.0
	_spin_time = 0.0
	_attack_hits.clear()
	attacks_performed += 1
	_spin_start_yaw = visual.rotation.y
	# La descarga es un salto, no un giro pegado al suelo: se eleva, sale hacia
	# su derecha y aterriza antes de cerrar la vuelta, con su amortiguado.
	if is_on_floor():
		velocity.y = spin_jump_velocity
	velocity += visual.global_basis.x.normalized() * spin_jump_side_push
	_release_arm_pose()
	if _charge_effect != null:
		_charge_effect.burst(spin_reach)
		_charge_effect.set_charge(0.0)
	if _charge_storm != null:
		_charge_storm.unleash(get_blade_tip())
	_flatten_nearby_grass()
	charge_changed.emit(0.0, false)
	attack_started.emit(attacks_performed)
	spin_attack_started.emit()
	_notificar_combate("giro")
	return true


func _spend_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(0.0, stamina - amount)
	_stamina_pause = stamina_regen_delay
	stamina_changed.emit(stamina, stamina_max)


func _recover_stamina(delta: float) -> void:
	if _stamina_pause > 0.0:
		_stamina_pause = maxf(0.0, _stamina_pause - delta)
		return
	if stamina >= stamina_max:
		return
	stamina = minf(stamina_max, stamina + stamina_regen * delta)
	stamina_changed.emit(stamina, stamina_max)


func grow_vitals(health_bonus: int, stamina_bonus: int) -> void:
	## Lo llaman la campaña al cerrar un acto y la forja al subir de grado: el
	## héroe se hace más resistente conforme avanza la historia, no sólo por
	## llevar mejor acero.
	stamina_max += float(stamina_bonus)
	stamina = stamina_max
	stamina_changed.emit(stamina, stamina_max)
	vitals_grown.emit(health_bonus, stamina_bonus)


func get_charge_strength() -> float:
	return _charge_strength


func _item_mesh_scale(item_id: String) -> float:
	var inventory := _inventory_manager()
	if inventory == null or item_id.is_empty():
		return 1.0
	var definition := inventory.call("get_item_definition", item_id) as Dictionary
	return float(definition.get("mesh_scale", 1.0))


func _punto_agarre(slot: int, item_id: String) -> Vector3:
	var definicion: Dictionary = _inventory_manager().get_item_definition(item_id)
	var punto: Variant = definicion.get("grip_point")
	return punto if punto is Vector3 else EQUIPMENT_SPECS[slot].get("grip_point", Vector3.ZERO)


func _pose_arma_en_mano(slot: int, item_id: String) -> Transform3D:
	var escala := float(EQUIPMENT_SPECS[slot].scale) * _item_mesh_scale(item_id)
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * escala), -_punto_agarre(slot, item_id) * escala)


func _pose_arma_en_espalda(slot: int, item_id: String) -> Transform3D:
	var escala := float(EQUIPMENT_SPECS[slot].scale) * _item_mesh_scale(item_id)
	var pose := _pose_of(BACK_WEAPON_POSITION, BACK_WEAPON_EULER_DEGREES, escala)
	pose.origin -= pose.basis * _punto_agarre(slot, item_id)
	return pose


func is_spin_attacking() -> bool:
	## Lo consultan los jefes cuya coraza sólo cede al giro de 360°: el golpe
	## llega por la misma vía que un tajo normal, así que hace falta preguntar de
	## dónde viene.
	return attack_phase == AttackPhase.SPIN


func is_spin_ready() -> bool:
	return _charge_strength >= 1.0


func is_charging_attack() -> bool:
	return attack_phase == AttackPhase.CHARGING


func _can_begin_melee() -> bool:
	if entrada_interfaz_bloqueada or _descartar_input_interfaz: return false
	# Con las manos libres se puede golpear igual: es el gancho de la biblioteca.
	if equipped_slot != 0 and _equipped_mesh == null:
		return false
	if equipped_category in ["bow", "torch"]:
		return false
	if _weapon_on_back or is_drawing_equipment() or is_guarding or is_rolling:
		return false
	return not (is_mounted() or is_attacking or _attack_cooldown > 0.0)


func _update_melee_input(delta: float) -> void:
	if equipped_category == "torch" or is_guarding or is_rolling or is_mounted():
		_limpiar_entrada_ataque()
		return
	if Input.is_action_just_pressed("attack"):
		_ataque_mantenido = true
		_tiempo_pulsacion_ataque = 0.0
		_tajos_pendientes = mini(_tajos_pendientes + 1, 2)
	# Un clic durante el envainado espera a que termine el viaje y desenvaina.
	# Comprobarlo sólo al pulsar dejaba el golpe perdido con el arma a la espalda.
	if _tajos_pendientes > 0 and _weapon_on_back and not is_drawing_equipment():
		_pending_draw_attack = draw_weapon()
	if _ataque_mantenido:
		if Input.is_action_pressed("attack"):
			_tiempo_pulsacion_ataque += delta
		else:
			_ataque_mantenido = false
	if (_tajos_pendientes > 0 or _ataque_mantenido) and attack_phase != AttackPhase.CHARGING and _can_begin_melee():
		if _tajos_pendientes > 0:
			_tajos_pendientes -= 1
			_start_slash()
		elif equipped_slot > 0 and _ataque_mantenido and _tiempo_pulsacion_ataque >= UMBRAL_ATAQUE_MANTENIDO:
			# La carga sólo comienza tras el tajo y su recuperación, con el botón
			# todavía sostenido. Un clic siempre responde al pulsar, no al soltar.
			if start_charge(): _ataque_mantenido = false
	if attack_phase != AttackPhase.CHARGING:
		return
	_charge_time += delta
	_spend_stamina(charge_stamina_drain * delta)
	if stamina <= 0.0:
		# Agotado a media carga: el gesto se resuelve como tajo, no se queda
		# colgado con el arma en alto y la tormenta encima.
		action_feedback.emit("Vigor agotado")
		_start_slash()
		return
	_charge_strength = clampf(_charge_time / maxf(charge_full_time, 0.05), 0.0, 1.0)
	if _charge_effect != null:
		_charge_effect.set_charge(_charge_strength)
	charge_changed.emit(_charge_strength, is_spin_ready())
	if not Input.is_action_pressed("attack"):
		if is_spin_ready():
			start_spin_attack()
		else:
			_start_slash()


func _limpiar_entrada_ataque() -> void:
	_tajos_pendientes = 0
	_ataque_mantenido = false
	_tiempo_pulsacion_ataque = 0.0
	_pending_draw_attack = false


func _start_slash() -> void:
	attack_phase = AttackPhase.SLASH
	_release_arm_pose()
	is_attacking = true
	_attack_time = 0.0
	_attack_hits.clear()
	attacks_performed += 1
	if _charge_effect != null:
		_charge_effect.set_charge(0.0)
	charge_changed.emit(0.0, false)
	var chain := [LIB_SLASH_A, LIB_SLASH_B, LIB_SLASH_C]
	if _slash_chain_window <= 0.0:
		_slash_chain = 0
	var library_slash: String = chain[_slash_chain % chain.size()]
	_slash_chain = (_slash_chain + 1) % chain.size()
	# Cada herramienta tiene su gesto: el hacha tala y el puño da un gancho.
	if equipped_category == "axe" and _library != null and _library.has_animation(LIB_CHOP):
		library_slash = LIB_CHOP
	elif equipped_slot == 0 and _library != null and _library.has_animation(LIB_PUNCH):
		library_slash = LIB_PUNCH
	if _library != null and _library.has_animation(library_slash):
		_library.upper_body_only = true
		_library.bone_filter = PackedStringArray()
		_library.play_library(library_slash, 1.0)
		_library_target = 1.0
		_library.influence = 1.0
		# Las duraciones efectivas viven aparte: escribir sobre los ajustes
		# exportados los dejaba alterados para siempre en cuanto se daba un tajo.
		_slash_duration = maxf(_library.get_length(library_slash), 0.35)
		_slash_hit_start = _slash_duration * 0.22
		_slash_hit_end = _slash_duration * 0.78
		# El tercer golpe del combo es más largo y más lento de recuperar.
		_slash_chain_window = _slash_duration + attack_recovery + 0.45
	else:
		_slash_duration = attack_duration
		_slash_hit_start = attack_hit_start
		_slash_hit_end = attack_hit_end
		_play_animation(ANIM_ATTACK, 0.06, attack_animation_rate)
	attack_started.emit(attacks_performed)
	_notificar_combate("tajo")


func is_mounted() -> bool:
	return control_state == ControlState.MOUNTED and is_instance_valid(current_mount)


func get_facing_direction_xz() -> Vector2:
	# El CharacterBody no gira: gira Visual, y al montar Visual pasa a ser hijo
	# del caballo. Leer su base global mantiene brújula y mapa correctos en ambos
	# estados sin duplicar lógica de orientación.
	var forward := -visual.global_basis.z
	var direction := Vector2(forward.x, forward.z)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.UP


func get_network_facing_yaw() -> float:
	var direction := get_facing_direction_xz()
	return atan2(-direction.x, -direction.y)


func configure_network_replica(name_value: String, index_value: int) -> void:
	network_remote = true
	player_display_name = name_value.strip_edges().left(24)
	if player_display_name.is_empty():
		player_display_name = "Aventurero"
	character_index = clampi(index_value, 0, CHARACTER_PATHS.size() - 1)
	quaternius_hero_path = _character_path(character_index)


func apply_identity(name_value: String, index_value: int) -> void:
	player_display_name = name_value.strip_edges().left(24)
	if player_display_name.is_empty():
		player_display_name = "Aventurero"
	var safe_index := clampi(index_value, 0, CHARACTER_PATHS.size() - 1)
	var next_path := _character_path(safe_index)
	var character_changed := safe_index != character_index or next_path != quaternius_hero_path
	character_index = safe_index
	quaternius_hero_path = next_path
	if _nameplate != null:
		_nameplate.text = player_display_name
	if character_changed and is_node_ready():
		_reload_quaternius_hero()


func apply_network_state(position_value: Vector3, yaw_value: float, velocity_value: Vector3, slot_value: int, sample_time: float = -1.0, grounded: bool = true) -> void:
	var arrival_time := float(Time.get_ticks_usec())/1000000.0
	if sample_time<0.0: sample_time = arrival_time
	var previous_generation: int = _network_motion.generation
	if not _network_motion.push_sample(position_value,yaw_value,velocity_value,sample_time,arrival_time,grounded): return
	_network_target_position = position_value
	_yaw_red_autoritativo = yaw_value
	if not _network_state_ready or previous_generation!=_network_motion.generation:
		global_position = position_value
		visual.rotation.y = yaw_value
		reset_physics_interpolation()
		_network_state_ready = true
	if slot_value != equipped_slot:
		if slot_value > 0:
			equip_item(slot_value)
		else:
			_clear_equipped_item()


func get_network_authoritative_position() -> Vector3:
	return _network_target_position if network_remote and _network_state_ready else global_position


func get_camera_target() -> Node3D:
	return current_mount if is_mounted() else self


func get_nearby_mount() -> Horse:
	var nearest: Horse
	var nearest_distance := mount_distance
	for node in get_tree().get_nodes_in_group("mountable"):
		var horse := node as Horse
		if horse == null or horse.mounted:
			continue
		var distance := global_position.distance_to(horse.global_position)
		if distance <= nearest_distance:
			nearest = horse
			nearest_distance = distance
	return nearest


func mount_horse(horse: Horse) -> bool:
	if control_state != ControlState.ON_FOOT or horse == null or horse.mounted or is_attacking:
		return false

	current_mount = horse
	control_state = ControlState.MOUNTED
	velocity = Vector3.ZERO
	collision.set_deferred("disabled", true)
	attack_shape.set_deferred("disabled", true)
	horse.set_mounted(true)
	visual.reparent(horse.rider_anchor, false)
	# El rig conserva la colisión a pie, pero hundimos las piernas en la montura
	# para que el torso quede sentado sobre la silla real del caballo.
	visual.position = Vector3(0.0, -0.15, 0.08)
	visual.rotation = Vector3.ZERO
	global_position = horse.global_position
	_play_animation(ANIM_SIT, 0.12, 1.25)
	mount_state_changed.emit(true, horse)
	return true


func dismount() -> bool:
	if not is_mounted():
		return false

	var horse := current_mount
	var exit_direction := horse.visual.global_basis.x.normalized()
	visual.reparent(self, false)
	visual.position = Vector3.ZERO
	visual.rotation = Vector3(0.0, horse.get_facing_yaw(), 0.0)
	global_position = horse.global_position + exit_direction * dismount_offset + Vector3.UP * 0.35
	velocity = Vector3.ZERO
	control_state = ControlState.ON_FOOT
	current_mount = null
	collision.set_deferred("disabled", false)
	horse.set_mounted(false)
	_play_animation(ANIM_IDLE, 0.12)
	mount_state_changed.emit(false, horse)
	return true


func _update_attack(delta: float, aplicar_impactos: bool = true) -> void:
	match attack_phase:
		AttackPhase.CHARGING:
			attack_shape.disabled = true
			# El arma se va alzando a medida que sube la carga: el gesto se lee
			# como "está acumulando" y no como una pose que aparece de golpe.
			if _charge_effect != null:
				_charge_effect.update_pulse(delta)
			if _charge_storm != null:
				_charge_storm.set_intensity(_charge_strength, delta, get_blade_tip(), global_position)
		AttackPhase.SLASH:
			_attack_time += delta
			var active := _attack_time >= _slash_hit_start and _attack_time <= _slash_hit_end
			attack_shape.disabled = not active
			if active and aplicar_impactos:
				_apply_melee_hits()
			if _attack_time >= _slash_duration:
				_finish_attack()
		AttackPhase.SPIN:
			_spin_time += delta
			_attack_time = _spin_time
			var progress := clampf(_spin_time / maxf(spin_duration, 0.1), 0.0, 1.0)
			# Arranque rápido y frenada al final: el giro se lee como un latigazo
			# y no como una peonza a velocidad constante.
			var eased := 1.0 - pow(1.0 - progress, 2.4)
			visual.rotation.y = _spin_start_yaw + TAU * spin_turns * eased
			# La tormenta acompaña al remolino y se disipa con él. Apagarla al
			# soltar la dejaba invisible justo en el gesto que el jugador mira.
			if _charge_storm != null:
				# La caída se queda por encima del umbral de tormenta: bajando
				# más, el viento se cortaba de golpe a mitad del remolino.
				_charge_storm.set_intensity(
					1.0 - eased * 0.40, delta, get_blade_tip(), global_position
				)
			var active_spin := progress <= 0.9
			attack_shape.disabled = not active_spin
			if active_spin and aplicar_impactos:
				_apply_melee_hits(true)
			if progress >= 1.0:
				_finish_attack()
		_:
			attack_shape.disabled = true


func _finish_attack() -> void:
	attack_phase = AttackPhase.NONE
	is_attacking = false
	_release_arm_pose()
	if _charge_storm != null:
		_charge_storm.calm()
	attack_shape.disabled = true
	_attack_cooldown = attack_recovery
	_charge_time = 0.0
	_charge_strength = 0.0
	_spin_time = 0.0
	if _charge_effect != null:
		_charge_effect.set_charge(0.0)
	charge_changed.emit(0.0, false)


func _cancel_melee_charge() -> void:
	_limpiar_entrada_ataque()
	if attack_phase != AttackPhase.CHARGING:
		return
	attack_phase = AttackPhase.NONE
	_release_arm_pose()
	if _charge_storm != null:
		_charge_storm.calm()
	_charge_time = 0.0
	_charge_strength = 0.0
	if _charge_effect != null:
		_charge_effect.set_charge(0.0)
	charge_changed.emit(0.0, false)


func _flatten_nearby_grass() -> void:
	## La fuerza especial deja huella: tumba la hierba de todo el ruedo, no solo
	## la que el héroe pisa.
	var vegetation := get_node_or_null("../VegetationScatter")
	if vegetation != null and vegetation.has_method("flatten_grass_burst"):
		vegetation.call("flatten_grass_burst", global_position, spin_reach * 1.9, 1.6)


func _ensure_charge_effect() -> void:
	if _charge_effect == null or not is_instance_valid(_charge_effect):
		_charge_effect = CHARGE_EFFECT_SCRIPT.new() as WeaponChargeEffect
		_charge_effect.name = "WeaponChargeEffect"
		visual.add_child(_charge_effect)
	if _equipped_mesh != null:
		_charge_effect.attach_to_weapon(_equipped_mesh)
	# La tormenta vive en el mundo, no en el héroe: los rayos caen del cielo y
	# el viento y la luz son del escenario entero.
	if network_remote:
		return
	if _charge_storm == null or not is_instance_valid(_charge_storm):
		_charge_storm = CHARGE_STORM_SCRIPT.new() as ChargeStorm
		_charge_storm.name = "ChargeStorm"
		var host := get_parent()
		if host == null:
			host = self
		host.add_child(_charge_storm)
		_charge_storm.bind(host)


func get_blade_tip() -> Vector3:
	if _equipped_mesh == null or _equipped_mesh.mesh == null:
		return global_position + Vector3.UP * 1.6
	var bounds := _equipped_mesh.mesh.get_aabb()
	return _equipped_mesh.to_global(
		Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y, 0.0)
	)


func _release_arm_pose() -> void:
	## Suelta cualquier corrección sostenida del brazo armado.
	if _weapon_arm != null:
		_weapon_arm.raise_weight = 0.0
		_weapon_arm.lean_weight = 0.0


func _build_library_animation() -> void:
	if skeleton == null:
		return
	_library = LIBRARY_ANIMATION_SCRIPT.new() as LibraryAnimation
	_library.name = "LibraryAnimation"
	_library.influence = 0.0
	_library.active = true
	_library.target_animator = animation_player
	_library.source_host = self
	skeleton.add_child(_library)


func has_library_animation(animation_name: String) -> bool:
	return _library != null and _library.has_animation(animation_name)


func get_library_catalogue() -> PackedStringArray:
	## Todo lo que la biblioteca ofrece sobre este personaje. Lo consultan las
	## pruebas y el menú de gestos.
	return _library.get_available() if _library != null else PackedStringArray()


func play_gesture(animation_name: String, speed_override: float = 0.0) -> bool:
	## Lanza cualquier movimiento del catálogo. Los que se apoderan del tren
	## inferior dejan al héroe quieto mientras duran; el resto se pueden dar
	## caminando. Un gesto nuevo sustituye al que hubiera en marcha.
	if _library == null or not _library.has_animation(animation_name):
		return false
	var resolved := _library.resolve(animation_name)
	var config: Dictionary = GESTURES.get(animation_name, GESTURES.get(resolved, {}))
	var lower_body := bool(config.get("piernas", false))
	var speed: float = speed_override if speed_override > 0.0 else float(config.get("ritmo", 1.0))
	_library.upper_body_only = not lower_body
	if not _library.play_library(animation_name, speed):
		_library.upper_body_only = true
		return false
	_gesture_name = animation_name
	_gesture_lower_body = lower_body
	_gesture_duration = maxf(_library.get_length(animation_name) / maxf(speed, 0.05), 0.05)
	_gesture_time = _gesture_duration
	_library_target = 1.0
	gesture_started.emit(animation_name)
	return true


func react_to_hit() -> bool:
	## Gesto de golpe recibido. Con el escudo en alto el impacto lo absorbe la
	## tabla —`Idle_Shield_Break`—; sin él, el héroe sale despedido. No
	## interrumpe el remolino, que ya es invulnerable por diseño.
	if is_rolling or attack_phase == AttackPhase.SPIN or is_mounted():
		return false
	return play_gesture(LIB_GUARD_BREAK if is_guarding else LIB_HURT)


func is_playing_gesture() -> bool:
	return not _gesture_name.is_empty()


func get_gesture() -> String:
	return _gesture_name


func cancel_gesture() -> void:
	if not _gesture_name.is_empty():
		_end_gesture()


func _end_gesture() -> void:
	var finished := _gesture_name
	_gesture_name = ""
	_gesture_time = 0.0
	_gesture_lower_body = false
	if _library != null:
		# El tren superior vuelve a ser el modo normal: es lo que permite atacar
		# y montar guardia sin dejar de andar.
		_library.upper_body_only = true
	_library_target = 0.0
	gesture_finished.emit(finished)


func is_playing_library_animation() -> bool:
	return _library != null and _library.is_playing_library() and _library.influence > 0.05


func get_library_animation() -> String:
	return _library.get_current() if _library != null else ""


func _update_library_pose(delta: float) -> void:
	## Decide qué gesto de la biblioteca corresponde al estado actual y con qué
	## fuerza se mezcla. Es el único sitio que fija `_library_target`: repartir
	## esa decisión llevaba a que un estado apagase la pose de otro.
	if _library == null:
		return
	_gesture_time = maxf(_gesture_time - delta, 0.0)
	_sheath_time = maxf(_sheath_time - delta, 0.0)
	# El filtro de huesos se fija en cada rama, no antes: reasignarlo dos veces
	# por fotograma obligaba a recalcular los enlaces del retargeter.
	if not _gesture_name.is_empty():
		# Un gesto puntual manda sobre todo lo demás mientras dura.
		_library_target = 1.0
		if _gesture_time <= 0.0:
			_end_gesture()
	elif attack_phase == AttackPhase.CHARGING:
		# La recarga no sale de un fotograma de la biblioteca: el brazo se estira
		# a mano en `_update_body_tuck` y la muñeca lleva el filo a la vertical.
		# Así el gesto es exactamente el pedido, y no el que más se le parezca de
		# las 43 animaciones.
		_library.bone_filter = PackedStringArray()
		_library_target = 0.0
	elif attack_phase == AttackPhase.SPIN:
		# El remolino conserva la MISMA postura de la recarga. Tomar prestado un
		# fotograma de la biblioteca al soltar cambiaba el brazo de sitio —se iba
		# hacia arriba— justo en el gesto que el jugador está mirando. Con el
		# arma quieta al costado, lo que barre el círculo es el giro del cuerpo.
		_library.bone_filter = PackedStringArray()
		_library_target = 0.0
	elif attack_phase == AttackPhase.SLASH and not _library.get_current().is_empty():
		# Los tajos solo mueven el tronco: si el salto hubiera dejado el modo de
		# cuerpo entero, el héroe se quedaría clavado al atacar.
		_library.upper_body_only = true
		_library.bone_filter = PackedStringArray()
		_library_target = 1.0
	elif _sheath_time > 0.0 and _library.has_animation(LIB_SHEATH):
		# El brazo lleva la espada a la espalda al ritmo del viaje de la malla.
		# Solo se toca el brazo armado, así que el héroe puede seguir corriendo
		# mientras la envaina, que es cuando ocurre.
		var travel := 1.0 - clampf(_sheath_time / maxf(stow_transition, 0.05), 0.0, 1.0)
		if _sheath_reverse:
			travel = 1.0 - travel
		_library.upper_body_only = true
		_library.bone_filter = CHARGE_ARM_BONES
		_library.hold_library(LIB_SHEATH, sheath_pose_reach * travel)
		# Entra y sale con una campana: ni un tirón al empezar ni al acabar.
		_library_target = sin(clampf(1.0 - _sheath_time / maxf(stow_transition, 0.05), 0.0, 1.0) * PI)
	elif is_guarding and not is_mounted():
		_library.upper_body_only = true
		_library.bone_filter = PackedStringArray()
		if _shield_mesh == null and _library.has_animation(LIB_SWORD_BLOCK):
			# La parada con espada es un gesto de un solo golpe, así que se
			# sostiene su fotograma más cerrado en vez de reproducirla en bucle.
			_library.hold_library(LIB_SWORD_BLOCK, SWORD_BLOCK_TIME)
		elif _library.get_current() != _library.resolve(LIB_GUARD):
			_library.play_library(LIB_GUARD, 1.0)
		_library_target = 1.0
	elif _library_idle_gesture(delta):
		_library.upper_body_only = true
		_library.bone_filter = PackedStringArray()
		_library_target = 1.0
	else:
		_library.upper_body_only = true
		_library.bone_filter = PackedStringArray()
		_library_target = 0.0
	_library.influence = move_toward(_library.influence, _library_target, delta * 6.0)
	if _library.influence <= 0.001 and _library_target <= 0.0:
		_library.stop_library()
	_update_body_tuck(delta)


func _library_idle_gesture(delta: float) -> bool:
	## Gestos de reposo largos: quieto con la antorcha en alto, o de brazos
	## cruzados cuando el jugador lleva un rato sin hacer nada. Dan vida al
	## personaje sin interferir con ninguna acción.
	if is_mounted() or is_rolling or is_drawing_bow or is_drawing_equipment():
		_idle_gesture_time = 0.0
		return false
	if Vector2(velocity.x, velocity.z).length() > 0.35 or not is_on_floor():
		_idle_gesture_time = 0.0
		return false
	_idle_gesture_time += delta
	if equipped_category == "torch" and _library.has_animation(LIB_TORCH_IDLE):
		if _library.get_current() != _library.resolve(LIB_TORCH_IDLE):
			_library.play_library(LIB_TORCH_IDLE, 1.0)
		return true
	if _idle_gesture_time < idle_gesture_delay or equipped_slot != 0:
		return false
	if not _library.has_animation(LIB_FOLD_ARMS):
		return false
	if _library.get_current() != _library.resolve(LIB_FOLD_ARMS):
		_library.play_library(LIB_FOLD_ARMS, 1.0)
	return true


func _free_arm_direction() -> Vector3:
	## Húmero del brazo libre: cuelga a lo largo del eje del tronco inclinado
	## —hacia abajo y hacia atrás, en el mismo ángulo que la inclinación— y
	## abierto al costado. Derivarlo de la inclinación evita que los dos números
	## se contradigan cuando se retoca uno.
	var lean := deg_to_rad(charge_lean_degrees)
	return Vector3(-charge_free_arm_flare, -cos(lean), -sin(lean)).normalized()


func _hero_direction(local: Vector3) -> Vector3:
	## Pasa una dirección del sistema del héroe —+x su derecha, +y arriba, +z su
	## frente— al mundo. Las dos direcciones de la recarga usaban convenios de
	## signo distintos para la Z; con un solo sitio no vuelve a pasar.
	return (
		visual.global_basis.x.normalized() * local.x
		+ Vector3.UP * local.y
		- visual.global_basis.z.normalized() * local.z
	).normalized()


func _update_body_tuck(delta: float) -> void:
	## Encogimiento de la columna. `Idle_Shield` deja al héroe erguido —cabeza
	## baja 0.01 m, medido—, así que el escudo no se leía como protección. Se
	## hunde el tronco con un giro explícito sobre el abdomen: brazos, cuello y
	## cabeza cuelgan de él y acompañan el gesto.
	if _weapon_arm == null:
		return
	var charging := attack_phase == AttackPhase.CHARGING or attack_phase == AttackPhase.SPIN
	var wants_tuck := is_guarding and not is_mounted() and not is_rolling
	if charging:
		# Al cargar el tronco se inclina y el brazo armado se estira en vertical.
		# El estirado se suelta con el latigazo del remolino.
		var build := smoothstep(0.0, 0.55, _charge_strength)
		if attack_phase == AttackPhase.SPIN:
			build = 1.0
		# El tronco se inclina y además se gira hacia el lado del arma: es el
		# escorzo de quien recoge fuerza antes de soltarla.
		_weapon_arm.lean_rotations = [
			{"bone": TUCK_BONE, "axis": GUARD_TUCK_AXIS, "degrees": charge_lean_degrees},
			{
				# Sobre el eje vertical hacia abajo: así un valor positivo gira
				# el tronco hacia su derecha, que es lo que dice el ajuste.
				"bone": CHARGE_TWIST_BONE,
				"axis": Vector3.DOWN,
				"degrees": charge_twist_degrees,
			},
		]
		_weapon_arm.lean_weight = build
		# Los dos brazos se posan: el armado apunta al costado con el codo algo
		# flexionado, y el libre se levanta recogido.
		_weapon_arm.raise_chains = [
			{
				"chain": CHARGE_RAISE_CHAIN,
				"direction": _hero_direction(charge_arm_direction),
				"bend_degrees": charge_elbow_degrees,
				"bend_axis": Vector3.UP,
			},
			{
				"chain": CHARGE_FREE_UPPER,
				"direction": _hero_direction(_free_arm_direction()),
			},
			{
				"chain": CHARGE_FREE_LOWER,
				"direction": _hero_direction(charge_free_forearm_direction),
			},
		]
		_weapon_arm.raise_weight = build
		return
	_weapon_arm.raise_weight = move_toward(_weapon_arm.raise_weight, 0.0, delta * 8.0)
	_weapon_arm.lean_rotations = [
		{"bone": TUCK_BONE, "axis": GUARD_TUCK_AXIS, "degrees": guard_tuck_degrees},
	]
	_weapon_arm.lean_weight = move_toward(
		_weapon_arm.lean_weight, 1.0 if wants_tuck else 0.0, delta * 5.0
	)


func _build_weapon_arm_modifier() -> void:
	if skeleton == null or skeleton.find_bone("Fist.R") < 0:
		return
	_weapon_arm = WEAPON_ARM_SCRIPT.new() as WeaponArmModifier
	_weapon_arm.name = "WeaponArmModifier"
	_weapon_arm.hand_bone = "Fist.R"
	skeleton.add_child(_weapon_arm)


func _library_pose_allows_weapon() -> bool:
	## Los gestos de reposo no pelean con la corrección de muñeca: la necesitan.
	## Sin ella, el gesto de la antorcha la dejaba de canto y apuntando al frente
	## —solo se veía su sombra— en vez de en alto.
	if _library == null:
		return false
	var current := _library.get_current()
	return (
		current == _library.resolve(LIB_TORCH_IDLE)
		or current == _library.resolve(LIB_FOLD_ARMS)
	)


func _update_weapon_stabilizer(delta: float) -> void:
	## El vaivén del brazo es el que da alegría al paseo, así que hombro y codo
	## se dejan intactos: solo la muñeca recibe una corrección parcial para que
	## el arma no bascule de horizontal a vertical en cada zancada.
	if _weapon_arm == null or _equipped_mesh == null or equipped_slot == 0:
		if _weapon_arm != null:
			_weapon_arm.stabilize_weight = move_toward(_weapon_arm.stabilize_weight, 0.0, delta * 4.0)
		return
	# La corrección del filo vale para la acumulación y para el remolino: la
	# dirección se expresa en el sistema del héroe, así que al girar el cuerpo la
	# hoja se lo lleva y barre el círculo sin cambiar de postura.
	var charging := attack_phase == AttackPhase.CHARGING or attack_phase == AttackPhase.SPIN
	var wants_stabilizer := (
		attack_phase == AttackPhase.NONE
		and not is_drawing_bow
		and not is_mounted()
		and not _weapon_on_back
		and not is_drawing_equipment()
		and not (is_playing_library_animation() and not _library_pose_allows_weapon())
		and equipped_category in ["sword", "axe", "torch"]
	)
	var target := 0.0
	if charging:
		# En la recarga la muñeca sí manda a fondo: el fotograma de la biblioteca
		# deja el arma horizontal, cruzando la cara, y lo que se pidió es verla
		# alzada al costado. Llevar su eje largo al cielo la saca de la cabeza y
		# la pone en silueta contra el fondo.
		target = 1.0
	elif wants_stabilizer:
		target = float(
			EQUIPMENT_SPECS[equipped_slot].get(
				"carry_stabilization", weapon_carry_stabilization
			)
		)
	_weapon_arm.stabilize_weight = move_toward(_weapon_arm.stabilize_weight, target, delta * 6.0)
	if target <= 0.0:
		return
	var grip_euler: Vector3 = _equipped_mesh.get_meta("grip_euler", Vector3.ZERO)
	_weapon_arm.weapon_axis_local = Basis.from_euler(grip_euler) * Vector3.UP
	if charging:
		# Ligeramente echada hacia atrás: leída de perfil, una vertical exacta se
		# confunde con el propio cuerpo.
		# El filo toma la misma dirección que el brazo: así prolonga la línea del
		# hombro en vez de formar un ángulo con ella.
		_weapon_arm.desired_axis_world = _hero_direction(charge_arm_direction)
		return
	var spec: Dictionary = EQUIPMENT_SPECS[equipped_slot]
	var carry: Vector3 = spec.get("carry_direction", Vector3.UP)
	_weapon_arm.desired_axis_world = (
		visual.global_basis.x.normalized() * carry.x
		+ Vector3.UP * carry.y
		- visual.global_basis.z.normalized() * carry.z
	).normalized()


func _apply_melee_hits(full_circle: bool = false) -> void:
	var origen := get_network_authoritative_position()
	var candidates: Array[Node] = []
	if not network_remote:
		for body in attack_area.get_overlapping_bodies(): candidates.append(body)

	# La consulta física adicional evita perder golpes si el arma cruza un
	# objetivo entre dos actualizaciones del monitor de Area3D. El giro cargado
	# usa una esfera porque alcanza a todo lo que rodea al héroe, no solo a lo
	# que tiene delante.
	var base := Basis(Vector3.UP,_yaw_red_autoritativo) if network_remote else visual.global_basis.orthonormalized()
	var forward := -base.z.normalized()
	var query := PhysicsShapeQueryParameters3D.new()
	if full_circle:
		var sphere := SphereShape3D.new()
		sphere.radius = spin_reach * spin_area_overreach
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, origen + Vector3.UP * 1.05)
	else:
		var query_shape := BoxShape3D.new()
		query_shape.size = Vector3(1.65, 2.05, _attack_reach)
		query.shape = query_shape
		query.transform = Transform3D(
			base,
			origen + Vector3.UP * 1.05 + forward * (_attack_reach * 0.52)
		)
	query.collision_mask = 5
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	for result in get_world_3d().direct_space_state.intersect_shape(query, 24):
		var collider := result.get("collider") as Node
		if collider != null and collider not in candidates:
			candidates.append(collider)

	var hit_world_target := false
	for body in candidates:
		hit_world_target = _apply_hit_to_body(body, 2 if full_circle else 1) or hit_world_target

	# Los bosques usan MultiMesh y una única malla física para decenas de miles
	# de troncos. Consultar su índice espacial al blandir el arma permite talar
	# cualquier árbol sin convertir cada ejemplar en un nodo/collider individual.
	if not hit_world_target and not network_remote:
		var vegetation := get_node_or_null("../VegetationScatter")
		if vegetation != null and vegetation.has_method("try_hit_nearest_tree"):
			vegetation.call(
				"try_hit_nearest_tree",
				equipped_category,
				equipped_item_id,
				global_position,
				forward,
				spin_reach * spin_area_overreach if full_circle else _attack_reach,
				self
			)


func _apply_hit_to_body(body: Node, impacts: int = 1) -> bool:
	if body == self or _attack_hits.has(body.get_instance_id()):
		return false
	if body is RPGEnemy:
		if network_remote and not _sesion_red().is_world_authority(): return false
		var origen := get_network_authoritative_position()+Vector3.UP*1.05
		var rayo := PhysicsRayQueryParameters3D.create(origen,(body as Node3D).global_position+Vector3.UP,1)
		rayo.exclude = [get_rid()]
		# Los personajes no son muros: el barrido puede alcanzar varios enemigos.
		for filtro in 24:
			var obstaculo := get_world_3d().direct_space_state.intersect_ray(rayo)
			if obstaculo.is_empty() or obstaculo.collider==body: break
			if not obstaculo.collider is CharacterBody3D: return false
			var excluidos := rayo.exclude
			excluidos.append(obstaculo.collider.get_rid())
			rayo.exclude = excluidos
			if filtro==23: return false
	elif network_remote:
		return false
	_attack_hits[body.get_instance_id()] = true
	if body is RPGEnemy and not network_remote and not _sesion_red().is_world_authority():
		melee_hit.emit(body)
		return true
	var hit_position := _equipped_mesh.global_position if _equipped_mesh != null else attack_area.global_position
	if network_remote: hit_position = get_network_authoritative_position()+Vector3.UP
	# El giro cargado reparte varios impactos por objetivo. Repetir la llamada
	# mantiene intacta la firma que ya implementan enemigos, vetas y props.
	if body.has_method("receive_tool_hit"):
		for _impact in maxi(impacts, 1):
			body.call("receive_tool_hit", equipped_category, equipped_item_id, hit_position, self)
	elif body.has_method("receive_melee_hit"):
		for _impact in maxi(impacts, 1):
			body.call("receive_melee_hit", hit_position)
	else:
		return false
	melee_hit.emit(body)
	return true


func _sync_with_mount() -> void:
	if not is_instance_valid(current_mount):
		control_state = ControlState.ON_FOOT
		current_mount = null
		collision.set_deferred("disabled", false)
		return
	global_position = current_mount.global_position
	velocity = current_mount.velocity


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	# Bajando pesa más que subiendo: el salto gana peso y deja de sentirse como
	# un descenso flotando de pie.
	var scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
	velocity += get_gravity() * scale * delta


func _apply_jump() -> void:
	if is_rolling or Input.is_action_pressed("dodge"):
		return
	if Input.is_action_just_pressed("jump") and is_on_floor() and attack_phase == AttackPhase.NONE:
		velocity.y = jump_velocity


func _apply_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	if camera != null and input_vector.length_squared() > 0.0:
		var camera_forward := -camera.global_basis.z
		var camera_right := camera.global_basis.x
		camera_forward.y = 0.0
		camera_right.y = 0.0
		direction = (camera_right.normalized() * input_vector.x - camera_forward.normalized() * input_vector.y).normalized()

	var target_speed := sprint_speed if _is_sprint_pressed() else walk_speed
	match attack_phase:
		AttackPhase.CHARGING:
			target_speed *= 0.34
		AttackPhase.SLASH:
			target_speed *= 0.28
		AttackPhase.SPIN:
			target_speed *= 0.14
	if is_drawing_bow:
		target_speed *= 0.30
	if is_guarding:
		target_speed *= 0.46
	var target_velocity := direction * target_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)
	if attack_phase == AttackPhase.SPIN:
		# Durante el remolino la orientación la manda `_update_attack`: dejar que
		# el movimiento gire al héroe rompería las vueltas completas.
		pass
	elif is_strafing():
		var strafe_camera := get_viewport().get_camera_3d()
		if strafe_camera != null:
			var strafe_forward := -strafe_camera.global_basis.z
			strafe_forward.y = 0.0
			if strafe_forward.length_squared() > 0.001:
				visual.rotation.y = lerp_angle(
					visual.rotation.y, atan2(-strafe_forward.x, -strafe_forward.z), turn_speed * delta
				)
	elif is_drawing_bow:
		var aim_camera := get_viewport().get_camera_3d()
		if aim_camera != null:
			var aim_forward := -aim_camera.global_basis.z
			aim_forward.y = 0.0
			if aim_forward.length_squared() > 0.001:
				var aim_yaw := atan2(-aim_forward.x, -aim_forward.z) + deg_to_rad(aiming_body_yaw_degrees)
				visual.rotation.y = lerp_angle(visual.rotation.y, aim_yaw, turn_speed * delta)
	elif direction.length_squared() > 0.0:
		var desired_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, turn_speed * delta)


func _update_locomotion_animation() -> void:
	# La carga y el remolino ya no congelan el cuerpo: sobreescriben solo el
	# brazo armado, así que las piernas siguen dando pasos debajo.
	if attack_phase == AttackPhase.SLASH or is_rolling:
		return
	# Las réplicas no chocan con el suelo y is_on_floor() siempre daría false.
	var grounded := _network_grounded if network_remote else is_on_floor()
	if not grounded:
		_play_animation(ANIM_JUMP, 0.1)
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > walk_speed + 0.8:
		_play_animation(ANIM_RUN, 0.12, clampf(horizontal_speed / sprint_speed * run_animation_rate, 0.95, 1.48))
	elif horizontal_speed > 0.25:
		_play_animation(ANIM_WALK, 0.12, clampf(horizontal_speed / walk_speed * walk_animation_rate, 0.82, 1.68))
	else:
		_play_animation(ANIM_IDLE, 0.18, 0.85)


func _play_animation(animation_name: String, blend: float, speed: float = 1.0) -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name, blend)
	animation_player.speed_scale = speed


func _configure_animation_loops() -> void:
	if animation_player == null:
		return
	for animation_name in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if animation_player.has_animation(animation_name):
			animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR


func _configure_realistic_hero() -> void:
	if realistic_animation == null:
		return
	if realistic_animation.has_animation(REALISTIC_IDLE):
		var idle := realistic_animation.get_animation(REALISTIC_IDLE)
		idle.loop_mode = Animation.LOOP_LINEAR
		realistic_animation.play(REALISTIC_IDLE)


func _update_realistic_visual(delta: float) -> void:
	if realistic_pose == null:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var motion_amount := clampf(horizontal_speed / sprint_speed, 0.0, 1.0)
	_realistic_stride += delta * lerpf(2.2, 8.5, motion_amount)
	var desired_position := Vector3.ZERO
	var desired_rotation := Vector3.ZERO

	if is_mounted():
		# La postura se acompasa a la zancada real del caballo, no a un seno
		# propio: al galope el jinete se levanta de la silla y se echa adelante,
		# como un jockey; al paso apenas se mueve.
		var gait := clampf(current_mount.gait, 0.0, 1.0)
		var stride := sin(current_mount.stride_phase * 2.0)
		desired_position.y = stride * lerpf(0.012, 0.075, gait)
		desired_position.z = -0.10 * gait
		desired_rotation.x = deg_to_rad(lerpf(-3.0, -19.0, gait) + stride * 2.6 * gait)
		desired_rotation.z = deg_to_rad(sin(current_mount.stride_phase) * 1.6 * gait)
	elif is_drawing_bow:
		desired_position.z = -0.07 * _bow_draw_strength
		desired_rotation.y = deg_to_rad(-8.0 * _bow_draw_strength)
	elif attack_phase == AttackPhase.CHARGING:
		# Cuclillas y temblor creciente: el héroe se hunde y vibra mientras
		# acumula fuerza, que es la lectura de "esto va a salir con todo".
		var tremble := sin(_charge_time * lerpf(14.0, 42.0, _charge_strength))
		desired_position.y = -0.09 * _charge_strength + tremble * 0.008 * _charge_strength
		desired_position.z = 0.10 * _charge_strength
		desired_rotation.x = deg_to_rad(-7.0 * _charge_strength)
		desired_rotation.y = deg_to_rad(tremble * 2.4 * _charge_strength)
	elif attack_phase == AttackPhase.SPIN:
		var spin_phase := clampf(_spin_time / maxf(spin_duration, 0.1), 0.0, 1.0)
		var lean := sin(spin_phase * PI)
		desired_position.y = 0.07 * lean
		desired_rotation.z = deg_to_rad(-9.0 * lean)
		desired_rotation.x = deg_to_rad(-5.0 * lean)
	elif is_attacking:
		var phase := clampf(_attack_time / maxf(_slash_duration, 0.05), 0.0, 1.0)
		var strike := sin(phase * PI)
		var follow_through := sin(phase * PI * 0.72)
		desired_position.z = -0.18 * strike
		desired_rotation.y = deg_to_rad(16.0 * strike - 6.0 * follow_through)
		desired_rotation.z = deg_to_rad(-4.0 * strike)
	else:
		desired_position.y = absf(sin(_realistic_stride)) * 0.035 * motion_amount
		desired_rotation.x = deg_to_rad(-5.5 * motion_amount)
		desired_rotation.z = deg_to_rad(sin(_realistic_stride * 0.5) * 1.8 * motion_amount)

	var blend := 1.0 - exp(-14.0 * delta)
	realistic_pose.position = realistic_pose.position.lerp(desired_position, blend)
	realistic_pose.rotation = realistic_pose.rotation.lerp(desired_rotation, blend)
	_update_weapon_grip_alignment(blend)


func _update_weapon_grip_alignment(blend: float) -> void:
	## Espada, hacha y antorcha ya no se recalculan cada fotograma: su agarre es
	## fijo dentro del hueso `Fist` y por eso acompañan al brazo como algo
	## sujeto de verdad. El arco es la única excepción, porque sus palas deben
	## quedar verticales y su cuerda mirando al arquero para que la flecha salga
	## por el centro del arco hacia el punto de mira.
	if _weapon_grip == null or _equipped_mesh == null or equipped_category != "bow":
		return
	var socket := _weapon_grip.get_parent() as Node3D
	if socket == null:
		return
	var aiming := is_drawing_bow or _bow_release_time > 0.0
	var aim := get_aim_direction()
	var plane_aim := aim.rotated(Vector3.UP, deg_to_rad(bow_plane_yaw_degrees))
	# En reposo el arco se lleva ladeado, como se carga de verdad: vertical
	# rozaba el suelo con la pala inferior a cada paso.
	var limb_reference := Vector3.UP
	if not aiming:
		limb_reference = Vector3.UP.rotated(
			(-visual.global_basis.z).normalized(), deg_to_rad(bow_rest_tilt_degrees)
		)
	var limb := limb_reference - plane_aim * limb_reference.dot(plane_aim)
	if limb.length_squared() < 0.01:
		var fallback := -visual.global_basis.z
		limb = fallback - plane_aim * fallback.dot(plane_aim)
	limb = limb.normalized()
	var side := plane_aim.cross(limb).normalized()
	# Ejes medidos en Bow_Wooden.obj: +Y recorre las palas, la cuerda vive en +X
	# y la flecha viaja hacia -X. Con la cuerda hacia el arquero el disparo sale
	# justo por el hueco de la empuñadura.
	var target_global_basis := Basis(-plane_aim, limb, -side).orthonormalized()
	var target_local_basis := socket.global_basis.orthonormalized().inverse() * target_global_basis
	_weapon_grip.basis = _weapon_grip.basis.orthonormalized().slerp(target_local_basis, clampf(blend, 0.0, 1.0))


func get_aim_direction() -> Vector3:
	if network_remote and (is_drawing_bow or _bow_release_time>0.0) and _last_arrow_direction.length_squared()>0.001: return _last_arrow_direction.normalized()
	## Al tensar el arco manda la cámara; el resto del tiempo, el frente del
	## héroe. Así el arco descansa vertical junto al cuerpo sin dar tirones.
	if is_drawing_bow or _bow_release_time > 0.0:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			return -camera.global_basis.z.normalized()
	var facing := -visual.global_basis.z
	facing.y = 0.0
	return facing.normalized() if facing.length_squared() > 0.001 else Vector3.FORWARD


func get_aim_point() -> Vector3:
	if network_remote: return get_arrow_launch_origin()+get_aim_direction()*80.0
	## Punto exacto de la retícula. Trazar el rayo desde la cámara por el centro
	## de la pantalla es lo que hace que la flecha se clave donde el jugador
	## está mirando, en vez de salir 14° hacia el suelo con el ángulo de cámara.
	var camera := get_viewport().get_camera_3d()
	var fallback := global_position + Vector3.UP * 1.45 + get_aim_direction() * bow_aim_distance
	if camera == null:
		return fallback
	var from := camera.global_position
	var to := from - camera.global_basis.z.normalized() * bow_aim_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 5)
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if not result.is_empty() else to


func get_arrow_speed() -> float:
	## Velocidad con la que saldría la flecha ahora mismo. La usan tanto el
	## disparo como la predicción de impacto, para que lo que se ve apuntando
	## sea exactamente lo que va a ocurrir al soltar.
	var strength := maxf(_bow_draw_strength, bow_min_release_strength)
	return lerpf(arrow_min_speed, arrow_max_speed, strength)


func solve_launch_direction(origin: Vector3, target: Vector3, speed: float) -> Vector3:
	## Dirección de tiro que hace pasar la flecha por el punto de la retícula,
	## contando con que le cae la gravedad encima.
	##
	## Antes se disparaba en línea recta hacia ese punto y la flecha caía por el
	## camino: a 179 m de la retícula acababa 151 m por debajo, medido. De ahí
	## que el punto de mira no indicase nada.
	##
	## Se resuelve la parábola de tiro bajo: para una distancia horizontal `d` y
	## un desnivel `h`, con velocidad `v` y gravedad `g`,
	##   tan(θ) = (v² − √(v⁴ − g·(g·d² + 2·h·v²))) / (g·d)
	## Si el radicando sale negativo el blanco está fuera de alcance y se tira
	## con los 45° de máximo recorrido, que es lo más lejos que puede llegar.
	var to_target := target - origin
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	if distance < 0.5 or speed <= 0.01:
		var straight := to_target
		return straight.normalized() if straight.length_squared() > 0.0001 else get_aim_direction()
	var horizontal := flat / distance
	var gravity := AdventureArrow.GRAVITY
	var height := to_target.y
	var speed_squared := speed * speed
	var radicand := (
		speed_squared * speed_squared
		- gravity * (gravity * distance * distance + 2.0 * height * speed_squared)
	)
	if radicand < 0.0:
		return (horizontal + Vector3.UP).normalized()
	var angle := atan((speed_squared - sqrt(radicand)) / (gravity * distance))
	return (horizontal * cos(angle) + Vector3.UP * sin(angle)).normalized()


func get_predicted_impact() -> Dictionary:
	## Dónde va a clavarse la flecha si se suelta ahora. Se integra la misma
	## parábola que usará el proyectil y se traza el trozo recorrido en cada
	## paso, así que el punto tiene en cuenta el terreno y lo que haya en medio.
	var origin := get_arrow_launch_origin()
	var target := get_aim_point()
	var speed := get_arrow_speed()
	var direction := solve_launch_direction(origin, target, speed)
	var velocity_now := direction * speed
	var point := origin
	var space := get_world_3d().direct_space_state
	var step := 1.0 / 30.0
	for _iteration in 240:
		var next := point + velocity_now * step
		velocity_now += Vector3.DOWN * AdventureArrow.GRAVITY * step
		var query := PhysicsRayQueryParameters3D.create(point, next, 5)
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return {
				"position": hit.position as Vector3,
				"reaches_aim": (hit.position as Vector3).distance_to(target) < 1.6,
			}
		point = next
	return {"position": point, "reaches_aim": false}


func get_arrow_launch_origin() -> Vector3:
	## La flecha nace en la empuñadura del arco, que es el punto por el que el
	## jugador la ve salir. Tomarla de la mano de la cuerda dejaba el astil
	## desalineado con el arco, medio palmo por encima.
	if equipped_category == "bow" and _equipped_mesh != null:
		return _equipped_mesh.global_position
	if _weapon_socket != null:
		return _weapon_socket.global_position
	return global_position + Vector3.UP * 1.45


func _build_bow_ik() -> void:
	if skeleton == null:
		return
	if skeleton.find_bone("UpperArm.L") < 0 or skeleton.find_bone("UpperArm.R") < 0:
		return
	# Los marcadores no gobiernan el IK —el modificador recibe los objetivos
	# como vectores—, pero dejan la postura de tiro visible en el árbol de
	# nodos y en las pruebas, que comprueban ahí la altura del anclaje.
	_bow_left_target = Marker3D.new()
	_bow_left_target.name = "BowLeftHandTarget"
	skeleton.add_child(_bow_left_target)
	_bow_right_target = Marker3D.new()
	_bow_right_target.name = "BowRightHandTarget"
	skeleton.add_child(_bow_right_target)
	_bow_ik = ARCHER_ARMS_SCRIPT.new() as ArcherArmsModifier
	_bow_ik.name = "BowArmsIK"
	skeleton.add_child(_bow_ik)
	_bow_ik.influence = 1.0
	_bow_ik.active = true
	_bow_ik_active = false


func _update_bow_pose(delta: float) -> void:
	_bow_release_time = maxf(_bow_release_time - delta, 0.0)
	if _aim_hold_time > 0.0:
		_aim_hold_time = maxf(_aim_hold_time - delta, 0.0)
		if _aim_hold_time <= 0.0 and not is_drawing_bow:
			_set_camera_aiming(false)
	if _bow_ik == null or _ride_influence > 0.001:
		return
	var active := equipped_category == "bow" and (is_drawing_bow or _bow_release_time > 0.0)
	# La influencia entra y sale con una rampa: pasar de golpe de la animación a
	# la postura de tiro daba un tirón muy visible en los hombros.
	var target_influence := 1.0 if active else 0.0
	_bow_ik.right_influence = move_toward(_bow_ik.right_influence, target_influence, delta * 7.0)
	if not active:
		_bow_ik.left_influence = move_toward(_bow_ik.left_influence, _shield_arm_influence, delta * 7.0)
		_bow_ik_active = _bow_ik.right_influence > 0.001
		if not _bow_ik_active:
			return
	else:
		_bow_ik.left_influence = _bow_ik.right_influence
	var release_ratio := _bow_release_time / maxf(bow_release_pose_duration, 0.01)
	var strength := _bow_draw_strength if is_drawing_bow else _bow_release_strength * release_ratio
	# El nodo importado de Quaternius está girado 180° respecto al `Visual`:
	# en espacio del esqueleto +Z es delante del personaje.
	#
	# El ancla de la cuerda es fija junto a la mejilla y la mano del arco se
	# deduce de ella siguiendo la puntería. Al derivar una de la otra, ancla,
	# cola de la flecha y empuñadura quedan alineadas: antes la cuerda tiraba de
	# un punto medio metro al lado de la flecha.
	var anchor := ANCHOR_AT_STRING.lerp(ANCHOR_AT_CHEEK, strength)
	var aim_local := (skeleton.global_basis.inverse() * get_aim_direction()).normalized()
	var draw_length := lerpf(0.34, 0.74, strength)
	# El brazo tiene un alcance finito: recortamos el tensado en vez de mover la
	# mano fuera de la línea de tiro, que rompería esa alineación.
	var to_anchor := anchor - LEFT_SHOULDER_LOCAL
	var along := to_anchor.dot(aim_local)
	var outside := to_anchor.length_squared() - ARM_REACH * ARM_REACH
	var discriminant := along * along - outside
	if discriminant > 0.0:
		draw_length = minf(draw_length, -along + sqrt(discriminant))
	_bow_ik.left_target = anchor + aim_local * maxf(draw_length, 0.2)
	_bow_ik.right_target = anchor
	_bow_ik.torso_twist = deg_to_rad(archer_torso_twist_degrees)
	if _bow_left_target != null:
		_bow_left_target.position = _bow_ik.left_target
	if _bow_right_target != null:
		_bow_right_target.position = _bow_ik.right_target
	_bow_ik_active = true
	if _nocked_arrow != null and _left_weapon_socket != null:
		# El astil descansa siempre sobre la empuñadura del arco y su cola
		# retrocede al tensar hasta encontrarse con la mano de la cuerda: es la
		# única forma de que la flecha que se ve encajada sea la que sale.
		var rest := get_arrow_launch_origin()
		var aim_forward := get_aim_point() - rest
		aim_forward = aim_forward.normalized() if aim_forward.length_squared() > 1.44 else get_aim_direction()
		_nocked_arrow.global_position = rest - aim_forward * lerpf(0.10, 0.34, strength)
		_nocked_arrow.look_at(_nocked_arrow.global_position + aim_forward, Vector3.UP, false)
	_update_dynamic_bow_string()


func _create_nocked_arrow() -> void:
	if _nocked_arrow != null or model_root == null:
		return
	_nocked_arrow = AdventureArrow.new()
	_nocked_arrow.name = "NockedArrow"
	model_root.add_child(_nocked_arrow)
	_nocked_arrow.set_physics_process(false)
	_nocked_arrow.set_meta("nocked_visual", true)
	_build_dynamic_bow_string()


func _build_dynamic_bow_string() -> void:
	_destroy_dynamic_bow_string()
	if model_root == null or _equipped_mesh == null or equipped_category != "bow":
		return
	_set_static_bow_string_visible(false)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.90, 0.76)
	for index in 2:
		var segment := MeshInstance3D.new()
		segment.name = "DynamicBowString%d" % (index + 1)
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.014
		cylinder.bottom_radius = 0.014
		cylinder.height = 0.1
		cylinder.radial_segments = 4
		cylinder.material = material
		segment.mesh = cylinder
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model_root.add_child(segment)
		_bow_string_segments.append(segment)


func _update_dynamic_bow_string() -> void:
	if _bow_string_segments.size() != 2 or _equipped_mesh == null or _weapon_socket == null:
		return
	# Coordenadas de la superficie `White` del Bow_Wooden de Quaternius.
	var upper_tip := _equipped_mesh.to_global(Vector3(0.369, 0.925, 0.0))
	var lower_tip := _equipped_mesh.to_global(Vector3(0.369, -0.925, 0.0))
	# La cuerda agarra la cola de la flecha; usar el centro del puño dejaba el
	# vértice de la V a un palmo del astil.
	var string_hand := _weapon_socket.global_position
	if _nocked_arrow != null and is_instance_valid(_nocked_arrow):
		string_hand = _nocked_arrow.global_position + _nocked_arrow.global_basis.z.normalized() * AdventureArrow.NOCK_OFFSET
	_orient_string_segment(_bow_string_segments[0], upper_tip, string_hand)
	_orient_string_segment(_bow_string_segments[1], lower_tip, string_hand)


func _orient_string_segment(segment: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		segment.visible = false
		return
	segment.visible = true
	var cylinder := segment.mesh as CylinderMesh
	if cylinder != null:
		cylinder.height = length
	var basis := Basis(Quaternion(Vector3.UP, delta / length)).orthonormalized()
	segment.global_transform = Transform3D(basis, (from + to) * 0.5)


func _set_static_bow_string_visible(visible_value: bool) -> void:
	if _equipped_mesh == null or equipped_category != "bow" or _equipped_mesh.mesh == null:
		return
	for surface in _equipped_mesh.mesh.get_surface_count():
		var source := _equipped_mesh.mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null or source.resource_name.to_lower() != "white":
			continue
		if visible_value:
			_equipped_mesh.set_surface_override_material(surface, null)
		else:
			var hidden := StandardMaterial3D.new()
			hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hidden.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
			hidden.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_equipped_mesh.set_surface_override_material(surface, hidden)


func _destroy_dynamic_bow_string() -> void:
	for segment in _bow_string_segments:
		if is_instance_valid(segment):
			segment.queue_free()
	_bow_string_segments.clear()
	_set_static_bow_string_visible(true)


func _build_right_hand_socket() -> void:
	if skeleton == null:
		push_error("El protagonista no tiene esqueleto para sujetar objetos.")
		return
	var fist_index := skeleton.find_bone("Fist.R")
	if fist_index < 0:
		push_error("El protagonista no tiene el hueso Fist.R.")
		return
	_weapon_socket = BoneAttachment3D.new()
	_weapon_socket.name = "RightHandSocket"
	skeleton.add_child(_weapon_socket)
	_weapon_socket.bone_name = "Fist.R"
	_weapon_socket.set_meta("equipment_socket", true)
	_weapon_grip = Node3D.new()
	_weapon_grip.name = "EquipmentGrip"
	_weapon_socket.add_child(_weapon_grip)


func _build_left_hand_socket() -> void:
	if skeleton == null:
		return
	var fist_index := skeleton.find_bone("Fist.L")
	if fist_index < 0:
		return
	_left_weapon_socket = BoneAttachment3D.new()
	_left_weapon_socket.name = "LeftHandWeaponSocket"
	skeleton.add_child(_left_weapon_socket)
	_left_weapon_socket.bone_name = "Fist.L"
	_left_weapon_socket.set_meta("equipment_socket", true)
	_shield_socket = BoneAttachment3D.new()
	_shield_socket.name = "LeftHandShieldSocket"
	skeleton.add_child(_shield_socket)
	_shield_socket.bone_name = "Fist.L"
	_shield_grip = Node3D.new()
	_shield_grip.name = "ShieldGrip"
	_shield_grip.position = Vector3(-0.08, 0.02, -0.08)
	_shield_grip.rotation = Vector3(PI * 0.5, 0.0, -PI * 0.5)
	_shield_socket.add_child(_shield_grip)


func _build_back_socket() -> void:
	## Un solo anclaje en el `Torso` sostiene lo que se lleva a la espalda: el
	## escudo pegado al cuerpo y el arma cruzada por delante de él.
	if skeleton == null or skeleton.find_bone("Torso") < 0:
		return
	_back_socket = BoneAttachment3D.new()
	_back_socket.name = "BackSocket"
	skeleton.add_child(_back_socket)
	_back_socket.bone_name = "Torso"
	_back_shield_grip = Node3D.new()
	_back_shield_grip.name = "BackShieldGrip"
	_back_socket.add_child(_back_shield_grip)
	_back_weapon_grip = Node3D.new()
	_back_weapon_grip.name = "BackWeaponGrip"
	_back_socket.add_child(_back_weapon_grip)


func _pose_of(position: Vector3, euler_degrees: Vector3, scale_value: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(euler_degrees.x), deg_to_rad(euler_degrees.y), deg_to_rad(euler_degrees.z)
	))
	return Transform3D(basis.scaled(Vector3.ONE * scale_value), position)


func _start_mesh_move(
	mesh: MeshInstance3D, destination: Node3D, target: Transform3D, duration: float, on_finished: Callable
) -> void:
	## Reaparentar conservando la pose del mundo y luego interpolar hacia la pose
	## de destino: así el objeto viaja de la mano a la espalda sin saltos y sin
	## necesitar una animación dedicada, que este rig no tiene.
	if mesh == null or destination == null:
		return
	_equipment_moves = _equipment_moves.filter(func(entry: Dictionary) -> bool:
		return entry["mesh"] != mesh
	)
	mesh.reparent(destination, true)
	_equipment_moves.append({
		"mesh": mesh, "from": mesh.transform, "to": target,
		"time": 0.0, "duration": maxf(duration, 0.01), "done": on_finished,
	})


func _update_mesh_move(delta: float) -> void:
	if _equipment_moves.is_empty():
		return
	var still_running: Array[Dictionary] = []
	for entry in _equipment_moves:
		# La comprobación va antes de la conversión: convertir un objeto ya
		# liberado aborta el script.
		if not is_instance_valid(entry["mesh"]):
			continue
		var mesh := entry["mesh"] as MeshInstance3D
		entry["time"] = float(entry["time"]) + delta
		var progress := clampf(float(entry["time"]) / float(entry["duration"]), 0.0, 1.0)
		var eased := progress * progress * (3.0 - 2.0 * progress)
		mesh.transform = (entry["from"] as Transform3D).interpolate_with(entry["to"] as Transform3D, eased)
		if progress < 1.0:
			still_running.append(entry)
			continue
		mesh.transform = entry["to"] as Transform3D
		var callback := entry["done"] as Callable
		if callback.is_valid():
			callback.call()
	_equipment_moves = still_running


func is_moving_equipment() -> bool:
	return not _equipment_moves.is_empty()


func is_drawing_equipment() -> bool:
	## Solo cuenta la transición del arma que se lleva en la mano: si lo que
	## viaja es el arma que se está guardando, el héroe puede seguir peleando.
	for entry in _equipment_moves:
		if entry["mesh"] == _equipped_mesh:
			return true
	return false


func _refresh_equipped_shield() -> void:
	if _shield_grip == null:
		return
	# El escudo puede estar en el brazo o colgado a la espalda: hay que vaciar
	# los dos agarres o cada refresco de equipo deja un escudo duplicado.
	for holder in [_shield_grip, _back_shield_grip]:
		if holder == null:
			continue
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_shield_mesh = null
	var inventory := _inventory_manager()
	if inventory == null:
		return
	var shield_id := String(inventory.call("get_equipped_item", "shield"))
	if shield_id.is_empty() or not bool(inventory.call("has_item", shield_id)):
		return
	var definition := inventory.call("get_item_definition", shield_id) as Dictionary
	var path := String(definition.get("obj_path", ""))
	var mesh := _equipment_mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = OBJ_LOADER.load_mesh(path)
		if mesh == null:
			return
		_equipment_mesh_cache[path] = mesh
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "Equipped%s" % shield_id
	_shield_mesh.mesh = mesh.duplicate() as ArrayMesh
	_shield_mesh.set_meta("medieval_shield_only", true)
	# El escudo cuelga de la espalda de salida; solo pasa al antebrazo cuando el
	# jugador se pone en guardia.
	is_guarding = false
	_shield_arm_influence = 0.0
	var holder: Node3D = _back_shield_grip if _back_shield_grip != null else _shield_grip
	holder.add_child(_shield_mesh)
	_shield_mesh.transform = _back_shield_pose()
	_configure_equipment_materials(_shield_mesh)


func _update_ride_pose(delta: float) -> void:
	## Manos a las riendas mientras cabalga. Sin esto los brazos seguían la
	## animación de estar sentado y quedaban colgando junto al cuerpo.
	if _bow_ik == null:
		return
	var riding := is_mounted()
	_ride_influence = move_toward(_ride_influence, 1.0 if riding else 0.0, delta * 5.0)
	if _ride_influence <= 0.001:
		return
	var gait := clampf(current_mount.gait, 0.0, 1.0) if riding else 0.0
	# Las riendas se acortan al galope: las manos suben y se acercan al pecho.
	var reins_height := lerpf(1.24, 1.34, gait)
	var reins_reach := lerpf(0.52, 0.40, gait)
	_bow_ik.left_target = Vector3(0.20, reins_height, reins_reach)
	_bow_ik.right_target = Vector3(-0.20, reins_height, reins_reach)
	_bow_ik.left_influence = _ride_influence
	_bow_ik.right_influence = _ride_influence
	_bow_ik.torso_twist = 0.0


func _update_shield_carry(delta: float) -> void:
	# Las réplicas de red no leen el ratón: sin esta guarda, el escudo de los
	# demás jugadores subía cuando el jugador local pulsaba el botón derecho.
	if is_mounted() or _ride_influence > 0.001:
		return
	if not network_remote:
		# Sin escudo en el inventario el héroe para con la espada: la biblioteca
		# trae `Sword_Block` justo para eso.
		var has_shield := _shield_mesh != null and is_instance_valid(_shield_mesh)
		var wants_guard := (
			Input.is_action_pressed("block")
			and not entrada_interfaz_bloqueada
			and (has_shield or equipped_category == "sword")
			and not is_mounted()
			and not is_rolling
			and not is_playing_gesture()
			and equipped_category != "bow"
			and attack_phase != AttackPhase.SPIN
		)
		if wants_guard and not is_guarding:
			_raise_shield()
		elif not wants_guard and is_guarding:
			_lower_shield()
	# Con la pose de escudo de la biblioteca en marcha, el IK del brazo estorba:
	# la propia animación ya coloca el antebrazo como debe.
	var wants_arm_ik := is_guarding and not is_playing_library_animation()
	_shield_arm_influence = move_toward(_shield_arm_influence, 1.0 if wants_arm_ik else 0.0, delta * 5.0)
	if _bow_ik != null and not is_drawing_bow and _shield_arm_influence > 0.001:
		_bow_ik.left_target = GUARD_HAND_TARGET
	# Con la maniobra terminada la cara del escudo se corrige contra el frente
	# del héroe: si dependiera del puño, giraría con cada paso.
	if is_guarding and _shield_mesh != null and is_instance_valid(_shield_mesh) and not is_moving_equipment():
		_shield_mesh.transform = _guard_shield_pose()


func _back_shield_pose() -> Transform3D:
	## Pose del escudo colgado a la espalda, con su desplazamiento lateral.
	return _pose_of(
		BACK_SHIELD_POSITION + Vector3(back_shield_side_offset, 0.0, 0.0),
		BACK_SHIELD_EULER_DEGREES,
		SHIELD_SCALE
	)


func _guard_shield_pose() -> Transform3D:
	## Pose local en el puño izquierdo que deja la cara del escudo mirando al
	## frente y su disco vertical.
	if _shield_grip == null:
		return Transform3D.IDENTITY
	var forward := -visual.global_basis.z.normalized()
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var canted := forward.rotated(Vector3.UP, deg_to_rad(GUARD_SHIELD_CANT_DEGREES))
	var target_basis := Basis(Vector3.UP.cross(canted), Vector3.UP, canted).orthonormalized()
	var local := _shield_grip.global_basis.orthonormalized().inverse() * target_basis
	# El desplazamiento va en el eje frontal del propio escudo: así la tabla se
	# adelanta a la mano en vez de quedar ensartada en ella.
	var offset := GUARD_SHIELD_ARM_OFFSET + local * Vector3(0.0, 0.0, GUARD_SHIELD_FORWARD_OFFSET)
	return Transform3D(local.scaled(Vector3.ONE * SHIELD_SCALE), offset)


func _raise_shield() -> void:
	is_guarding = true
	_cancel_bow_draw()
	_cancel_melee_charge()
	if _shield_grip != null and _shield_mesh != null:
		_start_mesh_move(_shield_mesh, _shield_grip, _guard_shield_pose(), shield_transition, Callable())
	guard_changed.emit(true)
	_notificar_combate("guardia",{"activo":true})


func _lower_shield() -> void:
	is_guarding = false
	if _back_shield_grip != null and _shield_mesh != null:
		_start_mesh_move(
			_shield_mesh, _back_shield_grip,
			_back_shield_pose(),
			shield_transition, Callable()
		)
	guard_changed.emit(false)
	_notificar_combate("guardia",{"activo":false})


func get_damage_multiplier() -> float:
	## Lo consulta el guion RPG al herir al héroe: en guardia el escudo absorbe
	## la mayor parte del golpe, y CUÁNTA depende del escudo que lleve. Con una
	## reducción fija, mejorar de rodela a égida no cambiaba nada y la mitad de
	## la forja no servía para nada.
	if not is_guarding:
		return 1.0
	var inventory := _inventory_manager()
	var shield_id := "" if inventory == null else String(inventory.call("get_equipped_item", "shield"))
	return RPGForge.shield_multiplier(shield_id, 1.0 - guard_damage_reduction)


func is_weapon_on_back() -> bool:
	return _weapon_on_back


func get_stowed_slot() -> int:
	return _stowed_slot


func _is_stowable(slot: int) -> bool:
	## Solo espada y hacha se llevan a la espalda. La antorcha quemaría la capa y
	## el arco necesita la mano izquierda libre para el escudo.
	return slot > 0 and EQUIPMENT_SPECS.has(slot) and String(EQUIPMENT_SPECS[slot].category) in ["sword", "axe"]


func stow_weapon() -> bool:
	if _weapon_on_back or _equipped_mesh == null or not _is_stowable(equipped_slot):
		return false
	if is_drawing_equipment() or attack_phase != AttackPhase.NONE:
		return false
	_weapon_on_back = true
	_stowed_slot = equipped_slot
	_idle_combat_time = 0.0
	_sheath_time = stow_transition
	_sheath_reverse = false
	_start_mesh_move(
		_equipped_mesh, _back_weapon_grip,
		_pose_arma_en_espalda(equipped_slot, equipped_item_id),
		stow_transition, Callable()
	)
	weapon_stowed.emit(true)
	return true


func draw_weapon() -> bool:
	if not _weapon_on_back or _equipped_mesh == null or is_drawing_equipment():
		return false
	_weapon_on_back = false
	_idle_combat_time = 0.0
	_sheath_time = stow_transition
	_sheath_reverse = true
	_start_mesh_move(
		_equipped_mesh, _weapon_grip,
		_pose_arma_en_mano(equipped_slot, equipped_item_id),
		stow_transition, Callable()
	)
	weapon_stowed.emit(false)
	return true


func _update_weapon_carry(delta: float) -> void:
	_update_mesh_move(delta)
	if _pending_draw_attack and not _weapon_on_back and not is_drawing_equipment():
		_pending_draw_attack = false
	if not _is_stowable(equipped_slot) or is_mounted():
		_idle_combat_time = 0.0
		return
	var sprinting := Vector2(velocity.x, velocity.z).length() > walk_speed + 0.8
	var calm := (
		attack_phase == AttackPhase.NONE
		and not is_drawing_bow
		and not is_guarding
		and not is_rolling
	)
	if sprinting and calm:
		_idle_combat_time += delta
	else:
		_idle_combat_time = 0.0
	if _idle_combat_time >= auto_stow_delay:
		stow_weapon()


func equip_item(slot: int, objeto_remoto: String = "") -> bool:
	if not EQUIPMENT_SPECS.has(slot) or _weapon_grip == null:
		return false
	var inventory := _inventory_manager()
	if inventory == null:
		return false
	var item_id := objeto_remoto if network_remote and not objeto_remoto.is_empty() else String(inventory.call("get_quick_slot_item", slot))
	if item_id.is_empty():
		action_feedback.emit("Todavía no posees ese objeto")
		return false
	_cancel_bow_draw()
	_cancel_melee_charge()
	if is_guarding and slot == 3:
		_lower_shield()
	# El arma que estaba en la mano no se destruye: viaja a la espalda mientras
	# se saca la nueva, que es lo que hace legible el cambio de equipo.
	var send_to_back := (
		_is_stowable(equipped_slot)
		and equipped_slot != slot
		and _equipped_mesh != null
		and not _weapon_on_back
		and _back_weapon_grip != null
	)
	# Si el hueco pedido es justo el que descansa en la espalda, la malla nueva
	# nace allí y sube a la mano: se ve desenvainar.
	var draw_from_back := (
		_back_weapon_grip != null
		and _stowed_slot == slot
		and (_weapon_on_back or _stowed_mesh != null)
	)
	if send_to_back:
		if _stowed_mesh != null and is_instance_valid(_stowed_mesh):
			_stowed_mesh.queue_free()
		_stowed_mesh = _equipped_mesh
		_stowed_slot = equipped_slot
		_start_mesh_move(
			_stowed_mesh, _back_weapon_grip,
			_pose_arma_en_espalda(equipped_slot, equipped_item_id),
			stow_transition, Callable()
		)
		_equipped_mesh = null
	elif _equipped_mesh != null:
		_equipped_mesh.get_parent().remove_child(_equipped_mesh)
		_equipped_mesh.queue_free()
		_equipped_mesh = null
	if draw_from_back:
		if _stowed_mesh != null and is_instance_valid(_stowed_mesh):
			_stowed_mesh.queue_free()
		_stowed_mesh = null
		_stowed_slot = 0
	_weapon_on_back = false
	_idle_combat_time = 0.0
	for child in _weapon_grip.get_children():
		_weapon_grip.remove_child(child)
		child.queue_free()

	var spec: Dictionary = EQUIPMENT_SPECS[slot]
	var definition := inventory.call("get_item_definition", item_id) as Dictionary
	var path := String(definition.get("obj_path", ""))
	if path.is_empty():
		return false
	var equipment_mesh := _equipment_mesh_cache.get(path) as ArrayMesh
	if equipment_mesh == null:
		equipment_mesh = OBJ_LOADER.load_mesh(path)
		if equipment_mesh == null:
			return false
		_equipment_mesh_cache[path] = equipment_mesh

	_equipped_mesh = MeshInstance3D.new()
	_equipped_mesh.name = spec.node_name
	# Cada objeto recibe su propia copia de malla/materiales. Así puede
	# desaparecer al cambiar de hueco sin dejar instancias de material colgadas.
	_equipped_mesh.mesh = equipment_mesh.duplicate() as ArrayMesh
	# La escala de la ranura por la corrección propia de la pieza: sin ella las
	# armas del pack medieval salen al triple de tamaño que las del pack RPG.
	_equipped_mesh.scale = Vector3.ONE * float(spec.scale) * _item_mesh_scale(item_id)
	_equipped_mesh.set_meta("equipment_slot", slot)
	var target_hand := String(spec.get("hand", "right"))
	var target_socket: BoneAttachment3D = _left_weapon_socket if target_hand == "left" else _weapon_socket
	if target_socket == null:
		return false
	if _weapon_grip.get_parent() != target_socket:
		_weapon_grip.reparent(target_socket, false)
	var grip_point := _punto_agarre(slot, item_id)
	var grip_euler := Vector3(
		deg_to_rad(float(spec.get("grip_euler_degrees", Vector3.ZERO).x)),
		deg_to_rad(float(spec.get("grip_euler_degrees", Vector3.ZERO).y)),
		deg_to_rad(float(spec.get("grip_euler_degrees", Vector3.ZERO).z))
	)
	# El cuarto de vuelta deja el filo hacia fuera sin cambiar la dirección
	# longitudinal del arma ni añadir correcciones por fotograma.
	grip_euler = (Basis.from_euler(grip_euler) * Basis(Vector3.UP, deg_to_rad(float(spec.get("grip_roll_degrees", 0.0))))).get_euler()
	_equipped_mesh.set_meta("held_in_right_hand", target_hand == "right")
	_equipped_mesh.set_meta("held_in_hand", target_hand)
	_equipped_mesh.set_meta("grip_position", HAND_GRIP_OFFSET)
	_equipped_mesh.set_meta("grip_point", grip_point)
	_equipped_mesh.set_meta("grip_euler", grip_euler)
	# El puño se cierra sobre `grip_point`: desplazamos la malla para que ese
	# punto caiga en el centro de la mano en lugar de su origen de exportación,
	# que en el hacha está a media caña y en la espada bajo el pomo.
	_weapon_grip.position = HAND_GRIP_OFFSET
	_weapon_grip.rotation = grip_euler
	_equipped_mesh.position = -grip_point * float(spec.scale) * _item_mesh_scale(item_id)
	if draw_from_back:
		_back_weapon_grip.add_child(_equipped_mesh)
		_equipped_mesh.transform = _pose_arma_en_espalda(slot, item_id)
		_start_mesh_move(
			_equipped_mesh, _weapon_grip,
			_pose_arma_en_mano(slot, item_id),
			stow_transition, Callable()
		)
	else:
		_weapon_grip.add_child(_equipped_mesh)
	_configure_equipment_materials(_equipped_mesh)
	if slot == 3:
		_equipped_mesh.set_meta("ranged_weapon", true)
	if slot == 4:
		_add_torch_light()

	equipped_slot = slot
	equipped_item_id = item_id
	equipped_item_name = String(definition.get("display_name", item_id.replace("_", " ")))
	equipped_category = String(spec.category)
	if _shield_grip != null:
		_shield_grip.visible = equipped_category != "bow"
	_attack_reach = maxf(float(spec.reach), 0.15)
	var box := attack_shape.shape as BoxShape3D
	if box != null:
		box.size = Vector3(1.7, 2.2, _attack_reach)
	attack_area.position.z = -_attack_reach * 0.52
	# La alineación global no debe esperar al siguiente fotograma: así al
	# cambiar de hueco nunca se ve un instante el hacha o la antorcha paralela
	# al brazo, y las pruebas/replicación reciben ya la pose definitiva.
	_update_weapon_grip_alignment(1.0)
	if _charge_effect != null and is_instance_valid(_charge_effect):
		_charge_effect.attach_to_weapon(_equipped_mesh)
	equipment_changed.emit(equipped_slot, equipped_item_name)
	_notificar_combate("equipo")
	return true


func get_equipped_mesh() -> MeshInstance3D:
	return _equipped_mesh


func get_equipped_item_name() -> String:
	return equipped_item_name


func get_equipped_item_id() -> String:
	return equipped_item_id


func get_equipped_category() -> String:
	return equipped_category


func get_arrow_count() -> int:
	var inventory := _inventory_manager()
	return int(inventory.call("get_arrow_count")) if inventory != null else 0


func get_bow_draw_strength() -> float:
	return _bow_draw_strength


func _update_bow_input(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_begin_bow_draw()
	if not is_drawing_bow:
		return
	_bow_draw_time += delta
	_bow_draw_strength = clampf(_bow_draw_time / bow_full_draw_time, 0.0, 1.0)
	bow_draw_changed.emit(_bow_draw_strength, get_arrow_count())
	if Input.is_action_just_released("attack"):
		_release_bow_arrow()


func _begin_bow_draw() -> bool:
	if entrada_interfaz_bloqueada or is_mounted() or is_attacking or equipped_category != "bow":
		return false
	if get_arrow_count() <= 0:
		action_feedback.emit("No tienes flechas: busca cofres o recógelas")
		bow_draw_changed.emit(0.0, 0)
		return false
	is_drawing_bow = true
	_bow_draw_time = 0.0
	_bow_draw_strength = 0.0
	_set_camera_aiming(true)
	_create_nocked_arrow()
	bow_draw_changed.emit(0.0, get_arrow_count())
	_notificar_combate("tensar",{"direccion":get_aim_direction()})
	return true


func _release_bow_arrow() -> bool:
	if not is_drawing_bow:
		return false
	# Un clic normal dura menos de 120 ms: exigir ese mínimo hacía que la mayoría
	# de los disparos no salieran nunca. Ahora el toque corto dispara flojo y
	# mantener pulsado sigue premiando con más potencia.
	var strength := maxf(_bow_draw_strength, bow_min_release_strength)
	var inventory := _inventory_manager()
	if inventory == null:
		_cancel_bow_draw()
		return false
	var arrow_item := String(inventory.call("consume_arrow"))
	if arrow_item.is_empty():
		_cancel_bow_draw()
		return false
	var origin := get_arrow_launch_origin()
	var aim_point := get_aim_point()
	var speed := lerpf(arrow_min_speed, arrow_max_speed, strength)
	# La flecha sale con el ángulo que compensa la caída, así que se clava en el
	# punto de la retícula en vez de varios metros por debajo.
	var direction := solve_launch_direction(origin, aim_point, speed)
	var arrow := _nocked_arrow
	_nocked_arrow = null
	if arrow == null:
		arrow = AdventureArrow.new()
	# La misma flecha visible que estaba encajada en la cuerda pasa a ser el
	# proyectil: no hay salto visual ni se crea una segunda flecha superpuesta.
	arrow.name = "ArrowProjectile"
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	if arrow.get_parent() == null:
		projectile_parent.add_child(arrow)
	else:
		arrow.reparent(projectile_parent, true)
	arrow.global_position = origin
	arrow.set_physics_process(true)
	arrow.launch(direction, speed, self, strength)
	if _sesion_red().is_networked(): _attack_cooldown = 0.20
	_notificar_combate("flecha",{"origen":origin,"direccion":direction,"fuerza":strength})
	_bow_release_strength = strength
	_bow_release_time = bow_release_pose_duration
	_aim_hold_time = aim_follow_after_shot
	_last_arrow_origin = origin
	_last_arrow_direction = direction
	_cancel_bow_draw()
	arrow_fired.emit(get_arrow_count(), strength)
	return true


func _cancel_bow_draw() -> void:
	if not is_drawing_bow and _bow_draw_strength <= 0.0:
		return
	is_drawing_bow = false
	_bow_draw_time = 0.0
	_bow_draw_strength = 0.0
	if _nocked_arrow != null:
		_nocked_arrow.queue_free()
		_nocked_arrow = null
	_destroy_dynamic_bow_string()
	if _aim_hold_time <= 0.0:
		_set_camera_aiming(false)
	bow_draw_changed.emit(0.0, get_arrow_count())
	_notificar_combate("reposo")


func _set_camera_aiming(active: bool) -> void:
	var camera_rig := get_node_or_null("../CameraRig")
	if camera_rig != null and camera_rig.has_method("set_aiming"):
		camera_rig.call("set_aiming", active)


func _clear_equipped_item() -> void:
	_cancel_bow_draw()
	_cancel_melee_charge()
	_weapon_on_back = false
	_idle_combat_time = 0.0
	if _stowed_mesh != null and is_instance_valid(_stowed_mesh):
		_stowed_mesh.queue_free()
	_stowed_mesh = null
	_stowed_slot = 0
	if _weapon_grip != null:
		for child in _weapon_grip.get_children():
			_weapon_grip.remove_child(child)
			child.queue_free()
	_equipped_mesh = null
	equipped_slot = 0
	equipped_item_name = "Manos vacías"
	equipped_item_id = ""
	equipped_category = ""
	_attack_reach = punch_reach
	if _shield_grip != null:
		_shield_grip.visible = true


func _reload_quaternius_hero() -> void:
	var previous_slot := equipped_slot
	_clear_equipped_item()
	for child in model_root.get_children():
		model_root.remove_child(child)
		child.queue_free()
	skeleton = null
	character_mesh = null
	animation_player = null
	realistic_skeleton = null
	realistic_animation = null
	_weapon_socket = null
	_left_weapon_socket = null
	_weapon_grip = null
	_shield_socket = null
	_shield_grip = null
	_shield_mesh = null
	_library = null
	_library_target = 0.0
	_gesture_name = ""
	_gesture_time = 0.0
	_idle_gesture_time = 0.0
	_sheath_time = 0.0
	_slash_chain = 0
	_slash_chain_window = 0.0
	_back_socket = null
	_back_shield_grip = null
	_back_weapon_grip = null
	_stowed_mesh = null
	_weapon_on_back = false
	_bow_ik = null
	_weapon_arm = null
	_bow_left_target = null
	_bow_right_target = null
	_bow_ik_active = false
	_load_quaternius_hero()
	_configure_realistic_hero()
	_build_right_hand_socket()
	_build_left_hand_socket()
	_build_bow_ik()
	_build_library_animation()
	_build_weapon_arm_modifier()
	_build_back_socket()
	_refresh_equipped_shield()
	_configure_animation_loops()
	_play_animation(ANIM_IDLE, 0.0)
	if previous_slot > 0:
		equip_item(previous_slot)


func _load_quaternius_hero() -> void:
	var loaded_scene := _load_gltf_scene(quaternius_hero_path)
	if loaded_scene != null:
		model_root.add_child(loaded_scene)
		loaded_scene.rotation_degrees.y = 180.0
		_recolor_hero_skin(loaded_scene)
		loaded_scene.set_meta("character_source", quaternius_hero_path)
	realistic_pose = model_root
	realistic_model = model_root
	skeleton = _find_skeleton(model_root)
	character_mesh = _find_visible_mesh(model_root)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	realistic_skeleton = skeleton
	realistic_animation = animation_player


func _recolor_hero_skin(loaded_scene: Node3D) -> void:
	# Cowboy_Male trae la cabeza casi negra en el material Skin. Ojos, cejas y
	# bigote usan Face/Hair, por lo que se conservan al aplicar un tono humano.
	skin_surface_count = 0
	var mesh_nodes: Array[Node] = loaded_scene.find_children("*", "MeshInstance3D", true, false)
	if loaded_scene is MeshInstance3D:
		mesh_nodes.push_front(loaded_scene)
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != "Skin":
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.albedo_color = hero_skin_color
			material.metallic = 0.0
			material.roughness = 0.86
			material.set_meta("human_skin_recolor", true)
			mesh_instance.set_surface_override_material(surface, material)
			mesh_instance.set_meta("human_skin_recolored", true)
			skin_surface_count += 1


func _load_gltf_scene(path: String) -> Node3D:
	var imported := ResourceLoader.load(path)
	if imported is PackedScene:
		var imported_node := (imported as PackedScene).instantiate() as Node3D
		if imported_node != null:
			imported_node.set_meta("loaded_via_project_importer", true)
		return imported_node
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("No se pudo cargar el modelo Quaternius: %s" % path)
		return null
	var node := document.generate_scene(state)
	if node != null:
		node.set_meta("loaded_via_project_importer", false)
	return node as Node3D


func _configure_equipment_materials(equipment: MeshInstance3D) -> void:
	for surface in equipment.mesh.get_surface_count():
		var source := equipment.mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		var material_name := source.resource_name.to_lower()
		var is_steel := "steel" in material_name or "grey" in material_name or "silver" in material_name
		var is_gold := "gold" in material_name or "yellow" in material_name
		var is_metal := is_steel or is_gold
		# Los MTL de los distintos packs usan nombres diferentes (Steel,
		# DarkSteel, Grey, Gold...). Normalizamos la familia completa para evitar
		# que las recompensas RPG recién equipadas aparezcan casi negras.
		if is_steel:
			material.albedo_color = Color("9aa9b5") if "light" in material_name else Color("687887")
		elif is_gold:
			material.albedo_color = Color("d29a32") if "dark" not in material_name else Color("986326")
		elif "wood" in material_name:
			material.albedo_color = Color("b0783f") if "light" in material_name else Color("8a5330")
		elif "red" in material_name:
			material.albedo_color = Color("c94a3b")
		elif "white" in material_name:
			material.albedo_color = Color("e1e1d8")
		elif "black" in material_name:
			material.albedo_color = Color("353b45")
		material.roughness = 0.36 if is_metal else 0.76
		material.metallic = 0.42 if is_metal else 0.03
		# Los MTL de Quaternius exportan Kd casi negro (el Bow_Wooden viene con
		# 0.051 0.026 0.041) porque el pack cuenta con sus propias texturas. Sin
		# un suelo de luminancia, cualquier objeto cuyo material no reconozcamos
		# por el nombre se ve como una silueta negra en cuanto entra en sombra.
		if material.albedo_color.get_luminance() < 0.20:
			var readable := material.albedo_color
			readable.v = maxf(readable.v, 0.55)
			readable.s = minf(readable.s, 0.58)
			material.albedo_color = readable
		if material_name == "fire":
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = Color(1.0, 0.19, 0.025)
			material.emission_energy_multiplier = 4.2
		equipment.mesh.surface_set_material(surface, material)


func _add_torch_light() -> void:
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	# Coordenada local del remate de WoodenTorch_Fire; hereda rotación y escala.
	light.position = Vector3(0.0, 2.62, 0.0)
	light.light_color = Color(1.0, 0.42, 0.12)
	light.light_energy = 4.2
	light.omni_range = 13.0
	light.shadow_enabled = true
	light.set_meta("equipped_torch_light", true)
	_equipped_mesh.add_child(light)


func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)


func _find_skeleton(parent: Node) -> Skeleton3D:
	for node in parent.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _find_visible_mesh(parent: Node) -> MeshInstance3D:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			return mesh_instance
	return null


func _build_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.name = "PlayerName"
	_nameplate.position = Vector3(0.0, 2.35, 0.0)
	_nameplate.text = player_display_name
	_nameplate.font_size = 34
	_nameplate.outline_size = 8
	_nameplate.modulate = Color(1.0, 0.91, 0.66)
	_nameplate.outline_modulate = Color(0.04, 0.055, 0.07, 0.94)
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.no_depth_test = true
	_nameplate.visible = network_remote
	add_child(_nameplate)


func _update_network_replica(delta: float) -> void:
	if not _network_state_ready:
		return
	_network_motion.advance(delta,float(Time.get_ticks_usec())/1000000.0)
	global_position = _network_motion.position
	if attack_phase!=AttackPhase.SPIN and not is_rolling: visual.rotation.y = _network_motion.yaw
	velocity = _network_motion.velocity
	_network_grounded = _network_motion.grounded
	_update_locomotion_animation()


func _on_local_identity_changed(name_value: String, index_value: int) -> void:
	if not network_remote:
		apply_identity(name_value, index_value)


func _on_inventory_equipment_changed(category: String, _item_id: String) -> void:
	if category == "shield":
		_refresh_equipped_shield()
	elif category == equipped_category and equipped_slot > 0:
		equip_item(equipped_slot)


func _inventory_manager() -> Node:
	return get_node_or_null("/root/InventoryManager")


func _character_path(index_value: int) -> String:
	return CHARACTER_PATHS[clampi(index_value, 0, CHARACTER_PATHS.size() - 1)]


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO


func _notificar_combate(tipo: String, datos: Dictionary = {}) -> void:
	if not network_remote: _sesion_red().enviar_accion_combate(self,tipo,datos)


func _sesion_red() -> Node:
	return get_node("/root/NetworkSession")
