# Consumo de RAM y CPU en reposo

**Sin medir.** La ISO no se compiló ni se arrancó, así que no hay cifras reales y este informe no inventa ninguna.

## Cómo obtenerlo

1. Arrancá el sistema, conectate a la red y dejalo 2 minutos sin tocar.
2. Menú > Sistema > **Diagnóstico**.
3. El resultado queda en `~/lpc-diag.txt`: CPU promedio de 30 s, `free -m`, cantidad de procesos, los 12 que más RAM usan y el tiempo de arranque.

## Tabla a completar

| Medición | VM 2 GB | Equipo real |
|---|---|---|
| RAM usada en reposo | | |
| CPU en reposo | | |
| Procesos | | |
| Tiempo de arranque | | |
| RAM con Firefox y una página | | |
| RAM con LauncherPC abierto | | |

## Qué queda residente

Kernel, systemd, udev, dbus, logind, journald, NetworkManager, wpa_supplicant, timesyncd, polkit, RustDesk, udisks si fue activado, Xorg, IceWM (con `icewmbg` e `icewm-session`) y nm-applet.

Los más pesados en reposo deberían ser Xorg y RustDesk. Si hace falta bajar más, se puede apagar RustDesk con `sudo systemctl disable --now rustdesk`, a costa de no recibir conexiones.
