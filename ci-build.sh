#!/usr/bin/env bash
# Lo que ejecuta build-iso.yml. El mismo workflow corre en GitHub (Ubuntu) y en Localci (Windows con Git Bash, sin sudo ni
# GITHUB_OUTPUT), así que cada uno compila con lo que tiene. El resultado queda en iso-out/, en la raíz del proyecto.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="$HERE"
[ -f "$HERE/../.github/workflows/build-iso.yml" ] && TOP="$(cd "$HERE/.." && pwd)"
cd "$TOP" || exit 1
SUB="${HERE#"$TOP"}"; SUB="${SUB#/}"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "Windows: se compila con WSL2 (build.ps1)"
    "${SYSTEMROOT:-C:/Windows}/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$HERE/build.ps1")"
    st=$?
    ;;
  *)
    if [ -n "${GITHUB_ACTIONS:-}" ] && command -v docker >/dev/null; then
      # El runner trae unos 14 GB libres y build.sh pide 20. --privileged hace falta para los montajes del chroot
      sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL
      sudo docker image prune -af >/dev/null
      df -h /
      sudo docker run --rm --privileged -e SGDB_KEY="${SGDB_KEY:-}" -v "$TOP":/repo -w "/repo/$SUB" debian:trixie bash build.sh
      st=$?
    elif [ "$(id -u)" -eq 0 ]; then
      bash "$HERE/build.sh"; st=$?
    elif command -v sudo >/dev/null; then
      sudo -E bash "$HERE/build.sh"; st=$?
    else
      echo "ERROR: hace falta root o sudo para compilar en Linux" >&2
      exit 1
    fi
    ;;
esac

mkdir -p iso-out
[ ! -d "$HERE/out" ] || find "$HERE/out" -maxdepth 1 -type f -exec mv -f {} iso-out/ \;
exit "$st"
