# Combate de expedición — 8 de noviembre de 2026

Los invitados ya pueden herir a los enemigos que controla el anfitrión. Antes
su animación y su movimiento viajaban, pero sus golpes sólo se ejecutaban en
la copia cliente. Los monstruos y los jefes también eligen ahora entre todos
los héroes conectados y envían el daño al jugador al que están atacando.

## Golpes y representación

`combate_cooperativo.gd` enlaza las intenciones fiables del canal ENet 3 con
las funciones nativas de `Player`. El anfitrión ejecuta los mismos tajos,
ventanas de impacto, alcance, giro de dos impactos y barridos de flecha que
el modo individual. Las copias cliente representan el gesto y reciben el
estado de enemigos y jefes; no vuelven a descontarles vida ni coraza.

- Cada intención incluye secuencia, reloj del emisor, posición, orientación,
  velocidad, estado de suelo, ranura y objeto exacto. La espada dorada de un
  invitado conserva su aspecto y sus 10 puntos de daño, aunque el anfitrión
  lleve la espada inicial de 3.
- Se rechazan secuencias repetidas, cadencias incompatibles con la recuperación,
  objetos de otra categoría, valores no finitos y giros sin carga previa de
  la misma arma. Una flecha requiere dirección unitaria, fuerza válida y un
  origen cercano al cuerpo.
- Los golpes consultan la posición recibida, separada de la presentación
  interpolada. Una pared detiene el acero; otros personajes permiten que el
  barrido alcance varios enemigos.
- Tensado, flecha encajada, disparo, carga, giro, guardia y voltereta se
  representan en el compañero remoto. El escudo viaja de la espalda al brazo
  mediante la misma transición del héroe local.
- Una flecha disparada lejos del anfitrión comprueba también la altura de
  Terrain3D: allí puede no existir colisión física de suelo. Respeta los
  agujeros de las grutas y conserva el barrido físico contra muros y enemigos.
- En cooperativo los remates conservan encuadre, sacudida y superposición de
  cámara, con la simulación a velocidad normal. La cámara lenta local hacía
  que los relojes de combate de los dos procesos avanzasen a distinto ritmo.
  El modo individual conserva su ralentización.

El inventario, el vigor y la vida de cada héroe siguen siendo locales. Estas
validaciones corrigen las reglas del cooperativo; no constituyen un sistema
antitrampas competitivo ni una simulación completa del jugador en el servidor.

## CPU de sincronización

Cada enemigo registra su id al entrar en el mundo. Recibir un paquete ya no
reconstruye un diccionario y dos listas de grupos para buscar sus destinatarios.
Los enemigos quietos tampoco vuelven a escribir una transformación idéntica.
El estado incluye animación y, para los jefes, coraza, sello, fase y postura.

Medición headless en este Mac M2 Pro, Godot 4.7.1: mundo completo de **265
enemigos y jefes**, cuatro tandas alternadas de 800 aplicaciones del mismo
paquete. Los dos caminos llaman al mismo método actual de cada enemigo; se
aísla la búsqueda por id y no se avanza la física entre aplicaciones.

| Camino | Primera tanda | Segunda tanda | Media |
| --- | ---: | ---: | ---: |
| Reconstruir índice y recorrer grupos | 537,70 µs | 539,83 µs | 538,76 µs |
| Índice conservado | 480,47 µs | 490,63 µs | 485,55 µs |

Es un **9,9 % menos de CPU en esta operación**, unos 0,053 ms por paquete.
No es una medida de FPS del juego ni del tráfico de red. El render sigue
siendo el límite observado en las cámaras anteriores; el objetivo actual de
**100–120 FPS sigue pendiente**. No se han reducido hierba, resolución, sombras ni distancias.
Datos y capturas: `generated/reviews/2026-11-08/combate/`.

## Pruebas ejecutadas

```bash
python3 tests/test_cooperative_combat.py
```

Arranca dos procesos reales con el mundo completo y conexión ENet local. Una
plataforma de prueba a 800 m aísla la pelea de los enemigos ambientales; el
código de ataque, proyectil, réplicas, inventario y autoridad es el real.

El recorrido comprueba golpes en ambos sentidos; tajo frontal; giro alrededor
del héroe y dos impactos sobre coraza; pared interpuesta; tensado y flecha;
daño dirigido al invitado; guardia con escudo en el brazo; esquiva; arma propia
y su daño; muerte y recompensa sin duplicarla al repetir estados. También
rechaza repetición, cadencia falsa, categoría incorrecta, giro sin carga y NaN.
El barrido fuera del área física se comprueba con una loma y un agujero de
terreno sintéticos. El combo remoto caduca igual que el local para que una
pausa devuelva el siguiente golpe al primer tajo y a su duración correcta.

Se retiró temporalmente la guarda de autoridad de `RPGBoss.receive_tool_hit`:
el recorrido falló con «El invitado cambia una coraza sin autoridad». Después
de restaurarla volvió a pasar. La ausencia de registro de enemigos también
se comprueba en `multiplayer_test`, junto con la recepción de paquetes parciales.
Omitir temporalmente el alta en ese índice produjo el fallo previsto; omitir
la caducidad del combo también hizo fallar el recorrido de combate.

Pasan además `multiplayer_test`, `medieval_combat_test`, `weapon_system_test`,
`combat_impact_test`, `adventure_system_test`, `rpg_story_test` y
`hero_moves_test`. La nueva prueba ENet está incluida en el workflow de Windows.
Se revisaron capturas de las poses en el mundo, incluido el arco desde ambos
lados y de perfil.

## Siguiente trabajo

- [Estados comprimidos y bloques de hasta 1.000 bytes](RED_ESTADOS.md): resuelto
  el aviso de MTU de los vecinos. Continúan el interés espacial, la reducción
  de listas persistentes repetidas y las pruebas WAN con ocho participantes.
- Interpolar enemigos y fauna, actualmente actualizados por estados del mundo.
- Compartir campaña, decisiones, recompensas persistentes y enemigos ya
  retirados antes de una incorporación tardía. La prueba actual verifica la
  recompensa durante una sesión conectada, no el reingreso tras una muerte.
- Replicar monturas y equipo defensivo exacto; el daño recibido ya consulta
  el escudo y las mejoras del jugador local al que corresponde.
