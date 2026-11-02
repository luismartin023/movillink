# Paso 0 — exclusion de Windows Defender SOLO para esta carpeta.
# Pide admin una sola vez; no toca nada mas.
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '   PASO 0 - EXCLUSION DEL ANTIVIRUS' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  MovilLink usa scripts de PowerShell, y algunos'
Write-Host '  antivirus los revisan o bloquean.'
Write-Host ''
Write-Host '  Esto agrega SOLO esta carpeta a las exclusiones'
Write-Host '  de Windows Defender. Con otro antivirus, agrega'
Write-Host '  la carpeta a sus exclusiones a mano.'
Write-Host ''

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $admin) {
  Write-Host '  Se necesitan permisos de administrador. Solicitando elevacion...' -ForegroundColor Yellow
  Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
  exit
}

try {
  Add-MpPreference -ExclusionPath $raiz -ErrorAction Stop
  Write-Host "  [OK] Carpeta excluida: $raiz" -ForegroundColor Green
  Write-Host '  Ya puedes usar MovilLink sin problemas.'
} catch {
  Write-Host "  [X] No se pudo agregar la exclusion: $($_.Exception.Message)" -ForegroundColor Red
}
