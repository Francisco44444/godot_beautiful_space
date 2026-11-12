#!/usr/bin/env python3
"""Recorre seis ventanas con anfitrión e invitado reales, en ambos sentidos."""
from pathlib import Path
import argparse
import subprocess
import tempfile
import time
from test_network_handshake import available_udp_port, find_godot

RAIZ = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot')
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    godot = find_godot(args.godot)
    puerto = available_udp_port()
    carpeta = Path(tempfile.mkdtemp(prefix='senderos-menus-'))
    procesos = []
    try:
        for modo in ['host', 'client']:
            orden = [str(godot)] + ([] if modo == 'client' and args.capture else ['--headless'])
            orden += ['--path', str(RAIZ), '--log-file', str(carpeta/(modo+'-engine.log')),
                      '--script', 'res://tests/cooperative_ui_test.gd', '--', '--'+modo, f'--port={puerto}']
            if modo == 'client' and args.capture:
                orden += ['--capture']
            with (carpeta/(modo+'.txt')).open('w') as registro:
                procesos.append(subprocess.Popen(orden, cwd=RAIZ, stdout=registro, stderr=subprocess.STDOUT))
            if modo == 'host':
                limite = time.monotonic()+45
                while time.monotonic()<limite:
                    texto = (carpeta/'host.txt').read_text()
                    if 'UI HOST READY' in texto:
                        break
                    if procesos[0].poll() is not None or 'SCRIPT ERROR' in texto:
                        raise RuntimeError('No arrancó el anfitrión.')
                    time.sleep(.1)
                else:
                    raise RuntimeError('Tiempo agotado arrancando el anfitrión.')
        procesos[1].wait(timeout=100)
        if procesos[1].returncode != 0:
            raise RuntimeError('El invitado terminó con un fallo.')
        procesos[0].wait(timeout=8)
        for modo, proceso in zip(['host', 'client'], procesos):
            texto = (carpeta/(modo+'.txt')).read_text()
            assert proceso.returncode == 0 and 'SCRIPT ERROR' not in texto and 'above the MTU' not in texto
            assert ('UI HOST PASS' if modo == 'host' else 'UI CLIENT PASS') in texto
        cliente = (carpeta/'client.txt').read_text()
        assert cliente.count('COOPERATIVE UI WINDOW PASS') == 6
        assert cliente.count('COOPERATIVE UI CANCEL PASS') == 3
        print('COOPERATIVE UI PASS: seis ventanas, simulación y movimiento real con menús en ambos jugadores.')
        return 0
    except (RuntimeError, AssertionError, subprocess.TimeoutExpired) as error:
        print('Fallo de interfaz cooperativa:', error)
        for modo in ['host', 'client']:
            p = carpeta/(modo+'.txt')
            if p.exists():
                print(modo, '\n'.join(x for x in p.read_text().splitlines() if 'UI ' in x or 'ERROR:' in x))
        return 1
    finally:
        for proceso in procesos:
            if proceso.poll() is None:
                proceso.terminate()
                try:
                    proceso.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proceso.kill()
                    proceso.wait()
        print('Registros:', carpeta)

if __name__ == '__main__':
    raise SystemExit(main())
