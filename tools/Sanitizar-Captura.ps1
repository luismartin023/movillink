# Sanitizar-Captura.ps1 — censura datos vivos de APP\Recursos\captura.png
# (IP del movil, serial adb e IPs del historial) antes de publicarla.
# Coordenadas medidas sobre la captura de 518x907 (layout v1.2.2).
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
$fSub = New-Object System.Drawing.Font('Segoe UI', 9)

# --- linea de detalle de estado (serial real -> localhost), centrada ---
Tapa 15 184 490 22 505 195
$falso = '192.168.1.50:45000   ->   localhost:3000/acceso'
$wFalso = $g.MeasureString($falso, $fSub).Width
$g.DrawString($falso, $fSub, $gris, [int]((518 - $wFalso) / 2), 186)

# --- linea de info del dispositivo (IP + serial reales) ---
Tapa 36 438 460 20 505 450
$g.DrawString('IP: 192.168.1.50   -   adb-XXXXXXX._adb-tls-connect._tcp', $fSub, $gris, 40, 440)

$g.Dispose()
$tmp = "$png.tmp.png"
$img.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Move-Item -Force $tmp $png
Write-Host "captura.png sanitizada"
