# Decisiones técnicas

Datos comprobados el 31/10/2026 contra los índices de paquetes de Debian, la API de GitHub y los propios paquetes.

## Arquitectura: solo x86_64

Es la decisión que condiciona todo, y la impone un componente obligatorio:

| Componente | i386 en Linux | x86_64 |
|---|---|---|
| RustDesk 1.5.0 | **No** (la release trae x86_64, aarch64 y armv7) | Sí |
| Electron 45 (LauncherPC) | **No** (retirado hace años) | Sí |
| Debian 13 | Sin kernel ni instalador i386 | Sí |

Con 32 bits habría que renunciar a RustDesk actual y a LauncherPC, así que no es viable. **Limitación:** los equipos sin soporte de 64 bits, en general anteriores a 2006–2008, quedan fuera.

## Base: Debian 13 mínimo

| Alternativa | Conclusión |
|---|---|
| **Debian 13 mínimo** | **Elegida.** Soporte de seguridad hasta 2028 y LTS hasta 2030, `live-build` oficial, todos los paquetes disponibles y dependencias de RustDesk resueltas. Se instala sin `Recommends`. |
| antiX | Muy liviana, pero sin systemd, y el postinst de RustDesk solo instala su servicio con systemd. Su ISO se remasteriza con herramientas propias, menos automatizables. |
| Devuan | Mismo problema de RustDesk sin systemd y ninguna ventaja real frente a Debian mínimo. |
| Debian 12 | Ya salió del soporte regular (julio de 2026). |

La diferencia de RAM entre systemd y sysvinit es pequeña frente a la estabilidad de usar lo que RustDesk espera.

## Escritorio: IceWM, sin gestor de pantalla

IceWM reúne ventanas, barra, menú, bandeja, reloj y apagado en un único programa. Openbox necesitaría además panel y menú, y LXDE suma más procesos. El menú se genera solo con `icewm-menu-fdo`. Se entra con `agetty --autologin` + `startx`, sin LightDM.

## Red: NetworkManager + nm-applet

Ethernet por DHCP y reconexión automática sin intervención. Wi-Fi desde el icono de la bandeja. Una regla de polkit permite al usuario activo guardar redes sin llavero ni contraseña, porque sin ella la clave no quedaría guardada y no reconectaría. Se incluye firmware de Wi-Fi de Intel, Atheros, Broadcom, Realtek, MediaTek y otros.

## RustDesk 1.5.0

Última estable, publicada el 30/09/2026. Se descarga de la release oficial y se comprueba el SHA-256. Se usa el paquete normal, no el `sciter` (obsoleto) ni el `unattended-wayland`: el sistema usa X11.

**Riesgo detectado y resuelto:** su `postinst` mira `/proc/1/exe` para decidir si instala el servicio. En un chroot eso refleja el sistema que compila, y en WSL el servicio no se instalaría y el acceso remoto entrante no funcionaría. El hook `0200-lpc-rustdesk` lo instala siempre.

**Costo:** el servicio queda residente como root. Es necesario para recibir conexiones.

## Instalador de `.deb`: gdebi

Herramienta existente: muestra nombre, versión y descripción, resuelve dependencias con apt e informa errores. Solo consume memoria mientras está abierta. `lpc-deb` agrega dos cosas: arranca el agente de contraseñas y, como la ISO no trae índices de apt, los actualiza antes de abrir un paquete. Por eso **resolver dependencias faltantes requiere Internet**.

## Explorador: PCManFM

Cumple todo lo pedido. ROX-Filer gasta algo menos pero no monta USB con la misma facilidad. Se usan `gvfs` y `udisks2` sin `gvfs-backends`: papelera y USB sí, red no.

## Navegador: Firefox ESR

| Opción | Conclusión |
|---|---|
| **Firefox ESR 153** | **Elegido.** Con actualizaciones de seguridad de Debian, compatible con la web actual y configurable para gastar menos. |
| Chromium 156 | También tiene soporte, pero tiende a usar más RAM por pestaña y agregaría una segunda copia del motor que ya trae Electron. |
| Falkon | Interfaz liviana, pero QtWebEngine arrastra versiones de seguridad atrasadas y sumaría Qt entero. |
| NetSurf, Dillo, Links | Muy livianos, pero no abren bien la web actual. |

Se ajusta en `/etc/firefox-esr/lpc.js`: 2 procesos de contenido, descarga de pestañas con poca memoria, sin telemetría.

## Optimización

| Medida | Motivo |
|---|---|
| Sin `Recommends` ni documentación | Menos paquetes y espacio |
| zram con lz4, hasta el tamaño de la RAM y 4 GB como máximo | Más memoria útil con poco gasto de CPU |
| `apt-daily`, `man-db`, `e2scrub` y `wait-online` apagados | Sin tareas de fondo y arranque más rápido. **Costo:** las actualizaciones son manuales |
| journald en RAM, tope de 16 MB | Menos escritura |
| 2 consolas virtuales | Menos procesos |
| PipeWire por socket | Sin consumo hasta que algo reproduce |
| Agente de contraseñas bajo demanda | Sin residente |
| LauncherPC no arranca solo | Electron gasta unos cientos de MB; se activa en Ajustes si se quiere |
| Con menos de 3 GB, fondo animado apagado de inicio | Menos GPU y RAM en el primer arranque |

**Se mantienen:** udev, dbus, logind, journald, NetworkManager, timesyncd (sin hora correcta falla HTTPS), RustDesk y el kernel estándar de Debian, por compatibilidad con hardware antiguo.

**Paquetes no deseados:** `x11-xserver-utils` trae `cpp` como dependencia. Es parte de la cadena de `xrdb`, no se usa para desarrollar, y se dejó para no romper dependencias del escritorio.

## Instalador: debian-installer

`live-build` lo integra en modo `live`: copia el sistema de la ISO al disco y elimina los paquetes exclusivos del Live, con interfaz gráfica GTK. Calamares habría sumado Qt y una configuración propia que no se pudo probar. El instalador se abre desde el **menú de arranque**, no desde el escritorio Live.

## Steam

No va en la ISO: necesita bibliotecas de 32 bits y más de 1 GB. Menú > Sistema > Instalar Steam habilita i386 e instala `steam-installer` de Debian.
