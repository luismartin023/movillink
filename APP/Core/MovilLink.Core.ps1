# MovilLink.Core — orquestador del dominio.
# La Interfaz (WinForms) y la Consola (CLI) son adaptadores que consumen
# SOLO estas funciones: Initialize-MovilLink, Connect-Auto, Confirm-Conexion,
# Invoke-ConexionDirecta y los helpers de ficha/reverse del dominio.
#
# Orden de ataque (la ficha JSON es plan B, nunca el primero):
#   1. mDNS: autoconnect del daemon + linea explicita (reinicia daemon zombie)
#   2. ficha telefono-ultimo.json (misma red primero)
#   3. vecinos ARP con puertos de la ficha
#   4. barrido /24 con puertos conocidos
#   5. ultimo-ultimo: IP viva con puerto rotado -> rango efimero + adb connect

$ErrorActionPreference = 'Stop'
$env:ADB_MDNS_OPENSCREEN = '1'

# Dominio puro (misma carpeta Dominio/, por orden de dependencia).
. (Join-Path $PSScriptRoot 'Dominio\ficha.ps1')
. (Join-Path $PSScriptRoot 'Dominio\red.ps1')
. (Join-Path $PSScriptRoot 'Dominio\adb.ps1')

# Log unico: la capa que consume el Core redefine $script:OnLog.
$script:OnLog = { param($m) Write-Host $m }
function Log([string]$m) { & $script:OnLog $m }

# Capturadora de errores: cualquier adaptador la llama al atrapar una
# excepcion — deja logs\error-*.log con contexto para diagnostico.
function Write-ErrorLog($Err) {
  try {
    if (-not $script:logsDir) { return }
    $f = Join-Path $script:logsDir ('error-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $cuerpo = @(
      "MovilLink - error capturado  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
      "PSVersion : $($PSVersionTable.PSVersion)"
      "OS        : $([Environment]::OSVersion.VersionString)"
      "adb       : $($script:adb)"
      "---------------------------------------------"
      ($Err | Out-String)
      "ScriptStackTrace:"
      ($Err.ScriptStackTrace | Out-String)
    ) -join [Environment]::NewLine
    Set-Content -Encoding utf8 -Path $f -Value $cuerpo
    return $f
  } catch { return $null }
}

# Punto de entrada: fija raiz del paquete, ficha, logs y resuelve adb.
function Initialize-MovilLink([string]$Raiz) {
  $script:Raiz = $Raiz
  $script:ficha = Join-Path $Raiz 'telefono-ultimo.json'
  $script:logsDir = Join-Path $Raiz 'logs'
  New-Item -ItemType Directory -Force $script:logsDir | Out-Null
  $script:adb = Resolve-Adb $Raiz
  $script:daemonReiniciado = $false
  return [pscustomobject]@{ raiz = $Raiz; ficha = $script:ficha; logs = $script:logsDir; adb = $script:adb; adbOk = [bool]$script:adb }
}

# ================== CONECTAR: PLAN A -> PLAN B -> BARRIDO ==================
# Devuelve el serial elegido o $null.
function Connect-Auto {
  if (-not $script:adb) { Log 'adb no encontrado — ejecuta 1-Instalar-Necesarios.bat'; return $null }
  $lista = @(Get-Moviles)
  if ($lista.Count -gt 0) { return (Select-Serial $lista) }

  # ---- plan A: mDNS (autoconnect del daemon + linea explicita) ----
  Log 'Buscando el movil (mDNS)...'
  & $script:adb mdns services | Out-Null
  foreach ($i in 1..8) {
    $lista = @(Get-Moviles)
    if ($lista.Count -gt 0) { break }
    if ($i -eq 4) {
      $linea = & $script:adb mdns services | Where-Object { $_ -match '_adb-tls-connect\._tcp' } | Select-Object -First 1
      if ($linea -and $linea -match '([\d.]+:\d+)\s*$') { & $script:adb connect $Matches[1] | Out-Null }
    }
    Start-Sleep -Milliseconds 700
  }
  # Segunda oportunidad tras revivir un daemon zombie (mDNS mudo).
  if (-not $lista) {
    Restart-AdbDaemon
    & $script:adb mdns services | Out-Null
    $lista = @(Wait-Movil 6 600)
    if (-not $lista) {
      $linea = & $script:adb mdns services | Where-Object { $_ -match '_adb-tls-connect\._tcp' } | Select-Object -First 1
      if ($linea -and $linea -match '([\d.]+:\d+)\s*$') {
        & $script:adb connect $Matches[1] | Out-Null
        $lista = @(Wait-Movil 5 500)
      }
    }
  }
  if ($lista) { return (Select-Serial $lista) }

  # ---- plan B: ficha (historial manual/auto), misma red primero ----
  $candidatos = @(Get-Candidatos | Sort-Object { -not (Test-MismaRed $_.ip) })
  $ipsVivas = @()
  foreach ($e in $candidatos) {
    Log "mDNS mudo. Probando ficha $($e.ip):$($e.adbPort)..."
    $s = Test-SondaTcp $e.ip ([int]$e.adbPort) 3000
    if ($s -eq 'Open') {
      & $script:adb connect "$($e.ip):$($e.adbPort)" | Out-Null
      $lista = @(Wait-Movil 6 500)
      if ($lista) { return (Select-Serial $lista) }
    }
    elseif ($s -eq 'Refused') { $ipsVivas += $e.ip; Log '  host vivo, puerto cerrado.' }
    else { Log '  sin respuesta.' }
  }

  # ---- vecinos ARP con los puertos de la ficha ----
  $puertosFicha = @($candidatos.adbPort | Sort-Object -Unique | Select-Object -First 3)
  if ($puertosFicha) {
    $vecinos = @(Get-Vecinos @($candidatos.ip))
    if ($vecinos) {
      Log "Sondeando $($vecinos.Count) vecinos ARP en puertos $($puertosFicha -join ', ')..."
      foreach ($ip in $vecinos) {
        foreach ($pp in $puertosFicha) {
          $s = Test-SondaTcp $ip ([int]$pp) 800
          if ($s -eq 'Refused' -and $ipsVivas -notcontains $ip) { $ipsVivas += $ip }
          if ($s -ne 'Open') { continue }
          Log "  ${ip}:$pp responde -> adb connect"
          & $script:adb connect "${ip}:$pp" | Out-Null
          $lista = @(Wait-Movil 4 500)
          if ($lista) { return (Select-Serial $lista) }
        }
      }
    }
  }

  # ---- barrido /24 con los puertos conocidos ----
  foreach ($pp in $puertosFicha) {
    Log "Barriendo la subred en el puerto $pp..."
    foreach ($ip in (Find-EnSubred ([int]$pp))) {
      Log "  ${ip}:$pp responde -> adb connect"
      & $script:adb connect "${ip}:$pp" | Out-Null
      $lista = @(Wait-Movil 2 400)
      if ($lista) { return (Select-Serial $lista) }
      if ($ipsVivas -notcontains $ip) { $ipsVivas += $ip }
    }
  }

  # ---- ultimo recurso: IP viva pero puerto rotado -> rango efimero ----
  foreach ($ip in ($ipsVivas | Select-Object -Unique)) {
    $p = Find-PuertoEfimero $ip
    if ($p) {
      $lista = @(Wait-Movil 5 500)
      if ($lista) { Save-Endpoint $ip $p; return (Select-Serial $lista) }
    }
  }
  return $null
}

# Conexion directa a un endpoint escrito a mano (caja IP:PUERTO o ficha).
function Invoke-ConexionDirecta([string]$Endpoint) {
  if (-not $script:adb) { return $null }
  Log "adb connect $Endpoint"
  $r = & $script:adb connect $Endpoint 2>&1 | Out-String
  Log $r.Trim()
  $lista = @(Wait-Movil 6 500)
  if (-not $lista) { return $null }
  if ($Endpoint -match '^(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$') { Save-Endpoint $Matches[1] ([int]$Matches[2]) }
  return (Select-Serial $lista)
}

# La ficha debe guardar un ip:puerto real. Con transporte _tcp el serial no
# lo trae: se pide la IP al movil y el puerto se redescubre cruzando los
# LISTEN de su netstat con los puertos conocidos.
function Sync-Ficha([string]$Serial, [string[]]$Lista) {
  $directo = $Lista | Where-Object { $_ -match '^(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$' } | Select-Object -First 1
  if ($directo -and $directo -match '^(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$') {
    Save-Endpoint $Matches[1] ([int]$Matches[2]); return
  }
  $ip = Get-IpMovil $Serial
  if (-not $ip) { return }
  $cand = @()
  $cand += @(Get-Candidatos | Where-Object { $_.ip -eq $ip } | ForEach-Object { [int]$_.adbPort })
  $cand += @(Get-PuertosEscuchaMovil $Serial | Where-Object { $_ -ge 30000 })
  foreach ($p in ($cand | Sort-Object -Unique)) {
    if ((Test-SondaTcp $ip $p 1200) -ne 'Open') { continue }
    if (Invoke-AdbConnect "${ip}:$p") { Save-Endpoint $ip $p; return }
  }
}

# Tras conectar: actualizar ficha (puede abrir un transporte ip:puerto),
# deduplicar transportes quedando el _tcp, y asegurar el reverse.
function Confirm-Conexion([string]$Serial, [int]$P) {
  $lista = @(Get-Moviles)
  Sync-Ficha $Serial $lista
  $lista = @(Get-Moviles)
  $elegido = Select-Serial $lista
  foreach ($d in $lista) { if ($d -ne $elegido) { & $script:adb disconnect $d | Out-Null } }
  if (-not (Test-Reverse $elegido $P)) { Set-Reverse $elegido $P }
  return $elegido
}
