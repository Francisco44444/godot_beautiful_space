# Luciérnagas y crepúsculo — 11 de noviembre de 2026

## El corte reproducido

En 0.1.17, el enjambre del valle se apagaba al superar una luz diurna de 0,25.
La prueba del bosque real a 0,26 encontraba el nodo oculto: no había estados
intermedios. El Bosque Tenebroso quedaba excluido del ambiente nocturno.

Ahora el brillo sigue una curva suave entre 0,32 y 0,06 de luz diurna, tanto
al anochecer como al amanecer. Durante la noche completa conserva el nivel 1.
De día los enjambres quedan ocultos y se evitan las consultas de bioma,
árboles y altura que no necesita un efecto apagado.

El fundido multiplica el pulso en los vértices. Conserva la deriva y el
parpadeo de cada luciérnaga, sin añadir ese cálculo a cada píxel del halo.
El ambiente se sigue revisando cada 0,3 segundos; no se añade otro callback
ni otro temporizador.

## Dos bosques y el claro

El valle mantiene sus luces verdes. El Tenebroso utiliza el mismo enjambre
de 112 instancias, con un tono ámbar que cambia gradualmente al cruzar de
bioma. Las luciérnagas ambientales se colocan cerca de los árboles y del
suelo; no se añaden a nieve, desierto ni posiciones elevadas sobre el terreno.

El claro descubierto conserva sus 256 luces y su condición de misión.
Su celebración acompaña el fundido del crepúsculo. El enjambre ambiental
anclado allí recuerda su centro real; las revisiones en reposo no lo vuelven
a recolocar y al marcharse recupera el entorno del héroe.

Se reutilizan los MultiMesh y materiales existentes. No se crean luces
puntuales ni nodos adicionales para cada luciérnaga. El resplandor sigue
respetando la profundidad de árboles, suelo y edificios.

## Coste con el mundo activo

Apple M2 Pro, Godot 4.7.1, Metal Forward+, 1600×900, escala 1, MSAA 0,
VSync desactivado, LOD a 400 m y umbral 0,85. Héroe quieto y protegido del
daño durante la sonda; IA, animaciones y HUD activos. Se comprueba su posición
y que los 240 fotogramas de cada tanda se dibujen realmente.

Se alterna anterior/nuevo/nuevo/anterior, con 100 fotogramas de calentamiento
y 240 medidos. El parpadeo, deriva y ascenso de los enjambres repiten el mismo
reloj por fotograma en ambos programas; el resto del mundo continúa activo.
Dos ensayos previos con reloj libre mostraban variación apreciable entre
controles, especialmente junto a las luces cercanas del claro. No se usan
para atribuir una ganancia o pérdida al cambio.

| Vista | FPS anteriores | FPS nuevos | p95 anterior / nuevo |
| --- | ---: | ---: | ---: |
| Valle de noche, fija | 47,94 | 48,09 | 22,65 / 22,60 ms |
| Valle de noche, movimiento | 47,07 | 47,15 | 27,75 / 27,98 ms |
| Valle de día | 48,60 | 48,41 | 22,28 / 22,46 ms |
| Valle al ocaso | 37,39 | 37,50 | 28,72 / 28,62 ms |
| Tenebroso de noche | 60,70 | 61,29 | 16,85 / 16,78 ms |
| Claro de noche | 63,29 | 63,26 | 17,52 / 17,45 ms |

Las diferencias son pequeñas: esta revisión no acredita una mejora general
de FPS. El objetivo de 100–120 FPS sigue pendiente. No se recortan hierba,
árboles, alcance, sombras ni resolución. Estas mediciones corresponden a este
Mac y estas vistas, no a Windows.

## Comprobaciones

`firefly_transition_test.gd` recorre el encendido y apagado completos,
comprueba niveles intermedios, brillo nocturno, los dos biomas, el límite de
altura y la celebración del claro. También verifica el reposo y el regreso
del enjambre ambiental. Está incluida en la compilación de Windows.

Con `--render-check`, un SubViewport independiente comprueba los píxeles de
una luciérnaga apagada, tenue y encendida. Volver al nivel tenue reproduce la
misma imagen. Así no basta con que el parámetro de GDScript tenga un valor:
el shader debe aplicarlo realmente. Esta pasada se ejecuta con Metal.

Nueve defectos inyectados hacen fallar los controles previstos: corte nocturno,
brillo binario, Tenebroso excluido, altura ignorada, secreto revelado antes de
tiempo, centro incorrecto, reposicionamiento repetido, uniforme sin aplicar
al dibujo y pérdida del filtro de bioma. Se restauran los fuentes y el control
gráfico positivo vuelve a pasar.

También pasan las regresiones de aventura, relevo solar y lunar, guardado,
combate cooperativo y puertas compartidas. Las dos últimas utilizan procesos
ENet reales: anfitrión e invitado, más un tercer jugador tardío para las puertas.

Las 96 capturas comparan 24 vistas de anochecer, noche y amanecer en valle,
Tenebroso y claro, con controles originales y la variante nueva. Los actores y shaders se
congelan, mientras Terrain3D y el descarte de vegetación siguen actualizando
la vista. Se invalida una primera serie que congelaba también esos gestores.

En la noche completa del valle, la diferencia nueva máxima por canal es un
nivel sobre 255 en las capturas revisadas, dentro de la variación de los
controles. El crepúsculo cambia deliberadamente el brillo de los puntos de luz.

Las mediciones, registros, capturas y fuentes de las sondas retiradas quedan
en `generated/reviews/2026-11-11/luciernagas/`, fuera del paquete del juego.

## Alcance del cooperativo

Los enjambres ambientales se dibujan alrededor del héroe local y dependen de
la luz del mundo compartida por el anfitrión. Son efectos visuales, sin
recompensas ni objetos que recoger. Las puertas continúan usando la apertura
fiable de 0.1.17. El recorrido del ciervo y los recuerdos mantienen su estado
actual; compartir todo su progreso narrativo sigue pendiente.
