#!/usr/bin/env python3
"""Comprueba cuatro puertas en dos mundos ENet y con un invitado tardío."""
from pathlib import Path
import subprocess
import tempfile
import time
from test_network_handshake import available_udp_port, find_godot

RAIZ = Path(__file__).resolve().parents[1]

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot')
    parser.add_argument('--capture',action='store_true')
    args = parser.parse_args()
    godot = find_godot(args.godot)
    puerto = available_udp_port()
    carpeta = Path(tempfile.mkdtemp(prefix='senderos-puertas-'))
    procesos = []
    try:
        for modo in ['host', 'client']:
            registro = (carpeta/(modo+'.txt')).open('w')
            orden = [str(godot)]+([] if modo=='client' and args.capture else ['--headless'])+['--path',str(RAIZ),'--log-file',str(carpeta/(modo+'-engine.log')),'--script','res://tests/cooperative_gate_test.gd','--','--'+modo,f'--port={puerto}']+(['--capture'] if modo=='client' and args.capture else [])
            proceso = subprocess.Popen(orden,cwd=RAIZ,stdout=registro,stderr=subprocess.STDOUT)
            procesos.append(proceso)
            if modo == 'host':
                limite = time.monotonic()+40
                while time.monotonic()<limite:
                    s=(carpeta/'host.txt').read_text()
                    if 'GATE HOST READY' in s: break
                    if proceso.poll() is not None or 'SCRIPT ERROR' in s: raise RuntimeError('No arrancó el anfitrión.')
                    time.sleep(.1)
                else: raise RuntimeError('Tiempo agotado iniciando el anfitrión.')
        procesos[-1].wait(timeout=90)
        cliente=(carpeta/'client.txt').read_text()
        assert procesos[-1].returncode==0 and 'GATE CLIENT PASS' in cliente and 'SCRIPT ERROR' not in cliente
        with (carpeta/'late.txt').open('w') as registro:
            tardio=subprocess.Popen([str(godot),'--headless','--path',str(RAIZ),'--log-file',str(carpeta/'late-engine.log'),'--script','res://tests/cooperative_gate_test.gd','--','--client','--late',f'--port={puerto}'],cwd=RAIZ,stdout=registro,stderr=subprocess.STDOUT)
            procesos.append(tardio)
            tardio.wait(timeout=50)
        assert tardio.returncode==0 and 'GATE LATE CLIENT PASS' in (carpeta/'late.txt').read_text()
        procesos[0].wait(timeout=6)
        for nombre in ['host','client','late']:
            texto=(carpeta/(nombre+'.txt')).read_text()
            assert 'SCRIPT ERROR' not in texto and 'above the MTU' not in texto
        assert procesos[0].returncode==0 and 'GATE HOST PASS' in (carpeta/'host.txt').read_text()
        print('COOPERATIVE GATE PASS')
        return 0
    except (RuntimeError,AssertionError,subprocess.TimeoutExpired) as error:
        print('Fallo de puerta cooperativa:',error)
        for modo in ['host','client','late']:
            f=carpeta/(modo+'.txt')
            if f.exists(): print(modo, '\n'.join(x for x in f.read_text().splitlines() if 'GATE' in x or 'ERROR:' in x))
        return 1
    finally:
        for proceso in procesos:
            if proceso.poll() is None:
                proceso.terminate()
                try: proceso.wait(timeout=3)
                except subprocess.TimeoutExpired: proceso.kill();proceso.wait()
        print('Registros:',carpeta)

if __name__=='__main__': raise SystemExit(main())
