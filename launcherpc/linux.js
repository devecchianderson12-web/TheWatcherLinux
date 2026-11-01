// Equivalentes en Linux de lo que en Windows hacen el registro, PowerShell, XInput y LibreHardwareMonitor (módulo puro, sin Electron)
const fs = require('fs');
const path = require('path');

// ---------- Steam para Linux ----------
// No hay registro: Steam se instala en una de estas carpetas (nativo, paquete de Debian, Flatpak o Snap)
const STEAM_DIRS = ['.steam/steam', '.steam/root', '.steam/debian-installation', '.local/share/Steam',
  '.var/app/com.valvesoftware.Steam/.local/share/Steam', 'snap/steam/common/.local/share/Steam'];
function steamRoot(home) {
  for (const d of STEAM_DIRS) {
    const p = path.join(home, d);
    try { if (fs.statSync(path.join(p, 'steamapps')).isDirectory()) return fs.realpathSync(p); } catch {}
  }
  return null;
}

// ---------- Epic Games ----------
// Epic no tiene cliente para Linux: sus juegos se instalan con Heroic Games Launcher (o legendary), que los registra en installed.json
const LEGENDARY = ['.config/heroic/legendaryConfig/legendary/installed.json',
  '.var/app/com.heroicgameslauncher.hgl/config/heroic/legendaryConfig/legendary/installed.json', '.config/legendary/installed.json'];
function heroicGames(home) {
  const out = new Map();
  for (const f of LEGENDARY) {
    let j;
    try { j = JSON.parse(fs.readFileSync(path.join(home, f), 'utf8')); } catch { continue; }
    for (const g of Object.values(j || {})) {
      if (!g || !g.app_name || !g.title || out.has(g.app_name)) continue;
      const url = 'heroic://launch?appName=' + encodeURIComponent(g.app_name) + '&runner=legendary';
      out.set(g.app_name, { id: 'epic:' + g.app_name, type: 'epic', name: g.title, dir: g.install_path || '', url, start: url });
    }
  }
  return [...out.values()];
}

// ---------- Aplicaciones (.desktop) ----------
function parseDesktop(text) {
  const o = {};
  let main = false;
  for (const raw of String(text).split(/\r?\n/)) {
    const l = raw.trim();
    if (l.startsWith('[')) { if (main) break; main = l === '[Desktop Entry]'; continue; }
    const i = l.indexOf('=');
    if (!main || i < 1) continue;
    const k = l.slice(0, i).trim();
    if (!(k in o)) o[k] = l.slice(i + 1).trim();
  }
  return o;
}
// Exec= sin los códigos de campo (%f, %U…): el launcher no pasa archivos a los programas que abre
const execLine = s => String(s || '').replace(/%%/g, '\0').replace(/\s*%[fFuUdDnNickvm]/g, '').replace(/\0/g, '%').trim();

const appDirs = home => ['/usr/share/applications', '/usr/local/share/applications', path.join(home, '.local/share/applications'),
  '/var/lib/flatpak/exports/share/applications', path.join(home, '.local/share/flatpak/exports/share/applications'), '/var/lib/snapd/desktop/applications'];
// Lanzadores de tiendas, no juegos. Los juegos que Steam deja en el menú ya salen de su biblioteca.
const NOT_A_GAME = /^(steam|heroic|com\.heroicgameslauncher\.hgl|com\.valvesoftware\.Steam|lutris|net\.lutris\.Lutris)\.desktop$/i;
function desktopGames(home) {
  const out = new Map();
  for (const dir of appDirs(home)) {
    let files = [];
    try { files = fs.readdirSync(dir).filter(f => f.endsWith('.desktop') && !NOT_A_GAME.test(f)); } catch { continue; }
    for (const f of files) {
      try {
        const d = parseDesktop(fs.readFileSync(path.join(dir, f), 'utf8'));
        if (d.Type !== 'Application' || !d.Name || !d.Exec || d.NoDisplay === 'true' || d.Hidden === 'true') continue;
        if (!String(d.Categories || '').split(';').includes('Game') || /\bsteam:\/\//.test(d.Exec)) continue;
        out.set(f, { id: 'app:' + f.replace(/\.desktop$/, ''), type: 'app', name: d.Name, dir: '', exec: execLine(d.Exec), start: f, icon: iconFile(d.Icon) });
      } catch {}
    }
  }
  return [...out.values()];
}
// Icono de una aplicación: ruta absoluta o nombre del tema; solo se usa como última portada
function iconFile(icon) {
  if (!icon) return null;
  if (path.isAbsolute(icon)) return /\.(png|jpe?g)$/i.test(icon) && fs.existsSync(icon) ? icon : null;
  const sizes = ['512x512', '256x256', '128x128', '96x96', '64x64', '48x48'];
  const list = [...sizes.map(s => `/usr/share/icons/hicolor/${s}/apps/${icon}.png`), `/usr/share/pixmaps/${icon}.png`];
  return list.find(f => fs.existsSync(f)) || null;
}

// ---------- Programas ----------
// El equivalente del .exe: AppImage, binarios de juegos, scripts y .desktop. Sin extensión solo cuenta un ejecutable ELF
const PROG_RE = /\.(x86_64|x86|appimage|sh|bin|desktop)$|^[^.]+$/i;
function isProgram(file) {
  const name = path.basename(file);
  if (!PROG_RE.test(name)) return false;
  if (name.includes('.')) return true;
  let fd;
  try {
    fs.accessSync(file, fs.constants.X_OK);
    const b = Buffer.alloc(4);
    fd = fs.openSync(file, 'r');
    fs.readSync(fd, b, 0, 4, 0);
    return b.toString('latin1') === '\x7fELF';
  } catch { return false; } finally { if (fd !== undefined) fs.closeSync(fd); }
}
// Cómo abrir un programa: [orden, argumentos]. Un .desktop se abre con su Exec; un script sin permiso de ejecución, con sh
function launchArgs(file) {
  if (/\.desktop$/i.test(file)) {
    const d = parseDesktop(fs.readFileSync(file, 'utf8'));
    return d.Exec ? ['/bin/sh', ['-c', execLine(d.Exec)]] : null;
  }
  let x = true;
  try { fs.accessSync(file, fs.constants.X_OK); } catch { x = false; }
  if (x) return [file, []];
  return /\.sh$/i.test(file) ? ['/bin/sh', [file]] : null;
}

// ---------- Discos ----------
// Pendrives y discos que montó udisks (el explorador propio del launcher los muestra como lugares rápidos)
function drives(user) {
  const out = [{ name: 'Sistema de archivos', path: '/', kind: 'drive' }];
  for (const base of [path.join('/media', user), path.join('/run/media', user), '/mnt']) {
    try {
      for (const e of fs.readdirSync(base, { withFileTypes: true }))
        if (e.isDirectory()) out.push({ name: e.name, path: path.join(base, e.name), kind: 'drive' });
    } catch {}
  }
  return out;
}

// ---------- Inicio con el sistema ----------
const autostartFile = home => path.join(home, '.config/autostart/ps-launcher.desktop');
function setAutostart(home, on, exec, hidden) {
  const f = autostartFile(home);
  if (!on) { try { fs.unlinkSync(f); } catch {} return; }
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, `[Desktop Entry]\nType=Application\nName=PS Launcher\nExec=${exec}${hidden ? ' --hidden' : ''}\nX-GNOME-Autostart-enabled=true\n`);
}

// ---------- Ventana activa (lo que xprop -spy escribe en cada cambio) ----------
// "_NET_ACTIVE_WINDOW(WINDOW): window id # 0x1a00003" → 0x1a00003n; sin ventana → 0n
function activeWindow(line) {
  const m = /window id # (0x[0-9a-f]+)/i.exec(line);
  return m ? BigInt(m[1]) : null;
}
const isShellWindow = s => /_NET_WM_WINDOW_TYPE_(DOCK|DESKTOP)/.test(String(s));

// ---------- Mando (/dev/input/js*) ----------
// Sustituye a XInput y winmm. Evento de 8 bytes: tiempo u32, valor s16, tipo u8 (1 botón, 2 eje, 0x80 estado inicial), número u8.
// L1/R1 = botones 4 y 5 en xpad, hid-playstation, nintendo y genéricos. L2/R2 = ejes 2 y 5 si son analógicos, o botones 6 y 7 si no.
class Pad {
  constructor() { this.btn = new Set(); this.ax = {}; this.tail = Buffer.alloc(0); this.down = false; }
  // Devuelve { combo: se acaba de completar L1+R1+L2+R2, press: se pulsó algo }
  feed(chunk) {
    const b = this.tail.length ? Buffer.concat([this.tail, chunk]) : chunk;
    let i = 0, press = false;
    for (; i + 8 <= b.length; i += 8) {
      const v = b.readInt16LE(i + 4), t = b[i + 6], n = b[i + 7], live = !(t & 0x80), k = t & 0x7f;
      if (k === 1) { if (v) { this.btn.add(n); if (live) press = true; } else this.btn.delete(n); }
      else if (k === 2) this.ax[n] = v;
    }
    this.tail = b.subarray(i);
    const trig = (this.ax[2] > 0 && this.ax[5] > 0) || (this.btn.has(6) && this.btn.has(7));
    const c = this.btn.has(4) && this.btn.has(5) && trig, combo = c && !this.down;
    this.down = c;
    return { combo, press };
  }
}

// ---------- GPU sin nvidia-smi ----------
// AMD expone uso y temperatura en sysfs; leerlo no lanza ningún proceso. Sustituye a LibreHardwareMonitor.
function gpuSysfs(root = '/sys/class/drm') {
  let cards = [];
  try { cards = fs.readdirSync(root).filter(c => /^card\d+$/.test(c)); } catch { return null; }
  for (const c of cards) {
    const dev = path.join(root, c, 'device');
    let use = null, temp = null;
    try { use = parseInt(fs.readFileSync(path.join(dev, 'gpu_busy_percent'), 'utf8'), 10); } catch {}
    try {
      const h = fs.readdirSync(path.join(dev, 'hwmon'))[0];
      temp = parseInt(fs.readFileSync(path.join(dev, 'hwmon', h, 'temp1_input'), 'utf8'), 10) / 1000;
    } catch {}
    if (Number.isFinite(use) || Number.isFinite(temp)) return { gpuUse: Number.isFinite(use) ? use : null, gpuTemp: Number.isFinite(temp) ? temp : null };
  }
  return null;
}

module.exports = { steamRoot, heroicGames, parseDesktop, execLine, desktopGames, iconFile, isProgram, launchArgs, drives, setAutostart, autostartFile, activeWindow, isShellWindow, Pad, gpuSysfs };
