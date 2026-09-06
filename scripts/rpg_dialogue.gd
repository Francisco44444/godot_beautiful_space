class_name RPGDialogue
extends RefCounted

## La memoria conversacional de Aeloria.
##
## Antes cada habitante soltaba siempre el mismo párrafo, dijeras lo que dijeras
## y fuera la primera vez o la décima. Eso no es un personaje: es un cartel.
##
## Aquí una conversación se compone de tres piezas, y las tres dependen de lo que
## ha pasado ANTES:
##
##   SALUDO      cambia según cuántas veces habéis hablado y cuántos encargos le
##               has cumplido a ESA persona. La primera vez se presentan; a la
##               tercera ya no; cuando les has resuelto algo, cambian de tono.
##   CUERPO      el encargo o el acto, que lo pone quien llama a esta clase.
##   COLETILLA   una frase pegada al momento: si es de noche, si vas herido, si
##               acabas de cerrar un acto. Es lo que hace que parezca que te
##               están mirando a ti y no a un jugador cualquiera.
##
## Y cada uno habla a su manera: Tavia nombra cosas que se tocan, Brenn deja las
## frases sin terminar, Ysra mide, Nara da por hecho lo peor, Calen se disculpa
## sin decirlo, Maela cuenta en pasos y Orin gruñe.

## Cuántas conversaciones separan un escalón de trato del siguiente.
const FAMILIAR := 2
const CONFIANZA := 5

const GREETINGS := {
	"tavia": [
		"«Tú no eres de aquí. Se te nota en cómo pisas la hierba.»",
		"«Otra vez. Bien.» Sigue a lo suyo mientras habla.",
		"«Ya te oí llegar. Andas distinto que los de la villa.»",
		"Deja el azadón antes de hablarte, que es lo más parecido a un abrazo que hace Tavia.",
	],
	"brenn": [
		"No dice nada. Espera a que hables tú.",
		"«Ah. Tú.» Vuelve a mirar al bosque.",
		"«Pensé que no volvías.» No aclara si le alegra.",
		"«Siéntate si quieres.» Es la primera vez que te ofrece algo.",
	],
	"ysra": [
		"«No te muevas ahí, que me tapas el norte.»",
		"«Segunda visita. Anotado.»",
		"«Vienes con una frecuencia razonable. Eso me gusta.»",
		"«Me has hecho revisar dos cosas que daba por ciertas. Gracias.»",
	],
	"nara": [
		"«Bebe antes de hablar. Aquí se habla después.»",
		"«Has vuelto. En el desierto eso ya es noticia.»",
		"«Empiezo a contar contigo, y eso aquí es imprudente.»",
		"Te sirve agua sin que se la pidas.",
	],
	"maela": [
		"«¿Vienes de fuera? Espera, no me lo digas: de fuera.» Coge el lápiz.",
		"«Vuelves. Al mapa le vienen bien los que vuelven.»",
		"«Te he puesto en el mapa. Un punto pequeño, no te emociones.»",
		"«Ya no eres un punto. Eres una línea, que es más difícil de dibujar.»",
	],
	"orin": [
		"«Si vienes a mirar, mira desde ahí.»",
		"«Otra vez tú. ¿Se te ha roto algo?»",
		"«Tú al menos devuelves las cosas enteras.»",
		"«Te guardo el mejor acero. No lo vayas contando.»",
	],
	"calen": [
		"«Alto ahí.» Se relaja al verte las manos vacías.",
		"«Perdona lo del otro día. Es la costumbre.»",
		"«Contigo hablo más claro que con mis propios hombres.»",
		"«Hay algo que tendré que contarte. Todavía no.»",
	],
}

const ASIDES := {
	"tavia": {
		"noche": "«Vete a dormir, anda. Lo que hay ahí fuera de noche no se arregla con espada.»",
		"herido": "«Estás sangrando en mi huerto. Siéntate.»",
		"acto": "«Desde lo tuyo, el bosque suena distinto. Más lleno.»",
		"dia": "«Aprovecha la luz, que dura poco en esta época.»",
	},
	"brenn": {
		"noche": "«De noche no bajes. Ni tú.»",
		"herido": "«Eso te lo ha hecho algo con las manos. Ten cuidado.»",
		"acto": "«Duermo seis horas seguidas desde entonces. Seis.»",
		"dia": "«Con luz se ve menos de lo que crees.»",
	},
	"ysra": {
		"noche": "«Buena hora. La única hora, en realidad.»",
		"herido": "«Pierdes sangre a un ritmo que no me gusta calcular.»",
		"acto": "«La constelación va con doce segundos de adelanto. Es un buen error.»",
		"dia": "«De día esto es un tubo mirando a nada.»",
	},
	"nara": {
		"noche": "«De noche el desierto se estrecha. No es una forma de hablar.»",
		"herido": "«La arena entra en las heridas. Lávatelas antes de dormir.»",
		"acto": "«El pozo ha subido dos palmos. No sé por qué. Lo sé por qué.»",
		"dia": "«A mediodía no se camina. A mediodía se espera.»",
	},
	"maela": {
		"noche": "«¿A dónde vas a estas horas? Ni siquiera yo dibujo de noche.»",
		"herido": "«Te voy a marcar por dónde NO ir. Que también sirve.»",
		"acto": "«He tenido que redibujar media hoja por tu culpa. Encantada.»",
		"dia": "«Buena luz para medir. Si te aburres, cuéntame los pasos hasta el molino.»",
	},
	"orin": {
		"noche": "«La fragua está apagada. Vuelve mañana si quieres filo.»",
		"herido": "«Con esa herida no aguantas un mandoble. Ni el tuyo.»",
		"acto": "«Se ha vendido más acero esta semana que en todo el invierno. La gente vuelve a salir.»",
		"dia": "«Está caliente. Si vas a pedirme algo, pídemelo ya.»",
	},
	"calen": {
		"noche": "«Doblo la guardia de noche. No sirve de nada, pero se duerme mejor.»",
		"herido": "«Ve a que te vean eso. Es una orden, y no mando en ti.»",
		"acto": "«Un nombre menos ahí fuera. Cuatro me faltan para dormir.»",
		"dia": "«Los portones abiertos otra vez. Pequeñas cosas.»",
	},
}


## LAS RESPUESTAS. Cada conversación se puede contestar de tres maneras, y las
## tres cuestan algo distinto:
##
##   HUMILDE  te rebajan lo que piden y te lo cuentan todo, pero pagan menos.
##            Es el camino de quien prefiere terminar a lucirse.
##   DIRECTO  el trato tal cual. Ni concesiones ni alardes.
##   ALTIVO   te piden MÁS y pagan MUCHO más, y encima NO te dicen dónde
##            buscar ni cuál es el punto débil del jefe: te lo has ganado.
##
## Esa última es la consecuencia que de verdad importa. Contestarle mal a Ysra
## no te resta puntos en una tabla invisible: te deja subiendo a las Cumbres
## Blancas sin saber que la coraza del Coloso sólo cede al giro cargado.
const TONES := {
	"humilde": {"needed": -1, "reward": 0.7, "regard": 1, "hint": true},
	"directo": {"needed": 0, "reward": 1.0, "regard": 0, "hint": true},
	"altivo": {"needed": 2, "reward": 1.7, "regard": -1, "hint": false},
}

const REPLIES := {
	"tavia": {
		"humilde": "«Dime qué hace falta y lo hago.»",
		"directo": "«Cuéntame dónde y me pongo.»",
		"altivo": "«Cinco setales son pocos. Dime un número que valga la pena.»",
	},
	"brenn": {
		"humilde": "«No hace falta que bajes tú. Voy yo.»",
		"directo": "«Entendido.»",
		"altivo": "«Tú le contestaste a esa voz. Yo la voy a callar.»",
	},
	"ysra": {
		"humilde": "«Explíquemelo despacio y no me dejaré nada.»",
		"directo": "«Deme la cifra y subo.»",
		"altivo": "«Guárdese los cálculos. Lo veré con mis ojos.»",
	},
	"nara": {
		"humilde": "«Beberé, escucharé y saldré al alba, como se hace aquí.»",
		"directo": "«Dime por dónde y voy.»",
		"altivo": "«He cruzado peores dunas que la tuya.»",
	},
	"maela": {
		"humilde": "«Enséñame el mapa y no me saldré de él.»",
		"directo": "«Márcame el punto.»",
		"altivo": "«Tu mapa me sobra. Sé leer un camino.»",
	},
	"orin": {
		"humilde": "«Dime cuánto y de qué, y te lo traigo entero.»",
		"directo": "«Trato hecho.»",
		"altivo": "«Tráeme tú el hierro. Yo pego mejor que forjas.»",
	},
	"calen": {
		"humilde": "«A sus órdenes, si me deja hacerlo a mi manera.»",
		"directo": "«Cuente conmigo.»",
		"altivo": "«No necesito su bendición para entrar ahí.»",
	},
}


static func replies(npc_id: String) -> Array[Dictionary]:
	## Las tres respuestas, con la voz de quien contesta y su efecto.
	var voice: Dictionary = REPLIES.get(npc_id, {
		"humilde": "«Dígame qué hace falta.»",
		"directo": "«De acuerdo.»",
		"altivo": "«Puedo con algo más que eso.»",
	})
	var out: Array[Dictionary] = []
	for tone in ["humilde", "directo", "altivo"]:
		out.append({
			"tone": tone,
			"line": String(voice.get(tone, "")),
			"effect": (TONES[tone] as Dictionary).duplicate(),
		})
	return out


static func regard_line(regard: int) -> String:
	## Cómo te trata quien ya te conoce. No es una barra: es una frase.
	if regard <= -3:
		return "Te habla sin mirarte."
	if regard <= -1:
		return "Contesta corto."
	if regard >= 3:
		return "Te trata como a uno de los suyos."
	if regard >= 1:
		return "Se le nota que le caes bien."
	return ""


static func tier(met: int, helped: int) -> int:
	## El trato sube con las visitas, pero sube ANTES si le has resuelto algo:
	## cumplirle un encargo a alguien vale más que pasarte cinco veces a saludar.
	if helped >= 2 or (helped >= 1 and met >= FAMILIAR):
		return 3
	if met >= CONFIANZA:
		return 2
	if met >= 1:
		return 1
	return 0


## Para los habitantes que no tienen voz propia escrita: no se quedan mudos,
## pero tampoco fingen una personalidad que no se ha trabajado.
const GENERIC := [
	"Te mira de arriba abajo sin disimular.",
	"«Otra vez por aquí.»",
	"«Ya me sé tu cara.»",
	"«Contigo se puede hablar. No es lo normal últimamente.»",
]


static func greeting(npc_id: String, met: int, helped: int) -> String:
	var lines: Array = GREETINGS.get(npc_id, GENERIC)
	if lines.is_empty():
		return ""
	return String(lines[clampi(tier(met, helped), 0, lines.size() - 1)])


static func aside(npc_id: String, moment: String, wounded: bool, closed_act: bool) -> String:
	## El orden importa: si vas herido eso es lo que un vecino te dice primero,
	## por encima de la hora que sea.
	var pool: Dictionary = ASIDES.get(npc_id, {})
	if pool.is_empty():
		return ""
	if wounded:
		return String(pool.get("herido", ""))
	if closed_act:
		return String(pool.get("acto", ""))
	if moment == "Noche":
		return String(pool.get("noche", ""))
	return String(pool.get("dia", ""))


static func directions(npc_id: String, place: String, bearing: String) -> String:
	## Indicar el camino también es cosa de carácter: Maela da rumbo y pasos,
	## Brenn dice "por ahí" y confía en que te apañes.
	if place.is_empty():
		return ""
	# La línea de "dónde buscar" ya viene con su punto final: si no se le quita,
	# la frase compuesta sale con dos ("...de Robledal.. al norte").
	var head := place.strip_edges().trim_suffix(".")
	var tail := bearing.strip_edges().trim_suffix(".")
	place = head
	bearing = tail
	if bearing.is_empty():
		match npc_id:
			"brenn":
				return "«%s.» Señala con la barbilla. «Ya lo encontrarás.»" % place
			_:
				return "«%s.»" % place
	match npc_id:
		"maela":
			return "«%s, %s. Y ojo con no pasarte: desde ahí el sendero engaña.»" % [place, bearing]
		"ysra":
			return "«%s, %s. Si te desvías más de un cuarto, lo notarás en el frío.»" % [place, bearing]
		"orin":
			return "«%s, %s. Y vuelve entero, que el acero cuesta.»" % [place, bearing]
		"nara":
			return "«%s, %s. Sal al alba o no salgas.»" % [place, bearing]
		"calen":
			return "«%s, %s. Llévate a alguien, si encuentras a alguien.»" % [place, bearing]
		"brenn":
			return "«%s.» Señala con la barbilla. «%s. Ya lo encontrarás.»" % [place, bearing]
		_:
			return "«%s, %s.»" % [place, bearing]
