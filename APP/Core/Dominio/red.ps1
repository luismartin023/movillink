# Dominio RED — sondas TCP y descubrimiento en la LAN.
# Sin estado: cada funcion es pura sobre sus parametros.

# Sonda TCP clasificada: Open = el puerto escucha; Refused = host VIVO pero
# puerto cerrado (senal clave para "misma IP, puerto nuevo"); Silent = muerto.
function Test-SondaTcp([string]$Ip, [int]$Port, [int]$Ms = 2000) {
  $c = [System.Net.Sockets.TcpClient]::new()
  try {
    $t = $c.ConnectAsync($Ip, $Port)
    if (-not $t.Wait($Ms)) { return 'Silent' }
    if ($c.Connected) { return 'Open' }
    $se = $t.Exception
    while ($se -and -not ($se -is [System.Net.Sockets.SocketException])) { $se = $se.InnerException }
    if ($se -and $se.SocketErrorCode -eq [System.Net.Sockets.SocketError]::ConnectionRefused) { return 'Refused' }
    return 'Silent'
  }
  catch { return 'Silent' }
  finally { $c.Close() }
}

# Prioriza endpoints de la red actual (mismo prefijo que alguna IP real del
# PC — /24+ -> 3 octetos; redes grandes 172.x/10.x -> 2).
function Test-MismaRed([string]$IpMovil) {
  $b = $IpMovil -split '\.'
  foreach ($mi in (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
                   $_.InterfaceAlias -notmatch 'VMware|Loopback|vEthernet' })) {
    $a = $mi.IPAddress -split '\.'
    $octetos = if ($mi.PrefixLength -ge 24) { 3 } else { 2 }
    $misma = $true
    foreach ($i in 0..($octetos - 1)) { if ($a[$i] -ne $b[$i]) { $misma = $false; break } }
    if ($misma) { return $true }
  }
  return $false
}

# Sonda TCP paralela a todo el /24 de cada interfaz real con un puerto dado.
function Find-EnSubred([int]$Port, [int]$Ms = 4000) {
  $encontradas = [System.Collections.Generic.List[string]]::new()
  foreach ($mi in (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
                   $_.InterfaceAlias -notmatch 'VMware|Loopback|vEthernet' -and $_.PrefixLength -ge 24 })) {
    $base = ($mi.IPAddress -split '\.')[0..2] -join '.'
    $clientes = foreach ($i in 1..254) {
      $ip = "$base.$i"
      if ($ip -eq $mi.IPAddress) { continue }
      $c = [System.Net.Sockets.TcpClient]::new()
      [pscustomobject]@{ ip = $ip; c = $c; t = $c.ConnectAsync($ip, $Port) }
    }
    if ($clientes) { [void][System.Threading.Tasks.Task]::WaitAll(@($clientes.t), $Ms) }
    foreach ($cl in $clientes) { if ($cl.c.Connected) { [void]$encontradas.Add($cl.ip) }; $cl.c.Close() }
  }
  return $encontradas.ToArray()
}

# Vecinos ARP vivos de las interfaces reales (excluye propias y omitidas).
function Get-Vecinos([string[]]$Omitidas) {
  $propias = @((Get-NetIPAddress -AddressFamily IPv4).IPAddress)
  @(Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.InterfaceAlias -notmatch 'VMware|Loopback|vEthernet' -and
      $_.LinkLayerAddress -match '^([0-9a-fA-F]{2}-){5}[0-9a-fA-F]{2}$' -and
      $_.LinkLayerAddress -ne 'ff-ff-ff-ff-ff-ff' -and
      $_.IPAddress -match '^\d{1,3}(\.\d{1,3}){3}$' -and
      $propias -notcontains $_.IPAddress -and $Omitidas -notcontains $_.IPAddress
    } | Select-Object -ExpandProperty IPAddress -Unique | Select-Object -First 40)
}

# Barrido del rango efimero de Android (32768-60999) en UNA sola IP viva, en
# lotes paralelos. Cada puerto abierto se valida con `adb connect` real —
# solo adbd responde al handshake TLS. Tope ~45s.
function Find-PuertoEfimero([string]$Ip) {
  Log "  ${Ip}: barriendo rango efimero (puerto rotado)..."
  $desde = 32768; $hasta = 60999; $lote = 1200; $tope = (Get-Date).AddSeconds(45)
  for ($base = $desde; $base -le $hasta -and (Get-Date) -lt $tope; $base += $lote) {
    $fin = [Math]::Min($base + $lote - 1, $hasta)
    $clientes = foreach ($p in $base..$fin) {
      $c = [System.Net.Sockets.TcpClient]::new()
      [pscustomobject]@{ p = $p; c = $c; t = $c.ConnectAsync($Ip, $p) }
    }
    [void][System.Threading.Tasks.Task]::WaitAll(@($clientes.t), 800)
    $abiertos = @()
    foreach ($cl in $clientes) { if ($cl.c.Connected) { $abiertos += $cl.p }; $cl.c.Close() }
    foreach ($p in $abiertos) {
      Log "  ${Ip}:$p abierto -> adb connect"
      if (Invoke-AdbConnect "${Ip}:$p") { Log "  ${Ip}:$p CONFIRMADO"; return $p }
    }
  }
  return $null
}
