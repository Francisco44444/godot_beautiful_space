# Web de Senderos en el NAS

Dirección pública: **https://franfuco4444.synology.me:24573/senderos/**.
Utiliza el mismo servidor estático y puerto que la página de Vigo, dentro de
su propia carpeta. La referencia de Vigo se consultó por la dirección local
`http://192.168.0.25:24572/vigo/`, ya que el acceso público no vuelve a entrar
desde esta red.

`website/` contiene HTML, CSS, JavaScript y capturas reales del juego. No necesita
compilador ni dependencias externas. El instalador es la descarga principal;
también ofrece el ZIP completo, tamaño y SHA-256 a partir de `version.json`.
El lanzador conserva su canal de actualizaciones de GitHub Releases.

## Publicar una versión

Primero se crea la release con el script existente:

```bash
./tools/publicar_cambios.sh release 0.1.6 "Bosques, grutas y cooperativo"
```

Cuando termina GitHub Actions:

```bash
bash tools/publicar_web_nas.sh 0.1.6 --subir
```

El segundo script descarga los tres assets de la release, comprueba tamaño y
SHA-256 del juego y el contenido del instalador, prepara `dist/web/` y publica
mediante SSH. Sube los ZIP antes que el manifiesto y la página. Cada archivo
se verifica en el NAS antes del renombrado final. Conserva las versiones
anteriores y no modifica la carpeta de Vigo ni la de Duelo de Sables.

La página consulta su manifiesto con `cache: no-store`. La configuración actual
de nginx sirve la carpeta nueva directamente, por lo que no requiere añadir
puertos, cambiar el proxy ni reiniciar los contenedores.
