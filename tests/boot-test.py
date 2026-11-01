import os,re,socket,subprocess,sys,time
iso='/root/ax/tw.iso';out='/root/at';os.makedirs(out,exist_ok=True)
ser,mon=out+'/s.sock',out+'/m.sock'
for f in(ser,mon):
    if os.path.exists(f):os.remove(f)
vm=subprocess.Popen(["qemu-system-x86_64","-enable-kvm","-cpu","host","-m","2048","-smp","2","-cdrom",iso,"-kernel","/root/ax/iso/antiX/vmlinuz1","-initrd","/root/ax/iso/antiX/initrd.gz","-append","quiet lang=es_AR console=tty0 console=ttyS0,115200","-vga","std","-nic","user,model=e1000","-display","none","-serial",f"unix:{ser},server,nowait","-monitor",f"unix:{mon},server,nowait"])
time.sleep(2);s=socket.socket(socket.AF_UNIX);s.connect(ser);s.settimeout(1);m=socket.socket(socket.AF_UNIX);m.connect(mon);buf=""
def read(p,t):
    global buf
    e=time.time()+t
    while time.time()<e:
        if re.search(p,buf):
            r=buf;buf="";return r
        try:buf+=s.recv(65536).decode("utf-8","replace")
        except socket.timeout:pass
    raise TimeoutError(p+" :: "+buf[-1200:])
def shot(n):
    m.sendall(f"screendump /tmp/{n}.ppm\n".encode());time.sleep(2);subprocess.run(f"pnmtopng /tmp/{n}.ppm > {out}/{n}.png",shell=True,stderr=subprocess.DEVNULL)
n=0
def run(c,t=90):
    global n
    n+=1;s.sendall(f'{c}; echo F""IN{n}x\n'.encode());r=read(rf"FIN{n}x",t);print("$ "+c+"\n"+r[-2500:],flush=True)
try:
    time.sleep(70);shot("1");
    time.sleep(5);s.sendall(bytes([10]));read(r"# ",60)
    run("stty cols 150; stty -echo; export PAGER=cat NO_COLOR=1; cat /proc/1/comm; head -6 /home/*/.icewm/toolbar; grep -n CONKY /home/*/.desktop-session/*.conf; uname -r; locale | head -2; free -m; ps -eo rss,comm --sort=-rss | head -14; ps -e --no-headers | wc -l; who; pgrep -a slimski; pgrep -a icewm; ip -4 a | grep inet; connmanctl services 2>&1 | head; ls /etc/runit/runsvdir/default | tr '\\n' ' '; sv status rustdesk 2>&1; pgrep -a rustdesk; curl -sS -m 10 -o /dev/null -w 'https %{http_code}\\n' https://deb.debian.org/")
    run("U=demo; echo U=$U; export DISPLAY=:0 XAUTHORITY=$(ls /home/demo/.Xauthority /tmp/.Xauth* /var/run/slim*.auth 2>/dev/null|head -1); ls -la /home/$U/.Xauthority; su $U -c 'DISPLAY=:0 XAUTHORITY=/home/demo/.Xauthority sh -c \"(rustdesk >/tmp/rd.log 2>&1 &) ; sleep 14\"'; pgrep -a rustdesk; tail -4 /tmp/rd.log; which loginctl")
    shot("2")
    run("U=demo; su $U -c 'DISPLAY=:0 XAUTHORITY=/home/demo/.Xauthority sh -c \"(thewatcher >/tmp/w.log 2>&1 &) ; sleep 14\"'; pgrep -a thewatcher; tail -4 /tmp/w.log; free -m | sed -n 2p")
    shot("3")
    print("OK")
except Exception as e:print("FALLO",e);shot("fallo")
finally:vm.kill()
