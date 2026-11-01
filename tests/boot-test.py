#!/usr/bin/env python3
"""Arranca la ISO en QEMU y comprueba el sistema por consola serie. Uso: boot-test.py <iso> <carpeta-salida> [ram-mb]
Necesita qemu-system-x86, netpbm, xorriso y /dev/kvm. Guarda capturas PNG y resultado.txt."""
import os
import re
import socket
import subprocess
import sys
import time

iso, out = sys.argv[1], sys.argv[2]
ram = sys.argv[3] if len(sys.argv) > 3 else "2048"
os.makedirs(out, exist_ok=True)
for n in ("vmlinuz", "initrd.img"):
    subprocess.run(["xorriso", "-osirrox", "on", "-indev", iso, "-extract", "/live/" + n, f"{out}/{n}"], check=True, capture_output=True)
ser, mon = f"{out}/ser.sock", f"{out}/mon.sock"
for s in (ser, mon):
    if os.path.exists(s):
        os.remove(s)
cmd = ["qemu-system-x86_64", "-enable-kvm", "-cpu", "host", "-m", ram, "-smp", "2", "-cdrom", iso, "-kernel", f"{out}/vmlinuz", "-initrd", f"{out}/initrd.img",
       "-append", "boot=live components username=usuario hostname=lpc-linux locales=es_AR.UTF-8 keyboard-layouts=latam timezone=America/Argentina/Buenos_Aires console=tty0 console=ttyS0,115200",
       "-vga", "std", "-nic", "user,model=e1000", "-drive", f"if=none,id=usbd,format=raw,file={out}/usb.img", "-usb", "-device", "usb-storage,drive=usbd", "-display", "none", "-serial", f"unix:{ser},server,nowait", "-monitor", f"unix:{mon},server,nowait"]
subprocess.run(f"truncate -s 64M {out}/usb.img && mkfs.vfat {out}/usb.img >/dev/null", shell=True, check=True)
vm = subprocess.Popen(cmd)
time.sleep(2)
s = socket.socket(socket.AF_UNIX)
s.connect(ser)
s.settimeout(1)
m = socket.socket(socket.AF_UNIX)
m.connect(mon)
buf = ""
res = open(f"{out}/resultado.txt", "w", encoding="utf-8")


def read(pat, t):
    global buf
    end = time.time() + t
    while time.time() < end:
        if re.search(pat, buf):
            r = buf
            buf = ""
            return r
        try:
            buf += s.recv(65536).decode("utf-8", "replace")
        except socket.timeout:
            pass
    raise TimeoutError(pat + " :: " + buf[-1500:])


seq = 0


def run(c, t=60):
    global seq
    seq += 1
    s.sendall(f"{c}; echo FIN{seq}$?\n".encode())
    r = read(rf"FIN{seq}\d+", t)
    r = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", r)
    res.write(f"\n$ {c}\n{r}\n")
    res.flush()
    print(f"$ {c}\n{r[-1800:]}", flush=True)
    return r


def shot(name):
    m.sendall(f"screendump /tmp/{name}.ppm\n".encode())
    time.sleep(2)
    subprocess.run(f"pnmtopng /tmp/{name}.ppm > {out}/{name}.png", shell=True, stderr=subprocess.DEVNULL)


try:
    t0 = time.time()
    read(r"login:", 240)
    res.write(f"login serie a los {time.time() - t0:.0f} s\n")
    s.sendall(b"usuario\n")
    read(r"Contrase|[Pp]ass", 20)
    s.sendall(b"live\n")
    read(r"[$#] ", 30)
    time.sleep(25)
    shot("1-escritorio")
    run("stty cols 160; export DISPLAY=:0 XAUTHORITY=$(ls -d /run/lightdm/usuario/xauthority $HOME/.Xauthority 2>/dev/null | head -1)")
    run("systemd-analyze; systemctl --failed --no-pager; ps -eo rss,comm --sort=-rss | head -20; free -m; loginctl list-sessions --no-legend; loginctl show-session $(loginctl list-sessions --no-legend | awk '/usuario/ && !/tty|pts/ {print $1; exit}') -p Type -p Display; cat /proc/swaps")
    run("pgrep -a Xorg; pgrep -a icewm; pgrep -a nm-applet; nmcli -t device; curl -sS -m 10 -o /dev/null -w 'https %{http_code}\\n' https://deb.debian.org/")
    run("systemctl is-active rustdesk NetworkManager systemd-timesyncd; dpkg-query -W rustdesk ps-launcher firefox-esr pcmanfm gdebi icewm; stat -c '%a %U' /opt/ps-launcher/chrome-sandbox")
    run("lpc-diag | tail -40", 90)
    run("(rustdesk >/tmp/rd.log 2>&1 &) ; sleep 15; pgrep -a rustdesk | head -5")
    shot("2-rustdesk")
    run("pkill -f 'rustdesk$'; (pcmanfm >/tmp/fm.log 2>&1 &) ; sleep 6; pgrep -a pcmanfm; free -m | sed -n 2p")
    shot("3-archivos")
    run("pkill pcmanfm; (firefox-esr https://www.debian.org >/tmp/ff.log 2>&1 &) ; sleep 30; pgrep -c firefox; free -m | sed -n 2p")
    shot("4-firefox")
    run("pkill firefox; sleep 2; (ps-launcher >/tmp/lp.log 2>&1 &) ; sleep 30; pgrep -c ps-launcher; free -m | sed -n 2p; pgrep -a xprop; tail -15 /tmp/lp.log; ls ~/.config/ps-launcher")
    shot("5-launcher")
    run("ls ~/.config; xprop -root _NET_ACTIVE_WINDOW; xwininfo -root -tree | grep -i 'launcher' | head -3; pkill ps-launcher; sleep 1")
    run("lsblk -o NAME,SIZE,TRAN | grep usb; udisksctl mount -b /dev/sda --no-user-interaction; ls /media/usuario 2>&1; udisksctl unmount -b /dev/sda --no-user-interaction", 30)
    run("cd /tmp; sudo apt-get update 2>&1 | tail -1; apt-get download sl 2>&1 | tail -1; sudo gdebi -n /tmp/sl*.deb 2>&1 | tail -3; which sl; dpkg-query -W libncurses6 sl", 120)
    res.write("\nOK\n")
    print("OK")
except Exception as e:
    res.write(f"\nFALLO {e}\n")
    print("FALLO", e)
    shot("fallo")
finally:
    vm.kill()
    res.close()
