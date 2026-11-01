// Pruebas de lógica de la adaptación a Linux (sin Electron). Uso: node distro/tests/linux.test.js
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const root = [path.join(__dirname, '../launcherpc'), path.join(__dirname, '../..')].find(d => fs.existsSync(path.join(d, 'linux.js')));
const lx = require(path.join(root, 'linux.js'));

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'lpc-'));
const w = (f, s) => { const p = path.join(tmp, f); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, s); return p; };
const ev = (v, t, n) => { const b = Buffer.alloc(8); b.writeInt16LE(v, 4); b[6] = t; b[7] = n; return b; };
let n = 0;
const t = (name, fn) => { fn(); n++; console.log('ok  ' + name); };

t('Exec sin códigos de campo', () => {
  assert.equal(lx.execLine('supertux2 %U'), 'supertux2');
  assert.equal(lx.execLine('app --x=100%% %f'), 'app --x=100%');
});
t('parseDesktop lee solo [Desktop Entry]', () => {
  const d = lx.parseDesktop('[Desktop Entry]\nName=Juego\nExec=a\n[Desktop Action x]\nName=Otro\n');
  assert.equal(d.Name, 'Juego');
});
t('Steam: encuentra la carpeta nativa', () => {
  fs.mkdirSync(path.join(tmp, '.local/share/Steam/steamapps'), { recursive: true });
  assert.ok(lx.steamRoot(tmp).endsWith(path.join('.local', 'share', 'Steam')));
});
t('Heroic: lee installed.json', () => {
  w('.config/heroic/legendaryConfig/legendary/installed.json', JSON.stringify({ Fortnite: { app_name: 'Fortnite', title: 'Fortnite', install_path: '/g/f' } }));
  const g = lx.heroicGames(tmp);
  assert.equal(g[0].id, 'epic:Fortnite');
  assert.equal(g[0].url, 'heroic://launch?appName=Fortnite&runner=legendary');
});
t('.desktop: juegos sí, lanzadores y entradas de Steam no', () => {
  const a = '.local/share/applications/';
  w(a + 'sdl.desktop', '[Desktop Entry]\nType=Application\nName=SuperTux\nExec=supertux2 %U\nCategories=Game;ArcadeGame;\n');
  w(a + 'steam.desktop', '[Desktop Entry]\nType=Application\nName=Steam\nExec=steam\nCategories=Game;\n');
  w(a + 'st.desktop', '[Desktop Entry]\nType=Application\nName=X\nExec=steam steam://rungameid/1\nCategories=Game;\n');
  w(a + 'ed.desktop', '[Desktop Entry]\nType=Application\nName=Editor\nExec=ed\nCategories=Utility;\n');
  const g = lx.desktopGames(tmp).filter(x => x.id === 'app:sdl' || x.name === 'Steam' || x.name === 'X' || x.name === 'Editor');
  assert.deepEqual(g.map(x => x.exec), ['supertux2']);
});
t('Programas por extensión', () => {
  for (const f of ['g.x86_64', 'g.AppImage', 'run.sh', 'j.desktop']) assert.ok(lx.isProgram(w('p/' + f, 'x')), f);
  assert.ok(!lx.isProgram(w('p/lib.so', 'x')));
  assert.ok(!lx.isProgram(w('p/leeme.txt', 'x')));
});
t('launchArgs de un .desktop', () => {
  const r = lx.launchArgs(w('p/z.desktop', '[Desktop Entry]\nExec=juego %f\n'));
  assert.deepEqual(r, ['/bin/sh', ['-c', 'juego']]);
});
t('xprop: ventana activa', () => {
  assert.equal(lx.activeWindow('_NET_ACTIVE_WINDOW(WINDOW): window id # 0x1a00003'), 0x1a00003n);
  assert.equal(lx.activeWindow('_NET_ACTIVE_WINDOW(WINDOW): window id # 0x0'), 0n);
  assert.equal(lx.activeWindow('otra cosa'), null);
  assert.ok(lx.isShellWindow('_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_DOCK'));
  assert.ok(!lx.isShellWindow('_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_NORMAL'));
});
t('Mando Xbox: LB+RB+LT+RT con ejes, una vez por pulsación', () => {
  const p = new lx.Pad();
  p.feed(Buffer.concat([ev(-32767, 0x82, 2), ev(-32767, 0x82, 5)]));
  assert.equal(p.feed(ev(1, 1, 4)).combo, false);
  p.feed(ev(1, 1, 5)); p.feed(ev(30000, 2, 2));
  assert.equal(p.feed(ev(30000, 2, 5)).combo, true);
  assert.equal(p.feed(ev(31000, 2, 5)).combo, false);
  p.feed(ev(0, 1, 4));
  assert.equal(p.feed(ev(1, 1, 4)).combo, true);
});
t('Mando genérico: L2 y R2 como botones', () => {
  const p = new lx.Pad();
  for (const b of [4, 5, 6]) p.feed(ev(1, 1, b));
  assert.equal(p.feed(ev(1, 1, 7)).combo, true);
});
t('Mando: evento partido entre dos lecturas y estado inicial que no cuenta como pulsación', () => {
  const p = new lx.Pad(), e = ev(1, 1, 0);
  assert.equal(p.feed(e.subarray(0, 3)).press, false);
  assert.equal(p.feed(e.subarray(3)).press, true);
  assert.equal(new lx.Pad().feed(ev(1, 0x81, 1)).press, false);
});
t('Uso de GPU por sysfs', () => {
  w('drm/card0/device/gpu_busy_percent', '37\n');
  w('drm/card0/device/hwmon/hwmon1/temp1_input', '54000\n');
  assert.deepEqual(lx.gpuSysfs(path.join(tmp, 'drm')), { gpuUse: 37, gpuTemp: 54 });
  assert.equal(lx.gpuSysfs(path.join(tmp, 'nada')), null);
});
t('Inicio con el sistema: crea y borra el .desktop', () => {
  lx.setAutostart(tmp, true, '/usr/bin/ps-launcher', true);
  assert.ok(fs.readFileSync(lx.autostartFile(tmp), 'utf8').includes('Exec=/usr/bin/ps-launcher --hidden'));
  lx.setAutostart(tmp, false, '/usr/bin/ps-launcher', true);
  assert.ok(!fs.existsSync(lx.autostartFile(tmp)));
});
fs.rmSync(tmp, { recursive: true, force: true });
console.log(`\n${n} pruebas correctas`);
