extends RefCounted

const TITULOS := ["Las semillas del recuerdo", "El eco de la bruma", "El observatorio dormido", "El agua de las dunas", "La campana sin nombre"]
const OBJETIVOS := ["Despierta las piedras siguiendo el ciclo de una semilla.", "Equilibra la balanza del recuerdo con cuatro cargas de piedra.", "Orienta los tres espejos hacia las constelaciones grabadas.", "Conecta los canales hasta llenar las tres acequias del oasis.", "Devuelve a las campanas el eco de los tres nombres."]
const PISTAS := ["Primero nace, luego respira, después da sombra.", "La inscripción exige cuatro. Las rocas pesan uno, dos y tres.", "El cielo está escrito como II · I · III. Cada espejo tiene cuatro posiciones.", "Las marcas de las válvulas dicen I–II, II–III y III. Cada giro abre lo cerrado y cierra lo abierto.", "Escucha el eco: tu nombre, el de Mira, el de Brenn."]
const SIMBOLOS := [["Semilla","Hoja","Roble"],["Roca · peso I","Roca · peso II","Roca · peso III"],["Espejo lunar","Espejo estelar","Espejo solar"],["Canal de poniente","Canal central","Canal de levante"],["Mira","Brenn","Tu nombre"]]
static func actos(originales: Array[Dictionary]) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for i in originales.size():
		var a := originales[i].duplicate(true)
		a.title = TITULOS[i]
		a.teaches = ["Leer un ciclo natural en los símbolos", "Combinar pesos y comprobar la balanza", "Relacionar marcas y orientación", "Seguir cómo se comunican las válvulas", "Recordar los nombres en el orden del eco"][i]
		a.goal = OBJETIVOS[i]
		a.opening = "El lugar conserva un nombre entre sus piedras. Lee los símbolos del santuario y reconstruye su mecanismo para devolver la voz a la campana."
		a.hint = PISTAS[i]
		a.closing = "Las tres piedras se iluminan y el bronce vuelve a pronunciar %s. El paisaje recupera su voz." % a.relic
		salida.append(a)
	return salida

const RECADOS := [
	["El mapa después de la lluvia", "Maela secó sus mojones en una arqueta al salir del puerto. El agua borró las marcas del sendero. Recupera las piezas verdes para que vuelva a dibujar la ruta."],
	["El temple del regreso", "Orin quiere reparar las herramientas de quienes vuelven al valle. Guardó cristal verde en una arqueta fuera de la villa; busca su sello de yunque."],
	["El herbario de Tavia", "Tavia dejó las muestras del robledal en una arqueta de campo. Sigue el rumbo de su mapa y trae los cristales que sujetan las hojas secas."],
	["La canción del molino", "El viejo camino conserva las piedras con las que se marcaba el compás al caminar. Tavia recuerda dónde guardaron las últimas: en una arqueta del camino blanco."],
	["La corona de la primera alcaldesa", "Antes de tener casas, Robledal ya tenía una alcaldesa. Tavia quiere llevar su corona a la plaza; la arqueta de los fundadores sigue en las afueras."],
	["Las letras de la niebla", "Brenn busca los fragmentos del antiguo cartel de la posada. Están protegidos en una arqueta al pie de la sierra. Devuélveselos para que la aldea recupere su nombre."],
	["El recuerdo de una voz", "El padre de Brenn marcaba los senderos orientales con piedras verdes. La última caja de señales quedó en el bosque. Encuéntrala y sigue el camino de vuelta."],
	["La llave prestada", "La aldea prestó una llave al último cartógrafo de las grutas. Brenn señala en tu mapa dónde guardaba su equipaje. Hay copias suficientes para conservar el acceso."],
	["Once segundos de arco", "Ysra ha calculado el error de la lente del observatorio: once segundos de arco. Necesita cristal de hielo del estuche de instrumentos que dejó fuera de la aldea."],
	["Las cotas olvidadas", "La nieve cubrió las marcas de la antigua expedición. Ysra conserva su ubicación en el mapa: recupera las piedras de medición de la arqueta de la cumbre."],
	["La página del cielo quieto", "Falta el séptimo volumen del observatorio. Explica qué hacer cuando el cielo parece detenerse. Encuentra la arqueta de libros y devuélveselo a Ysra."],
	["La memoria de los pozos", "Nara quiere recuperar las señales verdes de los antiguos pozos. Las guardaron en una arqueta de las dunas antes de la última tormenta."],
	["Un cristal al mediodía", "El cristal del desierto conserva el calor del sol. Nara dejó una muestra envuelta en paños fuera del oasis. Sigue el rumbo del mapa y tráela a la sombra."],
	["Las señales del relevo", "Calen está reconstruyendo las antiguas rutas entre castillos. Busca los cristales de señal en la arqueta indicada y ayúdale a volver a unir los caminos."],
	["Las órdenes del farero", "Una caja conserva las señales con las que el farero anunciaba el regreso de los viajeros. Calen quiere que vuelvan a leerse desde las almenas."],
	["El cáliz del juramento", "El cáliz desapareció cuando callaron las campanas. Calen encontró su marca en el inventario de una arqueta: recupéralo para que la villa pueda renovar su promesa."],
	["Las luces del confín", "Más allá de los árboles rojos quedaron cristales que reflejan el amanecer. Calen te pide que encuentres la arqueta del confín y vuelvas con una parte de aquella luz."],
	["Oro para un nuevo hogar", "Orin quiere forjar herrajes que duren para los refugios del valle. Hay lingotes guardados en una arqueta del camino; tráele oro entero, sin fundir monedas."],
]
static func encargos(originales: Array[Dictionary]) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for i in originales.size():
		var q := originales[i].duplicate(true)
		q.kind = 2
		if originales[i].kind == 0: q.target = "Crystal4" if i % 2 == 0 else "Crystal2"
		q.title = RECADOS[i][0]
		q.brief = RECADOS[i][1] + " Recupera la arqueta y entrega %d piezas a %s." % [q.needed,q.giver.capitalize()]
		q.where = "La cartografía del encargo señala la arqueta de «%s»." % q.title
		salida.append(q)
	return salida
