# LauncherPC Linux

Distribución Linux ultraligera basada en **Debian 13 (trixie) de 64 bits**, con escritorio IceWM, NetworkManager, RustDesk, Firefox ESR, PCManFM, instalador gráfico de `.deb` y LauncherPC adaptado a Linux.

> **Estado:** versión 0.1.0, compilada y probada en máquina virtual. Instalador en disco, Wi-Fi y conexión real de RustDesk siguen sin probar: ver [docs/PRUEBAS.md](docs/PRUEBAS.md). La ISO está en [Releases](../../releases).

## 1. Qué necesitás

| | |
|---|---|
| Sistema para compilar | **Debian 13** (recomendado), Ubuntu 22.04 o posterior, **Windows 10/11 con WSL2**, o cualquier Linux con Docker |
| Procesador | x86_64 |
| RAM | 4 GB o más (mínimo 2 GB) |
| Espacio libre | **20 GB** en un disco ext4 |
| Internet | Sí, se descargan unos 2 GB |
| Tiempo | De 20 minutos a varias horas, según el equipo y la conexión |

Equipo donde corre el sistema: procesador de **64 bits**, 2 GB de RAM como mínimo razonable (1 GB para escritorio y navegador con pocas pestañas), 8 GB de disco. **No funciona en procesadores de 32 bits**: RustDesk y Electron no publican versiones i386 para Linux ([docs/DECISIONES.md](docs/DECISIONES.md)).

## 2. Dependencias

`build.sh` las comprueba y las instala solo con `apt`: `live-build`, `debootstrap`, `xorriso`, `squashfs-tools`, `mtools`, `dosfstools`, `curl`, `ca-certificates`, `unzip`, `binutils` y `dpkg-dev`. No hace falta Node.js. Para instalarlas a mano:

```bash
sudo apt install --no-install-recommends live-build debootstrap xorriso squashfs-tools mtools dosfstools curl ca-certificates unzip binutils dpkg-dev
```

## 3. Preparar y compilar

### En Debian o Ubuntu

Extraé el ZIP **en un disco de Linux** y ejecutá:

```bash
unzip LauncherPC-Linux-0.1.0.zip
```

```bash
cd LauncherPC-Linux-0.1.0 && sudo bash build.sh
```

En Ubuntu y otros sistemas con `apt`, `build.sh` crea primero un Debian 13 mínimo dentro de `work/buildroot` y compila ahí.

### En Windows

1. En una PowerShell **de administrador**, una sola vez:

   ```powershell
   wsl --install -d Debian
   ```

2. Reiniciá si lo pide y abrí Debian una vez para crear tu usuario.
3. Extraé el ZIP en una carpeta y hacé doble clic en `build.bat`.

El script copia el proyecto al disco de Linux de WSL, porque un chroot no funciona sobre `C:`, y al terminar deja la ISO en la carpeta `out` de Windows.

### Con Docker

```bash
docker run --rm --privileged -v "$PWD":/src -w /src debian:trixie bash build.sh
```

### En GitHub, sin instalar nada

El workflow `build-iso.yml` compila la ISO en los servidores de GitHub, en cerca de una hora, y la publica en **Releases** con la versión siguiente: 0.1.0, 0.1.1, 0.1.2...

1. En este repositorio ya está. Con el ZIP, subí su contenido extraído a un repositorio propio, incluida la carpeta oculta `.github`.
2. Abrí **Actions > Build ISO LauncherPC Linux > Run workflow**.
3. Al terminar, descargá la ISO desde **Releases**.

### Con Localci

`build-iso.yml` también corre en Localci, pero en Windows compila con WSL2: hace falta instalar Debian en WSL una sola vez, como en la sección de Windows. Sin WSL el paso falla y muestra la instrucción. El resultado queda en `iso-out/`.

### Reconstruir

Para empezar de cero, conservando las descargas de `cache/`:

```bash
sudo bash build.sh --clean
```

## 4. Qué hace el script

1. Comprueba sistema, espacio y permisos. 2. Instala las herramientas faltantes. 3. Prepara el entorno. 4. Descarga RustDesk y Electron de sus sitios oficiales y comprueba el SHA-256. 5. Empaqueta LauncherPC en un `.deb`. 6. Configura `live-build`. 7. Integra aplicaciones y escritorio. 8. Construye la ISO. 9. Verifica que la ISO contenga el sistema, UEFI, el instalador y los paquetes obligatorios. 10. Muestra dónde quedó, o el error y la línea donde falló.

## 5. Dónde queda la ISO

| Archivo | Contenido |
|---|---|
| `out/lpc-linux-0.1.0-amd64.hybrid.iso` | La ISO |
| `out/*.sha256` | Suma de comprobación |
| `out/paquetes-instalados.txt` | Lista exacta de paquetes y versiones |
| `out/ps-launcher_*_amd64.deb` | LauncherPC para Linux |
| `out/build.log` | Registro completo |

## 6. Grabar en un pendrive

Esto **borra todo el pendrive**.

- **Windows:** [Rufus](https://rufus.ie) en modo **DD** o [balenaEtcher](https://etcher.balena.io).
- **Linux:** buscá el dispositivo con `lsblk` y reemplazá `/dev/sdX`:

```bash
sudo dd if=out/lpc-linux-0.1.0-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## 7. Probar en una máquina virtual

**VirtualBox:** nueva máquina Debian 64 bits, 2 GB de RAM, 2 CPU, 16 MB o más de video, disco de 16 GB, y la ISO como unidad óptica. Para probar UEFI: Sistema > Habilitar EFI.

**QEMU:**

```bash
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 -cdrom out/lpc-linux-0.1.0-amd64.hybrid.iso -vga virtio -nic user,model=virtio-net-pci
```

## 8. Usar el sistema

- **Modo Live:** es la primera opción del menú de arranque. Entra solo como `usuario`; la contraseña es `live`.
- **Instalar:** en el menú de arranque elegí **Start installer**.
- **Wi-Fi:** icono de red junto al reloj. **Ethernet:** se conecta sola.
- **Accesos:** LauncherPC, navegador, RustDesk y archivos están en la barra; el resto en el menú.
- **Instalar un `.deb`:** doble clic en el archivo, o Menú > Instalar paquete .deb.
- **Apagar y reiniciar:** Menú > Salir (según el idioma, `Logout`), que ofrece apagar y reiniciar.
- **Actualizar:** Menú > Sistema > Actualizar el sistema. Es manual: no hay tareas en segundo plano.
- **Medir:** Menú > Sistema > Diagnóstico guarda `~/lpc-diag.txt`.
- **Sin inicio automático:** el sistema instalado entra sin contraseña. Para pedirla, ejecutá:

```bash
sudo mkdir -p /etc/lpc && sudo touch /etc/lpc/no-autologin
```

## 9. Solución de problemas

| Problema | Solución |
|---|---|
| `Ejecutá el script como root` | Usá `sudo bash build.sh`. |
| `No compiles en un disco de Windows` o `no sirve para un chroot` | Mové el proyecto a un disco ext4, o usá `build.bat`. |
| `SHA-256 incorrecto` | Descarga dañada: borrá el archivo de `cache/` y repetí. Si persiste, ver [docs/ACTUALIZAR.md](docs/ACTUALIZAR.md). |
| `Failed to fetch` o `404` de apt | Mirror caído o paquete actualizado: repetí, o cambiá `DEBIAN_MIRROR` en `versions.env`. |
| `Falta el paquete obligatorio` | Buscá el primer error en `out/build.log`. |
| `Hay montajes activos` | Reiniciá y repetí. |
| WSL no encuentra Debian | Ejecutá `wsl --install -d Debian` y abrilo una vez. |
| Arranca sin escritorio | Abrí tty2 con Ctrl+Alt+F2 y revisá `/var/log/lightdm/` y `/var/log/Xorg.0.log`. |
| Pantalla negra en una GPU antigua | En el menú de arranque pulsá `e` o Tab y agregá `nomodeset`. |
| No aparece el Wi-Fi | Falta firmware: revisá `sudo dmesg \| grep -i firmware` y agregá el paquete a `config/package-lists/sistema.list.chroot`. |
| LauncherPC va lento | Ajustes > Fondo animado: No, o Ajustes > Gráficos > Optimizar. |

## 10. Estructura

| Carpeta | Contenido |
|---|---|
| `build.sh`, `build.ps1`, `build.bat` | Compilación |
| `versions.env` | Versiones y SHA-256 fijados |
| `config/package-lists/` | Paquetes de la distribución |
| `config/hooks/live/` | Instalación de aplicaciones, servicios y limpieza |
| `config/includes.chroot/` | Configuración del sistema y del escritorio |
| `config/includes.chroot/usr/local/bin/` | Herramientas y diagnóstico (`lpc-*`) |
| `launcher/` | Empaquetado de LauncherPC |
| `launcherpc/` | Código y recursos gráficos de LauncherPC con la adaptación a Linux |
| `.github/workflows/build-iso.yml`, `ci-build.sh` | Compilación en GitHub Actions y Localci |
| `launcherpc/.github/workflows/build.yml` | Compilación del `.exe` de Windows |
| `tests/` | Pruebas de lógica: `node tests/linux.test.js` |
| `docs/` | Decisiones, adaptación, versiones, actualización, pruebas y consumo |
