#!/usr/bin/env python3
"""Genera LauncherPC-Linux-<versión>.zip en la raíz del repositorio. Uso: python distro/tools/make_zip.py"""
import pathlib
import re
import zipfile

DISTRO = pathlib.Path(__file__).resolve().parents[1]
REPO = DISTRO.parent
VERSION = re.search(r'DISTRO_VERSION="([^"]+)"', (DISTRO / "versions.env").read_text(encoding="utf-8")).group(1)
TOP = f"LauncherPC-Linux-{VERSION}"
OUT = REPO / f"{TOP}.zip"
SKIP = {"work", "cache", "out", "__pycache__"}
LAUNCHER = ["main.js", "preload.js", "lhm.js", "linux.js", "index.html", "package.json", "README.md", "CLAUDE.md",
            "assets/icon.png", "assets/icon-512.png", "assets/icon.svg", "assets/icon.ico", "assets/xmb-wave.mp4"]
BINARY = {".png", ".ico", ".mp4"}


def add(z, src, name):
    data = src.read_bytes()
    if src.suffix.lower() not in BINARY and not name.endswith((".bat", ".ps1")):
        data = data.replace(b"\r\n", b"\n")      # Linux no acepta CRLF en scripts
    if name.endswith(".ps1"):
        data = b"\xef\xbb\xbf" + data             # sin BOM, PowerShell 5 rompe los acentos
    executable = (name.endswith(".sh") or "/usr/local/" in name or name.endswith(("/ps-launcher", "/postinst", "icewm/startup"))
                  or "/hooks/" in name)
    info = zipfile.ZipInfo(name, date_time=(2026, 10, 31, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (0o100755 if executable else 0o100644) << 16
    z.writestr(info, data)


with zipfile.ZipFile(OUT, "w", compresslevel=9) as z:
    for f in sorted(DISTRO.rglob("*")):
        rel = f.relative_to(DISTRO)
        if f.is_file() and not SKIP.intersection(rel.parts):
            add(z, f, f"{TOP}/{rel.as_posix()}")
    for f in LAUNCHER:
        add(z, REPO / f, f"{TOP}/launcherpc/{f}")
    # build-iso.yml en la raíz: subiendo el ZIP extraído a un repositorio, GitHub compila la ISO. build.yml es el del .exe de Windows
    add(z, REPO / ".github/workflows/build-iso.yml", f"{TOP}/.github/workflows/build-iso.yml")
    add(z, REPO / ".github/workflows/build.yml", f"{TOP}/launcherpc/.github/workflows/build.yml")
print(OUT, OUT.stat().st_size)
