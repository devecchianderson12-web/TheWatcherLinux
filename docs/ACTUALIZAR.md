# Actualizar y reconstruir

## En un sistema ya instalado

Menú > Sistema > **Actualizar el sistema** ejecuta `apt-get update` y `full-upgrade`. Conviene hacerlo con frecuencia: es el único mecanismo de actualizaciones, y Firefox recibe parches de seguridad por esa vía.

RustDesk no tiene repositorio de apt: se actualiza instalando el `.deb` nuevo con doble clic.

## En la ISO

### Paquetes de Debian

No hace falta cambiar nada: cada compilación toma lo último de Debian 13.

```bash
sudo bash build.sh --clean
```

Para agregar o quitar paquetes: editá `config/package-lists/*.list.chroot`.

### RustDesk o Electron

1. Buscá la versión en sus releases de GitHub.
2. Calculá el SHA-256 del archivo. La API de GitHub lo publica en `assets[].digest` para RustDesk; Electron lo publica en `SHASUMS256.txt`.
3. Cambiá versión y SHA-256 en `versions.env`.
4. Recompilá.

Si Electron cambia de versión mayor, comprobá las bibliotecas que necesita y actualizá `launcher/control.in`.

### LauncherPC

Reemplazá los archivos de `launcherpc/` y recompilá. La versión del paquete sale de `package.json`.

## Reconstruir la ISO

```bash
sudo bash build.sh
```

Reconfigura y reconstruye `work/lb`. Las descargas de `cache/` se reutilizan si el SHA-256 coincide. Con `--clean` se borran también `work/` y `out/`.

## Pasar a Debian 14

Cambiá `DEBIAN_SUITE` y revisá nombres de paquetes (`libavcodec61`, los `t64` de `launcher/control.in`) y opciones de `live-build`. Si necesitás una imagen reproducible al detalle, apuntá `DEBIAN_MIRROR` a una fecha de `snapshot.debian.org`.
