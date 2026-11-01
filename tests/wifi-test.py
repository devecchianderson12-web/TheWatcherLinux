import os,re,socket,subprocess,sys,time
iso=sys.argv[1];out='/root/wt';os.makedirs(out,exist_ok=True)
for n in("vmlinuz","initrd.img"):subprocess.run(["xorriso","-osirrox","on","-indev",iso,"-extract","/live/"+n,f"{out}/{n}"],check=True,capture_output=True)
ser=f"{out}/s.sock"
if os.path.exists(ser):os.remove(ser)
vm=subprocess.Popen(["qemu-system-x86_64","-enable-kvm","-cpu","host","-m","2048","-smp","2","-cdrom",iso,"-kernel",f"{out}/vmlinuz","-initrd",f"{out}/initrd.img","-append","boot=live components username=usuario hostname=thewatcher locales=es_AR.UTF-8 keyboard-layouts=latam console=tty0 console=ttyS0,115200","-vga","std","-nic","user,model=e1000","-display","none","-serial",f"unix:{ser},server,nowait"])
time.sleep(2);s=socket.socket(socket.AF_UNIX);s.connect(ser);s.settimeout(1);buf=""
def read(p,t):
    global buf
    e=time.time()+t
    while time.time()<e:
        if re.search(p,buf):
            r=buf;buf="";return r
        try:buf+=s.recv(65536).decode("utf-8","replace")
        except socket.timeout:pass
    raise TimeoutError(p+" :: "+buf[-1500:])
n=0
def run(c,t=90):
    global n
    n+=1;s.sendall(f"{c}; echo FIN{n}x\n".encode());r=read(rf"\nFIN{n}x",t);print("$ "+c+"\n"+r[-2600:],flush=True)
try:
    read("login:",240);s.sendall(b"usuario\n");read("Contrase|[Pp]ass",20);s.sendall(b"live\n");read(r"[$#] ",30);time.sleep(20)
    run("stty cols 150; stty -echo; export LC_ALL=C PAGER=cat NO_COLOR=1; sudo apt-get update 2>&1 | tail -1; sudo apt-get install -y -qq hostapd dnsmasq-base 2>&1 | tail -1",180)
    run("sudo modprobe mac80211_hwsim radios=2; sleep 3; nmcli device; rfkill list 2>&1 | head; ls /usr/lib/firmware/regulatory.db 2>&1; sudo dmesg | grep -i 'regulatory\\|cfg80211' | tail -5")
    run("P=$(cat /sys/class/net/wlan1/phy80211/name); sudo ip netns add ap; sudo iw phy $P set netns name ap; sleep 2; A='sudo ip netns exec ap'; $A ip link set lo up; $A ip link set wlan1 up; $A ip addr add 10.9.0.1/24 dev wlan1; printf 'interface=wlan1\\ndriver=nl80211\\nssid=prueba\\nhw_mode=g\\nchannel=6\\nwpa=2\\nwpa_passphrase=clave12345\\nwpa_key_mgmt=WPA-PSK\\nrsn_pairwise=CCMP\\n' > /tmp/h.conf; ($A hostapd -B /tmp/h.conf >/tmp/h.log 2>&1); sleep 3; tail -4 /tmp/h.log; $A dnsmasq --interface=wlan1 --bind-interfaces --dhcp-range=10.9.0.10,10.9.0.20 --no-resolv; sleep 2; sudo nmcli device wifi rescan; sleep 6; sudo nmcli device wifi list | cat")
    run("sudo nmcli device wifi connect prueba password clave12345 ifname wlan0; sleep 4; nmcli device; ip -4 addr show wlan0 | grep inet; ping -c2 -W2 10.9.0.1 | tail -2; sudo nmcli -f connection.id,802-11-wireless-security.psk-flags connection show prueba | cat; cat /etc/resolv.conf; ls -la /etc/resolv.conf; sudo ls /etc/NetworkManager/system-connections/",60)
    run("sudo journalctl -u polkit --no-pager | tail -6; sudo ls -la /etc/polkit-1/rules.d/; systemctl status wpa_supplicant --no-pager | head -4; nmcli general permissions | head -14; groups")
    run("sudo journalctl -u NetworkManager --no-pager | grep -i 'wlan0\\|supplicant' | tail -14")
    print("OK")
except Exception as e:print("FALLO",e)
finally:vm.kill()
