# Publicar Senderos del Horizonte para Windows

El jugador recibe una sola vez `SenderosDelHorizonte-Instalador.zip`. Al ejecutar
`Instalar.bat`, se crea un acceso directo. Ese acceso siempre abre el lanzador,
consulta `version.json`, verifica tamano y SHA-256, instala la nueva version en
`%LOCALAPPDATA%\\SenderosDelHorizonte` y conserva la version anterior si algo falla.

El canal estable consulta siempre este asset de la última GitHub Release:

```text
https://github.com/Francisco44444/godot_beautiful_space/releases/latest/download/version.json
```

## Publicación automática

```bash
./tools/publicar_cambios.sh release 0.1.2 "descripción de los cambios"
```

También puede hacerse con doble clic en `PublicarCambios.command`. El script
confirma los archivos, actualiza las versiones internas, crea el commit y envía
la etiqueta. GitHub Actions descarga Godot 4.7.1, ejecuta las pruebas, exporta el
proyecto y publica los tres assets sin utilizar el Mac para compilar.

Cada ZIP del juego es inmutable y el `version.json` de esa misma release contiene
su tamaño, SHA-256 y URL definitiva. Nunca se publica un manifiesto que apunte a
un paquete cuyo hash aún no se haya comprobado.

Los cambios normales enviados a `main` también producen un ejecutable de prueba
en **GitHub → Actions**, conservado durante 14 días. Esa compilación no se publica
en Releases y, por tanto, no actualiza a los jugadores.

La generación local se conserva únicamente como procedimiento de emergencia:

```bash
./tools/build_windows_release.sh 0.1.1 \
  "https://github.com/Francisco44444/godot_beautiful_space/releases/download/v0.1.1/SenderosDelHorizonte-Windows-x86_64-0.1.1.zip"
```

Todos los lanzadores siguen la URL `releases/latest/download/version.json`, por
lo que no necesitan redistribuirse. Google Drive queda únicamente como copia de
respaldo. Consulta `docs/AUTOMATIC_BUILDS.md` para el flujo completo.

El repositorio y sus releases deben ser públicos para que el lanzador descargue
sin credenciales. El ejecutable Windows sin firma puede activar SmartScreen. Una
publicación para usuarios no técnicos debería firmarse con un certificado de
código.
