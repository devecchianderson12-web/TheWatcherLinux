# Registro de pruebas

Fecha: 31/10/2026. Equipo: Windows 11, sin WSL, Docker, QEMU ni VirtualBox. Instalar WSL requiere administrador y cambia la configuración del sistema, así que no se forzó: **la ISO no se compiló**.

## Pruebas exigidas sobre la ISO

Ninguna se pudo ejecutar. Completar después de compilar.

| # | Prueba | Estado | Cómo comprobarla |
|---|---|---|---|
| 1 | La ISO arranca (BIOS y UEFI) | **No probado** | VM |
| 2 | Entorno gráfico | **No probado** | Aparece IceWM |
| 3 | Ethernet | **No probado** | `lpc-diag` |
| 4 | Wi-Fi | **No probado** | Hardware real o adaptador USB; en una VM no suele poder probarse |
| 5 | RustDesk abre | **No probado** | Icono de la barra |
| 6 | RustDesk conecta | **No probado** | Conexión entre dos equipos, en ambos sentidos |
| 7 | Instalar `.deb` | **No probado** | Doble clic en un `.deb` con dependencias |
| 8 | Explorador | **No probado** | Copiar, mover, borrar, crear carpeta |
| 9 | Navegador | **No probado** | Abrir sitios actuales |
| 10 | LauncherPC en Linux | **No probado** | Abrir, escanear, mando, guardar ajustes, cerrar y volver a abrir |
| 11 | USB | **No probado** | Conectar un pendrive |
| 12 | Apagar y reiniciar | **No probado** | Menú > Salir o `Logout` |
| 13 | Consumo reducido | **No probado** | [CONSUMO.md](CONSUMO.md) |
| — | Instalar en disco | **No probado** | Instalador del menú de arranque, y reiniciar sin la ISO |

## Lo que sí se comprobó

| Comprobación | Resultado |
|---|---|
| RustDesk 1.5.0 es la última estable y su SHA-256 coincide con GitHub | Correcto |
| Electron 45.2.1: SHA-256 de Linux y de Windows coinciden con `SHASUMS256.txt` | Correcto |
| Todos los paquetes de las listas existen en Debian 13 para amd64 | Correcto |
| Dependencias de RustDesk (de su `control`) y de Electron (leídas del binario ELF) existen en Debian 13 | Correcto |
| Resolución de dependencias simplificada de todo el sistema | Unos 670 paquetes, sin faltantes. No sustituye a apt |
| Todas las opciones de `lb config` existen en live-build de Debian 13 | Correcto, contra su código |
| Claves de `preferences` existen en IceWM 3.7.4 | Correcto |
| Carpetas de `live-build`, ruta de `lxpolkit` y de los monitores de `gvfs` | Correcto, contra los paquetes |
| `bash -n` de todos los scripts | Correcto |
| `node --check` de `main.js` y `linux.js` | Correcto |
| `node tests/linux.test.js`: 13 pruebas de lógica | Correctas |
| LauncherPC modificado en **Windows** con Electron 45.2.1, sin ventana visible | Carga la interfaz; sin errores en consola, solo el aviso de CSP de desarrollo |
| `build-deb.sh` con el Electron real, simulando `dpkg-deb` en Windows | Recorre todos los pasos. No se generó un `.deb` real |
| ZIP extraído y comparado archivo por archivo con el proyecto; pruebas repetidas desde el ZIP; sin CRLF ni datos privados | Correcto |

## No verificado y con riesgo

Es lo primero que conviene revisar si algo falla.

- **Código Linux de `main.js`:** no corrió nunca en Linux real. `linux.js` tiene pruebas, pero las partes que dependen de X11, `xprop`, `/dev/input` y Electron para Linux no.
- **Formato `heroic://launch`:** viene de una fuente secundaria y solo para otros runners; no se probó con Heroic.
- **`lb build` completo:** es el primer intento real. Un fallo en la primera compilación es posible.
- **Instalador en modo `live`:** no se probó.
- **`build-iso.yml`:** no se ejecutó en GitHub. Compila con Docker, y el espacio libre del runner puede variar. En Windows, `ci-build.sh` se probó hasta el aviso de que falta WSL.
- **WSL2:** `live-build` en WSL2 no está documentado de forma oficial; se tomaron precauciones (disco ext4, servicio de RustDesk).
- **Bandeja de LauncherPC en IceWM:** si no aparece, el launcher sigue funcionando y se cierra desde Ajustes.
- **Firefox ESR 153:** el ajuste `dom.ipc.processCount.webIsolated` limita procesos, pero no se midió el efecto.
