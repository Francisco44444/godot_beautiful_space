"""Relay de RPC opacas: ocho jugadores, anfitrión con ID 1 y salas efímeras."""
import asyncio
import json
import secrets
import struct
import time
from collections import deque
from dataclasses import dataclass, field
from aiohttp import web, WSMsgType

CABECERA = struct.Struct('<iBBBB')
MAX_PAQUETE = 65536 + CABECERA.size
MAX_COLA = 2 * 1024 * 1024
ALFABETO = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

@dataclass
class Conexion:
    ws: web.WebSocketResponse
    cola: deque = field(default_factory=deque)
    aviso: asyncio.Event = field(default_factory=asyncio.Event)
    bytes_cola: int = 0

    def enviar(self, datos, fiable=True):
        peso = len(datos)
        if self.bytes_cola + peso > MAX_COLA:
            if not fiable: return
            # Un invitado lento nunca bloquea al resto ni pierde eventos fiables.
            asyncio.create_task(self.ws.close(code=1013, message=b'Conexion lenta'))
            return
        self.cola.append(datos)
        self.bytes_cola += peso
        self.aviso.set()

    async def escritor(self):
        while not self.ws.closed:
            await self.aviso.wait()
            self.aviso.clear()
            while self.cola and not self.ws.closed:
                datos = self.cola.popleft()
                self.bytes_cola -= len(datos)
                if isinstance(datos, str): await self.ws.send_str(datos)
                else: await self.ws.send_bytes(datos)

    def evento(self, **datos): self.enviar(json.dumps(datos, separators=(',', ':')))

@dataclass
class Sala:
    version: str
    miembros: dict = field(default_factory=dict)
    siguiente_id: int = 2


def crear_app():
    app = web.Application(client_max_size=MAX_PAQUETE)
    salas = {}

    async def salud(_request):
        return web.json_response({'ok': True, 'salas': len(salas), 'jugadores': sum(len(s.miembros) for s in salas.values())})

    async def conectar(request):
        # No se comparten cookies ni credenciales con los demás juegos del NAS.
        origen = request.headers.get('Origin', '')
        if origen and not (origen.startswith('http://127.0.0.1:') or origen.startswith('http://localhost:') or origen == 'https://franfuco4444.synology.me:24573'):
            raise web.HTTPForbidden()
        ws = web.WebSocketResponse(heartbeat=20, max_msg_size=MAX_PAQUETE, compress=False)
        await ws.prepare(request)
        crear = request.query.get('accion') == 'crear'
        codigo = request.query.get('sala', '').upper()
        version = request.query.get('version', '')[:32]
        sala = salas.get(codigo)
        error = ''
        if crear:
            if len(salas) >= 64: error = 'El NAS está lleno; inténtalo más tarde'
            else:
                while True:
                    codigo = ''.join(secrets.choice(ALFABETO) for _ in range(6))
                    if codigo not in salas: break
                sala = Sala(version)
                salas[codigo] = sala
        elif sala is None: error = 'Esa sala no existe o ya se ha cerrado'
        elif sala.version != version: error = 'Actualizad el juego a la misma versión'
        elif len(sala.miembros) >= 8: error = 'La sala ya tiene ocho jugadores'
        if error:
            await ws.send_json({'tipo':'error', 'mensaje':error})
            await ws.close()
            return ws
        identidad = 1 if crear else sala.siguiente_id
        if not crear: sala.siguiente_id += 1
        cliente = Conexion(ws)
        sala.miembros[identidad] = cliente
        cliente.evento(tipo='bienvenida', id=identidad, sala=codigo)
        if not crear: sala.miembros[1].evento(tipo='entra', id=identidad)
        escritor = asyncio.create_task(cliente.escritor())
        saldo, ultimo = 4 * 1024 * 1024, time.monotonic()
        try:
            async for mensaje in ws:
                if mensaje.type == WSMsgType.BINARY:
                    datos = mensaje.data
                    ahora = time.monotonic()
                    saldo = min(4 * 1024 * 1024, saldo + (ahora - ultimo) * 2 * 1024 * 1024) - len(datos)
                    ultimo = ahora
                    if saldo < 0 or not CABECERA.size < len(datos) <= MAX_PAQUETE:
                        await ws.close(code=1008)
                        break
                    destino, canal, modo, _, _ = CABECERA.unpack_from(datos)
                    if modo > 2 or (identidad != 1 and destino != 1):
                        await ws.close(code=1008)
                        break
                    # El origen procede del socket, jamás de un ID del cliente.
                    reenvio = CABECERA.pack(identidad, canal, modo, 0, 0) + datos[CABECERA.size:]
                    for numero, invitado in tuple(sala.miembros.items()):
                        if numero == identidad: continue
                        if destino > 0 and numero != destino: continue
                        if destino < 0 and numero == -destino: continue
                        invitado.enviar(reenvio, fiable=modo == 2)
                elif mensaje.type == WSMsgType.TEXT and identidad == 1:
                    try: orden = json.loads(mensaje.data)
                    except (ValueError, TypeError): continue
                    if orden.get('tipo') == 'expulsar':
                        expulsado = sala.miembros.get(orden.get('id'))
                        if expulsado and expulsado is not cliente: await expulsado.ws.close(code=1008)
        finally:
            escritor.cancel()
            await asyncio.gather(escritor, return_exceptions=True)
            sala.miembros.pop(identidad, None)
            if identidad == 1:
                salas.pop(codigo, None)
                await asyncio.gather(*(c.ws.close(code=1001, message=b'El anfitrion salio') for c in tuple(sala.miembros.values())))
            elif 1 in sala.miembros:
                sala.miembros[1].evento(tipo='sale', id=identidad)
        return ws

    async def cerrar(_app):
        conexiones = [c.ws.close(code=1001) for s in tuple(salas.values()) for c in tuple(s.miembros.values())]
        if conexiones: await asyncio.gather(*conexiones)

    app.router.add_get('/senderos/coop/healthz', salud)
    app.router.add_get('/senderos/coop/ws', conectar)
    app.on_shutdown.append(cerrar)
    return app

if __name__ == '__main__':
    web.run_app(crear_app(), host='0.0.0.0', port=8080)
