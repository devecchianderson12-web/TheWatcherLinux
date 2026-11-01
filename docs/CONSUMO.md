# Consumo de RAM y CPU en reposo

Versión 0.1.1, medido el 01/11/2026 en QEMU/KVM con 2 GB de RAM y 2 CPU, en modo Live, con `tw-diag`. **Es una máquina virtual: en hardware real las cifras pueden variar.**

| Medición | Resultado |
|---|---|
| RAM usada en reposo | **357 MB** de 1973 MB (`free`, columna usado) |
| RAM disponible | 1615 MB |
| CPU en reposo, promedio de 30 s | **2 %** |
| Procesos | 125 |
| Arranque hasta el modo gráfico | **11,8 s** (kernel 4,3 s + sistema 7,5 s) |
| RAM usada con Firefox y una página | 889 MB |
| RAM usada con The Watcher abierto, sin cámaras | 526 MB |

En modo Live parte de los archivos ocupa memoria caché. No está incluido en el valor "usado".

## Procesos que más memoria usan

Valores RSS, que cuentan dos veces la memoria compartida.

| Proceso | MB |
|---|---|
| Xorg | 96,8 |
| nm-applet | 93,2 |
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

Menú > Sistema > **Diagnóstico**. El resultado queda en `~/tw-diag.txt`.
