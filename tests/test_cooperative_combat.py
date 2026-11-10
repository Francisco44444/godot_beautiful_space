#!/usr/bin/env python3
"""Comprueba combate real de invitado/anfitrión en dos procesos Godot ENet."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess
import tempfile
import time
from test_network_handshake import find_godot, available_udp_port

ROOT = Path(__file__).resolve().parents[1]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot')
    parser.add_argument('--break-client-ward', action='store_true')
    parser.add_argument('--capture-resources', action='store_true')
    args = parser.parse_args()
    godot = find_godot(args.godot)
    port = available_udp_port()
    carpeta = Path(tempfile.mkdtemp(prefix='senderos-combate-'))
    base = [str(godot), '--headless', '--path', str(ROOT), '--script', 'res://tests/cooperative_combat_test.gd']
    anfitrion = None
    invitado = None
    with (carpeta/'host.txt').open('w') as host_log, (carpeta/'guest.txt').open('w') as guest_log:
        try:
            anfitrion = subprocess.Popen(base[:2]+['--log-file',str(carpeta/'host-engine.log')]+base[2:]+['--','--host',f'--port={port}'],cwd=ROOT,stdout=host_log,stderr=subprocess.STDOUT)
            limite = time.monotonic()+40
            while time.monotonic()<limite:
                contenido = (carpeta/'host.txt').read_text()
                if 'COOP COMBAT HOST READY' in contenido: break
                if anfitrion.poll() is not None or 'SCRIPT ERROR' in contenido: raise RuntimeError('No arranca el anfitrión.')
                time.sleep(.1)
            else: raise RuntimeError('Tiempo agotado preparando el anfitrión.')
            extra = ['--break-client-ward'] if args.break_client_ward else []
            cliente = base[:1]+(['--headless'] if not args.capture_resources else [])+['--log-file',str(carpeta/'guest-engine.log')]+base[2:]+['--','--client',f'--port={port}']+extra+(['--capture-resources'] if args.capture_resources else [])
            invitado = subprocess.Popen(cliente,cwd=ROOT,stdout=guest_log,stderr=subprocess.STDOUT)
            invitado.wait(timeout=80)
            if invitado.returncode: raise RuntimeError('Falló el invitado.')
            anfitrion.wait(timeout=8)
            host = (carpeta/'host.txt').read_text()
            guest = (carpeta/'guest.txt').read_text()
            if anfitrion.returncode or 'COOP COMBAT HOST PASS' not in host or 'COOP COMBAT CLIENT PASS' not in guest or 'SCRIPT ERROR' in host+guest: raise RuntimeError('Combate incompleto o errores de script.')
            if 'COOP RESOURCE HOST PASS' not in host or 'COOP RESOURCE CLIENT PASS' not in guest: raise RuntimeError('La tala con instantáneas periódicas y restauración no se verificó entre ambos procesos.')
            if 'COOP CAVE HOST PASS' not in host or 'COOP CAVE CLIENT PASS' not in guest: raise RuntimeError('No se verificaron los cuatro interiores con disparos cooperativos y desactivación al salir.')
            if 'above the MTU' in host+guest: raise RuntimeError('Un estado cooperativo vuelve a provocar fragmentación ENet.')
            print('COOPERATIVE COMBAT PASS: combate autoritativo y respuesta del invitado por ENet real.')
            print('Registros:',carpeta)
            return 0
        except (RuntimeError,subprocess.TimeoutExpired) as error:
            print(str(error))
            for nombre in ['host.txt','guest.txt']:
                texto=(carpeta/nombre).read_text()
                relevantes=[line for line in texto.splitlines() if 'COOP' in line or 'SCRIPT ERROR' in line or 'ERROR:' in line]
                print(nombre,'\n'+'\n'.join(relevantes[:24]),'\n'+texto[-2200:])
            print('Registros:',carpeta)
            return 1
        finally:
            for proceso in [invitado,anfitrion]:
                if proceso is not None and proceso.poll() is None:
                    proceso.terminate()
                    try: proceso.wait(timeout=3)
                    except subprocess.TimeoutExpired: proceso.kill(); proceso.wait()

if __name__=='__main__': raise SystemExit(main())
