# Diagnostico rapido: adb, dispositivos, mDNS, reverse y ficha.
$ErrorActionPreference = 'Continue'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'Core\MovilLink.Core.ps1')
Initialize-MovilLink $raiz | Out-Null
$script:OnLog = { param($m) Write-Host "  $m" }

Write-Host ''
Write-Host '  ======= DIAGNOSTICO MOVILLINK =======' -ForegroundColor Cyan
Write-Host ''
if (-not $script:adb) {
  Write-Host '  adb: NO ENCONTRADO -> ejecuta la opcion 2 del menu' -ForegroundColor Red
  exit 1
}
Write-Host "  adb: $script:adb"
& $script:adb version | Select-Object -First 1 | ForEach-Object { Write-Host "       $_" }
Write-Host ''
Write-Host '  --- dispositivos ---' -ForegroundColor Cyan
& $script:adb devices
Write-Host ''
Write-Host '  --- mDNS (vacio = tu red no pasa multicast) ---' -ForegroundColor Cyan
& $script:adb mdns services
Write-Host ''
Write-Host '  --- reverse ---' -ForegroundColor Cyan
$lista = @(Get-Moviles)
if ($lista) { & $script:adb -s (Select-Serial $lista) reverse --list } else { Write-Host '  (sin movil)' }
Write-Host ''
Write-Host '  --- ficha (APP\Datos\telefono-ultimo.json) ---' -ForegroundColor Cyan
$cand = @(Get-Candidatos)
if ($cand) { $cand | ForEach-Object { Write-Host "   $($_.ip):$($_.adbPort)  ($($_.actualizado))" } } else { Write-Host '  (vacia)' }
Write-Host ''
Write-Host '  Si el movil esta vinculado pero no conecta:'
Write-Host '   1) Depuracion inalambrica ON, mismo WiFi'
Write-Host '   2) Puerto rotado -> la app lo barre sola, o conecta directo IP:PUERTO'
Write-Host "   3) 'unauthorized' -> acepta la huella RSA en el movil"
