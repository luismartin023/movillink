# Dominio ADB — unica puerta de salida hacia el ejecutable adb.
# Ninguna otra capa invoca adb.exe directamente.

# Resuelve adb en orden: PATH -> platform-tools portable del paquete ->
# shim de winget -> rutas conocidas. Devuelve la ruta/comando o $null.
function Resolve-Adb([string]$Raiz) {
  if (Get-Command adb -ErrorAction SilentlyContinue) { return 'adb' }
  $candidatas = @(
    (Join-Path $Raiz 'APP\platform-tools\adb.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\adb.exe'),
    'C:\Users\luism\Downloads\platform-tools-latest-windows\platform-tools\adb.exe'
  )
  foreach ($r in $candidatas) { if ($r -and (Test-Path $r)) { return $r } }
  return $null
}

function Get-Moviles {
  @((& $script:adb devices) | Where-Object { $_ -match "`tdevice$" } | ForEach-Object { ($_ -split '\s+')[0] })
}

function Wait-Movil([int]$Intentos = 4, [int]$Ms = 600) {
  foreach ($i in 1..$Intentos) {
    $l = @(Get-Moviles)
    if ($l.Count -gt 0) { return $l }
    Start-Sleep -Milliseconds $Ms
  }
  return @()
}

# Daemon zombie: mDNS vacio con el movil vivo en la LAN mata el plan A. Un
# solo reinicio por llamada — el env ADB_MDNS_OPENSCREEN si aplica al nacer.
$script:daemonReiniciado = $false
function Restart-AdbDaemon {
  if ($script:daemonReiniciado) { return }
  $script:daemonReiniciado = $true
  Log 'Daemon adb zombie -> kill-server + start-server (reintenta mDNS)...'
  & $script:adb kill-server 2>$null | Out-Null
  & $script:adb start-server 2>$null | Out-Null
  Start-Sleep -Milliseconds 800
}

function Invoke-AdbConnect([string]$Endpoint) {
  $r = & $script:adb connect $Endpoint 2>&1 | Out-String
  return ($r -match 'connected')
}

# Preferir transporte mDNS (_tcp): se reconecta solo si se cae la red.
function Select-Serial([string[]]$Lista) {
  $s = $Lista | Where-Object { $_ -match '_adb-tls-connect' } | Select-Object -First 1
  if (-not $s) { $s = $Lista[0] }
  return $s
}

# IP real del movil desde su propio shell (para cuando solo existe el
# transporte _tcp, cuyo serial no trae ip:puerto).
function Get-IpMovil([string]$Serial) {
  try {
    $salida = & $script:adb -s $Serial shell "ip -f inet addr show wlan0" 2>$null
    foreach ($l in $salida) { if ($l -match 'inet (\d{1,3}(?:\.\d{1,3}){3})/') { return $Matches[1] } }
  } catch {}
  return $null
}

# Puertos en LISTEN del movil (candidatos adb cuando el serial es _tcp).
function Get-PuertosEscuchaMovil([string]$Serial) {
  $puertos = @()
  try {
    foreach ($l in (& $script:adb -s $Serial shell "netstat -tln" 2>$null)) {
      if ($l -notmatch 'LISTEN') { continue }
      $f = $l -split '\s+'
      if ($f.Count -lt 6 -or $f[3] -match '^127\.') { continue }
      $p = ($f[3] -split ':')[-1]
      if ($p -match '^\d+$') { $puertos += [int]$p }
    }
  } catch {}
  return $puertos
}

function Set-Reverse([string]$Serial, [int]$P) {
  & $script:adb -s $Serial reverse "tcp:$P" "tcp:$P" | Out-Null
}

function Test-Reverse([string]$Serial, [int]$P) {
  $l = & $script:adb -s $Serial reverse --list 2>$null
  return [bool]($l | Where-Object { $_ -match "tcp:$P\s+tcp:$P" })
}
