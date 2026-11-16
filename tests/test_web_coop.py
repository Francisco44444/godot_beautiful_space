#!/usr/bin/env python3
"""Prueba el relay real y dos procesos Godot con RPC del juego."""
import argparse
import asyncio
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))
from aiohttp import web, ClientSession, WSMsgType
from server.senderos_web.relay import crear_app, CABECERA, Conexion, MAX_COLA

async def limites(url):
    async with ClientSession() as http:
        host = await http.ws_connect(url+'?accion=crear&version=prueba')
        bienvenida = await host.receive_json()
        sala = bienvenida['sala']
        assert bienvenida['id'] == 1
        clientes=[]
        try:
            malo = await http.ws_connect(url+f'?accion=unir&sala={sala}&version=otra')
            assert (await malo.receive_json())['tipo'] == 'error', 'Se mezclan versiones incompatibles'
            await malo.close()
            for indice in range(7):
                cliente=await http.ws_connect(url+f'?accion=unir&sala={sala}&version=prueba')
                assert (await cliente.receive_json())['id'] == indice+2
                assert (await host.receive_json())['tipo'] == 'entra'
                clientes.append(cliente)
            lleno=await http.ws_connect(url+f'?accion=unir&sala={sala}&version=prueba')
            assert (await lleno.receive_json())['tipo'] == 'error', 'La sala supera ocho jugadores'
            await lleno.close()
            await clientes[0].send_bytes(CABECERA.pack(1,4,2,0,0)+b'prueba')
            recibida=await host.receive_bytes()
            assert CABECERA.unpack_from(recibida)[:3] == (2,4,2), 'El relay pierde el origen o el canal'
            assert recibida[8:] == b'prueba'
            # Un invitado nunca puede hacerse pasar por el servidor ante otro.
            await clientes[0].send_bytes(CABECERA.pack(3,0,2,0,0)+b'suplantar')
            respuesta=await clientes[0].receive()
            assert respuesta.type == WSMsgType.CLOSE, 'Se permite enviar RPC entre invitados sin autoridad'
            assert (await host.receive_json())['tipo'] == 'sale'
            await host.close()
            for cliente in clientes[1:]:
                assert (await cliente.receive()).type == WSMsgType.CLOSE, 'Queda una sala huérfana sin anfitrión'
        finally:
            await host.close()
            for cliente in clientes: await cliente.close()

async def ejecutar(godot, url=None):
    runner=None
    if url is None:
        runner=web.AppRunner(crear_app());await runner.setup()
        with socket.socket() as s:s.bind(('127.0.0.1',0)); puerto=s.getsockname()[1]
        await web.TCPSite(runner,'127.0.0.1',puerto).start()
        url=f'ws://127.0.0.1:{puerto}/senderos/coop/ws'
    try:
        await asyncio.wait_for(limites(url),15)
        with tempfile.TemporaryDirectory(prefix='senderos-web-') as carpeta:
            archivo=Path(carpeta)/'sala.txt'
            base=[godot,'--headless','--path',str(RAIZ),'--script','res://tests/web_coop_test.gd','--','--url='+url,'--archivo='+str(archivo)]
            host=await asyncio.create_subprocess_exec(*base,'--host',stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
            cliente=None
            try:
                inicio=time.monotonic()
                while not archivo.exists() and host.returncode is None and time.monotonic()-inicio<15: await asyncio.sleep(.1)
                if not archivo.exists():
                    host.terminate();salida=(await host.communicate())[0].decode();raise AssertionError(salida)
                cliente=await asyncio.create_subprocess_exec(*base,'--sala='+archivo.read_text(),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
                h,c=await asyncio.wait_for(asyncio.gather(host.communicate(),cliente.communicate()),30)
                texto=h[0].decode()+c[0].decode()
                assert host.returncode==cliente.returncode==0 and 'WEB_COOP_HOST_OK' in texto and 'WEB_COOP_CLIENT_OK' in texto, texto
                assert 'SCRIPT ERROR' not in texto, texto
                print(texto)
            finally:
                for proceso in [host,cliente]:
                    if proceso and proceso.returncode is None:proceso.terminate();await proceso.wait()
    finally:
        if runner:await runner.cleanup()
    print('WEB COOP OK: 8 plazas, autoridad, versiones, desconexión y RPC de dos procesos reales.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--godot',default=str(RAIZ/'tools/runtime/Godot.app/Contents/MacOS/Godot'))
    parser.add_argument("--url")
    args=parser.parse_args();asyncio.run(ejecutar(args.godot,args.url))
