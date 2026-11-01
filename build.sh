#!/usr/bin/env bash
# Construye la ISO de LauncherPC Linux desde cero. Uso: sudo bash build.sh [--clean]
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${LPC_WORK:-$ROOT/work}"
OUT="$ROOT/out"
CACHE="$ROOT/cache"
LOG="$OUT/build.log"
STEP=0

say()  { STEP=$((STEP + 1)); printf '\n\033[1;36m[%02d] %s\033[0m\n' "$STEP" "$1"; }
die()  { printf '\n\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }
trap 'printf "\n\033[1;31mLa compilación falló en la línea %s. Ver %s\033[0m\n" "$LINENO" "$LOG" >&2' ERR

# Un ZIP abierto en Windows puede dejar CRLF o quitar los permisos de ejecución
normalize_tree() {
  find "$ROOT/config" "$ROOT/launcher" -type f -exec sed -i 's/\r$//' {} + -exec chmod 644 {} +
  find "$ROOT/config" "$ROOT/launcher" -type d -exec chmod 755 {} +
  find "$ROOT" -maxdepth 2 -type f -name '*.sh' -not -path "$ROOT/work/*" -exec sed -i 's/\r$//' {} + -exec chmod 755 {} +
}

check_host() {
  [ "$(id -u)" -eq 0 ] || die "Ejecutá el script como root: sudo bash build.sh"
  [ "$(uname -m)" = x86_64 ] || die "Hace falta un sistema x86_64 para compilar"
  case "$ROOT" in
    /mnt/[a-z]/*) die "No compiles en un disco de Windows ($ROOT): copiá la carpeta dentro de Linux o usá build.ps1" ;;
  esac
  mkdir -p "$OUT" "$CACHE" "$WORK"
  local fs_type free ram
  fs_type="$(stat -f -c %T "$WORK")"
  case "$fs_type" in ntfs*|fuseblk|vfat|msdos|9p|v9fs|drvfs) die "El sistema de archivos $fs_type no sirve para un chroot: usá ext4" ;; esac
  free="$(df -BG --output=avail "$WORK" | tail -1 | tr -dc 0-9)"
  [ "$free" -ge 20 ] || die "Hacen falta 20 GB libres en $WORK y hay $free GB"
  ram="$(awk '/MemTotal/ {print int($2 / 1048576)}' /proc/meminfo)"
  [ "$ram" -ge 2 ] || echo "Aviso: con menos de 2 GB de RAM la compresión será muy lenta"
}

host_is_debian13() {
  [ -r /etc/os-release ] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  [ "${ID:-}" = debian ] && [ "${VERSION_CODENAME:-}" = "$DEBIAN_SUITE" ]
}

# live-build depende de la versión de Debian: en cualquier otro sistema con apt se compila dentro de un Debian 13 mínimo
run_in_buildroot() {
  command -v apt-get >/dev/null || die "Este sistema no usa apt. Compilá con Docker (ver README.md) o en Debian 13"
  say "Sistema distinto de Debian 13: preparando un entorno de compilación Debian 13"
  apt-get update
  apt-get install -y debootstrap debian-archive-keyring
  local br="$WORK/buildroot"
  cleanup_buildroot() { umount -lf "$br/src" "$br/lpc-work" "$br/dev/pts" "$br/dev" "$br/sys" "$br/proc" 2>/dev/null || true; }
  cleanup_buildroot
  if [ ! -x "$br/usr/bin/apt-get" ]; then
    grep -q " $br/" /proc/mounts && die "Hay montajes activos en $br"
    rm -rf "$br"
    debootstrap --keyring=/usr/share/keyrings/debian-archive-keyring.gpg --variant=minbase --include=ca-certificates \
      "$DEBIAN_SUITE" "$br" "$DEBIAN_MIRROR" /usr/share/debootstrap/scripts/sid
  fi
  cp -f /etc/resolv.conf "$br/etc/resolv.conf"
  mkdir -p "$br/src" "$br/lpc-work"
  trap cleanup_buildroot EXIT
  mount --bind "$ROOT" "$br/src"
  mkdir -p "$WORK/inner"
  mount --bind "$WORK/inner" "$br/lpc-work"
  mount -t proc proc "$br/proc"
  mount -t sysfs sys "$br/sys"
  mount --bind /dev "$br/dev"
  mount --bind /dev/pts "$br/dev/pts"
  chroot "$br" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LANG=C.UTF-8 \
    LPC_INSIDE=1 LPC_WORK=/lpc-work SGDB_KEY="${SGDB_KEY:-}" bash /src/build.sh
}

install_deps() {
  say "Comprobando e instalando las herramientas de compilación"
  local need=(live-build debootstrap xorriso squashfs-tools mtools dosfstools curl ca-certificates unzip binutils dpkg-dev)
  local missing=()
  for p in "${need[@]}"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed' || missing+=("$p"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Instalando: ${missing[*]}"
    apt-get update
    apt-get install -y --no-install-recommends "${missing[@]}"
  fi
}

# Descarga a la caché y comprueba el SHA-256; una descarga rota nunca llega a la ISO
fetch() {
  local url="$1" sha="$2" file="$CACHE/$(basename "$1")"
  if ! echo "$sha  $file" | sha256sum -c --status 2>/dev/null; then
    curl -fL --retry 5 --retry-delay 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
    echo "$sha  $file" | sha256sum -c --status || { rm -f "$file"; die "SHA-256 incorrecto: $url"; }
  fi
  echo "Verificado: $(basename "$file")"
}

launcher_src() {
  if [ -f "$ROOT/launcherpc/main.js" ]; then echo "$ROOT/launcherpc"
  elif [ -f "$ROOT/../main.js" ]; then (cd "$ROOT/.." && pwd)
  else die "No se encontró el código de LauncherPC (launcherpc/main.js)"; fi
}

configure_lb() {
  say "Configurando la distribución"
  local lb="$WORK/lb"
  [ -d "$lb/config" ] && (cd "$lb" && lb clean --purge >/dev/null 2>&1 || true)
  rm -rf "$lb"
  mkdir -p "$lb"
  cd "$lb"
  lb config noauto \
    --mode debian --system live --distribution "$DEBIAN_SUITE" --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --mirror-bootstrap "$DEBIAN_MIRROR" --mirror-chroot "$DEBIAN_MIRROR" --mirror-binary "$DEBIAN_MIRROR" \
    --mirror-chroot-security "$DEBIAN_SECURITY_MIRROR" --mirror-binary-security "$DEBIAN_SECURITY_MIRROR" \
    --security true --updates true --backports false \
    --apt-recommends false --apt-indices false --cache-packages true \
    --firmware-chroot false --firmware-binary false \
    --linux-flavours amd64 --memtest none --win32-loader false --zsync false --source false --checksums sha256 \
    --debian-installer live --debian-installer-gui true --debian-installer-distribution "$DEBIAN_SUITE" \
    --chroot-squashfs-compression-type xz \
    --image-name "$DISTRO_ID-$DISTRO_VERSION" \
    --iso-application "$DISTRO_NAME" --iso-volume "LPC_LINUX_${DISTRO_VERSION//./_}" --iso-publisher "$DISTRO_NAME" \
    --bootappend-live "boot=live components quiet username=usuario hostname=lpc-linux locales=es_AR.UTF-8 keyboard-layouts=latam timezone=America/Argentina/Buenos_Aires"
  cp -a "$ROOT/config/." "$lb/config/"
  mkdir -p "$lb/config/packages.chroot"
  cp "$CACHE/$(basename "$RUSTDESK_URL")" "$WORK"/launcher/ps-launcher_*_amd64.deb "$lb/config/packages.chroot/"
  find "$lb/config" -type f -path '*hooks*' -exec chmod 755 {} +
  find "$lb/config/includes.chroot/usr/local" -type f -exec chmod 755 {} +
  chmod 755 "$lb/config/includes.chroot/etc/X11/icewm/startup"
}

build_iso() {
  say "Construyendo la ISO (entre 20 minutos y varias horas)"
  cd "$WORK/lb"
  lb build || die "lb build falló"
}

verify_iso() {
  say "Verificando la ISO"
  local iso
  iso="$(find "$WORK/lb" -maxdepth 1 -name '*.iso' | head -1)"
  [ -n "$iso" ] || die "live-build terminó sin generar una ISO"
  local size; size="$(stat -c %s "$iso")"
  [ "$size" -gt 500000000 ] || die "La ISO mide solo $size bytes"
  xorriso -indev "$iso" -find /live/filesystem.squashfs -- 2>/dev/null | grep -q filesystem.squashfs || die "La ISO no contiene el sistema"
  xorriso -indev "$iso" -find /EFI -- 2>/dev/null | grep -q EFI || echo "Aviso: la ISO no trae arranque UEFI"
  xorriso -indev "$iso" -find /install -- 2>/dev/null | grep -q install || echo "Aviso: la ISO no trae el instalador"
  local list="$WORK/lb/chroot.packages.live"
  for p in rustdesk ps-launcher firefox-esr pcmanfm gdebi network-manager icewm; do
    grep -q "^$p[[:space:]]" "$list" || die "Falta el paquete obligatorio $p en la ISO"
  done
  mv -f "$iso" "$OUT/"
  cp -f "$list" "$OUT/paquetes-instalados.txt"
  cp -f "$WORK"/launcher/ps-launcher_*_amd64.deb "$OUT/"
  local final="$OUT/$(basename "$iso")"
  (cd "$OUT" && sha256sum "$(basename "$final")" > "$(basename "$final").sha256")
  say "Terminado"
  echo "ISO:      $final"
  echo "Tamaño:   $((size / 1048576)) MB"
  echo "SHA-256:  $final.sha256"
  echo "Paquetes: $OUT/paquetes-instalados.txt"
  echo "Launcher: $OUT/$(basename "$WORK"/launcher/ps-launcher_*_amd64.deb)"
  [ -z "${SUDO_UID:-}" ] || chown -R "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$OUT" "$CACHE"
}

main() {
  sed -i 's/\r$//' "$ROOT/versions.env" 2>/dev/null || true
  # shellcheck disable=SC1091
  . "$ROOT/versions.env"
  if [ "${1:-}" = --clean ]; then
    grep -q " $ROOT/work/" /proc/mounts && die "Hay montajes activos en work/: reiniciá antes de limpiar"
    rm -rf "${ROOT:?}/work" "${ROOT:?}/out"
  fi
  check_host
  normalize_tree
  : > "$LOG"
  exec > >(tee -a "$LOG") 2>&1
  if [ -z "${LPC_INSIDE:-}" ] && ! host_is_debian13; then
    run_in_buildroot
    local iso; iso="$(find "$OUT" -maxdepth 1 -name '*.iso' | head -1)"
    [ -n "$iso" ] || die "La compilación no generó ninguna ISO"
    echo "ISO: $iso"
    exit 0
  fi
  install_deps
  say "Preparando el entorno de compilación"
  say "Descargando los componentes desde sus fuentes oficiales"
  fetch "$RUSTDESK_URL" "$RUSTDESK_SHA256"
  fetch "$ELECTRON_URL" "$ELECTRON_SHA256"
  say "Empaquetando LauncherPC para Linux"
  LPC_SRC="$(launcher_src)" CACHE="$CACHE" DEST="$WORK/launcher" ELECTRON_ZIP="$CACHE/$(basename "$ELECTRON_URL")" \
    bash "$ROOT/launcher/build-deb.sh"
  configure_lb
  build_iso
  verify_iso
}

main "$@"
