# Genera la identidad visual de MovilLink en APP\Recursos\:
#   logo.png (512) + app.ico (256 PNG-en-ICO) + banner.png (1200x400)
# Uso: powershell -ExecutionPolicy Bypass -File tools\Generar-Recursos.ps1
Add-Type -AssemblyName System.Drawing

$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out  = Join-Path $raiz 'APP\Recursos'
New-Item -ItemType Directory -Force $out | Out-Null

$navyA = [System.Drawing.Color]::FromArgb(14, 38, 78)
$navyB = [System.Drawing.Color]::FromArgb(30, 80, 160)
$mint  = [System.Drawing.Color]::FromArgb(46, 220, 150)
$blanco = [System.Drawing.Color]::White
$celeste = [System.Drawing.Color]::FromArgb(140, 185, 240)

function New-RoundRect($rect, [int]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
  $p.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
  $p.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
  $p.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Draw-Logo([System.Drawing.Graphics]$g, [float]$s) {
  # Marca: telefono + flechas circulares (el puente/reverse) + arcos wifi.
  $g.TranslateTransform(0, 0)
  $g.ScaleTransform($s / 512.0, $s / 512.0)

  # telefono (silueta blanca)
  $penW = New-Object System.Drawing.Pen($blanco, 18)
  $fono = New-RoundRect (New-Object System.Drawing.RectangleF(196, 116, 120, 280)) 26
  $g.DrawPath($penW, $fono)
  # pantalla
  $scr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 130, 205))
  $pant = New-RoundRect (New-Object System.Drawing.RectangleF(214, 146, 84, 214)) 14
  $g.FillPath($scr, $pant); $scr.Dispose()
  # boton home
  $btnHome = New-Object System.Drawing.SolidBrush($blanco)
  $g.FillEllipse($btnHome, 246, 366, 20, 20); $btnHome.Dispose()

  # flechas de ciclo alrededor del telefono (verde menta)
  $pen = New-Object System.Drawing.Pen($mint, 22)
  $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawArc($pen, 120, 90, 272, 272, 205, 210)   # arco superior izq->der
  $g.DrawArc($pen, 120, 150, 272, 272, 25, 210)   # arco inferior der->izq
  # puntas de flecha (cap pequeño — AdjustableArrowCap escala con el grosor)
  $ah = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(2.6, 3)
  $pen.CustomEndCap = $ah
  $g.DrawArc($pen, 120, 90, 272, 272, 180, 25)
  $g.DrawArc($pen, 120, 150, 272, 272, 0, 25)
  $ah.Dispose(); $pen.Dispose(); $penW.Dispose()
}

# ------------------------------- logo.png -------------------------------
$logo = New-Object System.Drawing.Bitmap(512, 512)
$g = [System.Drawing.Graphics]::FromImage($logo)
$g.SmoothingMode = 'AntiAlias'
$base = New-RoundRect (New-Object System.Drawing.RectangleF(8, 8, 496, 496)) 110
$br = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.RectangleF(0, 0, 512, 512)), $navyA, $navyB, 45.0)
$g.FillPath($br, $base); $br.Dispose()
Draw-Logo $g 512
$logo.Save((Join-Path $out 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()

# ------------------------------- app.ico --------------------------------
# ICO con PNG 256 embebido (soportado desde Vista, nitido a cualquier escala).
$ico256 = New-Object System.Drawing.Bitmap(256, 256)
$g2 = [System.Drawing.Graphics]::FromImage($ico256)
$g2.SmoothingMode = 'AntiAlias'
$base2 = New-RoundRect (New-Object System.Drawing.RectangleF(4, 4, 248, 248)) 55
$br2 = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.RectangleF(0, 0, 256, 256)), $navyA, $navyB, 45.0)
$g2.FillPath($br2, $base2); $br2.Dispose()
Draw-Logo $g2 256
$g2.Dispose()
$ms = New-Object System.IO.MemoryStream
$ico256.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray(); $ms.Dispose(); $ico256.Dispose()
$fs = [System.IO.File]::Create((Join-Path $out 'app.ico'))
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)      # ICONDIR
$bw.Write([byte]0); $bw.Write([byte]0)                              # w=256 h=256
$bw.Write([byte]0); $bw.Write([byte]0)                              # paleta/reservado
$bw.Write([uint16]1); $bw.Write([uint16]32)                         # planes/bpp
$bw.Write([uint32]$png.Length); $bw.Write([uint32]22)               # tam/offset
$bw.Write($png)
$bw.Close(); $fs.Close()

# ------------------------------ banner.png ------------------------------
$ban = New-Object System.Drawing.Bitmap(1200, 400)
$g3 = [System.Drawing.Graphics]::FromImage($ban)
$g3.SmoothingMode = 'AntiAlias'
$g3.TextRenderingHint = 'AntiAlias'
$brB = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.RectangleF(0, 0, 1200, 400)), $navyA, $navyB, 15.0)
$g3.FillRectangle($brB, 0, 0, 1200, 400); $brB.Dispose()
# acento inferior menta
$acc = New-Object System.Drawing.SolidBrush($mint)
$g3.FillRectangle($acc, 0, 384, 1200, 16); $acc.Dispose()
# logo dentro del banner
$lg = New-Object System.Drawing.Bitmap(280, 280)
$gl = [System.Drawing.Graphics]::FromImage($lg); $gl.SmoothingMode = 'AntiAlias'
$bs = New-RoundRect (New-Object System.Drawing.RectangleF(6, 6, 268, 268)) 60
$brl = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.RectangleF(0, 0, 280, 280)), $navyA, $navyB, 45.0)
$gl.FillPath($brl, $bs); $brl.Dispose()
Draw-Logo $gl 280
$gl.Dispose()
$g3.DrawImage($lg, 70, 60, 280, 280)
$lg.Dispose()
# textos
$ft = New-Object System.Drawing.Font('Segoe UI Semibold', 96, [System.Drawing.FontStyle]::Bold)
$fs2 = New-Object System.Drawing.Font('Segoe UI', 30)
$w = New-Object System.Drawing.SolidBrush($blanco)
$wc = New-Object System.Drawing.SolidBrush($celeste)
$g3.DrawString('MovilLink', $ft, $w, 390, 108)
$g3.DrawString('Tu dev server en el movil, sin cables', $fs2, $wc, 396, 266)
$w.Dispose(); $wc.Dispose(); $ft.Dispose(); $fs2.Dispose()
$g3.Dispose()
$ban.Save((Join-Path $out 'banner.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$ban.Dispose(); $logo.Dispose()

Get-ChildItem $out | ForEach-Object { "OK $($_.Name)  $([math]::Round($_.Length/1kb,1)) KB" }
