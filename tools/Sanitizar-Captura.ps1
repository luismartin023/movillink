# Sanitizar-Captura.ps1 — censura datos vivos de APP\Recursos\captura.png
# (IP del movil, serial adb e IPs del historial) antes de publicarla.
Add-Type -AssemblyName System.Drawing
$png = (Resolve-Path (Join-Path $PSScriptRoot '..\APP\Recursos\captura.png')).Path
$img = [System.Drawing.Bitmap]::FromFile($png)
$g = [System.Drawing.Graphics]::FromImage($img)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'ClearTypeGridFit'

function Muestra([int]$x, [int]$y) { return $img.GetPixel($x, $y) }
function Tapa([int]$x, [int]$y, [int]$w, [int]$h, [int]$sx, [int]$sy) {
  $b = New-Object System.Drawing.SolidBrush (Muestra $sx $sy)
  $g.FillRectangle($b, $x, $y, $w, $h); $b.Dispose()
}
$gris = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 105, 130))
$texto = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(45, 55, 72))
$fSub = New-Object System.Drawing.Font('Segoe UI', 10)
$fMono = New-Object System.Drawing.Font('Consolas', 11)

# --- linea de info del dispositivo (IP + serial) ---
Tapa 26 438 468 26 485 450
$g.DrawString('IP: 192.168.1.50   ·   adb-XXXXXXX._adb-tls-connect._tcp', $fSub, $gris, 30, 440)

# --- filas del historial (IPs/puertos reales) ---
Tapa 30 482 468 42 485 500
$g.DrawString('192.168.1.50:45000    (2026-01-01T00:00:00)', $fMono, $texto, 40, 484)
$g.DrawString('10.0.0.20:39000      (2025-12-30T09:15:00)', $fMono, $texto, 40, 503)

$g.Dispose()
$tmp = "$png.tmp.png"
$img.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Move-Item -Force $tmp $png
Write-Host "captura.png sanitizada"
