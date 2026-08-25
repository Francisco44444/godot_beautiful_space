# Compilaciones automáticas

GitHub Actions exporta el juego con Godot 4.7.1 y su plantilla oficial de
Windows. El ordenador del desarrollador no genera ni sube los ZIP.

## Dos canales

- Cada cambio enviado a `main` crea un ejecutable de prueba en la pestaña
  **Actions**. Se conserva 14 días y no modifica a los jugadores instalados.
- Cada etiqueta `vX.Y.Z` crea una GitHub Release, adjunta el juego,
  `version.json` y el instalador, y la marca como última. Los lanzadores la
  detectan automáticamente.

## Uso desde macOS

Después de guardar cambios manuales en Godot, haz doble clic en
`PublicarCambios.command`:

1. **Prueba**: confirma los archivos, crea el commit y genera un ZIP temporal.
2. **Actualización oficial**: propone el siguiente número, actualiza las
   versiones internas, crea el commit y la etiqueta, y publica la release.

El script muestra todos los archivos que va a incluir y exige escribir
`PUBLICAR`. No guarda contraseñas ni tokens; utiliza la autenticación normal de
Git/GitHub configurada en el Mac.

También puede ejecutarse desde Terminal:

```bash
./tools/publicar_cambios.sh prueba - "ajuste de vegetación"
./tools/publicar_cambios.sh release 0.1.2 "nueva zona del bosque"
```

## Qué hace el workflow

1. Descarga el código.
2. Descarga Godot 4.7.1 y sus plantillas desde `godotengine/godot`.
3. Importa los recursos y ejecuta pruebas básicas.
4. Exporta Windows x86-64.
5. Crea el ZIP, el manifiesto SHA-256 y el instalador.
6. Guarda un artifact o publica la actualización, según el disparador.

El NAS no interviene en la compilación. Continúa sirviendo únicamente el
directorio de partidas activas.
