# Estado rapido para el menu: una linea con adb + movil + reverse.
$ErrorActionPreference = 'SilentlyContinue'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'Core\MovilLink.Core.ps1')
$cfg = Initialize-MovilLink $raiz | Out-Null
$script:OnLog = { param($m) }

$adbTxt = if ($script:adb) { 'OK' } else { 'FALTA -> opcion 2' }
$movilTxt = 'ninguno'
$revTxt = '-'
if ($script:adb) {
  $lista = @(Get-Moviles)
  if ($lista.Count -gt 0) {
    $serial = Select-Serial $lista
    $movilTxt = "$($lista.Count) conectado ($serial)"
    $revTxt = if (Test-Reverse $serial 3000) { 'tcp:3000 OK' } else { 'SIN reverse' }
  }
}
Write-Host "   adb: $adbTxt   |   movil: $movilTxt   |   reverse: $revTxt"
