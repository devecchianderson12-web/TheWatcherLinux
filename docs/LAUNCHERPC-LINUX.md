# Adaptación de LauncherPC a Linux

La adaptación se hizo en el mismo código: Windows sigue usando sus caminos y Linux entra por `process.platform === 'linux'`. Lo específico está en `linux.js`, un módulo sin Electron que se puede probar solo. Se empaqueta con Electron 45.2.1, sin instalar Node.js.

| Función en Windows | En Linux | Estado |
|---|---|---|
| Interfaz, diseños, fondos, portadas, explorador propio | Sin cambios | Conservado |
| Teclado y mando en la interfaz | Gamepad API de Chromium | Conservado |
| Registro para encontrar Steam | Carpetas nativa, Debian, Flatpak y Snap | Adaptado |
| Steam | `steam://rungameid/` con `xdg-open` | Adaptado |
| Epic Games | Epic no tiene cliente para Linux: lee `installed.json` de **Heroic** o legendary y abre con `heroic://launch` | Adaptado; Heroic no viene incluido |
| Detección de aplicaciones | Nuevo: archivos `.desktop` con categoría `Game`, también Flatpak y Snap | Agregado |
| `.exe` y carpetas de juegos | AppImage, `.x86_64`, `.x86`, `.sh`, `.bin`, `.desktop` y binarios ELF | Adaptado |
| `.lnk`, `.url`, `.bat` | `.desktop` | Adaptado |
| Ayudante PowerShell, primer plano | `xprop -spy _NET_ACTIVE_WINDOW`: por eventos, sin sondeo | Adaptado |
| Pausa con otro programa delante | Igual, con el ayudante de arriba | Conservado |
| Combinación L1+R1+L2+R2 (XInput/winmm) | Lectura de `/dev/input/js*`, con detección de mandos por inotify | Adaptado |
| Atajo Ctrl+Alt+P | `globalShortcut` en X11 | Conservado |
| Ocultar barra de tareas | La opción se oculta. **Falla conocida en 0.1.0:** la barra de IceWM queda sobre el launcher | Pendiente |
| Forzar primer plano (`AttachThreadInput`) | `win.focus()`, IceWM no lo bloquea | Sustituido |
| Iniciar con Windows | `~/.config/autostart/ps-launcher.desktop` | Adaptado |
| CPU y RAM | Sin cambios | Conservado |
| GPU NVIDIA | `nvidia-smi` | Conservado |
| LibreHardwareMonitor | `sysfs` (uso y temperatura en AMD) | Adaptado |
| Actualizador `.exe` | Baja `ps-launcher_*_amd64.deb` de la release y lo abre el instalador del sistema | Adaptado, ver abajo |
| Nombre de producto del `.exe` | No aplica: se usan nombre de archivo y carpeta | Sin equivalente |
| Icono del `.exe` | Icono del `.desktop` o del tipo de archivo | Adaptado |
| `in-process-gpu` | Solo en Windows: era por un límite del driver | Quitado en Linux |

## Sin equivalente

- **Juegos de Windows (`.exe`):** el launcher no los ejecuta en Linux. Steam Proton y Heroic pueden hacerlo si el usuario los configura.
- **Wayland:** el ayudante usa X11, que es lo que trae la distribución. El lanzador fuerza `--ozone-platform=x11`.

## Actualizaciones

Para que Linux detecte una versión nueva, la release de GitHub tiene que incluir `ps-launcher_<versión>_amd64.deb`, que `build.sh` deja en `out/`. El workflow actual solo publica el `.exe`. Mientras eso no cambie, Linux muestra que no hay actualizaciones y el launcher se actualiza reconstruyendo la ISO o instalando el `.deb` a mano.

## Datos del usuario

`~/.config/PS Launcher/`: `config.json`, `library.json`, `covers/`, `bgvideo/`.

## Clave de SteamGridDB

No se incluye. Para compilar con clave propia, definí `SGDB_KEY` antes de `build.sh`. Sin ella, el launcher usa portadas de Steam y la clave de Ajustes.
