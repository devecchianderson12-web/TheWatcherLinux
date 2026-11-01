# Registro de pruebas

Versión 0.1.0, 01/11/2026. La ISO se compiló con `build.sh` en WSL2 con Debian 13 y se probó con `tests/boot-test.py` en QEMU/KVM (2 GB de RAM, 2 CPU, e1000, pantalla virtual sin GPU real). **No se probó en hardware físico.**

## Pruebas exigidas

| # | Prueba | Resultado | Detalle |
|---|---|---|---|
| 1 | La ISO arranca | **Correcto en VM** | Menú de arranque visto en BIOS y UEFI (OVMF). Sistema completo arrancado en 9,7 s |
| 2 | Entorno gráfico | **Correcto en VM** | IceWM, barra, accesos y bandeja |
| 3 | Ethernet | **Correcto en VM** | DHCP automático, HTTPS 200 |
| 4 | Wi-Fi | **No probado** | La VM no tiene Wi-Fi |
| 5 | RustDesk abre | **Correcto en VM** | Muestra ID y contraseña, estado "Listo", sesión x11 aceptada |
| 6 | RustDesk conecta | **No probado** | Hace falta una conexión real entre dos equipos |
| 7 | Instalar `.deb` | **Parcial** | `gdebi -n` instaló un paquete y su dependencia faltante. La ventana gráfica no se probó |
| 8 | Explorador | **Parcial** | PCManFM abre en español; copiar y mover no se probaron a mano |
| 9 | Navegador | **Correcto en VM** | Firefox ESR abrió www.debian.org por HTTPS |
| 10 | LauncherPC | **Parcial** | Abre con su interfaz, detecta primer plano con `xprop` y guarda configuración. No se probaron mando, Steam ni juegos. **Falla conocida:** la barra de IceWM queda encima |
| 11 | USB | **Correcto en VM** | Pendrive virtual montado solo en `/media/usuario` |
| 12 | Apagar y reiniciar | **No probado** | Desde el menú de IceWM |
| 13 | Consumo reducido | **Correcto en VM** | Ver [CONSUMO.md](CONSUMO.md) |
| — | Instalar en disco | **No probado** | Es lo primero que conviene probar en una VM |

`systemctl --failed` no mostró servicios con error.

## Fallos encontrados en la compilación y en las pruebas

| Fallo | Causa | Solución |
|---|---|---|
| `firmware-ipw2x00` frena la compilación | Exige aceptar una licencia de forma interactiva | Quitado: es Wi-Fi de portátiles Pentium M, de 32 bits, que este sistema no admite |
| RustDesk no entra en la ISO | live-build solo toma archivos `*_amd64.deb` | Se copia como `rustdesk_<versión>_amd64.deb` |
| `loadlin` frena la compilación | Busca documentación que el sistema excluye | `--loadlin false` |
| RustDesk: "Unsupported display server tty" | Con `startx`, logind ve una sesión tty y RustDesk no acepta conexiones | LightDM con inicio automático |
| Iconos vacíos en la barra | Nombres que IceWM no encuentra | Ruta directa e icono propio |

## Comprobaciones previas

Versiones y SHA-256 de RustDesk y Electron, paquetes contra Debian 13, 13 pruebas de lógica de `linux.js`, y LauncherPC modificado cargando en Windows con Electron 45.2.1.

## Pendiente de verificar

- Instalador en disco y sistema instalado, incluido el inicio automático.
- Wi-Fi y conexión real de RustDesk.
- Hardware físico antiguo y GPU reales: la VM no prueba aceleración.
- LauncherPC con mando, Steam y Heroic. El formato `heroic://launch` viene de una fuente secundaria.
- `build-iso.yml` en GitHub.
