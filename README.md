# TheWatcher Linux

Sistema liviano de 64 bits basado en **antiX 26.1 Full** (Debian 13, sin systemd), con The Watcher y RustDesk instalados y sin el software que no hace falta. La ISO está en [Releases](../../releases).

## Qué trae

| Función | Aplicación |
|---|---|
| Cámaras | The Watcher 1.1.6 |
| Acceso remoto | RustDesk 1.5.0 |
| Navegador | Firefox ESR |
| Archivos | zzzFM |
| Instalador de `.deb` | deb-installer, de antiX |
| Red | ConnMan con su icono (cmst) |
| Escritorio | IceWM, con accesos en la barra |
| Instalador en disco | Instalador gráfico de antiX |

Se conservan los dos kernels de antiX: 5.10 para equipos antiguos y 6.6 para los más nuevos, seleccionables en el menú de arranque.

## Qué se quitó

LibreOffice, GIMP, programas de correo, chat, torrents, multimedia y escáner, impresión, compiladores completos de C++, cabeceras del kernel, firmware de servidores y otros escritorios. La lista exacta está en [config/purge.list](config/purge.list).

## Uso

- **Modo Live:** arranca solo con el usuario `demo`, contraseña `demo`. La contraseña de root es `root`.
- **Instalar en disco:** menú de aplicaciones > Sistema > instalador de antiX.
- **Wi-Fi:** icono de red junto al reloj.

## Requisitos

Procesador de 64 bits. No funciona en 32 bits porque RustDesk y The Watcher solo existen para 64 bits.

## Compilar

Necesita Debian 13 o WSL2, 20 GB libres, Internet y la ISO original `antiX 26.1 Full` de 64 bits, que se comprueba por SHA-256.

```bash
sudo bash build.sh "/ruta/Antix 26.1 Full.iso"
```

La ISO queda en `out/`.

## Decisiones

- **Base antiX:** reemplaza a la base anterior de Debian con live-build. Trae su propio soporte de hardware y herramientas probadas.
- **RustDesk sin systemd:** antiX bloquea `libsystemd0`, y RustDesk la declara aunque sus binarios no la usan. Se reempaqueta sin esa dependencia y su servicio se agrega para runit y sysvinit. Otros sistemas de inicio del menú, como s6 o dinit, no lo arrancan solo.
- **Wi-Fi Broadcom:** se conserva el módulo `wl` ya compilado para los dos kernels, sin dejar DKMS instalado.
- **Red:** se mantiene ConnMan, el sistema de antiX, en lugar de NetworkManager.
- **Actualizaciones:** las automáticas de antiX siguen como vienen.

## Pruebas

Versión 0.1.3 en QEMU/KVM con 2 GB de RAM. **No se probó en hardware físico.**

| Prueba | Resultado |
|---|---|
| Arranque BIOS hasta el escritorio | Correcto |
| Menú de arranque UEFI | Correcto |
| Ethernet y HTTPS | Correcto |
| RustDesk abre con ID y contraseña, servicio activo con runit | Correcto |
| The Watcher abre | Correcto, sin cámaras reales |
| Wi-Fi | **No probado** |
| Conexión real de RustDesk | **No probado** |
| Instalador en disco | **No probado** |
| Instalar un `.deb` | **No probado** |
| USB, apagado y Firefox con páginas reales | **No probado** |

**Consumo en VM, medido antes de apagar Conky:** 349 MB de RAM usada con Conky encendido, 151 procesos. En esta versión Conky queda apagado.
