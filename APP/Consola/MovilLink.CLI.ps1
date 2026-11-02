# MovilLink.CLI — adaptador de terminal. Mismo Core, sin ventana:
#   .\MovilLink.CLI.ps1                      -> autodescubre y conecta
#   .\MovilLink.CLI.ps1 -Conectar "IP:PUERTO" -> manual directo
#   .\MovilLink.CLI.ps1 -Puerto 3001         -> otro puerto de dev server
param(
  [string]$Conectar = '',
  [int]$Puerto = 3000
)

$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot '..\Core\MovilLink.Core.ps1')
$cfg = Initialize-MovilLink $raiz

if (-not $cfg.adbOk) {
  Write-Host 'adb no encontrado. Ejecuta primero: 1-Instalar-Necesarios.bat'
  exit 1
}

try {
  $serial = $null
  if ($Conectar.Trim()) {
    & $script:adb connect $Conectar.Trim()
    $lista = @(Wait-Movil 8 700)
    if ($lista) { $serial = Select-Serial $lista }
  }
  else {
    $serial = Connect-Auto
  }

  if (-not $serial) {
    Write-Host ''
    Write-Host 'SIN RESPUESTA DEL MOVIL. Que hacer, en orden:'
    Write-Host '  1) Movil: Opciones de desarrollador > Depuracion inalambrica ON, mismo WiFi que el PC.'
    Write-Host '  2) Si cambiaste de red o apagaste/encendiste la depuracion, la IP:PUERTO es nueva ->'
    Write-Host '       .\MovilLink.CLI.ps1 -Conectar "IP:PUERTO"'
    Write-Host '  3) Diagnostico: adb connect IP:PUERTO | adb devices | adb mdns services | arp -a'
    exit 1
  }

  Start-Sleep -Milliseconds 1200
  $serial = Confirm-Conexion $serial $Puerto

  Write-Host "Movil: $serial"
  & $script:adb devices
  Write-Host ''
  Write-Host "Listo. localhost:$Puerto del movil apunta a este PC:"
  & $script:adb -s $serial reverse --list
  Write-Host ''
  Write-Host "Chrome del movil  -> http://localhost:$Puerto/acceso"
  Write-Host "Login del colegio -> http://<subdominio>.localhost:$Puerto/acceso"
  exit 0
} catch {
  $f = Write-ErrorLog $_
  Write-Host "ERROR: $($_.Exception.Message)"
  if ($f) { Write-Host "Detalle: $f" }
  exit 1
}
