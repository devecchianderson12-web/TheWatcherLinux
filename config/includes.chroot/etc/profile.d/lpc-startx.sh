# Escritorio al iniciar sesión en tty1
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ]; then
  exec startx /usr/local/bin/lpc-session -- -nolisten tcp -keeptty vt1 >/dev/null 2>&1
fi
