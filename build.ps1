# Compila la ISO desde Windows con WSL2. Uso: clic derecho > Ejecutar con PowerShell, o build.bat
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$distro = 'Debian'

function Wsl-List {
  $old = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.Encoding]::Unicode      # wsl.exe escribe en UTF-16
  try { (& wsl.exe --list --quiet 2>$null) | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
  finally { [Console]::OutputEncoding = $old }
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'Este Windows no tiene WSL. Hace falta Windows 10 2004 o posterior.' }
if ((Wsl-List) -notcontains $distro) {
  Write-Host "Falta WSL2 con Debian. En una PowerShell de administrador ejecutá:" -ForegroundColor Yellow
  Write-Host "  wsl --install -d Debian" -ForegroundColor Yellow
  Write-Host "Reiniciá si lo pide, abrí Debian una vez para crear tu usuario y volvé a ejecutar este script." -ForegroundColor Yellow
  exit 1
}

# Un chroot no funciona sobre /mnt/c: el proyecto se copia al disco de Linux
$drive = $here.Substring(0, 1).ToLower()
$src = '/mnt/' + $drive + ($here.Substring(2) -replace '\\', '/')
$script = @"
set -e
export DEBIAN_FRONTEND=noninteractive
mkdir -p /root/lpc-build
cd '$src'
tar --exclude=./work --exclude=./cache --exclude=./out -cf - . | tar -xf - -C /root/lpc-build
[ ! -d '$src/cache' ] || cp -rn '$src/cache' /root/lpc-build/
cd /root/lpc-build
bash build.sh
mkdir -p '$src/out' '$src/cache'
cp -f out/*.iso out/*.sha256 out/*.txt out/build.log '$src/out/'
cp -n cache/* '$src/cache/' 2>/dev/null || true
"@ -replace "`r`n", "`n"

$tmp = Join-Path $here 'wsl-build.sh'
[IO.File]::WriteAllText($tmp, $script, (New-Object Text.UTF8Encoding $false))
try { & wsl.exe -d $distro -u root --exec bash "$src/wsl-build.sh" }
finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
if ($LASTEXITCODE -ne 0) { throw "La compilación falló. Ver el registro dentro de WSL: /root/lpc-build/out/build.log" }
Write-Host "`nISO lista en: $here\out" -ForegroundColor Green
