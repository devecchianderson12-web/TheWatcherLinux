# Consumo de RAM y CPU en reposo

Medido el 01/11/2026 en QEMU/KVM con 2 GB de RAM y 2 CPU, en modo Live, con `lpc-diag`. **Es una máquina virtual: en hardware real las cifras pueden variar.**

| Medición | Resultado |
|---|---|
| RAM usada en reposo | **371 MB** de 1973 MB (`free`, columna usado) |
| RAM disponible | 1602 MB |
| CPU en reposo, promedio de 30 s | **1 %** |
| Procesos | 118 |
| Arranque hasta el modo gráfico | **9,7 s** (kernel 3,2 s + sistema 6,4 s) |
| RAM usada con Firefox y una página | 911 MB |
| RAM usada con LauncherPC abierto | 666 MB |

En modo Live parte de los archivos ocupa memoria caché. No está incluido en el valor "usado".

## Procesos que más memoria usan

Valores RSS, que cuentan dos veces la memoria compartida.

| Proceso | MB |
|---|---|
| Xorg | 98,5 |
| nm-applet | 92,9 |
| RustDesk (3 procesos) | 64,3 + 53,3 + 37,0 |
| NetworkManager | 19,4 |
| wireplumber | 16,0 |
| udisksd | 13,8 |
| icewm | 12,4 |
| pipewire | 11,1 |

RustDesk es lo que más consume, y es necesario para recibir conexiones. Para ahorrar esa memoria en un equipo que no las necesite:

```bash
sudo systemctl disable --now rustdesk
```

## Repetir la medición

Menú > Sistema > **Diagnóstico**. El resultado queda en `~/lpc-diag.txt`.
