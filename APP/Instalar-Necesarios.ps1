# MovilLink - instalador de herramientas necesarias.
# Orden: verifica adb -> winget (GLOBAL, usuario) -> descarga oficial de
# Google a APP\platform-tools (portable, sin tocar PATH). En ambos casos
# la app lo encuentra sola via Resolve-Adb.
$ErrorActionPreference = 'Continue'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'Core\MovilLink.Core.ps1')

function Paso([string]$t) { Write-Host ''; Write-Host "== $t" -ForegroundColor Cyan }
function Ok([string]$t)   { Write-Host "   [OK] $t" -ForegroundColor Green }
function Mal([string]$t)  { Write-Host "   [..] $t" -ForegroundColor Yellow }

Write-Host '============================================' -ForegroundColor Cyan
Write-Host '  MovilLink - INSTALAR HERRAMIENTAS' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

Paso '1/3  PowerShell'
$v = $PSVersionTable.PSVersion
if ($v.Major -ge 5) { Ok "PowerShell $v (WinForms incluido)" } else { Mal "PowerShell $v muy viejo - actualiza Windows" }

Paso '2/3  Android Platform-Tools (adb)'
$adb = Resolve-Adb $raiz
if ($adb) {
  & $adb version | Select-Object -First 1 | ForEach-Object { Ok $_ }
} else {
  Mal 'adb no encontrado -> instalando'
  $instalado = $false

  # Via 1 (GLOBAL): winget -> shim en %LOCALAPPDATA%\Microsoft\WinGet\Links
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host '   winget install Google.PlatformTools ...'
    winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements --disable-interactivity
    # PATH del proceso no se refresca: probar el shim directo
    $shim = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\adb.exe'
    if ((Get-Command adb -ErrorAction SilentlyContinue) -or (Test-Path $shim)) { $instalado = $true; Ok 'adb instalado (winget, global)' }
  } else { Mal 'winget no disponible en este Windows' }

  # Via 2 (PORTABLE): zip oficial de Google -> APP\platform-tools\
  if (-not $instalado) {
    $zip = Join-Path $env:TEMP 'platform-tools-movillink.zip'
    try {
      Write-Host '   Descargando platform-tools desde dl.google.com ...'
      Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing
      Expand-Archive -Force $zip (Join-Path $raiz 'APP')
      Remove-Item $zip -ErrorAction SilentlyContinue
      if (Test-Path (Join-Path $raiz 'APP\platform-tools\adb.exe')) { $instalado = $true; Ok 'adb instalado en APP\platform-tools (portable)' }
    } catch { Mal "descarga fallo: $($_.Exception.Message)" }
  }

  $adb = Resolve-Adb $raiz
  if (-not $adb) { Write-Host ''; Write-Host '   [X] No se pudo instalar adb. Descarga manual:' -ForegroundColor Red; Write-Host '       https://developer.android.com/tools/releases/platform-tools' -ForegroundColor Red; exit 1 }
}

Paso '3/3  Verificacion'
& $adb version | Select-Object -First 1 | ForEach-Object { Ok "adb responde: $_" }
Write-Host ''
Write-Host '============================================' -ForegroundColor Green
Write-Host '  LISTO - ya puedes abrir MovilLink.bat' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
