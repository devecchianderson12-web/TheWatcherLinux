#!/usr/bin/env bash
# Construye TheWatcher Linux modificando la ISO oficial de antiX 26.1 Full (x64).
# Uso, como root en Debian 13 o WSL2: bash build.sh "/ruta/antiX-26.1 Full.iso"
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:?Indicá la ruta de la ISO de antiX}"
sed -i 's/\r$//' "$ROOT/versions.env" "$ROOT"/config/*
# shellcheck disable=SC1091
. "$ROOT/versions.env"
W="${TW_WORK:-/root/tw-antix}"
OUT="$ROOT/out"
F="$W/fs"
ISO="$OUT/thewatcher-linux-$DISTRO_VERSION-amd64.iso"
export DEBIAN_FRONTEND=noninteractive

say() { printf '\n\033[1;36m== %s\033[0m\n' "$1"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }
unbind() { for m in dev/pts dev sys proc; do mountpoint -q "$F/$m" && umount -l "$F/$m"; done; return 0; }
trap unbind EXIT

[ "$(id -u)" -eq 0 ] || die "Ejecutá el script como root"
[ -f "$SRC" ] || die "No existe $SRC"
echo "$ANTIX_SHA256  $SRC" | sha256sum -c --status || die "La ISO no es antiX 26.1 Full x64 (SHA-256 distinto)"
echo "$THEWATCHER_SHA256  $ROOT/packages/$THEWATCHER_DEB" | sha256sum -c --status || die "packages/$THEWATCHER_DEB no coincide con versions.env"

say "Herramientas"
apt-get update -qq
apt-get install -y -qq --no-install-recommends squashfs-tools xorriso curl ca-certificates dpkg-dev >/dev/null

say "RustDesk"
mkdir -p "$ROOT/cache" "$OUT"
RD="$ROOT/cache/rustdesk-$RUSTDESK_VERSION-x86_64.deb"
echo "$RUSTDESK_SHA256  $RD" | sha256sum -c --status 2>/dev/null || curl -fL --retry 5 -o "$RD" "$RUSTDESK_URL"
echo "$RUSTDESK_SHA256  $RD" | sha256sum -c --status || die "SHA-256 de RustDesk incorrecto"
# antiX no usa systemd y bloquea libsystemd0 por política. RustDesk la declara pero sus binarios no la enlazan.
rm -rf "$W/rd"; mkdir -p "$W/rd"
dpkg-deb -R "$RD" "$W/rd/d"
sed -i 's/ libsystemd0,//' "$W/rd/d/DEBIAN/control"
dpkg-deb --root-owner-group -Zxz -b "$W/rd/d" "$W/rd/rustdesk.deb" >/dev/null

say "Extrayendo la ISO"
unbind
rm -rf "$F" "$W/iso"; mkdir -p "$W/iso"
xorriso -osirrox on -indev "$SRC" -extract / "$W/iso" 2>/dev/null
chmod -R u+w "$W/iso"
unsquashfs -q -n -d "$F" "$W/iso/antiX/linuxfs" >/dev/null

say "Preparando el chroot"
mount -t proc p "$F/proc"; mount -t sysfs s "$F/sys"; mount --bind /dev "$F/dev"; mount --bind /dev/pts "$F/dev/pts"
cp -aL "$F/etc/resolv.conf" "$W/resolv.orig" 2>/dev/null || : > "$W/resolv.orig"
rm -f "$F/etc/resolv.conf"; cp /etc/resolv.conf "$F/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$F/usr/sbin/policy-rc.d"; chmod 755 "$F/usr/sbin/policy-rc.d"
chroot "$F" sh -c 'apt-get update 2>&1 | tail -2' || true

say "Quitando lo innecesario"
# wl.ko (Wi-Fi Broadcom) se compiló con DKMS: se conserva sin dejar DKMS ni cabeceras
for k in "$F"/lib/modules/*; do mkdir -p "$W/wl/$(basename "$k")"; cp "$k/updates/dkms/wl.ko" "$W/wl/$(basename "$k")/"; done
P="$(tr '\n' ' ' < "$ROOT/config/purge.list")"
chroot "$F" bash -c "set -f; apt-get -s purge --autoremove $P" | awk '/^Purg/{print $2}' > "$W/purge.sim"
for keep in antix-installer connman cmst slimski icewm zzzfm firefox-esr deb-installer x11-xserver-utils; do
  grep -qx "$keep" "$W/purge.sim" && die "La purga quitaría $keep"
done
chroot "$F" bash -c "set -f; apt-get -y purge --autoremove $P" >/dev/null
for k in "$W"/wl/*; do v="$(basename "$k")"; mkdir -p "$F/lib/modules/$v/updates/dkms"; cp "$k/wl.ko" "$F/lib/modules/$v/updates/dkms/"; chroot "$F" depmod "$v"; done
# Sin esto, al iniciar sesión desktop-menu pide contraseña para limpiar los accesos de lo que se quitó
chroot "$F" bash -c 'dpkg-divert --list | grep "by antix26-desktop-files" | while read -r _ _ f _ t _; do
  if [ ! -e "$t" ]; then [ -L "$f" ] && rm -f "$f"; dpkg-divert --package antix26-desktop-files --rename --remove "$f" >/dev/null; fi; done'
# Dentro del chroot: los accesos son enlaces absolutos, y desde fuera parecerían rotos
chroot "$F" find -L /usr/share/applications -maxdepth 1 -type l -delete

say "Idioma"
sed -i -E 's/^([a-zA-Z])/# \1/; s/^# *(es_AR.UTF-8 UTF-8|es_ES.UTF-8 UTF-8|en_US.UTF-8 UTF-8)/\1/' "$F/etc/locale.gen"
chroot "$F" locale-gen >/dev/null
chroot "$F" update-locale LANG=es_AR.UTF-8
sed -i 's#^linux /antiX/${kernel} quiet#linux /antiX/${kernel} quiet lang=es_AR#' "$W/iso/boot/grub/grub.cfg"
grep -rl 'quiet' "$W/iso/boot/syslinux"/*.cfg 2>/dev/null | xargs -r sed -i 's/quiet/quiet lang=es_AR/'

say "Instalando The Watcher y RustDesk"
cp "$W/rd/rustdesk.deb" "$F/tmp/rustdesk.deb"
cp "$ROOT/packages/$THEWATCHER_DEB" "$F/tmp/thewatcher.deb"
# El postinst de RustDesk lee el PID 1 del anfitrión; si es systemd llama a systemctl, que antiX no tiene
printf '#!/bin/sh\nexit 0\n' > "$F/usr/bin/systemctl"; chmod 755 "$F/usr/bin/systemctl"
chroot "$F" apt-get -y --no-install-recommends install /tmp/rustdesk.deb /tmp/thewatcher.deb >/dev/null
rm -f "$F/usr/bin/systemctl" "$F"/tmp/*.deb "$F/usr/lib/systemd/system/rustdesk.service"
chroot "$F" sh -c 'apt-get -y --no-install-recommends --only-upgrade install firefox-esr 2>&1 | tail -1' || true
ln -sf /usr/share/rustdesk/rustdesk "$F/usr/bin/rustdesk"

say "Servicios y escritorio"
mkdir -p "$F/etc/sv/rustdesk"
install -m 755 "$ROOT/config/rustdesk.run" "$F/etc/sv/rustdesk/run"
ln -sf /etc/sv/rustdesk "$F/etc/runit/runsvdir/default/rustdesk"
install -m 755 "$ROOT/config/rustdesk.init" "$F/etc/init.d/rustdesk"
chroot "$F" update-rc.d rustdesk defaults >/dev/null 2>&1 || true
for s in ssh rsync smartmontools bluetooth saned cups gpm; do
  rm -f "$F/etc/runit/runsvdir/default/$s"
  chroot "$F" update-rc.d "$s" disable >/dev/null 2>&1 || true
done
find "$F/etc/skel/.icewm" "$F/usr/share/antiX/localisation" -type f -name 'toolbar*' -exec cp "$ROOT/config/toolbar" {} \;
sed -i 's/^LOAD_CONKY=.*/LOAD_CONKY="false"/' "$F/etc/skel/.desktop-session/desktop-session.conf"
cp "$ROOT/config/90-tw.conf" "$F/etc/sysctl.d/90-tw.conf"
if [ -n "${TW_TEST:-}" ]; then     # consola de root por el puerto serie: solo para tests/boot-test.py, nunca en una release
  mkdir -p "$F/etc/sv/ttest"
  printf '#!/bin/sh\nexec setsid bash -i </dev/ttyS0 >/dev/ttyS0 2>&1\n' > "$F/etc/sv/ttest/run"; chmod 755 "$F/etc/sv/ttest/run"
  ln -sf /etc/sv/ttest "$F/etc/runit/runsvdir/default/ttest"
fi
chroot "$F" dpkg-query -W > "$OUT/paquetes-instalados.txt"
rm -rf "$W/desktop.ok"; mkdir -p "$W/desktop.ok"; cp -P "$F"/usr/share/applications/*.desktop "$W/desktop.ok/"
chroot "$F" bash -c 'apt-get clean; rm -rf /var/lib/apt/lists/* /root/.bash_history; dpkg --audit'
rm -f "$F/usr/sbin/policy-rc.d" "$F/etc/resolv.conf"
cp "$W/resolv.orig" "$F/etc/resolv.conf"
unbind

say "Reconstruyendo la ISO"
rm -f "$W/iso/antiX/linuxfs" "$ISO"
mksquashfs "$F" "$W/iso/antiX/linuxfs" -comp zstd -b 262144 -noappend -quiet -no-progress -wildcards -e 'tmp/*' >/dev/null
(cd "$W/iso/antiX" && md5sum linuxfs > linuxfs.md5)
echo "UncompressedSizeKB=$(du -sk "$F" | cut -f1)" > "$W/iso/antiX/linuxfs.info"
xorriso -indev "$SRC" -outdev "$ISO" -boot_image any replay -volid antiX-Live -compliance no_emul_toc \
  -update "$W/iso/antiX/linuxfs" /antiX/linuxfs -update "$W/iso/antiX/linuxfs.md5" /antiX/linuxfs.md5 \
  -update "$W/iso/antiX/linuxfs.info" /antiX/linuxfs.info -update "$W/iso/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  -update_r "$W/iso/boot/syslinux" /boot/syslinux -commit 2>&1 | tail -1
for d in terminal minstall web-browser file-manager deb-installer; do [ -L "$W/desktop.ok/$d.desktop" ] || die "Falta el acceso $d.desktop"; done
for p in rustdesk thewatcher firefox-esr connman antix-installer; do grep -q "^$p[[:space:]:]" "$OUT/paquetes-instalados.txt" || die "Falta $p"; done
xorriso -indev "$ISO" -report_el_torito plain 2>&1 | grep -q UEFI || die "La ISO perdió el arranque UEFI"
say "Listo"
ls -la "$ISO"
