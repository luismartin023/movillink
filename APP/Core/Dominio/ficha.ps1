# Dominio FICHA — historial de endpoints en telefono-ultimo.json.
# Es la entrada MANUAL del usuario y el historial automatico a la vez:
# la app lo lee/escribe y el usuario puede editarlo a mano.

function Read-Ficha {
  if (Test-Path $script:ficha) { try { Get-Content -Raw $script:ficha | ConvertFrom-Json } catch { $null } }
}

function Get-Candidatos {
  $f = Read-Ficha
  if (-not $f) { return @() }
  if ($f.ultimos) { return @($f.ultimos) }
  if ($f.ip) { return @($f) }
  return @()
}

# Historial: uno nuevo va primero, sin duplicar ip+puerto, max 8.
function Save-Endpoint([string]$Ip, [int]$Port) {
  if ($Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or $Port -lt 1) { return }
  $nuevo = [pscustomobject]@{ ip = $Ip; adbPort = $Port; actualizado = (Get-Date -Format 's') }
  $resto = @(Get-Candidatos | Where-Object { -not ($_.ip -eq $Ip -and [int]$_.adbPort -eq $Port) })
  $ultimos = @(@($nuevo) + $resto | Select-Object -First 8)
  @{ ultimos = $ultimos } | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $script:ficha
}

function Remove-Endpoint([string]$Ip, [int]$Port) {
  $resto = @(Get-Candidatos | Where-Object { -not ($_.ip -eq $Ip -and [int]$_.adbPort -eq $Port) })
  @{ ultimos = $resto } | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $script:ficha
}
