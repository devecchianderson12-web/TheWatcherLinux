#!/usr/bin/env bash
# Empaqueta LauncherPC + Electron para Linux en un .deb. No hace falta Node.js: la app no tiene dependencias de npm en ejecución.
# Variables: LPC_SRC (código), ELECTRON_ZIP (Electron oficial verificado), DEST (salida). SGDB_KEY es opcional.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$LPC_SRC/package.json" | head -1)"
[ -n "$VERSION" ] || { echo "No se pudo leer la versión de package.json" >&2; exit 1; }

PKG="$DEST/pkg"
APP="$PKG/opt/ps-launcher"
rm -rf "$DEST"
mkdir -p "$APP" "$PKG/DEBIAN" "$PKG/usr/bin" "$PKG/usr/share/applications" \
  "$PKG/usr/share/icons/hicolor/256x256/apps" "$PKG/usr/share/icons/hicolor/512x512/apps"

unzip -q "$ELECTRON_ZIP" -d "$APP"
# Con otro nombre que "electron" app.isPackaged es verdadero
mv "$APP/electron" "$APP/ps-launcher"
rm -f "$APP/resources/default_app.asar"
find "$APP/locales" -type f ! -name 'es.pak' ! -name 'es-419.pak' ! -name 'en-US.pak' -delete

R="$APP/resources/app"
mkdir -p "$R/assets"
for f in main.js preload.js lhm.js linux.js index.html package.json; do cp "$LPC_SRC/$f" "$R/"; done
cp "$LPC_SRC"/assets/icon.png "$LPC_SRC"/assets/icon-512.png "$LPC_SRC"/assets/xmb-wave.mp4 "$R/assets/"
# Clave opcional de SteamGridDB: igual que en el workflow de Windows, nunca en el código
if [ -n "${SGDB_KEY:-}" ]; then printf '{"sgdb":"%s"}' "$SGDB_KEY" > "$R/build-key.json"; fi

chmod -R u=rwX,go=rX "$APP"
chmod 755 "$APP/ps-launcher" "$APP/chrome_crashpad_handler"
chmod 4755 "$APP/chrome-sandbox"

install -m 755 "$HERE/ps-launcher" "$PKG/usr/bin/ps-launcher"
install -m 644 "$HERE/ps-launcher.desktop" "$PKG/usr/share/applications/ps-launcher.desktop"
install -m 644 "$LPC_SRC/assets/icon.png" "$PKG/usr/share/icons/hicolor/256x256/apps/ps-launcher.png"
install -m 644 "$LPC_SRC/assets/icon-512.png" "$PKG/usr/share/icons/hicolor/512x512/apps/ps-launcher.png"

sed "s/@VERSION@/$VERSION/; s/@SIZE@/$(du -sk "$PKG" | cut -f1)/" "$HERE/control.in" > "$PKG/DEBIAN/control"
install -m 755 "$HERE/postinst" "$PKG/DEBIAN/postinst"

dpkg-deb --root-owner-group --build "$PKG" "$DEST/ps-launcher_${VERSION}_amd64.deb"
rm -rf "$PKG"
echo "Paquete: $DEST/ps-launcher_${VERSION}_amd64.deb"
