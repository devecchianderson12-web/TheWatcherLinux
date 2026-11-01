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

### RustDesk

1. Buscá la versión en sus releases de GitHub.
2. La API de GitHub publica el SHA-256 en `assets[].digest`.
3. Cambiá versión y SHA-256 en `versions.env`.
4. Recompilá.

### The Watcher

Reemplazá el `.deb` de `packages/` y actualizá nombre y SHA-256 en `versions.env`.

## Reconstruir la ISO

```bash
sudo bash build.sh
```

Reconfigura y reconstruye `work/lb`. Las descargas de `cache/` se reutilizan si el SHA-256 coincide. Con `--clean` se borran también `work/` y `out/`.

## Pasar a Debian 14

Cambiá `DEBIAN_SUITE` y revisá nombres de paquetes (`libavcodec61`) y opciones de `live-build`. Si necesitás una imagen reproducible al detalle, apuntá `DEBIAN_MIRROR` a una fecha de `snapshot.debian.org`.
